# Migrations e o banco em produção

Abra esta referência quando precisar **mudar o schema de um banco que já tem dados e tráfego**: adicionar/remover coluna, trocar tipo, criar índice, adicionar constraint, fazer backfill, particionar, carregar volume, ou decidir se uma migration do Prisma pode ir para produção como foi gerada. Não cobre normalização, teoria relacional, design de índices ou escolha de tipos — outras referências tratam disso.

Contexto de validação: **PostgreSQL 18** é a versão estável atual (lançada em 25/09/2025; minor 18.4 de 14/05/2026). Versões suportadas em julho de 2026: 18, 17, 16, 15 e 14 (14 sai de suporte em 12/11/2026). PostgreSQL 19 está em Beta 2 — não assuma nada dele em produção. Prisma ORM está na linha **7.x**.

---

## 1. A tabela que importa: operação DDL → trava? → por quanto → alternativa segura

Regra de base do PostgreSQL: **`ALTER TABLE` adquire `ACCESS EXCLUSIVE` por padrão**, salvo nas formas explicitamente documentadas como menos restritivas. `ACCESS EXCLUSIVE` conflita com *todos* os modos — inclusive `ACCESS SHARE`, que é o lock de um `SELECT` simples. É o único modo que bloqueia leitura.

Três perguntas distintas — não confunda:

1. **Qual lock?** Define *quem* fica bloqueado.
2. **Quanto tempo o lock é segurado?** Define o *dano*. Um `ACCESS EXCLUSIVE` de 2ms é inofensivo; de 40 minutos derruba o produto.
3. **Reescreve a tabela?** Rewrite = cópia nova completa + índices, precisa de até **o dobro do espaço em disco**, e segura o `ACCESS EXCLUSIVE` durante toda a cópia.

| Operação | Lock | Segura por | Rewrite? | Alternativa segura |
|---|---|---|---|---|
| `ADD COLUMN` sem default | `ACCESS EXCLUSIVE` | ms (catálogo) | Não | Seguro. Só cuidado com o lock queue (§2). |
| `ADD COLUMN ... DEFAULT <constante>` | `ACCESS EXCLUSIVE` | ms (catálogo) | **Não, desde PG 11** | Seguro em ≥11. O default é avaliado no momento do statement e guardado em `pg_attribute.attmissingval` (`atthasmissing = true`). |
| `ADD COLUMN ... DEFAULT <volátil>` (`gen_random_uuid()`, `clock_timestamp()`, `random()`) | `ACCESS EXCLUSIVE` | **duração do rewrite** | **Sim** | `ADD COLUMN` nulo → `ALTER COLUMN SET DEFAULT` → backfill em lotes (§4). |
| `ADD COLUMN ... GENERATED ALWAYS AS (...) STORED` | `ACCESS EXCLUSIVE` | duração do rewrite | **Sim** | Coluna comum + trigger, ou aceite janela. **Virtual generated column (PG 18) nunca reescreve.** |
| `ADD COLUMN ... GENERATED ... AS IDENTITY` | `ACCESS EXCLUSIVE` | duração do rewrite | **Sim** | Expand/contract (§3). |
| `ADD COLUMN` de domain com constraint | `ACCESS EXCLUSIVE` | duração do rewrite | **Sim** | Use o tipo base + `CHECK ... NOT VALID` (§ abaixo). |
| `ADD COLUMN ... NOT NULL` sem default | `ACCESS EXCLUSIVE` | falha se a tabela tiver linhas | — | Nullable → backfill → `SET NOT NULL` via CHECK. |
| `DROP COLUMN` | `ACCESS EXCLUSIVE` | ms (catálogo) | Não | Rápido no banco. **O perigo é a aplicação**, não o lock — ver §3/§5. Espaço só volta com `VACUUM FULL`/rewrite. |
| `ALTER COLUMN TYPE` (genérico: `int` → `bigint`, `text` → `int`, `numeric(10,2)` → `numeric(12,2)`) | `ACCESS EXCLUSIVE` | **duração do rewrite da tabela + todos os índices** | **Sim** | Expand/contract (§3). Nova coluna, backfill, troca. |
| `ALTER COLUMN TYPE` binário-coercível (`varchar` ↔ `text` sem mudar collation) | `ACCESS EXCLUSIVE` | ms | **Não** | Seguro. Regra da doc: sem rewrite quando o `USING` não muda o conteúdo e o tipo antigo é binário-coercível para o novo (ou domain irrestrito sobre ele). |
| `ALTER COLUMN TYPE varchar(50)` → `varchar(120)` (**aumentar**) | `ACCESS EXCLUSIVE` | ms | **Não, desde PG 9.2** | Seguro. O limite é um check implícito. |
| `ALTER COLUMN TYPE varchar(50)` → `varchar(20)` (**diminuir**) | `ACCESS EXCLUSIVE` | scan/rewrite completo | **Sim** | Não diminua. Se precisar validar tamanho, `CHECK (length(col) <= 20) NOT VALID` + `VALIDATE`. |
| `ALTER COLUMN SET NOT NULL` (direto) | `ACCESS EXCLUSIVE` | **scan completo da tabela** | Não (mas bloqueia leitura e escrita durante o scan) | O truque do CHECK — ver logo abaixo. |
| `ALTER COLUMN DROP NOT NULL` | `ACCESS EXCLUSIVE` | ms | Não | Seguro. |
| `ALTER COLUMN SET DEFAULT` / `DROP DEFAULT` | `ACCESS EXCLUSIVE` | ms | Não | Seguro. |
| `ADD CONSTRAINT ... CHECK (...)` (sem `NOT VALID`) | `ACCESS EXCLUSIVE` | **scan completo** | Não | `... NOT VALID` + `VALIDATE CONSTRAINT` em migration separada. |
| `ADD CONSTRAINT ... CHECK (...) NOT VALID` | `ACCESS EXCLUSIVE` | ms | Não | Seguro. Já passa a valer para linhas novas/alteradas. |
| `VALIDATE CONSTRAINT` | **`SHARE UPDATE EXCLUSIVE`** | scan completo, **sem bloquear leitura nem escrita** | Não | Este é o passo caro-mas-seguro. |
| `ADD FOREIGN KEY` (sem `NOT VALID`) | `SHARE ROW EXCLUSIVE` na tabela **e** na referenciada | scan completo; **bloqueia escrita nas duas** | Não | `NOT VALID` + `VALIDATE`. |
| `ADD FOREIGN KEY ... NOT VALID` | `SHARE ROW EXCLUSIVE` nas duas | ms | Não | Seguro. Ainda bloqueia escrita brevemente — use `lock_timeout`. |
| `ADD PRIMARY KEY` / `ADD UNIQUE` (direto) | `ACCESS EXCLUSIVE` | duração da construção do índice | Não | `CREATE UNIQUE INDEX CONCURRENTLY` → `ADD CONSTRAINT ... USING INDEX`. |
| `ADD CONSTRAINT ... UNIQUE USING INDEX idx` | `ACCESS EXCLUSIVE` | ms | Não | Seguro (com o índice já pronto). |
| `CREATE INDEX` (sem `CONCURRENTLY`) | `SHARE` | duração da construção; **bloqueia escrita, permite leitura** | Não | `CREATE INDEX CONCURRENTLY`. |
| `CREATE INDEX CONCURRENTLY` | `SHARE UPDATE EXCLUSIVE` | duração (mais longa: **dois scans**), **não bloqueia leitura nem escrita** | Não | Padrão em produção. Não roda dentro de transação. |
| `DROP INDEX` | `ACCESS EXCLUSIVE` | ms | Não | Curto, mas entra na fila de locks (§2). |
| `DROP INDEX CONCURRENTLY` | `SHARE UPDATE EXCLUSIVE` | curto | Não | Preferível. Não roda em transação; não aceita `CASCADE`. |
| `REINDEX INDEX` | `ACCESS EXCLUSIVE` | duração | Sim (do índice) | `REINDEX INDEX CONCURRENTLY`. |
| `ALTER TABLE RENAME COLUMN` | `ACCESS EXCLUSIVE` | ms | Não | **Instantâneo no banco e destrutivo para a aplicação.** Expand/contract (§3). |
| `ALTER TABLE RENAME TO` | `ACCESS EXCLUSIVE` | ms | Não | Mesma coisa. Nunca em deploy único. |
| `ALTER TABLE SET LOGGED` / `SET UNLOGGED` | `ACCESS EXCLUSIVE` | duração do rewrite | **Sim** | Só em tabelas de staging. |
| `ALTER TABLE SET (fillfactor = ...)`, autovacuum/TOAST params, `parallel_workers` | `SHARE UPDATE EXCLUSIVE` | ms | Não | Seguro. |
| `ALTER TABLE SET STATISTICS`, `CLUSTER ON` | `SHARE UPDATE EXCLUSIVE` | ms | Não | Seguro. |
| `ATTACH PARTITION` | `SHARE UPDATE EXCLUSIVE` no pai; `ACCESS EXCLUSIVE` na partição (e na default) | scan de validação, **exceto** se houver `CHECK` equivalente já validado | Não | Sempre crie o `CHECK` casando com os bounds antes. |
| `DETACH PARTITION CONCURRENTLY` | duas transações: `SHARE UPDATE EXCLUSIVE` no pai; `ACCESS EXCLUSIVE` na partição no final | curto | Não | Preferível ao `DETACH` simples. |
| `TRUNCATE` | `ACCESS EXCLUSIVE` | ms | (recria arquivo) | Ok em staging. Em produção, nunca casualmente. |
| `VACUUM FULL` / `CLUSTER` | `ACCESS EXCLUSIVE` | duração da reescrita | **Sim** | `pg_repack`. |

### O truque do `SET NOT NULL` (PG ≥ 12)

A doc do `ALTER TABLE` é explícita: o scan do `SET NOT NULL` é pulado **se existir um `CHECK` válido que prove que nenhum NULL pode existir** (e que não seja removido no mesmo comando). Isso só foi implementado no PostgreSQL 12. Em 11 e anteriores, não há como evitar o scan sob `ACCESS EXCLUSIVE`.

```sql
-- Migration 1: instantânea. Já vale para linhas novas.
ALTER TABLE transactions
  ADD CONSTRAINT transactions_bank_account_id_not_null
  CHECK (bank_account_id IS NOT NULL) NOT VALID;

-- Migration 2: backfill das linhas antigas (§4), em lotes.

-- Migration 3: scan completo sob SHARE UPDATE EXCLUSIVE — não bloqueia tráfego.
ALTER TABLE transactions
  VALIDATE CONSTRAINT transactions_bank_account_id_not_null;

-- Migration 4: instantânea — o planner enxerga o CHECK válido e pula o scan.
ALTER TABLE transactions ALTER COLUMN bank_account_id SET NOT NULL;
ALTER TABLE transactions DROP CONSTRAINT transactions_bank_account_id_not_null;
```

Os passos 1, 3 e 4 são migrations **separadas** — cada uma em sua transação, cada uma com seu `lock_timeout`.

### O padrão `NOT VALID` para foreign keys

```sql
-- Instantâneo (SHARE ROW EXCLUSIVE nas duas tabelas, por milissegundos).
ALTER TABLE transactions
  ADD CONSTRAINT transactions_category_id_fkey
  FOREIGN KEY (category_id) REFERENCES categories(id)
  ON DELETE RESTRICT
  NOT VALID;

-- Depois, separado: SHARE UPDATE EXCLUSIVE, não bloqueia escrita.
ALTER TABLE transactions VALIDATE CONSTRAINT transactions_category_id_fkey;
```

Por que funciona: a doc diz que "a validação não precisa bloquear updates concorrentes, porque sabe que outras transações estão aplicando a constraint nas linhas que inserem ou atualizam; só as linhas pré-existentes precisam ser checadas".

**Sempre crie o índice do lado FK antes** (`CREATE INDEX CONCURRENTLY` em `transactions(category_id)`) — o PostgreSQL não cria índice automático em FK, e sem ele qualquer `DELETE` em `categories` faz seq scan em `transactions`.

### `CREATE INDEX CONCURRENTLY`: o que a doc realmente diz

- Faz **dois scans** da tabela, em duas transações, e espera transações concorrentes terminarem entre eles. É mais trabalho total e demora significativamente mais.
- **Não pode rodar dentro de bloco de transação.** Isto é a raiz de todo atrito com Prisma (§6).
- Se falhar (deadlock, violação de unicidade), deixa um **índice INVALID** no catálogo — ignorado nas queries, mas ainda pago em cada `INSERT`/`UPDATE`. Recupere com `DROP INDEX CONCURRENTLY` + recriar, ou `REINDEX INDEX CONCURRENTLY`.

```sql
SELECT c.relname, i.indisvalid, i.indisready
FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
WHERE NOT i.indisvalid;
```

- Em índice **unique**, a unicidade já é aplicada contra outras transações a partir do segundo scan — violações podem aparecer antes do índice estar disponível, e continuam sendo aplicadas mesmo se o build falhar.
- **Índices em tabelas particionadas não suportam build concorrente.** Workaround da própria doc: `CREATE INDEX CONCURRENTLY` em cada partição individualmente, depois `CREATE INDEX ... ON ONLY parent` (metadata) e `ALTER INDEX parent_idx ATTACH PARTITION child_idx`.

---

## 2. O lock queue: por que um `ALTER TABLE` de 2ms derruba o produto

Este é o item que mais causa incidente e o menos entendido.

Locks no PostgreSQL formam **fila**. Um pedido de `ACCESS EXCLUSIVE` que não pode ser concedido **não espera de lado — bloqueia todo mundo atrás dele**, inclusive `SELECT`s que sozinhos não conflitariam com nada.

```
t0  Sessão A: SELECT longo (relatório mensal, 8 min) → segura ACCESS SHARE.
t1  Deploy:   ALTER TABLE transactions ADD COLUMN notes text;
              → pede ACCESS EXCLUSIVE, conflita com A, entra na fila.
t2  App:      SELECT ... FROM transactions WHERE user_id = $1
              → pediria só ACCESS SHARE (não conflita com A!),
                mas está ATRÁS do ACCESS EXCLUSIVE na fila. Bloqueia.
t3  Todo endpoint que toca transactions timeouta. Pool esgota.
    O ALTER, que levaria 2ms, causou 8 minutos de outage total.
```

A operação era **metadata-only**. O tempo de execução do DDL é irrelevante — o que importa é o **tempo de espera pelo lock**. Culpados comuns: relatórios longos, `pg_dump`, conexões `idle in transaction` (o pior — transação aberta sem query rodando, `statement_timeout` não pega), réplicas com `hot_standby_feedback`, ORMs que abrem transação cedo demais.

### A defesa: `lock_timeout` + retry

```sql
SET lock_timeout = '3s';      -- só limita a ESPERA pelo lock (desde PG 9.3)
SET statement_timeout = '5s'; -- limita a EXECUÇÃO do statement
ALTER TABLE transactions ADD COLUMN notes text;
```

`lock_timeout` é o correto para DDL: falha rápido em vez de bloquear a fila. `statement_timeout` cobre o DDL que *adquire* o lock e aí demora (rewrite inesperado).

Referências do mundo real: **GoCardless** (`ActiveRecord::SaferMigrations`) usa `lock_timeout = 750ms` / `statement_timeout = 1500ms`; **postgres.ai** usa `lock_timeout = 50ms` com até 30 tentativas em backoff exponencial + jitter (base 10ms, teto 60s) — ~17,5 min de janela total. Escolha conforme o RTO: timeout baixo + muitos retries protege o tráfego; alto + poucos retries falha menos o deploy, mas arrisca mais.

Retry no próprio SQL, quando a ferramenta de migration não tem:

```sql
DO $$
DECLARE
  max_attempts CONSTANT int := 20;
  delay_ms bigint;
  done boolean := false;
BEGIN
  PERFORM set_config('lock_timeout', '100ms', false);
  FOR i IN 1..max_attempts LOOP
    BEGIN
      ALTER TABLE transactions ADD COLUMN notes text;
      done := true;
      EXIT;
    EXCEPTION WHEN lock_not_available THEN
      delay_ms := round(random() * least(30000, 10 * 2 ^ i));
      PERFORM pg_sleep(delay_ms::numeric / 1000);
    END;
  END LOOP;
  IF NOT done THEN
    RAISE EXCEPTION 'não foi possível adquirir o lock após % tentativas', max_attempts;
  END IF;
END $$;
```

**Regra derivada:** uma migration = **um statement DDL**. Locks adquiridos dentro de uma transação são segurados até o commit — juntar cinco `ALTER TABLE` num arquivo significa segurar cinco locks pelo tempo do mais lento, e um retry re-executa tudo. Separe em arquivos; cada um roda em sua transação e é retentável isoladamente.

**Antes de qualquer DDL, veja quem está segurando o quê:**

```sql
SELECT pid, state, now() - xact_start AS xact_age,
       now() - state_change AS idle_age, left(query, 80)
FROM pg_stat_activity
WHERE state <> 'idle' OR state = 'idle in transaction'
ORDER BY xact_start
LIMIT 20;
```

Um `xact_age` de 40 minutos numa sessão `idle in transaction` é um veto ao deploy.

---

## 3. Expand/contract (parallel change)

Toda mudança destrutiva de schema tem o mesmo problema: **o banco e a aplicação não podem trocar no mesmo instante**. Durante qualquer deploy rolling, código velho e código novo rodam simultaneamente contra o mesmo banco. Renomear uma coluna é atômico no banco (`ACCESS EXCLUSIVE`, milissegundos) e catastrófico na aplicação — instâncias antigas passam a fazer `SELECT` de uma coluna que não existe mais.

O padrão: **nunca faça uma mudança destrutiva. Faça uma aditiva, migre, e limpe depois.**

### Caso: renomear `transactions.value` → `transactions.amount_cents`

| # | Fase | Onde | Ação |
|---|---|---|---|
| 1 | **Expand** | migration (deploy N) | `ALTER TABLE transactions ADD COLUMN amount_cents integer;` — nullable, sem default, instantâneo. |
| 2 | **Dual write** | código (deploy N) | Escreve nas duas, **lê da antiga**. |
| 3 | **Backfill** | job | Em lotes, fora da migration (§4). |
| 4 | **Verificar** | — | `SELECT count(*) FROM transactions WHERE amount_cents IS DISTINCT FROM value;` → 0. |
| 5 | **Constraint** | migrations | `CHECK ... NOT VALID` → `VALIDATE` → `SET NOT NULL` (§1). |
| 6 | **Migrar leitura** | código (N+1) | Lê da nova, ainda escreve nas duas. Reversível sem tocar no banco — é o que torna o padrão seguro. |
| 7 | **Parar escrita antiga** | código (N+2) | — |
| 8 | **Contract** | migration (N+3) | `ALTER TABLE transactions DROP COLUMN value;` — só depois de N+2 estável. |

```ts
// Fase 2 — escrita dupla
await prisma.transaction.create({ data: { ...rest, value: amountCents, amountCents } });
```

Alternativa ao dual write no código: trigger `BEFORE INSERT OR UPDATE` que copia. Custa em toda escrita e é fácil de esquecer de remover — prefira código explícito.

**Custo honesto:** 4 deploys, ~1-2 semanas de calendário, período com dado duplicado, e a disciplina de *realmente* fazer a fase 8 (senão a tabela acumula colunas mortas). Vale para tabelas quentes e grandes. Para uma tabela de 200 linhas com 30s de janela aceitável, `RENAME COLUMN` num deploy só é a resposta certa — saiba quando não aplicar o padrão.

### Variantes

- **Trocar tipo** (`integer` → `bigint` em `transactions.id`): idêntico. Nova coluna `id_new bigint`, backfill, índice unique concurrently, troca de PK, drop. Nunca `ALTER COLUMN TYPE` direto numa tabela grande.
- **Quebrar tabela** (extrair `bank_accounts` de `transactions`): expand = criar a nova tabela + dual write; migrate = backfill + leitura da nova; contract = drop das colunas antigas. As fases 6/7 podem exigir *shadow reads* (ler das duas e comparar em log) antes de confiar.
- **Coluna nova obrigatória**: nunca `ADD COLUMN ... NOT NULL DEFAULT <volátil>`. É: nullable → default → backfill → NOT NULL via CHECK.

### Regra de ouro do acoplamento deploy↔migration

Ordene sempre para que **cada estado intermediário seja válido para as duas versões do código**:

| Mudança | Migration antes ou depois do deploy? |
|---|---|
| `ADD COLUMN` nullable | Migration **antes** |
| `ADD INDEX` | Antes |
| `DROP COLUMN` | Migration **depois** (código novo já não usa) |
| `DROP TABLE` | Depois |
| `RENAME` | Nem antes nem depois — expand/contract |
| `SET NOT NULL` | Depois do código já garantir o valor |

---

## 4. Backfill de dados

`UPDATE transactions SET amount_cents = value;` numa tabela de 50M linhas é a armadilha clássica. Sete problemas simultâneos:

1. **Lock por linha:** cada linha segura `ROW EXCLUSIVE` até o commit. Atualizar tudo bloqueia updates concorrentes em **todas** as linhas — a aplicação para de escrever na tabela.
2. **Bloat via MVCC:** `UPDATE` não altera a linha — cria versão nova e marca a antiga como morta. 50M linhas **dobram a tabela** em disco. O espaço não volta sozinho: `VACUUM` devolve ao freespace (não ao SO); só `VACUUM FULL`/`pg_repack` reescrevem.
3. **Bloat de índice:** cada versão nova exige entrada nova em cada índice, salvo se o update for HOT (nenhuma coluna indexada muda **e** há espaço na página — ajuste `fillfactor`).
4. **WAL:** centenas de GB, saturando disco, atrasando archiving e estourando `max_wal_size`.
5. **Replicação:** todo esse WAL vai às réplicas. Lag em minutos/horas; se a app lê de réplica, serve dado velho. Réplica lenta + `wal_keep_size` insuficiente = réplica destruída.
6. **Autovacuum paralisado:** com a transação longa aberta, o autovacuum **não pode limpar nenhuma linha morta** — o snapshot ainda pode precisar delas. O bloat cresce durante toda a operação e não é recuperado até o commit.
7. **Rollback:** falhou em 90% → perde tudo e ainda pagou o bloat.

### O padrão de lote com commit

Cada lote é **sua própria transação**. Isso mata os sete problemas: locks curtos, autovacuum consegue trabalhar entre lotes, WAL é gerado gradualmente, replicação acompanha, e progresso é preservado.

```ts
// scripts/backfill-amount-cents.ts — job, não migration.
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DIRECT_URL }) });

const BATCH = 5_000;
const PAUSE_MS = 200; // deixa autovacuum e réplica respirarem

async function main() {
  let cursor: string | null = null;

  for (;;) {
    // Keyset por PK: sem OFFSET, custo constante por lote.
    const rows: { id: string }[] = await prisma.$queryRaw`
      WITH batch AS (
        SELECT id FROM transactions
        WHERE amount_cents IS NULL
          AND (${cursor}::text IS NULL OR id > ${cursor}::text)
        ORDER BY id
        LIMIT ${BATCH}
        FOR UPDATE SKIP LOCKED     -- não briga com escrita da aplicação
      )
      UPDATE transactions t
      SET amount_cents = t.value
      FROM batch b
      WHERE t.id = b.id
      RETURNING t.id
    `;

    if (rows.length === 0) break;
    cursor = rows[rows.length - 1].id;
    console.log(`backfilled ${rows.length}, cursor=${cursor}`);

    await checkReplicationLag();       // aborte se o lag passar do aceitável
    await new Promise((r) => setTimeout(r, PAUSE_MS));
  }
}
```

Regras:

- **Tamanho do lote:** 1.000–10.000 linhas. Meça: cada lote deve levar **menos de 1 segundo**. Se levar mais, diminua.
- **Idempotente:** o `WHERE amount_cents IS NULL` permite reiniciar de onde parou. Nunca use `LIMIT/OFFSET` — cursor por PK.
- **`FOR UPDATE SKIP LOCKED`:** evita que o backfill fique esperando linhas que a aplicação está escrevendo.
- **Throttle por lag:** monitore e pause.

```sql
SELECT application_name,
       pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes,
       replay_lag
FROM pg_stat_replication;
```

- **Nunca dentro de `prisma migrate`.** Uma migration do Prisma roda numa transação; um backfill de 50M linhas dentro dela reintroduz todos os problemas e trava o deploy por horas. Backfill é job separado, executável, monitorável, retomável.
- **Depois:** `VACUUM ANALYZE transactions;` (ou confie no autovacuum, mas verifique). Se o bloat ficou grande, `pg_repack` — não `VACUUM FULL` em produção (`ACCESS EXCLUSIVE` pela duração inteira).

---

## 5. Migrations reversíveis: quando `down` é ficção

O `down` só é honesto quando a operação **não perde informação**:

| `up` | `down` honesto? |
|---|---|
| `ADD COLUMN` nullable | Sim (`DROP COLUMN`) |
| `CREATE INDEX` | Sim |
| `ADD CONSTRAINT` | Sim |
| `CREATE TABLE` | Sim (se ninguém escreveu nela) |
| `DROP COLUMN` | **Não.** O `down` recria a coluna vazia. Os dados sumiram. |
| `DROP TABLE` | **Não.** |
| `ALTER COLUMN TYPE` com perda (`bigint`→`int`, `numeric(12,2)`→`numeric(10,2)`) | **Não.** |
| `UPDATE`/backfill | **Não.** Não existe "des-update" sem guardar o valor anterior. |
| `RENAME` | Sim tecnicamente — mas a aplicação já quebrou. |

Além disso: em produção, o `down` **nunca é executado**. O deploy falha às 3h e ninguém roda `migrate down` num banco com tráfego — o risco é maior que o do problema original. O Prisma sequer implementa `down`: **não existe `prisma migrate down`**.

**O que fazer no lugar:**

1. **Roll forward, não roll back.** A recuperação de uma migration ruim é uma migration nova. Exige que o deploy da aplicação seja reversível *sem* tocar no banco — o que só acontece se você seguiu §3.
2. **Toda migration aditiva ou compatível para trás.** Se é sempre seguro deixá-la aplicada, você nunca precisa de `down`.
3. **Antes de destruir, arquive.** No lugar de `DROP TABLE categories`: `ALTER TABLE categories RENAME TO categories_deprecated_20260717;` na migration N, e `DROP TABLE` 30 dias depois, confirmado zero acesso. Rollback real de custo zero por 30 dias.
4. **Separe migration de deploy.** Migration aditiva + código revertível = rollback é `git revert` + redeploy, em segundos, sem SQL.
5. **Backup verificado + PITR** é a rede real para perda de dados. Um script `down` não é.
6. Se escrever `down`, escreva **para o dev local** (onde `migrate reset` é aceitável), não como plano de produção — e não se iluda quanto a isso.

---

## 6. Prisma 7 especificamente

### Os três comandos

| Comando | O que faz | Onde |
|---|---|---|
| `prisma migrate dev` | Detecta drift via **shadow database**, gera SQL a partir do diff do `schema.prisma`, aplica no banco de dev. Em **Prisma 7 não dispara mais `prisma generate` nem o seed automaticamente**. | Só dev. |
| `prisma migrate deploy` | Aplica migrations pendentes de `prisma/migrations/`. **Não** usa shadow DB, **não** detecta drift, **não** reseta, **não** gera artefatos. Avisa se uma migration já aplicada foi modificada. | CI/CD. A doc recomenda explicitamente **não** rodar localmente contra produção. |
| `prisma db push` | Introspecta o banco e o força ao estado do schema. **Não gera arquivo de migration nem escreve em `_prisma_migrations`.** | Prototipagem local. Nunca em produção. |

`db push` recusa quando detecta perda de dados; `--accept-data-loss` força. É o comando que mais destrói ambiente compartilhado — se alguém rodou `db push` no banco de dev, o próximo `migrate dev` verá drift e pedirá reset.

**Advisory lock:** os comandos de migrate adquirem um advisory lock com timeout de **10s, não configurável**. Desativável com `PRISMA_SCHEMA_DISABLE_ADVISORY_LOCK` (desde 5.3.0) — necessário em alguns pools/proxies. Se seu CI roda duas instâncias de `migrate deploy` em paralelo, uma falha aqui.

### Shadow database

Banco temporário criado e destruído a cada `migrate dev`. Serve para (a) reexecutar todo o histórico e detectar **drift** — divergência entre o banco real e o que o histórico de migrations produziria; (b) gerar o SQL do diff; (c) detectar perda de dados.

Consequências práticas:
- O usuário de dev precisa de permissão para **criar e dropar bancos**. Em provedores gerenciados que não permitem isso, aponte `shadowDatabaseUrl` para um banco vazio dedicado.
- **Não é usado em produção.** `migrate deploy` e `migrate resolve` não o tocam.
- **SQL manual editado entra no histórico e é reexecutado no shadow DB.** Se você escreveu `CREATE INDEX CONCURRENTLY` numa migration, o shadow DB vai tentar rodá-la — e é aqui que dói (abaixo).

### Migration falhada em produção: `migrate resolve`

`migrate deploy` para no primeiro erro e marca a migration como falhada em `_prisma_migrations`. Nenhuma migration posterior roda até resolver. **Não existe rollback automático.**

Duas saídas:

```bash
# A) A migration não deve ser considerada aplicada; quero corrigir e reaplicar.
npx prisma migrate resolve --rolled-back 20260717120000_add_amount_cents
# → Se ela executou PARCIALMENTE, você precisa reverter à mão o que passou,
#   ou tornar o SQL idempotente (IF NOT EXISTS / IF EXISTS).
#   Depois: corrija o migration.sql, commite, e rode migrate deploy.

# B) Já apliquei os passos restantes manualmente no banco.
npx prisma migrate resolve --applied 20260717120000_add_amount_cents
# → Garanta que o estado do banco bate EXATAMENTE com o migration.sql.
```

**A escolha entre as duas é o momento de maior risco de um deploy de banco.** Erre e o histórico do Prisma passa a mentir sobre o schema — e todo `migrate dev` futuro pedirá reset.

`prisma migrate diff` é o instrumento para descobrir a verdade:

```bash
npx prisma migrate diff \
  --from-url "$DATABASE_URL" \
  --to-schema-datamodel prisma/schema.prisma \
  --script
```

Se a saída for vazia, o banco bate com o schema. Se não, isso é o drift — e o SQL para fechá-lo.

### O que o Prisma NÃO gera e exige SQL manual

O gerador do Prisma produz SQL a partir do diff do PSL. Tudo que não existe no PSL, ele não gera — e pior, **num `migrate dev` seguinte ele pode tentar remover o que ele não conhece**, porque o shadow DB (que só reexecuta migrations) não o tem.

| Recurso | Situação em Prisma 7.x |
|---|---|
| `CREATE INDEX CONCURRENTLY` | **Nunca gerado.** SQL manual + migration fora de transação (ver abaixo). |
| `DROP INDEX CONCURRENTLY` | Idem. |
| `CHECK` constraints | **Sem sintaxe em PSL.** SQL manual. O Prisma não os representa e não os dropa (não os enxerga), mas também não os valida. |
| Row Level Security (RLS) | SQL manual. |
| Views | Preview feature `views` (desde 4.9.0), **ainda em Preview** — a definição SQL da view precisa ser escrita à mão de qualquer forma. |
| Triggers e stored procedures | Sem equivalente em PSL. SQL manual, sempre. |
| Índices parciais | **Suportado desde 7.4.0** via `where` em `@@index`/`@@unique`/`@unique`, atrás da preview feature `partialIndexes`. |
| Índices por expressão | Não suportado em PSL. SQL manual. |
| Tipos custom / extensions (`citext`, `postgis`) | `Unsupported("...")` no PSL — o campo **não aparece no Prisma Client**; acesso só via `$queryRaw`. |
| `NOT VALID` / `VALIDATE CONSTRAINT` | Nunca gerado. SQL manual. |
| Particionamento declarativo | Não representável. SQL manual + `Unsupported`/introspecção manual. |
| Defaults por função de banco | `@default(dbgenerated("gen_random_uuid()"))`. |

### O workflow correto: `--create-only`

```bash
# 1. Edite o schema.prisma
# 2. Gere sem aplicar:
npx prisma migrate dev --create-only
# 3. Edite prisma/migrations/2026.../migration.sql
# 4. Aplique:
npx prisma migrate dev
```

Este é o único mecanismo suportado para colocar SQL correto na migration. Use-o **por padrão** em qualquer projeto com produção, não como exceção.

Exemplo: o Prisma gera para um índice novo em `transactions(user_id, date)`:

```sql
-- gerado
CREATE INDEX "transactions_user_id_date_idx" ON "transactions"("user_id", "date");
```

O que você troca para:

```sql
-- editado à mão
CREATE INDEX CONCURRENTLY IF NOT EXISTS "transactions_user_id_date_idx"
  ON "transactions" ("user_id", "date" DESC);
```

**Problema:** `CREATE INDEX CONCURRENTLY` não roda dentro de transação, e o Prisma envolve cada `migration.sql` numa. Opções, em ordem de preferência:

1. **Migration isolada só com o CIC.** Um arquivo por índice, nada mais. Alguns setups do Prisma toleram — teste no seu.
2. **Tirar do Prisma.** Deixe o índice fora do `schema.prisma` e crie-o por um script de deploy separado (`psql -f`), fora do `migrate deploy`. Custo: o `migrate dev` seguinte vai querer criá-lo/dropá-lo, porque o shadow DB não o tem. Contorno: adicione-o ao `schema.prisma` como `@@index([userId, date])` **e** faça a migration que "cria" o índice ser um no-op idempotente:
   ```sql
   -- migration.sql
   CREATE INDEX IF NOT EXISTS "transactions_user_id_date_idx"
     ON "transactions" ("user_id", "date");
   -- Nota: em produção este índice já foi criado CONCURRENTLY pelo script de deploy.
   -- Este statement é no-op lá e cria normalmente em dev/shadow.
   ```
   Este é o padrão mais robusto na prática: o PSL descreve a *forma*, o script de deploy controla o *como*.
3. Aceitar `CREATE INDEX` bloqueante numa janela de manutenção. Só para tabelas pequenas.

O mesmo raciocínio vale para `CHECK`/RLS: coloque no `migration.sql` com `IF NOT EXISTS`/`DO $$ ... $$` idempotente, e saiba que o Prisma nunca vai reconciliá-los.

### Exemplo integrado: `bank_accounts` no domínio financeiro

```prisma
// schema.prisma (Prisma 7)
generator client {
  provider        = "prisma-client-js"
  previewFeatures = ["partialIndexes"]
}

datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")   // pooled (PgBouncer/Prisma Accelerate)
  directUrl = env("DIRECT_URL")     // direto — usado pelo CLI/migrate
}

model Transaction {
  id            String            @id @default(uuid())
  userId        String            @map("user_id")
  bankAccountId String?           @map("bank_account_id")
  amountCents   Int               @map("amount_cents")
  status        TransactionStatus @default(POSTED)
  date          DateTime          @db.Date

  user        User         @relation(fields: [userId], references: [id])
  bankAccount BankAccount? @relation(fields: [bankAccountId], references: [id])

  @@index([userId, date(sort: Desc)])  // acesso principal: extrato recente primeiro
  @@index([bankAccountId])             // FK sem índice = DELETE em seq scan
  // Índice parcial (7.4+, preview): só pendências são consultadas por status.
  @@index([userId, date], where: { status: PENDING }, map: "transactions_pending_idx")
  @@map("transactions")
}
```

Migrations correspondentes, escritas à mão via `--create-only`:

```sql
-- 20260717_add_amount_cents/migration.sql
ALTER TABLE "transactions" ADD COLUMN "amount_cents" integer;
-- Constraint de domínio que o PSL não expressa: valor nunca zero.
ALTER TABLE "transactions" ADD CONSTRAINT "transactions_amount_cents_nonzero"
  CHECK ("amount_cents" <> 0) NOT VALID;

-- 20260722_validate_amount_cents/migration.sql (após o backfill)
-- SHARE UPDATE EXCLUSIVE — não bloqueia tráfego.
ALTER TABLE "transactions" VALIDATE CONSTRAINT "transactions_amount_cents_nonzero";
```

### Connection pooling com Prisma 7

Mudança importante da v7: **não existem mais parâmetros de pool na connection URL**. Pool size, acquire timeout e afins são configurados **por driver adapter**.

```ts
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

const adapter = new PrismaPg({
  connectionString: process.env.DATABASE_URL,
  max: 10,                       // pool size — configurado no adapter, não na URL
  idleTimeoutMillis: 30_000,
});

export const prisma = new PrismaClient({ adapter });
```

Regra de dimensionamento: **pool size × número de instâncias ≤ `max_connections` do PostgreSQL** (menos a reserva de superuser e de ferramentas). Com Fastify em container escalável, isso estoura silenciosamente: 20 pods × pool 10 = 200 conexões.

Armadilhas:

- **Serverless:** cada invocação instancia seu `PrismaClient`, cada um com seu pool. Funções "pausadas" seguram conexões zumbis. Use pool pequeno (1–3) + pooler externo.
- **`Promise.all` com muitas queries:** esgota o pool e dispara timeout de aquisição. É a causa nº 1 de "connection pool timeout" com Prisma.
- **PgBouncer em transaction mode:** incompatível com prepared statements e com transações interativas do Prisma. Sinalize com `?pgbouncer=true` na URL.
- **`directUrl`:** obrigatório quando o app usa pooler. `migrate deploy`/`migrate dev` precisam de conexão direta (advisory locks, DDL, shadow DB). Sem isso, migrations falham de forma confusa atrás do PgBouncer.

### N+1 no Prisma

**`include` vs `select`:** `include` traz *todos* os campos escalares do modelo pai mais as relações; `select` traz só o que você pede. Você não pode usar os dois no mesmo nível (pode aninhar `select` dentro de `include`). Em tabela financeira larga, `include` puxa colunas que ninguém usa — banda, memória e, quando há TOAST, I/O extra.

```ts
// Ruim: traz tudo de transactions + tudo de category.
const txs = await prisma.transaction.findMany({ include: { category: true } });

// Bom: só o necessário.
const txs = await prisma.transaction.findMany({
  select: { id: true, amountCents: true, date: true,
            category: { select: { id: true, name: true } } },
});
```

**`findMany` em loop — o N+1 clássico:**

```ts
// Ruim: 1 + N queries.
const accounts = await prisma.bankAccount.findMany({ where: { userId } });
for (const acc of accounts) {
  acc.txs = await prisma.transaction.findMany({ where: { bankAccountId: acc.id } });
}

// Bom: relação aninhada — 1 query (ou 2, conforme a estratégia).
const accounts = await prisma.bankAccount.findMany({
  where: { userId },
  select: { id: true, name: true, transactions: { select: { id: true, amountCents: true } } },
});

// Ou, se o loop for inevitável: uma query com IN, agrupe em memória.
const txs = await prisma.transaction.findMany({
  where: { bankAccountId: { in: accounts.map((a) => a.id) } },
});
```

**`relationLoadStrategy`** (`previewFeatures = ["relationJoins"]`):

- `join`: um único `LATERAL JOIN` no PostgreSQL com agregação JSON no banco. **Default quando a flag está ligada.**
- `query`: uma query por tabela, junção no servidor de aplicação. Útil para poupar CPU do banco ou quando o JOIN explode em cardinalidade (fan-out).

```ts
const accounts = await prisma.bankAccount.findMany({
  relationLoadStrategy: 'join',   // ou 'query'
  select: { id: true, transactions: { select: { id: true } } },
});
```

**Estado em 7.x:** `relationJoins` **continua em Preview** (desde 5.7.0), disponível em PostgreSQL, CockroachDB e MySQL. É a preview feature mais usada do Prisma, mas há issues abertas antes do GA. Ligue-a com medição, não por fé: `join` nem sempre ganha — em relação 1:N com muitas linhas filhas o JOIN duplica os campos do pai e pode ser mais lento que duas queries. Meça com `EXPLAIN (ANALYZE, BUFFERS)`.

Preview features ativas em 7.x (referência): `views` (4.9.0), `relationJoins` (5.7.0), `nativeDistinct` (5.7.0), `typedSql` (5.19.0), `strictUndefinedChecks` (5.20.0), `fullTextSearchPostgres` (6.0.0), `shardKeys` (6.10.0), `partialIndexes` (7.4.0). Já GA: `driverAdapters` (GA em 6.16.0), `multiSchema` (GA em 6.13.0), `prismaSchemaFolder` (GA em 6.7.0).

---

## 7. Particionamento

### O número honesto: não particione cedo demais

A doc do PostgreSQL é direta: os benefícios "normalmente se acumulam quando a tabela seria muito grande — uma regra prática é que o tamanho da tabela exceda a memória física do servidor".

Traduzindo para decisão:

- **< 50 GB:** não particione. Índice certo e `VACUUM` funcionando resolvem.
- **50–100 GB:** talvez, se o padrão de acesso for temporal e você precisar descartar dados antigos.
- **> 100 GB** com acesso concentrado em janela recente e retenção definida: sim.
- Alvo de tamanho por partição: **10–100 GB**, idealmente com a partição quente + seus índices cabendo em `shared_buffers`.

**O motivo mais forte de particionar não é performance de SELECT — é lifecycle.** `DROP TABLE transactions_2024_01` é instantâneo; `DELETE FROM transactions WHERE date < '2024-02-01'` gera bloat massivo, WAL e horas de vacuum.

**O custo, que ninguém menciona no blog post:**

- **Planning time cresce com o número de partições.** Caso medido pelo pganalyze: 0,7ms de planning para 0,235ms de execução — mais tempo planejando que executando. Em OLTP com queries de 1ms, é regressão pura.
- **Memória por sessão** cresce com partições por consulta (metadata carregada no planning).
- **Unique/PK devem incluir todas as colunas da chave de partição** — a restrição que mais mata designs. `transactions(id)` como PK global é **impossível** particionando por `date`: a PK precisa ser `(id, date)`.
- **Não existem índices globais.** Cada partição tem os seus.
- **`CREATE INDEX CONCURRENTLY` não funciona em tabela particionada** (§1).
- Caso ChartMogul (via pganalyze): saíram de list partitioning (uma partição por cliente, milhares de tabelas) para hash com **30 partições** → 5x em SELECT simples, 3x em JOIN. **Menos partições foi a otimização.**

### As três estratégias

```sql
-- RANGE: o caso default para série temporal financeira.
CREATE TABLE transactions (
  id              uuid        NOT NULL DEFAULT gen_random_uuid(),
  user_id         uuid        NOT NULL,
  bank_account_id uuid,
  amount_cents    integer     NOT NULL,
  date            date        NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, date)          -- a chave de partição É obrigatória na PK
) PARTITION BY RANGE (date);

CREATE TABLE transactions_2026_07 PARTITION OF transactions
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');  -- limite superior EXCLUSIVO

-- Partição default: pega o que não casa. Cuidado: ATTACH de nova partição
-- exige scan da default para provar que nada colide.
CREATE TABLE transactions_default PARTITION OF transactions DEFAULT;
```

- **LIST:** por valores discretos (`type`, `status`, tenant fixo). Só quando o conjunto é pequeno e estável.
- **HASH:** distribuição uniforme por `modulus`/`remainder`, quando não há chave natural de range. Escolha o `modulus` de uma vez — mudar depois é redistribuir tudo.

### Partition pruning

```sql
SET enable_partition_pruning = on;  -- default
```

Ocorre em dois momentos:
- **Plan time:** quando o valor é constante ou parâmetro conhecido no planning.
- **Execution time:** quando só é conhecido na execução (subquery, nested loop parametrizado).

Ponto crítico: **pruning é dirigido pelos bounds da partição, não por índices.** E ele **só funciona se a query filtrar pela chave de partição**. Uma query como `WHERE user_id = $1` numa tabela particionada por `date` toca **todas** as partições — pior que a tabela não-particionada. Se seu padrão de acesso dominante não inclui a chave de partição, particionar por ela é uma regressão pura.

Verifique sempre:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT sum(amount_cents) FROM transactions
WHERE date >= '2026-07-01' AND date < '2026-08-01' AND user_id = '...';
-- Procure por "Partitions removed: N" / a lista de partições no plano.
```

### Migrar uma tabela existente para particionada

**O PostgreSQL não converte tabela comum em particionada.** Não existe `ALTER TABLE ... PARTITION BY`. O caminho, com o mínimo de downtime:

```sql
-- 1. Nova tabela particionada, com nome temporário.
CREATE TABLE transactions_new (LIKE transactions INCLUDING ALL)
  PARTITION BY RANGE (date);

-- 2. Cria as partições necessárias (histórico + futuro).
CREATE TABLE transactions_new_2026_07 PARTITION OF transactions_new
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
-- ... etc

-- 3. Copia o histórico em lotes (§4), com a aplicação ainda escrevendo na antiga.
-- 4. Dual write pela aplicação, ou trigger na antiga replicando para a nova.
-- 5. Swap na janela mínima:
BEGIN;
SET lock_timeout = '3s';
ALTER TABLE transactions      RENAME TO transactions_old;
ALTER TABLE transactions_new  RENAME TO transactions;
COMMIT;
-- 6. Depois de estabilizar: DROP TABLE transactions_old;
```

Alternativa mais elegante quando a tabela antiga inteira cabe numa faixa (ex.: "tudo até hoje"): **anexe-a como partição**.

```sql
-- Crie o CHECK ANTES: com um CHECK válido casando os bounds,
-- o ATTACH pula o scan de validação.
ALTER TABLE transactions_old
  ADD CONSTRAINT transactions_old_range
  CHECK (date >= '2020-01-01' AND date < '2026-07-01') NOT VALID;
ALTER TABLE transactions_old VALIDATE CONSTRAINT transactions_old_range;

-- ATTACH pega só SHARE UPDATE EXCLUSIVE no pai (ACCESS EXCLUSIVE na partição).
ALTER TABLE transactions ATTACH PARTITION transactions_old
  FOR VALUES FROM ('2020-01-01') TO ('2026-07-01');

ALTER TABLE transactions_old DROP CONSTRAINT transactions_old_range;  -- redundante agora
```

**Manutenção:** criar partições futuras é obrigação recorrente — se faltar partição, o `INSERT` falha (ou cai na default, e aí o `ATTACH` seguinte precisa scanear a default). Use `pg_partman` ou um cron. Remover: `DETACH PARTITION ... CONCURRENTLY` (lock reduzido, duas transações) ou `DROP TABLE` direto.

**Prisma e particionamento:** o PSL não representa particionamento. O caminho é SQL manual via `--create-only`, e a PK composta `(id, date)` precisa virar `@@id([id, date])` no schema para o Prisma não brigar. Espere atrito com `migrate dev`/shadow DB.

---

## 8. Grandes volumes

### Paginação: keyset, não `OFFSET`

`OFFSET 99980` não pula linhas — o PostgreSQL **lê e descarta 99.980 linhas** antes de devolver as 20 seguintes. O custo cresce linearmente com o offset. Além disso, `OFFSET` é **incorreto** sob escrita concorrente: se uma linha for inserida ou removida entre duas páginas, o usuário vê itens repetidos ou pulados.

```sql
-- Ruim: degrada com a profundidade e mente sob concorrência.
SELECT * FROM transactions WHERE user_id = $1
ORDER BY date DESC, id DESC OFFSET 99980 LIMIT 20;

-- Bom: index seek direto, custo constante em qualquer profundidade.
SELECT * FROM transactions
WHERE user_id = $1
  AND (date, id) < ($2, $3)      -- comparação de tupla = ordem lexicográfica
ORDER BY date DESC, id DESC
LIMIT 20;
```

Precisa de índice em `(user_id, date DESC, id DESC)`. A **comparação de tupla** `(date, id) < ($2, $3)` é o detalhe que quase todo mundo erra — `date <= $2 AND id < $3` está errado e não usa o índice da mesma forma. O `id` é o desempate: sem ele, transações na mesma data quebram a paginação.

No Prisma, keyset é `cursor` + `skip: 1`:

```ts
const page = await prisma.transaction.findMany({
  where: { userId },
  orderBy: [{ date: 'desc' }, { id: 'desc' }],
  take: 20,
  ...(cursorId ? { cursor: { id: cursorId }, skip: 1 } : {}),
});
```

O `cursor` do Prisma opera sobre campos únicos; para ordenação composta, `$queryRaw` com comparação de tupla dá controle exato.

`OFFSET` só é aceitável quando o usuário precisa saltar para página numerada **e** o total de páginas é pequeno. Admin com 3 páginas: use. Feed infinito, API pública, sync: nunca.

### `COPY` vs `INSERT`

Recomendações da doc (`populate.html`), em ordem de impacto:

1. **`COPY` é significativamente mais rápido** que `INSERT`. Comando único — não precisa desabilitar autocommit à parte. Ainda mais rápido **na mesma transação de um `CREATE TABLE` ou `TRUNCATE`**.
2. Se for `INSERT`: **desabilite autocommit** e agrupe em uma transação; use multi-values.
3. **Remova índices antes, recrie depois** — criar sobre dados prontos é mais rápido que atualizar linha a linha.
4. **Remova foreign keys antes, recrie depois** — checagem em lote é mais eficiente e evita estourar a fila de eventos de trigger.
5. **`SET maintenance_work_mem = '1GB'`** — acelera `CREATE INDEX` e `ADD FOREIGN KEY`.
6. **Aumente `max_wal_size`** — reduz checkpoints durante a carga.
7. **Desabilite archiving/replicação** (`wal_level = minimal`, `archive_mode = off`, `max_wal_senders = 0`) — exige restart e **base backup novo depois**. Só em carga inicial, nunca em banco vivo.
8. **`ANALYZE` no final.** Não opcional: sem estatísticas o planner erra e você culpa o índice.

Para `pg_restore`: `-j N` (paralelo), `--single-transaction` se quiser atomicidade, `ANALYZE` ao final.

Em Node/TypeScript, `COPY ... FROM STDIN` via `pg-copy-streams` é a rota; `prisma.$executeRaw` não faz COPY. Para importar CSV de extrato bancário, é a diferença entre 40 segundos e 40 minutos.

### `UNLOGGED`

Tabela `UNLOGGED` não gera WAL: escrita muito mais rápida. O preço:

- **Truncada automaticamente após crash do servidor.** Não "possivelmente perdida" — zerada.
- **Não é replicada.** Não existe na standby.
- Converter (`SET LOGGED`/`SET UNLOGGED`) **reescreve a tabela** sob `ACCESS EXCLUSIVE`.

Uso legítimo: tabela de staging para importar extratos. Carrega em `UNLOGGED`, valida, transforma, `INSERT ... SELECT` para a tabela real, `DROP`. Se der crash no meio, refaz o import. **Nunca** para dado que o usuário considera salvo.

### Séries temporais

`transactions` num app de finanças pessoais é série temporal com particularidades:

- **Append-only na prática** — update raro, delete raríssimo → bloat baixo, `fillfactor` default ok.
- **Acesso concentrado nos últimos ~90 dias** → range em `date`, partição quente cabendo em `shared_buffers`.
- **Agregação por mês/categoria é o padrão de query** → tabela agregada (`monthly_summaries`) mantida incrementalmente, ou materialized view com `REFRESH ... CONCURRENTLY` (exige índice unique; sem `CONCURRENTLY` pega `ACCESS EXCLUSIVE`).
- **Retenção:** particione se houver política de descarte. Sem ela, o principal ganho do particionamento desaparece.
- **BRIN** em `created_at` numa tabela append-only grande custa KB contra GB de um B-tree e serve bem a range scan amplo — exige correlação física com a ordem de inserção, que append-only dá de graça.

---

## 9. Ambientes e dados de teste

### Seeds

Seed serve para **dado de referência determinístico** (categorias padrão, enums em tabela, plano de contas), não para simular volume. Em **Prisma 7, `migrate dev` não roda mais o seed automaticamente** — invoque explicitamente.

```jsonc
// package.json
{ "prisma": { "seed": "tsx prisma/seed.ts" } }
```

```ts
// prisma/seed.ts — idempotente por construção.
await prisma.category.upsert({
  where: { key: 'groceries' },
  update: {},
  create: { key: 'groceries', name: 'Mercado', type: 'EXPENSE' },
});
```

Seed que não é idempotente vira ruído em CI e falha na segunda execução.

### Dados sintéticos

Para testar performance você precisa de **volume e distribuição realistas** — não de 100 linhas uniformes. A distribuição importa mais que o volume: se 5% dos usuários têm 90% das transações, um seed uniforme esconde exatamente o problema que você quer encontrar.

```sql
-- 5M transações com data distribuída em 3 anos e usuários com cauda longa.
INSERT INTO transactions (user_id, amount_cents, type, date)
SELECT
  (SELECT id FROM users ORDER BY random() ^ 3 LIMIT 1),   -- viés: poucos users, muitas txs
  (random() * 500000)::int - 250000,
  (ARRAY['EXPENSE','INCOME','INVESTMENT'])[1 + floor(random()*3)]::"TransactionType",
  current_date - (random() * 1095)::int
FROM generate_series(1, 5000000);
ANALYZE transactions;
```

Sempre `ANALYZE` depois. Sem estatísticas, o `EXPLAIN` mede ficção.

### Anonimização de dump de produção

Nunca copie produção para dev sem tratar. Em finanças pessoais, o dump é o produto inteiro do ponto de vista de um vazamento.

**`postgresql_anonymizer`** (extensão `anon`, Dalibo) oferece três estratégias:

- **Anonymous dump** — o caso de uso alvo aqui. Exporta um `.sql` já com valores falsos, via um usuário mascarado; a extensão intercepta o export. É o que você compartilha com dev/consultor sem nunca dar acesso à produção.
- **Static masking** — reescreve os dados no disco (todas as linhas de todas as tabelas com coluna mascarada). Lento por definição; suporta paralelismo com background workers. Use num clone restaurado, nunca na produção.
- **Dynamic masking** — usuários internos (suporte, DBA) veem dados mascarados ao consultar o banco vivo.

Regras práticas: anonimize **num clone**, nunca na produção. Mascare o que identifica **e o que é sensível por si** — e-mail, nome, `profile_image`, e, em finanças, **valores e descrições de transação** (`amount_cents` real + data + categoria reidentifica uma pessoa com facilidade absurda). **Preserve a distribuição** (trocar todo `amount_cents` por `100` destrói o dump para teste de performance) e **a integridade referencial** (mascare `user_id` de forma determinística com salt, senão as FKs quebram). Se puder, prefira **dados sintéticos**: anonimização é mitigação de risco, não eliminação.

### Testes de integração com banco real

SQLite em teste e PostgreSQL em produção é uma mentira que você paga em produção: tipos, constraints, transações e o planner são todos diferentes. **Teste contra PostgreSQL.**

Três estratégias, do mais rápido ao mais isolado:

**1. Transação com rollback** (µs por teste). `BEGIN` no `beforeEach`, `ROLLBACK` no `afterEach`. Limitação séria: o código sob teste **não pode gerenciar transação própria** (nested vira savepoint, e `$transaction` do Prisma não coopera bem), e não serve se o teste depende de commit visível a outra conexão.

**2. Template database** (dezenas de ms por teste, isolamento total)

```sql
CREATE DATABASE test_template;                          -- setup global: migrate deploy + seed
CREATE DATABASE test_worker_1 TEMPLATE test_template;   -- por worker: cópia física
```

`CREATE DATABASE ... TEMPLATE` copia arquivos — muito mais rápido que reaplicar migrations. Requisito: nenhuma conexão aberta no template durante a cópia. Melhor relação custo/isolamento para suíte com Vitest e workers paralelos.

**3. Testcontainers** (boot em segundos, mas realista e reprodutível)

```ts
import { PostgreSqlContainer } from '@testcontainers/postgresql';

const container = await new PostgreSqlContainer('postgres:18-alpine')
  .withDatabase('balancie_test')   // NUNCA 'postgres': snapshot exige dropar o DB conectado
  .start();

process.env.DATABASE_URL = container.getConnectionUri();
execSync('npx prisma migrate deploy', { env: process.env });

await container.snapshot();        // congela o estado limpo (módulo Postgres, testcontainers >= 10.23.0)
// por teste:
await container.restoreSnapshot(); // volta ao estado limpo
```

O `snapshot()`/`restoreSnapshot()` do módulo Postgres requer **testcontainers >= 10.23.0** e **não funciona se o database do container for `postgres`** — a lógica precisa dropar o database conectado usando o database de sistema.

Combinação recomendada: **Testcontainers para o container + template database para isolamento por teste**. Boot único, testes isolados e rápidos.

Rode `prisma migrate deploy` (não `migrate dev`) no setup de teste: sem shadow DB, sem geração, sem interatividade — determinístico em CI.

**Teste as migrations em si.** O CI deve rodar `migrate deploy` contra um dump anonimizado com volume realista e **medir o tempo**. Uma migration que leva 40ms em dev com 100 linhas e 40 minutos em produção com 50M é a falha mais comum, e a única forma de vê-la antes é medir com volume.

---

## 10. Checklist de produção

Antes de aplicar **qualquer** migration:

**Sobre a operação**
- [ ] Localizei cada statement DDL na tabela do §1. Sei qual lock cada um pega.
- [ ] Nenhum statement causa **rewrite** de tabela grande. Se causa, confirmei em cópia com `pg_relation_filenode()` antes e depois.
- [ ] Nenhum scan completo sob `ACCESS EXCLUSIVE` (`SET NOT NULL` direto, `CHECK` sem `NOT VALID`, `ADD FK` sem `NOT VALID`).
- [ ] Índices são `CONCURRENTLY`, em migration isolada ou fora do `migrate deploy`.
- [ ] **Um statement DDL por migration.** Nada de cinco `ALTER TABLE` num arquivo.

**Sobre o lock**
- [ ] `SET lock_timeout` no início de cada migration (750ms–3s conforme o RTO).
- [ ] `SET statement_timeout` como rede contra o rewrite não previsto.
- [ ] Há retry com backoff, ou eu aceito re-executar o deploy à mão.
- [ ] Verifiquei `pg_stat_activity`: nenhuma transação longa nem `idle in transaction` na tabela alvo **agora**.
- [ ] Sei quais jobs longos (relatórios, `pg_dump`, ETL) rodam nesta janela.

**Sobre a compatibilidade**
- [ ] Nenhuma operação destrutiva (`DROP COLUMN`, `RENAME`, `ALTER TYPE`) no mesmo deploy do código que a exige. Expand/contract aplicado.
- [ ] O código **antigo** continua funcionando com o schema **novo** (rolling deploy).
- [ ] O código **novo** funciona com o schema **antigo**, se a migration falhar.
- [ ] Se houver `DROP`, o código que usava a coluna/tabela já está em produção há ≥ 1 deploy estável.

**Sobre os dados**
- [ ] Backfill é **job separado**, em lotes, idempotente, retomável — não está dentro da migration.
- [ ] Estimei o WAL gerado e sei que o disco aguenta.
- [ ] Sei o lag de replicação aceitável e vou monitorar durante a operação.
- [ ] Backup recente **verificado** (restaurado, não só existente) + PITR disponível.

**Sobre o Prisma**
- [ ] Migration gerada com `--create-only` e o SQL foi **lido**.
- [ ] `prisma migrate diff --from-url $DATABASE_URL --to-schema-datamodel` contra produção não mostra drift inesperado **antes** do deploy.
- [ ] Um único `migrate deploy` roda por vez (advisory lock de 10s, não configurável).
- [ ] `directUrl` configurado, se o app usa pooler.
- [ ] SQL manual (CHECK, RLS, índice concorrente) é idempotente e sobrevive à reexecução no shadow DB.

**Medição**
- [ ] Rodei a migration contra dump anonimizado com **volume de produção** e cronometrei.
- [ ] Sei o tempo esperado e o que fazer se passar de 3x isso.
- [ ] Tenho o plano de roll forward escrito (não o `down`).
- [ ] Alguém além de mim sabe que este deploy vai acontecer e como abortá-lo.

**Depois**
- [ ] `ANALYZE` na tabela alterada.
- [ ] Nenhum índice `INVALID` (`SELECT ... FROM pg_index WHERE NOT indisvalid`).
- [ ] Todas as constraints validadas (`SELECT conname FROM pg_constraint WHERE NOT convalidated`).
- [ ] Bloat verificado se houve backfill; `pg_repack` agendado se necessário.

---

## Fontes

- PostgreSQL 18 docs: [ALTER TABLE](https://www.postgresql.org/docs/current/sql-altertable.html), [Explicit Locking](https://www.postgresql.org/docs/current/explicit-locking.html), [CREATE INDEX](https://www.postgresql.org/docs/current/sql-createindex.html), [Table Partitioning](https://www.postgresql.org/docs/current/ddl-partitioning.html), [Populating a Database](https://www.postgresql.org/docs/current/populate.html), [Versioning Policy](https://www.postgresql.org/support/versioning/)
- [strong_migrations (ankane)](https://github.com/ankane/strong_migrations)
- [postgres.ai — lock_timeout and retries](https://postgres.ai/blog/20210923-zero-downtime-postgres-schema-migrations-lock-timeout-and-retries)
- [GoCardless — Zero-downtime Postgres migrations](https://gocardless.com/blog/zero-downtime-postgres-migrations-a-little-help/)
- [Crunchy Data — When Does ALTER TABLE Require a Rewrite?](https://www.crunchydata.com/blog/when-does-alter-table-require-a-rewrite)
- [pganalyze — Partitioning and the risk of high partition counts](https://pganalyze.com/blog/5mins-postgres-partitioning)
- [brandur — A Missing Link in Postgres 11: Fast Column Creation with Defaults](https://brandur.org/postgres-default)
- Prisma docs: [Development and production](https://www.prisma.io/docs/orm/prisma-migrate/workflows/development-and-production), [Shadow database](https://www.prisma.io/docs/orm/prisma-migrate/understanding-prisma-migrate/shadow-database), [Patching and hotfixing](https://www.prisma.io/docs/orm/prisma-migrate/workflows/patching-and-hotfixing), [Customizing migrations](https://www.prisma.io/docs/orm/prisma-migrate/workflows/customizing-migrations), [Unsupported database features](https://www.prisma.io/docs/orm/prisma-migrate/workflows/unsupported-database-features), [Prototyping (db push)](https://www.prisma.io/docs/orm/prisma-migrate/workflows/prototyping-your-schema), [Relation queries](https://www.prisma.io/docs/orm/prisma-client/queries/relation-queries), [Databases connections](https://www.prisma.io/docs/orm/prisma-client/setup-and-configuration/databases-connections), [Preview features](https://www.prisma.io/docs/orm/reference/preview-features/client-preview-features), [Prisma ORM v7.4](https://www.prisma.io/blog/prisma-orm-v7-4-query-caching-partial-indexes-and-major-performance-improvements)
- [PostgreSQL Anonymizer](https://postgresql-anonymizer.readthedocs.io/) — [Anonymous Dumps](https://postgresql-anonymizer.readthedocs.io/en/latest/anonymous_dumps/), [Static Masking](https://postgresql-anonymizer.readthedocs.io/en/latest/static_masking/)
- [Testcontainers for Node.js — PostgreSQL module](https://node.testcontainers.org/modules/postgresql/)
