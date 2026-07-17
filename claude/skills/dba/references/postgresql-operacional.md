# PostgreSQL Operacional: Tipos, DDL e Operação

Abra esta referência quando precisar **decidir** algo concreto sobre PostgreSQL: que tipo usar para uma coluna, se a constraint vale a pena, se soft delete resolve ou cria problema, por que a tabela está inchada, que parâmetro mexer, como achar a query cara, ou se o backup existe de verdade. Não é um tutorial — é um conjunto de vereditos com o trade-off explícito.

Baseline: **PostgreSQL 17/18**. Quando o comportamento mudou entre versões, a versão está dita. PG 18 é a série estável atual.

---

## 1. Tipos de dados

### 1.1 Dinheiro: `numeric` vs `float` vs inteiro em centavos

**Veredito para app financeiro: `numeric(N, S)`.** Sem hesitação.

A doc é explícita: `numeric` "é especialmente recomendado para armazenar valores monetários e outras quantidades onde exatidão é necessária. Cálculos com valores `numeric` produzem resultados exatos onde possível, ex.: adição, subtração, multiplicação."

| Opção | Exatidão | Custo | Veredito |
|---|---|---|---|
| `numeric(14,2)` | Exata em +, -, × | "Muito lento comparado a integer ou float" (doc); 2 bytes por grupo de 4 dígitos + 3–8 de overhead | **Use isto** |
| `double precision` / `real` | Aproximada | Rápido | **Nunca para dinheiro** |
| `bigint` em centavos | Exata | Mais rápido e compacto | Válido, mas escala vira problema da aplicação |
| `money` | Fixo, sem fração de centavo | — | **Nunca** (ver 1.1.1) |

Por que não `float`: a doc avisa que "alguns valores não podem ser convertidos exatamente para o formato interno e são armazenados como aproximações" e conclui: "se você requer armazenamento e cálculos exatos (como para valores monetários), use o tipo `numeric`." Detalhe que morde em relatório: **`numeric` arredonda empates para longe do zero; `real`/`double precision` arredondam (na maioria das máquinas) para o par mais próximo** — `float` nem erra de forma consistente com a expectativa contábil.

O argumento "mas `numeric` é lento" é real e quase sempre irrelevante: a query gasta tempo em I/O e planejamento, não em somar `numeric`. Só considere `bigint` em centavos se medir que a aritmética é o gargalo.

```sql
CREATE TABLE transactions (
  id          uuid PRIMARY KEY DEFAULT uuidv7(),        -- PG 18+
  account_id  uuid NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
  amount      numeric(14,2) NOT NULL,                   -- positivo = crédito
  currency    char(3) NOT NULL DEFAULT 'BRL',           -- ISO 4217, largura fixa real
  occurred_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT amount_nonzero CHECK (amount <> 0)
);
```

`numeric(14,2)` suporta até 999.999.999.999,99 — de sobra. Precisão máxima declarável é 1000; sem restrição, `numeric` guarda até 131072 dígitos antes da vírgula.

**Nota sobre Prisma:** `Decimal` mapeia para `numeric`. Use `@db.Decimal(14, 2)` explicitamente — o default do Prisma é `Decimal(65,30)`, desperdício. No TypeScript o valor volta como `Prisma.Decimal` (decimal.js), **não** `number` — nunca faça `Number(tx.amount)` antes de somar, ou reintroduz float pela porta dos fundos.

#### 1.1.1 O tipo `money` — não use

O wiki oficial ("Don't Do This") é direto: `money` é ponto fixo que não lida bem com frações de centavo, tem arredondamento imprevisível, e **não armazena designação de moeda** — mudar `lc_monetary` altera como valores já existentes são exibidos. Um app financeiro multi-moeda com `money` é uma bomba-relógio.

### 1.2 `text` vs `varchar(n)` vs `char(n)`

**Veredito: `text` por padrão. `varchar(n)` só quando o limite é uma regra de negócio real. `char(n)` praticamente nunca.**

A doc é inequívoca: "Não há diferença de performance entre esses três tipos, exceto pelo espaço de armazenamento aumentado ao usar o tipo blank-padded, e alguns ciclos de CPU extras para checar o tamanho... `character(n)` é geralmente o mais lento dos três por causa dos custos adicionais de armazenamento."

| Tipo | Quando |
|---|---|
| `text` | Default. Toda string livre: descrição, nome, memo |
| `varchar(n)` | Limite é regra de negócio verificável (ex.: código de 6 caracteres) |
| `char(n)` | Só largura genuinamente fixa e sem semântica de espaço (ex.: `char(3)` para ISO 4217) |

O wiki acrescenta o argumento decisivo contra `varchar(n)` reflexivo: ele "não fornece vantagem de armazenamento ou performance sobre `text`", e limites arbitrários "arriscam erros futuros em produção quando os dados excedem as expectativas". Mudar `varchar(50)` para `varchar(100)` é um `ALTER TABLE`; mudar `text` é nada. Contraponto honesto: `varchar(n)` documenta intenção e barra lixo na porta do banco — defesa em profundidade não é crime. O erro é o reflexo `varchar(255)` herdado do MySQL, que não significa nada. `char(n)` tem armadilha extra: é preenchido com espaços até a largura declarada, e "espaços à direita criam comportamento confuso de comparação".

### 1.3 `timestamptz` vs `timestamp`

**Veredito: `timestamptz` quase sempre.**

O wiki oficial lista `timestamp` (sem timezone) em "Don't Do This": ele armazena apenas "uma foto de um calendário e um relógio" sem contexto de fuso, e "aritmética entre timestamps de fusos diferentes ou entre timestamps de verão e inverno pode dar a resposta errada."

O ponto que confunde todo mundo: **`timestamptz` não armazena o timezone.** Ele armazena um instante absoluto (UTC internamente) e converte na entrada/saída conforme o `TimeZone` da sessão. O nome é péssimo — mas é por isso que ele é o certo: um lançamento financeiro **é** um ponto no tempo.

O anti-padrão que o wiki chama pelo nome: "Armazenar valores UTC numa coluna `timestamp without time zone` é, infelizmente, uma prática comumente herdada de outros bancos que não têm suporte usável a timezone. Use `timestamp with time zone` em vez disso" — porque "não há como o banco saber que UTC é o timezone pretendido para os valores da coluna." `timestamp` sem tz só é legítimo para horário de parede independente de fuso ("o alarme toca às 08:00 onde quer que o usuário esteja"). Raro em finanças.

| Caso | Tipo |
|---|---|
| Quando a transação ocorreu | `timestamptz` |
| `created_at` / `updated_at` | `timestamptz` |
| Data de competência de uma fatura (dia civil, sem hora) | `date` |
| Vencimento contratual "dia 10", sem instante | `date` |
| Duração / diferença | `interval` |

Corolários do wiki: **não use `timetz`** ("implementado apenas para conformidade SQL", diz o manual) e **não use `CURRENT_TIME`** (retorna `timetz`). Use `CURRENT_TIMESTAMP` / `now()` / `CURRENT_DATE`.

Outra do wiki que morde em relatório: **não use `BETWEEN` com timestamps.** `BETWEEN` é intervalo fechado nos dois lados. `WHERE occurred_at BETWEEN '2026-06-01' AND '2026-06-30'` inclui a meia-noite do dia 30 mas perde o resto do dia 30 — e se você encadear meses, o dia de fronteira é contado duas vezes. Use meio-aberto:

```sql
-- Certo: meio-aberto [início, fim)
WHERE occurred_at >= '2026-06-01' AND occurred_at < '2026-07-01'
```

`date` e `interval`: `date` é 4 bytes, sem hora, sem fuso — use para competência/vencimento. `interval` guarda meses/dias/microssegundos separadamente de propósito (1 mês não tem duração fixa); é ótimo para recorrência (`'1 month'::interval`) e perigoso para somar durações precisas.

### 1.4 Chave primária: `uuid` (v4 vs v7) vs `bigint identity`

O problema do UUID v4 é físico: **UUIDs aleatórios têm localidade de índice ruim.** Valores gerados em sequência não ficam próximos no índice, então cada insert vai para uma posição aleatória da B-tree → page splits, cache miss, bloat de índice e amplificação de WAL.

UUID v7 resolve isso colocando o timestamp nos bits mais significativos: os inserts voltam a ser append na borda direita do índice, como um `bigint` sequencial, mantendo a propriedade de "gerar em qualquer lugar sem coordenação". **PG 18 traz `uuidv7()` nativo** (e `uuidv4()` como alias explícito de `gen_random_uuid()`). Antes: extensão (`pg_uuidv7`) ou geração na aplicação.

| Opção | Prós | Contras | Quando |
|---|---|---|---|
| `bigint GENERATED ALWAYS AS IDENTITY` | 8 bytes, sequencial, índice ótimo | Enumerável por terceiros; precisa do banco para gerar | Default se ID não é público |
| `uuid` v7 | Gera no client, sem coordenação; ordenado no índice | 16 bytes; **timestamp de criação é decodificável** | Default quando ID é público / gerado no app |
| `uuid` v4 | Opaco, sem vazar tempo | Insert aleatório: page splits, bloat, mais WAL | Só quando o vazamento de tempo importa |
| `serial` / `bigserial` | — | Wiki: "Don't Do This" | Não use em código novo |

**Sobre `serial`:** o wiki lista em "Don't Do This" — tipos serial criam "comportamentos estranhos" que complicam gestão de schema, dependências e permissões. Desde PG 10 use identity columns, que são padrão SQL.

`GENERATED ALWAYS` vs `BY DEFAULT`: com `ALWAYS`, um valor explícito no INSERT só é aceito com `OVERRIDING SYSTEM VALUE` — protege contra o clássico bug de inserir manualmente um ID que depois colide com o gerado pela sequence. E use **`bigint`**, não `integer`: `integer` estoura em 2,1 bilhões, e a migração depois é dolorosa e evitável por 4 bytes por linha.

**Recomendação para o projeto (finanças pessoais, PG 18):** `uuid` v7 se os IDs aparecem em URL/API (o app gera, evita round-trip, e não vaza contagem de registros como `bigint` vazaria); `bigint identity` em tabelas internas (junção, lookup). O trade-off do v7: ele **vaza o instante de criação** — se isso for sensível, use v4 e aceite o custo de índice.

### 1.5 `enum` nativo vs tabela de domínio vs `CHECK`

Os três são defensáveis. O que decide é **quanto o conjunto de valores muda** e **se os valores precisam de atributos**.

| Critério | `enum` nativo | Tabela lookup + FK | `text` + `CHECK` |
|---|---|---|---|
| Espaço | 4 bytes | 2–8 bytes (FK) | tamanho do texto |
| Adicionar valor | `ALTER TYPE ... ADD VALUE` (metadado, sem rebuild) | `INSERT` | `ALTER TABLE` + revalidação |
| Remover valor | **Não existe `DROP VALUE`** | `DELETE` (FK protege) | `ALTER TABLE` |
| Renomear | `ALTER TYPE ... RENAME VALUE` | `UPDATE` numa linha | `ALTER TABLE` |
| Atributos extras (label, ordem, ativo) | Não | **Sim** | Não |
| Ordenação customizada | Sim (ordem de declaração) | Sim (coluna `sort_order`) | Não |
| Estimativas do planner | Boas | Piores (planner não sabe qual `id` é qual valor) | Boas |

**O custo real de alterar um enum — dois fatos concretos da doc:**

1. `ALTER TYPE ... ADD VALUE`: "Se executado dentro de um bloco de transação, o novo valor não pode ser usado até que a transação tenha sido commitada." Isso quebra migrations que adicionam o valor e o usam no mesmo arquivo transacional — pega Prisma Migrate em cheio. Até PG 12 era pior: `ADD VALUE` não podia sequer rodar dentro de bloco de transação; PG 13 relaxou para a regra atual.

2. **Não existe remover valor de enum.** Não há `ALTER TYPE ... DROP VALUE`. A saída é recriar o tipo e reescrever todas as colunas que o usam — ou seja, uma migration cara em produção.

Nota de performance da doc: comparações envolvendo um valor adicionado podem ser mais lentas que entre membros originais, tipicamente quando `BEFORE`/`AFTER` posicionam o valor fora do fim, ou se o contador de OID deu wraparound. "A lentidão é geralmente insignificante"; se incomodar, dump/restore ou recriar o tipo.

**Critério de decisão:**
- Conjunto **fechado e estável**, sem atributos, sem remoção prevista → `enum`. Ex.: `transaction_kind` ('debit', 'credit').
- Conjunto que o **usuário gerencia**, ou que precisa de label/cor/ordem/soft-disable → **tabela lookup**. Ex.: `categories` num app de finanças — o usuário cria as dele. Isso nem é decisão, é modelagem.
- Conjunto pequeno, estável, e você quer flexibilidade de `ALTER TABLE` sem o drama do enum → `text` + `CHECK`, idealmente encapsulado num `DOMAIN`.

```sql
-- enum: conjunto fechado do sistema
CREATE TYPE transaction_kind AS ENUM ('debit', 'credit');

-- lookup: conjunto que o usuário gerencia (o caso de categories)
CREATE TABLE categories (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  color       text,
  sort_order  int NOT NULL DEFAULT 0,
  archived_at timestamptz
);

-- domain + CHECK: meio-termo com nome
CREATE DOMAIN currency_code AS char(3) CHECK (VALUE ~ '^[A-Z]{3}$');
```

**Atenção Prisma:** o `enum` do Prisma gera enum nativo do PostgreSQL. Isso significa que você herda o problema de "não dá para remover valor" — e o `ADD VALUE` em transação. Se o conjunto vai mudar, prefira tabela lookup mesmo que o Prisma torne enum mais conveniente no TypeScript.

### 1.6 `jsonb` vs `json` — e quando JSONB é preguiça

**`jsonb`, salvo exceção rara.** A doc: "a maioria das aplicações deveria preferir armazenar dados JSON como `jsonb`, a não ser que haja necessidades bem especializadas, como premissas legadas sobre ordenação de chaves de objeto."

| | `json` | `jsonb` |
|---|---|---|
| Armazenamento | cópia exata do texto | binário decomposto |
| Espaços em branco | preservados | descartados |
| Ordem das chaves | preservada | não preservada |
| Chaves duplicadas | todas mantidas (última vale) | só a última mantida |
| Índice | **não** | GIN, btree, hash |
| Processamento | reparse a cada execução | sem reparse, mais rápido |

**Quando JSONB é legítimo:**
- Payload externo cru que você quer guardar como recebeu (resposta de gateway de pagamento, webhook do Open Finance) para auditoria/replay.
- Atributos genuinamente esparsos e heterogêneos, com dezenas de formas possíveis, onde nenhuma query filtra por eles.
- Metadados que a aplicação lê inteiros e nunca agrega.

**Quando é preguiça de modelar:**
- Você já sabe as chaves. Se `metadata->>'category'` aparece num `WHERE`, isso é uma coluna.
- Você precisa de constraint sobre o conteúdo (FK, NOT NULL, CHECK) — JSONB não te dá nada disso de graça.
- Você agrega/soma valores lá de dentro. `SUM((metadata->>'amount')::numeric)` é uma confissão.

A própria doc dá o critério: "Idealmente, documentos JSON deveriam cada um representar um dado atômico que as regras de negócio ditam não poder razoavelmente ser subdividido em dados menores que poderiam ser modificados independentemente." Traduzindo o teste: **se um pedaço do JSON pode ser modificado sozinho, ele quer ser uma coluna.**

Índices: `jsonb_ops` (default) suporta `?`, `?|`, `?&`, `@>`, `@?`, `@@`. `jsonb_path_ops` não suporta os operadores de existência de chave, mas "é geralmente muito menor... e a especificidade das buscas é melhor". Ressalva: vai mal com estruturas vazias tipo `{"a": {}}`.

```sql
-- Payload cru de integração: JSONB legítimo
ALTER TABLE transactions ADD COLUMN provider_payload jsonb;
CREATE INDEX ON transactions USING gin (provider_payload jsonb_path_ops);
```

### 1.7 Arrays, `citext`, range types

**Arrays.** Legítimos para listas pequenas, ordenadas, sem identidade própria e sem FK — ex.: `tags text[]`. Indexáveis com GIN (`@>`, `&&`). Deixam de ser legítimos no instante em que você quer FK para os elementos, atributos por elemento, ou contar/agregar por elemento — isso é uma tabela de junção. Array não tem integridade referencial.

**`citext`.** Comparação case-insensitive; chama `lower()` internamente. Útil para `email` como UNIQUE sem espalhar `lower()`. Mas a doc atual **recomenda não usá-lo**: "Considere usar *collations não-determinísticas* em vez deste módulo. Elas podem ser usadas para comparações case-insensitive, accent-insensitive, e outras combinações, e lidam com mais casos especiais Unicode corretamente."

Caveats explícitos: não cobre alguns casos Unicode ("quando uma letra maiúscula tem duas equivalentes minúsculas"); depende do `LC_CTYPE` e "não é verdadeiramente case-insensitive nos termos definidos pelo padrão Unicode"; "não é tão eficiente quanto `text` porque as funções de operador e comparação B-tree precisam fazer cópias dos dados e convertê-los para minúsculo"; e o schema dos operadores precisa estar no `search_path`, senão os operadores case-sensitive são invocados **silenciosamente**. Alternativa moderna:

```sql
CREATE COLLATION case_insensitive (provider = icu, locale = 'und-u-ks-level2', deterministic = false);
CREATE TABLE users (
  id    uuid PRIMARY KEY DEFAULT uuidv7(),
  email text COLLATE case_insensitive NOT NULL UNIQUE
);
```

**Range types.** Built-in: `int4range`, `int8range`, `numrange`, `tsrange`, `tstzrange`, `daterange`. Cada um tem um **multirange** correspondente (`int4multirange` etc.), adicionados no **PG 14**. Bounds: `[` inclusivo, `(` exclusivo — `[3,7)` inclui 3 e exclui 7.

O valor real dos ranges está nas **exclusion constraints**: impedir sobreposição no banco, algo que `UNIQUE` não consegue expressar. Ver 2.6.

---

## 2. Constraints e integridade

**Por que a integridade pertence ao banco, e não só à aplicação:**

1. A aplicação não é o único escritor. Migration, script de correção, seed, psql às 3h da manhã, um segundo serviço, o console de admin — todos escrevem.
2. Validação na aplicação é **check-then-act** e sofre race condition: dois requests concorrentes fazem `SELECT` (nenhum acha), ambos fazem `INSERT`, e você tem duplicata. Só uma constraint serializa isso.
3. Constraints são **verificadas**, não prometidas. Um `NOT NULL` é invariante do dado; um `if (!x) throw` é invariante do caminho de código que você lembrou de escrever.
4. O planner usa constraints: `NOT NULL` e `CHECK` melhoram estimativas.

A aplicação valida para **dar boa mensagem de erro**; o banco valida para **garantir**. Fazer só um é um bug esperando.

### 2.1 `NOT NULL`

O default de uma coluna é nullable — quase nunca o que você quer. Cada coluna nullable é um `| null` que vaza para o TypeScript e um branch que alguém vai esquecer.

**PG 18** passou a armazenar constraints `NOT NULL` no catálogo `pg_constraint`, o que permite **nomeá-las** e usar `NOT VALID` via `ALTER TABLE` — útil para adicionar `NOT NULL` numa tabela grande sem varrê-la inteira sob lock.

### 2.2 `CHECK`

Armadilha central: "uma check constraint é satisfeita se a expressão avalia para true **ou null**." `CHECK (amount > 0)` **não** barra `NULL`. Para isso, `NOT NULL` também.

```sql
ALTER TABLE transactions
  ADD CONSTRAINT amount_nonzero CHECK (amount <> 0),
  ADD CONSTRAINT currency_iso   CHECK (currency ~ '^[A-Z]{3}$');
```

Em tabela grande, adicione com `NOT VALID` (não varre o existente, só valida novas linhas) e depois `VALIDATE CONSTRAINT` (lock fraco):

```sql
ALTER TABLE transactions ADD CONSTRAINT amount_nonzero CHECK (amount <> 0) NOT VALID;
ALTER TABLE transactions VALIDATE CONSTRAINT amount_nonzero;
```

### 2.3 `UNIQUE` e unique parcial

Cria automaticamente um índice B-tree único. O ponto que quebra gente: **por padrão, dois `NULL` não são considerados iguais**, então múltiplas linhas com `NULL` na coluna passam pelo `UNIQUE`.

Desde **PG 15** dá para inverter isso com `NULLS NOT DISTINCT`:

```sql
CREATE TABLE products (product_no integer UNIQUE NULLS NOT DISTINCT);
```

**Unique parcial** é a ferramenta mais subutilizada do PostgreSQL — só existe como índice, não como constraint de tabela:

```sql
-- Só uma conta "default" ativa por usuário
CREATE UNIQUE INDEX accounts_one_default_per_user
  ON accounts (user_id) WHERE is_default AND deleted_at IS NULL;
```

### 2.4 `PRIMARY KEY`

`UNIQUE` + `NOT NULL`. Uma por tabela. Cria índice B-tree único e marca as colunas `NOT NULL`.

### 2.5 `FOREIGN KEY` — e o custo de FK não indexada

**Este é o gotcha operacional mais caro e mais comum.** A doc: "Como um `DELETE` de uma linha na tabela referenciada ou um `UPDATE` de uma coluna referenciada vai requerer um scan da tabela referenciadora... é frequentemente uma boa ideia indexar as colunas referenciadoras também. Como isso nem sempre é necessário... a declaração de uma foreign key constraint **não cria automaticamente um índice** nas colunas referenciadoras."

Traduzindo: **PostgreSQL indexa a coluna referenciada (é PK), mas NÃO a referenciadora.** Sem esse índice, todo `DELETE` no pai dispara um **sequential scan no filho inteiro** — por linha deletada. Relatos de campo mostram ordens de magnitude (50k deletes em ~100ms com índice vs ~30 min sem).

```sql
-- A FK NÃO cria isto. Você cria.
CREATE INDEX ON transactions (account_id);
CREATE INDEX ON transactions (category_id);
```

**Prisma não cria esses índices sozinho no PostgreSQL.** Toda relação no schema Prisma exige um `@@index([fk_column])` explícito, exceto quando a FK já é prefixo de outro índice.

Ações de `ON DELETE` / `ON UPDATE`:

| Ação | Efeito | Uso em finanças |
|---|---|---|
| `NO ACTION` (default) | Erro; checagem pode ser deferida até o fim da transação | Default seguro |
| `RESTRICT` | Erro imediato, não deferível | Proteger `accounts` com transações |
| `CASCADE` | Apaga/atualiza as linhas filhas | `user` → seus dados; **nunca** para dado financeiro histórico |
| `SET NULL` | Zera a coluna referenciadora | `category` deletada → transação vira "sem categoria" |
| `SET DEFAULT` | Coloca o default | Raro; o default precisa existir no pai |

`SET NULL`/`SET DEFAULT` aceitam lista de colunas — útil em FK composta.

**Critério:** `CASCADE` só quando o filho **não tem significado sem o pai** (um `session` sem `user`). Dado financeiro histórico nunca é assim: use `RESTRICT`.

`DEFERRABLE INITIALLY DEFERRED` adia a checagem para o `COMMIT`. Resolve dependência circular e inserção fora de ordem dentro de uma transação — ex.: lançar as duas pernas de uma transferência entre contas onde cada uma referencia a outra. Custo: o erro aparece no commit, longe do statement culpado, e a memória de constraints pendentes cresce.

### 2.6 `EXCLUDE` — a constraint que ninguém usa e devia

Generaliza `UNIQUE`: "garante que, para quaisquer duas linhas comparadas nas colunas/expressões especificadas, ao menos uma comparação de operador retorne false ou null." Com `=` é `UNIQUE`; com `&&` (overlap) é impedir sobreposição.

```sql
CREATE EXTENSION btree_gist;

-- Um orçamento por categoria por período, sem sobreposição de datas
CREATE TABLE budgets (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  category_id bigint NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  amount      numeric(14,2) NOT NULL,
  period      daterange NOT NULL,
  EXCLUDE USING gist (category_id WITH =, period WITH &&)
);
```

`btree_gist` é o que permite misturar tipos escalares (`=`) com ranges (`&&`) no mesmo índice GiST. Sem a extensão, só ranges.

**PG 18** adicionou sintaxe temporal nativa que cobre o caso comum sem GiST manual: `PRIMARY KEY (room_id, during WITHOUT OVERLAPS)`, `UNIQUE (doctor_id, time_slot WITHOUT OVERLAPS)`, e FKs com `PERIOD`.

Nota: nem `EXCLUDE` nem unique parcial existem no schema Prisma — vão em migration SQL manual (`prisma migrate dev --create-only`, depois edite).

### 2.7 `DOMAIN`

Tipo nomeado com constraint embutida — um nome e um lugar só para a regra. Trade-off: ORMs (Prisma incluso) geralmente não entendem domains e a introspecção fica torta; em stack Prisma, prefira `CHECK` na tabela.

```sql
CREATE DOMAIN money_amount AS numeric(14,2) CHECK (VALUE IS NOT NULL);
CREATE DOMAIN email AS text CHECK (VALUE ~ '^[^@]+@[^@]+\.[^@]+$');
```

---

## 3. Chaves: natural vs surrogate

O debate honesto, sem torcida. **Natural key** = o dado do mundo real é a chave (CPF, ISO 4217, e-mail). **Surrogate key** = `bigint identity` ou `uuid` sem significado.

| Eixo | Natural | Surrogate |
|---|---|---|
| Estabilidade | **Muda** — pessoa troca e-mail, país troca código | **Nunca muda** — a propriedade que importa |
| Propagação | FK carrega o valor; `UPDATE` vira cascata cara | FK estreita e uniforme, barata |
| Largura | Composta e larga → índices e JOINs caros | 8–16 bytes |
| JOINs | Menos (a FK já tem o valor) | Um a mais para chegar ao valor legível |
| Sigilo | Dado sensível (CPF) espalha por FKs e logs | Não vaza negócio |
| Unicidade real | Vem de graça | **Exige UNIQUE separado** — o que muita gente esquece |

**Critério de decisão, em ordem:**

1. Existe candidata natural que é **imutável, mandatória, única e não-sensível**? Quase nunca. `currency_code` é; CPF não é (pode ser corrigido, é sensível); e-mail não é (muda).
2. A tabela é **referenciada** por outras? Se sim → surrogate. O custo de mudar uma natural key propaga por todas as FKs.
3. É **tabela de junção pura**? PK composta das duas FKs é natural e correta — não invente surrogate.
4. É **lookup pequena, estável e não-sensível**? Natural é legítima e mais legível (`currency_code char(3) PRIMARY KEY`).

**Regra prática:** surrogate como PK + **UNIQUE na chave natural**. A parte que as pessoas erram é a segunda: surrogate não dispensa a unicidade real. Um `users.id uuid` sem `UNIQUE (email)` é uma tabela sem integridade com um ID bonito.

```sql
CREATE TABLE users (
  id    uuid PRIMARY KEY DEFAULT uuidv7(),   -- surrogate: identidade
  email text NOT NULL UNIQUE,                -- natural: unicidade do negócio
  created_at timestamptz NOT NULL DEFAULT now()
);
```

---

## 4. Soft delete vs hard delete

**Soft delete** = `deleted_at timestamptz` e todo `SELECT` filtra `WHERE deleted_at IS NULL`.

| | Hard delete | Soft delete |
|---|---|---|
| Integridade | FK garante de verdade | FK vê a linha "deletada" como viva |
| Queries | Simples | **Todas** precisam do filtro; esquecer = bug silencioso |
| `UNIQUE` | Funciona | **Quebra** (ver abaixo) |
| Tamanho | Tabela encolhe | Cresce para sempre; índices carregam lixo |
| Auditoria/undo | Perdido | Preservado |
| LGPD "direito ao esquecimento" | Atendido | **Não atendido** — o dado ainda está lá |

### O problema com `UNIQUE`

Constraint `UNIQUE` é aplicada sobre **todas** as linhas, inclusive as soft-deleted. Usuário deleta a conta `email = 'a@b.com'` e tenta recriar → violação de unicidade contra um registro que "não existe".

**1. Unique parcial — a resposta certa no PostgreSQL:**

```sql
CREATE UNIQUE INDEX users_email_active
  ON users (email) WHERE deleted_at IS NULL;
```

Só linhas ativas entram no índice; soft-deleted repetem o e-mail à vontade. Bônus: o índice fica menor porque não carrega os deletados.

**2. `UNIQUE (email, deleted_at)` — não faça.** Como `NULL` não é distinto de `NULL`, várias linhas **ativas** (`deleted_at IS NULL`) com o mesmo e-mail **passam** pela constraint. É o pior dos dois mundos.

**3. Tabela de arquivo:** hard delete + `INSERT` numa `*_archive`. Mantém a tabela quente limpa, a integridade real, e atende auditoria.

**Critério:**
- **Financeiro histórico** (transações): não delete — nem soft nem hard. Lançamento é imutável; correção é estorno, não `DELETE`.
- Dado que o usuário gerencia e pode querer de volta (categorias, contas): **soft delete + unique parcial**.
- Obrigação de esquecimento (PII de quem pediu exclusão): **hard delete** ou anonimização real.
- Efêmero (sessions, tokens): **hard delete**, e cuide do bloat (seção 5).

**Prisma:** não tem soft delete nativo; você implementa via extension/middleware, e o risco é exatamente o item que quebra — um `$queryRaw` esquecido vê os deletados. Centralize o acesso, ou exponha uma view (`CREATE VIEW active_accounts AS SELECT * FROM accounts WHERE deleted_at IS NULL`).

---

## 5. VACUUM e MVCC operacional

### 5.1 De onde vem o bloat

MVCC: `UPDATE` **não** altera a linha no lugar — cria uma nova versão e marca a antiga como morta. `DELETE` só marca. As versões mortas (dead tuples) ocupam espaço e são varridas pelas queries até o VACUUM reciclá-las.

VACUUM existe por quatro razões (doc): recuperar espaço de linhas atualizadas/deletadas; atualizar estatísticas do planner (via ANALYZE); atualizar a **visibility map** (habilita index-only scan e permite pular páginas limpas); e prevenir falha de **transaction ID wraparound**.

### 5.2 VACUUM vs VACUUM FULL

| | `VACUUM` | `VACUUM FULL` |
|---|---|---|
| Lock | `SHARE UPDATE EXCLUSIVE` | **`ACCESS EXCLUSIVE`** |
| Concorrência | SELECT/INSERT/UPDATE/DELETE seguem | **Bloqueia tudo, inclusive SELECT** |
| Espaço | Marca para reuso — **não devolve ao SO** | Compacta e devolve ao SO |
| Custo | Barato, incremental | Reescreve a tabela inteira; precisa de ~2x o espaço em disco |

**Por que `VACUUM FULL` trava:** ele adquire `ACCESS EXCLUSIVE` e reescreve a tabela num arquivo novo. Nada — nem um `SELECT` — passa enquanto isso. Numa tabela de transações de vários GB, é downtime.

Autovacuum **nunca** emite `VACUUM FULL`. A recomendação da doc é usar VACUUM padrão com frequência suficiente para nunca precisar do FULL. Se precisar recuperar espaço sem downtime, use `pg_repack` (extensão) em vez de `VACUUM FULL`.

### 5.3 Como o autovacuum decide

```
vacuum threshold = Minimum(
    autovacuum_vacuum_max_threshold,          -- PG 18+
    autovacuum_vacuum_threshold + autovacuum_vacuum_scale_factor * reltuples
)
```

| Parâmetro | Default | O que faz |
|---|---|---|
| `autovacuum_vacuum_threshold` | 50 | Base de tuplas mortas |
| `autovacuum_vacuum_scale_factor` | 0.1 (10%) | Escala com o tamanho da tabela |
| `autovacuum_vacuum_max_threshold` | — | **PG 18**: teto absoluto de tuplas mortas |
| `autovacuum_vacuum_insert_threshold` | 1000 | Base para vacuum disparado por inserts |
| `autovacuum_vacuum_insert_scale_factor` | 0.05 | Escala do insert threshold |
| `autovacuum_vacuum_cost_delay` | 2ms | Pausa entre páginas (throttle de I/O) |
| `autovacuum_vacuum_cost_limit` | 200 | Custo de I/O antes de dormir |
| `autovacuum_naptime` | 10s | Intervalo entre checagens do launcher |
| `autovacuum_max_workers` | 3 | Workers concorrentes |

**Onde o default falha:** o `scale_factor` de 10% é uma fração — o problema é que ele **não escala**. Numa tabela de 100 linhas, dispara com 60 tuplas mortas: ótimo. Numa tabela de 50 milhões de transações, só dispara com **5 milhões de tuplas mortas** — bloat enorme acumulado antes do primeiro vacuum, e aí o vacuum é longo e pesado.

**A correção é por tabela**, não global:

```sql
-- Tabela grande e quente: dispara a cada ~5k tuplas mortas, não a cada 10%
ALTER TABLE transactions SET (
  autovacuum_vacuum_scale_factor = 0.01, autovacuum_vacuum_threshold = 5000,
  autovacuum_analyze_scale_factor = 0.02);

-- Alta rotatividade (sessions/jobs): agressivo
ALTER TABLE sessions SET (
  autovacuum_vacuum_scale_factor = 0.0, autovacuum_vacuum_threshold = 1000,
  autovacuum_vacuum_cost_delay = 0);
```

No PG 18, `autovacuum_vacuum_max_threshold` resolve isso de forma mais limpa: um teto absoluto, sem zerar o scale factor. Outros defaults que falham: `autovacuum_max_workers = 3` num banco com centenas de tabelas quentes → fila; `autovacuum_vacuum_cost_delay` caiu de 20ms para **2ms** (PG 12), mas em SSD ainda é conservador.

**PG 18** trouxe ainda `autovacuum_worker_slots` (mudar `autovacuum_max_workers` sem restart — antes exigia restart) e **eager freezing** de páginas all-visible em vacuums normais (`vacuum_max_eager_freeze_failure_rate`), reduzindo o custo do vacuum agressivo posterior.

### 5.4 Tabelas de alta rotatividade

O padrão que mata: tabela pequena com `UPDATE` constante (contador, fila de jobs, sessions). Poucas linhas, milhões de versões mortas — 10 linhas lógicas e 2 GB em disco. Duas respostas:

- **HOT updates** evitam atualizar índices quando a coluna alterada não é indexada e há espaço na página. Baixe o `fillfactor` (`ALTER TABLE jobs SET (fillfactor = 70)`) e **não indexe** a coluna que muda toda hora.
- Long-running transactions **bloqueiam o vacuum globalmente**: ele não pode reciclar nada mais novo que a transação aberta mais antiga. Um `BEGIN` esquecido num pool causa bloat em tabelas que não têm nada a ver com ele. Idem replication slots parados e prepared transactions órfãs.

### 5.5 Transaction ID wraparound

XIDs são de 32 bits (~4,3 bilhões). Sem freezing, após ~2 bilhões de transações os XIDs antigos pareceriam "do futuro" → **perda de dados**. VACUUM marca linhas antigas como "frozen" (sempre mais velho que qualquer XID normal).

| Parâmetro | Default | Papel |
|---|---|---|
| `autovacuum_freeze_max_age` | 200M | Força autovacuum mesmo com autovacuum off |
| `vacuum_freeze_min_age` | 50M | Idade para a linha ser congelável |
| `vacuum_freeze_table_age` | 150M | Dispara vacuum agressivo (varre todas as páginas) |

Progressão dos sintomas: primeiro `WARNING: database "mydb" must be vacuumed within 39985967 transactions`; abaixo de ~3M restantes, `ERROR: database is not accepting commands to avoid wraparound data loss` — **outage total**, banco em modo single-user. Monitore antes:

```sql
SELECT c.oid::regclass AS table_name,
       greatest(age(c.relfrozenxid), age(t.relfrozenxid)) AS xid_age
FROM pg_class c LEFT JOIN pg_class t ON c.reltoastrelid = t.oid
WHERE c.relkind IN ('r','m') ORDER BY 2 DESC LIMIT 20;
```

Alerte acima de ~50% de `autovacuum_freeze_max_age` (100M no default). Se estiver subindo, procure as três causas usuais: transação antiga aberta (`pg_stat_activity`), prepared transaction órfã (`pg_prepared_xacts`), replication slot abandonado (`pg_replication_slots`).

---

## 6. Configuração que importa

Ordem de importância real: **memória > autovacuum > checkpoint/WAL > custos do planner**. `random_page_cost` é o último da fila, apesar de ser o mais citado em blog post.

| Parâmetro | Default | Ponto de partida | Como raciocinar |
|---|---|---|---|
| `shared_buffers` | 128MB | 25% da RAM | Cache do PostgreSQL. Não vá a 80%: o SO também cacheia, e você pagaria duas vezes. Acima de ~40% costuma piorar. Exige restart. |
| `effective_cache_size` | 4GB | 50–75% da RAM | **Não aloca nada.** É uma dica ao planner sobre quanto cache (PG + SO) existe. Baixo demais → planner subutiliza índices. Grátis de aumentar. |
| `work_mem` | 4MB | 16–64MB | **Por operação de sort/hash, não por conexão.** Uma query com 3 sorts × 50 conexões = 150 × work_mem. É a forma clássica de causar OOM. Prefira setar por sessão em queries pesadas. |
| `maintenance_work_mem` | 64MB | 512MB–2GB | VACUUM, CREATE INDEX. Como normalmente só uma roda por sessão, "é seguro setar significativamente maior que work_mem". Acelera muito o vacuum. |
| `random_page_cost` | 4.0 | **1.1 em SSD** | Ver abaixo |
| `max_connections` | 100 | 100–200 + pooler | Ver seção 7 |
| `wal_buffers` | -1 (1/32 de shared_buffers, teto 16MB) | deixe | "Ajustes ao default são necessários muito menos frequentemente que em releases anteriores" |
| `checkpoint_completion_target` | 0.9 | 0.9 | Espalha as escritas do checkpoint, baixando o pico de I/O |
| `max_wal_size` | 1GB | 4–16GB em write-heavy | Baixo demais → checkpoints por volume, frequentes e caros |
| `effective_io_concurrency` | **16 (PG 18)** | 16+ em NVMe | Default subiu para 16 no PG 18; antes era 1 |
| `maintenance_io_concurrency` | **16 (PG 18)** | 16+ | Idem |

### `random_page_cost` — por que 4.0 é errado em SSD

O default de 4.0 modela **disco rígido rotacional**: acesso aleatório ~40x mais lento que sequencial, assumindo que ~90% das leituras aleatórias vêm do cache (40 × 0.1 ≈ 4). Em SSD/NVMe não há cabeça de leitura para mover — a penalidade quase some. Com 4.0 num SSD o planner **superestima** index scan e escolhe seq scan onde o índice seria melhor; o sintoma é seq scan em tabela grande com predicado seletivo.

Ponto de partida: **1.1** em SSD (não 1.0 — deixe diferença mínima em relação a `seq_page_cost = 1.0`, para o planner ainda preferir sequencial no empate). Em storage de rede (EBS gp3 etc.), 1.5–2.0 calibra melhor.

Mas a doc/wiki avisa da ordem correta: antes de mexer nisso, **garanta que o autovacuum funciona, que as estatísticas estão sendo coletadas e que a memória está dimensionada**. Um plano ruim quase sempre é estatística velha, não custo mal calibrado.

**PG 18** mudou o jogo de I/O: subsistema de **I/O assíncrono** (`io_method`, `io_combine_limit`, view `pg_aios`) acelerando seq scans, bitmap heap scans e vacuum; e `initdb` agora habilita **data checksums** por padrão (`--no-data-checksums` desliga; `pg_upgrade` exige que a configuração bata entre origem e destino).

---

## 7. Connection pooling

### Por que o PostgreSQL sofre com muitas conexões

**Um processo do SO por conexão.** Não é thread — é `fork()`. Cada backend custa memória base (alguns MB) mais o `work_mem` das suas queries. Pior: várias estruturas internas são **O(número de conexões)** — snapshot de MVCC, tabela de locks, `ProcArray`. O contraintuitivo: **`max_connections` alto degrada o banco mesmo com as conexões idle**, porque o custo de tirar um snapshot cresce. A resposta não é aumentar `max_connections` — é um pooler.

Ponto de partida clássico: `((núcleos × 2) + spindles efetivos)` conexões **ativas**. Numa VM de 4 vCPU com SSD, ~10–20 conexões ativas saturam a CPU; além disso é fila com overhead.

### PgBouncer: os três modos

| Modo | Conexão devolvida | Multiplexação | O que quebra |
|---|---|---|---|
| **session** | No fim da sessão do client | Baixa (só limita o total) | Nada |
| **transaction** | No fim de cada transação | **Alta** — milhares de clients → dezenas de conexões | Estado que atravessa transação (ver lista) |
| **statement** | No fim de cada statement | Máxima | Transações multi-statement **proibidas** (força autocommit) |

**Transaction mode é o que você quer** em 95% dos casos web/API — é o único que entrega multiplexação real. A doc do PgBouncer lista como **incompatível com transaction pooling**: `SET`/`RESET`, `LISTEN`/`NOTIFY`, `WITH HOLD CURSOR`, `PREPARE`/`DEALLOCATE`, temp tables `PRESERVE`/`DELETE ROWS`, `LOAD` e **advisory locks de nível de sessão**.

A razão comum: todos são estado de **sessão**, e em transaction mode você não tem garantia de voltar ao mesmo backend. O mais traiçoeiro é advisory lock de sessão — você adquire num backend e tenta liberar noutro; o lock fica pendurado até a conexão morrer. **Statement mode** só serve para workload analítico single-statement puro; qualquer transação real quebra.

### Prepared statements — o ponto que morde Prisma

Prepared statements vivem no **nível de sessão**. Em transaction pooling clássico, você faz `PREPARE` num backend e o `EXECUTE` cai noutro que nunca viu o prepare → o clássico `prepared statement "s0" does not exist`.

**PgBouncer 1.21+ resolve**: rastreia prepared statements em transaction mode e os prepara on-the-fly na conexão vinculada. Requer `max_prepared_statements` ≠ 0 (0 = desabilitado); o valor é o tamanho de um cache LRU por conexão de servidor. Trade-off da doc: "tente garantir que esse valor seja maior que a quantidade de prepared statements comumente usados pela sua aplicação. Tenha em mente que quanto maior o valor, maior o footprint de memória de cada conexão PgBouncer no seu servidor PostgreSQL."

**Na prática com Prisma + PgBouncer:**
- PgBouncer ≥ 1.21 com `max_prepared_statements = 100` (ou mais): funciona.
- PgBouncer antigo, ou serverless poolers que não suportam: adicione `?pgbouncer=true` na `DATABASE_URL` do Prisma — isso desabilita prepared statements. Custo: replanejamento a cada query.
- **Migrations precisam de conexão direta.** Aponte `directUrl` no datasource para o Postgres, sem passar pelo pooler — DDL e advisory locks de migration não sobrevivem a transaction pooling.

### Pooling na aplicação vs PgBouncer

| | Pool no app (`pg`, Prisma) | PgBouncer |
|---|---|---|
| Escopo | Por **instância** do processo | Global no cluster |
| Problema | N instâncias × pool_size → estoura `max_connections` | Resolve exatamente isso |
| Latência | Zero hop | Um hop a mais (µs) |
| Serverless | **Inútil** — cada invocação é um processo novo | Essencial |

Não são alternativas — são **camadas**. O pool do app evita reconectar a cada request; o PgBouncer evita que 20 instâncias × 10 conexões = 200 backends no Postgres. Numa API Fastify com múltiplos containers você quer os dois: pool pequeno no app (`connection_limit=5`) apontando para PgBouncer em transaction mode.

**Conta que salva:** `instâncias × connection_limit ≤ max_connections − reservas`. Uma API Fastify em 10 pods com o default do Prisma (`num_cpus × 2 + 1`, ex. 9) = 90 conexões — quase o `max_connections` default de 100, sem contar migrations, admin e réplicas.

---

## 8. Observabilidade

### 8.1 `pg_stat_statements` — a primeira coisa a instalar

```conf
# postgresql.conf — exige restart
shared_preload_libraries = 'pg_stat_statements'
compute_query_id = on
track_io_timing = on
```
```sql
CREATE EXTENSION pg_stat_statements;
```

Config: `pg_stat_statements.max` (default 5000, só no start), `.track` (`top` default / `all` / `none`), `.track_utility` (on), `.track_planning` (**off** por default — tem overhead), `.save` (on).

**Achar a query cara — pelo tempo total, não pelo mean.** Uma query de 5ms chamada 1M de vezes custa mais que uma de 2s chamada 10 vezes:

```sql
SELECT queryid, calls, round(total_exec_time::numeric,1) AS total_ms,
       round(mean_exec_time::numeric,2) AS mean_ms, rows,
       round(100.0*shared_blks_hit/nullif(shared_blks_hit+shared_blks_read,0),1) AS hit_pct,
       left(query, 90) AS query
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY total_exec_time DESC LIMIT 20;
```

Outras leituras do mesmo dado:
- `temp_blks_written > 0` → a query estourou `work_mem` e foi para o disco.
- `wal_bytes` alto → query escreve muito WAL (candidata a revisão em replicação).
- `rows / calls` enorme → a aplicação busca demais e filtra na memória.
- `stddev_exec_time` alto → a query é instável (parâmetro ruim, plano variável).

### 8.2 `pg_stat_user_tables` — achar a tabela inchada

```sql
SELECT relname, n_live_tup, n_dead_tup,
       round(100.0*n_dead_tup/nullif(n_live_tup+n_dead_tup,0),1) AS dead_pct,
       last_autovacuum, autovacuum_count,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_stat_user_tables ORDER BY n_dead_tup DESC LIMIT 20;
```

Leitura: `dead_pct` alto + `last_autovacuum` antigo/nulo = autovacuum não está dando conta → ajuste por tabela (5.3). `seq_scan` alto em tabela grande com `seq_tup_read` enorme = índice faltando.

**PG 18** adicionou `total_vacuum_time`, `total_autovacuum_time`, `total_analyze_time`, `total_autoanalyze_time` em `pg_stat_all_tables` — dá para ver quanto tempo o vacuum realmente gasta por tabela.

Para medir bloat de verdade (e não estimar): extensão `pgstattuple` (`SELECT * FROM pgstattuple('transactions')`). Cara — varre a tabela; rode fora de pico.

### 8.3 `pg_stat_activity` — o que está acontecendo agora

```sql
-- Transações antigas: bloqueiam vacuum e queimam XID
SELECT pid, state, now() - xact_start AS xact_age, now() - state_change AS state_age,
       wait_event_type, wait_event, left(query, 80)
FROM pg_stat_activity
WHERE state <> 'idle' OR state = 'idle in transaction'
ORDER BY xact_start NULLS LAST;
```

`idle in transaction` de longa duração é o inimigo: segura locks, impede vacuum, e geralmente é bug de pool no app (transação aberta e não fechada). Defenda-se no servidor — e para locks travados, use `pg_blocking_pids(pid)`:

```conf
idle_in_transaction_session_timeout = '60s'
statement_timeout = '30s'          # ajuste por workload; não deixe 0 em API
lock_timeout = '5s'
```

### 8.4 `pg_stat_io`

Adicionada no **PG 16**. Mostra I/O por tipo de backend e contexto (`normal`, `vacuum`, `bulkread`, `bulkwrite`): hits, reads, writes, extends, evictions. É como você descobre se `shared_buffers` está pequeno (muitos `evictions` em contexto `normal`) ou se o vacuum está dominando o I/O.

**PG 18** ampliou: novas colunas `read_bytes`, `write_bytes`, `extend_bytes` (e removeu `op_bytes`), e **passou a incluir atividade de WAL** — em consequência, `wal_write`, `wal_sync`, `wal_write_time` e `wal_sync_time` foram **removidas de `pg_stat_wal`**. Se você tem dashboard lendo `pg_stat_wal`, ele quebra no upgrade para 18.

### 8.5 Views e extensões úteis

| Objeto | Para quê |
|---|---|
| `pg_stat_database` | Commits/rollbacks, deadlocks, cache hit ratio, tempo de I/O |
| `pg_stat_user_indexes` | `idx_scan = 0` → índice nunca usado, candidato a drop |
| `pg_stat_replication` | Lag de réplicas |
| `pg_replication_slots` | Slot abandonado → WAL acumula e disco enche |
| `pg_locks` | Quem bloqueia quem |
| `pg_stat_progress_vacuum` | Progresso de um vacuum em curso |
| `auto_explain` | Loga o plano de queries lentas **em produção**, sem reproduzir |
| `pg_buffercache` | O que está em `shared_buffers` agora |
| `pgstattuple` | Bloat medido, não estimado |

```conf
# auto_explain: pegue o plano da query lenta em produção
shared_preload_libraries = 'pg_stat_statements,auto_explain'
auto_explain.log_min_duration = '500ms'
auto_explain.log_analyze = on          # cuidado: overhead de instrumentação
```

Índices nunca usados — só confie depois de um ciclo completo de negócio (o relatório mensal usa um índice que fica 29 dias parado):
```sql
SELECT relname, indexrelname, idx_scan, pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE idx_scan = 0 AND indexrelid NOT IN (SELECT conindid FROM pg_constraint)
ORDER BY pg_relation_size(indexrelid) DESC;
```

---

## 9. Backup e recuperação

**A regra:** backup não testado não é backup — é uma esperança com custo de storage. Restore que ninguém executou tem probabilidade não-trivial de falhar exatamente no dia em que importa. Agende um restore real (em outro host, cronometrado) com a mesma seriedade do backup.

### 9.1 Lógico (`pg_dump`) vs físico

| | `pg_dump` / `pg_dumpall` | Físico (`pg_basebackup`, pgBackRest) |
|---|---|---|
| O que é | Comandos SQL / formato custom | Cópia binária do cluster |
| Granularidade | Uma tabela, um schema, um banco | Cluster inteiro |
| Restore parcial | **Sim** — uma tabela | Não |
| Cross-version | **Sim** (restaura em versão maior) | Não (mesma major, mesma arquitetura) |
| Velocidade em base grande | Lenta | Rápida |
| Serve para PITR | **Não** | **Sim** (é a base) |
| Ponto no tempo | Só o instante do dump | Qualquer instante (com WAL) |

A doc é explícita: "`pg_dump` e `pg_dumpall` não produzem backups em nível de sistema de arquivos e **não podem ser usados como parte de uma solução de arquivamento contínuo**. Tais dumps são lógicos e não contêm informação suficiente para serem usados por replay de WAL."

Ou seja: **`pg_dump` não é uma estratégia de backup completa.** Ele resolve "alguém dropou a tabela `categories`" e migração entre versões. Não te dá "restaure para 14:32:07, um segundo antes do UPDATE sem WHERE". Use `-Fc` (custom) ou `-Fd` (directory, permite `-j` paralelo); `-Fp` só para inspeção.

```bash
pg_dump -Fc -Z 6 -d balancie -f balancie-$(date +%F).dump
pg_restore -d balancie -t categories balancie-2026-07-17.dump   # só uma tabela
```

**PG 18:** `pg_dump --statistics` preserva estatísticas do otimizador; `pg_upgrade` agora as preserva por padrão (`--no-statistics` desliga) — antes, todo upgrade era seguido de `ANALYZE` obrigatório e um período de planos ruins.

### 9.2 PITR / WAL archiving

Combinação: **base backup físico + arquivamento contínuo de WAL**. No restore, o Postgres restaura o base e replica os WALs até o alvo (`recovery_target_time`, `_lsn`, `_xid` ou `_name`).

```conf
wal_level = replica
archive_mode = on
archive_command = 'pgbackrest --stanza=balancie archive-push %p'
```

Não escreva `archive_command` na mão com `cp`. Use **pgBackRest** ou **barman** — eles resolvem retenção, verificação, compressão, incremental e paralelismo, que é exatamente onde o script caseiro falha silenciosamente por meses.

Prática comum: base full semanal + WAL contínuo; para bases < 100 GB, **os dois tipos** (físico e lógico), já que o dump lógico é barato e cobre restore parcial. Defina **RPO** (quanto dado aceita perder) e **RTO** (em quanto tempo precisa voltar) antes de escolher: `pg_dump` diário = RPO de 24h; WAL contínuo = RPO de segundos. É decisão de negócio, não de infra.

### 9.3 Replicação: streaming vs lógica

| | Streaming (física) | Lógica |
|---|---|---|
| Granularidade | Cluster inteiro | **Por tabela** |
| Versão | Mesma major | **Cross-version** |
| Escrita no destino | Não (standby read-only) | **Sim**, inclusive em tabelas replicadas |
| DDL | Replicado | **Não replicado** — aplique manualmente |
| Uso | HA / failover, réplica de leitura | Reporting, upgrade sem downtime, consolidação, CDC |
| Bidirecional | Não | Sim |

**Replicação não é backup.** Um `DROP TABLE` replica em milissegundos para todas as réplicas. Réplica protege contra falha de hardware; backup protege contra erro humano e corrupção lógica. Você precisa dos dois.

O caso de uso matador da replicação lógica: **upgrade de major version com downtime de segundos** — replique 17 → 18, valide, vire o tráfego.

---

## 10. Extensões que valem conhecer

| Extensão | Quando |
|---|---|
| `pgcrypto` | Hash e criptografia no banco. **Não** use para senha de app — use argon2/bcrypt na aplicação. Útil para criptografar campo específico em repouso |
| `pg_trgm` | Busca por similaridade e `LIKE '%termo%'` indexável (GIN/GiST trigram). É o que faz "buscar transação por descrição parcial" não ser seq scan |
| `btree_gist` | Misturar tipos escalares com ranges numa exclusion constraint (seção 2.6) |
| `pgstattuple` | Medir bloat de verdade em vez de estimar |
| `pg_buffercache` | Inspecionar o conteúdo de `shared_buffers` |
| `auto_explain` | Capturar plano de query lenta em produção sem reproduzir |
| `postgis` | Dado geoespacial. Padrão de facto da indústria — se tem lat/long e query por proximidade, é isto |
| `timescaledb` | Séries temporais de alto volume (métricas, IoT): particionamento automático, compressão, agregados contínuos. Overkill para transações de finanças pessoais |
| `pgvector` | Embeddings e busca por similaridade (HNSW/IVFFlat). Para features de IA sobre seus dados |
| `pg_repack` | Remover bloat **sem** o `ACCESS EXCLUSIVE` do `VACUUM FULL` |
| `pg_cron` | Agendar jobs dentro do banco (limpeza, refresh de matview) |

---

## Checklist de decisão rápida

- Dinheiro → `numeric(14,2)`; nunca `float`, nunca `money`. String → `text`. Instante → `timestamptz`; dia civil → `date`.
- Intervalo de data em query → meio-aberto (`>= x AND < y`), nunca `BETWEEN`.
- PK → `uuid` v7 se público (PG 18: `uuidv7()`), `bigint GENERATED ALWAYS AS IDENTITY` se interno. Nunca `serial`.
- Conjunto fechado do sistema → `enum`; do usuário → tabela lookup. Lembre: **enum não tem `DROP VALUE`**.
- JSON → `jsonb`. Se a chave aparece num `WHERE`, ela é coluna.
- **Toda FK precisa de índice na coluna referenciadora.** O Postgres não cria; o Prisma não cria.
- Soft delete → unique parcial `WHERE deleted_at IS NULL`. Financeiro histórico → nem soft nem hard: estorno.
- Tabela grande e quente → `autovacuum_vacuum_scale_factor` por tabela (0.01), não o default de 0.1.
- SSD → `random_page_cost = 1.1`, mas só depois de memória e autovacuum ajustados.
- Muitas instâncias → PgBouncer transaction mode + `max_prepared_statements > 0` (≥ 1.21) + `directUrl` para migrations.
- Primeira extensão a instalar em qualquer banco → `pg_stat_statements`.
- Backup → físico + WAL (PITR) para o cluster, `pg_dump` para restore parcial. Teste o restore, ou não conte como backup. **Réplica não é backup.**
