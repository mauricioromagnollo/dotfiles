---
name: nodejs
description: Escrever, revisar e depurar código Node.js/TypeScript de backend — runtime Node 24, semântica de JavaScript, TypeScript strict, Fastify, Prisma e Vitest. Use ao criar ou alterar rota, controller, use case, repositório, migration, schema Zod ou teste; ao investigar erro de tipo, comportamento assíncrono, vazamento, lentidão ou query; ao decidir entre API nativa do Node e dependência nova. Dispare também em pedidos como "cria um endpoint", "adiciona um campo", "por que esse await não espera", "esse tipo não bate", "essa query tá lenta", "escreve o teste disso", "isso deveria ser stream?", "posso usar require aqui?", mesmo que Node, TypeScript, Fastify, Prisma ou Vitest não sejam citados por nome. Também para justificar NÃO adicionar biblioteca e NÃO abstrair.
---

# Node.js e TypeScript no backend

Backend em Node é decidido em quatro fronteiras: o que entra (validação), o que o núcleo assume (tipos), o que sai (serialização) e o que persiste (banco). Quase todo bug caro deste stack nasce de uma dessas fronteiras vazando para a outra — um `any` que atravessa o controller, um campo que o serializer come em silêncio, um `Decimal` que vira `number`, um `await` que ninguém deu. A linguagem e o framework não protegem você disso; a disciplina nas fronteiras protege.

**Este arquivo é o mapa. Não leia todas as referências** — decida aqui e abra apenas a que a tarefa exige.

## Referências

| Referência | Quando abrir |
|---|---|
| `references/nodejs-runtime.md` | Event loop, ESM vs CJS, streams e backpressure, `AsyncLocalStorage`, worker threads, graceful shutdown, APIs nativas do Node 24 que substituem dependência |
| `references/javascript-core.md` | Semântica da linguagem por baixo do TS: coerção, closures, protótipos, microtasks, combinators de Promise, ponto flutuante e dinheiro, `Map`/`Set`/`WeakMap`, datas |
| `references/typescript.md` | Narrowing, generics, `satisfies`, tipos derivados, `module: node16`, flags de strict, branded types — antes de escrever qualquer tipo não trivial |
| `references/fastify.md` | Rota, controller, hook, plugin, encapsulamento, type provider Zod, error handler, serialização, `inject()` |
| `references/prisma.md` | O ORM: `select` vs `include`, `$transaction`, N+1, `Decimal`, códigos de erro (P2002/P2025/P2003), driver adapter, o que a v7 mudou. Para **modelagem, índices, `EXPLAIN`, isolamento e migration sem downtime**, a skill é a `dba` |
| `references/vitest.md` | API de teste, `vi.mock` e hoisting, fixtures, isolamento e paralelismo, estratégia unit/integration/e2e |

Esta skill cobre a **plataforma**. As vizinhas cobrem o resto, e delegar para elas é preferível a repetir o assunto aqui: `craft` para princípios, design patterns, estrutura de classes, modelagem de domínio, nomear, dimensionar e decidir se abstrai, `dba` para tudo que é banco além da API do Prisma (schema, índice, plano de execução, concorrência, migration sem downtime), `conventional-commits` na hora de commitar.

> As referências foram escritas contra versões específicas: **Node 24, TypeScript 5.8, Fastify 5, Prisma 7, Vitest 3, Zod 4.** Onde o projeto atual estiver em outra major, confirme antes de aplicar — as seções de "o que mudou na vN" existem justamente porque essas fronteiras se movem. Se a instalação local desta skill trouxer uma referência extra de convenções do próprio repositório, ela ganha desta skill em qualquer conflito de estilo.

## O fluxo

### 1. Descubra a convenção antes de impor a sua

Nenhuma regra de estilo desta skill vale mais que o que o repositório já faz. **Antes de criar arquivo novo**, gaste 30 segundos estabelecendo:

- **Formatação**: existe Prettier, ou é ESLint puro? Ponto e vírgula ou não? Aspas? Rode `npx eslint --print-config <um-arquivo.ts>` em vez de adivinhar — a resposta é factual e barata.
- **Nomes**: leia dois arquivos irmãos do que você vai criar. O sufixo é `-use-case.ts` ou `-usecase.ts`? Interface leva prefixo `I`? Pastas por tipo ou por feature?
- **Erro**: o projeto lança exceção ou devolve `Result`/`Either`? Os dois no mesmo repo é sinal de migração pela metade — pergunte para qual lado.
- **Módulos**: `package.json` tem `"type": "module"`? Isso decide se o `.js` em import relativo é obrigatório (veja `references/typescript.md` — a orientação genérica erra isso com frequência).

Um arquivo que segue a convenção errada com perfeição é retrabalho. Copiar o vizinho é quase sempre a resposta certa.

### 2. Localize a fronteira antes de escrever

Antes de abrir qualquer arquivo, responda: a mudança é de **contrato** (o que o cliente HTTP vê), de **regra** (o que o negócio decide) ou de **dado** (o que persiste)? As três quase nunca são o mesmo arquivo, e confundi-las é a origem da maior parte do retrabalho.

Num backend em camadas típico: contrato mora nas rotas/controllers e é onde a tradução de nomenclatura acontece; regra mora nos use cases e não conhece Fastify nem Prisma; forma do dado mora no schema (Zod) e no `schema.prisma`, que precisam concordar sem que ninguém garanta isso por você; acesso a dado mora nos repositórios, e **é onde o erro do ORM morre e vira erro de domínio**.

O teste de vazamento é simples: se o use case importa `fastify` ou `@prisma/client`, a fronteira já vazou.

### 3. Derive o tipo, não o redigite

A regra mais valiosa deste stack, e a mais fácil de quebrar sem perceber: **um conceito tem uma definição, e todo o resto se deriva dela.**

```ts
// O schema é a fonte
export const TransactionSchema = z.object({ /* ... */ })
export type Transaction = z.infer<typeof TransactionSchema>

// DTO: derivado
export type CreateTransactionDto = Pick<Transaction, 'description' | 'type'>

// Rota: derivado, e traduzido para o contrato público na borda
body: TransactionSchema.omit({ id: true }).extend({
  category_id: TransactionSchema.shape.categoryId
})
```

Se você digitou `z.string()` numa rota para um campo que já existe no domínio, parou de derivar e criou uma segunda fonte de verdade. Elas vão divergir — a única questão é quando.

O mesmo vale contra o ORM: os tipos gerados pelo Prisma são a verdade do banco. Não redigite o model como interface, e desconfie de todo `as Model` — um cast na fronteira do Prisma é uma afirmação não verificada exatamente onde o dado é menos confiável.

### 4. Erro é fronteira, não detalhe

Duas decisões que precisam ser tomadas uma vez e valer para o repo inteiro:

- **Onde o erro do ORM vira erro de domínio.** P2002 (unique), P2025 (not found) e P2003 (FK) precisam ser traduzidos na camada de repositório. Se subirem crus, o cliente recebe 500 para o que era 409.
- **Onde o erro de domínio vira status HTTP.** Ou o erro carrega o `statusCode`, ou existe um mapper no error handler — os dois padrões funcionam, misturá-los não. Um único `setErrorHandler` deve ser o único lugar que decide o status.

E o que nunca vaza no body: `error.message` cru em 5xx entrega stack, nome de tabela e string de conexão para o cliente. 5xx recebe mensagem genérica e o detalhe vai para o log.

### 5. Antes de adicionar dependência, verifique o Node 24

Node 24 tem nativamente muita coisa que virou reflexo instalar: `fetch`, `structuredClone`, `crypto.randomUUID`, `util.parseArgs`, `--env-file`, `--watch`, `node:test`, `node:sqlite`. Uma dependência a menos é uma superfície de supply chain, um upgrade e um `npm audit` a menos. Se a API nativa resolve, ela ganha — e diga isso explicitamente em vez de instalar em silêncio.

O contrário também vale: não reimplemente à mão o que o Fastify/Zod/Prisma já fazem por schema. Validação manual dentro do use case costuma ser sinal de que a rota não declarou o schema direito.

### 6. Teste no nível que prova alguma coisa

- **Unit**: domínio e use cases. Mocke só as fronteiras. Fake in-memory > mock quando o comportamento importa.
- **Integration**: repositório contra banco real. **Mockar o `PrismaClient` produz teste que passa com código quebrado** — se a query está errada, o mock não sabe.
- **E2E**: `fastify.inject()` (mais rápido e mais fiel que subir socket), banco real.

Antes de prometer teste de integração, verifique se existe infraestrutura para isso (setup de banco, truncate, testcontainers). Config de teste presente não significa infraestrutura presente — um `sample.spec.ts` com `expect(1 + 1).toBe(2)` é placeholder, não suíte.

Determinismo não é opcional: faker com seed, fake timers para data, zero `sleep`, ordem de teste independente. Teste flaky é bug, não é ruído.

## Quando parar

Alguns sinais de que a resposta certa é fazer menos:

- Um `as` no meio da regra de negócio quase sempre significa que o tipo está errado em outro lugar. Corrija lá.
- Se você está escrevendo um tipo condicional que precisa de comentário para ser lido, o custo já passou o benefício.
- Uma abstração criada para um único caso de uso não é extensibilidade, é indireção — a skill `craft` cobre esse julgamento.
- Interface declarada que ninguém usa no ponto de injeção é decoração, não desacoplamento.
- Se a mudança exige tocar todas as camadas de uma vez, isso pode ser normal: camadas finas são assim de propósito. Não é, por si só, sinal de que algo está errado.
