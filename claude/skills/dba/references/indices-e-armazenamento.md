# Índices e Armazenamento

Abra esta referência quando precisar **decidir**: criar ou não um índice, qual tipo, em quais colunas e em que ordem; entender por que uma query faz Seq Scan apesar do índice existir; estimar o custo de escrita que um índice novo vai impor; ou justificar uma escolha de organização física (heap, ordenação, hashing, particionamento). A base teórica vem de Elmasri & Navathe, caps. 17 e 18. Tudo que extrapola o livro está marcado como **Nota prática:** — geralmente é a tradução para o PostgreSQL real.

Domínio dos exemplos: finanças pessoais (contas, transações, categorias), PostgreSQL + Prisma.

---

## 1. Por que I/O domina o custo

### Hierarquia de memória (Elmasri, cap. 17.1.1)

| Nível | Meio | Característica |
|---|---|---|
| Primário | Cache (SRAM), DRAM | Rápido, volátil, caro, pequeno |
| Intermediário | Flash / EEPROM | Não volátil, apagamento em bloco |
| Secundário | Disco magnético | Não volátil, on-line, acesso aleatório por bloco |
| Terciário | Óptico, fita | Off-line, acesso sequencial, backup/arquivamento |

A CPU **não processa dados no armazenamento secundário**. Todo dado precisa ser copiado para um buffer na memória principal, processado, e reescrito se alterado (Elmasri, cap. 17.1.2). Bancos de dados vivem no armazenamento secundário por três motivos: não cabem na RAM, o disco é não volátil, e o custo por byte é ordens de grandeza menor.

### Bloco é a unidade de tudo

A trilha do disco é dividida em **blocos** (ou páginas) de tamanho fixo, definido na formatação — tipicamente 512 a 8.192 bytes (Elmasri, cap. 17.2.1). A transferência entre disco e memória acontece **sempre em blocos inteiros**. Ler 1 byte custa o mesmo que ler o bloco todo.

Custo de acessar um bloco arbitrário:

```
tempo_total = tempo_de_busca + atraso_rotacional + tempo_de_transferência
```

Números do livro (disco de servidor): busca 3–8 ms, atraso rotacional 2 ms a 15.000 rpm, transferência ~0,4–2 ms. Total 9–60 ms para o **primeiro** bloco; blocos contíguos subsequentes custam apenas 0,4–2 ms cada, porque busca e rotação são eliminadas (Elmasri, cap. 17.2.1).

Daí as duas leis que governam todo o resto:

1. **A localização dos dados no disco é o gargalo principal das aplicações de banco de dados.** Milissegundos versus nanossegundos de CPU.
2. **Colocar 'informações relacionadas' em blocos contíguos é o objetivo básico de qualquer organização de armazenamento em disco** (Elmasri, cap. 17.2.1).

Toda estrutura dos caps. 17 e 18 existe para **minimizar o número de transferências de bloco**.

### Fator de blocagem (Elmasri, cap. 17.4.3)

```
bfr = floor(B / R)          registros por bloco
b   = ceil(r / bfr)         blocos necessários para r registros
```

Espaço desperdiçado por bloco: `B - (bfr * R)` bytes. Organização **espalhada** (spanned) permite um registro atravessar blocos, com ponteiro no fim do bloco; **não espalhada** (unspanned) proíbe. Registros de tamanho fixo em blocos não espalhados permitem endereçamento direto por posição — o *i*-ésimo registro está no bloco `floor(i/bfr)`, posição `i mod bfr`.

### Buffering (Elmasri, cap. 17.3)

Com **buffering duplo**, a CPU processa o buffer A enquanto o controlador de I/O preenche o buffer B. Isso elimina busca e rotação para todas as transferências exceto a primeira, e permite leitura contínua de blocos consecutivos. É a razão pela qual varredura sequencial é muito mais barata por bloco do que acesso aleatório.

### Nota prática: o que muda com SSD/NVMe

O livro é de uma era de discos magnéticos. O que mudou:

- **Tempo de busca praticamente desapareceu.** Um NVMe faz um acesso aleatório de 4 KB em ~50–100 µs — 50 a 100× mais rápido que HDD. A penalidade de aleatório vs. sequencial caiu de ~50× para ~2–4×.
- **O gargalo não sumiu, mudou de lugar.** Sequencial ainda ganha por: readahead do SO, menos syscalls, prefetch, e melhor uso da cache do PostgreSQL. E acessar 1 milhão de linhas via índice ainda faz 1 milhão de acessos ao heap.
- **Escrita em flash tem custo assimétrico.** Apagamento é por bloco (o livro já nota isso, cap. 17.1.1); write amplification e garbage collection interno são reais. Índices demais = escrita amplificada.
- **A consequência direta em PostgreSQL:** o default `random_page_cost = 4.0` foi calibrado para HDD. Em SSD/NVMe use `1.1`. Sem esse ajuste o planner subestima sistematicamente o valor dos index scans e escolhe Seq Scan cedo demais.

```sql
-- em postgresql.conf, para SSD/NVMe
random_page_cost = 1.1
seq_page_cost = 1.0
effective_cache_size = '12GB'   -- ~50-75% da RAM da máquina
effective_io_concurrency = 200  -- NVMe; 1-2 para HDD
```

Isso não invalida o modelo do livro. **Continua sendo um modelo de contagem de blocos** — só mudou o peso relativo entre bloco aleatório e bloco sequencial.

---

## 2. Organização de arquivo primária

A organização primária determina **onde o registro fica fisicamente** no disco. Um arquivo tem exatamente uma (Elmasri, cap. 17.1.2).

### 2.1 Heap / desordenado (Elmasri, cap. 17.6)

Registros na ordem de inserção; novos vão no fim do arquivo.

| Operação | Custo |
|---|---|
| Inserção | 2 acessos (lê último bloco, regrava). **Ótimo.** |
| Busca por qualquer condição | `b/2` na média se único match; `b` se nenhum ou vários |
| Exclusão | Localiza + regrava; deixa buraco, ou usa marcador de exclusão |
| Leitura ordenada | Exige cópia classificada (ordenação externa) |

Exclusões acumulam espaço desperdiçado → exige **reorganização periódica**.

**Nota prática:** toda tabela PostgreSQL é um heap. Não existe índice clusterizado no PostgreSQL (diferente de InnoDB/SQL Server, onde a PK *é* a organização física). O marcador de exclusão do livro é literalmente o `xmax`/tuple visibility do MVCC, e a "reorganização periódica" é o `VACUUM`. Isso significa que **a PK no PostgreSQL é apenas mais um índice secundário** — insight que muda decisões de modelagem.

### 2.2 Ordenado / sequencial (Elmasri, cap. 17.7)

Ordenado fisicamente por um **campo de ordenação**. Se esse campo é chave, é a **chave de ordenação**.

| Operação | Custo |
|---|---|
| Busca por igualdade na chave de ordenação | `log₂(b)` (pesquisa binária por blocos) |
| Busca por outro campo | `b/2` (linear) |
| Range (`>`, `<`, `BETWEEN`) na chave de ordenação | Muito eficiente — matches são contíguos |
| Leitura em ordem da chave | Ótimo, sem ordenação |
| Próximo registro em ordem | Geralmente 0 acessos extras (mesmo bloco) |
| **Inserção** | **~`b/2` blocos lidos e regravados. Péssimo.** |

A inserção é o problema fatal: manter a ordem física exige mover metade dos registros. Mitigações: (a) espaço livre reservado em cada bloco; (b) **arquivo de overflow** desordenado, mesclado periodicamente ao arquivo mestre — inserção fica barata, busca fica cara (binária no mestre + linear no overflow).

> "Os arquivos ordenados raramente são usados em aplicações de banco de dados, a menos que um caminho de acesso adicional, chamado índice primário, seja utilizado" (Elmasri, cap. 17.7).

**Nota prática:** PostgreSQL não mantém ordem física. `CLUSTER tabela USING indice` reordena uma vez e **não mantém** — novos INSERTs vão para o fim do heap. Só faz sentido em tabela histórica pouco atualizada, e o único consumidor real dessa correlação física é o índice BRIN (§7.5).

### 2.3 Hashing (Elmasri, cap. 17.8)

`h(K)` aplicada ao **campo de hash** dá diretamente o endereço. Custo: **1 acesso de bloco** para recuperar o registro. Só serve para **condição de igualdade em um único campo**.

**Hashing externo** (cap. 17.8.2): o espaço de endereços é dividido em **buckets** (um bloco ou cluster de blocos). Colisão só é problema quando o bucket enche → cadeia de overflow encadeada.

Meta de ocupação: `r/M` entre **0,7 e 0,9** — abaixo disso desperdiça espaço, acima disso as colisões explodem. `M` primo distribui melhor com a função `mod`.

**Hashing estático:** `M` fixo. Se `r << m*M`, desperdício; se `r >> m*M`, cadeias de overflow longas e recuperação lenta. Corrigir exige rehash completo — proibitivo em arquivo grande.

**Hashing extensível** (cap. 17.8.3): diretório de `2^d` endereços de bucket, `d` = profundidade global. Os `d` bits de ordem alta do valor de hash indexam o diretório. Cada bucket tem profundidade local `d'`. Bucket estoura → divide em dois (bits `010` e `011` em vez de `01`), `d'` aumenta em 1. Se `d' == d`, o **diretório dobra**.

- Vantagem: desempenho não degrada com o crescimento; divisão reorganiza só um bucket; overhead do diretório é insignificante.
- Custo: **2 acessos** (diretório + bucket) em vez de 1.

**Hashing dinâmico:** precursor; mesmo efeito, mas o diretório é uma árvore binária (nó interno com ponteiro 0/1; folha aponta pro bucket) em vez de um array plano.

**Hashing linear:** **sem diretório**. Começa com `M` buckets e `h_j(K) = K mod (2^j · M)`. Quando ocorre overflow, divide o bucket `n` (não o que estourou!) em ordem linear 0, 1, 2, …, redistribuindo com a função seguinte. Um único contador `n` basta: se `h_j(K) < n`, o bucket já foi dividido → aplique `h_{j+1}`. Quando `n == M`, todos foram divididos, `n` volta a 0 e passa-se à próxima função.

Melhor que disparar por overflow: disparar por **fator de carga** `f = r / (bfr · N)` — divide quando `f > 0,9`, combina quando `f < 0,7`. Mantém a carga constante enquanto o arquivo cresce e encolhe, sem diretório.

**Limitação comum a todos:** busca por campo que não seja o de hash é tão cara quanto num heap. Range query é impossível.

### 2.4 Arquivos mistos (Elmasri, cap. 17.9.1)

Registros de **tipos diferentes** agrupados fisicamente no mesmo bloco, para materializar um relacionamento. Ex.: cada registro de DEPARTAMENTO seguido do cluster de seus ALUNOs. Cada registro carrega um **campo de tipo de registro**. Vantagem: recuperar pai + filhos custa 1 acesso. Usado por SGBDs de objeto e sistemas legados hierárquicos/rede.

**Nota prática:** o PostgreSQL não oferece isso. O que existe de mais próximo:
- **Particionamento** (`PARTITION BY RANGE/LIST/HASH`) — separa fisicamente por chave, o inverso do arquivo misto, mas resolve o mesmo problema de "co-localizar o que é lido junto".
- **Desnormalização / JSONB embutido** — colocar os filhos dentro da linha do pai. Trade-off real: 1 acesso na leitura vs. perda de integridade referencial e reescrita da linha inteira a cada update do filho.
- Em Prisma, isso é a decisão entre relação `1:N` e campo `Json`.

---

## 3. RAID e armazenamento (Elmasri, cap. 17.10) — o essencial

**Problema:** a capacidade da RAM quadruplica a cada 2–3 anos; o tempo de acesso do disco melhora <10% ao ano. **Solução:** array de discos pequenos atuando como um disco lógico rápido.

**Data striping** distribui os dados por vários discos: em nível de bit (byte partido entre 8 discos → 8× a taxa de transferência) ou em **nível de bloco** (blocos alternados; várias requisições pequenas independentes atendidas em paralelo). Melhora vazão e balanceia carga.

**Confiabilidade:** um array de *n* discos tem `1/n` da confiabilidade de um disco — 100 discos com MTBF de 200.000h → MTBF do array = 2.000h (83 dias). Redundância é obrigatória: **espelhamento** (dobra a taxa de leitura) ou **paridade** / códigos de correção de erro.

Níveis que ainda importam:

| Nível | O que faz | Quando |
|---|---|---|
| 0 | Striping puro, sem redundância | Melhor escrita; zero tolerância a falha. Só para dados descartáveis |
| 1 | Espelhamento | Aplicações críticas — **logs de transação (WAL)**. Reconstrução mais fácil |
| 5 | Striping em bloco + paridade distribuída | Armazenamento em grande volume; penalidade de escrita (read-modify-write) |
| 6 | P+Q (Reed-Solomon) | Tolera 2 falhas com 2 discos redundantes |
| 0+1 / 10 | Striping + espelhamento (mín. 4 discos) | O padrão de facto para banco de dados |

**Nota prática:** hoje o assunto quase sempre é volume gerenciado em nuvem (EBS gp3/io2, Cloud SDN, disco de RDS/Aurora). Regras que sobrevivem: (a) **RAID 5 é ruim para OLTP** — a penalidade de escrita por paridade se soma à write amplification do banco; (b) **RAID 10 ou espelhamento** para dados quentes; (c) **RAID nunca é backup** — não protege contra `DELETE` errado; (d) em nuvem gerenciada, provisionamento de IOPS substitui a escolha de nível.

SAN/NAS (cap. 17.11) são detalhe de infraestrutura, não de projeto de banco.

---

## 4. Índices ordenados de único nível (Elmasri, cap. 18.1)

Um índice é uma **estrutura de acesso auxiliar**: um arquivo adicional que oferece um caminho secundário, sem afetar o posicionamento físico no arquivo de dados. Entradas na forma `<K(i), P(i)>`, ordenadas por `K`, pesquisáveis por busca binária.

### Denso vs. esparso (Elmasri, cap. 18.1.1)

- **Denso:** uma entrada de índice para **cada registro**.
- **Esparso (não denso):** uma entrada para apenas alguns valores — tipicamente uma por bloco, usando o primeiro registro do bloco como **âncora de bloco**.

Índice esparso é menor → busca binária mais rasa. Índice denso é maior, mas **permite decidir se o registro existe sem tocar o arquivo de dados**.

### Os três tipos

| Tipo | Campo | Ordenação física? | Entradas | Densidade | Quantos por arquivo |
|---|---|---|---|---|---|
| **Primário** | Chave (único) | Sim | nº de **blocos** do arquivo | Esparso | No máx. 1 (compartilha o slot com clustering) |
| **Agrupamento (clustering)** | Não chave | Sim | nº de **valores distintos** | Esparso | No máx. 1 |
| **Secundário (chave)** | Chave | Não | nº de **registros** | Denso | Vários |
| **Secundário (não chave)** | Não chave | Não | registros ou valores distintos | Denso ou esparso | Vários |

Um arquivo tem no máximo **um campo de ordenação física** — logo, no máximo um índice primário **ou** um de agrupamento, nunca ambos (Elmasri, cap. 18.1).

### Os números que justificam tudo (Elmasri, cap. 18.1.1, Exemplos 1–2)

Arquivo: `r = 30.000`, `R = 100 B`, `B = 1.024 B` → `bfr = 10`, `b = 3.000` blocos. Chave `V = 9 B`, ponteiro `P = 6 B` → entrada de índice `15 B` → `bfr_i = 68`.

| Estratégia | Acessos de bloco |
|---|---|
| Varredura linear no heap | 1.500 (média) |
| Busca binária no arquivo ordenado | 12 |
| **Índice primário** (esparso, 3.000 entradas → 45 blocos) | `log₂(45)` + 1 = **7** |
| **Índice secundário** (denso, 30.000 entradas → 442 blocos) | `log₂(442)` + 1 = **10** |
| **Índice multinível** (fan-out 68, 3 níveis) | 3 + 1 = **4** |

Leia essa tabela como o argumento central do capítulo 18: o índice secundário é pior que o primário (é denso, logo maior), mas comparado à alternativa real — varredura linear de 1.500 blocos — ele é 150× melhor. **É por isso que índices secundários existem.**

### Índice secundário em campo não chave (Elmasri, cap. 18.1.3)

Três opções para lidar com duplicatas:
1. Entradas duplicadas, uma por registro (índice denso).
2. Entrada de tamanho variável com lista de ponteiros.
3. **A mais usada:** entrada de tamanho fixo, um valor único por entrada, apontando para um **bloco de ponteiros de registro** — um nível extra de indireção. Custa um acesso a mais, mas simplifica inserção e permite resolver condições complexas **intersectando ponteiros sem tocar o arquivo de dados**.

Guarde a opção 3: ela reaparece como bitmap em folha de B+-tree (§7.4) e como Bitmap Index Scan no PostgreSQL.

---

## 5. Índices multiníveis (Elmasri, cap. 18.2)

Busca binária divide o espaço por **2** a cada passo → `log₂(b)`. A ideia multinível: tratar o índice como arquivo ordenado e criar um índice primário **sobre ele**. Cada nível divide o espaço por **fo** (fan-out = `bfr_i`, o fator de bloco do índice).

```
t = ceil( log_fo (r₁) )        níveis
custo de busca = t + 1         acessos de bloco
```

Com `fo = 68` e 442 blocos de primeiro nível: nível 2 = 7 blocos, nível 3 = 1 bloco (topo). `t = 3`, busca = 4 acessos, contra 10 do índice de nível único.

O problema: todos os níveis são arquivos **fisicamente ordenados** → inserção/exclusão continuam caras. É exatamente o que ISAM (IBM) tinha e o que motivou os **índices multiníveis dinâmicos** — deixar espaço livre em cada bloco e criar/remover blocos conforme o arquivo cresce. Isso é a B-tree.

---

## 6. B-tree e B+-tree (Elmasri, cap. 18.3)

### Árvore de pesquisa de ordem *p* (cap. 18.3.1)

Nó: `<P₁, K₁, P₂, K₂, …, P_q>` com `q ≤ p`, `K₁ < K₂ < … < K_{q-1}`, e para todo `X` na subárvore de `P_i`: `K_{i-1} < X < K_i`. Nada garante **balanceamento** — a árvore pode ficar distorcida, com folhas em níveis diferentes, e exclusões deixam nós quase vazios (desperdício + níveis a mais).

Objetivos do balanceamento: profundidade mínima, velocidade de busca uniforme, e pouca reestruturação sob inserção/exclusão.

### B-tree de ordem *p* (cap. 18.3.1)

Nó interno: `<P₁, <K₁,Pr₁>, P₂, <K₂,Pr₂>, …, P_q>`. Cada `P` é ponteiro de árvore, **cada `Pr` é ponteiro de dados**.

Restrições:
1. Cada nó tem no máximo `p` ponteiros de árvore e `p-1` valores de chave.
2. Cada nó exceto raiz e folhas tem pelo menos `ceil(p/2)` ponteiros. A raiz tem pelo menos 2 (a menos que seja o único nó).
3. **Todas as folhas no mesmo nível.**

**Inserção:** nó cheio → divide em dois no mesmo nível; o valor **do meio sobe** para o pai junto com dois ponteiros. Se o pai estiver cheio, propaga; pode chegar à raiz e criar um novo nível. **Exclusão:** nó fica com menos da metade → combina com vizinhos; pode propagar e **reduzir** níveis.

**O número 69%:** após inserções e exclusões aleatórias, os nós estabilizam em ~69% de ocupação. Divisões e combinações passam a ser raras → inserção e exclusão ficam eficientes. Vale para B+ também.

### B+-tree (cap. 18.3.2) — e por que venceu

Diferença única e decisiva: **ponteiros de dados existem apenas nos nós folha**. Nós internos guardam só `<chave, ponteiro de árvore>` e servem exclusivamente para guiar a busca; alguns valores das folhas são **replicados** nos internos. As folhas são **encadeadas** (`P_próximo`), formando uma lista ligada ordenada.

Consequências:

1. **Fan-out maior.** Sem `Pr` nos nós internos, cabem mais entradas por bloco → `p` maior → **menos níveis** → menos acessos de bloco.
2. **Range scan é trivial.** Desce uma vez até a folha e segue a lista ligada. A B-tree exigiria voltar aos nós internos.
3. **Custo de busca uniforme.** Toda chave está numa folha; toda busca custa exatamente a altura da árvore.

Os números do livro (cap. 18.3.2, Exemplos 4–6), com `V=9`, `B=512`, `P=6`, `Pr=7`, nós a 69%:

| | Ordem *p* | Entradas em 3 níveis |
|---|---|---|
| B-tree | 23 | **65.535** |
| B+-tree | 34 (interno), 31 (folha) | **255.507** |

Quase 4× mais entradas na mesma altura. **"Esse é o principal motivo para as B+-trees serem preferidas às B-trees como índices para arquivos de banco de dados."**

Cálculo da ordem (interno): `(p·P) + ((p-1)·V) ≤ B`. Folha: `(p_folha·(Pr+V)) + P ≤ B`.

**Variações:** exigir 2/3 de ocupação em vez de 1/2 → **B\*-tree**. Fator de preenchimento (fill factor) configurável entre 0,5 e 1,0, possivelmente distinto para folhas e internos.

### Nota prática: a B+-tree do PostgreSQL

- É uma **B+-tree Lehman-Yao** (alto grau de concorrência, sem lock da raiz). Página de índice = 8 KB → fan-out de centenas. **3 a 4 níveis cobrem centenas de milhões de linhas** — a altura quase nunca é o problema.
- `fillfactor` default do B-tree é **90** (não 69%). Para índice em coluna sempre-crescente (`id`, `created_at`), `fillfactor=100` é melhor: as inserções vão sempre à direita e não há split no meio.
- **Deduplicação (PG 13+):** chaves duplicadas são armazenadas uma vez com uma lista de TIDs — reduz drasticamente o tamanho de índices em colunas de baixa cardinalidade. Similar em espírito à opção 3 do cap. 18.1.3.
- Ponteiro de dados = **CTID** = `(número_do_bloco, offset)` — literalmente o "ponteiro de registro" do livro (cap. 18.1, nota 8).
- **Índice físico, não lógico** (cap. 18.6.1): PostgreSQL indexa CTID físico. Quando um UPDATE move a linha, todos os índices precisam de nova entrada — daí a importância do HOT (§9).

---

## 7. Índices em múltiplas chaves e outros tipos

### 7.1 Índice ordenado composto (Elmasri, cap. 18.4.1)

Índice sobre `<A₁, A₂, …, A_n>` com chave de pesquisa `<v₁, v₂, …, v_n>`, em **ordenação lexicográfica**: `<3, n>` precede `<4, m>` para quaisquer `n, m`.

O problema que ele resolve (cap. 18.4): `Dnr = 4 AND Idade = 59` com índices separados oferece só três estratégias ruins — usar um índice e filtrar, usar o outro e filtrar, ou intersectar os dois conjuntos. Se cada condição isolada casa com muitos registros mas a combinada com poucos, **nenhuma é eficiente**.

**A regra do leftmost prefix decorre diretamente da ordenação lexicográfica.** Um índice em `(a, b, c)` serve para `(a)`, `(a,b)`, `(a,b,c)` — não para `(b)` ou `(b,c)`, porque os valores de `b` não estão globalmente ordenados; estão ordenados apenas *dentro* de cada valor de `a`.

**Nota prática:** o PostgreSQL *consegue* usar um índice `(a,b,c)` para um predicado só em `b` — mas via **full index scan** com filtro, não via descida na árvore. Aparece no `EXPLAIN` como Index Scan com `Filter:` em vez de `Index Cond:`. Só é vantajoso quando o índice é muito menor que a tabela. Não conte com isso.

Ordem das colunas — critério de decisão, nesta ordem:

1. **Colunas de igualdade antes de colunas de range.** Após a primeira condição de range, as colunas seguintes deixam de restringir a descida na árvore.
2. **Entre igualdades, a mais seletiva primeiro** — reduz o número de páginas de índice tocadas (efeito secundário; a diferença costuma ser pequena).
3. **Coluna do `ORDER BY` na ordem certa**, para evitar o nó de Sort.

```sql
-- "transações de uma conta num período, mais recentes primeiro"
-- SELECT * FROM transacoes
--  WHERE conta_id = $1 AND ocorrida_em >= $2 AND ocorrida_em < $3
--  ORDER BY ocorrida_em DESC;

CREATE INDEX idx_transacoes_conta_data
  ON transacoes (conta_id, ocorrida_em DESC);
-- conta_id (igualdade) antes de ocorrida_em (range) — e o DESC mata o Sort.
```

Inverter para `(ocorrida_em, conta_id)` quebraria as duas regras: o range em `ocorrida_em` viria primeiro, tornando `conta_id` inútil para a descida.

### 7.2 Hashing particionado (Elmasri, cap. 18.4.2)

Extensão do hashing estático: para chave de *n* componentes, a função gera *n* endereços que são **concatenados**. `Dnr=4 → '100'` (3 bits) e `Idade=59 → '10101'` (5 bits) → bucket `10010101`. Buscar só por `Idade=59` exige varrer os 8 buckets `xxx10101`.

- Vantagem: estende para qualquer número de atributos; sem estruturas de acesso separadas; bits de ordem alta podem ser dados aos atributos mais acessados.
- Desvantagem fatal: **não trata range query em nenhum componente**.

**Nota prática:** o que sobrevive disso é o `PARTITION BY HASH` do PostgreSQL — mesma ideia, mesma limitação (só igualdade poda partições).

### 7.3 Arquivos de grade (Elmasri, cap. 18.4.3)

Vetor *n*-dimensional com uma **escala linear** por atributo, construída para distribuir os valores uniformemente. Cada célula aponta para um bucket. `Dnr=4, Idade=59` → célula `(1,5)`.

- Bom para **range em múltiplos atributos**: `Dnr < 5 AND Idade > 40` mapeia para um retângulo de células e acessa exatamente os buckets correspondentes.
- Custo: overhead de espaço do vetor + reorganização frequente em arquivos dinâmicos.

**Nota prática:** os descendentes vivos são **GiST** e **SP-GiST** no PostgreSQL — indexação multidimensional para tipos geométricos, `tsrange`/`daterange`, `inet`, kNN. A intuição de particionar o espaço em células continua idêntica.

### 7.4 Índices de hash (Elmasri, cap. 18.5.1)

Estrutura secundária: entradas `<K, Pr>` num arquivo de hash dinamicamente expansível. Busca por hash em `K`, depois segue `Pr`.

### 7.5 Índices bitmap (Elmasri, cap. 18.5.2)

Para a coluna `C` e valor `V` numa relação de `n` linhas: um vetor de `n` bits; bit `i` = 1 se a linha `i` tem `C = V`. Coluna com `m` valores distintos → `m` bitmaps.

Operações:
- `C₁ = V₁` → retorna direto os Row_ids.
- `C₁ = V₁ AND C₂ = V₂` → **AND lógico** dos dois bitmaps. Generaliza para *k* condições, e para AND-OR complexos.
- `COUNT(*)` → conta os bits '1'.
- `C₁ <> V₁` → complemento booleano.

**Espaço:** 1 milhão de linhas × 100 B = arquivo de 100 MB. Cada bitmap = 1 Mbit = 125 KB. 200 bitmaps de CEP = 25 MB = **25% do arquivo de dados**. Vetores grandes são processados em palavras de 32/64 bits com instruções AND/OR/NOT nativas — computacionalmente muito eficiente.

**Quando NÃO usar:** coluna com poucos valores distintos e distribuição uniforme, tipo `Sexo` — `Sexo = 'M'` recupera 50% das linhas. **"Nesses casos, é melhor realizar uma varredura completa."** O índice não é o gargalo; o acesso ao heap é.

**Custo de escrita:** cada INSERT exige entrada em **todos** os bitmaps de todas as colunas indexadas. Exclusão exige renumerar linhas e deslocar bits — evitado com um **bitmap de existência** (0 = excluída mas ainda presente, 1 = existe).

**Bitmap em folha de B+-tree:** para um valor que ocorre em 10% das linhas, a lista de ponteiros custa `4 · n/10 = 0,4n` bytes; o bitmap custa `n/8 = 0,125n` bytes. Ponto de equilíbrio: **1/32**. Acima dessa frequência, armazenar bitmap em vez de ponteiros de registro compacta o índice.

**Nota prática — atenção, isto confunde muita gente:** o PostgreSQL **não tem índice bitmap persistente** (isso é Oracle). O que ele tem é o **Bitmap Index Scan**: um bitmap construído *em memória, na hora da query*, a partir de um índice B-tree qualquer. É o mecanismo que aparece no plano quando o número de linhas é grande demais para Index Scan (muitos acessos aleatórios) e pequeno demais para Seq Scan:

```
Bitmap Heap Scan on transacoes
  Recheck Cond: ...
  ->  BitmapAnd
        ->  Bitmap Index Scan on idx_transacoes_categoria
        ->  Bitmap Index Scan on idx_transacoes_conta
```

`BitmapAnd`/`BitmapOr` são exatamente a interseção de bitmaps do livro (e a intersecção de ponteiros da opção 3, cap. 18.1.3) — só que efêmeros. Vantagem: o heap é lido **em ordem física de bloco**, transformando acesso aleatório em quase-sequencial. É a razão pela qual índices de coluna única separados às vezes bastam. `Recheck Cond` aparece quando o bitmap perde precisão (vira "lossy", por página em vez de por tupla) por falta de `work_mem`.

### 7.6 Indexação baseada em função (Elmasri, cap. 18.5.3)

A chave do índice é o **resultado de uma função** sobre um ou mais campos.

```sql
CREATE INDEX idx_maiusc ON funcionario (UPPER(unome));
-- Sem isso, WHERE UPPER(unome) = 'SILVA' faz varredura completa:
-- "um índice de B+-tree só é pesquisado pelo uso direto do valor da coluna;
--  o uso de qualquer função em uma coluna impede que tal índice seja utilizado."
```

Também funciona sobre expressões (`salario + salario*pct_comissao`) e — o uso mais engenhoso — para **exclusividade condicional**, via `CASE` que mapeia para NULL as linhas que devem ficar fora do índice (o SGBD não armazena entradas com todas as chaves NULL).

**Nota prática:** no PostgreSQL o mesmo caso se resolve de forma direta com **índice parcial** (§8.2), que é mais claro e menor. A função de um índice de expressão precisa ser `IMMUTABLE` — `now()` ou `to_char(x, 'TZ')` não servem. Rode `ANALYZE` após criar: só então o planner coleta estatísticas *da expressão*.

### 7.7 Índices lógicos vs. físicos (Elmasri, cap. 18.6.1)

**Físico:** `<K, Pr>` com `Pr` = endereço físico (bloco + deslocamento). Problema: se o registro se move — e ele se move, p.ex. quando um bucket de hashing linear/extensível se divide — todos os ponteiros nos índices secundários precisam ser encontrados e atualizados.

**Lógico:** `<K, K_p>`, onde `K_p` é a chave da organização primária. Pesquisa o índice secundário, obtém `K_p`, e acessa via organização primária. Custo: uma pesquisa extra. Usado quando endereços físicos mudam com frequência.

**Nota prática:** este é exatamente o eixo PostgreSQL vs. MySQL/InnoDB. PostgreSQL usa índices **físicos** (CTID). InnoDB usa índices **lógicos**: todo índice secundário aponta para a **chave primária**, não para o endereço — por isso `SELECT ... WHERE email = ?` no InnoDB faz duas descidas de árvore (índice secundário → PK clusterizada), e por isso PKs grandes envenenam todos os índices secundários no InnoDB. O trade-off do livro, literal, em produção.

### 7.8 Arquivo totalmente invertido (Elmasri, cap. 18.6.2)

Arquivo com índice secundário em **cada** campo. Como todos são secundários, o arquivo de dados é um heap. É, com outro nome, a arquitetura padrão de uma tabela PostgreSQL bem indexada.

### 7.9 Armazenamento por coluna (Elmasri, cap. 18.6.3)

Particionamento vertical + índices por coluna + compressão (dicionário, run-length, supressão de NULL). Vantagem em **data warehouse** (somente leitura). Bancos linha-a-linha são otimizados para escrita.

**Nota prática:** relevante se o app de finanças ganhar analytics pesado. Opções: extensão `citus_columnar`, DuckDB, ClickHouse, ou um data warehouse separado. Não force o PostgreSQL OLTP a ser OLAP.

---

## 8. Seletividade: decidir se o índice vai ser usado

### A fórmula (Elmasri, cap. 19.8.2)

```
d  = número de valores distintos do atributo
sl = seletividade = fração de registros que satisfazem uma condição de igualdade
s  = cardinalidade de seleção = sl · r     (nº médio de registros retornados)

Atributo chave:      d = r,  sl = 1/r,   s = 1
Atributo não chave:  sl = 1/d,           s = r/d     (assume distribuição uniforme)
```

A hipótese de uniformidade quebra na vida real. Com 200 funcionários em 5 departamentos distribuídos `(1,5) (2,25) (3,70) (4,40) (5,60)`, a seletividade real por valor é `(1: 0,025) (2: 0,125) (3: 0,35) (4: 0,2) (5: 0,3)` — nada perto de `1/5 = 0,2`. Por isso otimizadores guardam **histogramas** da distribuição (Elmasri, cap. 19.8.2, nota 20).

E o critério de decisão vem do cap. 18.5.2: se a condição recupera **50% das linhas**, a varredura completa ganha. Índice paga quando `sl` é baixa.

### Nota prática: como fazer isso no PostgreSQL

```sql
-- 1. Seletividade real, medida
SELECT count(DISTINCT categoria_id) AS d,
       count(*)                     AS r,
       count(*)::float / count(DISTINCT categoria_id) AS s_medio
FROM transacoes;

-- 2. O que o planner acredita
SELECT attname, n_distinct, null_frac, correlation,
       most_common_vals, most_common_freqs
FROM pg_stats
WHERE tablename = 'transacoes' AND attname = 'categoria_id';
```

Leitura de `pg_stats`:
- **`n_distinct`** positivo = contagem absoluta; **negativo** = fração de `r` (`-1` = todos únicos, ou seja, chave). Se está muito errado: `ALTER TABLE ... ALTER COLUMN ... SET STATISTICS 1000; ANALYZE;`
- **`most_common_vals`/`most_common_freqs`** = o histograma do livro. É o que permite ao planner escolher Seq Scan para `categoria_id = <valor comum>` e Index Scan para `= <valor raro>` — **com o mesmo índice, na mesma query**. Não é bug; é a decisão certa.
- **`correlation`** próximo de ±1 = ordem lógica ≈ ordem física. É a "ordenação física" do livro, medida. **Só com correlação alta o BRIN funciona.**
- Colunas correlacionadas (`conta_id` e `moeda`) quebram a estimativa, que assume independência: `CREATE STATISTICS ... (dependencies, ndistinct) ON conta_id, moeda FROM transacoes;`

Regras de bolso (PostgreSQL, SSD):

| Seletividade estimada | Plano provável |
|---|---|
| < ~1% | Index Scan |
| ~1% a ~10% | Bitmap Heap Scan |
| > ~10–20% | Seq Scan (e está certo) |

Se o índice existe e não é usado, verifique **nesta ordem**: (1) `ANALYZE` foi rodado? (2) a coluna do predicado é o leftmost prefix? (3) há função/cast implícito sobre a coluna? (4) tipos batem (`bigint` vs `int`)? (5) `random_page_cost` está calibrado para SSD? (6) a seletividade é realmente baixa? (7) a tabela é pequena o suficiente para o Seq Scan ganhar de fato?

**Sempre confirme com `EXPLAIN (ANALYZE, BUFFERS)`**, e compare `rows=` estimado com `actual rows=`. Divergência de ordem de grandeza = problema de estatística, não de índice.

---

## 9. PostgreSQL: o mapa completo

### 9.1 Tipos de índice — quando cada um serve

| Tipo | Estrutura (livro) | Operadores | Use quando |
|---|---|---|---|
| **B-tree** | B+-tree (cap. 18.3.2) | `= < <= > >= BETWEEN IN`, `LIKE 'x%'`, `IS NULL`, `ORDER BY` | Default. 95% dos casos |
| **Hash** | Hash index (cap. 18.5.1) | `=` apenas | Chave grande, só igualdade. Raramente vale |
| **GiST** | Árvore de pesquisa balanceada genérica / grid (cap. 18.4.3) | Contenção, sobreposição, kNN | `tsrange`, `daterange`, PostGIS, exclusion constraint |
| **SP-GiST** | Árvore de partição de espaço | Prefixo, quadtree, k-d tree | `inet`, `text` com prefixos, pontos |
| **GIN** | Arquivo invertido (cap. 18.6.2) | `@>`, `?`, `@@` | `jsonb`, arrays, full-text |
| **BRIN** | Âncora de bloco (cap. 18.1.1) levada ao extremo | `= < >` em coluna correlacionada | Tabela enorme append-only, alta `correlation` |

**Hash (Nota prática):** WAL-logged e crash-safe desde o PG 10 — o motivo histórico para evitá-lo caiu. Ainda assim: não suporta range, `ORDER BY`, unicidade, nem `INCLUDE`. Só ganha do B-tree quando a chave é grande (o hash é de tamanho fixo). Na dúvida, B-tree.

**BRIN (Nota prática):** guarda min/max por faixa de blocos (`pages_per_range`, default 128). Tamanho ridículo — megabytes onde o B-tree gastaria gigabytes. **Depende inteiramente da correlação física** (`pg_stats.correlation` > 0,9). É o índice esparso/âncora de bloco do cap. 18.1.1 aplicado direto ao heap.

```sql
-- Tabela de transações de 500M linhas, append-only por data.
CREATE INDEX idx_transacoes_brin ON transacoes
  USING brin (ocorrida_em) WITH (pages_per_range = 64);
-- Se INSERTs vierem fora de ordem, a correlação cai e o BRIN vira inútil.
```

### 9.2 Índice parcial

Indexa só o subconjunto que interessa. **É a arma mais subestimada do PostgreSQL.**

```sql
-- 98% das transações estão conciliadas; só as pendentes são consultadas.
CREATE INDEX idx_transacoes_pendentes
  ON transacoes (conta_id, ocorrida_em)
  WHERE status = 'PENDENTE';
```

Ganhos: índice ~50× menor, cabe na cache, **e não é atualizado quando a linha vira conciliada e sai do predicado**. O predicado da query precisa ser provado implicado pelo `WHERE` do índice — na prática, repita a condição literalmente.

Também resolve a exclusividade condicional do cap. 18.5.3, Exemplo 3, sem o truque do `CASE`:

```sql
CREATE UNIQUE INDEX uq_conta_padrao
  ON contas (usuario_id) WHERE eh_padrao;
-- Uma única conta padrão por usuário; não restringe as demais.
```

### 9.3 Índice de expressão

```sql
CREATE INDEX idx_transacoes_mes
  ON transacoes (date_trunc('month', ocorrida_em));
-- Serve: WHERE date_trunc('month', ocorrida_em) = '2026-07-01'
-- Alternativa quase sempre melhor: índice comum em ocorrida_em + range
--   WHERE ocorrida_em >= '2026-07-01' AND ocorrida_em < '2026-08-01'
-- Um range sargable dispensa o índice de expressão. Prefira reescrever a query.
```

Use índice de expressão quando **não dá** para reescrever: `lower(email)`, `(dados->>'externo_id')`, `(valor_centavos * taxa)`.

### 9.4 Covering index / INCLUDE / index-only scan

```sql
-- SELECT ocorrida_em, valor_centavos FROM transacoes
--  WHERE conta_id = $1 AND ocorrida_em >= $2;

CREATE INDEX idx_transacoes_cobertura
  ON transacoes (conta_id, ocorrida_em)
  INCLUDE (valor_centavos);
```

Colunas em `INCLUDE` ficam **apenas nas folhas**, não nos nós internos — logo **não aumentam a chave, não reduzem o fan-out, não afetam a altura**. Isso é a distinção B-tree vs. B+-tree do cap. 18.3.2 usada deliberadamente: dados só na folha.

Diferença vs. colocar a coluna na chave: `INCLUDE` não serve para busca nem `ORDER BY`, e não participa da unicidade — o que é justamente o que permite `UNIQUE (a) INCLUDE (b)`.

**Index-Only Scan tem uma pegadinha grande:** o índice do PostgreSQL **não guarda informação de visibilidade MVCC**. Para pular o heap, o planner consulta o **visibility map**; se a página não está marcada como all-visible, ele volta ao heap assim mesmo. `EXPLAIN (ANALYZE)` denuncia:

```
Index Only Scan using idx_transacoes_cobertura on transacoes
  Heap Fetches: 48213      <-- alto = VACUUM atrasado; o index-only não está acontecendo
```

`Heap Fetches` alto → `VACUUM (ANALYZE) transacoes;` e considere autovacuum mais agressivo nessa tabela. Suporte a `INCLUDE`: B-tree (PG 11+), GiST e SP-GiST (PG 14+). Hash, GIN e BRIN: não.

### 9.5 O custo de escrita de cada índice

Aqui está o trade-off que o livro enuncia (cap. 18.5.2: "Sempre que uma linha for inserida na relação, uma entrada precisa ser criada em todos os bitmaps... Esse processo representa um overhead de indexação") e que na prática se paga em quatro moedas:

1. **Escrita amplificada.** Todo INSERT/DELETE toca **todos** os índices. 6 índices = 7 escritas de página por linha.
2. **WAL.** Cada modificação de índice gera WAL → mais I/O, replicação mais lenta, backups maiores.
3. **HOT bloqueado.** Um UPDATE que **não altera nenhuma coluna indexada** e cabe na mesma página faz *Heap-Only Tuple update*: nenhum índice é tocado. Se você indexar `atualizado_em`, **todo** UPDATE deixa de ser HOT. Isso costuma ser o pior índice do sistema.
4. **Page splits e bloat.** Inserção em índice não sequencial (ex.: UUIDv4) espalha splits pela árvore toda. **UUIDv7 / ULID** (ordenado no tempo) preserva o padrão append-only e reduz drasticamente o split — decisão relevante se a PK do projeto for UUID.

| Índice | Custo de leitura | Custo de escrita |
|---|---|---|
| B-tree | Baixo | Moderado; alto se a chave for aleatória |
| B-tree parcial | Baixo | **Baixo** — só escreve se a linha casa o predicado |
| GIN | Baixo | **Alto** — muitas entradas por linha. Mitigue com `fastupdate` |
| BRIN | Moderado | **Quase zero** |
| Hash | Baixo | Moderado |

Regras operacionais:
- `CREATE INDEX CONCURRENTLY` / `DROP INDEX CONCURRENTLY` sempre em produção. Sem isso, você trava escrita na tabela.
- Índices não usados são puro custo: `SELECT relname, indexrelname, idx_scan FROM pg_stat_user_indexes WHERE idx_scan = 0;` (mas cheque o uptime antes de derrubar).
- Índices redundantes: `(a)` é inútil se `(a,b)` existe. `(b,a)` **não** é redundante com `(a,b)`.
- Bloat: `REINDEX CONCURRENTLY` (PG 12+).

### 9.6 Nota prática: Prisma

O Prisma cobre só o básico. O resto vai em migration SQL crua.

```prisma
model Transacao {
  id            String   @id @default(uuid(7))
  contaId       String
  categoriaId   String?
  valorCentavos BigInt
  status        Status
  ocorridaEm    DateTime

  @@index([contaId, ocorridaEm(sort: Desc)])   // composto + ordem: OK
  @@unique([contaId, idExterno])                // unique composto: OK
}
```

Índice parcial, `INCLUDE`, expressão, GIN, GiST e BRIN não têm sintaxe no schema — escreva na migration:

```sql
CREATE INDEX CONCURRENTLY idx_transacoes_pendentes
  ON "Transacao" ("contaId", "ocorridaEm") WHERE status = 'PENDENTE';

CREATE INDEX CONCURRENTLY idx_transacoes_cobertura
  ON "Transacao" ("contaId", "ocorridaEm") INCLUDE ("valorCentavos");

CREATE INDEX CONCURRENTLY idx_transacoes_brin
  ON "Transacao" USING brin ("ocorridaEm");
```

Cuidados: o Prisma **não detecta drift** dessas migrations manuais — documente-as. `prisma migrate dev` não usa `CONCURRENTLY` nos índices que ele gera; para tabelas grandes em produção, escreva a migration na mão. E `@default(uuid(7))` no lugar de `uuid(4)` pelo motivo do §9.5.

---

## 10. Tabela de decisão: sintoma → índice candidato → o que custa

| Sintoma | Candidato | O que custa |
|---|---|---|
| `WHERE conta_id = ?` | B-tree em `(conta_id)` | Escrita em todo INSERT/DELETE; page split se `conta_id` for aleatório |
| `WHERE conta_id = ? AND ocorrida_em BETWEEN ? AND ?` | B-tree em `(conta_id, ocorrida_em)` — igualdade antes do range | Índice maior; substitui e torna redundante o de `(conta_id)` |
| Mesma query, mas `ORDER BY ocorrida_em DESC LIMIT 50` | `(conta_id, ocorrida_em DESC)` | Nada além do acima; elimina o nó de Sort |
| Query retorna 2–3 colunas de uma tabela larga | Adicionar `INCLUDE (col)` | Índice maior; **exige VACUUM em dia** ou `Heap Fetches` mata o ganho |
| Query só toca 2% das linhas (`status='PENDENTE'`) | Índice **parcial** com `WHERE status='PENDENTE'` | Nada. Menor e mais barato de escrever. O predicado precisa casar |
| `WHERE lower(email) = ?` | Índice de **expressão** | Função precisa ser `IMMUTABLE`; `ANALYZE` obrigatório após criar |
| `WHERE date_trunc('month', d) = ?` | **Reescreva para range** e use B-tree em `(d)` | Zero. Um índice de expressão aqui seria desperdício |
| Duas colunas de média cardinalidade, combinações variadas | Dois índices de coluna única (deixe o `BitmapAnd` combinar) | 2× escrita; menos eficiente que o composto se a combinação for fixa |
| `WHERE dados @> '{"tag":"x"}'` (jsonb) | **GIN** | **Escrita cara.** Mitigue com `fastupdate=on` e `gin_pending_list_limit` |
| Full-text em descrição da transação | **GIN** em `to_tsvector(...)` | Idem GIN + custo de CPU na indexação |
| `WHERE periodo && tsrange(?, ?)` | **GiST** | Escrita moderada; também habilita `EXCLUDE` constraint |
| Range em tabela append-only de 500M linhas | **BRIN** | Quase nada — **mas morre se a `correlation` cair** |
| "Só uma conta padrão por usuário" | `UNIQUE ... WHERE eh_padrao` | Nada. Resolve o cap. 18.5.3 Ex. 3 sem o truque do CASE |
| `= ` em chave longa, sem range nem ordenação | **Hash** | Sem range, sem `ORDER BY`, sem unique, sem `INCLUDE`. Quase sempre B-tree ganha |
| Coluna com 2–3 valores, distribuição uniforme | **Nenhum** | Seq Scan ganha (cap. 18.5.2). Índice = custo puro |
| Tabela com < ~1.000 linhas | **Nenhum** (só a PK) | Cabe na cache; Seq Scan sempre ganha |
| Índice existe e não é usado | Não é índice novo — investigue | Rode o checklist do §8: ANALYZE, prefix, função, tipo, `random_page_cost` |
| Muitos UPDATEs, escrita lenta | **Remova índices** | Cheque `idx_scan = 0` e índice em `atualizado_em`, que mata o HOT |

---

## 11. Checklist de decisão

Antes de criar um índice, responda:

1. **Qual query, exatamente?** Sem query concreta não há índice. `EXPLAIN (ANALYZE, BUFFERS)` primeiro.
2. **Qual é a seletividade real?** `count(DISTINCT) / count(*)`, e olhe `most_common_freqs`. Acima de ~10% de linhas retornadas, o índice não vai ser usado — e está certo.
3. **Já existe um índice cujo leftmost prefix cobre isto?** Estenda em vez de criar outro.
4. **Igualdades antes de ranges, e o `ORDER BY` na ordem certa?**
5. **Um índice parcial resolve?** Quase sempre é a opção mais barata.
6. **Quantas escritas por segundo esta tabela recebe?** Multiplique pelo número de índices.
7. **Este índice bloqueia HOT updates?** (Ele indexa uma coluna que muda com frequência?)
8. **Como vou saber se ele está sendo usado?** `pg_stat_user_indexes.idx_scan`, revisado em 30 dias.
9. **`CREATE INDEX CONCURRENTLY`?** Sim. Sempre, em produção.

E o princípio-guia, que atravessa os dois capítulos sem mudar: **o objetivo é sempre reduzir o número de blocos transferidos.** Um índice que não reduz blocos é só custo de escrita disfarçado de otimização.
