# Fastify 5 em produção com TypeScript

Decisões em Fastify 5 + TypeScript 5.8 strict + zod 4 + `fastify-type-provider-zod` + `@fastify/swagger` + pino 9. Abra ao criar/alterar rotas, hooks, middlewares, schemas de resposta, tratamento de erro, logging, testes E2E ou config de servidor.

## Modelo mental: encapsulamento e o grafo de plugins

A parte que mais confunde. Fastify **não** é um objeto global mutável: cada `register()` cria um **novo contexto filho**, e o que você declara lá (decorators, hooks, `setErrorHandler`, parsers) **não sobe** para o pai nem vaza para irmãos. Filho herda do pai; o pai nunca enxerga o filho.

```
root  (decorate('db'), setValidatorCompiler, cors)
 ├── authenticatedContext   (addHook onRequest → auth)   → só as rotas daqui exigem token
 └── publicContext          (decorate('foo'))
      └── grandchild        (decorate('bar'))  ← publicContext NÃO vê 'bar'
```

`fastify-plugin` (`fp`) marca o plugin com `skip-override`: ele passa a rodar **no contexto do pai**, e tudo que registra fica visível para quem o registrou e para os irmãos seguintes.

**Regra de decisão:**
- Use `fp` quando o plugin **existe para expor algo**: `decorate('db', …)`, `decorate('authenticate', …)`, error handler global, content-type parser.
- **Não** use `fp` quando o plugin **agrupa rotas** ou quando o isolamento é a feature: auth em só uma subárvore, `preHandler` que não deve tocar `/health`, prefixos. Envolver rotas em `fp` faz o hook de auth vazar para o app inteiro — é assim que se abre o público por acidente.

Sintoma clássico: “registrei o plugin e `fastify.db` é `undefined`” ⇒ plugin sem `fp`; o decorator nasceu e morreu no contexto filho.

Ordem é grafo, não arquivo: em cada contexto os plugins carregam na ordem de registro e **só então** as rotas; `pluginTimeout` (10s) estoura se um plugin async nunca resolve. Aqui, `FastifyApplication.start()` faz `await this.app.register(this.registerRoutes.bind(this))` — as rotas ficam num contexto filho, por isso `setErrorHandler` precisa estar no root.

## Ciclo de vida da request (ordem real) e o uso de cada hook

```
Request → Routing → onRequest → preParsing → Parsing → preValidation
→ Validation (erro ⇒ 400) → preHandler → Handler
→ preSerialization → onSend → Response → onResponse
                 (qualquer erro ⇒ onError → setErrorHandler)
```

| Hook | Uso real |
|---|---|
| `onRequest` | **Autenticação.** `request.body` ainda é `undefined` — rejeitar token inválido aqui evita parsing/validação. |
| `preParsing` | Transformar o stream de entrada (descompressão custom). Raro. |
| `preValidation` | Mutar `request.body` antes do schema (ex.: `camelCase` ⇄ `snake_case`). |
| `preHandler` | **Autorização** (papel/ownership) — body e params já validados. É onde entram os middlewares deste projeto. |
| `preSerialization` | Envelope/paginação. **Não roda** se o payload for `string`, `Buffer`, `stream` ou `null`. |
| `onSend` | **Headers finais** e payload já serializado (`X-Request-Id`, cache). Último ponto antes do socket. |
| `onError` | **Só log/observabilidade.** `reply.send()` aqui lança exceção. Roda **antes** do `setErrorHandler`. |
| `onResponse` | Métricas/latência (`reply.elapsedTime`). |
| `onTimeout` / `onRequestAbort` | `connectionTimeout` estourou / cliente desconectou. Não dá para responder. |

Hooks de aplicação: `onReady` (antes do listen; não registra rota aqui), `onListen`, `preClose` (para de aceitar; fecha WS/SSE), **`onClose`** (libera recursos — pool do Prisma/pg; filhos fecham antes dos pais), `onRoute` (síncrono; inspecionar/alterar rotas — útil para injetar tags de Swagger), `onRegister` (**não dispara** com `fp`).

Todos encapsulados exceto `onClose`. Arrow function perde o `this` da instância.

## Async vs `done`: escolha um

O `done` **não existe** quando o hook é `async` ou retorna Promise. Chamar os dois — `async (request, reply, done) => { await check(request); done() }` — executa a cadeia de hooks **duas vezes**: bug intermitente, difícil de achar. Em hook async, apenas `await` e retorne.

Para responder **de dentro de um hook async**, chame `reply.send()` e **`return reply`** — sem isso o Fastify não sabe que a cadeia terminou e segue para o handler:

```ts
app.addHook('onRequest', async (request, reply) => {
  if (!request.headers.authorization) {
    return reply.code(401).send({ error: 'Unauthorized' }) // return é obrigatório
  }
})
```

Mesma regra no handler: **ou** `return payload` **ou** `return reply.send(payload)`. Retornar um valor *e* chamar `reply.send()` no mesmo handler async dispara `FST_ERR_REP_ALREADY_SENT`. Para stream em handler async, `return reply.send(stream)` é o único caminho correto.

## Validação e serialização por schema

O `serializerCompiler` é **o maior ganho de performance do Fastify**: com schema de resposta, ele compila um serializador especializado (fast-json-stringify) em vez de `JSON.stringify` genérico. Rota sem `response` schema é rota lenta.

**O efeito colateral que morde:** campo **ausente** no schema de resposta é **silenciosamente removido** do body. Sem erro, sem warning. Você adiciona `phone` ao use case, o teste unitário passa, e a API devolve sem `phone`. Campo que “sumiu misteriosamente” ⇒ olhe o `response` schema antes de qualquer outra coisa.

O mesmo comportamento é a defesa: `password_hash` fora do schema **nunca vaza**, mesmo que o use case devolva a entidade inteira. Trate a lista de campos do response schema como contrato de segurança, não como documentação.

Mantenha `allErrors` desligado (default) em rota quente. `attachValidation: true` move o erro para `request.validationError` em vez de responder 400 sozinho; `schemaErrorFormatter` centraliza a mensagem de validação.

## Type provider com zod: tipagem ponta a ponta

Configurado, `request.body`/`params`/`query` vêm **inferidos do zod** — sem generics manuais e sem `z.infer` espalhado:

```ts
import { serializerCompiler, validatorCompiler, type ZodTypeProvider } from 'fastify-type-provider-zod'

const app = fastify({ logger: false }).withTypeProvider<ZodTypeProvider>()
app.setValidatorCompiler(validatorCompiler)
app.setSerializerCompiler(serializerCompiler)

app.route({
  method: 'POST',
  url: '/api/v1/transactions',
  schema: {
    tags: ['Transactions'],
    description: 'Cria uma transação',
    body: z.object({ amount: z.number().int(), description: z.string().min(1) }),
    response: {
      201: z.object({ id: z.uuid() }).describe('`Created` - Transação criada'),
      ...CommonErrorResponseSchemas
    }
  },
  handler: async (request, reply) => {
    request.body.amount // number — inferido, sem cast
    return reply.code(201).send({ id: created.id })
  }
})
```

`withTypeProvider` retorna uma **nova referência tipada**; guarde-a (é o `FastifyTypedInstance` em `src/main/application/types.ts`). Em plugins, `FastifyPluginAsync` **não propaga** o type provider — use `FastifyPluginAsyncZod`. `z.infer<typeof Schema>` serve para reaproveitar o tipo no domínio; no handler é redundante. `.describe()` vira `description` no OpenAPI.

**Swagger:** `transform: jsonSchemaTransform` converte os zod schemas em OpenAPI, e precisa ser registrado **antes** das rotas — este projeto chama `enableSwagger()` no construtor e registra rotas em `start()`, ordem correta; inverter esvazia a doc sem erro algum.

**Caveat zod 4 / lib v7+:** serialização passou a usar `z.output<T>` em vez de `z.input<T>` — response schema com `.transform()` valida o valor **pós-transform**.

## Erros: um único lugar

`setErrorHandler` é **encapsulado**: dentro de um plugin, só pega os erros daquele contexto. Este projeto define no root (`setErrorHandlingMiddleware`), cobrindo tudo. Mapeie **erro de domínio → status HTTP aqui e em nenhum outro lugar** — controller com `try/catch` escolhendo status espalha a política.

```ts
app.setErrorHandler((error, request, reply) => {
  if (hasZodFastifySchemaValidationErrors(error)) {
    return reply.code(400).send({ error: 'Bad Request', code: 'VALIDATION_ERROR', validations: error.validation })
  }
  if (isResponseSerializationError(error)) {   // bug nosso: resposta não bate com o schema
    request.log.error({ issues: error.cause.issues }, 'response serialization error')
    return reply.code(500).send({ error: 'Internal Server Error' })
  }
  if (error instanceof NotFoundError) return reply.code(404).send({ error: 'Not Found', message: error.message })
  request.log.error({ err: error }, 'unhandled error')
  return reply.code(500).send({ error: 'Internal Server Error' })
})
```

**Nunca vaze no body de erro:** `error.stack`, o objeto original, nomes de tabela, caminho de arquivo, e `error.message` de 5xx desconhecido (pode conter SQL/credencial). Stack vai para o **log**. O `ErrorHandlingMiddleware` atual devolve `error.message` cru — para 5xx isso deve virar mensagem genérica.

Códigos do dia a dia: `FST_ERR_VALIDATION` (400), `FST_ERR_NOT_FOUND` (404), `FST_ERR_CTP_INVALID_MEDIA_TYPE` (415 — cliente sem `Content-Type: application/json`), `FST_ERR_CTP_BODY_TOO_LARGE` (413), `FST_ERR_REP_ALREADY_SENT`. `setNotFoundHandler` também é encapsulado.

## Decorators

```ts
app.decorate('db', prismaClient)          // instância — precisa de fp se vier de plugin
app.decorateRequest('userId', null)       // declara a shape
app.addHook('onRequest', async (req) => { req.userId = decoded.sub })
```

**Nunca coloque objeto/array mutável em `decorateRequest`** — no Fastify 5 isso é bloqueado. O valor seria **compartilhado entre todas as requests**: vazamento de dados entre usuários e memory leak. Declare `null` (ou getter) e preencha no `onRequest`. Declarar antes importa porque V8 otimiza a *shape*; adicionar propriedade depois causa deopt em toda request.

Tipagem via module augmentation — `declare module 'fastify' { interface FastifyRequest { userId?: string } }`, como em `src/main/application/fastify.d.ts`.

## Logging com pino

Em v5, logger customizado vai em **`loggerInstance`** (`logger` só aceita opções — passar instância quebra). `request.log` é um child logger com `reqId` já injetado: **use `request.log`, nunca o logger global**, ou você perde a correlação.

```ts
const app = fastify({
  loggerInstance: pino({ redact: ['req.headers.authorization', 'req.body.password', '*.access_token'] }),
  requestIdHeader: 'x-request-id',   // cuidado: cliente passa a controlar o reqId
  genReqId: () => randomUUID(),
  trustProxy: true
})
```

`redact` é obrigatório: `authorization`, `password`, `refresh_token`, `access_token`. Serializers custom de `req`/`res` **não podem lançar** — se lançarem, o log some. Logar response headers vaza `Set-Cookie`. `disableRequestLogging` aceita função: silencie `/health`.

Este projeto usa `fastify({ logger: false })` com um `ILogger` próprio — aceitável, mas **perde o `reqId` automático**. Mantendo assim, propague um correlation id via `onRequest` + `onSend`.

## Testes: `inject()` vs supertest

`fastify.inject()` (light-my-request) simula a request **sem abrir porta**: sem bind, sem conflito em testes paralelos, sem `listen`/`close`, mais rápido, e passa por **todo** o pipeline (hooks, validação, serialização). É o default certo.

```ts
const response = await app.inject({ method: 'POST', url: '/api/v1/auth/login', payload: { email, password } })
expect(response.statusCode).toBe(200)
expect(response.json().access_token).toBeTypeOf('string')
```

Use **supertest** (com `await app.ready()` + `app.server`) só quando o teste depende de conexão **real**: keep-alive, timeout de socket, upload em stream, HTTP/2, cliente externo. Para E2E de rota — 95% dos casos — `inject` cobre o mesmo e é mais estável.

## Produção

- **Graceful shutdown:** `SIGTERM`/`SIGINT` → `await app.close()` → `preClose` (para de aceitar) → `onClose` (feche Prisma/pg aqui). `return503OnClosing` (default `true`) faz o LB tirar a instância. `forceCloseConnections: 'idle'` (default) fecha só conexões ociosas; `true` mata tudo — necessário em k8s se keep-alive segura o pod.
- **Timeouts:** `keepAliveTimeout` 72s (default) deve ser **maior** que o do proxy/ALB, senão 502 intermitente. `requestTimeout` default `0` (sem limite) — defina (ex.: 120000) se não houver proxy protegendo.
- **`bodyLimit`** default 1 MiB — aumente por rota, nunca global. `maxParamLength` default 100.
- **`trustProxy: true`** atrás de proxy, senão `request.ip` é o IP do LB — quebra rate limit e auditoria.
- **CORS:** allowlist explícita. `origin: true` + `credentials: true` reflete qualquer origem — nunca em produção.
- **`@fastify/helmet`** e **`@fastify/rate-limit`** (inclusive no `/auth/login`, por IP+email).
- **Healthcheck:** sem auth, sem I/O pesado; escute em `0.0.0.0` (default é `localhost` e a readinessProbe do k8s falha).
- **Capacidade:** 2 vCPU/instância para menor latência (GC usa o segundo core); 1 vCPU se o alvo é throughput. RegExp em rota quente é caro.

## v4 → v5: o que realmente pega

- **Node 20+** (aqui: 24 ✓). `logger: pinoInstance` → **`loggerInstance`**.
- `request.routerPath`/`routeConfig`/`context` → **`request.routeOptions`**; `reply.getResponseTime()` → `reply.elapsedTime`; `request.connection` → `request.socket`.
- **`listen(3000)` não existe** → `listen({ port, host })`. `reply.sent = true` → **`reply.hijack()`**.
- **`reply.redirect(code, url)` → `reply.redirect(url, code)`** — argumentos invertidos, troca silenciosa de comportamento.
- **`decorateRequest`/`decorateReply` com objeto/array agora lançam.**
- JSON Schema completo obrigatório (`jsonShortHand` removido) — irrelevante aqui: o zod provider gera o schema.
- Sem `;` como delimitador de querystring; `params` sem prototype → `Object.hasOwn()`.
- `version`/`versioning` → `constraints: { version }`. Plugin não pode misturar callback e Promise.
- HEAD custom deve vir antes do GET (ou `exposeHeadRoutes: false`).

## Armadilhas com consequência real

1. Handler async que retorna valor **e** chama `reply.send()` → `FST_ERR_REP_ALREADY_SENT`.
2. Hook async que também chama `done()` → cadeia executada **duas vezes**.
3. `reply.send()` em hook async **sem `return reply`** → handler roda mesmo assim.
4. Plugin sem `fastify-plugin` → decorator `undefined` no pai.
5. Rotas dentro de `fastify-plugin` → hook de auth vaza para o app inteiro.
6. Campo fora do `response` schema → **removido em silêncio**.
7. `setErrorHandler` dentro de plugin → não pega erro das outras rotas.
8. `reply.send()` em `onError` → exceção.
9. `@fastify/swagger` depois das rotas → doc vazia, sem erro.
10. Logger global em vez de `request.log` → logs sem `reqId`.
