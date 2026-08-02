# Segurança de API e GraphQL

O que muda quando não há navegador nem HTML no meio: sem renderização, sem SOP, sem
`Content-Security-Policy` para salvar você — e um cliente que é, por construção, hostil.
Abra este arquivo ao revisar rota REST, resolver GraphQL, serviço gRPC, handler de webhook,
gateway ou qualquer coisa que fale JSON/Protobuf com o mundo. Para o recorte web/browser
(XSS, CSP, CORS, cookies) veja `references/xss-e-navegador.md`; para IDOR/BOLA e mass
assignment como classe geral, `references/autorizacao-e-logica-de-negocio.md`.

## Índice

- [Por que APIs têm uma lista própria](#por-que-apis-têm-uma-lista-própria)
- [OWASP API Security Top 10 — edição vigente (2023)](#owasp-api-security-top-10--edição-vigente-2023)
- [Validação de entrada em API REST](#validação-de-entrada-em-api-rest)
- [Consumo de recurso e rate limiting](#consumo-de-recurso-e-rate-limiting)
- [Inventário: versionamento, shadow e zombie APIs](#inventário-versionamento-shadow-e-zombie-apis)
- [Autenticação e transporte em API](#autenticação-e-transporte-em-api)
- [Webhooks nos dois sentidos](#webhooks-nos-dois-sentidos)
- [GraphQL](#graphql)
- [gRPC e Protobuf](#grpc-e-protobuf)
- [WebSocket e SSE](#websocket-e-sse)
- [Respostas e vazamento](#respostas-e-vazamento)
- [Sinais em revisão de código](#sinais-em-revisão-de-código)
- [Falsos positivos comuns](#falsos-positivos-comuns)
- [Fontes](#fontes)

## Por que APIs têm uma lista própria

O OWASP Top 10 web (edição vigente **2025**, publicada em 6 de novembro de 2025) organiza risco
em torno de *o que o servidor faz com o dado* — injeção, misconfiguration, cripto. O OWASP API
Security Top 10 existe separado desde 2019 porque, em API, três premissas do modelo web caem:

1. **O cliente não é confiável por construção.** Numa aplicação server-rendered você controla o
   HTML que o usuário recebe; se o botão "excluir" não aparece, a maioria dos usuários não o
   chama. Numa API, o cliente é um SPA, um app mobile ou um `curl` — o contrato inteiro está
   publicado (OpenAPI, bundle JS, tráfego do app). Toda checagem client-side é decoração. A
   consequência prática é que **lógica de autorização que na web ficava implícita na navegação
   vira obrigação explícita em cada endpoint**.
2. **Não há renderização.** Sem HTML no meio, XSS refletido praticamente some (o `Content-Type:
   application/json` + `X-Content-Type-Options: nosniff` fecha o vetor), CSRF fica restrito aos
   casos em que o parser aceita content-type simples, e clickjacking é irrelevante. O peso migra
   inteiro para autorização, exposição de dado e consumo de recurso.
3. **A superfície é orientada a objeto/recurso.** `GET /orders/{id}` expõe um identificador por
   design. A superfície de ataque de uma API é o produto cartesiano
   *(recurso × identificador × propriedade × método × versão)*, e cada célula precisa de uma
   decisão de autorização. É por isso que **6 das 10 categorias de 2023 são, na raiz, falha de
   autorização ou de restrição de uso** — nada disso é detectável por WAF, porque a requisição é
   sintaticamente perfeita.

O Top 10 web de 2025 reconheceu a convergência: **A01:2025 Broken Access Control** absorveu BOLA,
BFLA, SSRF e escalação de privilégio explicitamente. Continue usando as duas listas — a de API é
mais útil quando você está com o código de um controller na frente.

## OWASP API Security Top 10 — edição vigente (2023)

**Confirmado em agosto de 2026: a edição vigente ainda é a de 2023** (publicada em 5 de junho de
2023). Não há edição 2025/2026, release candidate nem call for data anunciado na página do
projeto. Use os códigos `APIx:2023` — citar "API1:2019" está desatualizado (a lista de 2019 tinha
"Excessive Data Exposure" e "Mass Assignment" separados; 2023 fundiu os dois em BOPLA e adicionou
SSRF, Unsafe Consumption e Sensitive Business Flows).

| Código | Nome | O que é na prática | Aprofunda em |
|---|---|---|---|
| **API1:2023** | Broken Object Level Authorization (BOLA) | Trocar o ID no path/body/query e receber o objeto de outro tenant. `GET /api/v1/invoices/1042`. É o #1 há três edições e o achado mais pago em bug bounty. | `autorizacao-e-logica-de-negocio.md` |
| **API2:2023** | Broken Authentication | JWT sem verificar assinatura, `alg: none`, token sem `exp`, refresh eterno, reset de senha sem invalidar sessão, credential stuffing sem lockout. | `autenticacao-e-sessao.md` |
| **API3:2023** | Broken Object Property Level Authorization (BOPLA) | Fusão de *excessive data exposure* (a API devolve o objeto inteiro e o front esconde) com *mass assignment* (a API aceita `{"role":"admin"}` no `PATCH`). Autorização no nível de **campo**, não de objeto. | `autorizacao-e-logica-de-negocio.md`, e aqui em [Validação de entrada](#validação-de-entrada-em-api-rest) |
| **API4:2023** | Unrestricted Resource Consumption | Sem rate limit, sem limite de tamanho de body, `?limit=999999`, endpoint que dispara SMS/e-mail/LLM. Custa dinheiro antes de custar disponibilidade. | [aqui](#consumo-de-recurso-e-rate-limiting) |
| **API5:2023** | Broken Function Level Authorization (BFLA) | Chamar `DELETE /api/users/42` sendo usuário comum, ou descobrir `/api/admin/*` trocando o verbo. É autorização por *operação*, não por objeto. | `autorizacao-e-logica-de-negocio.md` |
| **API6:2023** | Unrestricted Access to Sensitive Business Flows | Não é bug de código: é o fluxo de negócio automatizável. Bot comprando todo o estoque de lançamento e revendendo; reservar 90% dos assentos de um voo e cancelar para derrubar o preço; farmar crédito de indicação criando contas. Defesa: fingerprint de dispositivo, detecção de padrão não-humano, captcha, limite por fluxo (não por rota). | [aqui](#consumo-de-recurso-e-rate-limiting) e `threat-modeling-e-severidade.md` |
| **API7:2023** | Server Side Request Forgery | A API busca uma URL fornecida pelo usuário (webhook, importar de URL, avatar remoto, preview de link). | `ssrf-e-camada-http.md` |
| **API8:2023** | Security Misconfiguration | CORS permissivo, TLS fraco, header de debug, verbo não restrito, `Cache-Control` ausente em resposta autenticada, stack trace. | [Respostas e vazamento](#respostas-e-vazamento) |
| **API9:2023** | Improper Inventory Management | `/v1` no ar sem os fixes do `/v2`, host de staging exposto, Swagger público, `/actuator`. | [Inventário](#inventário-versionamento-shadow-e-zombie-apis) |
| **API10:2023** | Unsafe Consumption of APIs | Você confia mais no dado do fornecedor do que no do usuário. Payload de SQLi vindo de um nome de repositório de terceiro; seguir redirect do parceiro cegamente e reenviar o header `Authorization` para o host do atacante. | [aqui](#webhooks-nos-dois-sentidos) e `ssrf-e-camada-http.md` |

Nota sobre API10: o cenário do redirect é o mais subestimado. Se você usa `fetch` (que segue
redirect por padrão, `redirect: 'follow'`) ou `axios` (`maxRedirects: 5`) para chamar um parceiro
e o parceiro responde `301` para o host do atacante, seu cliente HTTP **reenvia o corpo e, em
muitos clientes, os headers** — incluindo o `Authorization` do parceiro. Trate a lista de
destinos de redirect com allowlist; veja `ssrf-e-camada-http.md`.

## Validação de entrada em API REST

### Schema-first, e o schema valendo em runtime

O erro estrutural é ter OpenAPI como documentação e validação como código separado: os dois
divergem em duas sprints. Faça o schema ser a fonte única e a validação derivar dele.

- **Fastify** valida com Ajv a partir do JSON Schema declarado na rota — é o caminho nativo, sem
  dependência extra.
- **Express**: `express-openapi-validator` monta middleware de validação de request *e* response a
  partir do `openapi.yaml`.
- **NestJS**: `ValidationPipe` global + `class-validator`.
- **Zod** com `fastify-type-provider-zod` ou tRPC quando o contrato é interno.

### `additionalProperties: false` / `.strict()` e a relação com mass assignment

Mass assignment (API3:2023) acontece quando o corpo da requisição é copiado para a entidade sem
filtro. A defesa em profundidade tem duas camadas independentes:

```ts
// ❌ vulnerável — o cliente decide quais colunas escrever
app.patch('/me', async (req) => {
  return prisma.user.update({ where: { id: req.user.id }, data: req.body })
})
// PATCH /me {"name":"x","role":"ADMIN","emailVerified":true,"credits":999999}

// ✅ camada 1 — schema fechado: campo desconhecido é erro, não é "ignorado"
const Body = z.strictObject({ name: z.string().min(1).max(80) })
// ✅ camada 2 — allowlist explícita na escrita (nunca espalhe o body)
app.patch('/me', { schema: { body: zodToJsonSchema(Body) } }, async (req) => {
  const { name } = Body.parse(req.body)
  return prisma.user.update({ where: { id: req.user.id }, data: { name } })
})
```

Detalhes que custam caro:

- **Zod 4** (atual) tornou `.strict()`, `.strip()` e `.passthrough()` *deprecated* em favor de
  `z.strictObject()` / `z.looseObject()` / `.catchall(z.never())`. O default de `z.object()`
  continua sendo **strip** — ele *remove* a chave desconhecida em silêncio. Silêncio é aceitável
  para o modelo (a chave nunca chega ao Prisma), mas péssimo para detecção: você nunca vê o
  atacante tentando. Prefira `strictObject` em endpoints de escrita.
- **JSON Schema**: `additionalProperties: false` **só enxerga `properties`/`patternProperties`
  do mesmo objeto de schema**. Se você compôs com `allOf` ou `$ref`, ele rejeita as propriedades
  herdadas — e a "correção" comum (remover o `additionalProperties`) reabre o mass assignment. A
  keyword correta em composição é **`unevaluatedProperties: false`** (draft 2019-09+; no Ajv v8
  importe `Ajv2020` de `ajv/dist/2020`).
- **Fastify**: o Ajv default tem **`removeAdditional: true`**, ou seja, com
  `additionalProperties: false` no schema ele *remove* o campo extra em vez de rejeitar. Se você
  quer 400, defina `removeAdditional: false` em `ajv.customOptions` ou use
  `additionalProperties: false` com `removeAdditional: 'failing'`/`false`.
- **NestJS**: `new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true })`.
  Só `whitelist: true` **remove em silêncio**; `forbidNonWhitelisted: true` devolve 400. E
  atenção: `whitelist` remove tudo que não tem *decorator de validação* — um campo com
  `@IsOptional()` mas sem decorator de tipo pode ser removido sem você perceber.
- **Prisma**: `data: req.body` é o sink. Regra de revisão: em `create`/`update`, o objeto `data`
  deve ser literal com chaves escritas à mão, nunca spread do input.

### Coerção de tipo perigosa

`coerceTypes` transforma `"1"` em `1`, `"true"` em `true`, `"0"` em `false`. Isso é conveniente
para query string e desastroso quando o valor decide autorização.

```ts
// Fastify default: ajv com coerceTypes: 'array'
// schema { isAdmin: { type: 'boolean' } } aceita "false" (string) → false  ✅
// mas schema { userId: { type: 'string' } } com body {"userId": {"$ne": null}} …
```

Os casos concretos:

- **`coerceTypes` + comparação frouxa**: se o schema diz `type: 'number'` e o handler faz
  `if (body.tenantId !== user.tenantId)`, um `"42"` coagido para `42` compara certo; sem coerção,
  `"42" !== 42` passa. Ambos os lados quebram — o ponto é que **a validação e a comparação têm
  que concordar sobre o tipo**. Valide para o tipo final e compare com `===` sobre o tipo final.
- **NoSQL operator injection**: `type: 'string'` no schema barra `{"$ne": null}`, mas só se você
  *tiver* schema. Em Express + `express.json()` sem validação, `req.body.password` pode ser um
  objeto. Veja `injecao.md`.
- **Array vs escalar**: Fastify usa `coerceTypes: 'array'` por padrão — `?tag=a` vira `['a']`
  quando o schema pede array. O inverso (array onde se espera escalar) é o clássico
  `?id=1&id=2` virando `['1','2']` e quebrando um `parseInt` ou passando por um `includes`.
- **`useDefaults: true`** (default do Fastify) preenche campos ausentes com o `default` do schema.
  Se um campo de permissão tem `default`, um cliente que omite o campo recebe o default — verifique
  que nenhum `default` conceda privilégio.

### Limites: body, profundidade, array, string

Sem limite explícito, o parser JSON é um amplificador de CPU/memória barato de acionar.

| Limite | Default | Onde ajustar |
|---|---|---|
| Tamanho do body | Fastify: **1 MiB** (`bodyLimit`); Express `express.json()`: **100 kb** (`limit`) | por rota em Fastify (`{ bodyLimit }`), por middleware em Express |
| Profundidade de JSON | **nenhum** em `JSON.parse` nativo | valide com `depthLimit` no Ajv (`maxItems`/`maxProperties` não cobrem profundidade) ou parser com limite (`secure-json-parse`, `json-bigint` com opções) |
| Tamanho de array | nenhum | `maxItems` no JSON Schema / `.max(n)` no Zod — **sempre**, inclusive em arrays de IDs de um endpoint batch |
| Tamanho de string | nenhum | `maxLength` / `.max(n)`. Uma string de 900 kB dentro do body de 1 MiB passa e vira índice, log e coluna |
| Nº de propriedades | nenhum | `maxProperties` |
| Multipart | `@fastify/multipart`: configure `limits.fileSize`, `limits.files`, `limits.fields` | — |

O `allErrors: false` do Fastify é **deliberadamente** o default por segurança: `allErrors: true`
no Ajv permite DoS por schema com muitas branches. Não ligue globalmente.

### `Content-Type` e parser que aceita mais do que devia

- Rejeite content-type inesperado com **415 Unsupported Media Type** (ou 406 quando o problema é
  `Accept`). Em Express, `express.json()` só parseia `application/json` por padrão — mas muita
  gente escreve `express.json({ type: '*/*' })` e reabre CSRF (um `<form>` HTML só consegue enviar
  `application/x-www-form-urlencoded`, `multipart/form-data` ou `text/plain`; se o seu parser
  aceita esses como JSON, o endpoint volta a ser CSRF-able).
- `application/json; charset=utf-7`, `application/json;;`, `application/JSON` — parsers diferem em
  como normalizam. Se o gateway roteia por content-type e o backend parseia por sniffing, há
  divergência explorável.
- **`X-HTTP-Method-Override`** (e `X-Method-Override`, `X-HTTP-Method`, `?_method=DELETE`): o
  cliente manda `POST` e o framework interpreta `DELETE`. Se o gateway aplica política por verbo e
  o backend honra o override, a política é bypassada. Caso real documentado: GHSA-6qmp-9p95-fc5f
  no Google Cloud Endpoints ESPv2 — bypass de autenticação JWT via `X-HTTP-Method-Override`.
  **Desabilite method override** salvo necessidade comprovada, e se precisar, aplique-o *antes*
  da camada de autorização.

### Divergência de parser: chave duplicada e unicode

`{"role":"user","role":"admin"}` é JSON sintaticamente válido e a RFC 8259 não define o
comportamento. A pesquisa da Bishop Fox ("An Exploration of JSON Interoperability
Vulnerabilities") testou 49 parsers: a maioria fica com a **última** ocorrência, mas sete ficam
com a **primeira** — entre eles `jsonparser` e `gojay` (Go), `rapidjson` (C++) e `json-iterator`
(Java). `JSON.parse` do V8 fica com a última.

O ataque é sempre o mesmo: **duas camadas, dois parsers**. O gateway/WAF/serviço de autorização
lê a primeira chave e vê `user`; o serviço de negócio lê a última e vê `admin`. Também vale para
truncamento de número (`1e1000` → `Infinity` em JS, erro em outros), inteiros grandes
(`9007199254740993` perde precisão em JS) e comentários/trailing commas aceitos por parsers
tolerantes (`JSON5`, `serde_json` com feature).

Regra de revisão: **um único ponto de parse, o mais cedo possível, e reserialize** antes de
repassar entre serviços. Se o gateway toma decisão sobre o corpo, ele tem que ser o parser
canônico e reemitir o JSON normalizado.

Unicode: normalize com **NFKC antes de validar**, não depois. `U+212A KELVIN SIGN` normaliza para
`K`; `U+FF07 FULLWIDTH APOSTROPHE` para `'`; a ligatura `U+FB01 ﬁ` para `fi`. Validar antes e
normalizar depois é o padrão que gera bypass de filtro (CERT IDS01-J). Em identificadores
(username, e-mail, nome de arquivo), normalize **e** rejeite o que mudar na normalização, para não
criar dois "admin" diferentes que colidem no banco.

### Validar na borda e esquecer o serviço interno

O erro mais comum em arquitetura de microserviço: o gateway valida o schema, e o serviço interno
assume que o dado chegou validado. Isso quebra em três situações previsíveis — chamada
serviço-a-serviço que não passa pelo gateway, fila/evento que entra por outro caminho, e job que
lê do banco dado gravado por versão anterior do schema. **Valide de novo na fronteira do serviço.**
O custo é um `parse()` por request; o benefício é que a garantia deixa de depender da topologia
de rede.

Corolário para autorização: gateway pode negar cedo, mas a decisão autoritativa fica no serviço.
Ver a seção de [inventário](#inventário-versionamento-shadow-e-zombie-apis) sobre bypass de
gateway por normalização de path.

## Consumo de recurso e rate limiting

API4:2023. Trate como **duas** propriedades separadas: disponibilidade (o serviço cai) e custo (a
fatura sobe). A segunda tem virado a mais explorada, porque não precisa derrubar nada.

### Algoritmos e onde cada um serve

| Algoritmo | Estado por chave | Comportamento | Quando usar |
|---|---|---|---|
| Fixed window | contador + timestamp da janela | Simples; permite **2× o limite na virada da janela** (burst de borda) | quase nunca; só onde a precisão não importa |
| Sliding window log | sorted set com timestamp de cada request | Exato; memória O(requests) | limites baixos e caros (ex.: 5 tentativas de OTP/hora) |
| Sliding window counter | dois contadores + interpolação | Boa aproximação, memória O(1) | **default para API pública** |
| Token bucket | tokens + timestamp do último refill | Permite burst controlado (`burst`) com taxa média (`rate`) | clientes legítimos com tráfego em rajada (app que sincroniza no cold start) |
| Leaky bucket / GCRA | **um único timestamp** (TAT) | Mesmas propriedades do token bucket, mas com um número só — sem contador para incrementar atomicamente, o que o torna elegante em Redis (`go-redis/redis_rate` implementa GCRA em um script Lua) | rate limit distribuído de alto volume |

### Onde aplicar

Rate limit por IP sozinho não serve para nada em API: NAT corporativo compartilha IP entre
milhares de usuários legítimos e o atacante compra IPv4 residencial rotativo por dólares. Aplique
em camadas, e sempre pelo identificador mais forte disponível:

- **por credencial** (`user_id`, `api_key`, `client_id`) — a que importa;
- **por IP** — só como rede de proteção para tráfego não autenticado (login, signup, reset);
- **por rota** — porque `POST /reports/export` não pode ter o mesmo orçamento que `GET /health`;
- **por custo** — atribua um peso a cada endpoint e debite do mesmo bucket. É o modelo do GitHub
  GraphQL API (pontos por query) e a única forma sã quando um endpoint custa 1000× outro;
- **por fluxo de negócio** (API6:2023) — "N compras do mesmo SKU por conta por hora", "N convites
  por dia". Não é rate limit de HTTP, é regra de domínio.

### O que quase sempre fica sem limite

1. **Endpoints caros**: export de relatório, busca full-text, agregação, geração de PDF, `GET /me/
   activity?range=all`. Ponha timeout **e** limite de concorrência por usuário (semáforo), não só
   requests por minuto — 5 exports simultâneos de 2 minutos cada é pior que 300 requests rápidos.
2. **Endpoints que disparam custo externo**: envio de SMS/e-mail/push (custo por unidade, e é o
   vetor de *SMS pumping* / IRSF, onde o atacante lucra com o revenue share do número premium
   para o qual força o envio), verificação de telefone, e **chamada a LLM** — o pior caso, porque
   o custo por request é variável e controlado pelo input do atacante. Veja `llm-e-ia.md` para
   limite de token, de contexto e de ferramenta.
3. **Upload**: limite tamanho, número de arquivos por request, e requests de upload por período.
   Presigned URL (S3) não tem rate limit por si — limite a *emissão* do presign.
4. **Paginação sem teto**: `?limit=999999`, `?per_page=100000`, `?pageSize=-1`. Sempre
   `Math.min(Number(limit) || 20, 100)` e valide como inteiro positivo no schema. Offset alto
   (`?offset=5000000`) é DoS de banco por si só — prefira cursor.
5. **N+1 explorável**: um endpoint que aceita `?include=orders.items.product.reviews.author` e
   monta o join dinamicamente. Cada nível multiplica queries. Allowlist de `include` e
   profundidade máxima.
6. **Batch endpoints**: `POST /users/bulk` com array sem `maxItems` é o mesmo problema, explícito.

### Distribuído — por que o contador em memória não vale nada

`express-rate-limit` usa `MemoryStore` por padrão, e a própria documentação avisa: com N
instâncias, o limite efetivo é **entre `max` e `max × N`**. Três pods com `max: 100` deixam passar
até 300. Pior: com autoscaling, o atacante *aumenta* o próprio limite ao gerar carga. Em `node:
cluster`, `cluster-memory-store`; em produção multi-instância, `rate-limit-redis` (ou
`@fastify/rate-limit` com `redis`). Verifique também o prefixo de chave — dois serviços diferentes
compartilhando prefixo no mesmo Redis se limitam mutuamente.

Cuidado com o identificador de IP atrás de proxy: sem `trust proxy` configurado corretamente,
todos os requests chegam com o IP do load balancer e o rate limiter vira um único bucket global.
Com `trust proxy: true` (confiando em qualquer `X-Forwarded-For`), o atacante **escolhe** o
próprio bucket mandando `X-Forwarded-For: <aleatório>`. Configure o número exato de hops
confiáveis.

### Retry amplification e thundering herd

Quando o backend degrada, clientes com retry automático multiplicam a carga no pior momento —
3 retries por request transformam uma queda de 30% em 4× a carga. As defesas:

- **backoff exponencial com jitter completo** (`sleep = random(0, min(cap, base * 2^n))`); backoff
  sem jitter só sincroniza os clientes;
- **retry budget / circuit breaker**: só permita retry enquanto a proporção retry/request estiver
  abaixo de ~10%;
- **`Retry-After`** na resposta 429/503 e clientes que o honram;
- **não faça retry de erro não idempotente** sem `Idempotency-Key`;
- **cache com `stale-while-revalidate` e single-flight** (uma única chamada ao origin por chave em
  voo) para evitar cache stampede.

### Cabeçalhos `RateLimit-*`

O padrão IETF **ainda é Internet-Draft, não RFC**: `draft-ietf-httpapi-ratelimit-headers-11`,
de 23 de maio de 2026 (WG HTTPAPI). Ele define **dois** campos, ambos Structured Fields:

```http
RateLimit-Policy: "burst";q=100;w=60, "daily";q=1000;w=86400
RateLimit: "burst";r=42;t=17
```

- `RateLimit-Policy` — a política: `q` = quota (obrigatório), `w` = janela em segundos,
  `qu` = unidade da quota (`"requests"` default, também `"content-bytes"`,
  `"concurrent-requests"`), `pk` = chave de partição.
- `RateLimit` — o estado atual: `r` = quota restante (obrigatório), `t` = segundos até a janela
  efetiva terminar, `pk` = chave de partição.
- Convivendo com `Retry-After`, o draft diz que o `Retry-After` **não deve** apontar para um
  instante anterior ao fim da janela efetiva, e o cliente deve priorizar `Retry-After`.

Os headers de-facto ainda dominam (`X-RateLimit-Limit`, `X-RateLimit-Remaining`,
`X-RateLimit-Reset` — GitHub, Stripe e Twitter usam variantes). Emita os dois formatos se você
tem clientes legados; o custo é um header. Ponto de segurança: `RateLimit`/`X-RateLimit-*` em
endpoint **não autenticado** informa ao atacante exatamente quanto orçamento resta — em endpoints
de login/OTP, prefira não expor o restante.

### Proteção de custo (billing DoS / "denial of wallet")

Diferente de DoS: o serviço continua no ar, e a fatura é que quebra. Arquiteturas serverless e
pay-per-use são o alvo natural, porque o autoscaling absorve a carga e cobra por ela. Controles:

- **limite de concorrência** na função (AWS Lambda *reserved concurrency*) — é o único teto real;
  rate limit no gateway ainda cobra pelo gateway;
- **AWS Budgets + alarme de anomalia de custo**, com ação automática (desabilitar chave, reduzir
  concorrência) e não só e-mail;
- **quota por chave de API no gateway** (API Gateway usage plans, Cloudflare/Kong);
- **cap de gasto no provedor de LLM/SMS** por projeto e por chave;
- **CDN/WAF na frente** para absorver tráfego volumétrico antes do compute cobrado;
- alarme em **egress** (transferência de dados costuma ser a linha mais cara de um scraping).

## Inventário: versionamento, shadow e zombie APIs

API9:2023. O padrão é sempre o mesmo: **o fix foi para onde o time olha, e o atacante olha para
onde ninguém olha.**

- **Zombie API**: `/api/v1/users` continuou no ar depois do `/v2` — com o BOLA que o `v2`
  corrigiu. Ninguém removeu porque "algum cliente antigo pode usar". Meça: se o endpoint não tem
  tráfego há 90 dias, desligue; se tem, descubra de quem e migre com prazo.
- **Shadow API**: endpoint que existe no código e não existe no OpenAPI/gateway — feature flag,
  endpoint de debug, rota interna que o roteador expõe. Se o inventário vem só do spec, ele é uma
  lista de desejos.
- **Ambiente**: `api-staging.exemplo.com`, `api.dev.exemplo.com`, `*.internal` com DNS público.
  Staging costuma ter dado de produção anonimizado *mal* e autenticação relaxada. Certificate
  Transparency (crt.sh) entrega todos os subdomínios que já receberam certificado — o atacante não
  precisa adivinhar.

### O que procurar (também no próprio código)

| Caminho | O que vaza |
|---|---|
| `/swagger-ui.html`, `/swagger/index.html`, `/openapi.json`, `/v3/api-docs`, `/api-docs`, `/redoc` | O contrato inteiro, incluindo endpoints internos |
| `/graphql`, `/graphiql`, `/playground`, `/altair` | Schema completo via introspection; ver [GraphQL](#graphql) |
| `/actuator`, `/actuator/env`, `/actuator/heapdump`, `/actuator/mappings` | Spring Boot: `env` devolve variáveis de ambiente (credencial de banco, token de cloud); `heapdump` devolve um dump binário da JVM com segredo em texto claro na memória. Foi assim que um serviço de telemática da Volkswagen vazou credencial de cloud e ~9 TB de dados de GPS |
| `/debug/pprof/` | Go: perfil, goroutines, e `/debug/pprof/cmdline` com argumentos |
| `/.env`, `/.git/config`, `/.git/HEAD`, `/config.json`, `/.aws/credentials` | Segredo direto; `/.git` permite reconstruir o repositório inteiro |
| `/metrics` (Prometheus) | Nomes de rota internos, contagem por tenant, versão |
| `/health` verboso | Versão de dependência, host de banco, feature flags |
| `/.well-known/*` fora do previsto | Configuração de OIDC de ambiente errado |

### Como inventariar de verdade

Quatro fontes, e a interseção é onde mora o problema:

1. **Spec** (`openapi.yaml` no repositório) — o que deveria existir.
2. **Gateway/mesh** — o que está roteado.
3. **Tráfego real** (logs de acesso, traces OpenTelemetry, mirror de tráfego) — o que é chamado.
   Endpoint no tráfego e ausente no spec = shadow. Endpoint no spec sem tráfego = candidato a
   desligar.
4. **Descoberta ativa** — enumeração de subdomínio (Certificate Transparency, DNS bruteforce),
   varredura de path com wordlist, e extração de endpoints do bundle JS do front (é a fonte mais
   produtiva: o SPA cita rotas que o backend nunca documentou; Burp *JS Link Finder*, ou um
   `grep -Eo "'/api/[^'\"]+'"` no bundle).

Em CI, gere a spec a partir do código (`fastify-swagger`, `@nestjs/swagger`) e **falhe o build**
se houver rota registrada sem entrada no spec. Isso mata shadow API na origem.

### Bypass de gateway por normalização de path

Um subtipo de API9 que dá RCE-equivalente sem exploit: o gateway aplica política sobre o path
**cru** e o backend sobre o path **normalizado**, ou vice-versa. Variações que funcionam na
prática:

- `/public/../admin/secrets` (dot-segments resolvidos só no backend);
- `//admin/config` (barra dupla quebra o match exato do gateway);
- `/admin%2fconfig`, `/admin%252fconfig` (encoding simples e duplo);
- `/admin/config;foo=bar` (matrix parameters — GHSA-qcxp-gm7m-4j5v no Quarkus);
- **trailing slash**: reportado em 2026 no AWS API Gateway *HTTP API* — `GET /v1/accounts`
  retornava 401 e `GET /v1/accounts/` retornava 200, porque o match de rota e o Lambda authorizer
  discordavam sobre o path. O REST API tem match mais estrito.

Também aparece em Ory Oathkeeper (GHSA-p224-6x5r-fjpm), heimdall (GHSA-3q34-rx83-r6mq) e SFTPGo
(GHSA-x8qh-7475-c5mp). A lição de revisão: **se a única checagem de autorização está no gateway,
o serviço está a uma discrepância de normalização de ser público.** Repita a decisão no serviço.

## Autenticação e transporte em API

Detalhe de JWT, sessão, MFA e rotação de token está em `autenticacao-e-sessao.md`. Aqui, o que é
específico de API.

### API key vs token vs mTLS

| Mecanismo | Identifica | Revogação | Quando faz sentido |
|---|---|---|---|
| **API key** | a aplicação (não o usuário) | por chave, imediata | integração server-to-server, plano de uso, quota. Guarde **hash** da chave no banco (SHA-256 basta — a chave já tem entropia alta; não precisa de bcrypt), com um prefixo em claro (`sk_live_ab12…`) para identificação e busca |
| **Bearer token (JWT/opaco)** | o usuário/sessão | JWT: só com denylist por `jti` ou TTL curto. Opaco: imediata | acesso de usuário final, SPA, mobile |
| **mTLS** | o processo/host, com chave privada não exportável | por CRL/OCSP ou rotação curta | serviço-a-serviço em rede de confiança zero, parceiro de alto valor, PSD2/open banking |

Regras que evitam a maior parte dos incidentes: chave com **prefixo identificável** (permite
detecção automática em GitHub secret scanning), **escopo mínimo** por chave, **rotação sem
downtime** (aceitar duas chaves válidas durante a janela), e **nunca** logar o valor.

### `Authorization` header, nunca query string

A RFC 6750 §2.3 define o parâmetro `access_token` na URI e diz explicitamente que ele
**SHOULD NOT** ser usado "unless it is impossible to transport the access token in the
Authorization request header field or the HTTP request entity-body", citando "the high likelihood
that the URL containing the access token will be logged". A §5.3 lista onde ele vaza: histórico do
navegador, logs de servidor web e de proxy, estruturas de dados intermediárias.

Some a isso o header **`Referer`**: se a página `https://app.exemplo.com/x?token=abc` carrega um
script, uma imagem ou um link para terceiro, o `Referer` pode levar a URL inteira junto (a
política default moderna é `strict-origin-when-cross-origin`, que corta a query em cross-origin —
mas *não* corta em same-origin, e você não controla o `Referrer-Policy` de todo mundo no caminho).

Onde é inevitável (`EventSource`, `<img>` autenticado, link de download compartilhável): use um
**ticket de uso único e vida curta** em vez do token de sessão. Ver
[WebSocket e SSE](#websocket-e-sse).

### Assinatura de requisição (HMAC e SigV4)

Quando o cliente é um servidor e você quer integridade + autenticidade + anti-replay sem TLS
mútuo, assine a requisição.

**AWS SigV4** é o desenho de referência. Quatro passos:

1. **Canonical request** = `METHOD\nURI\nQueryString\nCanonicalHeaders\nSignedHeaders\nHashedPayload`
   — a canonicalização é o que impede que o proxy reordenar headers quebre a assinatura.
2. **String to sign** = `AWS4-HMAC-SHA256\n<X-Amz-Date>\n<YYYYMMDD/region/service/aws4_request>\n<hex(sha256(canonical request))>`.
3. **Signing key derivada em cadeia**:
   `HMAC(HMAC(HMAC(HMAC("AWS4"+secret, date), region), service), "aws4_request")` — a chave final
   é escopada por dia, região e serviço, então uma assinatura vazada tem alcance limitado.
4. **Signature** no header `Authorization: AWS4-HMAC-SHA256 Credential=…, SignedHeaders=…, Signature=…`.

Anti-replay: o `X-Amz-Date` entra na assinatura; o S3 rejeita com **`RequestTimeTooSkewed`** fora
de **15 minutos** (a documentação geral do IAM fala em 5 minutos para a maioria dos serviços).
`x-amz-content-sha256` é obrigatório no S3 e liga o corpo à assinatura (ou o literal
`UNSIGNED-PAYLOAD`). Presigned URL: máximo de **7 dias** (`--expires-in 604800`) via SDK/CLI, **12
horas** pelo console — e ela morre antes disso se as credenciais temporárias que a assinaram
expirarem.

**SigV4a** é a variante assimétrica (`AWS4-ECDSA-P256-SHA256`): keypair derivado do secret,
credential scope **sem região** e header `X-Amz-Region-Set` (aceita `us-west-*`), para assinatura
válida em múltiplas regiões (Multi-Region Access Points).

Se você for desenhar o seu: assine **método + path + query canônica + hash do corpo + timestamp +
nonce**, com a chave nunca trafegando. Se você não assina o corpo, o atacante troca o corpo. Se
você não assina o path, ele troca o endpoint.

**Anti-replay em geral**: timestamp assinado + janela de tolerância + nonce visto. O nonce só
precisa ser guardado durante a janela — `SET nonce:<v> 1 EX <janela> NX` no Redis, e se o `NX`
falhar, é replay. Janela curta demais gera falso negativo por clock skew (por isso a AWS chama o
erro de `TimeSkewed`); janela longa demais amplia a janela de replay. 5 minutos é o consenso de
mercado (Stripe: 300 s; Slack: 300 s; AWS: 300–900 s). NTP nos dois lados.

## Webhooks nos dois sentidos

### Recebendo webhook

O handler de webhook é um endpoint público que executa efeito colateral com privilégio (marcar
pedido como pago, provisionar conta, deletar recurso). Ele precisa de quatro coisas, nessa ordem:
**assinatura válida**, **recência**, **idempotência**, **processamento assíncrono**.

**Stripe** — header `Stripe-Signature`, lista `k=v` separada por vírgula:

```
Stripe-Signature: t=1492774577,v1=5257a869e7ecebeda32affa62cdca3fa51cad7e77a0e56ff536d0ce8e108d8bd
```

- `t` = timestamp Unix; `v1` = HMAC-SHA256 hex. Podem vir múltiplos `v1` (durante rotação de
  secret) — aceite se **qualquer um** bater. `v0` aparece em eventos de teste e é uma assinatura
  falsa de propósito.
- **`signed_payload = t + "." + raw_body`**, com o *signing secret* do endpoint (prefixo `whsec_`)
  como chave HMAC.
- Tolerância default de **300 segundos** nas bibliotecas oficiais
  (`DEFAULT_TOLERANCE: 300` no `stripe-node`); parâmetro `tolerance`, quarto argumento de
  `constructEvent(payload, header, secret, tolerance?)`. A doc avisa explicitamente para **não
  usar tolerância `0`** — isso desliga a checagem de recência.
- Em agosto de 2026, `v1` (HMAC-SHA256) segue sendo o único esquema válido em produção; o formato
  `k=v` existe justamente para permitir novos esquemas sem quebrar clientes.

**GitHub** — headers `X-Hub-Signature-256` (HMAC-SHA256, prefixo `sha256=`),
`X-Hub-Signature` (SHA-1, legado, não use), `X-GitHub-Delivery` (GUID do envio),
`X-GitHub-Event`, `X-GitHub-Hook-ID`, `User-Agent: GitHub-Hookshot/…`. **Não há timestamp
assinado**: a recomendação oficial contra replay é deduplicar pelo `X-GitHub-Delivery` (note que
uma *redelivery* manual mantém o GUID original). A doc é explícita: *"Never use a plain `==`
operator. Instead consider using a method like `secure_compare` or `crypto.timingSafeEqual`"*.
GitHub também espera resposta 2XX em até **10 segundos** e publica os IPs de origem em
`GET /meta` (campo `hooks`) para allowlist.

**O erro clássico: validar depois do parse.** A assinatura cobre os *bytes exatos* que o
provedor enviou. Se o body-parser já converteu para objeto, `JSON.stringify(req.body)` não
reproduz esses bytes — a ordem das chaves pode mudar, whitespace some, `1.0` vira `1`, unicode
escapado (`é`) vira o caractere. A verificação passa a falhar de forma intermitente e
alguém "resolve" desligando a verificação.

```ts
// ❌ vulnerável — reserializa e/ou compara em tempo variável
app.post('/webhooks/stripe', async (req, reply) => {
  const sig = req.headers['stripe-signature'] as string
  const expected = crypto.createHmac('sha256', secret)
    .update(JSON.stringify(req.body))          // bytes ≠ bytes originais
    .digest('hex')
  if (sig.split('v1=')[1] !== expected) return reply.code(400).send()  // == em string
  await provisionar(req.body)                  // síncrono, sem idempotência
})

// ✅ correto — raw body, tempo constante, recência, idempotência, async
app.addContentTypeParser('application/json', { parseAs: 'buffer' }, (_req, body, done) =>
  done(null, body))                            // guarda o Buffer cru

app.post('/webhooks/stripe', async (req, reply) => {
  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(     // faz timestamp + HMAC + timingSafeEqual
      req.body as Buffer,
      req.headers['stripe-signature'] as string,
      process.env.STRIPE_WEBHOOK_SECRET!,
    )                                           // tolerance default = 300 s
  } catch {
    return reply.code(400).send({ error: 'invalid signature' })
  }
  // idempotência: event.id é estável entre retries
  const inserted = await prisma.webhookEvent.createMany({
    data: { id: event.id, type: event.type }, skipDuplicates: true,
  })
  if (inserted.count === 0) return reply.code(200).send()   // já processado
  await fila.enqueue(event)                                  // responde rápido, processa fora
  return reply.code(200).send()
})
```

Em Express, o equivalente é `express.raw({ type: 'application/json' })` **apenas nessa rota**,
montada **antes** do `express.json()` global.

Comparação em tempo constante em Node: `crypto.timingSafeEqual(a, b)` aceita
`Buffer`/`TypedArray`/`DataView`/`ArrayBuffer` — **não aceita string** — e **lança
`RangeError` (`ERR_CRYPTO_TIMING_SAFE_EQUAL_LENGTH`) se os byte lengths diferem**. O padrão
correto é comparar digests, que têm tamanho fixo:

```ts
function verify(raw: Buffer, header: string, secret: string): boolean {
  const expected = crypto.createHmac('sha256', secret).update(raw).digest()  // 32 bytes
  const received = Buffer.from(header.replace(/^sha256=/, ''), 'hex')
  if (received.length !== expected.length) return false   // tamanho de digest não é segredo
  return crypto.timingSafeEqual(expected, received)
}
```

Outros pontos do handler:

- **Não confie no conteúdo do evento para valores críticos.** Mesmo com assinatura válida, o
  padrão robusto é usar o evento como *gatilho* e reconsultar a API do provedor
  (`stripe.checkout.sessions.retrieve(id)`) antes de liberar valor. Isso elimina uma classe
  inteira de bug em que o payload é confiável mas está desatualizado (ordem de entrega não é
  garantida).
- **Idempotência é obrigatória**, não opcional: todo provedor sério faz retry (Stripe reenvia com
  backoff por até ~3 dias). Chave: o ID do evento, com `UNIQUE` no banco — não um `SELECT` antes
  do `INSERT`, que corre com o retry concorrente.
- **Rate limit e tamanho** valem no webhook também: é um endpoint público.
- **Um secret por endpoint e por ambiente.** Secret de staging aceito em produção é bypass total.

### Enviando webhook (o lado que vira SSRF)

Se o seu produto deixa o cliente cadastrar uma URL de callback, você construiu um proxy HTTP
autenticado dentro da sua VPC. Isto é API7:2023 por design. Tratamento completo em
`ssrf-e-camada-http.md`; o resumo operacional:

- **Bloqueie destinos internos**: `127.0.0.0/8`, `0.0.0.0/8`, `::1/128`, RFC 1918
  (`10/8`, `172.16/12`, `192.168/16`), link-local `169.254.0.0/16` — em especial
  **`169.254.169.254`** (metadata de AWS/GCP/Azure) e `fd00::/8`, `ff00::/8`.
- **Resolva o DNS uma vez, valide todos os A/AAAA, e conecte no IP validado** (pinning via
  `lookup` customizado no agent do Node). Validar o hostname e depois deixar o cliente HTTP
  resolver de novo é uma janela de **DNS rebinding/TOCTOU**: o mesmo nome resolve para IP público
  na validação e para `169.254.169.254` na conexão.
- **Desligue ou limite redirects** e revalide cada destino — seguir redirect é o bypass mais comum
  de allowlist.
- **Exija HTTPS** e porta 443 (ou allowlist explícita de portas).
- **Timeouts curtos** de connect e read, **limite de bytes lidos** da resposta, e **nada de
  devolver o corpo/status da resposta ao usuário** — se você devolve, virou SSRF cego → SSRF com
  saída.
- **Egress segregado**: rode o worker de entrega em subnet sem rota para a rede interna. É a única
  defesa que sobrevive a um bypass de validação.
- **Assine o que você envia** (HMAC com secret por endpoint, timestamp no material assinado) e
  **publique seus IPs de origem** para o cliente fazer allowlist — é o que Stripe
  (`https://stripe.com/files/ips/ips_webhooks.json`) e GitHub (`GET /meta`) fazem.
- **Retry com backoff e teto**, mais desativação automática de endpoint que falha por muito tempo
  — senão o seu sistema de webhook vira um canhão de DDoS apontado para o cliente.

### Idempotency-Key

O draft IETF `draft-ietf-httpapi-idempotency-key-header` (versão **-07, de 2025-10-15**) está
**expirado e arquivado**, sem RFC. Na prática o padrão de facto é o da Stripe: header
`Idempotency-Key` (até 255 caracteres, UUID v4 recomendado), aplicável a **POST** (GET/DELETE já
são idempotentes por definição), que salva status code + corpo da **primeira** resposta —
**inclusive erros 500** — e devolve o mesmo resultado em repetições. Retenção garantida de pelo
menos **24 horas**. Implemente igual: `UNIQUE(idempotency_key, endpoint, user_id)`, com o corpo
da resposta persistido.

## GraphQL

<!-- SEÇÃO-GRAPHQL -->

## gRPC e Protobuf

gRPC herda os problemas de API e adiciona os seus. O que revisar:

**Transporte.** gRPC sobre HTTP/2 sem TLS (`grpc.WithTransportCredentials(insecure.NewCredentials())`
em Go, `grpc.ssl_channel_credentials()` ausente em Python) é comum em ambiente interno e não é
aceitável em rede compartilhada — o protocolo é binário, não criptografado. Para serviço-a-serviço
use **mTLS**: `credentials.NewTLS(&tls.Config{ClientAuth: tls.RequireAndVerifyClientCert, ClientCAs: pool})`.
Certificado curto (≤90 dias) com rotação automática. Um service mesh (Istio/Linkerd) resolve isso
com sidecar, mas **verifique se o serviço rejeita conexão que não venha do sidecar** — senão o
mTLS é opcional na prática.

**Authn/authz em interceptor, autorização de negócio no handler.** O interceptor unário
(`grpc.UnaryInterceptor`) é o lugar certo para extrair e validar o token de
`metadata.FromIncomingContext(ctx)` e devolver `status.Errorf(codes.Unauthenticated, ...)`. Mas
o interceptor conhece apenas o **nome do método** (`info.FullMethod`) — a decisão sobre *qual
objeto* o chamador pode tocar depende do corpo da mensagem e tem que ficar no handler. Repete-se
aqui o erro do gateway REST: proteger o método não protege o objeto.

Erros: `codes.Unauthenticated` (16) para credencial ausente/inválida, `codes.PermissionDenied` (7)
para autenticado mas sem permissão. Trocá-los vaza existência de recurso.

**Reflection em produção.** `reflection.Register(s)` publica o `.proto` inteiro em runtime —
serviços, métodos, tipos de mensagem, campos. Para um atacante, é a fase de reconhecimento inteira
resolvida: `grpcurl -plaintext host:50051 list` e ele tem o contrato. Registre condicionalmente:

```go
// ❌ vulnerável
reflection.Register(s)

// ✅ correto
if os.Getenv("ENVIRONMENT") != "production" {
    reflection.Register(s)
}
```

Desabilitar reflection não é controle de acesso (o `.proto` pode ter vazado no repositório ou no
app mobile — veja `mobile.md`), mas remove o caminho fácil.

**Limite de tamanho de mensagem.** O default de recepção é **4 MiB**; o de envio é
`math.MaxInt32` (efetivamente ilimitado) no servidor Go. Ou seja, o default protege o servidor de
mensagem grande do cliente, mas **não** protege o cliente de resposta enorme do servidor —
configure `grpc.MaxCallRecvMsgSize` no cliente. E cuidado com o antipadrão de "resolver" um erro
`ResourceExhausted: received message larger than max` subindo o limite para 100 MB: isso troca um
erro por um DoS. Streaming também precisa de teto — limite número de mensagens e duração da
stream, senão um cliente abre streams e nunca fecha.

**Deadline e cancelamento.** Em gRPC o deadline é propagado pelo `context`. Um servidor que ignora
`ctx.Done()` continua trabalhando depois que o cliente desistiu — é amplificação de DoS grátis.
Passe o `ctx` para toda chamada de banco e HTTP downstream, e **imponha um deadline máximo no
servidor** (`context.WithTimeout`) para o caso de cliente que não define nenhum. Verifique se o
cliente já trouxe deadline antes de sobrescrever.

**grpc-web e o proxy.** Navegador não fala gRPC nativo; é preciso um proxy (Envoy com o filtro
`grpc_web`, ou o proxy do Connect/`connect-go`). Duas consequências: (1) o proxy termina a conexão
e **o backend perde o certificado do cliente** — se autorização depende de mTLS, ela tem que ser
feita no proxy ou o proxy tem que repassar a identidade de forma assinada
(`x-forwarded-client-cert`, e o backend precisa confiar só no proxy); (2) volta a valer tudo de
navegador — CORS, cookie, CSRF. Um endpoint grpc-web que aceita `POST` com
`Content-Type: application/grpc-web-text` está fora dos content-types "simples" e portanto não é
CSRF-able por formulário, mas confirme que o proxy não aceita `text/plain`.

**Protobuf.** A serialização não valida semântica: em proto3 todo campo escalar tem valor default
(`0`, `""`, `false`) e não há como distinguir "ausente" de "zero" sem `optional` (reintroduzido em
proto3 a partir do protoc 3.15). Isso gera bug de autorização real — `if req.TenantId != ""` vira
a única checagem possível. Use `optional` ou wrappers, e valide com `protoc-gen-validate` /
`protovalidate` (`[(buf.validate.field).string.uuid = true]`). Campo desconhecido é preservado por
padrão no proto3 desde 3.5 — o que significa que dado não declarado atravessa o seu serviço para o
próximo; não é vulnerabilidade por si, mas invalida a intuição de "o schema filtra".

## WebSocket e SSE

### Autenticação no handshake

O handshake WebSocket é uma requisição HTTP normal (`GET` com `Upgrade: websocket`), então
**cookies são enviados automaticamente**. O problema: a API `WebSocket` do navegador **não
permite definir headers customizados** — não existe forma de mandar `Authorization: Bearer …`
a partir do `new WebSocket(url)`. As saídas, em ordem de preferência:

1. **Ticket de uso único.** O cliente, já autenticado por HTTP normal, chama
   `POST /ws/ticket` e recebe um token opaco de vida curta (30–60 s), uso único, ligado ao
   `user_id` e ao IP/UA. Conecta em `wss://…/ws?ticket=…`. O servidor troca o ticket por sessão e
   o invalida. Vaza em log? Sim — mas expira antes de ser útil e não é o token de sessão. **É a
   opção recomendada.**
2. **Cookie + verificação obrigatória de `Origin`.** Funciona, mas exige a defesa de CSWSH abaixo.
3. **Primeira mensagem de autenticação** depois do `open`: o servidor aceita a conexão sem
   identidade, exige uma mensagem `{type:"auth",token:…}` em até N segundos e derruba se não vier.
   Simples, mas cria uma janela em que conexões não autenticadas consomem recurso — limite o
   número delas por IP.
4. **`Sec-WebSocket-Protocol` como carona** — o Kubernetes faz isso: subprotocolo
   `base64url.bearer.authorization.k8s.io.<token em base64url sem padding>`. Funciona porque o
   subprotocolo é um dos poucos campos que o navegador deixa você controlar. **Desvantagens
   reais**: não é padronizado para isso, e o valor entra em logs de negociação de protocolo em
   proxies e bibliotecas. Use só quando 1 e 2 não forem viáveis.

**Nunca** coloque o token de sessão de longa duração na query string do `wss://` (mesmos motivos
da RFC 6750 §5.3).

### CSWSH — cross-site WebSocket hijacking

**A Same-Origin Policy não se aplica ao handshake WebSocket.** Qualquer página pode abrir
`new WebSocket('wss://api.exemplo.com/ws')` e o navegador **envia os cookies do alvo**, sem
preflight CORS, sem bloqueio de resposta. Se a autenticação da sua conexão é só o cookie, o site
do atacante fala com a sua API como o usuário logado — e, diferente de CSRF clássico, ele **lê a
resposta**, porque o canal é bidirecional e o SOP não intermedia frames de WebSocket.

O **`Origin`** é a única defesa nativa. O navegador o envia obrigatoriamente no handshake e a
página não consegue forjá-lo. Então:

```ts
// ❌ vulnerável — ws não valida Origin por padrão
const wss = new WebSocketServer({ server })

// ✅ correto — allowlist explícita, e rejeitar Origin ausente/null
const ALLOWED = new Set(['https://app.exemplo.com'])
const wss = new WebSocketServer({
  server,
  verifyClient: ({ origin, req }, done) => {
    if (!origin || !ALLOWED.has(origin)) return done(false, 403, 'Forbidden')
    // + validar a sessão do cookie/ticket aqui
    return done(true)
  },
})
```

Cuidados no check: comparação **exata** de string (não `startsWith` — `https://app.exemplo.com.
atacante.com` passa), rejeitar `Origin` ausente e rejeitar `null` (que vem de iframe sandbox e de
`data:`). Um cliente não-navegador pode forjar `Origin` à vontade — por isso o `Origin` é defesa
contra *o navegador da vítima*, não contra o atacante direto; a autenticação continua sendo
necessária.

Socket.IO tem `cors: { origin: [...] }`, que também governa o handshake do transporte polling.
Deixe explícito; `origin: '*'` com `credentials: true` é o mesmo buraco.

### Autorização por mensagem, depois do handshake

Autenticar no handshake responde "quem é". Não responde "pode fazer isso". Uma conexão aberta
recebe N mensagens ao longo de minutos, e cada uma é uma operação:

```ts
// ❌ vulnerável — autorização só na conexão
ws.on('message', async (raw) => {
  const msg = JSON.parse(raw.toString())
  if (msg.type === 'subscribe') subscribe(ws, msg.channel)   // qualquer canal!
})

// ✅ correto — cada mensagem é uma decisão de autorização
ws.on('message', async (raw) => {
  const msg = Msg.parse(JSON.parse(raw.toString()))          // schema + limite de tamanho
  if (msg.type === 'subscribe') {
    if (!(await canRead(ws.data.userId, msg.channel))) return ws.close(1008, 'forbidden')
    subscribe(ws, msg.channel)
  }
})
```

E lembre da **revogação**: uma conexão aberta sobrevive ao logout, à mudança de senha e à remoção
de permissão. Reavalie a autorização periodicamente (ou ao receber evento de invalidação) e feche
a conexão — senão o "logout de todos os dispositivos" não vale para WebSocket. Se o token tem
`exp`, feche a conexão quando ele expirar.

Outros pontos:

- **Backpressure e DoS**: uma conexão que não lê acumula no buffer de saída do servidor. Monitore
  `ws.bufferedAmount` e feche acima de um teto. Limite mensagens por segundo por conexão,
  tamanho de mensagem (`maxPayload` no `ws`, default 100 MiB — reduza) e número de conexões por
  usuário/IP. WebSocket também não passa por rate limiter HTTP: uma conexão, milhares de
  operações.
- **Compressão** (`permessage-deflate`): consome muita memória por conexão e reintroduz oráculo de
  compressão (família CRIME/BREACH) se você mistura segredo e dado do atacante na mesma mensagem.
  O `ws` a desabilita por padrão — mantenha assim salvo necessidade.
- **Tunelamento**: um WebSocket que aceita `{type:"proxy",url:…}` ou repassa payload para um
  serviço interno é SSRF com sessão persistente. O mesmo vale para o padrão "terminal no browser"
  (`/ws/exec`) — trate como execução remota de comando e autorize por objeto.

### SSE

`EventSource` também **não aceita headers customizados** (issue whatwg/html#2177, sem resolução).
Só `new EventSource(url, { withCredentials: true })` para mandar cookie — o que reintroduz a
necessidade de checar `Origin`/CSRF. Alternativas: `fetch()` com `ReadableStream` (permite
`Authorization`, e é o que os SDKs de LLM usam) ou o mesmo padrão de **ticket** do WebSocket.

Detalhes operacionais que viram incidente:

- Sobre **HTTP/1.1 o navegador limita 6 conexões por origem** — cada aba com um `EventSource`
  consome uma, e a sétima aba trava a aplicação inteira. Sobre HTTP/2 o limite negociado é ~100
  streams. Se a sua API serve SSE, sirva sobre HTTP/2.
- Proxies com buffering (nginx com `proxy_buffering on`) seguram o stream; `X-Accel-Buffering: no`
  desliga no nginx. Isso não é segurança, mas é o motivo de "funciona local e não em produção".
- Conexão longa = **autorização congelada**. Mesmo problema do WebSocket: reavalie e feche.
- `Cache-Control: no-store` na resposta `text/event-stream`, senão um proxy intermediário pode
  guardar o início do stream de um usuário e servir para outro.

## Respostas e vazamento

### Erro em produção

Stack trace numa resposta de API entrega framework, versão, caminho absoluto no disco, nome de
tabela e, com frequência, um trecho de query com valor. É o achado mais comum de qualquer scan e
o insumo mais útil para o próximo passo do atacante.

```ts
// ✅ Fastify — não vaze internals, mas mantenha correlação
app.setErrorHandler((err, req, reply) => {
  req.log.error({ err, reqId: req.id })            // detalhe no log
  const status = err.statusCode ?? 500
  reply.code(status).send(
    status >= 500
      ? { error: 'internal_error', requestId: req.id }   // genérico + id para o suporte
      : { error: err.code ?? 'bad_request', message: err.message },
  )
})
```

Cuidado com o *modo desenvolvimento ligado em produção*: `NODE_ENV` diferente de `production` em
Express faz o handler default imprimir o stack trace na resposta; `DEBUG=True` no Django devolve
uma página com settings e variáveis de ambiente; `app.debug` no Flask expõe o console Werkzeug com
PIN. Cheque a variável de ambiente no deploy, não no código.

Erro de validação também vaza: `"expected number, received string at body.internalRiskScore"`
informa a existência do campo. Devolva os erros de schema com o caminho, mas não com valores nem
com campos que o cliente não deveria conhecer.

### Headers que contam demais

| Header | Problema | Ação |
|---|---|---|
| `X-Powered-By: Express` | versão e stack | `app.disable('x-powered-by')` (Fastify não envia) |
| `Server: nginx/1.24.0` | versão exata → CVE direto | `server_tokens off` |
| `X-AspNet-Version`, `X-AspNetMvc-Version` | idem | remover no `web.config` |
| `X-Debug-*`, `X-Trace-*`, `X-Sql-Query` | interno vazando | remover no gateway |
| `Access-Control-Allow-Origin: *` com `Allow-Credentials: true` | combinação inválida (o navegador rejeita), mas indica config copiada sem entender. Reflexão do `Origin` + credentials **é** exploração real | ver `xss-e-navegador.md` |

`OPTIONS` verboso: um `OPTIONS *` ou `OPTIONS /api/users` que responde
`Allow: GET, POST, PUT, DELETE, PATCH, TRACE` entrega o mapa de verbos. Responda apenas o que a
rota realmente aceita e devolva **405** para verbo não suportado. `TRACE`/`TRACK` habilitados
devem ser desligados no servidor.

### Códigos de status que enumeram

`404` vs `403` é a diferença entre "não existe" e "existe e você não pode". Em recurso cujo
identificador é adivinhável ou sequencial, **responda 404 para ambos os casos** — caso contrário
o atacante enumera IDs válidos sem nunca ler um objeto. O mesmo vale para
`409 Conflict` no cadastro ("e-mail já existe") e para diferença de tempo entre "usuário não
existe" (sem hash de senha) e "senha errada" (com hash) — ver `autenticacao-e-sessao.md`.

O oposto também é problema: devolver `403` onde deveria ser `401` faz o cliente não tentar
renovar o token.

### Cache de resposta autenticada em CDN

O incidente clássico, e ele continua acontecendo. **Caso concreto e recente**: em 30 de março de
2026, entre 10:42 e 11:34 UTC, uma mudança de configuração na Railway habilitou cache em domínios
que tinham CDN desabilitado; respostas `GET` **sem header `Cache-Control` explícito** passaram a
ser cacheadas, e dados autenticados foram servidos a usuários não autenticados em ~0,05% dos
domínios. As respostas que traziam `Cache-Control` foram respeitadas.

A lição é a inversão do default: **muitos CDNs cacheiam `GET` 200 sem `Cache-Control`** (Azure
Front Door, por exemplo, escolhe um TTL aleatório entre 1 e 3 dias nesse caso). Portanto:

- Toda resposta com dado de usuário leva **`Cache-Control: no-store`** — `no-cache` só obriga
  revalidação, o objeto ainda é *armazenado*; `private` é honrado pelo navegador mas depende do
  CDN entender e respeitar.
- `Vary: Authorization, Cookie` como cinto e suspensório (mas não conte com ele: alguns CDNs
  removem `Vary` ou não incluem `Authorization` na cache key).
- Configure a **cache key** no CDN para incluir o cookie de sessão, ou — melhor — sirva API de um
  hostname/behavior com cache desabilitado por padrão.
- Cuidado com *cache deception*: `GET /api/me/profile.css` ou `/api/me/x.js` pode bater numa regra
  de "cachear estáticos por extensão" e gravar a resposta autenticada num path público. Normalize
  o path no origin e recuse extensões em rotas de API.

Em Next.js, atenção especial a Route Handlers e Server Components: dado autenticado precisa de
`export const dynamic = 'force-dynamic'` / `cache: 'no-store'` / `noStore()`, senão vira página
estática compartilhada.

### Paginação e contagem

`{"items":[…],"total":48210}` num endpoint escopado ao tenant é vazamento se `total` for calculado
sem o filtro de tenant — acontece quando alguém otimiza o `COUNT(*)` com uma query separada e
esquece o `WHERE`. Também: contagem total num endpoint de busca permite oráculo binário (refine o
filtro e leia o `total` para inferir existência de registro alheio). Se a contagem não é
necessária para a UI, não devolva; se é, garanta que ela usa exatamente o mesmo predicado da
listagem.

Cursor opaco: se o cursor é `base64(json({offset, tenantId}))`, o cliente edita o `tenantId`.
Assine o cursor ou derive-o só de campos ordenáveis, revalidando o escopo no servidor.

## Sinais em revisão de código

| Sinal (grep / padrão) | Onde | Por que importa |
|---|---|---|
| `data: req.body`, `Object.assign(entity, req.body)`, `{...req.body}` | Prisma/TypeORM/Mongoose | Mass assignment (API3) |
| `z.object(` em rota de escrita sem `strictObject`/`.catchall` | Zod | Campo extra é removido em silêncio — sem sinal de ataque |
| `additionalProperties` ausente em schema de body | Fastify/Ajv/OpenAPI | idem |
| `additionalProperties: false` junto de `allOf`/`$ref` | JSON Schema | Não filtra o que você acha que filtra; use `unevaluatedProperties` |
| `express.json({ type: '*/*' })`, `type: 'text/plain'` | Express | Reabre CSRF em endpoint JSON |
| Ausência de `bodyLimit`/`limit` em rota de upload ou batch | Fastify/Express | API4 |
| `limit`/`pageSize` usado sem `Math.min` ou sem `maximum` no schema | qualquer | `?limit=999999` |
| `findMany(` sem `take` | Prisma | Retorno ilimitado |
| `where: { id }` sem `tenantId`/`userId` no mesmo `where` | Prisma | BOLA — ver `autorizacao-e-logica-de-negocio.md` |
| `app.use(rateLimit(` sem `store:` | express-rate-limit | `MemoryStore` não vale nada multi-instância |
| `trust proxy` ausente ou `= true` | Express | Bucket global, ou bucket escolhido pelo atacante |
| `JSON.stringify(req.body)` dentro de `createHmac` | webhook | Assinatura sobre bytes reserializados |
| `===`/`==`/`!==` comparando assinatura ou token | qualquer | Use `crypto.timingSafeEqual` sobre digests |
| `constructEvent(…, …, …, 0)` | Stripe | Tolerância 0 desliga anti-replay |
| Handler de webhook sem `UNIQUE` no ID do evento | qualquer | Reprocessamento em retry |
| `reflection.Register(` sem guarda de ambiente | Go/gRPC | Schema completo público |
| `insecure.NewCredentials()`, `grpc.WithInsecure()` | Go/gRPC | Sem TLS |
| `grpc.MaxRecvMsgSize(` com valor > 32 MB | Go/gRPC | "Correção" que vira DoS |
| Handler gRPC que não passa `ctx` adiante | Go | Ignora deadline/cancelamento |
| `new WebSocketServer({ server })` sem `verifyClient` | ws | CSWSH |
| `origin.startsWith(`, `origin.includes(` | qualquer | `https://app.exemplo.com.atacante.com` passa |
| `cors: { origin: '*' }` com `credentials: true` | Socket.IO/NestJS | Config copiada sem entender |
| `ws.on('message')` sem checagem de permissão por mensagem | ws | Autorização só no handshake |
| `NODE_ENV` lido para decidir exposição de erro, mas não setado no Dockerfile | qualquer | Stack trace em produção |
| Resposta de dado de usuário sem `Cache-Control` | qualquer | CDN cacheia por default |
| `res.json(user)` devolvendo o objeto do ORM inteiro | qualquer | Excessive data exposure (`passwordHash`, `resetToken`, `internalNotes`) — em Fastify, o `response` schema com `fast-json-stringify` filtra por construção |
| `X-HTTP-Method-Override` honrado | Express `method-override`, Spring | Bypass de política por verbo |
| `redirect: 'follow'` / `maxRedirects` alto em chamada a parceiro | fetch/axios | API10 + SSRF |

Semgrep vale a pena para os padrões estruturais: `p/nodejs`, `p/owasp-top-ten`,
`p/javascript.express.security`, `p/gitlab-eslint` cobrem parte disso; escrever regra própria para
`data: $REQ.body` e para `createHmac(...).update(JSON.stringify(...))` dá retorno imediato porque
são padrões locais e de baixo falso positivo.

## Falsos positivos comuns

- **Endpoint interno sem autenticação atrás de mTLS ou de service mesh com política de
  autorização.** Se o serviço só aceita conexão com certificado de cliente emitido pela CA
  interna, ou se há `AuthorizationPolicy` do Istio negando por padrão, a ausência de token no
  handler não é vulnerabilidade. **Confirme**: a política existe, é `DENY` por padrão, e o pod
  rejeita tráfego que não venha do sidecar.
- **CSRF em endpoint que só aceita `application/json`.** Formulário HTML não consegue produzir
  esse content-type, e `fetch` cross-origin com content-type não-simples dispara preflight, que o
  CORS bloqueia. Não reporte CSRF sem antes verificar que o parser aceita
  `text/plain`/`x-www-form-urlencoded` ou que existe method override.
- **Rate limit ausente em endpoint atrás de gateway que já limita.** Verifique no gateway antes de
  abrir o achado. Vale reportar como *defense in depth* de severidade baixa se o endpoint for
  caro, não como falha.
- **`Math.random()` gerando ID de correlação, nome de arquivo temporário ou jitter de backoff.**
  Só é problema quando o valor é segredo (token, ticket, senha, nonce). Ver
  `criptografia-e-segredos.md`.
- **`GET` sem autenticação em endpoint deliberadamente público** (catálogo, status, healthcheck
  enxuto, `/.well-known/jwks.json`). Confirme que a resposta não muda por usuário.
- **Introspection GraphQL habilitada numa API pública documentada** (ex.: a API pública do GitHub).
  Se o schema já é público, desabilitar não agrega — o esforço deve ir para custo/complexidade e
  autorização.
- **Zod com `.object()` (strip) em endpoint de leitura**, onde o extra não é escrito em lugar
  nenhum. Não é mass assignment; no máximo é falta de sinal para detecção.
- **`403` em vez de `404`** onde a existência do recurso já é pública (ex.: repositório público
  no GitHub). A recomendação de mascarar só vale quando a existência é a informação sensível.
- **Body limit "baixo demais" reportado como DoS**: limite restritivo é a defesa, não a falha. O
  achado só existe se o limite estiver ausente ou absurdo.
- **`X-RateLimit-*` expostos** em API autenticada de parceiro: é feature documentada, não
  vazamento. Só vire achado em endpoint de autenticação/OTP não autenticado.
- **Token em query string na URL de um webhook de saída que *você* cadastrou no parceiro** (o
  parceiro só aceita URL): o risco é real mas mitigado por HTTPS + path secreto rotacionável;
  classifique como baixo e recomende assinatura HMAC, não como "token na URL" crítico.

## Fontes

**OWASP**
- [OWASP API Security Top 10 — 2023](https://owasp.org/API-Security/editions/2023/en/0x11-t10/) e a [página do projeto](https://owasp.org/www-project-api-security/) (confirmando que 2023 é a edição vigente em agosto de 2026)
- [API4:2023 Unrestricted Resource Consumption](https://owasp.org/API-Security/editions/2023/en/0xa4-unrestricted-resource-consumption/) · [API6:2023 Sensitive Business Flows](https://owasp.org/API-Security/editions/2023/en/0xa6-unrestricted-access-to-sensitive-business-flows/) · [API9:2023 Improper Inventory Management](https://owasp.org/API-Security/editions/2023/en/0xa9-improper-inventory-management/) · [API10:2023 Unsafe Consumption of APIs](https://owasp.org/API-Security/editions/2023/en/0xaa-unsafe-consumption-of-apis/)
- [OWASP Top 10:2025 (web)](https://owasp.org/Top10/2025/)
- [REST Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html)
- [gRPC Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/gRPC_Security_Cheat_Sheet.html)
- [GraphQL Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/GraphQL_Cheat_Sheet.html)
- [SSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html)

**PortSwigger Web Security Academy**
- [API testing](https://portswigger.net/web-security/api-testing) · [Server-side parameter pollution](https://portswigger.net/web-security/api-testing/server-side-parameter-pollution)
- [GraphQL API vulnerabilities](https://portswigger.net/web-security/graphql)
- [WebSockets](https://portswigger.net/web-security/websockets) · [Cross-site WebSocket hijacking](https://portswigger.net/web-security/websockets/cross-site-websocket-hijacking)

**Specs e RFCs**
- [draft-ietf-httpapi-ratelimit-headers-11](https://datatracker.ietf.org/doc/html/draft-ietf-httpapi-ratelimit-headers) (23/05/2026 — ainda Internet-Draft)
- [RFC 6750 §2.3 e §5.3 — Bearer token em URI](https://datatracker.ietf.org/doc/html/rfc6750#section-2.3)
- [draft-ietf-httpapi-idempotency-key-header](https://datatracker.ietf.org/doc/draft-ietf-httpapi-idempotency-key-header/) (-07, expirado)
- [GraphQL over HTTP](https://graphql.github.io/graphql-over-http/draft/) · [GraphQL multipart request spec](https://github.com/jaydenseric/graphql-multipart-request-spec)
- [RFC 6455 — The WebSocket Protocol](https://datatracker.ietf.org/doc/html/rfc6455) · [MDN: Server-sent events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events)

**Docs de produto**
- [Stripe — Webhooks e verificação de assinatura](https://docs.stripe.com/webhooks) · [Idempotent requests](https://docs.stripe.com/api/idempotent_requests) · [IPs de webhook](https://docs.stripe.com/ips)
- [GitHub — Validating webhook deliveries](https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries) · [Best practices for using webhooks](https://docs.github.com/en/webhooks/using-webhooks/best-practices-for-using-webhooks)
- [Slack — Verifying requests](https://docs.slack.dev/authentication/verifying-requests-from-slack)
- [AWS — Signature Version 4](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_sigv.html) · [Criar uma requisição assinada](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_sigv-create-signed-request.html) · [Presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ShareObjectPreSignedURL.html)
- [Node.js — `crypto.timingSafeEqual`](https://nodejs.org/api/crypto.html#cryptotimingsafeequala-b)
- [Fastify — Validation and Serialization](https://fastify.dev/docs/latest/Reference/Validation-and-Serialization/) · [Routes (`bodyLimit`)](https://fastify.dev/docs/latest/Reference/Routes/)
- [Zod — migration guide v4](https://zod.dev/v4/changelog) · [NestJS — Validation](https://docs.nestjs.com/techniques/validation)
- [Ajv — Combining schemas](https://ajv.js.org/guide/combining-schemas.html)
- [express-rate-limit — limitações do store default](https://github.com/express-rate-limit/express-rate-limit/issues/200)

**Pesquisa e incidentes**
- [Bishop Fox — An Exploration of JSON Interoperability Vulnerabilities](https://bishopfox.com/blog/json-interoperability-vulnerabilities) e os [labs companheiros](https://github.com/BishopFox/json-interop-vuln-labs)
- [Trail of Bits — Unexpected security footguns in Go's parsers](https://blog.trailofbits.com/2025/06/17/unexpected-security-footguns-in-gos-parsers/)
- [Railway — Incident report, 30/03/2026: authenticated user data cached](https://blog.railway.com/p/incident-report-march-30-2026-authenticated-user-data-cached)
- [Wiz — Exploring Spring Boot Actuator misconfigurations](https://www.wiz.io/blog/spring-boot-actuator-misconfigurations)
- [GHSA-6qmp-9p95-fc5f — bypass de JWT via `X-HTTP-Method-Override` no ESPv2](https://github.com/GoogleCloudPlatform/esp-v2/security/advisories/GHSA-6qmp-9p95-fc5f)
- [GHSA-qcxp-gm7m-4j5v — bypass de autorização por normalização de path no Quarkus](https://github.com/quarkusio/quarkus/security/advisories/GHSA-qcxp-gm7m-4j5v)
- [CERT IDS01-J — Normalize strings before validating them](https://wiki.sei.cmu.edu/confluence/display/java/IDS01-J.+Normalize+strings+before+validating+them)
- [Kubernetes — token via subprotocolo WebSocket (PR #47740)](https://github.com/kubernetes/kubernetes/pull/47740)
