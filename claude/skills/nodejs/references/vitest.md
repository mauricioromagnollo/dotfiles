# Vitest 3 — API e estratégia de teste em API Node

Referência para escrever e revisar testes neste projeto (Fastify 5 + Prisma 7 + PostgreSQL, Vitest 3.2.4, TypeScript strict, Node 24). Abra este arquivo antes de criar um `.spec.ts`, mexer em `vitest.config*.mts`, decidir o que mockar, ou investigar teste flaky/lento. Cobre a API que muda decisão — não o catálogo completo do doc.

**Aviso de versão**: o site do Vitest documenta a v4. Este projeto está em **3.2.4**. APIs que **não existem** na 3.2.4: o builder `test.extend('nome', fn)`, `test.override`, `test.aroundEach`/`aroundAll`. Use a forma de objeto do `test.extend` e `test.scoped`. Se copiar exemplo do doc, verifique o "4.x+" no badge.

---

## 1. Configuração real deste projeto

Quatro arquivos, um base e três derivados por nível:

| Arquivo | `name` | `include` | Paralelismo |
|---|---|---|---|
| `vitest.config.mts` | — (base) | `tests/**` | padrão |
| `vitest.config.unit.mts` | `UNIT TEST` | `tests/unit/**/*.spec.ts` | padrão (paralelo) |
| `vitest.config.integration.mts` | `INTEGRATION TEST` | `tests/integration/**/*.spec.ts` | `fileParallelism: false` |
| `vitest.config.e2e.mts` | `E2E TEST` | `tests/e2e/**/*.spec.ts` | `fileParallelism: false` |

Os derivados fazem spread do base (`...baseConfig.test`) — **spread é raso**. Sobrescrever `test.coverage` ou `test.alias` num derivado substitui o objeto inteiro, não faz merge. Adicione chaves no base quando quiser que valham para todos.

Base já define `restoreMocks: true`, `globals: true`, `environment: 'node'`, `testTimeout: 100000`, `reporters: ['verbose']`, aliases via `vite-tsconfig-paths`, e coverage v8 com thresholds em 98%.

**Consequências práticas**:
- `restoreMocks: true` restaura automaticamente todo `vi.spyOn` depois de cada teste. Portanto `afterEach(() => vi.clearAllMocks())` espalhado pelos specs é **redundante** — não copie esse padrão em teste novo.
- `globals: true` está ligado, mas os testes existentes importam `{ describe, it, expect }` de `vitest` explicitamente. **Mantenha o import explícito** — é a convenção do repo e sobrevive a `globals: false`.
- `testTimeout: 100000` (100s) é alto demais para unit. Um unit que trava só falha depois de 100s. Para unit, passe timeout local: `it('...', async () => {...}, 5000)`.

**Dois defeitos latentes no base** (não corrija sem pedir, mas saiba que existem):
1. `alias` tem espaço no fim do path: `new URL('./tests/ ', ...)` e `'./src/ '`. Esses aliases resolvem para caminho inválido. Funcionam hoje só porque `tsconfigPaths()` resolve `@/*` antes. Se o plugin sair, tudo quebra.
2. `coverage.all: true` foi removido no Vitest 3 — quem faz esse papel agora é `coverage.include`. A chave é ignorada.

---

## 2. API de teste — o que muda decisão

### `test.each` vs `test.for`

`each` **espalha** arrays em argumentos; `for` **não espalha** e entrega o `TestContext` como segundo parâmetro. Use `for` quando o caso é um array/objeto que você quer receber inteiro, ou quando precisa de fixtures dentro do caso.

```ts
// each: espalha
it.each([
  ['', 'password'],
  ['not-an-email', 'password']
])('should reject email %s', async (email, password) => { /* ... */ })

// for: não espalha, dá contexto
it.for([
  { input: '', expected: 'string' },
  { input: 'abc', expected: 'number' }
])('validates $input', ({ input, expected }, { expect }) => { /* ... */ })
```

Formatação do título: `%s %d %i %o %#` (índice) ou `$prop` / `$prop.nested` para objetos.

### `.only` / `.skip` / `.todo` / `.fails`

- `.only` **lança erro em CI** (`allowOnly` é false quando `process.env.CI`). Isso é proteção — não desligue.
- `.skip` mantém o teste visível como pulado; `.todo` declara intenção sem corpo. Prefira `.todo` a comentar código.
- `.fails` afirma que a promise/teste **falha**. Só use para caracterizar bug conhecido; um `.fails` que começa a passar quebra a suíte (que é o ponto).
- `.skipIf(cond)` / `.runIf(cond)` para condicionar por ambiente. Cuidado: `skipIf(!process.env.DATABASE_URL)` transforma "banco caiu" em "suíte verde". Prefira falhar alto.

### `.concurrent` e estado compartilhado

`.concurrent` roda testes do mesmo suite em paralelo dentro do arquivo. **Não use em `tests/integration` nem `tests/e2e`** deste projeto: o banco é compartilhado e dois testes concorrentes escrevendo na mesma tabela produzem falha intermitente. Além disso, com `.concurrent` o `expect` global não sabe a qual teste pertence — use o `expect` do contexto:

```ts
it.concurrent('pure calculation', async ({ expect }) => {
  expect(sum(2, 2)).toBe(4)  // expect local, não o global
})
```

`beforeEach` com variável de módulo (`let sut`) + `.concurrent` = corrida. Se o suite tem `let` no escopo do `describe`, `.concurrent` está errado ali.

### `test.extend` — fixtures (o recurso mais subutilizado)

Substitui o par `beforeEach`/`afterEach` com variável `let` por algo tipado, lazy e com cleanup acoplado. Fixture **só é construída se o teste a referenciar** no destructuring.

```ts
// tests/helpers/e2e-test.ts
import { test as base } from 'vitest'
import type { FastifyInstance } from 'fastify'
import { buildApi } from '@/main/build-api'
import { prisma } from '@/infra/prisma'
import { MockGenerator } from '@/tests/helpers'
import type { User } from '@/domain'

interface Fixtures {
  api: FastifyInstance
  user: User
}

export const test = base.extend<Fixtures>({
  // scope: 'file' → uma instância por arquivo (3.2.0+)
  api: [async ({}, use) => {
    const api = await buildApi()
    await api.ready()
    await use(api)
    await api.close()          // cleanup roda DEPOIS do use()
  }, { scope: 'file' }],

  user: async ({}, use) => {
    const created = await prisma.user.create({ data: MockGenerator.randomUser() })
    await use(created)
    await prisma.user.delete({ where: { id: created.id } })
  }
})
```

```ts
import { expect } from 'vitest'
import { test } from '@/tests/helpers/e2e-test'

test('GET /users/:id returns the user', async ({ api, user }) => {
  const response = await api.inject({ method: 'GET', url: `/api/users/${user.id}` })
  expect(response.statusCode).toBe(200)
  expect(response.json()).toMatchObject({ id: user.id, email: user.email })
})
```

Ganho real: o teste que não pede `user` não toca no banco. Com `beforeEach` global, todo teste do arquivo paga o custo e o vazamento.

Opções na 3.2.4: `{ auto: true }` (roda mesmo sem ser referenciada), `{ scope: 'test' | 'file' | 'worker' }`, `{ injected: true }` (valor vem de `provide` no config, por project). `test.scoped({...})` sobrescreve valor dentro de um `describe`.

### Hooks — ordem e cleanup

Ordem padrão (`sequence.hooks: 'stack'`): `beforeAll` de fora pra dentro, `beforeEach` de fora pra dentro, teste, `afterEach` **de dentro pra fora**, `afterAll` de dentro pra fora. Ou seja, `afterEach` é LIFO em relação a `beforeEach`.

Cleanup por retorno é mais seguro que `afterEach` separado — o par nasce junto:

```ts
beforeEach(() => {
  const spy = vi.spyOn(logger, 'error').mockImplementation(() => {})
  return () => spy.mockRestore()   // roda mesmo se o beforeEach seguinte falhar
})
```

`onTestFinished(fn)` registra cleanup **de dentro do teste**, roda mesmo se o teste falhar, na ordem inversa do registro. É o certo para recurso criado no meio do teste:

```ts
it('rolls back on conflict', async ({ onTestFinished }) => {
  const user = await prisma.user.create({ data: MockGenerator.randomUser() })
  onTestFinished(() => prisma.user.delete({ where: { id: user.id } }))
  // ... o delete acontece mesmo se a asserção abaixo estourar
})
```

`onTestFailed(fn)` só roda em falha — bom para dump de diagnóstico (últimas linhas de log, estado da tabela).

---

## 3. `expect` — escolhas que importam

**`toEqual` vs `toStrictEqual` vs `toMatchObject`**:
- `toEqual` — igualdade estrutural recursiva; **ignora propriedades `undefined`**. `{ a: 1, b: undefined }` iguala `{ a: 1 }`.
- `toStrictEqual` — além de tudo, exige mesma classe/protótipo, exige que `undefined` exista, e checa sparseness de array. É o certo quando a **classe** importa (entidade de domínio vs objeto literal) ou quando "campo ausente" ≠ "campo undefined" (payload de API).
- `toMatchObject` — subconjunto. É o certo para resposta HTTP que carrega `createdAt`/`id` que você não controla.

Regra prática neste projeto: resposta de rota → `toMatchObject` + asymmetric matchers; retorno de usecase → `toStrictEqual`.

```ts
expect(response.json()).toMatchObject({
  id: expect.any(String),
  email: user.email,
  createdAt: expect.stringMatching(/^\d{4}-\d{2}-\d{2}T/)
})
expect(response.json()).not.toHaveProperty('password')  // asserção negativa vale ouro
```

Asymmetric matchers: `expect.any(Constructor)`, `expect.objectContaining`, `expect.arrayContaining`, `expect.stringContaining`, `expect.closeTo(n, precisão)`. Compõem dentro de `toEqual`/`toHaveBeenCalledWith`.

**`rejects` / `resolves`** — o padrão do repo, e o `await` é obrigatório:

```ts
await expect(sut.execute(input)).rejects.toThrowError(
  new InvalidParamError({ paramName: 'password', expected: 'string' })
)
```

`toThrowError(new Error(...))` compara **apenas a `message`** — não a classe. Se a classe importa, adicione `.rejects.toBeInstanceOf(InvalidParamError)`.

**`expect.soft`** — coleta várias falhas em vez de parar na primeira. Útil quando você valida vários campos de um payload e quer ver todos os errados de uma vez.

**`expect.assertions(n)` / `expect.hasAssertions()`** — obrigatório quando o teste usa `try/catch` para capturar erro. Vários specs deste repo usam:

```ts
try { env.validate() } catch (error: any) { expect(error?.message).toBe('...') }
```

Se `validate()` **parar de lançar**, o `catch` nunca roda, zero asserções executam e o teste **passa verde com o código quebrado**. Isso é um falso negativo real na suíte. Corrija preferindo `expect(() => env.validate()).toThrowError(...)`, ou, se precisar inspecionar o erro, ancore com `expect.assertions(5)` no topo.

**Snapshots** — `toMatchInlineSnapshot` só vale para saída pequena, determinística e legível no diff (mensagem de erro formatada, SQL gerado). **Não use** para resposta HTTP com `id`/`createdAt`/faker: o snapshot vira ruído, ninguém revisa, e `-u` "conserta" a regressão. Snapshot que cabe numa asserção explícita deve ser uma asserção explícita.

---

## 4. `vi` — hoisting, spies, tempo

### O hoisting de `vi.mock`

`vi.mock` é **içado para o topo do arquivo, antes de todos os imports**. Por isso a factory não pode referenciar variável do escopo do módulo — ela ainda não existe:

```ts
// ❌ ReferenceError: Cannot access 'mockSend' before initialization
const mockSend = vi.fn()
vi.mock('@/infra/mailer', () => ({ send: mockSend }))

// ✅ vi.hoisted sobe a definição junto
const { mockSend } = vi.hoisted(() => ({ mockSend: vi.fn() }))
vi.mock('@/infra/mailer', () => ({ send: mockSend }))
```

Mock parcial preserva o resto do módulo:

```ts
vi.mock('@/shared/helpers', async (importOriginal) => ({
  ...await importOriginal<typeof import('@/shared/helpers')>(),
  PasswordHelper: vi.fn()
}))
```

`vi.mock` **só intercepta acesso externo ao módulo**. Se `moduloA.foo()` chama `moduloA.bar()` internamente, mockar `bar` não afeta essa chamada. Quando isso te morde, o problema é o design (falta de injeção), não o mock.

`vi.doMock` não é içado (aceita variáveis) mas só afeta `import()` dinâmico posterior.

### clear vs reset vs restore

| | histórico de chamadas | implementação | original |
|---|---|---|---|
| `clearAllMocks` | limpa | mantém | — |
| `resetAllMocks` | limpa | reseta p/ `undefined` | — |
| `restoreAllMocks` | limpa | — | **restaura o `spyOn`** |

O base já tem `restoreMocks: true`. Um `vi.spyOn` **não restaurado** é o clássico vazamento entre arquivos quando `isolate: false` — mas com `restoreMocks` ligado aqui, o risco real é outro: chamar `vi.resetAllMocks()` manualmente no meio do arquivo apaga implementações que o `beforeEach` montou.

### Env e tempo

`vi.stubEnv('JWT_SECRET', 'x')` + `vi.unstubAllEnvs()` é preferível a `vi.stubGlobal('process', { env })` — o `stubGlobal` de `process` inteiro (padrão em `node-environment.spec.ts`) derruba `process.cwd`, `process.exit` e tudo mais, e só não explode porque a classe sob teste só lê `env`.

Tempo determinístico:

```ts
beforeEach(() => {
  vi.useFakeTimers()
  vi.setSystemTime(new Date('2026-01-01T00:00:00Z'))
})
afterEach(() => vi.useRealTimers())
```

`setSystemTime` muda o relógio sem disparar timers. Cuidado: fake timers **congelam o event loop de timers** — Prisma/pg com pool e retry podem travar. Em `tests/integration`, use `toFake: ['Date']` para mockar só a data:

```ts
vi.useFakeTimers({ toFake: ['Date'] })
```

---

## 5. Isolamento e paralelismo

- **`pool`**: `forks` (padrão na v3, processos, isolamento real, `process.env`/`process.exit` seguros) vs `threads` (worker_threads, mais rápido, mas nativos como `bcrypt` e Prisma engine podem se comportar mal). Para este projeto, `forks` é a escolha certa — não troque para ganhar segundos.
- **`isolate: true`** (padrão): módulos recarregados por arquivo. `isolate: false` acelera muito, mas estado de módulo (singleton do `PrismaClient`, cache de config) passa a vazar entre arquivos.
- **`fileParallelism: false`**: força **um arquivo por vez**. É por isso que `integration` e `e2e` já têm no config, e por isso `test:coverage` passa `--fileParallelism=false`: esse script usa o `vitest.config.mts` base, cujo `include: ['tests/**']` roda **unit + integration + e2e juntos** contra **o mesmo banco PostgreSQL**. Dois arquivos truncando a mesma tabela em paralelo = flaky. A flag é o que segura isso — não remova por performance.
- **`maxConcurrency`**: limite de testes `.concurrent` simultâneos por arquivo. Irrelevante enquanto ninguém usar `.concurrent`.

**`globalSetup` vs `setupFiles`**:
- `globalSetup` roda **uma vez por execução**, num contexto separado (não enxerga `vi`, nem os globals de teste). Pode retornar uma função de teardown. Lugar certo para: subir container, rodar `prisma migrate deploy`.
- `setupFiles` roda **uma vez por arquivo de teste**, dentro do worker, com acesso a `vi` e hooks. Lugar certo para: `beforeEach` global de truncate de tabelas, `nock.disableNetConnect()`, seed de faker.

Ordem: `globalSetup` → (por arquivo) `setupFiles` na ordem do array → arquivo de teste.

```ts
// tests/helpers/setup-db.ts, referenciado em setupFiles do config de integration/e2e
import { beforeEach, afterAll } from 'vitest'
import { prisma } from '@/infra/prisma'

beforeEach(async () => {
  await prisma.$executeRawUnsafe('TRUNCATE TABLE "transactions", "users" RESTART IDENTITY CASCADE')
})
afterAll(async () => { await prisma.$disconnect() })
```

**`projects`** substituiu `workspace` no Vitest 3 (`workspace` está deprecado e sai na v4). Se um dia quiser `npm test` rodando os três níveis com nomes separados e um só relatório de coverage, é o caminho — em vez de quatro `.mts` com spread:

```ts
// vitest.config.mts
export default defineConfig({
  plugins: [tsconfigPaths()],
  test: {
    projects: [
      { test: { name: 'unit', include: ['tests/unit/**/*.spec.ts'] } },
      { test: { name: 'integration', include: ['tests/integration/**/*.spec.ts'], fileParallelism: false } },
      { test: { name: 'e2e', include: ['tests/e2e/**/*.spec.ts'], fileParallelism: false } }
    ],
    coverage: { /* fica no nível raiz, agregado */ }
  }
})
```
Roda um só: `npx vitest --project=unit`.

---

## 6. Estratégia por nível

### `tests/unit` — domínio, usecases, helpers
Sem I/O, sem banco, sem HTTP. Roda em paralelo. Mocke **só as fronteiras** (repositório, mailer, clock), via injeção no construtor — não via `vi.mock` de módulo. Um usecase que precisa de `vi.mock` para ser testado está acoplado a um detalhe de infra; o teste está te avisando.

```ts
const makeSut = () => {
  const userRepository = new InMemoryUserRepository()
  const passwordHelper = { hash: vi.fn().mockResolvedValue('hashed'), compare: vi.fn() }
  return { sut: new CreateUserUsecase(userRepository, passwordHelper), userRepository, passwordHelper }
}
```

### `tests/integration` — repositório contra banco real
Prisma real, PostgreSQL real, sem Fastify. Testa o que unit não alcança: constraints, unique, cascade, transação, o SQL que o Prisma gera de fato. `fileParallelism: false` + truncate em `beforeEach`.

### `tests/e2e` — HTTP de verdade
`api.inject()` (Fastify light-my-request, in-process, mais rápido e sem porta) ou `supertest(api.server)` quando precisar do socket real. Banco real, sem mock de nada interno. Assere status, shape do body, e o **que não deve estar lá** (`password`, stack trace). Nock só para bloquear/simular terceiro externo.

---

## 7. Mock: o que mockar e o que não

**Mocke**: HTTP de terceiro (nock), relógio (fake timers), aleatoriedade (faker com seed), coisas caras e sem valor de teste (`bcrypt` com custo alto em unit).

**Não mocke o `PrismaClient`.** É a armadilha mais cara desta stack:

```ts
// ❌ Este teste passa mesmo se o schema não tiver a coluna, se o where estiver errado,
//    se a constraint unique estourar em produção, ou se o campo mudar de nome.
vi.mock('@/infra/prisma', () => ({ prisma: { user: { findUnique: vi.fn() } } }))
```
Você acabou de testar que o seu mock retorna o que você mandou ele retornar. Todo o valor do repositório está justamente no acordo com o banco — o único lugar que o mock apaga. Repositório se testa em `tests/integration`, contra Postgres.

**Alternativa melhor a mock: fake/in-memory.** Para unit de usecase, um `InMemoryUserRepository` implementando a mesma interface tem comportamento real (guarda, busca, rejeita duplicado), é reutilizável e não quebra quando você adiciona um método. Um `vi.fn()` por método não tem comportamento nenhum e mente sobre a integração.

**Nock 14** para externo, em `setupFiles`:

```ts
import nock from 'nock'
import { beforeAll, afterEach, afterAll } from 'vitest'

beforeAll(() => { nock.disableNetConnect(); nock.enableNetConnect('127.0.0.1') })  // libera o banco/Fastify local
afterEach(() => { nock.cleanAll() })
afterAll(() => { nock.enableNetConnect() })
```

`nock.disableNetConnect()` é o que transforma "o teste bateu na API de verdade do fornecedor" num erro imediato em vez de num teste lento e intermitente. Assere que o interceptor foi consumido — `expect(scope.isDone()).toBe(true)` — senão um mock nunca chamado passa despercebido.

---

## 8. Determinismo

- **Faker com seed**: `faker.seed(1234)` num `setupFiles` torna a falha reproduzível. Sem seed, `MockGenerator.randomEmail()` gera valor novo a cada run — quando um teste quebra 1 vez em 50 por causa de um e-mail com apóstrofo, não há como reproduzir. Se preferir dados variados (fuzzing barato), imprima a seed usada no console para poder fixá-la.
- `MockGenerator.randomCPF()` usa `Math.random()` direto, fora do faker — a seed do faker **não** o controla. Se der flaky, é aqui.
- **Data**: nunca `new Date()` no assert. `setSystemTime` ou injete um `Clock`.
- **Nada de `sleep`**. `await new Promise(r => setTimeout(r, 500))` é confissão de corrida. Use `vi.advanceTimersByTime`, `await api.ready()`, ou espere o evento certo.
- **Ordem independente**: cada teste monta o que precisa. Valide com `--sequence.shuffle` — se quebrar, há acoplamento entre testes.
- **Teste flaky é bug**, do teste ou do código. `retry: 3` no config esconde corrida em produção. Se usar `retry`, use pontual e com issue aberta.

---

## 9. Armadilhas com consequência real

- **`--passWithNoTests` no script `test`**: `tests/integration` e `tests/e2e` hoje têm só `sample.spec.ts` com `expect(1+1).toBe(2)`. Um typo no `include`, ou um refactor que renomeia `.spec.ts` → `.test.ts`, deixa a suíte vazia e o CI **verde**. A flag é útil no `test:staged` (`run related` legitimamente encontra zero arquivos); é perigosa no script base.
- **Async sem `await`**: `expect(sut.execute()).rejects.toThrow()` sem `await` retorna uma promise que ninguém observa — o teste passa e a rejeição vira unhandled. Sempre `await` em `.rejects`/`.resolves`. Idem `expect(promise).resolves`.
- **`beforeAll` vazando entre arquivos**: `beforeAll` é por arquivo, mas o **módulo importado** é compartilhado quando `isolate: false`. Um `beforeAll` que cria usuário fixo com e-mail fixo colide com o do arquivo vizinho quando o paralelismo volta. Dado global com valor fixo é bomba-relógio; use faker por teste + cleanup em `onTestFinished`.
- **Spy não restaurado**: aqui o `restoreMocks: true` cobre `spyOn`, mas **não** cobre `vi.stubGlobal` (precisa de `unstubGlobals: true` ou `vi.unstubAllGlobals()`) nem `vi.useFakeTimers` (precisa de `vi.useRealTimers()`). Os specs que fazem `vi.stubGlobal('process', ...)` dependem de o próximo `beforeEach` sobrescrever — funciona por sorte, não por design.
- **Coverage alto sem asserção útil**: o threshold de 98% mede linhas executadas, não comportamento verificado. Um teste que chama o usecase e não assere nada dá 100% de cobertura. O `exclude` do coverage já tira `**/usecase.ts`, `**/repository.ts`, `**/controller.ts`, `src/domain/` — ou seja, **o número de 98% não fala sobre o núcleo do sistema**. Não use esse número como prova de que o domínio está testado.
- **`v8` e branches**: o provider v8 na 3.2 remapeia via AST e é preciso, mas `/* v8 ignore next */` em TypeScript **exige `-- @preserve`** (`/* v8 ignore next -- @preserve */`), senão o esbuild apaga o comentário e o ignore não tem efeito.
- **Spread raso nos configs derivados**: já citado — sobrescrever `test.coverage` no `.unit.mts` apagaria thresholds inteiros sem aviso.

---

## 10. CLI útil

```bash
npm run test:unit                  # -c vitest.config.unit.mts run
npm run test:watch                 # unit em watch
npm run test:integration           # banco de pé obrigatório
npm run test:e2e
npm run test:coverage              # os 3 níveis, serial, com threshold 98%
npm run test:staged                # vitest related --silent (arquivos alterados)

npx vitest -c vitest.config.unit.mts run -t "should hash"   # filtra por nome
npx vitest -c vitest.config.unit.mts run tests/unit/shared  # filtra por path
npx vitest --sequence.shuffle                               # caça acoplamento de ordem
npx vitest --bail=1                                         # para na 1ª falha
npx vitest --reporter=dot                                   # verbose é ruidoso em CI
```

**Debug**: `npx vitest --inspect-brk --no-file-parallelism -c vitest.config.unit.mts run <arquivo>`. `--inspect` exige `--no-file-parallelism` (e pool `forks` já é o padrão) — sem isso, o debugger anexa num worker que não é o seu.
