# TypeScript para backend Node

Decisões de tipo em API Node: estreitar dados da borda, derivar tipos em vez de redigitá-los, o que `module: node16` faz, e quais flags ligar além de `strict`. Abra ao modelar domínio/DTO, ao brigar com resolução de módulo, ao ver `as` se espalhando, ou antes de escrever tipo type-level. Contexto: `balancie-api` — TS 5.8, `strict`, `target: es2022`, `lib: es2023`, `module`/`moduleResolution: node16`, zod 4, Prisma 7, camadas `domain`/`usecases`/`repositories`/`dto`/`main`.

## A regra que organiza o resto: a borda valida, o núcleo confia

Um tipo é uma promessa; `zod` é o único lugar que transforma promessa em fato. Fora dele, todo tipo é herdado de algo já provado.

```ts
// src/domain/user.ts — o schema é a fonte, o tipo é consequência
export const UserSchema = z.object({ id: UUIDSchema, email: EmailSchema, /* ... */ }).strict()
export type User = z.infer<typeof UserSchema>   // nunca redigite os campos
```

Isso já está certo no projeto. Quem manda em cada fronteira: HTTP → `zod` via `fastify-type-provider-zod`; banco → tipos do Prisma; APIs externas → `zod` no adapter. Passada a fronteira, o núcleo confia e não revalida.

Corolário: DTO deriva do domínio, não duplica. `CreateTransactionDto = Pick<Transaction, 'amount' | …>` está correto — quando `Transaction` mudar, o DTO acompanha ou quebra o build, que é o que você quer. Redigitar os campos deixa o build verde com o código errado.

## `as` é onde os tipos morrem

`as` não converte nada: desliga a checagem e a mentira segue silenciosa até virar `TypeError` em produção. Merece a seção mais dura porque `src/repositories/balancie-db-repository/*.ts` está cheio dele — `return row as User` (user-repository.ts:82, 96, 110, 131, 156), `items: users as User[]` (:180).

Cada um afirma que uma linha do Prisma é um `User` do domínio, sem provar. Se `UserSchema` ganhar um campo que o `select` não traz, o compilador continua feliz e a request quebra. Ou a linha vira `User` por mapeamento explícito, ou passa por `UserSchema.parse`:

```ts
function toUser(row: PrismaUser): User {          // o compilador confere campo a campo
  return { id: row.id, email: row.email, name: row.name, role: row.role, /* ... */ }
}
```

Quando o `as` for inevitável (ponte entre enum do Prisma e union do domínio, como `dto.type as PrismaBankAccountType`), isole-o num único mapper com `satisfies` provando totalidade — não espalhe por 8 call sites.

### `satisfies` em vez de `as` ou anotação

`satisfies` checa o valor contra o tipo **sem alargar** o inferido. É quase sempre a escolha certa:

```ts
const config = { port: 3000, env: 'prod' } as Config          // ❌ não checa nada de verdade
const config: Config = { port: 3000, env: 'prod' }            // ⚠️ checa, mas env vira string
const config = { port: 3000, env: 'prod' } satisfies Config   // ✅ checa E env fica 'prod'

// uso mais valioso: provar que um Record cobre a union inteira (falta de caso = erro aqui, não no runtime)
const labels = { CUSTOMER: 'Cliente', ADMIN: 'Administrador' } satisfies Record<UserRole, string>
```

## Narrowing: como o compilador ganha certeza

Em ordem de preferência: `typeof`/`in`/`instanceof`/igualdade → discriminated union → type predicate → assertion function.

**Discriminated union** é o padrão que faz o resto funcionar — uma propriedade literal comum e o compilador estreita sozinho:

```ts
type Result<T> = { ok: true; value: T } | { ok: false; error: DomainError }
if (result.ok) result.value  // estreitado, sem cast
```

**`never` para exhaustiveness** — a técnica de maior retorno aqui. Torna "adicionei um caso na union" um erro de compilação em vez de bug silencioso:

```ts
function assertNever(x: never): never {
  throw new Error(`Caso não tratado: ${JSON.stringify(x)}`)
}

switch (tx.type) {
  case 'INCOME':  return apply(tx)
  case 'EXPENSE': return deduct(tx)
  default: return assertNever(tx)   // quebra o build se surgir 'TRANSFER'
}
```

**Type predicates** (`x is T`) — corpo e predicado precisam concordar; o compilador acredita em você, não verifica. Predicado errado é `as` com passos extras. Prefira derivar do zod:

```ts
const isUser = (x: unknown): x is User => UserSchema.safeParse(x).success  // ✅ prova de verdade
```

**Assertion functions** (`asserts x is T`) estreitam do ponto da chamada em diante. Exigem anotação explícita — não funcionam com `const f = (…) => {…}` sem tipo declarado.

## `unknown` vs `any` vs `never`

- `any` desliga o compilador e **contamina**: tudo que toca `any` vira `any`. Repare em `IUseCase<Input = any, Output = any>` (`src/usecases/usecase.ts`): os defaults fazem `IUseCase` sem argumentos aceitar qualquer coisa em `execute`. `unknown` como default forçaria o call site a se declarar.
- `unknown` é o `any` honesto: aceita tudo, não deixa fazer nada até estreitar. Use na entrada de dado não confiável.
- `never` é o conjunto vazio: nada lhe é atribuível. Daí servir de detector de exhaustividade.

### `catch (e: unknown)`

`useUnknownInCatchVariables` já vem por `strict`, e é uma feature: em JS pode-se lançar qualquer coisa, então `e` precisa ser estreitado antes do uso.

```ts
try { await repo.save(user) } catch (e: unknown) {
  if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') throw new EmailAlreadyExistsError()
  if (e instanceof Error) logger.error({ err: e.message })
  throw e   // não engula o que você não reconheceu
}
```

## `module: node16` — o que realmente acontece aqui

Isto confunde muita gente, e o detalhe decisivo é local: **o `package.json` do projeto não tem campo `"type"`**. Sob `node16`, isso significa que todo `.ts` daqui é **CommonJS**. Consequências:

- **`.js` em import relativo NÃO é obrigatório aqui.** A extensão só é exigida em arquivos ESM; como estes são CJS, `import { x } from './user'` está correto. Muda no dia em que alguém adicionar `"type": "module"` — aí todo import relativo precisa de `.js` (sim, `.js` apontando para um `.ts`: o caminho é o do output).
- O formato vem da extensão primeiro (`.mts`/`.cts` sempre ESM/CJS), depois do `"type"` do `package.json` mais próximo.
- `esModuleInterop` (ligado, implícito em `node16`) faz `import fs from 'fs'` funcionar contra CJS.
- **Dual package hazard**: pacote carregado nas duas versões vira duas instâncias — `instanceof` falha, singleton duplica.
- `import type` garante remoção do import no emit: evita ciclo em runtime entre `domain` e `repositories`.

Ligue **`verbatimModuleSyntax`**: força o que você escreve a ser o que é emitido. Com `import type`, elimina a classe de bugs "o import sumiu no build" / "o side-effect não rodou".

Sobre `paths` (`@/*` → `src/*`): o `tsconfig` só afeta a checagem — quem resolve em runtime é `module-alias` (prod) e `tsx`/`vite-tsconfig-paths` (dev/test). Alias que passa no `tsc` e explode no `node` é desalinhamento entre essas três configs; o compilador não avisa.

## Flags de `strict`, explicadas por consequência

`strict` já liga: `strictNullChecks`, `noImplicitAny`, `strictFunctionTypes`, `strictBindCallApply`, `strictPropertyInitialization`, `noImplicitThis`, `alwaysStrict`, `useUnknownInCatchVariables`. O que **não** vem junto e vale ligar:

| Flag | O que muda na prática |
|---|---|
| `noUncheckedIndexedAccess` | `arr[0]` e `map[k]` viram `T \| undefined`. Mata a maior fonte real de `undefined is not a function`. Adoção cara, retorno alto. **Ligue.** |
| `verbatimModuleSyntax` | O emit espelha o source (ver acima). **Ligue.** |
| `exactOptionalPropertyTypes` | Distingue "campo ausente" de "campo = `undefined`". Importa em update parcial: `{ name: undefined }` deixa de ser igual a não mandar nada — bug clássico de PATCH. |
| `noImplicitOverride` | Exige `override`. Barato; só rende com hierarquia de classes. |
| `noFallthroughCasesInSwitch` | Complementa `assertNever` nos switches de `type`/`status`. |

`skipLibCheck: true` (ligado) esconde erro real: se os tipos de Prisma 7, zod 4 e Fastify 5 forem incompatíveis entre si, você não fica sabendo. É trade-off de build, não boa prática — quando um tipo de dependência estiver misteriosamente errado, desligue antes de culpar seu código.

## Generics: úteis, e quando são over-engineering

Regra: **um type param precisa aparecer em pelo menos dois lugares** (entrada e saída, ou duas entradas) para pagar seu custo. Aparece uma vez só? É `unknown` com passos extras.

```ts
function first<T>(xs: T[]): T | undefined                       // ✅ T liga entrada e saída
function log<T>(x: T): void                                     // ❌ era pra ser (x: unknown)
function pluck<T, K extends keyof T>(xs: T[], k: K): T[K][]     // ✅ constraint dá retorno exato
function withFallback<T>(vs: T[], fb: NoInfer<T>): T            // 5.4: fb não polui a inferência de T
function routes<const T extends readonly string[]>(r: T): T     // 5.0: literais sem `as const`
```

Generics em repositório quase sempre são over-engineering: `IUseCase<Input, Output>` só ganha valor se algo consome usecases genericamente. Se cada implementação fixa os dois params, os generics só viraram ruído.

## Type-level: poder com custo de manutenção

Conditional (`T extends U ? A : B`), `infer`, mapped types e template literals resolvem casos reais — e produzem tipos indebugáveis: erro de 40 linhas, IntelliSense lento, próximo dev travado. **Regra: em aplicação, utility types prontos e mapped types simples; conditional recursivo e aritmética de template literal são para biblioteca.**

```ts
type PublicUser = Omit<User, 'password'>                        // ✅ derivado, óbvio, revisável
type Flatten<T> = T extends Array<infer I> ? I : T              // conditional + infer
type Mutable<T> = { -readonly [K in keyof T]: T[K] }            // mapped, modificador -readonly
type Getters<T> = { [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K] }  // template literal
```

Detalhe que morde: conditional types **distribuem** sobre unions — `T extends any ? T[] : never` com `string | number` dá `string[] | number[]`, não `(string|number)[]`. Para desligar, envolva em tuplas: `[T] extends [U]`.

Do dia a dia: `Pick`, `Omit`, `Partial`, `Required`, `Record`, `Exclude`, `Extract`, `NonNullable`, `Awaited<T>` (desembrulha promise), `ReturnType<typeof f>`, `Parameters<typeof f>`.

## Branded types para IDs e dinheiro

`userId: string` e `categoryId: string` são o mesmo tipo — trocar os dois na chamada compila. Branding dá distinção nominal com zero custo em runtime:

```ts
declare const brand: unique symbol
type Brand<T, B> = T & { readonly [brand]: B }

type UserId     = Brand<string, 'UserId'>
type CategoryId = Brand<string, 'CategoryId'>

const toUserId = (s: string): UserId => UUIDSchema.parse(s) as UserId  // única fábrica, valida

declare function find(id: UserId): Promise<User>
find(categoryId)   // ✅ erro de compilação — antes, bug de produção
```

Para dinheiro o ganho é maior: `type Cents = Brand<number, 'Cents'>` impede somar centavos com reais e documenta a unidade no tipo. Guarde dinheiro em inteiro (centavos) ou `Decimal` do Prisma — nunca `float`.

## Armadilhas restantes

- **`enum` vs union de string literal**: `enum` gera objeto em runtime, não é erasable (proibido sob `--erasableSyntaxOnly`, o type-stripping nativo do Node) e atrita com os tipos do Prisma. O padrão de `src/domain/user.ts` — objeto `as const` + `typeof M[keyof typeof M]` — é a escolha certa: zero runtime, interopera com `z.enum`, dá literais.
- **`interface` vs `type`**: `interface` faz declaration merging (aumentam seu tipo à distância) e só descreve objeto; `type` é fechado e faz union/conditional/mapped. Padrão: `type`, com `interface` para merging proposital ou `implements`.
- **`!`** é `as` disfarçado: `obj.foo!.bar` promete sem provar. Prefira early return, `?.` ou `??`.
- **Decorators**: os do 5.0 seguem o padrão ECMAScript, incompatíveis com `emitDecoratorMetadata` e decorators de parâmetro. `reflect-metadata` está nas deps — legados aqui doem, e são desnecessários nesta arquitetura.
- **`using` (5.2)**: `lib` é `es2023`, que **não** inclui `esnext.disposable` — `using` não typechecka. Para cleanup determinístico (conexão, transação), adicione `"esnext.disposable"` ao `lib`.
- **5.8**: cada branch de ternário em `return` é checado contra o retorno declarado — antes `any | string` colapsava para `any` e escondia o erro. Mais um motivo para **declarar o retorno** de funções públicas: sem anotação, não há contra o que checar.
