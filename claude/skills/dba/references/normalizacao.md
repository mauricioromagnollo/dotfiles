# Dependências funcionais e normalização

Abra esta referência para decidir **como agrupar atributos em tabelas**: ao modelar schema novo, ao revisar schema com dados duplicados ou inconsistentes, ao julgar se uma decomposição é segura, ou ao avaliar um pedido de desnormalização. Se a pergunta é "essa tabela está certa?", "posso quebrar isso em duas?" ou "vale duplicar esse campo?", a resposta está aqui.

Exemplos: finanças pessoais (contas, transações, categorias) em PostgreSQL.

---

## 1. As quatro diretrizes informais (Elmasri, cap. 15.1)

Detectam a maior parte dos problemas reais a olho nu, sem formalismo.

### Diretriz 1 — semântica clara

> Projete um esquema de relação de modo que seja fácil explicar seu significado. Não combine atributos de vários tipos de entidade e de relacionamento em uma única relação. (Elmasri, cap. 15.1.1)

Critério literal: **se você não explica a tabela em uma frase, ela está errada.** "Cada linha é uma transação" é bom. "Cada linha é uma transação com o nome da conta e o nome da categoria" é mistura de três entidades.

```sql
-- RUIM: mistura transação + conta + categoria
CREATE TABLE transacao_completa (
  id bigint PRIMARY KEY,
  conta_id bigint NOT NULL,
  conta_nome text NOT NULL,        -- atributo de CONTA
  conta_saldo numeric(14,2),       -- atributo de CONTA
  categoria_nome text NOT NULL,    -- atributo de CATEGORIA
  valor numeric(14,2) NOT NULL,
  ocorrida_em timestamptz NOT NULL
);

-- BOM: uma entidade por tabela, ligação por FK
CREATE TABLE conta     (id bigint PRIMARY KEY, nome text NOT NULL, saldo numeric(14,2) NOT NULL DEFAULT 0);
CREATE TABLE categoria (id bigint PRIMARY KEY, nome text NOT NULL UNIQUE);
CREATE TABLE transacao (
  id bigint PRIMARY KEY,
  conta_id bigint NOT NULL REFERENCES conta(id),
  categoria_id bigint NOT NULL REFERENCES categoria(id),
  valor numeric(14,2) NOT NULL,
  ocorrida_em timestamptz NOT NULL
);
```

Trade-off: a versão RUIM responde "transações com nome de conta" sem JOIN. **Decisão:** isso é problema de leitura, e leitura se resolve com VIEW/materialized view — não mudando a tabela base. O livro: "é aconselhável usar relações da base sem anomalias e especificar visões que incluem as junções para reunir os atributos frequentemente referenciados nas consultas importantes" (cap. 15.1.2).

### Diretriz 2 — sem anomalias de atualização

> Projete os esquemas de relação da base de modo que nenhuma anomalia de inserção, exclusão ou modificação esteja presente. Se houver alguma anomalia, anote-as claramente e cuide para que os programas que atualizam o banco de dados operem corretamente. (cap. 15.1.2)

Ver seção 2.

### Diretriz 3 — poucos NULLs

> Ao máximo possível, evite colocar atributos em uma relação da base cujos valores podem ser NULL com frequência. Se os NULLs forem inevitáveis, garanta que eles se apliquem apenas em casos excepcionais. (cap. 15.1.3)

Razões: desperdício de espaço; comportamento imprevisível em SELEÇÃO/JUNÇÃO (lógica de três valores); agregações (`COUNT`, `SUM`) que ignoram NULL silenciosamente. Pior: NULL é ambíguo — "não se aplica", "desconhecido", "conhecido mas não registrado" — e o SGBD representa os três igual.

Critério do livro: se só 15% das linhas têm o atributo, crie tabela separada só com as linhas que o têm.

```sql
-- RUIM: 95% das transações não são parceladas
CREATE TABLE transacao (
  id bigint PRIMARY KEY,
  valor numeric(14,2) NOT NULL,
  parcela_numero int,    -- NULL na esmagadora maioria
  parcela_total  int,    -- NULL
  parcela_grupo_id uuid  -- NULL
);

-- BOM: só existe linha quando o fato existe
CREATE TABLE transacao_parcelamento (
  transacao_id bigint PRIMARY KEY REFERENCES transacao(id) ON DELETE CASCADE,
  grupo_id uuid NOT NULL,
  numero int NOT NULL CHECK (numero >= 1),
  total  int NOT NULL CHECK (total  >= 1),
  CHECK (numero <= total)
);
```

Ganho colateral: os `CHECK` viram incondicionais. Na versão RUIM você escreveria `CHECK (parcela_numero IS NULL OR parcela_numero <= parcela_total)` — que não impede `numero` preenchido com `total` NULL.

**Nota prática:** no Prisma isso vira relação 1:1 opcional (`parcelamento Parcelamento?`) e o código para de espalhar `if (tx.parcelaNumero !== null)`.

### Diretriz 4 — nada de tuplas espúrias

> Projete esquemas de relação de modo que possam ser unidos com condições de igualdade sobre atributos que são pares relacionados corretamente (chave primária, chave estrangeira), de um modo que garanta que nenhuma tupla falsa será gerada. (cap. 15.1.4)

**Tupla espúria** = linha que aparece no JOIN mas não existe na realidade. Surge ao juntar por atributo que não é par (PK, FK) em nenhuma das tabelas.

```sql
CREATE TABLE tx_por_moeda (descricao text, moeda char(3));  -- PK (descricao, moeda)
CREATE TABLE tx_por_conta (id bigint PRIMARY KEY, conta_id bigint, valor numeric, moeda char(3));
```

`moeda` é o único atributo comum e não é chave em nenhuma. Junte por `moeda` e cada descrição em BRL cola com toda transação em BRL. A informação original é **irrecuperável**. Única diretriz não negociável; formalizada como junção não aditiva (seção 7).

---

## 2. Anomalias de inserção, remoção e atualização

```sql
CREATE TABLE transacao_conta (
  id bigint PRIMARY KEY,
  valor numeric(14,2) NOT NULL,
  ocorrida_em timestamptz NOT NULL,
  conta_id bigint NOT NULL,
  conta_nome text NOT NULL,
  conta_banco text NOT NULL,
  conta_titular text NOT NULL
);
```

**Inserção**, duas variantes (cap. 15.1.2):
1. Inserir transação na conta 7 exige repetir nome/banco/titular *corretamente*, coerentes com as outras linhas da conta 7. Nada força isso: digite "Nubnk" e a conta 7 passa a ter dois nomes.
2. **Não dá para cadastrar conta sem transações.** A saída seria uma linha com NULL em `valor`/`ocorrida_em` e `id` inventado — violando integridade de entidade. Conta recém-aberta é fato válido que o schema não sabe representar.

**Remoção:** apague a última transação da conta 7 e a conta 7 some do banco.

**Modificação:** titular muda de nome → atualizar todas as linhas de todas as transações da conta. Falhe em uma e a conta tem dois titulares. O livro nota ser a menos grave, "pois todas as tuplas podem ser atualizadas por uma única consulta SQL" — o risco é inconsistência transitória e custo de escrita.

**Decisão:** as três somem quando cada fato é armazenado **exatamente uma vez**. Formas normais são só testes mecânicos para verificar se você chegou lá.

---

## 3. Dependência funcional

> Uma dependência funcional X → Y entre conjuntos de atributos X e Y subconjuntos de R especifica que, para quaisquer duas tuplas t₁ e t₂ em r com t₁[X] = t₂[X], elas também devem ter t₁[Y] = t₂[Y]. (cap. 15.2.1)

**Se duas linhas concordam em X, obrigatoriamente concordam em Y.** X é o determinante (lado esquerdo).

Dois fatos que economizam tempo:
- X chave candidata de R ⇒ X → R (determina tudo).
- X → Y **não** implica Y → X.

### DF é semântica, não é dado

> Uma dependência funcional é uma propriedade do esquema de relação R, e não um estado de relação válido e específico r de R. Portanto, uma DF não pode ser deduzida automaticamente por determinada extensão de relação r, mas deve ser definida de maneira explícita por alguém que conhece a semântica dos atributos. (cap. 15.2.1)

A assimetria é o que importa:
- Você **nunca prova** uma DF olhando dados. Se hoje todo CEP tem uma cidade, é coincidência do dataset.
- Você **refuta** com um único contraexemplo: duas linhas, mesmo X, Y diferente.

Corolário: ferramenta de "descoberta automática de DFs" devolve as DFs válidas *naquele estado*. Fonte de hipóteses, não de decisões.

DFs em `transacao`:
```
transacao_id → {valor, ocorrida_em, conta_id, categoria_id}
conta_id     → {conta_nome, conta_banco, titular_id}
categoria_id → {categoria_nome, categoria_tipo}
titular_id   → titular_email
```
Por transitividade, `conta_id → titular_email` vale sem ser declarada.

### 3.1 Regras de inferência (cap. 16.1.1)

O conjunto declarado é `F`; o de todas as DFs deriváveis é o **fechamento** `F⁺`.

| Regra | Nome | Enunciado |
|---|---|---|
| RI1 | reflexiva | se X ⊇ Y, então X → Y |
| RI2 | aumento | {X → Y} ⊨ XZ → YZ |
| RI3 | transitiva | {X → Y, Y → Z} ⊨ X → Z |
| RI4 | decomposição | {X → YZ} ⊨ X → Y |
| RI5 | união | {X → Y, X → Z} ⊨ X → YZ |
| RI6 | pseudotransitiva | {X → Y, WY → Z} ⊨ WX → Z |

RI1–RI3 são as **regras de Armstrong**: *legítimas* (só derivam DFs verdadeiras) e *completas* (derivam todas). RI4–RI6 são convenientes mas deriváveis delas — não são poder extra.

**Armadilhas explícitas no livro:**
- X → A e Y → B **não** implicam XY → AB.
- XY → A **não** implica X → A nem Y → A.

Errar isso produz decomposições inválidas. Na dúvida, calcule o fechamento.

### 3.2 Fechamento de atributos (X⁺) — Algoritmo 16.1

`X⁺` = todos os atributos determinados por X dado F. Ferramenta mais útil do capítulo: testa chave, forma normal e equivalência.

```
entrada: conjunto F de DFs, conjunto de atributos X
X⁺ := X
repita
  oldX⁺ := X⁺
  para cada DF Y → Z em F:
      se X⁺ ⊇ Y então X⁺ := X⁺ ∪ Z
até (X⁺ = oldX⁺)
```

**Passo a passo.** `R = {tx_id, conta_id, conta_nome, titular_id, titular_email, categoria_id, categoria_nome, valor}`
```
F = { tx_id → {conta_id, categoria_id, valor}, conta_id → {conta_nome, titular_id},
      titular_id → titular_email, categoria_id → categoria_nome }
```
Calcular `{tx_id}⁺`:

| Passada | DF aplicada | X⁺ depois |
|---|---|---|
| início | — | `{tx_id}` |
| 1 | `tx_id → conta_id, categoria_id, valor` | `{tx_id, conta_id, categoria_id, valor}` |
| 1 | `conta_id → conta_nome, titular_id` | `+ conta_nome, titular_id` |
| 1 | `categoria_id → categoria_nome` | `+ categoria_nome` |
| 2 | `titular_id → titular_email` | `+ titular_email` |
| 3 | nada muda | estável — para |

`{tx_id}⁺ = R` ⇒ **`tx_id` é superchave**; atributo único ⇒ chave candidata.
`{conta_id}⁺ = {conta_id, conta_nome, titular_id, titular_email}` — não contém `valor` ⇒ não é superchave. Prova formal de que `conta_nome` não pertence à tabela de transações.

### 3.3 Achar uma chave — Algoritmo 16.2(a)

```
Ch := R
para cada atributo A em Ch:
    se (Ch − A)⁺ contém todos os atributos de R:
        Ch := Ch − {A}
```
Cuidado documentado: devolve **uma** chave, não todas — e qual depende da ordem de remoção.

### 3.4 Equivalência e cobertura (cap. 16.1.2)

- **F cobre E**: toda DF de E é deduzível de F (E ⊆ F⁺).
- **F e E equivalentes**: F⁺ = E⁺ — F cobre E **e** E cobre F.

Teste de "F cobre E": para cada `X → Y` em E, calcule `X⁺` **usando F**; se `X⁺ ⊇ Y` sempre, F cobre E. Repita ao contrário para equivalência.

### 3.5 Cobertura mínima (canônica) — Algoritmo 16.2

F é **mínimo** se (cap. 16.1.3):
1. Toda DF tem **um único atributo** no lado direito.
2. Nenhuma `X → A` pode virar `Y → A` com Y ⊂ X mantendo equivalência (sem atributo redundante à esquerda).
3. Nenhuma DF pode ser removida mantendo equivalência (sem DF redundante).

**Cobertura mínima** de E = conjunto mínimo equivalente a E. Sempre existe ≥1; **podem existir várias**, e coberturas diferentes geram schemas diferentes (seção 8.3).

```
1. F := E
2. substitua cada X → {A₁,…,Aₙ} pelas n DFs X → A₁, …, X → Aₙ
3. para cada X → A em F:
       para cada atributo B de X:
           se {F − (X→A)} ∪ {(X−{B}) → A} for equivalente a F:
               substitua X → A por (X−{B}) → A      -- poda lado esquerdo
4. para cada X → A restante em F:
       se F − {X→A} for equivalente a F:
           remova X → A                              -- poda DF inteira
```

**Passo a passo** (exemplo do livro). E = `{B → A, D → A, AB → D}`.
- Etapa 2: todas já com lado direito único.
- Etapa 3: `AB → D` tem lado esquerdo redundante? De `B → A`, aumentando com B (RI2): `B → AB` **(i)**; `AB → D` é dado **(ii)**; transitividade (RI3) em (i)+(ii) dá `B → D`. Logo `AB → D` vira `B → D`. Agora `E' = {B → A, D → A, B → D}`.
- Etapa 4: de `B → D` e `D → A`, transitividade dá `B → A` ⇒ redundante, sai.
- **Cobertura mínima: `{B → D, D → A}`.**

Desempate entre várias mínimas: o livro sugere a de menor número de DFs ou menor tamanho total. **Nota prática:** prefira a que produz tabelas alinhadas às entidades do domínio — o algoritmo não conhece o negócio.

---

## 4. Chaves (cap. 15.3.3)

- **Superchave** S ⊆ R: duas tuplas distintas nunca têm `t₁[S] = t₂[S]`. Não precisa ser mínima.
- **Chave**: superchave da qual remover qualquer atributo destrói a propriedade (mínima).
- **Chave candidata**: cada chave, quando há mais de uma.
- **Chave primária**: a candidata escolhida arbitrariamente; as outras, secundárias.
- **Atributo primo**: membro de *alguma* candidata. **Não primo**: de nenhuma.

Sem candidata conhecida, a relação inteira é superchave por default.

```sql
CREATE TABLE conta_bancaria (
  id bigint PRIMARY KEY,                    -- candidata 1
  banco_codigo char(3) NOT NULL,
  agencia text NOT NULL,
  numero  text NOT NULL,
  titular_id bigint NOT NULL,
  saldo numeric(14,2) NOT NULL,
  UNIQUE (banco_codigo, agencia, numero)    -- candidata 2
);
```
Primos: `id`, `banco_codigo`, `agencia`, `numero`. Não primos: `titular_id`, `saldo`. `{id, saldo}` é superchave e **não** é chave.

Importa porque **2FN, 3FN e BCNF são definidas em termos de "primo" e "superchave"** — errar a lista de candidatas invalida o diagnóstico inteiro.

---

## 5. Formas normais

### 5.1 Primeira forma normal (cap. 15.3.4)

> O domínio de um atributo deve incluir apenas valores atômicos (simples, indivisíveis) e o valor de qualquer atributo em uma tupla deve ser um único valor do domínio.

Proíbe: conjunto de valores, tupla de valores, relações aninhadas.

```sql
-- NÃO está em 1FN
CREATE TABLE transacao (id bigint PRIMARY KEY, valor numeric(14,2),
                        tags text);  -- 'mercado, essencial, recorrente'
```

**Três estratégias de correção**, em ordem de qualidade:

**1. Tabela separada com PK propagada — a melhor.** Sem redundância, sem limite de cardinalidade.
```sql
CREATE TABLE transacao_tag (
  transacao_id bigint NOT NULL REFERENCES transacao(id) ON DELETE CASCADE,
  tag text NOT NULL,
  PRIMARY KEY (transacao_id, tag)
);
```
**2. Expandir a chave** — PK vira `{transacao_id, tag}` na própria tabela; repete os demais atributos em cada linha. O livro nota que ela acaba decomposta na solução 1 nas etapas seguintes — pule direto.
**3. Colunas fixas** (`tag1`, `tag2`, `tag3`) — introduz NULLs, semântica falsa de ordenação, e consultas ruins ("transações com tag 'essencial'" vira OR de três colunas). Evite.

**Relações aninhadas.** Para `TRANSACAO(id, valor, {RATEIOS(categoria_id, percentual)})`: remova os atributos aninhados para nova tabela e **propague a PK**; a nova PK combina a chave parcial (`categoria_id`) com a PK original. Aplique recursivamente em múltiplos níveis.
```sql
CREATE TABLE transacao_rateio (
  transacao_id bigint NOT NULL REFERENCES transacao(id) ON DELETE CASCADE,
  categoria_id bigint NOT NULL REFERENCES categoria(id),
  percentual numeric(5,2) NOT NULL CHECK (percentual > 0 AND percentual <= 100),
  PRIMARY KEY (transacao_id, categoria_id)
);
```

**Dois multivalorados independentes: cuidado.** Para `PESSOA(cpf, {placa}, {telefone})`, a estratégia 2 gera `PESSOA_1FN(cpf, placa, telefone)`, que precisa de **todas as combinações** placa × telefone por CPF só para não inventar relação entre placa e telefone. O certo é a estratégia 1 com **duas** tabelas: `P1(cpf, placa)`, `P2(cpf, telefone)`. É o problema que a 4FN formaliza (seção 6).

**Nota prática — 1FN e PostgreSQL.** `jsonb`, `text[]` e tipos compostos violam a 1FN clássica. Não são proibidos, mas custam o que a 1FN prometia: sem FK (não existe FK de dentro de array), sem CHECK por elemento, sem estatísticas por valor, consultas viram operadores de contenção. O livro registra que objetos complexos e XML "tentam permitir e formalizar as relações aninhadas" — a teoria não é dogma. **Critério:** `jsonb` quando o conteúdo é opaco ao banco (payload de webhook, resposta de open banking guardada para auditoria) e nunca será filtrado, agregado ou referenciado. Se vai consultar por dentro ou garantir integridade, normalize.

### 5.2 Segunda forma normal (cap. 15.3.5, 15.4.1)

- `X → Y` **total**: remover qualquer atributo de X quebra a dependência.
- `X → Y` **parcial**: existe A ∈ X com `(X − {A}) → Y` ainda valendo.

> R está em 2FN se cada atributo não primo A não for parcialmente dependente de *qualquer* chave de R.

**Só se aplica com chave composta.** Chave de atributo único ⇒ 2FN automática.

```sql
-- Chave: {transacao_id, categoria_id}
CREATE TABLE transacao_rateio (
  transacao_id bigint,
  categoria_id bigint,
  percentual numeric(5,2) NOT NULL,
  categoria_nome text NOT NULL,   -- depende só de categoria_id → PARCIAL
  transacao_valor numeric(14,2),  -- depende só de transacao_id  → PARCIAL
  PRIMARY KEY (transacao_id, categoria_id)
);
```
Anomalia: renomear categoria exige atualizar toda linha de rateio dela.

**Correção** — cada não primo vai para a relação da parte da chave da qual depende totalmente: `transacao_rateio(transacao_id, categoria_id, percentual)`, com `categoria_nome` em `categoria` e `transacao_valor` em `transacao`.

### 5.3 Terceira forma normal (cap. 15.3.6, 15.4.2)

**Dependência transitiva**: `X → Y` é transitiva se existe Z que **não é candidata nem subconjunto de chave** com `X → Z` e `Z → Y`.

> R está em 3FN se, toda vez que uma DF não trivial X → A se mantiver em R, então **(a)** X é superchave de R, **ou** **(b)** A é atributo primo de R.

Alternativa equivalente: todo não primo é (i) total e funcionalmente dependente de cada chave e (ii) não transitivamente dependente de cada chave.

Duas formas de violar (cap. 15.4.3): **não primo determina não primo** (transitiva); **subconjunto próprio de chave determina não primo** (parcial — viola 2FN também).

```sql
CREATE TABLE conta (
  id bigint PRIMARY KEY,
  nome text NOT NULL,
  titular_id bigint NOT NULL,
  titular_email text NOT NULL,   -- id → titular_id → titular_email
  titular_cpf text NOT NULL
);
```
`titular_id` não é chave nem parte de chave e determina `titular_email` ⇒ transitiva ⇒ viola 3FN. Anomalias: e-mail repetido em cada conta; mudar exige N updates; titular sem conta não pode existir.

**Correção** — tire o atributo violador e coloque junto com o lado esquerdo que causa a transitividade:
```sql
CREATE TABLE titular (id bigint PRIMARY KEY, email text NOT NULL, cpf text NOT NULL UNIQUE);
CREATE TABLE conta   (id bigint PRIMARY KEY, nome text NOT NULL,
                      titular_id bigint NOT NULL REFERENCES titular(id));
```

**Ordem não importa.** O livro: "as dependências transitiva e parcial que violam a 3FN podem ser removidas em qualquer ordem"; a definição geral "pode ser aplicada diretamente para testar se um esquema está na 3FN (este não precisa passar pela 2FN primeiro)". A sequência 1FN→2FN→3FN é histórica. **Teste 3FN/BCNF direto.**

### 5.4 Boyce-Codd (BCNF/FNBC) (cap. 15.5)

> R está na FNBC se, toda vez que uma DF **não trivial** X → A se mantiver em R, então **X é superchave de R**.

A diferença para 3FN é uma linha: **a condição (b) "A é primo" sumiu.** Logo BCNF é estritamente mais forte: toda BCNF está em 3FN, não o inverso.

**Quando 3FN ≠ BCNF:** só quando existe `X → A` com X não superchave **e** A primo. Raro — "na prática, a maioria dos esquemas de relação que estão na 3FN também estão na FNBC". Toda relação de dois atributos está automaticamente em BCNF.

Exemplo — orçamento mensal por categoria, com a regra "cada meta pertence a exatamente uma categoria":
```sql
CREATE TABLE orcamento (
  mes date NOT NULL, categoria_id bigint NOT NULL, meta_id bigint NOT NULL,
  PRIMARY KEY (mes, categoria_id)
);
-- DF1: {mes, categoria_id} → meta_id
-- DF2: meta_id → categoria_id          (regra de negócio)
```
Candidatas: `{mes, categoria_id}` e `{mes, meta_id}`. **Todos os atributos são primos**, nenhum é não primo ⇒ está em 3FN trivialmente (condição (b) sempre satisfeita). Mas DF2 tem `meta_id` não superchave ⇒ **viola BCNF**, e a redundância é real: a associação meta→categoria se repete todo mês.

**Correção e o preço.** As três decomposições binárias possíveis **todas perdem DF1**:
1. `{mes, meta_id}` + `{mes, categoria_id}`
2. `{categoria_id, meta_id}` + `{categoria_id, mes}`
3. `{meta_id, categoria_id}` + `{meta_id, mes}` ← **escolhida**

A 3 é a única que **não gera tuplas espúrias na junção** (satisfaz NJB — seção 7.4). É o que o Algoritmo 16.5 produz.
```sql
CREATE TABLE meta     (id bigint PRIMARY KEY,
                       categoria_id bigint NOT NULL REFERENCES categoria(id));  -- DF2 via FK
CREATE TABLE meta_mes (meta_id bigint NOT NULL REFERENCES meta(id), mes date NOT NULL,
                       PRIMARY KEY (meta_id, mes));
```
DF1 não é mais imposta por tabela alguma — nada impede duas metas da mesma categoria no mesmo mês; checá-la exige juntar as duas.

**Trade-off nu:** BCNF elimina redundância mas **abre mão da preservação de dependências**. Critério na seção 8.4.

---

## 6. 4FN e 5FN — "isso aparece na vida real?"

### 4FN e dependência multivalorada (cap. 15.6)

> Se t₁ e t₂ existem em r com t₁[X] = t₂[X], então t₃ e t₄ também devem existir com t₃[X]=t₄[X]=t₁[X], t₃[Y]=t₁[Y], t₄[Y]=t₂[Y], t₃[Z]=t₂[Z], t₄[Z]=t₁[Z] — onde Z = R − (X ∪ Y).

Operacionalmente: **quando dois relacionamentos 1:N independentes são misturados em R(A,B,C), surge uma MVD** — notada `A ↠ B | C`. Ela força materializar o produto cartesiano de B por C para cada A, só para não inventar correlação entre B e C.

> R está na 4FN se, para cada MVD não trivial X ↠ Y em F⁺, X for superchave de R.

```sql
-- VIOLA 4FN: conta tem N titulares e N cartões, independentes
CREATE TABLE conta_titular_cartao (
  conta_id bigint, titular_cpf text, cartao_final char(4),
  PRIMARY KEY (conta_id, titular_cpf, cartao_final)
);
```
Conta com 3 titulares e 4 cartões ⇒ 12 linhas para 7 fatos. Anomalia: adicionar um cartão exige **3** INSERTs (um por titular); esquecer um torna a tabela incoerente, implicando relação titular–cartão inexistente.

**Correção** — uma relação por MVD, onde ela vira trivial:
```sql
CREATE TABLE conta_titular (conta_id bigint, titular_cpf text,     PRIMARY KEY (conta_id, titular_cpf));
CREATE TABLE conta_cartao  (conta_id bigint, cartao_final char(4), PRIMARY KEY (conta_id, cartao_final));
```
7 linhas em vez de 12; adicionar cartão = 1 INSERT.

Fatos úteis: relações com MVD não trivial tendem a ser **all-key**; all-key está sempre em BCNF (não tem DF alguma) — por isso 4FN existe. Toda DF é uma MVD (RI7), com a restrição extra de no máximo um valor de Y por X.

**Aparece na vida real?** Sim — é o caso de 4FN/5FN que vale conhecer. Surge de 1FN mal feita: você achatou dois multivalorados independentes na mesma tabela. O livro diz ser "raro que essas relações de todas as chaves com uma ocorrência combinatória de valores repetidos sejam projetadas na prática", mas "o reconhecimento das MVDs é essencial no projeto relacional". **Regra de bolso:** tabela de junção com **três** colunas na PK e as colunas 2 e 3 sem nada a ver uma com a outra ⇒ MVD.

### 5FN e dependência de junção (cap. 15.7)

> Uma DJ(R₁,…,Rₙ) sobre R determina que cada estado válido r de R deve ter decomposição de junção não aditiva para R₁,…,Rₙ. R está em 5FN se, para cada DJ não trivial em F⁺, cada Rᵢ for superchave de R.

Caso raro em que R **não** tem decomposição binária sem perdas, mas **tem** ternária. MVD é o caso especial n=2. Exemplo canônico (FORNECE): "sempre que f fornece a peça p, e o projeto j usa p, e f fornece ao menos uma peça a j, então f fornece p a j". Junte duas das três projeções → tuplas espúrias; junte as três → não.

**Aparece na vida real? Praticamente nunca.** O livro é categórico: "restrição semântica bastante peculiar, muito difícil de detectar na prática. Portanto, a normalização para a 5FN raramente é feita nestes termos"; "a descoberta de DJs em bancos de dados práticos com centenas de atributos é quase impossível" — restando à 5FN "valor mais teórico".

### Onde parar

> O projeto de banco de dados praticado na indústria hoje presta atenção particular à normalização apenas até a 3FN, FNBC ou, no máximo, 4FN. (cap. 15.3.2)

**Decisão:** mire BCNF. Aceite 3FN quando BCNF custar preservação de dependências (8.4). Verifique 4FN ao ver tabela all-key de 3+ colunas. Ignore 5FN salvo prova em contrário. E: "obter o status de normalização apenas de 1FN ou 2FN não é considerado adequado" — são degraus, não destinos.

---

## 7. Propriedades de uma decomposição

Verificar cada tabela isoladamente **não basta**: `FUNC_LOCAL(Fnome, Projlocal)` tem dois atributos, logo está em BCNF — e ainda assim produz tuplas espúrias ao juntar (cap. 16.2.1). D = {R₁,…,Rₘ} precisa de propriedades coletivas. **Preservação de atributos** (mínimo): ∪Rᵢ = R.

### 7.1 Preservação de dependências (cap. 16.2.2)

> D preserva dependências em relação a F se a união das projeções de F sobre cada Rᵢ for equivalente a F: `((π_R₁(F)) ∪ … ∪ (π_Rₘ(F)))⁺ = F⁺`

Onde `π_Rᵢ(F)` = DFs `X → Y` de F⁺ com X∪Y inteiramente contido em Rᵢ. Não precisa que as DFs originais apareçam literalmente — basta a união ser **equivalente**.

**Por que importa:** cada DF é uma restrição de negócio. Se não cabe em nenhuma tabela, não dá para impô-la com UNIQUE/FK/CHECK local; validar exigiria juntar tabelas a cada escrita — "uma opção que não é prática".

**Afirmação 1:** **sempre é possível** achar decomposição que preserva dependências com todas as relações em **3FN** (não BCNF).

### 7.2 Junção não aditiva / lossless (cap. 16.2.3)

> D tem a propriedade de junção sem perda em relação a F se, para cada estado r de R que satisfaça F: `*(π_R₁(r), …, π_Rₘ(r)) = r`

Vocabulário: "perda" é **perda de informação, não de tuplas** — sem a propriedade você ganha linhas a mais (espúrias). Por isso "junção não aditiva" é o termo preferido.

> A propriedade de junção não aditiva é extremamente crítica e deve ser alcançada a todo custo, ao passo que a propriedade de preservação de dependência, embora desejável, às vezes é sacrificada. (cap. 15.3.1)

**Esse é o ranking.** Lossless não é negociável; preservação de DFs é.

### 7.3 Teste geral — Algoritmo 16.3

```
entrada: R, decomposição D = {R₁,…,Rₘ}, conjunto F de DFs
1. matriz S: uma linha i por relação Rᵢ, uma coluna j por atributo Aⱼ de R
2. S(i,j) := bᵢⱼ  em todas as células          -- símbolo distinto por célula
3. para cada linha i, coluna j:
       se Rᵢ contém Aⱼ então S(i,j) := aⱼ      -- símbolo distinto por coluna
4. repita até uma passada completa não mudar nada:
       para cada DF X → Y em F:
           para todas as linhas que coincidem nas colunas de X:
               iguale os símbolos nas colunas de Y:
                   se alguma linha tem 'a' na coluna, propague 'a' às outras
                   senão, escolha um 'b' e propague às outras
5. alguma linha só com 'a' → lossless. Senão → não.
```

**Passo a passo.** `R = {tx_id, categoria_id, categoria_nome, valor}`, `F = { tx_id → {categoria_id, valor}, categoria_id → categoria_nome }`. Decomposição: `R₁ = {tx_id, categoria_id, valor}`, `R₂ = {categoria_id, categoria_nome}`.

Matriz inicial (etapas 1–3):

| | tx_id | categoria_id | categoria_nome | valor |
|---|---|---|---|---|
| R₁ | a₁ | a₂ | b₁₃ | a₄ |
| R₂ | b₂₁ | a₂ | a₃ | b₂₄ |

Etapa 4, aplicando `categoria_id → categoria_nome`: as linhas coincidem em `categoria_id` (ambas `a₂`); R₂ tem `a₃` em `categoria_nome` ⇒ propague `a₃` para R₁:

| | tx_id | categoria_id | categoria_nome | valor |
|---|---|---|---|---|
| R₁ | a₁ | a₂ | **a₃** | a₄ |
| R₂ | b₂₁ | a₂ | a₃ | b₂₄ |

**Linha R₁ toda 'a' ⇒ lossless.** Pode parar.

Contraste — a decomposição ruim da seção 1: nenhuma DF tem `moeda` no lado esquerdo, o loop não muda símbolo algum, nenhuma linha fica toda 'a' ⇒ **não é lossless**, e a matriz final é o contraexemplo que prova.

### 7.4 Decomposições binárias — Propriedade NJB (cap. 16.2.4)

Muito mais barato, mas só para **duas** relações:

> D = {R₁, R₂} é lossless em relação a F **se e somente se**
> `(R₁ ∩ R₂) → (R₁ − R₂)` ∈ F⁺ **ou** `(R₁ ∩ R₂) → (R₂ − R₁)` ∈ F⁺

Em português: **o que as duas tabelas têm em comum precisa ser chave de pelo menos uma delas.** É o formalismo da Diretriz 4.

Aplicando ao BCNF da seção 5.4, opção 3: `R₁ = {meta_id, categoria_id}`, `R₂ = {meta_id, mes}`. Interseção `{meta_id}`; `R₁ − R₂ = {categoria_id}`; `meta_id → categoria_id` é DF2 ✓ ⇒ lossless. Opções 1 e 2 falham — por isso a 3 é a desejável.

Generalização para MVDs, **NJB'** (cap. 16.5.3): R₁, R₂ são lossless em relação a F (DFs + MVDs) sse `(R₁ ∩ R₂) ↠ (R₁ − R₂)` ou `(R₁ ∩ R₂) ↠ (R₂ − R₁)`. Corolário: decompor por uma MVD `X ↠ Y` em `R₁ = (X ∪ Y)`, `R₂ = (R − Y)` é **sempre** lossless.

### 7.5 Decomposições sucessivas — Afirmação 2 (cap. 16.2.5)

Se D é lossless em relação a F, e Dᵢ é lossless para Rᵢ em relação à projeção de F sobre Rᵢ, então substituir Rᵢ por Dᵢ dentro de D preserva lossless no todo.

**Lossless compõe.** Decomponha em etapas, testando localmente com a NJB, sem reexecutar o 16.3 no schema inteiro.

---

## 8. Algoritmos de projeto

### 8.1 Algoritmo 16.4 — síntese 3FN preservando dependências

```
1. ache uma cobertura mínima G para F                (Algoritmo 16.2)
2. para cada lado esquerdo X em G:
       crie relação {X ∪ {A₁} ∪ … ∪ {Aₖ}}, onde X → A₁, …, X → Aₖ
       são as únicas DFs de G com X à esquerda   (X é a chave dessa relação)
3. coloque os atributos restantes em uma única relação (preservação de atributos)
```
**Afirmação 3:** tudo em 3FN; preserva dependências; **não garante lossless.**

**Passo a passo** (cap. 16.3.1). `U(Func_cpf, Pnr, Fsal, Ftelefone, Dnr, Projnome, Projlocal)`
```
DF1: Func_cpf → {Fsal, Ftelefone, Dnr}
DF2: Pnr → {Projnome, Projlocal}
DF3: {Func_cpf, Pnr} → {Fsal, Ftelefone, Dnr, Projnome, Projlocal}
```
Etapa 1 — na poda de lado esquerdo, `Pnr` é redundante em DF3 para `Fsal, Ftelefone, Dnr` (basta `Func_cpf`) e `Func_cpf` é redundante para `Projnome, Projlocal` (basta `Pnr`) ⇒ **DF3 inteiramente redundante**.
`G = {Func_cpf → Fsal, Ftelefone, Dnr;  Pnr → Projnome, Projlocal}`

Etapa 2 — dois lados esquerdos: `R₁(Func_cpf, Fsal, Ftelefone, Dnr)`, `R₂(Pnr, Projnome, Projlocal)`

**E o algoritmo falha.** `{Func_cpf, Pnr}` era chave de U — o relacionamento M:N **sumiu**; nenhuma relação o contém. "Embora o algoritmo preserve as dependências, ele não garante a preservação de toda a informação. Logo, o projeto resultante é um projeto com perda."

**Não use o 16.4.** Existe para motivar o 16.6.

### 8.2 Algoritmo 16.6 — síntese 3FN com lossless **e** preservação

```
1. ache uma cobertura mínima G para F                       (Algoritmo 16.2)
2. para cada lado esquerdo X em G: crie relação {X ∪ {A₁} ∪ … ∪ {Aₖ}}, X é a chave
3. se nenhuma relação em D contém uma chave de R:
       crie mais uma relação com os atributos de uma chave de R   (Alg. 16.2a)
4. elimine relações redundantes: R é redundante se for projeção de outra S do schema
```
Entrega **preserva dependências + lossless + tudo em 3FN**. É o algoritmo de síntese que você usa: "como o Algoritmo 16.6 alcança as duas propriedades desejáveis [...] ela é preferida em relação ao Algoritmo 16.4" (cap. 16.3.3).

**Exemplo 1** — mesmo U. Etapas 1–2 idênticas. Etapa 3: nenhuma relação contém a chave `{Func_cpf, Pnr}` ⇒ crie `R₃(Func_cpf, Pnr)`:
```
R₁(Func_cpf, Fsal, Ftelefone, Dnr)
R₂(Pnr, Projnome, Projlocal)
R₃(Func_cpf, Pnr)          -- o relacionamento M:N, recuperado
```

### 8.3 Algoritmo 16.5 — decomposição BCNF com lossless

```
1. D := {R}
2. enquanto existe esquema Q em D fora da BCNF:
       determine uma DF X → Y em Q que viole BCNF
       substitua Q em D pelos dois esquemas (Q − Y) e (X ∪ Y)
```
Entrega **tudo em BCNF + lossless**: cada passo é binário com interseção X, e `X → Y` vale por construção ⇒ NJB satisfeita; pela Afirmação 2 o todo é lossless. **Não garante preservação de dependências.**

**Testar se Q está em BCNF**, dois métodos: (a) para cada DF `X → Y` em Q, calcule `X⁺`; se não contém todos os atributos de Q, X não é superchave ⇒ violação; (b) sempre que Q viola BCNF existe par A, B com `(Q − {A,B}) → A` — calcule `(Q − {A,B})⁺` para cada par e veja se inclui A ou B.

**Passo a passo** — o `orcamento` da seção 5.4. `Q = {mes, categoria_id, meta_id}`, `F = {DF1: {mes,categoria_id} → meta_id, DF2: meta_id → categoria_id}`.
- `{meta_id}⁺ = {meta_id, categoria_id}` ⊉ Q ⇒ `meta_id` não é superchave ⇒ **DF2 viola BCNF**.
- Substitua Q por `(Q − Y)` e `(X ∪ Y)`, X=`{meta_id}`, Y=`{categoria_id}`: `{mes, meta_id}` e `{meta_id, categoria_id}`.
- Ambos em BCNF (dois atributos). Fim — a opção 3 da seção 5.4, e DF1 se perdeu.

**Não determinismo documentado** (cap. 16.4.2): o 16.5 **depende da ordem** em que as DFs são testadas; o 16.6 depende de **qual** cobertura mínima você escolheu — "como costuma haver muitas coberturas mínimas correspondentes a F, o algoritmo pode dar origem a diferentes projetos. Alguns desses projetos podem não ser desejáveis."

**Corolário:** são assistentes, não oráculos. Rode, olhe o resultado, aplique julgamento de domínio.

### 8.4 O trade-off central

> Não é possível ter todos os três a seguir: (1) projeto sem perdas garantido, (2) preservação de dependência garantida e (3) todas as relações na FNBC. A primeira condição é essencial e não pode ser comprometida. A segunda é desejável, mas não essencial, e pode ter de ser relaxada se insistirmos em obter a FNBC. (cap. 16.3.3)

| Algoritmo | Lossless | Preserva DFs | Forma normal |
|---|---|---|---|
| 16.4 | ✗ | ✓ | 3FN |
| 16.5 | ✓ | ✗ | BCNF |
| **16.6** | **✓** | **✓** | **3FN** |
| 16.7 | ✓ | ✗ | 4FN |

**Critério de decisão, na ordem:**
1. **Lossless join: obrigatório.** Sem discussão.
2. **Rode o 16.6** — 3FN + as duas propriedades.
3. **Teste cada relação do resultado para BCNF.** A maioria passa.
4. **Para as que falharem:**
   - DF perdida é imponível de outro jeito (CHECK, trigger, unique parcial, invariante numa transação)? → **BCNF** com o 16.5.
   - DF perdida é regra central que precisa ser imposta no banco a cada escrita? → **fique em 3FN** e documente a anomalia.
   - Redundância grande e volátil? → **BCNF**, imponha a DF na aplicação.
   - Redundância pequena sobre dados estáveis? → **3FN** é aceitável.

O livro autoriza a parada: "Se algum esquema de relação Rᵢ não estiver na FNBC, podemos decidir decompô-la ainda mais e deixá-la como se encontra na 3FN (com algumas possíveis anomalias de atualização)" (cap. 16.4.2).

### 8.5 Duas ressalvas

**Toda a teoria de lossless assume ausência de NULL nos atributos de junção**: "a teoria de decomposições de junção não aditiva está baseada na suposição de que nenhum valor NULL é permitido para os atributos de junção" (cap. 16.3.3). FK nullable **quebra a garantia** — a JUNÇÃO NATURAL descarta essas linhas silenciosamente. Se `transacao.conta_id` é nullable, `transacao ⋈ conta` perde toda transação sem conta. Use FK `NOT NULL` sempre que possível; onde não der, LEFT JOIN consciente.

**Tuplas suspensas** (cap. 16.4.1): decompondo demais, uma entidade pode existir em R₁ e não em R₂ — e sumir no INNER JOIN. Verifique se cada decomposição paga por si.

---

## 9. Desnormalização

> Desnormalização é o processo de armazenar a junção de relações na forma normal mais alta como uma relação da base, que está em uma forma normal mais baixa. (cap. 15.3.2)

Mecânica: inclui-se atributos de S em R porque as duas são consultadas juntas com frequência. "Isso reintroduz a redundância nas tabelas da base. Agora, existe uma dependência funcional parcial ou uma dependência transitiva na tabela R, criando assim os problemas de redundância associados" (cap. 20.1.2).

### Quando é legítima

> Esses ideais às vezes são sacrificados em favor de uma execução mais rápida de consultas e transações **que ocorrem com frequência**. (cap. 20.1.2)

> As relações podem ser deixadas em um estado de normalização inferior, como 2FN, por questões de desempenho. Fazer isso gera as penalidades correspondentes de lidar com as anomalias. (cap. 15.3.2)

Legítima quando **todas** valem: a consulta é frequente e comprovadamente cara (você mediu); os atributos duplicados são estáveis; o dilema pende para o join. O livro nomeia: "existe um dilema entre a atualização adicional necessária para manter a consistência dos atributos redundantes e o esforço necessário para realizar uma junção".

Casos nomeados (cap. 20.1.2, 20.2.2):
1. Colar atributos de S em R para matar um JOIN recorrente (o exemplo `TAREFA` — relação em 1FN que espelha os cabeçalhos de um relatório).
2. **Armazenar tabelas extras para manter DFs perdidas na decomposição BCNF** — guardar `ENSINA` além de `E1` e `E2` "reduz o projeto da FNBC para 3FN". Desnormalização como remédio para o trade-off de 8.4; "uma redundância extrema", nas palavras do livro: toda atualização em E1/E2 tem que ser aplicada em ENSINA.

### O que custa

Exatamente a seção 2: anomalias de inserção, remoção e modificação **voltam todas**. Você trocou consistência automática por velocidade de leitura, e a dívida é paga em código de escrita — para sempre, por todo dev que tocar a tabela, inclusive os que não sabem da duplicação.

### Como controlar

**Esgote as alternativas, nesta ordem:**
1. **Índice.** Muito JOIN lento é FK sem índice. Meça primeiro.
2. **VIEW.** Resolve ergonomia, não performance: "isso não significa que as operações de junção serão evitadas, mas que o usuário não precisa especificar as junções" (cap. 20.1.2). Legítimo quando o problema era só a query ser chata de escrever.
3. **Materialized view** — *a jogada principal.* "Se a tabela de visão for materializada, as junções seriam evitadas." Ganho de leitura com tabelas base normalizadas: a redundância é derivada por definição e fica **fora** do caminho de escrita.

```sql
CREATE MATERIALIZED VIEW mv_gasto_mensal AS
SELECT t.conta_id, c.nome AS conta_nome, cat.nome AS categoria_nome,
       date_trunc('month', t.ocorrida_em) AS mes, sum(t.valor) AS total
  FROM transacao t
  JOIN conta c       ON c.id   = t.conta_id
  JOIN categoria cat ON cat.id = t.categoria_id
 GROUP BY 1,2,3,4;
CREATE UNIQUE INDEX ON mv_gasto_mensal (conta_id, categoria_nome, mes);
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_gasto_mensal;
```
4. **Só então**, coluna redundante na tabela base.

**Se desnormalizar mesmo assim**, vale a Diretriz 2: "Se houver alguma anomalia, **anote-as claramente** e cuide para que os programas que atualizam o banco de dados operem corretamente" — e "as anomalias precisam ser observadas e consideradas (por exemplo, usando **triggers ou procedimentos armazenados** que fariam atualizações automáticas)" (cap. 15.1.2).

Checklist:
- [ ] mediu antes, com dados de produção, e a query é mesmo o gargalo?
- [ ] alternativas 1–3 esgotadas?
- [ ] consistência mantida por **mecanismo** (trigger / generated column / refresh job), não por convenção?
- [ ] duplicação documentada no schema, onde quem edita vai ver?
- [ ] existe teste que falha se as cópias divergirem?
- [ ] há como reverter? (o projeto lógico normalizado segue sendo a fonte da verdade — cap. 20.2.2)

**Nota prática — Prisma.** O Prisma não tem conceito de coluna derivada; coluna desnormalizada é coluna comum, e nada impede um `update` de escrever valor incoerente. Prefira mecanismos que vivem **no banco**:
```sql
ALTER TABLE transacao
  ADD COLUMN mes_competencia date
  GENERATED ALWAYS AS (date_trunc('month', ocorrida_em)::date) STORED;
```
`GENERATED ALWAYS ... STORED` é a forma segura: redundância física, zero risco de divergência, e o Prisma expõe como read-only. Trigger é o próximo recurso quando o valor vem de outra tabela. **Cópia mantida pela aplicação é o último recurso** — é o que a Diretriz 2 chama de "cuide para que os programas operem corretamente", ou seja: agora é problema seu, para sempre.

---

## 10. Resumo operacional

**Diagnóstico de uma tabela, em ordem:**
1. Consigo explicar a tabela em uma frase? (Diretriz 1)
2. Liste as DFs a partir das **regras de negócio**, não dos dados.
3. Calcule fechamentos; determine **todas** as candidatas; marque os primos.
4. Toda DF não trivial `X → A` tem X superchave? → **BCNF** ✓
5. Se não: A é primo? → é 3FN. Decida BCNF vs. preservação de DFs (8.4).
6. Se não: é 2FN? (parcial vs. transitiva orienta a correção, não muda o diagnóstico)
7. All-key de 3+ colunas com colunas independentes? → cheque **4FN**.
8. Toda decomposição: teste **NJB** (binária) ou **Algoritmo 16.3** (n-ária). Não negociável.

**Prioridades:** lossless join > semântica clara > preservação de dependências > BCNF > performance de leitura.

**Para levar:**
- DF é semântica: refuta-se com dados, nunca se prova com dados.
- Ordem 1FN→2FN→3FN é histórica. Teste 3FN/BCNF direto.
- Verificar tabelas isoladamente não basta — a decomposição tem propriedades próprias.
- Não dá para ter lossless + preservação de DFs + BCNF ao mesmo tempo. Lossless nunca cede.
- Desnormalização não é atalho: é dívida com pagamento mensal em código de escrita.
