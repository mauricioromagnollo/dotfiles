# Consultas e otimização: da álgebra relacional ao EXPLAIN do PostgreSQL

Abra esta referência quando precisar decidir por que uma consulta está lenta, se um índice vale a pena, se uma junção está sendo executada do jeito errado, ou quando um `EXPLAIN` mostra algo que você não sabe interpretar. O fio condutor é: **o otimizador pensa em álgebra relacional, escolhe algoritmos por custo estimado, e o custo estimado depende de estatísticas**. Quase todo problema de performance de consulta é um destes três elos quebrado.

Domínio dos exemplos: finanças pessoais — `contas`, `transacoes`, `categorias`.

```sql
-- Esquema de referência usado por todos os exemplos
CREATE TABLE contas (
  id            bigint PRIMARY KEY,
  usuario_id    bigint NOT NULL,
  nome          text   NOT NULL,
  saldo_cents   bigint NOT NULL DEFAULT 0
);

CREATE TABLE categorias (
  id         bigint PRIMARY KEY,
  usuario_id bigint NOT NULL,
  nome       text   NOT NULL
);

CREATE TABLE transacoes (
  id           bigint PRIMARY KEY,
  conta_id     bigint NOT NULL REFERENCES contas(id),
  categoria_id bigint     NULL REFERENCES categorias(id),
  valor_cents  bigint NOT NULL,
  ocorrida_em  timestamptz NOT NULL,
  descricao    text
);
-- ~10M linhas em transacoes, ~50k contas, ~200 categorias.
```

---

## 1. Álgebra relacional: a linguagem em que o plano é escrito

Todo nó de um plano de execução é um operador algébrico com um algoritmo escolhido. Saber ler o plano é saber mapear nó → operador.

| Operação | Notação | O que faz | Nó típico no PostgreSQL |
|---|---|---|---|
| SELEÇÃO | σ_cond(R) | Filtra **linhas** que satisfazem a condição | `Filter`, `Index Cond`, `Recheck Cond` |
| PROJEÇÃO | π_lista(R) | Escolhe **colunas**, elimina duplicatas | lista de `Output`, `Result` |
| RENOMEAR | ρ_S(R) | Renomeia relação/atributos | `AS` / alias |
| JUNÇÃO THETA | R ⋈_cond S | Combina pares que satisfazem uma condição qualquer | `Nested Loop`, `Hash Join`, `Merge Join` |
| EQUIJUNÇÃO | R ⋈_{A=B} S | Junção só com `=` | idem |
| JUNÇÃO NATURAL | R * S | Equijunção nos atributos homônimos, sem duplicar a coluna | idem |
| PRODUTO CARTESIANO | R × S | Todas as combinações | `Nested Loop` sem `Join Filter` |
| UNIÃO / INTERSEÇÃO / DIFERENÇA | ∪, ∩, − | Operações de conjunto sobre relações compatíveis na união | `Append`+`HashAggregate`, `HashSetOp`, `SetOp` |
| DIVISÃO | R ÷ S | "os que se relacionam com **todos** de S" | não existe nó; vira `NOT EXISTS` duplo |
| AGREGAÇÃO | _{attrs}ℱ_{func}(R) | Agrupa e resume | `HashAggregate`, `GroupAggregate` |
| JUNÇÃO EXTERNA | ⟕ ⟖ ⟗ | Junção que preserva linhas sem par, preenchendo com NULL | `Left Join`, `Full Join` no mesmo nó de junção |

Pontos que importam para decidir:

- **Seleção é comutativa e cascateável**: `σ_c1(σ_c2(R)) = σ_{c1 AND c2}(R)` e a ordem entre elas é livre (Elmasri, cap. 6.1.1). É isso que permite ao otimizador quebrar um `WHERE` conjuntivo e empurrar cada pedaço para onde quiser.
- **Projeção não é comutativa** e elimina duplicatas por definição na álgebra formal. SQL só elimina com `DISTINCT` (Elmasri, cap. 6.1.2). Eliminar duplicata custa ordenação ou hash — não é de graça.
- **Junção = produto cartesiano + seleção** (Elmasri, cap. 6.3.3). O conjunto {σ, π, ∪, ρ, −, ×} é completo; junção, interseção e divisão existem por conveniência. Isso é a base de toda a otimização: se junção é `σ(R × S)`, o otimizador pode reescrever nos dois sentidos.
- **Seletividade de junção (js)** = |R ⋈ S| / (|R| × |S|) (Elmasri, cap. 19.8.4). Se `A` é chave de `R`, então js ≤ 1/|R| — o resultado tem no máximo |S| linhas. Numa FK `NOT NULL` apontando para a PK, js = 1/|R| exatamente e o resultado tem |S| linhas. É por isso que junção por FK é previsível e junção sem chave dos dois lados explode.
- **Junção externa perde a comutatividade da junção interna**. `A LEFT JOIN B` ≠ `B LEFT JOIN A`. Isso restringe o espaço de reordenação do otimizador — uma razão prática para preferir `INNER JOIN` quando a semântica permite.
- **Divisão** ("contas que têm transação em *todas* as categorias do usuário") não tem operador em SQL. Expressa-se com `NOT EXISTS` aninhado ou com `COUNT(DISTINCT ...) = (SELECT COUNT(*) ...)`. É a leitura algébrica do quantificador universal (Elmasri, cap. 6.3.4).

### Árvore de consulta

A árvore de consulta é a representação interna: folhas = relações base, nós internos = operações; a execução vai das folhas à raiz (Elmasri, cap. 6.3.5). É literalmente o que o `EXPLAIN` imprime, invertido: no PostgreSQL a raiz aparece em cima e as folhas indentadas embaixo.

---

## 2. De SQL para álgebra: blocos de consulta

O SQL é traduzido para álgebra relacional estendida antes de otimizar. A unidade é o **bloco de consulta**: um `SELECT-FROM-WHERE` com seus `GROUP BY`/`HAVING`. Cada subconsulta aninhada é um bloco separado (Elmasri, cap. 19.1).

```sql
SELECT c.nome
FROM contas c
WHERE c.saldo_cents > (SELECT MAX(saldo_cents) FROM contas WHERE usuario_id = 42);
```

Dois blocos. O interno vira `ℱ_MAX(saldo_cents)(σ_{usuario_id=42}(contas))`, é avaliado **uma vez**, e o resultado entra no bloco externo como constante `c`. Essa é a subconsulta **não correlacionada** — barata e previsível.

A subconsulta **correlacionada**, em que uma variável do bloco externo aparece no `WHERE` do interno, é muito mais difícil de otimizar (Elmasri, cap. 19.1) porque o bloco interno tem que ser reavaliado por linha externa — a menos que o otimizador consiga *descorrelacionar* (transformar em junção/semi-junção).

**Critério de decisão:** se você escreveu uma subconsulta correlacionada num caminho quente, verifique no plano se ela virou `Hash Semi Join`/`Hash Join`. Se aparecer `SubPlan` com `loops=N` alto, ela não foi descorrelacionada — reescreva como junção explícita ou como CTE agregada.

Elmasri (cap. 20.2.3, item 5) dá exatamente esse padrão: a consulta "funcionário com maior salário em cada departamento" via correlação varre a tabela interna inteira por linha externa; quebrar em duas etapas (agregação materializada + junção) resolve. O equivalente no nosso domínio:

```sql
-- Ruim: correlacionada, potencialmente O(n²)
SELECT t.id FROM transacoes t
WHERE t.valor_cents = (SELECT MAX(valor_cents) FROM transacoes m WHERE m.conta_id = t.conta_id);

-- Melhor: agrega uma vez, junta uma vez
WITH maiores AS (
  SELECT conta_id, MAX(valor_cents) AS valor_cents
  FROM transacoes GROUP BY conta_id
)
SELECT t.id FROM transacoes t
JOIN maiores m ON m.conta_id = t.conta_id AND m.valor_cents = t.valor_cents;
```

---

## 3. Ordenação externa (external merge sort)

Ordenação aparece em `ORDER BY`, em sort-merge join, em `DISTINCT`, em `GROUP BY` por agrupamento, e em operações de conjunto (Elmasri, cap. 19.2). Quando o arquivo não cabe na memória, usa-se sort-merge externo, em duas fases:

1. **Fase de ordenação**: lê pedaços de `n_B` blocos, ordena em memória, grava de volta. Gera `n_R = ⌈b / n_B⌉` pedaços ordenados.
2. **Fase de intercalação**: intercala `d_M = min(n_B − 1, n_R)` pedaços por etapa, repetindo por `⌈log_{d_M}(n_R)⌉` passadas.

**Custo total (em acessos a bloco):**

```
(2 × b) + (2 × b × ⌈log_{d_M}(n_R)⌉)
```

O primeiro termo é a fase de ordenação (cada bloco lido e gravado uma vez). O segundo é a intercalação (cada passada lê e grava ~b blocos). Pior caso, com o mínimo de `n_B = 3` buffers: `(2 × b) + (2 × b × log_2 n_R)`.

**A leitura de decisão:** o custo é dominado pelo **número de passadas**, que é logarítmico na razão entre tamanho do arquivo e memória disponível. Dobrar a memória não corta o custo pela metade — corta uma passada inteira quando cruza um limiar. É por isso que `work_mem` tem efeito em degrau, não linear.

> **Nota prática:** no PostgreSQL isso é o nó `Sort`. Com `EXPLAIN (ANALYZE, BUFFERS)` você vê `Sort Method: quicksort Memory: 25kB` (coube) ou `Sort Method: external merge Disk: 82304kB` (não coube — foi para o disco). `external merge` num caminho quente é sinal para aumentar `work_mem` **na sessão/consulta**, não globalmente: `work_mem` é por nó de ordenação por conexão, e uma consulta com 5 sorts e 20 conexões multiplica. Alternativa melhor: um índice na ordem certa elimina o `Sort` inteiramente — Elmasri (cap. 19.2) já nota que a ordenação pode ser evitada se existir índice apropriado no atributo desejado.

---

## 4. Algoritmos de seleção

Elmasri (cap. 19.3.1) cataloga os métodos e (cap. 19.8.3) os custos:

| Método | Quando se aplica | Custo aproximado |
|---|---|---|
| S1 Busca linear | sempre | `b` (ou `b/2` em média se `=` em chave) |
| S2 Busca binária | arquivo ordenado pelo atributo | `log₂ b + ⌈s/bfr⌉ − 1` |
| S3a Índice primário, `=` em chave | 1 registro | `x + 1` |
| S3b Chave hash, `=` em chave | 1 registro | ~1 |
| S4 Índice de ordenação, `>` `>=` `<` `<=` em chave | range | `x + b/2` |
| S5 Índice de agrupamento (clustering), `=` em não chave | s registros contíguos | `x + ⌈s/bfr⌉` |
| S6 Índice secundário (B-tree), `=` | 1 ou s registros | chave: `x+1`; não chave: `x + 1 + s` |
| S7 Conjuntiva com um índice | AND, um atributo indexado | custo do método escolhido + recheck em memória |
| S8 Conjuntiva com índice composto | AND com `=` em várias colunas | como S3a/S5/S6 |
| S9 Conjuntiva por interseção de ponteiros | vários índices secundários com RIDs | soma das buscas + interseção em memória |

`x` = número de níveis do índice. Note o **caso patológico de S6 em atributo não chave**: `x + 1 + s`, onde `s` é a cardinalidade de seleção. Cada um dos `s` registros pode estar num bloco diferente. Se `s` for grande, o índice secundário é **pior** que a varredura linear.

O exemplo numérico de Elmasri (cap. 19.8.3) merece ser internalizado: `FUNCIONÁRIO` com r=10.000 em b=2.000 blocos.

- `σ_{Dnr=5}`: índice secundário custa `2 + 80 = 82` → ganha da varredura (2.000).
- `σ_{Sexo='F'}`: s = 5.000 → índice custa `1 + 5.000 = 5.001` → **perde** feio da varredura (2.000).
- `σ_{Cpf>...}` com índice secundário em range: `x + bI1/2 + r/2 = 5.004` → perde da varredura (2.000).

**Regra de decisão que sai daí:** índice em coluna de baixa cardinalidade, sem clustering, para uma condição pouco seletiva, é pior que não ter índice. O otimizador sabe disso — se ele não está usando seu índice, a primeira hipótese deve ser *"ele está certo"*, não *"ele está burro"*.

**Seleção disjuntiva (`OR`)**: pouca otimização é possível — o resultado é a união dos conjuntos. Se **qualquer** ramo do `OR` não tiver caminho de acesso, cai para varredura linear (Elmasri, cap. 19.3.1). Só compensa se **todos** os ramos tiverem índice, aí recupera cada um e faz união dos RIDs.

> **Nota prática:** é exatamente o `BitmapOr` do PostgreSQL. E é a razão do conselho de Elmasri (cap. 20.2.4, item 1) de reescrever `OR` como `UNION` — no PostgreSQL moderno o Bitmap resolve boa parte, mas `UNION ALL` ainda vence quando os ramos usam índices muito diferentes.

---

## 5. Algoritmos de junção

Esta é a decisão mais importante do otimizador. Notação: `R ⋈_{A=B} S`, `b_R`/`b_S` blocos, `n_B` buffers.

### J1 — Nested loop (força bruta) / block nested loop

Para cada linha (na prática, bloco) de `R` (loop externo), varre `S` inteiro (loop interno).

```
C_J1 = b_R + (⌈b_R / (n_B − 2)⌉ × b_S) + custo_escrita_resultado
```

**Não exige nenhum caminho de acesso.** É o fallback universal.

O exemplo de Elmasri (cap. 19.3.2), com `FUNCIONÁRIO` (b=2.000) e `DEPARTAMENTO` (b=10), `n_B=7`:
- FUNCIONÁRIO externo: `2.000 + ⌈2000/5⌉ × 10 = 6.000`
- DEPARTAMENTO externo: `10 + ⌈10/5⌉ × 2.000 = 4.010`

**Critério: o arquivo menor vai no loop externo.** Sempre. E se o menor couber inteiro na memória (`n_B > b_R + 2`), o custo desaba para `b_R + b_S` — não há razão para particionar nada.

### J2 — Index nested loop (single loop)

Se existe índice em `S.B`, para cada linha de `R` sonda o índice diretamente.

```
Índice secundário:   C = b_R + (|R| × (x_B + 1 + s_B)) + escrita
Índice clustering:   C = b_R + (|R| × (x_B + ⌈s_B/bfr_B⌉)) + escrita
Índice primário:     C = b_R + (|R| × (x_B + 1)) + escrita
Chave hash:          C = b_R + (|R| × h) + escrita
```

**O que decide aqui é o fator de seleção de junção** — a fração de linhas de um arquivo que participa da junção (Elmasri, cap. 19.3.2). No exemplo do livro (`DEPARTAMENTO ⋈_{Cpf_ger=Cpf} FUNCIONÁRIO`):
- FUNCIONÁRIO no loop: `2.000 + 6.000×3 = 20.000` — mas 5.950 dos 6.000 funcionários não gerenciam nada. Fator de seleção = 0,008.
- DEPARTAMENTO no loop: `10 + 50×5 = 260`. Fator = 1 (todo departamento tem gerente).

**Critério: no loop único, use o arquivo com o maior fator de seleção de junção** — aquele em que quase toda linha encontra par. Sondar o índice para linhas que não vão casar é trabalho puro jogado fora.

### J3 — Sort-merge join

Ordena ambos por `A`/`B`, varre os dois em paralelo casando valores iguais.

```
Já ordenados:     C = b_R + b_S + escrita
Precisa ordenar:  C ≈ b_R + b_S + b_R·log₂ b_R + b_S·log₂ b_S
```

**É o mais eficiente possível se os arquivos já estão ordenados** pelos atributos de junção — uma única passada em cada. No exemplo do livro, 2.010 acessos contra 30.500 do nested loop.

O caso de armadilha: usar índices secundários nos dois lados para *simular* a ordem. Os índices dão acesso ordenado, mas os registros estão espalhados fisicamente — cada acesso pode ser um bloco diferente. Elmasri (cap. 19.3.2) chama isso de "muito ineficaz".

### J4 — Hash join (partição-hash)

Fase de **particionamento**: aplica a mesma função hash em `R.A` e `S.B`, quebrando ambos em `M` partições. A propriedade garantida: linhas de `R_i` só podem casar com linhas de `S_i`.
Fase de **investigação (probe)**: para cada par `(R_i, S_i)`, carrega o menor em tabela hash na memória e sonda com o outro.

```
C_J4 ≈ 3 × (b_R + b_S) + escrita
```
(cada linha é lida e gravada uma vez no particionamento, e lida uma segunda vez no probe)

Caso feliz — o menor cabe na memória após o hash (`n_B > b_R + 2`): **não particiona nada**, custo `b_R + b_S + escrita`. Uma passada em cada arquivo.

**A dificuldade crítica é a uniformidade da função hash** (Elmasri, cap. 19.3.2). Se a distribuição for viesada, alguma partição não cabe na memória na fase 2, e o algoritmo degrada.

### Hash híbrido

Variação em que a fase de junção da **primeira partição** acontece durante o particionamento: o buffer é dividido de forma que a partição 1 de `R` fique inteira em memória; ao particionar `S`, tudo que hasheia para a partição 1 já é juntado e emitido na hora. Sobram `M−1` pares no disco em vez de `M`. O objetivo é juntar o máximo possível durante o particionamento, poupando gravar e reler (Elmasri, cap. 19.3.2). É o algoritmo padrão dos SGBDs modernos.

### Tabela de decisão

| Situação | Algoritmo que o otimizador deve escolher | Por quê |
|---|---|---|
| Lado externo pequeno (poucas linhas) + índice no lado interno | **Index nested loop** | custo ≈ `|R| × (x+1)`; imbatível quando `|R|` é pequeno |
| Ambos grandes, sem índice útil, equijunção | **Hash join** | 3×(b_R+b_S), independe de ordem |
| Ambos grandes, **já ordenados** pela chave de junção | **Merge join** | b_R + b_S, uma passada |
| Precisa ordenar os dois só para juntar | Hash geralmente vence | evita `b·log b` de dois sorts |
| Junção não-equi (`<`, `>`, `BETWEEN`) | **Nested loop** (obrigatoriamente) | hash e merge só funcionam com `=` |
| Um lado cabe inteiro na memória | Hash sem particionamento | b_R + b_S |
| Resultado precisa sair ordenado de qualquer jeito | Merge join ganha peso | o sort seria pago mesmo assim |

> **Nota prática — como isso aparece no PostgreSQL:**
> - `Nested Loop` — veja `loops=N` no lado interno. `N` = número de linhas do lado externo. `Nested Loop` com `loops` na casa dos milhares e sem índice do lado interno é o desastre clássico.
> - `Hash Join` — traz um nó `Hash` filho com `Buckets: 4096 Batches: 1 Memory Usage: 3520kB`. **`Batches: 1` significa que coube na memória** (caso feliz, sem particionamento). `Batches: 8` significa que particionou e foi ao disco — é o caso geral do J4, e sinal para revisar `work_mem`.
> - `Merge Join` — quase sempre acompanhado de `Sort` nos dois lados, ou de `Index Scan` que já entrega ordenado. Se você vê `Merge Join` com dois `Sort` caros, force um teste com `SET enable_mergejoin = off` e compare: às vezes é estimativa ruim.
> - `enable_nestloop`, `enable_hashjoin`, `enable_mergejoin` são **ferramentas de diagnóstico**, não de produção. Use para descobrir *o que o otimizador acha que custa o quê*, depois conserte a causa (estatística, índice, reescrita).

---

## 6. Projeção, conjuntos, agregação, junção externa

**Projeção** (Elmasri, cap. 19.4): trivial se a lista contém uma chave — o resultado tem o mesmo número de linhas. Senão, precisa eliminar duplicatas via ordenação ou hash. Em SQL o padrão é **não** eliminar; só com `DISTINCT`.

> **Nota prática:** `DISTINCT` desnecessário é um dos anti-padrões mais baratos de corrigir. Ele impõe um `HashAggregate` ou `Sort` que não estaria lá. Elmasri (cap. 20.2.3, item 3) diz literalmente: "um DISTINCT normalmente causa uma operação de ordenação e deve ser evitado ao máximo possível". Se você colocou `DISTINCT` porque a junção duplicou linhas, o problema é a junção — troque por `EXISTS`/semi-junção.

**Operações de conjunto** (Elmasri, cap. 19.4): implementadas por sort-merge (ordena ambas, varre uma vez) ou por hash. `UNION`/`INTERSECT`/`EXCEPT` eliminam duplicatas; `UNION ALL`/`INTERSECT ALL`/`EXCEPT ALL` não.

> **Nota prática:** `UNION ALL` é sempre mais barato que `UNION`. Use `UNION` só quando a deduplicação for semanticamente necessária.

**Produto cartesiano** é caro por construção: `n × m` linhas com `l + k` atributos. Elmasri (cap. 19.4) é explícito: "é importante evitar a operação PRODUTO CARTESIANO e substituí-la por junção durante a otimização".

**Agregação** (Elmasri, cap. 19.5.1):
- `MAX`/`MIN` sobre a tabela inteira com índice B-tree: segue o ponteiro mais à direita/esquerda até a folha. Não lê nenhum registro de dados.
- `SUM`/`AVG` só podem usar o índice se ele for **denso**. Índice esparso não sabe quantos registros há por entrada.
- `COUNT(*)` da relação inteira: costuma estar no catálogo.
- Com `GROUP BY`: particiona por ordenação ou hash nos atributos de agrupamento, depois agrega por grupo. **Se houver índice de agrupamento no atributo de grupo, os registros já estão particionados** — basta aplicar o cálculo.

> **Nota prática:** `SELECT max(ocorrida_em) FROM transacoes` com índice em `ocorrida_em` vira `Result → Limit → Index Only Scan Backward`, custo ~0. Mas `SELECT count(*) FROM transacoes` no PostgreSQL **não** é O(1) — MVCC obriga a verificar visibilidade. Com índice cobrindo e visibility map atualizado, vira `Index Only Scan`, que é mais barato que `Seq Scan` mas ainda O(n). Contadores exatos de tabelas grandes: mantenha agregado incremental. Aproximado: `reltuples` de `pg_class`.

**Junção externa** (Elmasri, cap. 19.5.2): calcula-se modificando um algoritmo de junção — para `LEFT OUTER`, use a relação esquerda como loop externo/único, e quando não achar par, emita a linha preenchida com NULL. Sort-merge e hash também estendem. Equivalente algébrico: `(R ⋈ S) ∪ ((π(R) − π(R ⋈ S)) × {NULL})`.

**Consequência de decisão:** `LEFT JOIN` não é "grátis" comparado a `INNER JOIN`, mas o custo extra é pequeno. O custo real é indireto: `LEFT JOIN` **restringe a reordenação de junções** do otimizador, porque não é comutativo. Numa consulta de 6 tabelas, isso pode custar caro. Se `WHERE b.col = x` filtra o lado direito de um `LEFT JOIN`, você acabou de transformá-lo num `INNER JOIN` sem perceber — escreva `INNER JOIN` e ganhe liberdade de reordenação.

---

## 7. Pipelining vs. materialização

(Elmasri, cap. 19.6 e 19.7.3)

- **Materialização**: o resultado de uma operação é gravado como relação temporária, e a operação seguinte lê esse arquivo. Custa E/S de escrita + E/S de leitura.
- **Pipelining** (processamento baseado em fluxo): as tuplas produzidas por uma operação são passadas direto para a próxima, tupla a tupla, sem tocar o disco.

"A vantagem do pipeline é a economia de custo por não ter de gravar os resultados intermediários em disco e não ter de lê-los de volta." Pipelining é preferido **sempre que viável**.

Quando não é viável: operadores **bloqueantes** — os que precisam consumir toda a entrada antes de emitir a primeira saída. Ordenação, agregação com hash, construção da tabela hash de um hash join.

> **Nota prática:** no PostgreSQL isso é a diferença entre custo **inicial** e custo **total** — `cost=0.29..8.31` significa "0.29 para produzir a primeira linha, 8.31 para produzir todas". Um nó com custo inicial alto é bloqueante. É por isso que:
> - `LIMIT 10` numa consulta com `Index Scan` retorna instantaneamente (pipeline puro, para na décima linha);
> - `LIMIT 10` numa consulta com `Sort` no topo paga a ordenação inteira antes de emitir qualquer coisa;
> - `CTE MATERIALIZED` (padrão até o PG 11, opt-in a partir do 12) força materialização e mata o pipeline. No PG 12+, use `WITH x AS MATERIALIZED (...)` só quando quiser exatamente isso — reusar o resultado várias vezes, ou impedir que o otimizador empurre um predicado ruim para dentro.

---

## 8. Otimização heurística: as regras de transformação

O parser gera uma **árvore canônica** ingênua: produto cartesiano de tudo no `FROM`, depois todas as condições do `WHERE`, depois a projeção do `SELECT`. Essa árvore **nunca é executada** — no exemplo de Elmasri (cap. 19.7.2), o produto cartesiano de 3 tabelas daria 10 milhões de tuplas de 300 bytes. Ela existe só como ponto de partida (Elmasri, cap. 19.7.2).

### As regras de equivalência (Elmasri, cap. 19.7.2)

1. **Cascata de σ**: `σ_{c1 AND c2 AND ... AND cn}(R) = σ_{c1}(σ_{c2}(...σ_{cn}(R)...))`
   *Vale porque* permite mover cada condição independentemente para ramos diferentes da árvore.
2. **Comutatividade de σ**: `σ_{c1}(σ_{c2}(R)) = σ_{c2}(σ_{c1}(R))`
   *Vale porque* deixa o otimizador aplicar primeiro a condição mais seletiva.
3. **Cascata de π**: `π_{L1}(π_{L2}(...π_{Ln}(R)...)) = π_{L1}(R)` — só a última importa.
   *Vale porque* elimina projeções redundantes de graça.
4. **Comutação de σ com π**: se `c` só envolve atributos da lista de projeção, `π_L(σ_c(R)) = σ_c(π_L(R))`.
5. **Comutatividade de ⋈ e ×**: `R ⋈ S = S ⋈ R`.
   *Vale porque* é o que habilita escolher qual lado é externo/interno — decisão que vimos valer 6.000 vs. 4.010 acessos.
6. **Comutação de σ com ⋈ (×)** — **a regra mais valiosa de todas**: se `c` só envolve atributos de `R`, então `σ_c(R ⋈ S) = (σ_c(R)) ⋈ S`. E se `c = c1 AND c2` com `c1` só em `R` e `c2` só em `S`: `σ_c(R ⋈ S) = (σ_{c1}(R)) ⋈ (σ_{c2}(S))`.
   *Vale porque* o tamanho da saída de uma binária é **multiplicativo** nos tamanhos das entradas. Reduzir a entrada antes reduz o produto.
7. **Comutação de π com ⋈ (×)**: se a condição de junção só usa atributos da lista de projeção, comuta direto. Senão, adicione os atributos da junção à lista e faça uma π final.
8. **Comutatividade das operações de conjunto**: `∪` e `∩` comutam; `−` não.
9. **Associatividade de ⋈, ×, ∪, ∩**: `(R θ S) θ T = R θ (S θ T)`.
   *Vale porque* junto com a regra 5 é o que gera todo o espaço de ordens de junção.
10. **Comutação de σ com operações de conjunto**: `σ(R θ S) = (σ(R)) θ (σ(S))` para `∪`, `∩`, `−`.
11. **π comuta com ∪**: `π_L(R ∪ S) = (π_L(R)) ∪ (π_L(S))`.
12. **Converter (σ, ×) em ⋈**: se a condição `c` de um `σ` que segue um `×` é uma condição de junção, então `σ_c(R × S) = R ⋈_c S`.

Mais as leis de De Morgan para normalizar `NOT`.

### O algoritmo heurístico (Elmasri, cap. 19.7.2)

1. Regra 1: quebre `σ` conjuntivos em cascata.
2. Regras 2, 4, 6, 10: **empurre cada σ o mais para baixo possível**. Condição sobre uma tabela só → desce até a folha. Condição sobre duas tabelas → desce até logo após as duas serem combinadas.
3. Regras 5 e 9: **reordene as folhas**. Coloque primeiro as relações com as seleções **mais restritivas** (menor seletividade — é o critério prático, porque estimativas de seletividade estão no catálogo). E **garanta que a ordem não force produtos cartesianos**.
4. Regra 12: combine `×` + `σ` em `⋈`.
5. Regras 3, 4, 7, 11: **empurre as projeções para baixo**, criando novas π conforme necessário. Mantenha só os atributos exigidos pelo resultado e pelas operações seguintes.
6. Identifique subárvores executáveis por um único algoritmo (agrupamento para pipelining).

**Resumo da heurística**: aplique primeiro o que reduz o tamanho dos resultados intermediários. σ reduz linhas, π reduz colunas — ambos para baixo, o quanto der. Junções mais restritivas primeiro. Evite produtos cartesianos.

> **Nota prática:** o PostgreSQL faz tudo isso e você vê o resultado como `Filter` colado no `Seq Scan` da folha em vez de num nó separado acima da junção. O que **impede** o predicate pushdown na prática:
> - função não-`IMMUTABLE` no predicado;
> - `CTE MATERIALIZED` (barreira de otimização explícita);
> - `LEFT JOIN` — um predicado sobre o lado nullable **não pode** descer sem mudar a semântica;
> - subconsulta com `LIMIT` (empurrar filtro para dentro mudaria quais linhas o LIMIT pega);
> - janela (`OVER`) — filtro após a janela não desce.
> Se o `Filter` está acima e você esperava que estivesse embaixo, é um destes.

---

## 9. Otimização baseada em custo

Heurística não basta. O otimizador **estima e compara** custos de estratégias e escolhe a de menor custo estimado. Isso exige (a) estimativas precisas e (b) limitar o espaço de busca — senão gasta-se mais tempo otimizando que executando (Elmasri, cap. 19.8).

### Componentes de custo (Elmasri, cap. 19.8.1)

1. **Acesso ao armazenamento secundário** (E/S de disco) — dominante em bancos grandes.
2. **Armazenamento em disco** de arquivos intermediários.
3. **Computação** (CPU) — dominante em bancos que cabem na memória.
4. **Uso de memória** (número de buffers).
5. **Comunicação** — dominante em distribuído.

"É difícil incluir todos os componentes numa função ponderada, devido à dificuldade de atribuir pesos adequados. É por isso que algumas funções de custo consideram apenas um único fator — acesso de disco."

> **Nota prática:** o PostgreSQL pondera explicitamente, e os pesos são configuráveis: `seq_page_cost` (1.0), `random_page_cost` (4.0), `cpu_tuple_cost` (0.01), `cpu_index_tuple_cost` (0.005), `cpu_operator_cost` (0.0025). **`random_page_cost = 4.0` é um default de disco rotacional.** Em SSD/NVMe, a razão real entre acesso aleatório e sequencial é perto de 1.1–1.5. Deixar 4.0 num SSD faz o otimizador subestimar sistematicamente índices e preferir `Seq Scan`. Baixar para 1.1 é uma das intervenções de maior retorno e menor risco num banco moderno. `effective_cache_size` (default irrisório) diz ao otimizador quanta memória o SO tem de cache — subestimá-lo tem o mesmo efeito de penalizar índices.

### Informação de catálogo (Elmasri, cap. 19.8.2)

Para cada arquivo: `r` (linhas), `R` (tamanho médio do registro), `b` (blocos), `bfr` (fator de bloco), organização primária. Para cada índice: `x` (níveis), `bI1` (blocos de primeiro nível).

E o par central: `d` (número de valores distintos) e `sl` (seletividade). Daí sai a **cardinalidade de seleção** `s = sl × r`.

- Atributo chave: `d = r`, `sl = 1/r`, `s = 1`.
- Atributo não chave, **assumindo distribuição uniforme**: `sl = 1/d`, `s = r/d`.

### Histogramas: por que a suposição de uniformidade quebra

"Para um atributo não chave com `d` valores distintos, **é comum acontecer de os registros não serem distribuídos uniformemente** entre esses valores" (Elmasri, cap. 19.8.2). O exemplo do livro: 5 departamentos, 200 funcionários distribuídos (1,5) (2,25) (3,70) (4,40) (5,60). A suposição uniforme diria 40 por departamento — erra por 8× no departamento 1.

A solução é o **histograma**: uma tabela de (valor, seletividade) que reflete a distribuição real. No exemplo: (1, 0.025) (2, 0.125) (3, 0.35) (4, 0.2) (5, 0.3).

Elmasri (cap. 19.8.3, S4) reconhece o limite: a estimativa de `x + b/2` para range "é muito aproximada e, embora possa estar correta na média, pode ser muito imprecisa em casos individuais. **Uma estimativa mais precisa é possível se a distribuição de registros for armazenada em um histograma.**"

### Estimativa de cardinalidade de junção

`|R ⋈ S| = js × |R| × |S|`, com os casos especiais:
- `A` chave de `R` → `js ≤ 1/|R|`, resultado ≤ `|S|`.
- `B` é FK `NOT NULL` referenciando a PK `A` de `R` → `js = 1/|R|` e o resultado tem **exatamente** `|S|` linhas.

### Por que a estimativa erra — e o que acontece quando erra

Os modos de falha, em ordem de frequência prática:

1. **Correlação entre colunas.** O otimizador estima `sel(A=x AND B=y) = sel(A=x) × sel(B=y)` — assume independência. Se `categoria_id = 7` ("Aluguel") só ocorre em transações com `valor_cents > 100000`, a estimativa conjunta erra por ordens de magnitude. É o erro que a suposição de uniformidade+independência de Elmasri (cap. 19.8.2) embute por construção.
2. **Estatísticas desatualizadas.** "O número de registros `r` muda toda vez que um registro é inserido ou excluído" (Elmasri, cap. 19.8.2). O otimizador precisa de valores *próximos*, não exatos — mas "próximos" tem limite.
3. **Erro composto ao longo da árvore.** Cada nó de junção estima a partir da estimativa do nó abaixo. Um erro de 10× na folha vira 10× em toda a subárvore acima.
4. **Predicados que o otimizador não sabe estimar** — funções, `LIKE '%x%'`, parâmetros opacos.

**O que acontece quando erra**: o otimizador escolhe o algoritmo errado. O caso canônico e catastrófico: subestimou o lado externo de um `Nested Loop` em 1.000× → o que ele achou que seriam 5 sondagens de índice são 5.000, e a consulta que deveria levar 2ms leva 40s. O simétrico: superestimou → escolheu `Hash Join` e construiu tabela hash de 8GB para juntar 12 linhas.

> **Nota prática — o sinal mais importante do EXPLAIN inteiro:**
> ```
> EXPLAIN (ANALYZE, BUFFERS) ...
> ->  Index Scan on transacoes  (cost=0.43..8.45 rows=1 width=48)
>                               (actual time=0.02..14.3 rows=8934 loops=1)
> ```
> **`rows=1` estimado contra `rows=8934` real é um erro de 4 ordens de magnitude.** Toda decisão tomada acima desse nó foi tomada com informação errada. Não olhe o resto do plano até consertar isso. Ferramentas, em ordem:
> 1. `ANALYZE transacoes;` — talvez seja só estatística velha.
> 2. `ALTER TABLE transacoes ALTER COLUMN categoria_id SET STATISTICS 1000;` depois `ANALYZE` — histograma mais fino (default: 100 buckets).
> 3. `CREATE STATISTICS st_tx (dependencies, ndistinct, mcv) ON conta_id, categoria_id FROM transacoes; ANALYZE transacoes;` — **estatísticas estendidas**, a resposta direta do PostgreSQL ao problema de correlação. Essa é a ferramenta que não existia na época do livro e que resolve o modo de falha nº 1.
> 4. Se o predicado é uma expressão, crie um índice de expressão — ele também cria estatísticas para a expressão.

### Ordem de junção e poda do espaço de busca

Uma consulta com `n` relações tem `n−1` junções e o número de árvores cresce explosivamente. Os otimizadores **limitam a estrutura a árvores left-deep** (o filho da direita de todo nó não folha é uma relação base) (Elmasri, cap. 19.8.5).

Duas vantagens das left-deep:
1. **São receptivas a pipelining** — enquanto tuplas de `R1 ⋈ R2` são produzidas, já sondam `R3`.
2. **Ter uma relação base como entrada de cada junção permite usar os caminhos de acesso dessa relação.**

"A ideia-chave do ponto de vista do otimizador em relação à ordenação de junção é **encontrar uma ordenação que reduza o tamanho dos resultados temporários**", porque estes alimentam os operadores seguintes.

Programação dinâmica encontra o ótimo sem enumerar tudo (Elmasri, cap. 19.8.3).

> **Nota prática:** o PostgreSQL usa programação dinâmica (System-R) até `geqo_threshold` (default 12) relações no `FROM`; acima disso troca para o **GEQO**, um otimizador genético que é *aproximado e não determinístico* — o mesmo SQL pode gerar planos diferentes entre execuções. Uma consulta com 15 junções que "às vezes é rápida e às vezes não" é isso. Também: `join_collapse_limit` e `from_collapse_limit` (default 8) fazem o planner **parar de reordenar** acima do limite e respeitar a ordem que você escreveu. Consulta grande + ordem ruim no `FROM` = plano ruim determinístico.

### Dicas (hints)

Elmasri (cap. 19.9) descreve os hints do Oracle e a justificativa: "um desenvolvedor de aplicação possa saber mais informações sobre os dados do que o otimizador". O exemplo é exatamente o de `Sexo` com 2 valores distintos e distribuição real 100/9.900.

> **Nota prática:** o PostgreSQL **não tem hints** por decisão de projeto. O equivalente é: (a) consertar as estatísticas — que é a resposta certa; (b) `pg_hint_plan` como extensão; (c) as flags `enable_*` como último recurso, escopo de sessão. A ausência de hints é uma pressão saudável: força a diagnosticar a causa em vez de mascará-la.

### Otimização semântica

Usa restrições do esquema para reescrever ou eliminar a consulta (Elmasri, cap. 19.10). Se existe uma `CHECK` garantindo que nenhum funcionário ganha mais que o supervisor, a consulta que procura tais funcionários retorna vazio sem executar.

> **Nota prática:** o PostgreSQL faz uma forma disso com `CHECK` constraints e **partition pruning** — uma partição cuja restrição contradiz o `WHERE` é eliminada em tempo de planejamento (`Subplans Removed: N` no plano). Constraints declaradas não são só integridade; são informação para o otimizador. Uma FK declarada permite ao planner **eliminar junções desnecessárias** (join removal): `SELECT t.* FROM transacoes t JOIN contas c ON c.id = t.conta_id` sem usar nenhuma coluna de `c` — o planner remove a junção inteira, mas **só se** a FK garantir que todo `conta_id` tem par. Prisma que declara relações sem FK no banco perde isso.

---

## 10. Projeto físico e tuning (Elmasri, cap. 20)

### Entradas da decisão (cap. 20.1.1)

Não se toma decisão de projeto físico sem conhecer a **combinação de tarefas** (workload). Para cada consulta: quais tabelas, quais atributos nas condições de seleção, se a condição é de igualdade/desigualdade/intervalo, quais atributos nas junções, quais atributos recuperados. **Os atributos de seleção e de junção são os candidatos a índice.**

Para cada atualização: quais tabelas, tipo de operação, atributos nas condições, **e atributos cujos valores mudam — estes são candidatos a *evitar* índice**, porque cada mudança obriga a atualizar o índice.

Mais: **frequência de chamada** (regra 80-20: ~80% do processamento vem de ~20% das consultas — não colete estatística de tudo, só dos 20%), **restrições de tempo** (consultas com SLA ganham prioridade nas estruturas de acesso primárias), **frequência de atualização** ("se um arquivo com inserções frequentes tem dez índices, cada um deve ser atualizado a cada inserção"), e **restrições de unicidade** (todo atributo único deve ter caminho de acesso — o índice é o que torna a verificação barata).

### Decisões de indexação (cap. 20.1.2)

1. **Indexar ou não**: o atributo deve ser chave, ou aparecer em condição de seleção (igualdade ou intervalo), ou em condição de junção. Motivo adicional para múltiplos índices: algumas operações são processadas **varrendo só o índice**, sem tocar o arquivo de dados.
2. **Quais atributos**: índice composto quando vários atributos aparecem juntos nas consultas. **A ordem dos atributos no índice composto deve corresponder às consultas.**
3. **Clustering**: no máximo um por tabela — implica ordem física. **Consultas de intervalo se beneficiam muito do agrupamento.** E o inverso, que é sutil: "se uma consulta tiver de ser respondida realizando apenas uma consulta de índice (sem recuperar registros de dados), **o índice correspondente não deverá ser agrupado**, pois o principal benefício do agrupamento é alcançado ao se recuperar os próprios registros".
4. **Hash vs. árvore**: B+-tree serve igualdade **e** intervalo; hash só igualdade, mas é bom para junções.
5. **Hashing dinâmico** para arquivos voláteis.

> **Nota prática — traduzindo para PostgreSQL:**
> - O PostgreSQL **não tem índice clustered** no sentido do livro. `CLUSTER tabela USING idx` é uma reorganização física **pontual**, não mantida — inserções posteriores voltam a desorganizar. O substituto real é a **correlação física** (`pg_stats.correlation`, entre −1 e 1). `ocorrida_em` numa tabela append-only tem correlação ≈ 1 naturalmente — ranges por data ficam baratos de graça. `categoria_id` tem correlação ≈ 0 — ranges por categoria pagam acesso aleatório. Quando a correlação é baixa e o range é grande, o planner escolhe `Bitmap Heap Scan`, que é o meio-termo: ordena os RIDs antes de ir ao heap.
> - **A ordem no índice composto é a regra mais violada na prática.** `CREATE INDEX ON transacoes (conta_id, ocorrida_em)` serve `WHERE conta_id = 1 AND ocorrida_em > x` e serve `WHERE conta_id = 1`. **Não serve** `WHERE ocorrida_em > x` sozinho. Coluna de igualdade primeiro, coluna de range depois — é isso que Elmasri quer dizer com "a ordenação deve corresponder às consultas".
> - **Índice parcial** não existe no livro e é uma das melhores ferramentas do PostgreSQL: `CREATE INDEX ON transacoes (conta_id) WHERE categoria_id IS NULL;` — índice pequeno para a consulta "transações não categorizadas", que é frequente e seletiva.
> - **Índice covering**: `CREATE INDEX ON transacoes (conta_id) INCLUDE (valor_cents);` é literalmente o "processar apenas varrendo os índices" do item 1 de Elmasri — vira `Index Only Scan`.

### Desnormalização (cap. 20.1.2)

O objetivo da normalização é minimizar redundância e evitar anomalias. "Esses ideais às vezes são sacrificados em favor de uma execução mais rápida de consultas e transações que ocorrem com frequência." Desnormalizar = incluir atributos de `S` em `R` para **evitar a junção** de `R` com `S` nas consultas frequentes.

**O dilema, textualmente**: "existe um dilema entre a atualização adicional necessária para manter a consistência dos atributos redundantes e o esforço necessário para realizar uma junção".

Alternativas na mesma família:
- **View**: não evita a junção, só evita que o usuário a escreva. **View materializada** evita a junção de verdade.
- **Particionamento vertical**: quebrar `R(Ch, A, B, C, D)` em `R1(Ch, A, B)`, `R2(Ch, C, D)` replicando a chave — todas ainda em FNBC. Vale quando grupos de atributos são acessados juntos e com frequências muito diferentes.
- **Particionamento horizontal**: fatias de linhas em tabelas distintas. O custo: consultas que atravessam todas as fatias precisam ser executadas contra todas e ter os resultados combinados.

**Critério de decisão para desnormalizar:** só quando (a) a junção evitada está nos 20% quentes, (b) a coluna copiada é quase imutável, (c) existe um ponto único que garante a atualização. `transacoes.categoria_nome` copiado de `categorias` satisfaz (a) e (b); a fonte de risco é (c).

> **Nota prática:** `saldo_cents` em `contas` **é** desnormalização — é `SUM(valor_cents)` das transações materializado. É quase sempre a decisão certa (a agregação está no caminho quente de toda tela), e é exatamente onde o dilema morde: o saldo precisa ser atualizado transacionalmente com a transação, ou você tem dado errado. Com Prisma: a escrita da transação e a atualização do saldo têm que estar no mesmo `$transaction`. Uma view materializada com `REFRESH` periódico **não** serve para saldo — serve para relatório mensal.

### Tuning (cap. 20.2)

"Após um banco ser implementado e estar em operação, o uso real revela fatores e áreas de problema que podem não ter sido considerados durante o projeto físico inicial." Objetivos: aplicações mais rápidas, menor tempo de resposta, melhor throughput. "**A linha divisória entre o projeto físico e o ajuste é muito tênue**" — tuning é projeto físico contínuo.

Estatísticas que o SGBD coleta: tamanhos de tabela, número de valores distintos por coluna, quantas vezes cada consulta é submetida, tempos por fase. Mais: estatísticas de armazenamento, de E/S e **hot spots de disco**, de processamento de consulta, de bloqueio/logging, e de índice (níveis, páginas folha não contíguas).

**Ajustando índices (cap. 20.2.1)** — os três sinais de que a escolha inicial precisa ser revista:
- consultas lentas por **falta** de índice;
- índices que **nem são utilizados**;
- índices que sofrem **muita atualização**, porque estão em atributo que muda com frequência.

E: "a maioria dos SGBDs tem um comando ou facilidade de **trace**, que pode ser usado pelo DBA para pedir que o sistema mostre como uma consulta foi executada". Esse comando é o `EXPLAIN`.

Sobre recriação: "se houver muitas exclusões na chave de índice, as páginas de índice podem conter **espaço desperdiçado**, que pode ser reivindicado durante a operação de recriação". E o alerta operacional: "a atualização de uma tabela em geral é suspensa enquanto um índice é descartado ou criado; **essa perda de serviço deve ser considerada**".

> **Nota prática:**
> - Índices não usados: `SELECT relname, indexrelname, idx_scan FROM pg_stat_user_indexes WHERE idx_scan = 0;` — mas só depois de um ciclo completo de negócio (fechamento mensal usa índices que ficam parados 29 dias).
> - Bloat de índice ("espaço desperdiçado" de Elmasri): `REINDEX INDEX CONCURRENTLY idx;` — o `CONCURRENTLY` é a resposta direta ao alerta de perda de serviço. Idem `CREATE INDEX CONCURRENTLY`.
> - `ANALYZE` atualiza estatísticas; `VACUUM` recupera espaço morto e atualiza o **visibility map** (sem o qual `Index Only Scan` degrada para acesso ao heap — você vê isso como `Heap Fetches: 892134` num `Index Only Scan`, que anula o benefício). **Autovacuum com defaults é conservador demais para tabelas grandes e quentes**: `autovacuum_vacuum_scale_factor = 0.2` significa esperar 20% da tabela morrer — em 10M linhas, são 2M tuplas mortas antes de agir. Para `transacoes`: `ALTER TABLE transacoes SET (autovacuum_vacuum_scale_factor = 0.02, autovacuum_analyze_scale_factor = 0.01);`
> - Um `ANALYZE` manual **depois de toda carga em massa ou migração**. Um bulk insert de 1M transações deixa o otimizador acreditando que a tabela tem o tamanho anterior — e ele vai escolher `Nested Loop` para uma tabela que agora é grande.
> - `pg_stat_statements` é a implementação direta de "o número de vezes que determinada consulta é submetida e os tempos exigidos" (cap. 20.2). É a ferramenta que encontra os **20% de Elmasri**:
> ```sql
> SELECT calls, total_exec_time, mean_exec_time, rows, query
> FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 20;
> ```
> Ordene por `total_exec_time`, não por `mean_exec_time`. A consulta de 2ms chamada 4 milhões de vezes custa mais que a de 8s chamada 3 vezes — e é a que revela o N+1.

### Tuning de consultas (cap. 20.2.3)

As duas indicações de que a consulta precisa de ajuste:
1. **A consulta emite muitos acessos ao disco** — ex.: consulta de combinação exata que varre a tabela inteira.
2. **O plano mostra que índices relevantes não estão sendo usados.**

Os casos típicos catalogados por Elmasri, que são os anti-padrões clássicos:

1. **Índices não são usados na presença de**: expressões aritméticas sobre a coluna (`Salario/365 > 10.50`), comparações numéricas entre **tipos de tamanho/precisão diferentes** (`Aqtd = Bqtd` com `INTEGER` vs `SMALLINT`), comparações `IS NULL`, e comparações de substring (`Unome LIKE '%eira'`).
2. **Índices não costumam ser usados em subconsultas aninhadas com `IN`** — a mesma consulta escrita como junção de bloco único usa o índice.
3. **`DISTINCT` redundante** — causa ordenação.
4. **Tabelas temporárias desnecessárias** — reduza múltiplas consultas a uma, a menos que o temporário seja necessário.
5. **Correlacionadas**: quebrar em agregação + junção (visto na seção 2).
6. **Se há várias opções de condição de junção, escolha a que usa índice de agrupamento e evite comparações de string.** Junte por `Cpf`, não por `Nome`.
7. **A ordem das tabelas no `FROM` pode afetar o processamento da junção** — troque para que a menor seja varrida e a maior use índice.
8. Otimizadores vão pior em aninhadas. Dos quatro tipos, só o primeiro (não correlacionada com agregação na interna) não dá problema — porque é avaliado uma vez.
9. **Views exageradas**: consultar a tabela base direto em vez de passar por uma view definida por junção.

E as transformações adicionais (cap. 20.2.4):
- `OR` → `UNION` (visto na seção 4);
- `NOT` → expressão positiva;
- `IN`, `= ALL`, `= ANY`, `= SOME` → junções;
- **propagar predicado de intervalo através da equijunção**: se `A.x = B.x` e há `A.x BETWEEN 1 AND 3`, repita a condição em `B.x`;
- reescrever `WHERE` para usar índice composto:
  ```sql
  -- Usa índice só em num_regiao, varre folhas procurando tipo_prod
  WHERE num_regiao = 3 AND ((tipo_prod BETWEEN 1 AND 3) OR (tipo_prod BETWEEN 8 AND 10))
  -- Usa o composto (num_regiao, tipo_prod)
  WHERE (num_regiao = 3 AND tipo_prod BETWEEN 1 AND 3)
     OR (num_regiao = 3 AND tipo_prod BETWEEN 8 AND 10)
  ```

"O objetivo é fazer que o SGBDR utilize índices de atributo único ou compostos existentes tanto quanto possível. Isso evita varreduras completas dos blocos de dados ou a varredura inteira dos nós folha do índice. **Os processos redundantes, como a classificação, devem ser evitados a qualquer custo.**"

---

## 11. Nota prática: lendo `EXPLAIN (ANALYZE, BUFFERS)`

Use **sempre** as três opções juntas. `EXPLAIN` sozinho só mostra a estimativa — e a estimativa é justamente o que está sob suspeita.

```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT c.nome, sum(t.valor_cents)
FROM contas c
JOIN transacoes t ON t.conta_id = c.id
WHERE c.usuario_id = 42 AND t.ocorrida_em >= '2026-01-01'
GROUP BY c.nome;
```

```
HashAggregate  (cost=8214.55..8216.55 rows=200 width=40)
               (actual time=48.112..48.140 rows=7 loops=1)
  Group Key: c.nome
  Buffers: shared hit=1284 read=612
  ->  Nested Loop  (cost=0.86..8180.05 rows=6900 width=40)
                   (actual time=0.061..44.203 rows=7215 loops=1)
        Buffers: shared hit=1284 read=612
        ->  Index Scan using contas_usuario_id_idx on contas c
              (cost=0.29..12.34 rows=7 width=32)
              (actual time=0.021..0.038 rows=7 loops=1)
              Index Cond: (usuario_id = 42)
              Buffers: shared hit=4
        ->  Index Scan using transacoes_conta_id_ocorrida_em_idx on transacoes t
              (cost=0.57..1156.82 rows=986 width=16)
              (actual time=0.014..5.910 rows=1031 loops=7)
              Index Cond: ((conta_id = c.id) AND (ocorrida_em >= '2026-01-01'))
              Buffers: shared hit=1280 read=612
Planning Time: 0.412 ms
Execution Time: 48.201 ms
```

Como ler, em ordem:
1. **`Execution Time` vs. `Planning Time`.** Planning de 200ms para execution de 3ms = consulta simples demais para tanto planejamento (ou `join_collapse_limit` alto demais, ou falta de prepared statement).
2. **`cost` é uma unidade abstrata, não milissegundos.** Nunca compare custo entre bancos ou entre configs diferentes. Compare custos **dentro do mesmo plano**, e compare `actual time` entre planos.
3. **`rows` estimado vs. `rows` real, nó a nó, de baixo para cima.** Ache o nó mais profundo com erro > 10× — é ali que a otimização foi envenenada.
4. **`loops`.** `actual time` e `rows` num nó são **por loop**. `rows=1031 loops=7` = 7.217 linhas e ~41ms totais, não 5.9ms. Erro de leitura clássico.
5. **`Buffers`.** `shared hit` = veio do cache do PostgreSQL (barato). `shared read` = foi ao SO/disco (caro). `read` alto num nó pequeno = dado frio. **É o único número do plano que fala de E/S real** — o custo de acesso ao armazenamento secundário de Elmasri (cap. 19.8.1).

### Tabela: o que vejo → o que significa → o que fazer

| O que vejo no EXPLAIN | O que significa | O que fazer |
|---|---|---|
| `Seq Scan` em tabela grande com `Filter` seletivo | Sem índice utilizável, ou o planner acha que a varredura é mais barata | Confira `rows` removed by filter. Se o filtro remove 99%, crie índice. Se remove 20%, o planner está certo (Elmasri 19.8.3: S6 com `s` grande perde de S1) |
| `Rows Removed by Filter: 4.9M` | Leu 5M linhas para devolver poucas | Índice na coluna do filtro, ou índice parcial |
| `rows=1` estimado, `rows=50000` real | **Estatística ruim ou correlação de colunas** | `ANALYZE`; `SET STATISTICS 1000`; `CREATE STATISTICS ... (dependencies, mcv)` |
| `rows=100000` estimado, `rows=3` real | Superestimativa → escolheu hash/merge sem necessidade | Mesma investigação; verifique predicados com função ou parâmetro opaco |
| `Nested Loop` com `loops=180000` | Loop externo gigante; ~180k sondagens | Se o interno tem índice e é rápido, pode estar ok. Se não, força `Hash Join` consertando a estimativa. Costuma ser subestimativa do externo |
| `Nested Loop` sem `Join Filter` nem `Index Cond` | **Produto cartesiano** | Condição de junção faltando no `ON`/`WHERE` (Elmasri 19.4: "é importante evitar") |
| `Hash` com `Batches: 8` (ou mais) | Hash não coube na memória; particionou para disco — o caso geral do J4 | Aumente `work_mem` na sessão; ou reduza o lado hasheado com filtro/projeção antes |
| `Sort Method: external merge Disk: 82MB` | Sort externo, múltiplas passadas (Elmasri 19.2) | `work_mem`; ou índice que já entregue a ordem e elimine o `Sort` |
| `Bitmap Heap Scan` + `Recheck Cond` + `lossy` | Bitmap estourou `work_mem`, virou por página; recheck linha a linha | `work_mem`; ou índice mais seletivo |
| `Bitmap Heap Scan` (não lossy) | Meio-termo: muitas linhas para Index Scan, poucas para Seq Scan; ordena RIDs antes do heap | Normal e saudável. Se quer eliminar, precisa de correlação física alta |
| `Index Only Scan` com `Heap Fetches: 890k` | Visibility map desatualizado — o benefício evaporou | `VACUUM tabela;` e reduza `autovacuum_vacuum_scale_factor` |
| `Filter` **acima** de uma junção, esperado embaixo | Pushdown bloqueado | LEFT JOIN sobre nullable? CTE materializada? função VOLATILE? subconsulta com LIMIT? |
| `SubPlan` com `loops` alto | Correlacionada não descorrelacionada (Elmasri 19.1, 20.2.3) | Reescreva como junção ou CTE agregada |
| `Merge Join` com dois `Sort` caros | Pagou 2 ordenações para juntar | Compare com `SET enable_mergejoin=off`. Hash costuma ganhar (Elmasri 19.3.2: J3 só brilha se já ordenado) |
| `Materialize` no lado interno de `Nested Loop` | Cacheou o interno para reusar entre loops | Normal. Se o interno é grande, o `Nested Loop` é o problema |
| Estimativa muda entre execuções da mesma query | GEQO (>= 12 relações no FROM) | Reduza junções; ou suba `geqo_threshold`; ou aceite o não determinismo |
| `Planning Time` > `Execution Time` | Excesso de planejamento | Prepared statements; reduza `join_collapse_limit` |

### Anti-padrões clássicos

| Anti-padrão | Por que mata o índice | Correção |
|---|---|---|
| **N+1** — 1 query para contas, N para transações | Nada de errado com cada query; o custo é o round-trip × N. É o `Nested Loop` do Elmasri (J1) executado **na aplicação**, sem buffers, com latência de rede por iteração | Uma junção. No Prisma: `include`/`select` aninhado, ou `findMany({ where: { conta_id: { in: ids } } })`. Diagnóstico: `pg_stat_statements` ordenado por `calls` |
| **Função sobre coluna indexada** — `WHERE date(ocorrida_em) = '2026-01-01'` | O índice guarda `ocorrida_em`, não `date(ocorrida_em)`. É exatamente o caso 1 de Elmasri (cap. 20.2.3) com expressões aritméticas | Reescreva como range **sargable**: `WHERE ocorrida_em >= '2026-01-01' AND ocorrida_em < '2026-01-02'`. Ou `CREATE INDEX ON transacoes ((date(ocorrida_em)))` — que também gera estatísticas para a expressão |
| **Tipos incompatíveis** — `WHERE conta_id = '42'`, ou `bigint` vs `int` em junção | Elmasri, cap. 20.2.3, caso 1: "comparações numéricas de atributos de diferentes tamanhos e precisão". Coerção implícita pode impedir o uso do índice | Cast explícito do **lado da constante**, nunca da coluna. Com Prisma, o schema é a fonte: `BigInt` no Prisma ↔ `bigint` na FK. Uma FK `Int` apontando para PK `BigInt` é junção degradada silenciosa |
| **`OFFSET` alto** — `LIMIT 20 OFFSET 100000` | O banco produz e **descarta** 100.000 linhas para devolver 20. Custo cresce linearmente com a página. Não há índice que salve — o OFFSET é aplicado depois | **Keyset pagination**: `WHERE (ocorrida_em, id) < (:ultima_data, :ultimo_id) ORDER BY ocorrida_em DESC, id DESC LIMIT 20`. Custo constante. Com índice em `(ocorrida_em DESC, id DESC)` vira `Index Scan` + `Limit`, pipeline puro. Prisma: `cursor` + `skip: 1` |
| **`SELECT *`** | Mais bytes por linha → menos linhas por bloco (`bfr` menor de Elmasri) → mais blocos → mais E/S. E **impede `Index Only Scan`**: o índice cobre 2 colunas, você pediu 14, tem que ir ao heap. Contraria a heurística de empurrar π para baixo (regra 5 do cap. 19.7.2) | Liste as colunas. Prisma: `select: { id: true, valor_cents: true }`. O ganho maior é o `Index Only Scan` habilitado |
| **`NOT IN` com NULL** — `WHERE categoria_id NOT IN (SELECT id FROM categorias WHERE ...)` | Lógica ternária: se a subconsulta retorna **um único NULL**, `NOT IN` é `UNKNOWN` para toda linha e o resultado é **vazio**. Silencioso, sem erro. E impede o planner de usar anti-junção | `NOT EXISTS` — semântica correta com NULL **e** vira `Hash Anti Join`. Ou `LEFT JOIN ... WHERE x IS NULL`. **Nunca use `NOT IN` com subconsulta.** `categoria_id` é nullable no nosso esquema — é exatamente o campo de risco |
| **`OR` entre colunas diferentes** | Elmasri, cap. 19.3.1: se qualquer ramo não tem caminho de acesso, cai para varredura linear | `UNION ALL` dos ramos (cap. 20.2.4, item 1). O `BitmapOr` do PG resolve parte, mas só se **todos** os ramos tiverem índice |
| **`LIKE '%texto%'`** | Prefixo aberto → B-tree inútil (cap. 20.2.3, caso 1) | `LIKE 'texto%'` usa índice (com `text_pattern_ops` se o collation não for C). Busca no meio: `pg_trgm` + índice GIN |
| **`DISTINCT` para consertar junção duplicada** | Impõe `Sort`/`HashAggregate` (cap. 20.2.3, caso 3) | O problema é a junção. `EXISTS` em vez de `JOIN` quando você só quer filtrar |
| **Índice em coluna de baixa cardinalidade** — ex. `tipo` com 3 valores | `s = r/d` é enorme; custo `x + 1 + s` do S6 perde da varredura (Elmasri, cap. 19.8.3, caso `Sexo`) | Não crie. Ou crie **parcial** no valor raro: `WHERE tipo = 'estorno'`. Ou composto com uma coluna seletiva na frente |

### Checklist de diagnóstico

1. `pg_stat_statements` ordenado por `total_exec_time` → ache os 20% (regra 80-20, cap. 20.1.1).
2. `EXPLAIN (ANALYZE, BUFFERS)` na pior.
3. Ache o nó mais profundo com `rows` estimado ≠ real por > 10×. **Conserte isso primeiro** — tudo acima foi decidido com informação errada.
4. `ANALYZE` → ainda erra? `SET STATISTICS 1000` → ainda erra? `CREATE STATISTICS` com `dependencies`/`mcv`.
5. Estimativa boa e ainda lento? Aí sim olhe algoritmo: `Batches > 1`, `Sort Method: external`, `Heap Fetches` alto, `loops` alto.
6. Índice em falta: confira ordem das colunas no composto, e se um parcial ou `INCLUDE` resolve.
7. Antes de criar índice: quantas escritas essa tabela recebe? (cap. 20.1.1, item D — cada índice é custo em toda inserção).
8. `random_page_cost` e `effective_cache_size` estão calibrados para o hardware? Se não, o otimizador está sistematicamente enviesado contra índices.
