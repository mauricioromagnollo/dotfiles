# Prisma 7 + PostgreSQL em produção

Referência para trabalhar com Prisma 7.3 nesta API financeira: o que a v7 mudou, como modelar dinheiro e índices, e as armadilhas que custam dados ou latência. Abra antes de mexer em `prisma/schema.prisma`, criar migration, escrever query nova em `src/repositories/balancie-db-repository/`, ou debugar erro do Prisma.

## Estado real deste projeto (leia primeiro)

Runtime em **7.3 (prisma, @prisma/client, @prisma/adapter-pg) + pg 8.17**, mas o schema ainda no formato antigo: `generator client { provider = "prisma-client-js" }` (legado, deprecado na v7) e `datasource db { provider = "postgresql" }` sem `url`. Funciona porque a v7 mantém `prisma-client-js` por compatibilidade. Duas consequências:

1. O import continua `from '@prisma/client'` (gerado em `node_modules`) e o projeto continua **CommonJS** (`module: node16`, sem `"type": "module"`). Não troque para `./generated/prisma/client` sem migrar o generator junto.
2. Migrar para `provider = "prisma-client"` é cascata: `output` obrigatório, ESM (`"type": "module"`, `module: ESNext`, `moduleResolution: bundler`), reescrita de imports, ajuste de `module-alias`/build. É um PR próprio, não efeito colateral.

`prisma.config.ts` é a fonte da verdade de `schema`, `migrations.path` e `datasource.url` (`env('POSTGRES_DATABASE_URL')`). Ele **não** define `migrations.seed` — por isso `prisma db seed` não funciona aqui; o seed roda via `npm run seed` (tsx). Para habilitar: `migrations: { seed: 'tsx prisma/seed.ts' }`.

## O que a v7 quebrou vindo da v6

- **Driver adapter obrigatório.** Não há mais engine binário fazendo pool; `new PrismaClient({ adapter })` é o único caminho — o projeto já acerta em `balancie-db-repository.ts`.
- **Defaults de pool mudaram e isso morde.** Valem os defaults do `pg`: `connectionTimeoutMillis` passa de 5s para **0 = espera infinita**, idle de 300s para **10s**. Sob saturação, a request **pendura para sempre** em vez de falhar rápido. Configure explícito:
  ```ts
  this.pool = new Pool({
    connectionString: this.env.postgres.databaseUrl,
    max: 10,                        // substitui o antigo ?connection_limit=
    connectionTimeoutMillis: 5_000, // NUNCA deixe 0 numa API
    idleTimeoutMillis: 30_000
  })
  ```
  O query param `?connection_limit=` na URL **não faz mais nada**: pool agora é config do `pg`.
- **`url`/`directUrl`/`shadowDatabaseUrl` no `datasource` deprecados** → `prisma.config.ts`.
- **Middleware (`$use`) removido** → `$extends`. Métricas e auto-seed removidos. Flags `--schema`/`--url`/`--skip-seed` removidas.
- Mínimos: Node 20.19+, TS 5.4+ (projeto em Node 24 / TS 5.8 — ok).

## Schema

**Dinheiro é `Decimal`, nunca `Float`.** O schema acerta: `amount Decimal @db.Decimal(14,2)`. `Float` é IEEE-754 binário — `0.1 + 0.2 !== 0.3` e saldo derrete em agregação. Para câmbio/taxas, escala maior (`Decimal(18,6)`) em vez de arredondar cedo.

**`DateTime` e timezone.** `date DateTime @db.Date` vira `DATE` puro, sem hora nem timezone: correto para "data da transação" (o dia é fato do domínio, não instante). `createdAt` é `timestamptz` — instante real. Não misture: comparar `@db.Date` com `new Date()` local derrapa um dia conforme o fuso do processo. Normalize para UTC meia-noite antes de filtrar.

**Índices saem da query, não do palpite.** Igualdade primeiro, range por último — é o que `@@index([userId, type, date])` faz: `userId` primeiro (todo acesso é escopado por usuário), `date` no fim porque entra como `gte`/`lte`. `[userId, date]` já serve query que filtra só por `userId` (prefixo), então **não crie `@@index([userId])` sozinho**. Antes de adicionar índice, prove com `EXPLAIN ANALYZE` (ative `enablePrismaLogs` para capturar o SQL) que há `Seq Scan` em tabela grande. Cada índice custa em todo `INSERT`/`UPDATE`; os 7 de `transactions` já estão no limite.

**`@@unique` é regra de negócio, não performance.** `@@unique([userId, source, externalId])` é o que torna ingestão de Open Finance idempotente. Cuidado com `NULL`: no Postgres `NULL` não conflita com `NULL`, então transações manuais (`externalId = null`) **nunca** colidem nesse unique — desejável aqui, mas fácil de confundir com bug.

**n-n implícito vs explícito.** Implícito (`Tag[]` dos dois lados) esconde a tabela de junção — só serve se ela nunca tiver atributos próprios; no dia que precisar de `createdAt`/`weight` nela, a migration é dolorosa. Em domínio financeiro, prefira **explícito** (`@@id([aId, bId])`).

**Soft delete** não é nativo; o schema usa `onDelete: Cascade` a partir de `User`. Se precisar: `deletedAt DateTime?` + `@@index([userId, deletedAt])`, e saiba o preço — **todo** `where` precisa de `deletedAt: null`, e esquecer um vaza registro apagado. Ou centraliza num `$extends`, ou não faz.

## Prisma Client

**`select` explícito é a regra.** Motivo concreto: `UserRepository.findByEmail` faz `findUnique({ where: { email } })` e devolve `row as User` — traz o **hash de senha** para o domínio e para qualquer serializador descuidado. Com `select: { id: true, email: true, name: true, role: true }` o vazamento é impossível por construção. Bônus: menos bytes, e adicionar coluna no schema não muda silenciosamente o payload da API. `select` e `include` **não coexistem no mesmo nível** — aninhe `select` dentro de `include`, ou use só `select`.

**Tipos gerados em vez de `any`.** Os repositórios usam `const where: any = {}` e `parseRowToModel(row: any)`, apagando o strict mode na fronteira mais perigosa. Use `Prisma.TransactionWhereInput` no filtro e `Prisma.TransactionGetPayload<{ select: ... }>` para o tipo da linha. `Prisma.validator<Prisma.TransactionSelect>()({...})` declara o `select` uma vez e deriva o tipo do retorno — mudar o `select` atualiza o tipo em vez de mentir.

**`$transaction` sequencial vs interativo.** Array = queries independentes e atômicas, sem lógica no meio. É o caso de `findMany` + `count` da paginação, que hoje usa `Promise.all` — **não é atômico** e pode devolver `totalCount` inconsistente com a página:

```ts
const [items, totalCount] = await this.db.$transaction([
  this.db.user.findMany({ where, orderBy, skip, take }),
  this.db.user.count({ where })
])
```
Interativo (callback) é para quando a decisão depende do resultado anterior — debitar saldo e criar transação só se houver fundos. Defaults: `maxWait: 2000ms`, `timeout: 5000ms`. **Zero I/O externo (HTTP, fila) dentro do callback**: você segura uma conexão de um pool `max: 10` durante a latência da rede, e 10 requests concorrentes travam a API.

**Isolation level.** Default do Postgres é `ReadCommitted`, que permite write skew — ler total e escrever baseado nele não é seguro. Para invariante de saldo, passe `isolationLevel: Prisma.TransactionIsolationLevel.Serializable` **com retry**: `Serializable` aborta transações conflitantes com **P2034**, e isso é contrato, não bug. Sem retry com backoff, você troca corrupção silenciosa por 500.

**`upsert` vs `createMany`.** `upsert` exige unique — na ingestão externa, `@@unique([userId, source, externalId])` é exatamente a chave. `createMany` é bem mais rápido (um `INSERT` multi-valores) mas **não roda nested writes nem retorna registros**; com `skipDuplicates: true` é o caminho para import em lote idempotente.

**Cursor vs offset.** `skip`/`take` (usado em `findManyWithFilters`) faz o Postgres varrer e descartar `skip` linhas — página 500 fica lenta e itens repetem/somem sob escrita concorrente. Para listas longas ordenadas por `date`:

```ts
const rows = await this.db.transaction.findMany({
  where: { userId },
  orderBy: [{ date: 'desc' }, { id: 'desc' }], // desempate estável obrigatório
  take: 20,
  ...(cursor && { cursor: { id: cursor }, skip: 1 })
})
```
Offset só sobrevive quando o usuário precisa de "página 7" e o total é pequeno.

## Performance

**N+1.** O Prisma **não** resolve se você faz o loop na mão (`for (const t of txs) await db.category.findUnique(...)`) — isso é literalmente N+1. Ele resolve via `include`/`select` aninhado. Regra: `await` dentro de `for`/`map` tocando o banco é N+1.

**`relationLoadStrategy`** escolhe entre `join` (um `LATERAL JOIN` com agregação JSON no Postgres) e `query` (várias queries, merge na aplicação). `join` é default e ganha na maioria dos casos (menos round-trips), mas paga em CPU do banco — a peça mais cara de escalar. Postgres saturado e Node ocioso → `query`. Meça, não adivinhe.

**`$queryRaw` quando o Prisma não expressa a query** — relatório financeiro (soma por categoria/mês, window function, `GROUP BY ROLLUP`) é o caso. Tagged template parametriza sozinho:

```ts
const rows = await this.db.$queryRaw<{ categoryId: string; total: Prisma.Decimal }[]>`
  SELECT category_id AS "categoryId", SUM(amount) AS total
  FROM transactions
  WHERE user_id = ${userId} AND date >= ${from} AND date <= ${to}
  GROUP BY category_id
`
```
`Prisma.sql` compõe fragmentos condicionais, `Prisma.join(ids)` expande arrays em `IN (...)`, `Prisma.empty` é o fragmento vazio. **`Prisma.raw()` e `$queryRawUnsafe` não escapam nada** — só para identificadores vindos de allowlist no código, jamais de input do usuário. O genérico `<T>` é **promessa não verificada**: `NUMERIC` volta `Prisma.Decimal`, `BIGINT` volta `BigInt` (quebra `JSON.stringify`), e `COUNT(*)` é `BigInt` — use `COUNT(*)::int`.

## Migrations

`migrate dev` é **só local**: detecta drift usando o **shadow database** (banco temporário onde replica todo o histórico do zero para validar), gera o SQL, pode pedir reset. `migrate deploy` é produção/CI: aplica pendentes, **não detecta drift, não reseta, não gera nada**. Nunca rode `migrate dev` contra produção.

**Mudança destrutiva → expand/contract.** Renomear/dropar coluna em um deploy só quebra a versão antiga ainda no ar. Três passos: *expand* (coluna nova nullable, app escreve nas duas) → *backfill* (migration de dados) → *contract* (dropa a antiga quando nenhuma instância antiga roda). As migrations `change_source_prop_name` e `chage_plans_and_transaction_source_names` são renomes — se rodaram sem downtime, houve janela de erro.

**Migração de dados ≠ de schema.** `migrate dev --create-only` gera sem aplicar; edite o SQL à mão para o `UPDATE`/backfill. Backfill de tabela grande numa migration única trava a tabela — faça em lotes, fora da migration.

**Falhou em produção?** A migration fica marcada failed e bloqueia todo deploy seguinte. `migrate resolve --rolled-back <nome>` se o SQL não chegou a alterar nada; `--applied <nome>` se o efeito já está no banco. Escolher errado deixa o histórico mentindo sobre o estado real.

## Testes

**Mockar o `PrismaClient` testa o mock, não a query.** Mock não valida constraint, cascade, tipo de coluna nem o `@@unique` que sustenta a idempotência — exatamente o que pode quebrar. Como os repositórios recebem `PrismaClient` por injeção, teste de repositório usa **banco real** (docker-compose/testcontainers); mock só nos use cases, contra a **interface** (`ITransactionRepository`), que é onde a abstração paga.

Isolamento: `TRUNCATE ... RESTART IDENTITY CASCADE` é simples e rápido o bastante. A alternativa — cada teste num `$transaction` com throw no fim para forçar rollback — é mais rápida, mas impede testar código que abre a própria transação. Não paralelize arquivos contra o mesmo banco sem um schema por worker.

## Erros → domínio

`PrismaClientKnownRequestError` tem `code`, `meta`, `message`, `clientVersion`. `balancie-db-repository` é o lugar de traduzir — deixar `P2002` vazar até o controller acopla HTTP ao ORM:

```ts
if (error instanceof Prisma.PrismaClientKnownRequestError) {
  if (error.code === 'P2002') throw new DuplicatedTransactionError(error.meta?.target as string[])
  if (error.code === 'P2003') throw new InvalidReferenceError(error.meta?.field_name as string)
  if (error.code === 'P2025') throw new TransactionNotFoundError()
}
throw error
```
Os que importam: **P2002** unique violado (`meta.target` = campos); **P2003** FK violada (`meta.field_name`) — aqui é `categoryId`/`bankAccountId` inexistente ou `onDelete: Restrict` bloqueando delete; **P2025** registro obrigatório não encontrado — é o que `TransactionRepository.update` lança quando o `userId` não bate, ou seja **404/403, não 500**; **P2000** valor longo demais; **P2034** conflito de escrita → retry.

## Extensions (`$extends`)

Substituem o middleware removido: `result` (campos computados), `query` (interceptar operações — soft delete, escopo por `userId`), `model` (métodos custom). Custo: `$extends` **retorna um client novo**, não muta o original — estender depois de passar `this.db` aos repositórios não aplica nada a eles. E extensões `query` são invisíveis no call site, o que piora o debug. Use para invariante de segurança que **não pode** ser esquecida; não para conveniência.

## Armadilhas com consequência real

- **`PrismaClient` por request.** Cada instância abre um pool; sob carga estoura `max_connections` e a API cai inteira. O projeto acerta: uma instância em `BalancieDbRepository`, viva pelo processo. Em dev com watch, guarde em `globalThis` para o hot-reload não acumular pools.
- **`Decimal` virando `number`.** `parseRowToModel` faz `rawAmount.toNumber()` — converte decimal exato em float e **anula a razão de usar `Decimal(14,2)`**. O dano fica latente até somar milhares de linhas ou ratear centavos. Mantenha `Prisma.Decimal` no domínio (ou inteiro em centavos) e serialize com `.toFixed(2)` na borda HTTP — `JSON.stringify(Decimal)` não produz número.
- **`findFirst` sem `orderBy`.** Em `findById` está ok (`id` é PK). Mas num where não-único devolve **linha arbitrária**: sem `ORDER BY` o Postgres não garante ordem e o resultado muda depois de um `VACUUM`. Funciona em dev, alterna em produção.
- **Seed não idempotente.** `prisma/seed.ts` cria dados via use cases. Se usa `create` em vez de `upsert`, rodar duas vezes estoura P2002 ou duplica. Ancore `upsert` nos uniques existentes (`users.email`, `categories(userId,name,type)`) com IDs determinísticos em vez de faker.
- **`where: any` nos repositórios.** Anula o strict mode onde um typo (`where.userid`) vira filtro ignorado — vazamento de dados entre usuários, silencioso e sem erro de tipo. `Prisma.TransactionWhereInput` custa uma linha.
