# SQL prático (PostgreSQL)

Abra esta referência ao escrever ou revisar SQL na mão: DDL, DML, `SELECT`, agregações, JOINs, subconsultas, conjuntos, views e SQL moderno (CTEs, window functions, upsert). Foco na **linguagem** e nas armadilhas. Normalização, índices, `EXPLAIN`, transações e modelagem são de outras referências desta skill.

Esquema usado nos exemplos:

```sql
CREATE TABLE accounts (
  id bigserial PRIMARY KEY,
  name varchar(80) NOT NULL,
  type varchar(20) NOT NULL,                    -- checking | savings | credit_card
  currency char(3) NOT NULL DEFAULT 'BRL',
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE categories (
  id bigserial PRIMARY KEY,
  name varchar(60) NOT NULL,
  kind varchar(10) NOT NULL,                    -- income | expense
  parent_id bigint REFERENCES categories(id)
);
CREATE TABLE transactions (
  id bigserial PRIMARY KEY,
  account_id bigint NOT NULL REFERENCES accounts(id),
  category_id bigint REFERENCES categories(id), -- nullable
  description varchar(200) NOT NULL,
  amount numeric(14,2) NOT NULL,                -- negativo = saída
  occurred_at date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
```

---

## 1. DDL

| Tipo | Armadilha |
|---|---|
| `numeric(p,s)` | **dinheiro** e valores exatos. Lento em massa, mas correto — nunca `float` para saldo |
| `double precision` | só grandezas físicas: `0.1 + 0.2 <> 0.3` |
| `bigint` | prefira em PK: `integer` estoura em 2.1 bi |
| `text` / `varchar(n)` | mesmo desempenho no PG; `varchar(n)` só como constraint de tamanho |
| `char(n)` | preenche com espaços à direita — raramente é o que você quer |
| `timestamptz` | **sempre `timestamptz`, nunca `timestamp`** — o sem-tz corrompe na virada de fuso |
| `boolean` | aceita `NULL`: o terceiro estado é esquecido |

O livro (2007, sotaque MySQL) usa `DEC`, `BLOB`, `DATETIME` → no PG: `numeric`, `bytea`, `timestamptz`.

Toda coluna que você vai filtrar ou agregar merece `NOT NULL` ou default explícito. Coluna nullable é uma promessa de que o `NULL` significa algo; se não significa, marque `NOT NULL`.

```sql
ALTER TABLE transactions ADD COLUMN notes text;
ALTER TABLE transactions DROP COLUMN notes;
ALTER TABLE transactions RENAME COLUMN notes TO memo;
ALTER TABLE transactions ALTER COLUMN amount TYPE numeric(16,2);
ALTER TABLE accounts ALTER COLUMN currency TYPE varchar(3) USING currency::varchar;  -- USING controla a conversão
ALTER TABLE transactions ALTER COLUMN description SET NOT NULL;
DROP TABLE IF EXISTS transactions;   -- CASCADE derruba views/FKs dependentes
```

**Armadilhas de `ALTER`:**
- Estreitar tipo (`varchar(50)` → `varchar(10)`) perde dados ou falha. Rode `SELECT max(length(col))` antes.
- `numeric(14,2)` → `integer` **arredonda em silêncio**.
- `DROP COLUMN` é irreversível fora de transação. `SELECT` primeiro, envolva em `BEGIN`.
- PostgreSQL **não reordena colunas** (não há `AFTER`/`FIRST` do MySQL). A ordem física é imutável; ordene na projeção do `SELECT`, que é o único lugar que importa.

---

## 2. DML

```sql
INSERT INTO transactions (account_id, category_id, description, amount, occurred_at)
VALUES (1, 7,    'Mercado',      -234.90, '2026-07-03'),
       (1, 12,   'Salário',      8500.00, '2026-07-05'),
       (2, NULL, 'Transferência', -500.00, '2026-07-05');

UPDATE transactions SET category_id = 7, description = 'Mercado — Extra' WHERE id = 42;
UPDATE transactions SET amount = amount * 1.10 WHERE category_id = 7;
DELETE FROM transactions WHERE occurred_at < '2020-01-01' AND account_id = 3;
```

Números sem aspas; texto/datas com **aspas simples**. Aspas duplas no PG delimitam **identificadores**: `WHERE description = "Mercado"` procura uma *coluna* chamada `Mercado` e dá erro. Apóstrofo em literal se duplica: `'Grover''s Mill'`.

**Nunca use `INSERT INTO t VALUES (...)` sem lista de colunas** em código: qualquer `ADD COLUMN` quebra o insert ou desloca valores em silêncio.

### ARMADILHA CENTRAL: `UPDATE`/`DELETE` sem `WHERE`

```sql
UPDATE transactions SET category_id = 7;  -- reclassificou TUDO
DELETE FROM transactions;                 -- esvaziou a tabela
```

Não há undo fora de transação. Protocolo:

1. Escreva o `WHERE` num `SELECT` e confira a contagem.
2. Troque `SELECT` por `UPDATE`/`DELETE` **mantendo o `WHERE` intacto**.
3. Em produção, envolva e confira antes de confirmar:
   ```sql
   BEGIN;
   DELETE FROM transactions WHERE occurred_at < '2020-01-01' AND account_id = 3;
   -- confira "DELETE 137" contra a contagem do passo 1
   ROLLBACK;  -- ou COMMIT
   ```
4. Melhor: use `RETURNING` (§12) e veja exatamente o que foi tocado.

Sub-armadilha: `WHERE category_id <> 7` **não pega as linhas com `category_id IS NULL`**. Um `DELETE` que você achou que limparia tudo menos a categoria 7 deixa as sem categoria para trás (§4).

---

## 3. SELECT

Ordem **lógica** de avaliação (não a de escrita) — explica quase todo erro:

```
FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → DISTINCT → ORDER BY → LIMIT/OFFSET
```

Daí: o `WHERE` não enxerga aliases do `SELECT` (roda antes); o `ORDER BY` enxerga; o `WHERE` não pode usar agregados (o `GROUP BY` ainda não rodou) — para isso existe `HAVING`.

`SELECT *` serve para exploração. Em código, nomeie as colunas: `*` transporta bytes inúteis, quebra quando o esquema muda e impede index-only scan.

| Operador | Nota |
|---|---|
| `=` / `<>` | com `NULL` retornam `NULL`, não `FALSE` |
| `<` `>` `<=` `>=` | funcionam em texto (collation) e datas |
| `BETWEEN a AND b` | **inclusivo nas duas pontas**; `BETWEEN 60 AND 30` retorna vazio |
| `IN (...)` | cuidado com `NOT IN` + `NULL` |
| `LIKE` / `ILIKE` | `%` = n caracteres, `_` = um; `ILIKE` é case-insensitive (PG) |
| `IS NULL` / `IS NOT NULL` | **a única forma** de testar `NULL` |
| `IS DISTINCT FROM` | `<>` que trata `NULL` como valor comparável |

```sql
-- date: BETWEEN serve
WHERE occurred_at BETWEEN '2026-07-01' AND '2026-07-31'
-- timestamptz: NUNCA BETWEEN. Use meio-aberto [início, fim)
WHERE created_at >= '2026-07-01' AND created_at < '2026-08-01'
```

Por quê: `BETWEEN '2026-07-01' AND '2026-07-31'` corta em `2026-07-31 00:00:00` e **perde o dia 31 inteiro**. `>= início AND < próximo_início` nunca erra.

### Precedência: `AND` liga mais forte que `OR`

```sql
-- ERRADO: lê-se (account_id = 1) OR (account_id = 2 AND amount < 0)
WHERE account_id = 1 OR account_id = 2 AND amount < 0
-- retorna TODAS as transações da conta 1, inclusive as positivas

-- CERTO
WHERE (account_id = 1 OR account_id = 2) AND amount < 0
```

**Sempre parentetize quando `AND` e `OR` aparecem juntos**, mesmo com a precedência a seu favor. O parêntese custa dois caracteres; auditar um relatório errado custa um dia.

`NOT` precede a condição (`WHERE NOT amount BETWEEN 0 AND 100`); prefira a forma positiva quando der.

### LIKE e coringas

**Armadilha do `%` à esquerda:** `LIKE '%mercado%'` não usa índice B-tree — sequential scan garantido. Com `%` só à direita (`'mercado%'`) o índice é usado (em locale não-C, crie com `varchar_pattern_ops`). Para busca por substring de verdade em tabela grande: trigram (`pg_trgm` + GIN) ou full-text — não `LIKE '%...%'`.

Escapar literais: `LIKE '100\%'` (backslash é o default no PG) ou `LIKE '100!%' ESCAPE '!'`.

### ORDER BY, LIMIT/OFFSET, DISTINCT

```sql
SELECT description, amount FROM transactions
 ORDER BY occurred_at DESC, id DESC   -- ASC é default
 LIMIT 20 OFFSET 40;

SELECT DISTINCT category_id FROM transactions;

-- DISTINCT ON (extensão PG): a "primeira" linha de cada grupo
SELECT DISTINCT ON (account_id) account_id, id, amount, occurred_at
  FROM transactions ORDER BY account_id, occurred_at DESC;
```

- **`ORDER BY` sem desempate**: empates saem em ordem arbitrária, que pode mudar entre execuções. Paginação com `LIMIT/OFFSET` sobre ordem não-determinística **repete e pula linhas**. Sempre desempate com coluna única: `ORDER BY occurred_at DESC, id DESC`.
- **`OFFSET` grande é lento**: produz e descarta N linhas. Para paginação profunda use keyset: `WHERE (occurred_at, id) < ('2026-07-03', 918) ORDER BY occurred_at DESC, id DESC LIMIT 20`.
- **`NULL` na ordem**: no PG vem por último em `ASC`, primeiro em `DESC`. Controle com `NULLS FIRST`/`NULLS LAST`.
- **`DISTINCT` não é band-aid**: duplicata inesperada quase sempre é JOIN multiplicando linhas (§6). `DISTINCT` esconde o bug e paga um sort.

---

## 4. NULL — lógica de três valores

O ponto que o livro martela, com razão. `NULL` **não é zero, não é string vazia, e não é igual a nada — nem a outro `NULL`**. Significa "desconhecido". Toda comparação com `NULL` retorna `NULL`, e o `WHERE` só deixa passar `TRUE`:

```sql
WHERE category_id = NULL    -- SEMPRE zero linhas
WHERE category_id <> NULL   -- SEMPRE zero linhas
WHERE category_id IS NULL   -- correto
```

| Expressão | Resultado | | Expressão | Resultado |
|---|---|---|---|---|
| `NULL = NULL` / `NULL <> NULL` | `NULL` | | `TRUE OR NULL` | `TRUE` |
| `NULL IS NULL` | `TRUE` | | `FALSE OR NULL` | `NULL` |
| `TRUE AND NULL` | `NULL` | | `NOT NULL` | `NULL` |
| `FALSE AND NULL` | `FALSE` | | `NULL IS DISTINCT FROM NULL` | `FALSE` |
| `1 IS DISTINCT FROM NULL` | `TRUE` | | | |

### `NOT IN` com NULL — o bug clássico

```sql
-- Se a subconsulta retornar UMA linha NULL, isto retorna ZERO linhas. Sempre.
SELECT * FROM transactions
 WHERE category_id NOT IN (SELECT id FROM categories WHERE kind = 'income');
```

`x NOT IN (1, 2, NULL)` expande para `x <> 1 AND x <> 2 AND x <> NULL`. O último é `NULL`, e `TRUE AND NULL = NULL` — nunca `TRUE`. Resultado vazio, sem erro.

```sql
-- 1. NOT EXISTS: imune a NULL, geralmente o melhor plano
SELECT t.* FROM transactions t
 WHERE NOT EXISTS (SELECT 1 FROM categories c
                    WHERE c.id = t.category_id AND c.kind = 'income');

-- 2. filtrar o NULL da subconsulta
WHERE category_id NOT IN (SELECT id FROM categories
                           WHERE kind = 'income' AND id IS NOT NULL)

-- 3. LEFT JOIN + IS NULL (anti-join manual)
SELECT t.* FROM transactions t
  LEFT JOIN categories c ON c.id = t.category_id AND c.kind = 'income'
 WHERE c.id IS NULL;
```

`IN` com `NULL` é menos traiçoeiro (`x IN (1, NULL)` dá `TRUE` se `x = 1`) mas nunca dá `FALSE` — dá `NULL`. Na prática o `WHERE` filtra igual, mas dentro de `NOT (...)` volta a morder.

```sql
COALESCE(category_id, 0)          -- primeiro não-nulo
NULLIF(amount, 0)                 -- vira NULL se for 0
amount / NULLIF(total, 0)         -- NULL em vez de divisão por zero
category_id IS DISTINCT FROM 7    -- pega também as linhas sem categoria
```

`IS DISTINCT FROM` é o operador que você queria que `<>` fosse.

---

## 5. Agregação e GROUP BY

```sql
SELECT category_id, count(*) AS n, sum(amount) AS total, avg(amount) AS media
  FROM transactions
 WHERE occurred_at >= '2026-07-01'   -- filtra LINHAS, antes de agregar
 GROUP BY category_id
HAVING sum(amount) < -1000           -- filtra GRUPOS, depois de agregar
 ORDER BY total;
```

### `COUNT(*)` vs `COUNT(coluna)`

| Forma | Conta |
|---|---|
| `count(*)` | **linhas** — inclui linhas com colunas nulas |
| `count(category_id)` | linhas onde `category_id IS NOT NULL` |
| `count(DISTINCT category_id)` | valores distintos não-nulos |
| `count(1)` | idêntico a `count(*)` no PG — não é mais rápido, é folclore |

Se `count(*)` e `count(col)` divergem, você descobriu quantos `NULL` a coluna tem. É ferramenta de diagnóstico, não acidente.

### Agregações ignoram NULL

`sum`, `avg`, `min`, `max` **descartam `NULL` em silêncio**. Com `amounts = 100, 200, NULL`:

```
sum(amount)   -- 300  (não NULL)
avg(amount)   -- 150  (300/2, NÃO 300/3!)
count(amount) -- 2
```

`avg` divide pela quantidade de **não-nulos**. Se `NULL` deve valer zero, seja explícito: `avg(COALESCE(amount, 0))` → 100, não 150. Decida a semântica e escreva-a. Em tabela vazia `sum()` retorna `NULL`, não `0`: blinde com `COALESCE(sum(amount), 0)`.

### GROUP BY

Toda coluna do `SELECT` fora de agregação **precisa** estar no `GROUP BY` (ou ser funcionalmente dependente da PK agrupada). Diferente do MySQL antigo, o PG rejeita em vez de inventar um valor.

```sql
-- ERRO: "description" must appear in the GROUP BY clause
SELECT category_id, description, sum(amount) FROM transactions GROUP BY category_id;

-- Ok: agrupou pela PK de accounts → dependência funcional
SELECT a.id, a.name, sum(t.amount)
  FROM accounts a JOIN transactions t ON t.account_id = a.id GROUP BY a.id;
```

### `WHERE` vs `HAVING`

| | `WHERE` | `HAVING` |
|---|---|---|
| Roda | **antes** do `GROUP BY` | **depois** do `GROUP BY` |
| Filtra | linhas individuais | grupos |
| Agregado | **não pode** | pode |
| Custo | reduz o volume que entra na agregação | filtra grupos já computados |

Regra: se a condição fala de **uma linha**, é `WHERE`; se fala de **um grupo**, é `HAVING`. Filtro de linha posto no `HAVING` agrega linhas que seriam descartadas — e frequentemente nem compila.

Para "somar só uma parte dentro do grupo", veja `FILTER` (§12).

---

## 6. JOINs

Modelo mental: todo JOIN é um produto cartesiano com linhas removidas por uma condição. O que muda é **quais linhas sobrevivem quando não há par**.

| JOIN | Sobrevivem | Quando |
|---|---|---|
| `CROSS JOIN` | todas × todas, sem condição | gerar combinações (calendário × contas); raramente intencional |
| `INNER JOIN` | só as que casam dos **dois** lados | o caso normal |
| `LEFT JOIN` | **todas de A** + as de B que casam; sem par → `NULL` em B | "todas as contas, mesmo com total zero" |
| `RIGHT JOIN` | espelho do `LEFT` | prefira sempre `LEFT` e reordene as tabelas |
| `FULL OUTER JOIN` | todas dos dois lados | reconciliação: achar órfãos dos dois lados |
| `NATURAL JOIN` | inner implícito por colunas homônimas | **não use** |
| self join | tabela consigo mesma, via aliases | hierarquia, comparar linhas da mesma tabela |

```sql
SELECT t.occurred_at, t.description, t.amount, a.name AS conta, c.name AS categoria
  FROM transactions t
  INNER JOIN accounts   a ON a.id = t.account_id
  INNER JOIN categories c ON c.id = t.category_id;
```

Repare: transações com `category_id IS NULL` **somem** — o inner join não acha par. Fonte constante de "faltam linhas no relatório". Se as sem-categoria devem aparecer, o join com `categories` tem que ser `LEFT`.

### Armadilha: `WHERE` num LEFT JOIN vira INNER JOIN

```sql
-- ERRADO: o WHERE descarta as linhas onde t.* é NULL, matando o LEFT
SELECT a.name, count(t.id) FROM accounts a
  LEFT JOIN transactions t ON t.account_id = a.id
 WHERE t.occurred_at >= '2026-07-01'    -- NULL >= data → NULL → descartada
 GROUP BY a.id, a.name;

-- CERTO: condição sobre a tabela do lado opcional vai no ON
SELECT a.name, count(t.id) FROM accounts a
  LEFT JOIN transactions t ON t.account_id = a.id
                          AND t.occurred_at >= '2026-07-01'
 GROUP BY a.id, a.name;
```

Regra: no `LEFT JOIN`, condição sobre a tabela da **esquerda** vai no `WHERE`; sobre a da **direita**, no `ON`. Única exceção intencional: o anti-join.

```sql
-- anti-join: categorias nunca usadas
SELECT c.* FROM categories c
  LEFT JOIN transactions t ON t.category_id = c.id
 WHERE t.id IS NULL;
```

### ARMADILHA MAIOR: JOIN que multiplica linhas e destrói o SUM

A que mais gera relatório financeiro errado. Se uma transação tem N tags, o join **duplica a transação N vezes** e o `SUM(amount)` conta o valor N vezes:

```sql
CREATE TABLE transaction_tags (
  transaction_id bigint NOT NULL REFERENCES transactions(id),
  tag_id bigint NOT NULL REFERENCES tags(id),
  PRIMARY KEY (transaction_id, tag_id)
);

-- ERRADO: uma transação de -100 com 3 tags entra como -300
SELECT a.name, sum(t.amount) FROM accounts a
  JOIN transactions     t  ON t.account_id = a.id
  JOIN transaction_tags tt ON tt.transaction_id = t.id
 GROUP BY a.id, a.name;
```

`SELECT DISTINCT` **não conserta**: as duplicatas têm valores idênticos e o `DISTINCT` só agiria após a agregação, tarde demais. `sum(DISTINCT amount)` é pior — colapsa duas compras legítimas de -50 numa só.

```sql
-- 1. agregue ANTES de juntar
WITH totais AS (SELECT account_id, sum(amount) AS total
                  FROM transactions GROUP BY account_id)
SELECT a.name, totais.total FROM accounts a JOIN totais ON totais.account_id = a.id;

-- 2. se o join é só para filtrar, use EXISTS — não projeta, não multiplica
SELECT a.name, sum(t.amount) FROM accounts a
  JOIN transactions t ON t.account_id = a.id
 WHERE EXISTS (SELECT 1 FROM transaction_tags tt
                WHERE tt.transaction_id = t.id AND tt.tag_id = 5)
 GROUP BY a.id, a.name;
```

Diagnóstico: se `count(*)` antes e depois do JOIN divergem sem que você esperasse, o join é 1:N e todo `SUM`/`AVG`/`COUNT` sobre o lado "1" está inflado.

### Self join

```sql
SELECT c.name AS categoria, p.name AS pai
  FROM categories c
  LEFT JOIN categories p ON p.id = c.parent_id;
```

`LEFT`, não `INNER`: as raízes têm `parent_id IS NULL` e sumiriam.

### NATURAL JOIN — não use

Junta por **todas** as colunas homônimas, implicitamente. No dia em que alguém adicionar `created_at` às duas tabelas, a query passa a juntar por `created_at` e retorna zero linhas — sem erro, sem aviso. É uma bomba ligada ao esquema. Escreva o `ON`. `USING (account_id)` é meio-termo aceitável: explícito e não duplica a coluna.

---

## 7. Subconsultas

```sql
-- escalar (um valor)
SELECT description, amount FROM transactions
 WHERE amount < (SELECT avg(amount) FROM transactions WHERE amount < 0);

-- como coluna do SELECT: legível, mas roda 1x por linha externa
SELECT a.name, (SELECT count(*) FROM transactions t WHERE t.account_id = a.id) AS n
  FROM accounts a;

-- correlacionada: t2 depende de t → conceitualmente roda 1x por linha externa
SELECT t.* FROM transactions t
 WHERE t.amount = (SELECT max(t2.amount) FROM transactions t2
                    WHERE t2.account_id = t.account_id);
```

Se uma subconsulta escalar retornar mais de uma linha, o PG dá erro **em runtime** — bug que só aparece quando os dados crescem. Garanta unicidade com agregação ou `LIMIT 1` + `ORDER BY` determinístico.

**Não-correlacionada** roda sozinha, uma vez. **Correlacionada** referencia a query externa: é cara, e quase sempre substituível por window function (§12).

```sql
WHERE category_id IN (SELECT id FROM categories WHERE kind = 'income')
WHERE EXISTS     (SELECT 1 FROM transaction_tags tt WHERE tt.transaction_id = t.id)
WHERE NOT EXISTS (SELECT 1 FROM transaction_tags tt WHERE tt.transaction_id = t.id)
WHERE amount > ANY (SELECT amount FROM transactions WHERE account_id = 2)  -- > o MENOR
WHERE amount > ALL (SELECT amount FROM transactions WHERE account_id = 2)  -- > o MAIOR
```

`= ANY (...)` é exatamente `IN (...)`. `<> ALL (...)` é exatamente `NOT IN (...)` — e herda o bug com `NULL`.

**`ALL` com conjunto vazio retorna `TRUE`**; `ANY` com vazio retorna `FALSE`. "Só aprove se for maior que todos os limites" aprova tudo quando não há limites cadastrados.

### Subconsulta ou JOIN?

| Situação | Escolha |
|---|---|
| Preciso de **colunas** da outra tabela no resultado | JOIN |
| Só preciso **filtrar** por existência | `EXISTS` / `NOT EXISTS` |
| Comparar contra um **agregado** (`avg`, `max`) | subconsulta escalar, CTE ou window function |
| A outra tabela é 1:N e vou agregar | agregue numa CTE **antes** de juntar (§6) |
| Query de 5 níveis | CTE (`WITH`) — nomeie os passos |

O livro afirma que "join é sempre mais eficiente que subconsulta". **Desatualizado**: o planejador do PG moderno reescreve `IN`/`EXISTS` como semi-join e frequentemente produz o mesmo plano. Escolha por **clareza** e meça com `EXPLAIN ANALYZE` quando importar.

---

## 8. Conjuntos

| Operador | Retorna | Duplicatas |
|---|---|---|
| `UNION` | A **ou** B | **remove** (custa sort/hash) |
| `UNION ALL` | A **ou** B | **mantém** — mais rápido |
| `INTERSECT` | A **e** B | remove |
| `EXCEPT` | A **mas não** B | remove |

```sql
SELECT description, amount, occurred_at FROM transactions_2025
UNION ALL
SELECT description, amount, occurred_at FROM transactions_2026
ORDER BY occurred_at DESC;   -- ORDER BY UMA vez, no fim, sobre o todo
```

Mesmo número de colunas, mesma ordem, tipos compatíveis. Nomes vêm do primeiro `SELECT`. `ORDER BY` só no final.

**Use `UNION ALL` por padrão.** `UNION` deduplica, o que custa caro e pode remover linhas legítimas idênticas — duas compras de R$ 50 no mesmo dia e categoria são dois fatos, não um. Só use `UNION` quando deduplicar for o objetivo declarado.

`INTERSECT`/`EXCEPT` existem no PG (o livro avisa que não existiam no MySQL de 2007). Legíveis, mas frequentemente mais lentos que o `EXISTS`/`NOT EXISTS` equivalente.

---

## 9. CASE

```sql
SELECT description, amount,
       CASE WHEN amount > 0     THEN 'entrada'
            WHEN amount < -1000 THEN 'saída grande'
            WHEN amount < 0     THEN 'saída'
            ELSE 'zerada'
       END AS tipo
  FROM transactions;
```

**A ordem dos `WHEN` importa**: o `CASE` para na primeira condição verdadeira. Se `WHEN amount < 0 THEN 'saída'` viesse antes de `WHEN amount < -1000`, nada seria 'saída grande'. Condições **específicas primeiro**.

Sem `ELSE`, o resultado é `NULL` para o que não casa — e você reencontra todos os problemas de §4. Escreva o `ELSE` sempre, nem que seja `ELSE NULL` explícito, para documentar a intenção.

```sql
-- UPDATE com CASE: um comando no lugar de N
UPDATE transactions
   SET category_id = CASE
     WHEN description ILIKE '%mercado%' THEN 7
     WHEN description ILIKE '%uber%'    THEN 11
     ELSE category_id                   -- preserva o que não casou
   END
 WHERE category_id IS NULL;
```

Funciona em `SELECT`, `WHERE`, `ORDER BY`, `GROUP BY`, `UPDATE ... SET` e dentro de agregados (mas veja `FILTER`, §12).

---

## 10. Funções do dia a dia

```sql
-- TEXTO
lower upper initcap length trim ltrim rtrim  substring(s FROM 1 FOR 3)  left(s,3) right(s,2)
replace(s,'de','para')  position('@' IN email)  regexp_replace(s,'\s+',' ','g')  s ~ '^[0-9]+$'
split_part('SAO PAULO, SP', ',', 1)   -- 'SAO PAULO'  (≈ SUBSTRING_INDEX do livro)
a || ' ' || b   -- NULL || 'x' = NULL !      concat(a,' ',b) / concat_ws('-',a,b,c) -- ignoram NULL

-- NÚMERO
abs  round(x,2)  ceil  floor  trunc(x,2)  mod(x,y)  power  sqrt  greatest  least  random

-- DATA / CAST
current_date  now()  now() AT TIME ZONE 'America/Sao_Paulo'  age(now(), created_at)
date_trunc('month', occurred_at)   extract(YEAR FROM occurred_at)   occurred_at + interval '1 month'
to_char(occurred_at, 'YYYY-MM')    to_date('03/07/2026', 'DD/MM/YYYY')    '2026-07-03'::date
generate_series('2026-01-01'::date, '2026-12-01'::date, '1 month')   -- gerar calendário
```

- **`||` propaga `NULL`**: `'Conta: ' || NULL` é `NULL`, não `'Conta: '`. Use `concat()` ou `COALESCE(col, '')`.
- Funções de string **não alteram a tabela** — retornam cópia. Para persistir: `UPDATE ... SET col = f(col)`.
- **`round`**: `round(numeric, n)` é half-up; `round(double precision)` é banker's rounding. `round(2.5::numeric)` = 3, `round(2.5::float8)` = 2. Para dinheiro: `numeric`, sempre.
- **`date_trunc`/`extract` sobre `timestamptz` usam o TimeZone da sessão**: um worker em UTC atribui as transações do dia 1º de madrugada ao mês anterior. Seja explícito: `date_trunc('month', created_at AT TIME ZONE 'America/Sao_Paulo')`.
- **Função sobre a coluna mata o índice**: `WHERE date_trunc('month', occurred_at) = '2026-07-01'` não usa índice em `occurred_at`. Reescreva como intervalo. Vale para `extract`, `lower()`, casts — qualquer expressão que envolva a coluna.

---

## 11. Views

```sql
CREATE VIEW monthly_by_category AS
SELECT date_trunc('month', t.occurred_at)::date AS mes,
       c.name AS categoria, sum(t.amount) AS total, count(*) AS n
  FROM transactions t
  LEFT JOIN categories c ON c.id = t.category_id
 GROUP BY 1, 2;

SELECT * FROM monthly_by_category WHERE mes = '2026-07-01';
DROP VIEW monthly_by_category;
CREATE OR REPLACE VIEW ...;   -- redefine mantendo GRANTs (tipos devem bater)
```

Uma view é uma **consulta nomeada**, não uma tabela: não armazena, roda toda vez, sempre reflete o estado atual. Serve para (a) esconder joins repetidos, (b) estabilizar um contrato de leitura enquanto o esquema base muda, (c) restringir colunas sensíveis via `GRANT` na view em vez da tabela. Não tem índice próprio — a performance é a da consulta subjacente.

### Atualizar através da view

Auto-atualizável no PG se: **uma** tabela no `FROM`; sem `DISTINCT`, `GROUP BY`, `HAVING`, `LIMIT`, `UNION`, window ou agregado; colunas são referências simples.

**Armadilha:** sem `WITH CHECK OPTION` você insere pela view uma linha que **não aparece na própria view**:

```sql
CREATE VIEW expense_categories AS SELECT * FROM categories WHERE kind = 'expense';
INSERT INTO expense_categories (name, kind) VALUES ('Bônus', 'income');
-- inserido na tabela base e some da view. Fantasma.

CREATE VIEW expense_categories AS
SELECT * FROM categories WHERE kind = 'expense'
WITH CHECK OPTION;   -- agora o insert acima é rejeitado
```

Views com `SUM`/`COUNT`/`GROUP BY`/`DISTINCT` são **somente leitura** — não há como decompor um agregado de volta em linhas. Para escrita em view complexa existe `INSTEAD OF` trigger, mas aí pergunte-se se a view é o lugar certo.

---

## 12. Nota prática: SQL moderno (o livro de 2007 não tem)

Não vem do livro. É o que hoje é obrigatório, e resolve melhor vários problemas que o livro resolve com subconsulta correlacionada.

### CTEs — `WITH`

```sql
WITH gastos_mes AS (
  SELECT category_id, sum(amount) AS total FROM transactions
   WHERE occurred_at >= '2026-07-01' AND occurred_at < '2026-08-01' AND amount < 0
   GROUP BY category_id
), com_nome AS (
  SELECT c.name AS categoria, g.total
    FROM gastos_mes g JOIN categories c ON c.id = g.category_id
)
SELECT categoria, total, round(100 * total / sum(total) OVER (), 1) AS pct
  FROM com_nome ORDER BY total;
```

Note o padrão de §6: `gastos_mes` **agrega antes de juntar**, então o join não pode inflar o `SUM`.

Planejamento: até o PG 11 a CTE era sempre materializada (barreira de otimização); do PG 12 em diante é inlined por padrão quando usada uma vez. Force com `AS MATERIALIZED` / `AS NOT MATERIALIZED`.

### `WITH RECURSIVE`

```sql
WITH RECURSIVE tree AS (
  SELECT id, name, parent_id, 1 AS depth, name::text AS path
    FROM categories WHERE parent_id IS NULL          -- âncora
  UNION ALL
  SELECT c.id, c.name, c.parent_id, t.depth + 1, t.path || ' > ' || c.name
    FROM categories c JOIN tree t ON t.id = c.parent_id
   WHERE t.depth < 10                                -- guarda contra ciclo. SEMPRE.
)
SELECT repeat('  ', depth - 1) || name AS arvore, path FROM tree ORDER BY path;
```

Dado cíclico (`A` pai de `B` pai de `A`) roda para sempre. Sempre limite a profundidade ou rastreie o caminho. `UNION` sem `ALL` também interrompe ciclos ao deduplicar, ao custo de um sort por iteração.

### Window functions

Agregam **sem colapsar linhas**. Onde o livro usa subconsulta correlacionada, use isto.

```sql
SELECT occurred_at, description, amount,
       sum(amount)  OVER (PARTITION BY account_id ORDER BY occurred_at, id) AS saldo_acum,
       sum(amount)  OVER (PARTITION BY account_id)                          AS total_conta,
       row_number() OVER (PARTITION BY account_id ORDER BY amount)          AS rn,
       lag(amount)  OVER (PARTITION BY account_id ORDER BY occurred_at)     AS anterior,
       amount - lag(amount) OVER (PARTITION BY account_id ORDER BY occurred_at) AS delta
  FROM transactions;
```

| Função | Comportamento / uso |
|---|---|
| `row_number()` | numera sem repetir (1,2,3) — "a primeira de cada grupo" |
| `rank()` | empatados dividem e **pula** a seguinte (1,1,3) |
| `dense_rank()` | empatados dividem, **não pula** (1,1,2) — "top 3 valores distintos" |
| `lag/lead(col, n, default)` | comparar com linha anterior/seguinte |
| `sum/avg/count/min/max ... OVER` | agregado sem colapsar linhas |

Padrão canônico "a última transação de cada conta":

```sql
WITH ranked AS (
  SELECT t.*, row_number() OVER (PARTITION BY account_id
                                 ORDER BY occurred_at DESC, id DESC) AS rn
    FROM transactions t
)
SELECT * FROM ranked WHERE rn = 1;
```

- **Não dá para filtrar por window function no `WHERE`** (a janela é computada junto com o `SELECT`, depois do `WHERE`). Envolva numa CTE, como acima.
- **Frame default**: `sum(x) OVER (ORDER BY d)` usa `RANGE ... CURRENT ROW`, que em empates de `d` inclui **todos** os empatados — o acumulado "salta". Para acumulado linha a linha, seja explícito:
  ```sql
  sum(amount) OVER (PARTITION BY account_id ORDER BY occurred_at, id
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
  avg(amount) OVER (PARTITION BY account_id ORDER BY occurred_at
                    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)   -- média móvel 7
  ```
- `last_value()` com frame default retorna a linha atual, não a última da partição — clássico.
- `WINDOW w AS (...)` nomeia janelas repetidas: `sum(amount) OVER w, row_number() OVER w`.

### `FILTER` — agregação condicional limpa

```sql
SELECT account_id,
       sum(amount) FILTER (WHERE amount > 0) AS entradas,
       sum(amount) FILTER (WHERE amount < 0) AS saidas,
       count(*)    FILTER (WHERE category_id IS NULL) AS sem_categoria,
       count(*)                                        AS total
  FROM transactions GROUP BY account_id;
```

Vantagem sobre `sum(CASE WHEN ... ELSE 0 END)`: retorna `NULL` quando nada casa (correto: "não havia entradas") em vez de `0` (ambíguo). E `count(*) FILTER` é impossível com `CASE` sem gambiarra.

### `INSERT ... ON CONFLICT` (upsert)

```sql
INSERT INTO categories (name, kind) VALUES ('Mercado', 'expense')
ON CONFLICT (name) DO NOTHING;

INSERT INTO budgets (category_id, month, limit_cents) VALUES (7, '2026-07-01', 1200.00)
ON CONFLICT (category_id, month)
DO UPDATE SET limit_cents = EXCLUDED.limit_cents
WHERE budgets.limit_cents <> EXCLUDED.limit_cents   -- evita write inútil
RETURNING *;
```

`EXCLUDED` é a pseudo-tabela com os valores que **teriam sido** inseridos; a tabela real vai pelo nome. **Requisito:** `ON CONFLICT (cols)` precisa de índice único/constraint correspondente, senão erro.

### `RETURNING`

```sql
INSERT INTO transactions (...) VALUES (...) RETURNING id, created_at;
UPDATE transactions SET category_id = 7 WHERE category_id IS NULL RETURNING id, description;
DELETE FROM transactions WHERE occurred_at < '2020-01-01' RETURNING *;
```

Elimina o round-trip "insere e depois busca o id". `RETURNING` num `DELETE` dentro de `BEGIN`/`ROLLBACK` é a forma mais segura de auditar um delete perigoso antes de confirmá-lo.

### `GROUPING SETS`, `ROLLUP`, `CUBE`

```sql
-- total por (conta, categoria), por conta, e geral — numa passada
SELECT a.name AS conta, c.name AS categoria, sum(t.amount) AS total
  FROM transactions t
  JOIN accounts a ON a.id = t.account_id
  LEFT JOIN categories c ON c.id = t.category_id
 GROUP BY ROLLUP (a.name, c.name);
```

`ROLLUP (a,b)` = `GROUPING SETS ((a,b), (a), ())` — hierárquico. `CUBE (a,b)` = todas as combinações.

**Armadilha:** subtotais vêm com `NULL` nas colunas agregadas, indistinguíveis de `NULL` real dos dados. Diferencie com `GROUPING()`:

```sql
SELECT CASE WHEN GROUPING(a.name) = 1 THEN 'TOTAL GERAL' ELSE a.name END AS conta, ...
```

---

## 13. Segurança e privilégios (resumo)

Outra referência aprofunda. O essencial:

```sql
CREATE ROLE reporter LOGIN PASSWORD 'trocar';
GRANT CONNECT ON DATABASE balancie TO reporter;
GRANT USAGE ON SCHEMA public TO reporter;
GRANT SELECT ON transactions TO reporter;
GRANT SELECT (id, name, type) ON accounts TO reporter;   -- por coluna
GRANT SELECT ON ALL TABLES IN SCHEMA public TO reporter;
GRANT reporter TO alice;                                  -- role como grupo
REVOKE INSERT ON transactions FROM reporter;
```

- **Não use superusuário na aplicação.** Uma role por perfil de acesso.
- **Não compartilhe conta entre pessoas**: perde-se a auditoria e a rotação de senha vira evento traumático.
- `WITH GRANT OPTION` deixa repassar o privilégio; `REVOKE ... CASCADE` derruba a cadeia inteira, `RESTRICT` falha se houver dependentes.
- **Views são ferramenta de segurança**: `SELECT` na view que expõe só o permitido, nenhum acesso à tabela base.
- Para multi-tenant, o mecanismo correto é Row Level Security (`ENABLE ROW LEVEL SECURITY` + `CREATE POLICY`) — assunto da referência de segurança.

---

## 14. Checklist de revisão

- [ ] `UPDATE`/`DELETE` tem `WHERE`? Rodou o `SELECT count(*)` com o mesmo `WHERE` antes?
- [ ] Comparação com possível `NULL` usa `IS NULL` / `IS DISTINCT FROM`, não `=` / `<>`?
- [ ] Tem `NOT IN` com subconsulta? Trocou por `NOT EXISTS`?
- [ ] `AND` e `OR` na mesma cláusula estão parentetizados?
- [ ] O JOIN pode multiplicar linhas? Se sim, agregou antes numa CTE?
- [ ] `LEFT JOIN` com condição da tabela direita — está no `ON`, não no `WHERE`?
- [ ] `count(*)` vs `count(col)` — escolheu conscientemente?
- [ ] Filtro de linha está no `WHERE` (não no `HAVING`)?
- [ ] `ORDER BY` desempata com coluna única (paginação determinística)?
- [ ] `UNION` deveria ser `UNION ALL`?
- [ ] Filtro em `timestamptz` usa `>= x AND < y`, sem função sobre a coluna?
- [ ] `CASE` tem `ELSE` e as condições específicas vêm primeiro?
- [ ] `INSERT` nomeia as colunas?
- [ ] Dinheiro é `numeric`, nunca `float`?
