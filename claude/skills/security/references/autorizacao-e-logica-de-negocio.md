# Autorização e lógica de negócio

Broken Access Control (A01:2025) e falhas de lógica de negócio: a classe de vulnerabilidade que
mais aparece, que mais paga em bug bounty e que ferramenta automática praticamente não encontra.
Abra este arquivo quando estiver revisando qualquer endpoint que receba um identificador, qualquer
código que decide "esse usuário pode?", qualquer fluxo com dinheiro, cupom, limite ou estado, e
qualquer sistema multi-tenant.

Identidade — quem é o usuário, login, sessão, MFA, JWT — está em
`references/autenticacao-e-sessao.md`. Aqui tratamos exclusivamente do que vem **depois** da
identidade: permissão. Assuma sempre, ao ler este arquivo, que a autenticação funcionou.

## Índice

- [Por que essa classe é diferente](#por-que-essa-classe-é-diferente)
- [IDOR / BOLA — autorização em nível de objeto](#idor--bola--autorização-em-nível-de-objeto)
- [BFLA — autorização em nível de função](#bfla--autorização-em-nível-de-função)
- [Mass assignment e autorização de campo (BOPLA)](#mass-assignment-e-autorização-de-campo-bopla)
- [Multi-tenancy](#multi-tenancy)
- [Race conditions e TOCTOU](#race-conditions-e-toctou)
- [Catálogo de falhas de lógica de negócio](#catálogo-de-falhas-de-lógica-de-negócio)
- [Modelos de autorização e onde a checagem mora](#modelos-de-autorização-e-onde-a-checagem-mora)
- [Autorização fora do request: jobs, filas, webhooks, cron](#autorização-fora-do-request-jobs-filas-webhooks-cron)
- [Como testar autorização de forma sistemática](#como-testar-autorização-de-forma-sistemática)
- [Sinais em revisão de código](#sinais-em-revisão-de-código)
- [Falsos positivos comuns](#falsos-positivos-comuns)
- [Fontes](#fontes)

## Por que essa classe é diferente

Em SQL injection, XSS ou SSRF existe um **payload**: uma string que carrega em si a malícia, que
pode ser detectada por assinatura, bloqueada por WAF, encontrada por taint analysis do dado
não-confiável até um sink conhecido. Em Broken Access Control não existe payload. A requisição é
sintaticamente perfeita, semanticamente válida, tem sessão legítima, passa por qualquer validação de
schema. O único problema é que o número `1234` deveria ser `5678`.

Quatro consequências práticas: **nenhum WAF ajuda** (não há o que assinar); **DAST não acha** sem
duas contas e sem saber qual objeto é de quem, e **SAST não acha** porque não existe sink — o "sink"
é a *ausência* de uma comparação; **o bug é uma omissão**, você procura a linha que não existe, e o
diff que a introduz parece limpo; e **a gravidade depende do domínio** — `GET /api/usuarios/42/nome`
é design numa rede social e vazamento de PII num app de saúde.

Números da edição vigente ([OWASP Top 10:2025](https://owasp.org/Top10/2025/A01_2025-Broken_Access_Control/),
publicada em novembro de 2025): A01:2025 Broken Access Control agrega **40 CWEs**, 1.839.701
ocorrências e 32.654 CVEs no dataset — o maior volume de CVEs da lista. A incidência média é 3,74%
com máxima de 20,15%, e o texto registra que **100% das aplicações testadas apresentaram alguma
forma de broken access control**. Novidade da edição 2025: **SSRF (CWE-918) foi absorvida em A01**
(era A10:2021), e CSRF (CWE-352) também está mapeada aqui. Para SSRF veja
`references/ssrf-e-camada-http.md`; para CSRF veja `references/xss-e-navegador.md`.

Na [OWASP API Security Top 10 — edição 2023](https://owasp.org/API-Security/editions/2023/en/0x11-t10/),
ainda a vigente, quatro das dez posições são falhas de autorização: API1 (BOLA), API2 (Broken
Authentication), API3 (BOPLA) e API5 (BFLA). O relatório da HackerOne
([Hacker-Powered Security Report, 9ª edição, 2025](https://www.hackerone.com/report/hacker-powered-security))
registra IDOR entre os cinco tipos mais reportados e uma tendência clara: falhas de autorização
subindo enquanto XSS e SQLi caem — o inverso do que os scanners cobrem bem.

### O teste mental que revela quase tudo

Diante de qualquer handler, faça duas perguntas em sequência:

> **1. Esse identificador veio do cliente?**
> (URL, body, query, header, cookie, campo aninhado, nome de arquivo, ID dentro de um array de
> batch, `node.id` de GraphQL, payload de webhook, claim customizada de JWT.)
>
> **2. Se sim: qual linha deste código prova que ele pertence a quem está pedindo?**

Se você não consegue apontar a linha — não a intenção, a linha — é um achado. E se a linha existe
mas está num arquivo diferente do que executa a query, é um achado potencial: verifique se todo
caminho de execução passa por ela (rota nova, verbo alternativo, job, versão v2 da API).

O corolário: **um identificador que o cliente controla nunca é autorização; é entrada.** A única
identidade confiável é a que veio da sessão/token verificado no servidor.

Um dado relevante para você, que é um modelo lendo isto: o
[benchmark da Semgrep sobre detecção de IDOR por LLMs](https://semgrep.dev/blog/2025/can-llms-detect-idors-understanding-the-boundaries-of-ai-reasoning/)
(2025) mediu acurácia por complexidade da autorização — 68% quando não há autorização nenhuma no
código, 50% quando a checagem está na mesma função/arquivo, **0% quando a lógica é RBAC espalhada em
múltiplos arquivos e 0% quando a proteção vem de middleware/framework**. No teste, Claude Code com
Sonnet 4 produziu 13 verdadeiros positivos contra 46 falsos positivos. A leitura útil: você acerta
quando o contexto é local e erra quando precisa raciocinar sobre proteção invisível. Portanto,
**antes de declarar um IDOR, vá ler o middleware, o repository e o guard**. E antes de declarar um
endpoint seguro, confirme que a proteção que você assumiu existe de fato.

## IDOR / BOLA — autorização em nível de objeto

IDOR (Insecure Direct Object Reference) e BOLA (Broken Object Level Authorization) são o mesmo bug
com dois nomes: OWASP web usa o primeiro, OWASP API usa o segundo. O
[IDOR Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Insecure_Direct_Object_Reference_Prevention_Cheat_Sheet.html)
define os três ingredientes: um **objeto** (conta, documento, ticket, transação), uma **referência**
a ele (ID, UUID, número de conta, token, slug) e uma **checagem de autorização de objeto ausente**.

```ts
// ❌ vulnerável — o ID é entrada, e nada prova a posse
app.get('/api/pedidos/:id', async (req) => {
  return prisma.pedido.findUnique({ where: { id: req.params.id } })
})

// ✅ correto — o escopo faz parte da query; o ID não pode "sair" do dono
app.get('/api/pedidos/:id', async (req) => {
  const pedido = await prisma.pedido.findFirst({
    where: { id: req.params.id, clienteId: req.user.id },
  })
  if (!pedido) throw new NotFoundError()   // 404, não 403 — veja abaixo
  return pedido
})
```

Dois detalhes que fazem diferença: `findUnique` **não aceita** condições fora da chave única — por
isso ele aparece tanto em IDOR; `findFirst` aceita. E devolver **404 em vez de 403** quando o objeto
existe mas não é seu evita um oráculo de enumeração (com 403 o atacante mapeia quais IDs existem);
use 403 só quando a existência do recurso já é pública.

### Onde o identificador se esconde

A URL é o caso fácil. O que escapa da revisão:

| Local | Exemplo | Por que passa despercebido |
| --- | --- | --- |
| Body de `POST`/`PATCH` | `{"contaDestino": 998, "valor": 10}` | Validado por schema, então "parece validado" |
| Query string secundária | `?export=true&orgId=7` | O parâmetro principal está certo |
| Campo aninhado | `{"pedido":{"itens":[{"produtoId":9,"precoId":3}]}}` | Zod valida o formato, ninguém valida a posse |
| Header customizado | `X-Account-Id`, `X-Tenant`, `X-On-Behalf-Of` | Fora do schema de validação |
| Cookie | `cart_id`, `last_org` | Tratado como "estado do cliente", não como entrada |
| Batch / bulk | `POST /api/mensagens/ler {"ids":[1,2,3,...]}` | A checagem existe no endpoint singular e some no plural |
| Download | `GET /arquivos?nome=fatura-2024-0009.pdf` | Vira path traversal *e* IDOR ao mesmo tempo |
| Upload/URL assinada | `PUT /uploads?key=orgs/7/logo.png` | O `key` vem do cliente |
| GraphQL global ID | `node(id: "UGVkaWRvOjEyMzQ=")` | Base64 esconde o inteiro; ver `references/api-e-graphql.md` |
| Webhook / callback | `POST /pagamentos/callback {"pedidoId":...}` | "É o gateway chamando" — mas o endpoint é público |
| JWT com claim de recurso | `{"sub":"u1","org":"acme"}` | A claim `org` pode não ser reemitida após remoção do usuário |
| WebSocket / SSE | `{"action":"subscribe","room":"pedido:1234"}` | Autorização feita só no handshake, não por mensagem |
| Filtro/ordenação | `?filter[usuarioId]=5` | Frameworks de query (JSON:API, Prisma `where` vindo do cliente) |

O último é especialmente perigoso: **passar `where` do cliente direto para o ORM** é IDOR
generalizado (e vira exfiltração de base inteira com operadores como `not`, `contains`, `some`).

```ts
// ❌ vulnerável — o cliente escolhe o filtro; ele escolhe também os dados dos outros
const itens = await prisma.pedido.findMany({ where: req.query.where as any })

// ✅ correto — allowlist de filtros + escopo obrigatório em AND
const filtro = filtroSchema.parse(req.query)      // z.strictObject({ status: z.enum([...]) })
const itens = await prisma.pedido.findMany({
  where: { AND: [filtro, { clienteId: req.user.id }] },
})
```

### Por que UUID não é correção

UUID v4 é **obscuridade**, não controle. O cheat sheet da OWASP é explícito: "mesmo com
identificadores complexos, checagens de controle de acesso são essenciais". E o UUID vaza por
caminhos mundanos: **logs e observabilidade** (URL completa em access log, Sentry, tracing);
**header `Referer`** ao navegar de `/pedidos/<uuid>` para um link externo (mitigável com
`Referrer-Policy: strict-origin-when-cross-origin`, hoje default de Chrome e Firefox);
**outro endpoint legítimo** — busca, feed, autocomplete, `include` do Prisma, listagem de
comentários; **export, CSV, PDF, e-mail transacional, payload de webhook**. E **UUID v1/v7 são
*time-ordered***: v1 embute timestamp e MAC address, v7 embute timestamp em milissegundos nos 48
bits mais significativos — ou seja, **v7 é parcialmente enumerável por proximidade temporal**.
Excelente para índice (veja a skill `dba`), ruim como segredo; se o ID é usado como capability, use
v4 ou 128 bits de CSPRNG.

UUID vale como **defesa em profundidade** (corta varredura em massa e enumeração sequencial, que
também vaza volume de negócio — quantos pedidos por dia). Nunca como controle primário. Corolário
inverso, para não gerar falso positivo: **ID sequencial exposto não é vulnerabilidade por si só**;
`/posts/1234` num blog público é design. O achado é a ausência da checagem, não o formato do ID.

### A correção real: escopo dentro da query, não checagem depois

```ts
// ⚠️ frágil — busca primeiro, checa depois
const pedido = await prisma.pedido.findUnique({ where: { id } })
if (pedido.clienteId !== req.user.id) throw new ForbiddenError()
return pedido
```

Isso funciona *hoje* e apodrece: alguém acrescenta um `include`, um `console.log(pedido)` ou um
`span.setAttribute('pedido', pedido)` **antes** da checagem e o dado já vazou; alguém extrai a busca
para um helper e o novo chamador não copia o `if`; `pedido` vem `null` e a linha lança `TypeError`
que um `catch` genérico transforma em 500 — ou em fluxo permissivo; o endpoint ganha um irmão
(`/api/v2/pedidos/:id`, `PATCH` além do `GET`, versão mobile) sem a checagem.

```ts
// ✅ melhor — escopo na query, na camada de dados, uma vez
// repositories/pedido.ts
export function pedidoRepo(scope: { clienteId: string }) {
  return {
    byId: (id: string) =>
      prisma.pedido.findFirst({ where: { id, clienteId: scope.clienteId } }),
    list: (args: PedidoFilter) =>
      prisma.pedido.findMany({ where: { ...args, clienteId: scope.clienteId } }),
  }
}
```

O ganho não é estético: com o escopo dentro da query, **esquecer a autorização exige uma ação
positiva** (construir o `prisma` cru em vez de pedir o repo). Com a checagem depois, esquecer é o
default. Segurança que depende de lembrar não escala num time.

Em SQL puro, a mesma ideia:

```sql
-- ❌ o WHERE é a identidade do objeto, não do dono
SELECT * FROM pedidos WHERE id = $1;

-- ✅ o dono faz parte do predicado; zero linhas é a resposta certa
SELECT * FROM pedidos WHERE id = $1 AND tenant_id = $2;
```

E há um erro sutil que aparece em revisão: escopo aplicado no `SELECT` mas não no `UPDATE`/`DELETE`.

```sql
-- ❌ escopo esquecido na escrita — IDOR destrutivo
UPDATE pedidos SET status = 'cancelado' WHERE id = $1;

-- ✅
UPDATE pedidos SET status = 'cancelado' WHERE id = $1 AND tenant_id = $2;
-- e verifique rowCount === 1; rowCount === 0 é 404, não sucesso silencioso
```

`rowCount === 0` tratado como sucesso é um bug recorrente: o endpoint responde 204, o atacante não
consegue apagar nada, e ninguém percebe que o mesmo padrão em outro handler *permite*.

### Sinais de código para IDOR

```bash
# Prisma: chave única sem escopo
grep -rn "findUnique({ *where: *{ *id:" src/
grep -rn "\.delete({ *where: *{ *id:" src/
grep -rn "\.update({ *where: *{ *id:" src/

# ID vindo do request usado direto
grep -rEn "(params|query|body)\.(id|userId|orgId|accountId|tenantId)" src/

# TypeORM / Sequelize / Mongoose
grep -rn "findOne({ *_id" src/ ; grep -rn "findByPk(" src/ ; grep -rn "findByIdAndUpdate" src/

# Rails / Django / Laravel
grep -rn "\.find(params\[:id\])" app/          # sem current_user.xxx.find
grep -rn "objects.get(pk=" .                   # sem filter(owner=request.user)
grep -rn "::find(\$request->" app/
```

Regra de Semgrep como ponto de partida (o `metavariable-regex` é o que evita ruído):

```yaml
rules:
  - id: prisma-por-id-sem-escopo
    languages: [ts, js]
    severity: WARNING
    message: acesso por id do request sem escopo; confirme se o repository já injeta o tenant
    patterns:
      - pattern-either:
          - pattern: $P.$M({ where: { id: $REQ.params.$X, ... }, ... })
          - pattern: $P.$M({ where: { id: $REQ.body.$X, ... }, ... })
      - metavariable-regex:
          metavariable: $M
          regex: ^(findUnique|findUniqueOrThrow|update|delete|upsert)$
```

## BFLA — autorização em nível de função

BOLA é "acessei o objeto do outro". BFLA (Broken Function Level Authorization, API5:2023) é
"executei uma função que não é para o meu papel". A distinção importa porque as correções são
diferentes: BOLA se resolve no dado, BFLA se resolve na rota.

Três eixos, na terminologia da [PortSwigger](https://portswigger.net/web-security/access-control):
**vertical** (usuário comum alcança função de admin — `POST /api/admin/usuarios/:id/promover`),
**horizontal** (função de outro usuário do mesmo nível — na prática vira BOLA) e
**contextual** (*context-dependent*: a função é permitida ao papel mas não **naquele estado** —
editar o carrinho depois do pagamento, aprovar o próprio pedido, cancelar um envio já despachado).
O terceiro é a ponte entre BFLA e falha de lógica de negócio.

### Os bypasses que realmente funcionam

| Técnica | Requisição | Por que passa |
| --- | --- | --- |
| Rota não listada | `GET /admin/painel` sem link no menu | Segurança por obscuridade; `/sitemap.xml`, JS bundle e `.map` entregam a rota |
| Verbo alternativo | `GET /api/usuarios/:id` protegido, `PUT` não | Guard registrado por rota+método; alguém adicionou o método depois |
| Method override | `POST /api/x` + `X-HTTP-Method-Override: DELETE` ou `?_method=DELETE` | Rails, Laravel, Symfony e alguns middlewares Express traduzem; o proxy que bloqueia `DELETE` não vê |
| `HEAD` | `HEAD /admin/relatorio` | Frameworks roteiam `HEAD` para o handler de `GET`; regra de WAF/proxy que casa só `GET` não pega. Corpo não volta, mas headers, timing e efeitos colaterais sim |
| Case | `/Admin/painel` | Proxy compara case-sensitive, app roteia case-insensitive (ou vice-versa) |
| Barra final | `/admin/deleteUser/` vs `/admin/deleteUser` | Regra do proxy casa exata; router normaliza |
| Sufixo | `/admin/deleteUser.json`, `.anything` | Spring com `useSuffixPatternMatch` (default `true` até Spring 4; `false` a partir do 5.3) |
| Parâmetro de path | `/admin;x=1`, `/admin%2f`, `/%2e%2e/admin` | Path params do Java (`;`), normalização divergente entre nginx e app |
| Header de override de URL | `GET / ` + `X-Original-URL: /admin` ou `X-Rewrite-URL: /admin` | Suportado por alguns front-ends (IIS/ARR, algumas configs de Apache/Nginx com proxy); o front autoriza `/`, o back serve `/admin` |
| Header interno confiado | `X-Forwarded-For: 127.0.0.1`, `X-Real-IP`, `X-Forwarded-User` | Allowlist por IP ou SSO por header sem stripping na borda |
| Header de framework | `x-middleware-subrequest` | **CVE-2025-29927**, Next.js: o header pulava o middleware inteiro |
| `Referer` como controle | `Referer: https://app/admin` | Totalmente controlado pelo cliente |
| Trailing dot / unicode | `/admin.`, `/аdmin` (а cirílico) | Normalização Unicode divergente |

O caso do Next.js é o exemplo canônico de "toda a autorização num lugar frágil":
[CVE-2025-29927](https://nvd.nist.gov/vuln/detail/CVE-2025-29927) (março de 2025, CVSS 9.1) permitia
pular o `middleware.ts` inteiro enviando `x-middleware-subrequest` — header que o próprio framework
usa para evitar loop de subrequest e que era confiado sem verificar origem. Corrigido em **12.3.5,
13.5.9, 14.2.25 e 15.2.3**; mitigação de borda: descartar o header no proxy. A lição transferível
não é "atualize o Next.js", é que **middleware é boa camada de defesa e péssima única camada**: um
bug do framework, uma rota que escapa do `matcher`, um rewrite ou uma chamada interna derrubam tudo.

```ts
// ❌ vulnerável — a única checagem está no middleware
// middleware.ts
export const config = { matcher: ['/admin/:path*'] }   // /api/admin/* não casa!

// ✅ defesa em profundidade — o handler também decide
// app/api/admin/usuarios/route.ts
export async function POST(req: Request) {
  const session = await auth()
  if (!session) return new Response(null, { status: 401 })
  if (!can(session.user, 'usuario:criar')) return new Response(null, { status: 403 })
  // ...
}
```

Padrões estruturais que eliminam categorias inteiras desses bypasses:

- **Deny by default no roteador**: autorização como configuração positiva por rota, e uma rota sem
  política declarada falha o boot (ou responde 403), em vez de ficar aberta.
  ```ts
  // Fastify: obriga toda rota a declarar policy
  app.addHook('onRoute', (route) => {
    if (route.url.startsWith('/health')) return
    if (!route.config?.policy) throw new Error(`rota sem policy: ${route.method} ${route.url}`)
  })
  app.addHook('preHandler', async (req, reply) => {
    const policy = req.routeOptions.config.policy
    if (!(await policy(req))) return reply.code(403).send()
  })
  ```
  Esse hook `onRoute` roda no registro da rota: o processo **não sobe** com rota desprotegida. É a
  correção mais barata e de maior efeito que existe para BFLA.
- **Normalizar antes de decidir**: decida autorização sobre o path já normalizado pelo *mesmo*
  parser que vai rotear. Nunca autorize por string bruta no proxy e roteie no app.
- **Strip de headers na borda**: o gateway remove `X-Original-URL`, `X-Rewrite-URL`,
  `X-HTTP-Method-Override`, `X-Forwarded-User`, `x-middleware-subrequest` e qualquer header que a
  aplicação trate como confiável.
- **Frontend que esconde botão não é controle.** Menu escondido, rota React protegida por
  `<RequireRole>`, campo `disabled` — todos existem para UX. A verificação canônica é no servidor.

## Mass assignment e autorização de campo (BOPLA)

API3:2023 (Broken Object Property Level Authorization) fundiu dois problemas espelhados: **escrita**
de propriedades que o usuário não deveria poder alterar (mass assignment) e **leitura** de
propriedades que ele não deveria ver (excessive data exposure).

### Escrita: mass assignment / over-posting

```ts
// ❌ vulnerável — o corpo inteiro vira update
app.patch('/api/me', async (req) => {
  return prisma.user.update({ where: { id: req.user.id }, data: req.body })
})
// PATCH /api/me {"nome":"Ana","role":"ADMIN","emailVerified":true,"creditos":999999}
```

Equivalentes por stack: `Object.assign(user, req.body)`, `user.set(req.body)` (Mongoose),
`Model.update(req.body)` (Sequelize), `@ModelAttribute User user` sem `@InitBinder` (Spring MVC),
`User.update(params[:user])` sem strong parameters (Rails), `$user->fill($request->all())` sem
`$fillable` (Laravel), `UpdateModel(user)` sem `includeProperties` (ASP.NET MVC),
`ModelForm(fields='__all__')` (Django).

O caso histórico: em 2012, Egor Homakov explorou mass assignment no GitHub (Rails) para adicionar a
própria chave SSH à organização `rails`. O
[Mass Assignment Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html)
registra o incidente e os nomes alternativos: *mass assignment* (Rails, Node), *autobinding* (Spring
MVC, ASP.NET MVC), *object injection* (PHP).

**Campos que escalam privilégio quando alcançáveis** — a lista para procurar em qualquer model:

| Campo | Efeito |
| --- | --- |
| `role`, `roles`, `isAdmin`, `permissions`, `scopes` | Escalação vertical direta |
| `tenantId`, `orgId`, `companyId`, `workspaceId` | Cross-tenant: mover objeto para outro tenant, ou a si mesmo para o tenant da vítima |
| `emailVerified`, `phoneVerified`, `kycStatus`, `mfaEnabled` | Pula verificação; às vezes destrava fluxo de recuperação de conta |
| `email` sem reverificação | Toma a conta via "esqueci a senha" |
| `saldo`, `creditos`, `balance`, `points`, `plan`, `planExpiresAt` | Dinheiro |
| `price`, `discount`, `total`, `currency` em item de pedido | Dinheiro (veja lógica de negócio) |
| `status`, `state`, `approvedBy`, `approvedAt` | Pula workflow de aprovação |
| `createdAt`, `updatedAt`, `deletedAt` | Fraude de auditoria, burla de janela de cancelamento/trial |
| `id`, `userId`, `ownerId` | Reatribuição de posse (IDOR de escrita) |
| `parentId`, `folderId`, `projectId` | Move objeto para container de outro |

Correção — **allowlist explícita**, nunca blocklist:

```ts
// ✅ Zod 4: schema estrito, apenas campos editáveis pelo próprio usuário
import { z } from 'zod'

const AtualizarPerfil = z.strictObject({          // z.strictObject rejeita chaves desconhecidas
  nome: z.string().min(1).max(120),
  bio: z.string().max(500).optional(),
})

app.patch('/api/me', async (req, reply) => {
  const data = AtualizarPerfil.parse(req.body)    // lança em `role`, `tenantId`, etc.
  return prisma.user.update({
    where: { id: req.user.id },
    data,
    select: { id: true, nome: true, bio: true },  // e a resposta também é allowlist
  })
})
```

Notas de versão: em **Zod 4**, `.strict()`, `.passthrough()` e `.strip()` estão deprecados em favor
de `z.strictObject()` / `z.looseObject()` (seguem funcionando por compatibilidade); equivalentes
manuais são `.catchall(z.never())` e `.catchall(z.unknown())`. O default do Zod é `strip`, que
**remove chaves desconhecidas silenciosamente** — o que já protege *se você usar o resultado do
`parse()`*. O bug clássico é validar e gravar outra coisa:

```ts
// ❌ vulnerável — valida uma coisa, grava outra
Schema.parse(req.body)
await prisma.user.update({ where: { id }, data: req.body })   // req.body, não o parsed!

// ✅
const data = Schema.parse(req.body)
await prisma.user.update({ where: { id }, data })
```

`grep -rn "parse(req.body)" src/ | grep -v "const .* ="` encontra exatamente esse padrão. Duas
armadilhas relacionadas: `z.record(z.unknown())` para "campos customizados" reabre o buraco (mande
campos livres para uma coluna `metadata jsonb`, nunca para o objeto raiz); e TypeScript **não valida
em runtime** — `data: req.body as Prisma.UserUpdateInput` compila e é exatamente o bug
(`grep -rn "as Prisma\." src/`).

### Leitura: excessive data exposure

O espelho: o endpoint devolve o objeto inteiro do banco e o frontend "esconde" o que não deve
aparecer. O atacante lê a resposta HTTP.

```ts
// ❌ vulnerável — devolve o registro inteiro
app.get('/api/me', async (req) =>
  prisma.user.findUnique({ where: { id: req.user.id } }))
// devolve passwordHash, mfaSecret, resetToken, stripeCustomerId, internalNotes, riskScore...

// ✅ select explícito
app.get('/api/me', async (req) =>
  prisma.user.findUnique({
    where: { id: req.user.id },
    select: { id: true, nome: true, email: true, avatarUrl: true },
  }))
```

Onde isso mais vaza: **`include` do Prisma** — `include: { autor: true }` num comentário devolve o
`User` completo do autor, `passwordHash` incluso; prefira
`select: { autor: { select: { id: true, nome: true } } }` (`include` e `select` são mutuamente
exclusivos no mesmo nível, então a presença de `include` é o sinal de revisão). **Listagens** que
devolvem e-mail e telefone de todos porque uma tela de admin precisa. **Serializer global**:
`toJSON()` que remove `password` mas foi escrito antes de `mfaSecret`, `apiKey` e `recoveryCodes`
existirem — blocklist envelhece, allowlist não. **GraphQL**: o campo existe no schema, a UI não usa,
a query do atacante usa (veja `references/api-e-graphql.md`). **Search/autocomplete** com `contains`
sobre e-mail, que vira oráculo de existência de conta.

O sinal de revisão mais rápido: **procure o `select` ausente**.

```bash
grep -rn "findMany({" src/ | grep -v "select"
grep -rn "include:" src/
grep -rn "SELECT \*" src/
```

## Multi-tenancy

Em SaaS B2B, cross-tenant é a falha de maior severidade possível e a mais silenciosa: não gera erro,
não gera log de exceção, não muda latência. O cliente A vê dados do cliente B e, em geral, ninguém
descobre até alguém reclamar.

### Estratégias e seus modos de falha

| Estratégia | Isolamento | Modo de falha característico |
| --- | --- | --- |
| Coluna `tenant_id` (shared schema) | Lógico, por predicado | **Um `WHERE` esquecido em qualquer lugar do código.** Migração nova, query raw, relatório, job, endpoint de admin |
| Schema por tenant (Postgres) | Lógico, por `search_path` | `search_path` setado por conexão vaza no pool; DDL cresce linearmente (10k tenants = 10k × N tabelas); migração fica cara e falha parcialmente |
| Banco por tenant | Físico | Roteamento errado de connection string; conexão "de admin" que aponta para o tenant errado; custo e limite de conexões |
| Silo por conta cloud | Físico total | Complexidade operacional; o vazamento migra para os serviços compartilhados (auth, billing, e-mail) |

Nenhuma estratégia protege contra a falha real, que é **um caminho de código que não conhece o
tenant**. Por isso a checagem tem de ser estrutural: o escopo entra no dado por construção, não por
disciplina.

### Escopo estrutural, em três camadas

**1. Middleware que resolve e injeta o escopo** — a única fonte do `tenantId` é o token/sessão
verificados, jamais um header ou body:

```ts
// ❌ vulnerável — o cliente escolhe o tenant
const tenantId = req.headers['x-tenant-id']

// ✅ o tenant vem da sessão; o subdomínio serve para UX e é validado contra a associação
app.addHook('preHandler', async (req) => {
  const membership = await prisma.membership.findFirst({
    where: { userId: req.user.id, tenant: { slug: subdomainOf(req.hostname) } },
    select: { tenantId: true, role: true },
  })
  if (!membership) throw new ForbiddenError()
  req.scope = { tenantId: membership.tenantId, role: membership.role }
})
```

**2. Cliente de dados que não sabe consultar sem escopo.** Com Prisma, uma *client extension*
aplicando `where` global:

```ts
// ✅ toda query passa a carregar tenantId; esquecer exige sair do cliente escopado
export function prismaFor(tenantId: string) {
  return prisma.$extends({
    query: {
      $allModels: {
        async $allOperations({ args, query, model, operation }) {
          if (MODELOS_GLOBAIS.has(model)) return query(args)      // ex.: Plan, Country
          if (operation === 'findUnique') {
            // findUnique não aceita filtro extra: degrade para findFirst
            return query({ ...args, where: { ...args.where, tenantId } } as any)
          }
          args.where = { AND: [args.where ?? {}, { tenantId }] }
          return query(args)
        },
      },
    },
  })
}
```

Ressalvas honestas dessa abordagem: ela **não cobre `$queryRaw`, `$executeRaw` nem `$transaction`
com SQL cru**; não cobre `create` (você precisa injetar `data.tenantId` também); e `findUnique`
promovido a filtro composto muda a semântica de erro. É uma boa camada, não a última.

**3. Row Level Security no Postgres** — a única camada que também protege query crua, script de
migração, ferramenta de BI e o estagiário com `psql`.

```sql
ALTER TABLE pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedidos FORCE  ROW LEVEL SECURITY;   -- aplica também ao dono da tabela

CREATE POLICY tenant_isolation ON pedidos
  USING      (tenant_id = current_setting('app.tenant_id', true)::uuid)
  WITH CHECK (tenant_id = current_setting('app.tenant_id', true)::uuid);
```

Mecânica que você precisa saber para revisar isso corretamente
([docs oficiais](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)):

- `USING` controla **quais linhas são visíveis** (`SELECT`, e quais linhas o `UPDATE`/`DELETE`
  enxerga). `WITH CHECK` controla **quais linhas podem ser gravadas** (`INSERT`, e o resultado do
  `UPDATE`). **Só `USING` é o erro clássico**: sem `WITH CHECK`, quando você o omite ele é copiado
  do `USING` — mas se as expressões diferem, um `UPDATE ... SET tenant_id = '<outro>'` pode mover a
  linha para fora do tenant. Escreva as duas.
- **`ENABLE` não basta.** O **dono da tabela ignora RLS** por padrão; `FORCE ROW LEVEL SECURITY`
  corrige isso. **Superusuário e roles com `BYPASSRLS` sempre ignoram** — e aplicações que conectam
  como owner ou superuser (o default de muito setup de Docker e de migração) têm RLS decorativa.
  Confira: `SELECT rolname, rolsuper, rolbypassrls FROM pg_roles;` e
  `SELECT relname, relrowsecurity, relforcerowsecurity FROM pg_class WHERE relrowsecurity;`.
- Políticas **PERMISSIVE** (default) combinam com **OR**; **RESTRICTIVE** combinam com **AND**. Uma
  política permissiva `USING (true)` criada "temporariamente para o job noturno" anula todas as
  outras. Procure por `USING (true)`.
- **Constraints de unicidade e chaves estrangeiras ignoram RLS** — por design, para manter
  integridade. Isso cria um canal encoberto: se `email` é `UNIQUE` global, o erro de violação revela
  que o e-mail existe em *outro* tenant. Torne unicidade composta: `UNIQUE (tenant_id, email)`.
- **Custo no planner**: a política vira predicado extra em toda query, e só funções `LEAKPROOF`
  (basicamente operadores built-in) podem ser avaliadas antes dela — as suas não são, então não
  descem abaixo do filtro. Garanta `tenant_id` **como primeira coluna** dos índices compostos mais
  usados (`CREATE INDEX ON pedidos (tenant_id, criado_em DESC)`), senão a RLS transforma index scan
  em seq scan filtrado. Detalhes de planejamento: veja a skill `dba`.
- `SET row_security = off` **não desliga a RLS**: faz a query **falhar com erro** se alguma política
  filtraria linhas. É o modo certo para backups (`pg_dump` usa isso) porque garante dump completo ou
  falha ruidosa, em vez de dump silenciosamente parcial.

Setando o tenant por transação, com pool:

```ts
// ✅ set_config(..., true) = LOCAL: escopo dura só a transação
await prisma.$transaction(async (tx) => {
  await tx.$executeRaw`SELECT set_config('app.tenant_id', ${tenantId}, true)`
  return tx.pedido.findMany()
})
```

**O detalhe que decide entre seguro e catastrófico**: o terceiro parâmetro `true` de `set_config`
significa `LOCAL` — o valor é revertido no fim da transação. Com `false` (ou `SET app.tenant_id =
...` sem `LOCAL`) o valor **fica grudado na conexão**, e a próxima requisição que pegar essa conexão
do pool herda o tenant anterior. Em PgBouncer com **transaction pooling**, `SET LOCAL` é seguro e
`SET` sem `LOCAL` é uma bomba; com **session pooling** ambos vazam entre requisições da mesma
sessão. Regra: **sempre `LOCAL`, sempre dentro da transação que executa as queries**. Nota sobre o
[exemplo oficial do Prisma](https://github.com/prisma/prisma-client-extensions/tree/main/row-level-security):
o README diz explicitamente que **não é destinado a produção** e que `$transaction()` no cliente
escopado "pode não funcionar como esperado", porque a extension já envolve cada query numa transação
em lote.

### Vazamentos por caminhos laterais

O `WHERE tenant_id` cobre a query. Não cobre:

| Caminho | Falha típica | Correção |
| --- | --- | --- |
| **Cache** (Redis, memória, HTTP) | Chave `user:42:perfil` ou `dashboard:mensal` sem tenant | Prefixe **sempre**: `t:{tenantId}:...`. Em cache HTTP, `Vary` correto e `Cache-Control: private` |
| **Job em background** | O worker recebe só `pedidoId` e busca com cliente global | Passe `tenantId` no payload e reconstrua o escopo no worker |
| **Fila** | Fila única com consumidores de todos os tenants; DLQ compartilhada com payload de PII | Escopo no payload; DLQ com retenção e acesso controlado |
| **Webhook de saída** | URL configurada pelo tenant A recebendo evento do tenant B por bug de fan-out | Filtro na origem do fan-out + assinatura por tenant |
| **Export / relatório / CSV** | Query de relatório escrita em SQL cru, fora do ORM escopado | RLS cobre isso — é o principal argumento a favor dela |
| **Busca full-text** (Elastic, Meili, `tsvector`) | Índice único sem filtro obrigatório de tenant | Filtro obrigatório injetado no cliente de busca, ou índice por tenant |
| **Storage** | Bucket sem prefixo por tenant; URL assinada com escopo largo | `s3://bucket/t/{tenantId}/...` + política IAM por prefixo; URL assinada curta e específica |
| **ID sequencial global** | `pedido #1043` revela volume total do SaaS; e enumerar é trivial | Numeração por tenant (`UNIQUE (tenant_id, numero)`) ou ID opaco |
| **E-mail transacional** | Template renderizado com dados carregados fora do escopo; "responder a todos" da notificação | Renderize com o mesmo cliente escopado |
| **Métrica / log / tracing** | Dashboard de suporte agregando sem filtro; log de um tenant visível a outro | Tenant como atributo obrigatório e filtro no backend de observabilidade |
| **Migração / seed / script** | Roda como superuser, ignora RLS, e às vezes copia dado entre tenants | Revisar toda migração que faz `UPDATE ... FROM` entre tabelas |
| **Feature flag / config** | Config carregada por singleton no boot com o tenant do primeiro request | Nunca guarde tenant em módulo de escopo global |

Esse último merece ênfase: **estado de request guardado em variável de módulo** é a origem de
vazamentos cross-tenant intermitentes e infernais de reproduzir. Em Node, `AsyncLocalStorage` é a
forma correta de propagar contexto por requisição; um `let tenantAtual` no topo do arquivo é
garantia de vazamento sob concorrência.

## Race conditions e TOCTOU

TOCTOU (*time-of-check to time-of-use*) é a lacuna entre verificar e agir. Historicamente foi
tratada como falha teórica em web porque "a janela é pequena demais". Isso mudou: a pesquisa de
James Kettle, [*Smashing the state machine: the true potential of web race conditions*](https://portswigger.net/research/smashing-the-state-machine)
(Black Hat USA / DEF CON 31, 2023), introduziu o **single-packet attack** e mostrou que a janela é
alcançável de forma confiável pela internet.

### Single-packet attack, em números

A técnica completa 20–30 requisições HTTP/2 num **único pacote TCP**: envia headers e corpo de todas
elas, retém o frame final de cada uma, desabilita `TCP_NODELAY` (deixando o algoritmo de Nagle
agrupar) e libera os frames finais juntos. Resultado medido de Melbourne para Dublin: **spread
mediano de 1 ms com desvio padrão de 0,3 ms**, contra **4 ms e 3 ms** do *last-byte sync* (a técnica
anterior, ainda usada quando o alvo só fala HTTP/1.1). Ou seja, jitter de rede deixa de existir como
proteção: **qualquer janela maior que ~1 ms é explorável remotamente**.

Além do *limit overrun* clássico (gastar duas vezes o mesmo saldo), a pesquisa nomeou os
**sub-states**: estados internos que a aplicação assume e abandona dentro do processamento de um
único request, invisíveis de fora. Exemplo real: **GitLab, [CVE-2022-4037](https://nvd.nist.gov/vuln/detail/CVE-2022-4037)** —
requisições simultâneas de troca de e-mail faziam o token de confirmação ser enviado para o endereço
errado permanecendo válido, resultando em account takeover. Causa raiz no Devise (Rails): o token
era lido do banco e o endereço de destino de uma variável de instância; entre enfileirar a
notificação e renderizar o corpo do e-mail, outra thread alterava o banco. A lição generalizável:
**ler pedaços do mesmo estado de fontes diferentes cria janela de inconsistência.**

### Padrões para procurar

| Padrão | Exemplo concreto | Sinal no código |
| --- | --- | --- |
| Double-spend | Saque/transferência concorrente com saldo suficiente para só uma | `if (saldo >= v)` seguido de `update` em statements separados |
| Resgate duplo de cupom | Mesmo código aplicado N vezes | `findFirst({ where: { codigo, usado: false } })` e depois `update` |
| Limite de convite/assento | 5 convites viram 40 | `count()` comparado a limite, depois `create` |
| Upgrade/downgrade de plano | Cobrança de um mês, features de vários | Leitura de plano + escrita em passos separados |
| Criação duplicada | 2 usuários com mesmo e-mail apesar do `UNIQUE` "checado" | `findFirst` + `create` sem constraint no banco, ou com `UNIQUE` só na aplicação |
| Voto / like / rating | Um voto vira N | Mesma forma |
| Multi-step com estado | Confirmar pagamento enquanto o carrinho é alterado | Duas rotas que tocam o mesmo agregado sem lock |
| Sub-state | Sessão que passa por "admin" antes de ser sobrescrita; upload que fica público antes de ser movido | Duas escritas sequenciais no mesmo objeto |
| Rate limit / OTP | Bypass do "3 tentativas" enviando 30 em paralelo | Contador incrementado depois da verificação |
| Idempotência falha | Retry do gateway processa o pagamento duas vezes | Handler de webhook sem chave de idempotência |

O sinal em código é sempre o mesmo formato: **check-then-act em duas idas ao banco**.

```ts
// ❌ vulnerável — janela entre a leitura e a escrita
const cupom = await prisma.cupom.findFirst({ where: { codigo, usado: false } })
if (!cupom) throw new Error('cupom inválido')
await prisma.cupom.update({ where: { id: cupom.id }, data: { usado: true } })
await creditar(req.user.id, cupom.valor)
```

### Defesas, da mais para a menos confiável

**1. Constraint no banco** — a única defesa que sobrevive a bug de aplicação, deploy parcial,
múltiplas instâncias e script manual.

```sql
CREATE UNIQUE INDEX ON resgates (cupom_id, usuario_id);          -- impede duplo resgate
ALTER TABLE contas ADD CONSTRAINT saldo_ok CHECK (saldo >= 0);   -- impede saldo negativo
```

Com o `CHECK`, `UPDATE contas SET saldo = saldo - $1` é atômico e a violação vira erro — sem janela.

**2. Escrita condicional atômica** — uma única instrução faz check e act:

```ts
// ✅ o WHERE é a checagem; se não casou, ninguém debitou
const r = await prisma.cupom.updateMany({
  where: { codigo, usado: false },
  data: { usado: true, usadoPor: req.user.id },
})
if (r.count !== 1) throw new ConflictError('cupom já utilizado')
```

Em SQL: `UPDATE cupons SET usado = true WHERE codigo = $1 AND usado = false RETURNING id` — zero
linhas significa que perdeu a corrida.

**3. `SELECT ... FOR UPDATE`** dentro de transação (lock pessimista de linha). Cuidados: adquira os
locks sempre na mesma ordem (ordene por ID), senão transferência A→B simultânea a B→A dá deadlock;
`FOR UPDATE SKIP LOCKED` é para fila de trabalho, não para autorização; e `FOR UPDATE` **não protege
linha que ainda não existe** — para isso, constraint única ou `pg_advisory_xact_lock(hashtext(k))`.

**4. Isolamento `SERIALIZABLE`.** No Postgres o SSI detecta o conflito e aborta uma das transações
com `SQLSTATE 40001` (`serialization_failure`). Correto e caro; exige **retry automático**, senão
você trocou race condition por 500 intermitente. `REPEATABLE READ` **não** basta: previne leitura
não-repetível e phantom por snapshot, mas write skew só cai com `SERIALIZABLE` (veja a skill `dba`).

**5. Lock distribuído (Redis)** — para recurso que não é linha (chamada a API externa, envio de
e-mail). Mínimo aceitável: `SET chave token NX PX 30000` e release por script Lua comparando o
token. **Redlock é controverso**: a crítica de Kleppmann sobre relógio, GC pause e ausência de
fencing token continua válida — é otimização de contenção, não garantia de correção. Nunca como
única defesa contra double-spend; use constraint.

**6. Chave de idempotência**, para dinheiro e para todo webhook de entrada: `INSERT` da chave numa
tabela com `UNIQUE`, e a violação (`P2002` no Prisma, `23505` no Postgres) responde 409. Guarde
também a **resposta** associada à chave, para que o retry legítimo receba o mesmo resultado em vez
de 409.

**7. Serialização por chave na fila** — um consumidor por partição, particionando por `contaId` /
`pedidoId` (Kafka por chave, SQS FIFO com `MessageGroupId`, BullMQ com concorrência 1 por grupo).
Elimina a concorrência em vez de coordená-la; é a opção mais robusta quando a operação é assíncrona.

### Como testar

```bash
# curl >= 7.66: --parallel dispara as requisições simultaneamente.
# O globbing [1-30] gera 30 URLs, então 30 requisições em voo ao mesmo tempo.
curl --parallel --parallel-immediate --parallel-max 30 \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"codigo":"PROMO10"}' \
  'https://alvo.local/api/cupons/resgatar?n=[1-30]'
```

Isso encontra limit overrun grosseiro. Para janelas de ~1 ms use **Turbo Intruder** com gate:

```python
# Turbo Intruder — single-packet attack (requer HTTP/2 no alvo)
def queueRequests(target, wordlists):
    engine = RequestEngine(endpoint=target.endpoint, concurrentConnections=1, engine=Engine.BURP2)
    for i in range(20):
        engine.queue(target.req, gate='resgate')
    engine.openGate('resgate')          # libera os frames finais juntos
```

No Burp (2023.9+) o **Repeater** faz isso nativamente: agrupe abas e use *"Send group in parallel
(single-packet attack)"*. A metodologia da
[Web Security Academy](https://portswigger.net/web-security/race-conditions) tem três fases:
**Predict** (mapear endpoints com potencial de colisão — qualquer coisa com limite, dinheiro ou
estado), **Probe** (medir o comportamento sequencial primeiro, depois disparar em paralelo e
procurar desvio: status diferente, duplicata, saldo inconsistente, e-mail a mais) e **Prove**
(remover requisições supérfluas e reproduzir de forma determinística). Faça *connection warming*:
mande uma requisição inocente antes, para o handshake TLS não distorcer o timing.

Como regressão automatizada — contra banco real, não mock:

```ts
test('não resgata o mesmo cupom duas vezes sob concorrência', async () => {
  const r = await Promise.all(
    Array.from({ length: 20 }, () => api.post('/api/cupons/resgatar', { codigo: 'X' })),
  )
  expect(r.filter((x) => x.status === 200)).toHaveLength(1)
  expect(await saldoDe(usuario)).toBe(10)
})
```

## Catálogo de falhas de lógica de negócio

Não existe assinatura para essas falhas — existe repertório. A tabela abaixo é o repertório: para
cada padrão, o que procurar no código.

### Dinheiro, preço e quantidade

| Falha | Ataque | Sinal em código |
| --- | --- | --- |
| Quantidade negativa | `{"qtd": -3}` gera crédito | `z.number()` sem `.int().positive()`; `total += preco * qtd` |
| Quantidade zero | Frete grátis, brinde sem compra | Ausência de `.min(1)` |
| Overflow / precisão | `qtd: 999999999999` estoura `Number`; `2**53` perde precisão | Aritmética de dinheiro em `number` |
| Ponto flutuante em dinheiro | `0.1 + 0.2 !== 0.3`; centavos somem ou sobram | `Float`/`Double` na coluna, `number` no TS |
| Arredondamento | Somar itens arredondados vs arredondar a soma; "salami slicing" | `Math.round` aplicado item a item |
| Moeda | Enviar `currency: "IDR"` e pagar 100 rupias por um item de 100 reais | Campo `currency` aceito do cliente |
| Preço no cliente | `{"produtoId":9,"preco":1}` | O handler lê `preco` do body em vez do banco |
| Desconto composto | Aplicar `PROMO10` cinco vezes; empilhar cupom com promoção | Ausência de `UNIQUE (pedido_id, cupom_id)` |
| Desconto maior que o total | Total negativo vira crédito na carteira | Falta `CHECK (total >= 0)` |
| Frete/imposto recalculado tarde | Alterar CEP após o cálculo | Valores persistidos no carrinho e não recalculados no fechamento |
| Parsing de valor | `"1.000,50"` interpretado como `1.0`; `parseFloat("1e3")` | `parseFloat`/`Number` sobre string de UI |
| Unidade | Preço em centavos misturado com preço em reais | Dois campos com nomes parecidos (`preco`, `precoCents`) |

Regra prática: **dinheiro é inteiro em centavos (`bigint`/`numeric`), nunca float**, e todo preço
vem do banco no momento do fechamento — o cliente manda `produtoId` e `quantidade`, nada mais.

```ts
// ❌ vulnerável — preço e total vêm do cliente
const total = req.body.itens.reduce((s, i) => s + i.preco * i.qtd, 0)

// ✅ preço autoritativo do banco; quantidade validada
const itens = z.array(z.strictObject({
  produtoId: z.string().uuid(),
  qtd: z.number().int().min(1).max(100),
})).min(1).parse(req.body.itens)

const produtos = await prisma.produto.findMany({
  where: { id: { in: itens.map(i => i.produtoId) }, ativo: true },
  select: { id: true, precoCentavos: true },
})
if (produtos.length !== itens.length) throw new BadRequestError()
const totalCentavos = itens.reduce((s, i) =>
  s + produtos.find(p => p.id === i.produtoId)!.precoCentavos * i.qtd, 0)
```

### Fluxo, estado e workflow

| Falha | Ataque | Sinal em código |
| --- | --- | --- |
| Etapa pulada | Ir direto a `POST /checkout/confirmar` sem passar por pagamento | Máquina de estados sem validação de transição |
| Reordenação | Confirmar antes de validar endereço/estoque | Estado guardado em sessão/cookie/hidden field |
| Carrinho alterado após pagamento | `PATCH /carrinho` entre autorizar e capturar | Carrinho mutável enquanto pedido está `AGUARDANDO_PAGAMENTO` |
| Reuso de token de etapa | Reusar `stepToken` do fluxo de outro usuário | Token sem vínculo com sessão nem expiração |
| Aprovação burlada | Aprovar o próprio pedido; auto-aprovação por bug de `approverId` | Falta `CHECK (aprovador_id <> solicitante_id)` |
| Cancelar sem reverter | Cancelar assinatura mantém acesso premium; remover do time mantém permissão | Revogação em endpoint separado, sem transação |
| Trial infinito | Recriar org/e-mail com `+alias`; alterar `createdAt` | `trialEndsAt` derivado de campo mutável |
| Reembolso duplicado | Pedir estorno duas vezes; estornar mais que o pago | Sem `UNIQUE (pagamento_id)` na tabela de estorno |
| Limite não decrementado | Contador incrementado só no caminho feliz | `increment` fora da transação principal |
| Referral fraud | Auto-indicação, ciclos A→B→A, contas descartáveis | Ausência de checagem de identidade/dispositivo/pagamento antes do bônus |

Estado deve viver no servidor, e transições devem ser explícitas:

```ts
// ✅ máquina de estados fechada; transição não declarada é impossível
const TRANSICOES = {
  RASCUNHO:            ['AGUARDANDO_PAGAMENTO', 'CANCELADO'],
  AGUARDANDO_PAGAMENTO:['PAGO', 'CANCELADO', 'EXPIRADO'],
  PAGO:                ['ENVIADO', 'ESTORNADO'],
  ENVIADO:             ['ENTREGUE'],
  ENTREGUE:            [],
  CANCELADO: [], EXPIRADO: [], ESTORNADO: [],
} as const

// e a transição é atômica e condicionada ao estado atual
const r = await prisma.pedido.updateMany({
  where: { id, tenantId, status: 'AGUARDANDO_PAGAMENTO' },
  data: { status: 'PAGO' },
})
if (r.count !== 1) throw new ConflictError('transição inválida')
```

O `where` com o estado de origem faz a transição ser atômica: resolve simultaneamente o problema de
lógica (só se sai de `AGUARDANDO_PAGAMENTO`) e o de concorrência (dois callbacks simultâneos só
conseguem um `count: 1`).

### Callbacks de gateway de pagamento

O endpoint que o gateway chama é **público, não autenticado e conhecido**. Três checagens são
obrigatórias e a terceira é a mais esquecida:

1. **Assinatura**, sobre o corpo **cru** (não o JSON reserializado):
   ```ts
   // ✅ Stripe: raw body + tolerância de replay (300s por padrão)
   const evento = stripe.webhooks.constructEvent(req.rawBody, req.headers['stripe-signature'],
                                                 process.env.STRIPE_WEBHOOK_SECRET!)
   ```
   Em Fastify, `req.body` já é o objeto parseado — é preciso configurar
   `addContentTypeParser('application/json', { parseAs: 'buffer' })` na rota do webhook, ou a
   verificação falha (ou, pior, alguém "resolve" desligando a verificação).
2. **Idempotência**: o gateway reentrega. Chave única por `event.id`.
3. **Conciliação de valor e moeda**: o pagamento aprovado tem de bater com o pedido.
   ```ts
   // ❌ vulnerável — confia no que o callback diz
   if (evento.type === 'checkout.session.completed') await marcarPago(evento.data.object.metadata.pedidoId)

   // ✅ compara com o valor autoritativo do próprio pedido
   const s = evento.data.object
   const pedido = await prisma.pedido.findFirst({ where: { id: s.metadata.pedidoId } })
   if (!pedido || s.amount_total !== pedido.totalCentavos || s.currency !== pedido.moeda.toLowerCase())
     return reply.code(202).send()      // registra alerta; não marca pago
   ```
   Sem a terceira checagem, um atacante que consiga criar uma sessão de pagamento de R$ 1,00
   apontando para o pedido de R$ 1.000,00 (via metadata manipulada no fluxo de criação) recebe a
   mercadoria. Também vale para "pagamento parcial aceito como total".

Isso conversa diretamente com o
[Transaction Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Transaction_Authorization_Cheat_Sheet.html),
cuja regra central é **WYSIWYS** (*What You See Is What You Sign*): os dados que o usuário aprovou
são os dados que o servidor executa, gerados pelo servidor, imutáveis após a aprovação, com
verificação final imediatamente antes da execução, credencial de autorização única por transação e
com validade curta.

### Entrada não convencional

Além dos números: string truncada por limite de coluna (`VARCHAR(20)` cortando
`atacante@empresa.com.evil.com` em `atacante@empresa.com` — burla validação de domínio corporativo),
e-mail com parsing divergente entre validador e provedor
(`"user@interno.com"@externo.com`, comentários RFC 5322, encoding punycode/unicode), datas no
passado ou futuro absurdo, timezone (janela de cancelamento que abre de novo em UTC-12), arrays
vazios que fazem `reduce` sem valor inicial cair no primeiro elemento, e IDs duplicados em batch
(`[1,1,1]` processado três vezes onde a lógica assumia unicidade).

## Modelos de autorização e onde a checagem mora

| Modelo | Forma | Bom para | Custo real |
| --- | --- | --- | --- |
| **ACL** | Lista por objeto: `(objeto, sujeito, permissão)` | Compartilhamento arbitrário (Drive) | Não responde "o que o usuário pode ver?" sem varrer |
| **RBAC** | Papel → conjunto de permissões | Times pequenos, poucos papéis | *Role explosion*: `admin_financeiro_br_leitura`. Não modela "dono deste documento" |
| **ABAC** | Política sobre atributos (usuário, recurso, ambiente) | Regras finas: horário, IP, valor, classificação | Difícil de auditar; explosão combinatória de políticas |
| **ReBAC** (Zanzibar) | Tuplas de relação + grafo | Hierarquia, herança, compartilhamento, multi-tenant B2B | Serviço externo no caminho crítico; consistência eventual |
| **Escopos OAuth** | `pedidos:ler` no token | Autorização de **cliente/aplicação** | **Não é autorização de usuário sobre objeto** — erro comum |

Esse último ponto é uma confusão frequente e cara: um token com escopo `pedidos:ler` diz que *o
aplicativo* pode ler pedidos. Não diz *quais* pedidos. Escopo nunca substitui BOLA. Veja
`references/api-e-graphql.md` e `references/autenticacao-e-sessao.md`.

O [Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)
recomenda preferir ABAC/ReBAC a RBAC em aplicações novas, por lógica booleana rica, menor explosão
de papéis e melhor suporte a multi-tenancy e requisições cross-organização.

Sobre ReBAC: modelos derivados do [Zanzibar](https://research.google/pubs/pub48190/) (Google, 2019)
— **OpenFGA**, **SpiceDB**, Permify — armazenam tuplas `documento:123#editor@usuario:ana` e resolvem
`Check(usuario:ana, editor, documento:123)` percorrendo o grafo, incluindo herança
(`pasta:x#editor` implica `documento:y#editor` para documentos na pasta). O detalhe operacional que
importa em revisão é **consistência**: Zanzibar usa *zookies* (token de versão) para pedir "resultado
não mais antigo que este momento"; SpiceDB expõe o equivalente como **ZedToken** e níveis
`minimize_latency` / `at_least_as_fresh` / `fully_consistent`; OpenFGA oferece
`HIGHER_CONSISTENCY` como flag opcional. **Sem passar o token, a checagem pode usar um snapshot
anterior à revogação** — a permissão que você acabou de remover ainda vale por alguns segundos.
Para revogação de acesso sensível (demissão, remoção de membro, documento confidencial), use o modo
consistente e aceite a latência.

### Onde a checagem deve viver

O argumento a favor de política centralizada é forte:

```ts
// ❌ regra espalhada — 40 cópias, 39 corretas
if (user.role === 'admin' || pedido.clienteId === user.id) { /* ... */ }

// ✅ uma função, um lugar, testável isoladamente
if (!can(user, 'pedido:ler', pedido)) throw new ForbiddenError()
```

Ganhos: um lugar para auditar, um lugar para testar, um lugar para mudar quando o produto inventar o
papel "financeiro só leitura". `grep -rn "role ===" src/` e `grep -rn "isAdmin" src/` medem
diretamente a dispersão — quanto maior o número, maior o risco.

O custo, dito honestamente: (1) a função central precisa do **objeto carregado**, o que muitas vezes
significa buscar antes de autorizar, reabrindo o "check depois" — por isso política central e escopo
na query são complementares, não alternativas; (2) políticas dinâmicas ficam difíceis de otimizar em
listagem (você não pode chamar `can()` para 10.000 linhas — precisa da versão "filtro", ex.
`ListObjects` no OpenFGA ou tradução da política para `WHERE`); (3) um serviço externo de
autorização entra no caminho crítico, com latência, disponibilidade e um novo modo de falha; (4)
indireção dificulta ler o código e esconde a regra de quem revisa. Para um monólito com 3 papéis,
uma tabela de permissões em código e uma função `can()` bem testada bate qualquer serviço externo.

### Deny by default e fail-closed

`Deny by default` significa que a ausência de política é negação, não permissão. Isso precisa ser
mecânico (o hook `onRoute` mostrado acima), não cultural.

`Fail-closed` significa que **erro é negação**:

```ts
// ❌ fail-open — o serviço de autorização cai e todo mundo vira admin
try {
  return await fga.check(user, action, object)
} catch {
  return true                       // "para não derrubar o produto"
}

// ❌ variante sutil: erro capturado em nível acima libera o fluxo
const permitido = await can(user, 'x', obj).catch(() => true)

// ✅ fail-closed com sinal
try {
  return await fga.check(user, action, object)
} catch (e) {
  logger.error({ err: e, user: user.id, action }, 'authz indisponível')
  throw new ServiceUnavailableError()   // 503, não acesso liberado
}
```

Variações de fail-open que aparecem em código real: `if (!user) return true` num helper chamado antes
do carregamento da sessão; comparação com `undefined` (`user.role !== 'blocked'` passa quando `role`
é `undefined`); política em YAML que não carregou e virou objeto vazio; feature flag de "modo
manutenção" que desliga guards; e o caso mais comum de todos — o `catch (e) { /* ignora */ }` em
volta de uma checagem que lança.

### Delegação, herança e revogação

Perguntas que revelam bugs em quase todo sistema de permissões que já existe:

- **Quem pode conceder?** Um `member` pode se promover a `owner`? Um `admin` pode criar outro
  `admin`? Regra: a concessão precisa de permissão explícita (`role:atribuir`) **e** de um teto —
  ninguém concede permissão que não tem. Procure `update({ data: { role } })` sem checagem de teto.
- **Herança por grupo/organização.** Se o usuário sai do grupo, o acesso derivado cai imediatamente
  ou só na próxima renovação de token? Permissão em claim de JWT com TTL de 24h significa **24h de
  acesso após a demissão**. Ou o TTL é curto e a permissão é reavaliada a cada request, ou existe uma
  denylist de sessões. Veja `references/autenticacao-e-sessao.md`.
- **Convite pendente.** Convite aceito depois que o convidante perdeu o direito de convidar; convite
  para e-mail que depois muda de dono; link de convite sem expiração.
- **Acesso residual.** Remover do time apaga a `membership`, mas: os ACLs diretos em documentos
  ficam; o token de API criado por ele continua válido; o webhook que ele criou continua entregando;
  o compartilhamento público que ele gerou continua ativo; o link de export assinado continua
  funcionando. **Revogação precisa ser uma transação que varre todas as fontes de permissão.**
- **Impersonation / "logar como cliente".** É a funcionalidade mais perigosa de qualquer SaaS.
  Precisa de: papel dedicado, aprovação/justificativa, expiração curta, banner visível, log
  imutável, escopo reduzido (nunca permitir trocar senha ou exportar dados durante a impersonação),
  e **proibição de impersonar outro admin** — senão vira escalada.

## Autorização fora do request: jobs, filas, webhooks, cron

É onde a autorização "some", porque não existe `req.user` para consultar. Padrões de falha:

- **Job que recebe só o ID.** `enviarRelatorio(pedidoId)` busca com o cliente global e envia para
  quem estiver no payload. Se o `pedidoId` puder ser influenciado pelo usuário, é IDOR assíncrono —
  e sem nenhum log de acesso negado.
- **Fila com payload confiável.** Quem enfileira é código nosso, então "o payload é confiável" — até
  que um endpoint permita enfileirar com parâmetros do cliente. Trate o payload da fila como entrada
  não confiável: revalide e reescope.
- **Cron que roda como superusuário.** Ignora RLS, atravessa tenants, e um bug de `WHERE` afeta a
  base inteira.
- **Webhook de saída.** O tenant configura a URL; o conteúdo precisa ser filtrado pelo escopo do
  tenant no momento do fan-out, não no momento da geração do evento. (Também é vetor de SSRF: veja
  `references/ssrf-e-camada-http.md`.)
- **Serviço interno sem authz.** "Está na VPC" — até que um SSRF na borda transforme qualquer serviço
  interno em endpoint público. mTLS ou token de serviço com escopo, sempre.

Padrão correto: **o job carrega o principal, não só o objeto.**

```ts
// ✅ o contexto de autorização viaja com o trabalho e é revalidado na execução
await fila.add('gerar-relatorio', {
  tenantId: req.scope.tenantId,
  solicitanteId: req.user.id,
  filtros,
})

// worker
async function handler(job) {
  const { tenantId, solicitanteId, filtros } = job.data
  const membership = await prisma.membership.findFirst({
    where: { userId: solicitanteId, tenantId },   // revalida: pode ter sido removido
  })
  if (!membership) return                          // não gera, não envia
  const db = prismaFor(tenantId)
  // ...
}
```

A revalidação importa: entre enfileirar e executar podem passar horas, e o usuário pode ter sido
desligado. Relatório agendado que continua chegando no e-mail do ex-funcionário é um achado real,
frequente e de impacto alto.

## Como testar autorização de forma sistemática

### A matriz

Monte, para o sistema em revisão, a matriz **papel × endpoint × propriedade do objeto**. As colunas
mínimas de papel: anônimo, usuário comum do tenant A, admin do tenant A, usuário do tenant B, admin
do tenant B, usuário desativado/removido, token de API com escopo reduzido, e (se existir) suporte
interno. As linhas: cada rota, com cada verbo.

Para cada célula, o esperado é um de: `200` (permitido), `403` (proibido, existência pública),
`404` (proibido, existência sigilosa), `401` (não autenticado). Toda célula sem valor esperado
definido é uma decisão de produto que ninguém tomou — e provavelmente um bug.

Regra de ouro do teste manual: **duas contas em cada dimensão**. Dois usuários no mesmo tenant (pega
horizontal), dois tenants (pega cross-tenant), dois níveis (pega vertical). Com uma conta só você não
encontra nada.

### A suíte executável — o entregável de maior valor

Uma revisão de autorização produz uma lista de achados que envelhece em uma sprint. Uma **suíte de
teste de autorização** produz um regressor permanente: quando alguém adicionar `/api/v2` ou trocar
`findFirst` por `findUnique`, o CI reprova. Se você só puder entregar uma coisa desta revisão,
entregue isto.

```ts
// test/authz-matrix.test.ts — Vitest
import { beforeAll, describe, expect, test } from 'vitest'
import { build } from '../src/app'
import { seedFixtures, type Fixtures } from './helpers/seed'

type Ator = 'anon' | 'userA' | 'adminA' | 'userB' | 'adminB' | 'removido'

interface Caso {
  nome: string
  method: 'GET' | 'POST' | 'PATCH' | 'DELETE'
  path: (f: Fixtures) => string
  body?: (f: Fixtures) => unknown
  esperado: Record<Ator, number>       // status esperado por ator
}

const CASOS: Caso[] = [
  {
    nome: 'ler pedido do tenant A',
    method: 'GET',
    path: (f) => `/api/pedidos/${f.pedidoDoUserA.id}`,
    esperado: { anon: 401, userA: 200, adminA: 200, userB: 404, adminB: 404, removido: 403 },
  },
  {
    nome: 'ler pedido de outro usuário no mesmo tenant',
    method: 'GET',
    path: (f) => `/api/pedidos/${f.pedidoDeOutroUserA.id}`,
    esperado: { anon: 401, userA: 404, adminA: 200, userB: 404, adminB: 404, removido: 403 },
  },
  {
    nome: 'promover usuário a admin',
    method: 'PATCH',
    path: (f) => `/api/usuarios/${f.userA.id}`,
    body: () => ({ role: 'ADMIN' }),
    esperado: { anon: 401, userA: 403, adminA: 200, userB: 404, adminB: 404, removido: 403 },
  },
  {
    nome: 'mass assignment: alterar o próprio papel via /me',
    method: 'PATCH',
    path: () => '/api/me',
    body: () => ({ nome: 'x', role: 'ADMIN', tenantId: '00000000-0000-0000-0000-000000000000' }),
    // 400: o schema estrito rejeita chaves desconhecidas
    esperado: { anon: 401, userA: 400, adminA: 400, userB: 400, adminB: 400, removido: 403 },
  },
]

describe('matriz de autorização', () => {
  let app: Awaited<ReturnType<typeof build>>
  let f: Fixtures
  const tokens: Record<Ator, string | null> = {} as never

  beforeAll(async () => {
    app = await build()
    f = await seedFixtures(app)
    Object.assign(tokens, f.tokens, { anon: null })
  })

  for (const caso of CASOS) {
    for (const [ator, status] of Object.entries(caso.esperado) as [Ator, number][]) {
      test(`${caso.method} ${caso.nome} | ${ator} -> ${status}`, async () => {
        const res = await app.inject({
          method: caso.method,
          url: caso.path(f),
          payload: caso.body?.(f),
          headers: tokens[ator] ? { authorization: `Bearer ${tokens[ator]}` } : {},
        })
        expect(res.statusCode).toBe(status)
        if (status !== 200) expect(res.body).not.toContain(f.segredoDoTenantA)
      })
    }
  }
})

// Guarda estrutural: nenhuma rota pode existir sem política declarada.
test('toda rota registrada declara uma policy', async () => {
  const app = await build()
  const semPolicy = app.routes.filter((r) => !r.config?.policy && !r.url.startsWith('/health'))
  expect(semPolicy.map((r) => `${r.method} ${r.url}`)).toEqual([])
})
```

Três propriedades que fazem essa suíte valer o esforço:

1. **A tabela é a especificação.** Revisar `CASOS` é mais rápido e mais confiável que ler 40 handlers.
2. **O último teste é o mais valioso**: pega a rota *nova* que ninguém lembrou de adicionar à matriz.
   O padrão "enumerar rotas do framework e exigir política" existe em Fastify (`app.routes` /
   `printRoutes`), Express (`app._router.stack`), NestJS (`DiscoveryService`), Spring
   (`RequestMappingHandlerMapping.getHandlerMethods()`) e Django (`get_resolver().url_patterns`).
3. **A asserção negativa** (`not.toContain(segredo)`) pega o caso em que o status está certo mas o
   corpo de erro vazou dados.

### Ferramentas

- **Burp Autorize** (extensão BApp): grava a sessão de um usuário de baixo privilégio e reenvia todo
  o tráfego do usuário privilegiado com aquele cookie/token, comparando as respostas.
  Classifica em *Bypassed!* / *Enforced!* / *Is enforced??? (please configure enforcement detector)*.
  É a ferramenta de melhor custo-benefício para IDOR/BFLA em aplicação com muitas telas.
- **AuthMatrix** (BApp): monta a matriz papel × request explicitamente e roda como regressão. Mais
  trabalhoso de configurar, melhor como artefato repetível.
- **Burp Repeater "Send group in parallel"** para race conditions (single-packet attack nativo).
- **ZAP** com contextos e usuários múltiplos: *Access Control Testing* gera matriz e relatório.
- **Semgrep** para os padrões locais (`findUnique` sem escopo, `req.body` em `data:`, `catch` que
  retorna `true`). Não espere que ele encontre IDOR de verdade — ele encontra o *formato* do IDOR.
  Veja `references/ferramentas.md`.

## Sinais em revisão de código

| Sinal | Onde procurar | Por que importa |
| --- | --- | --- |
| `findUnique({ where: { id } })` com `id` do request | Prisma | Não aceita escopo; IDOR clássico |
| `data: req.body`, `Object.assign(x, req.body)` | qualquer ORM | Mass assignment |
| `parse(req.body)` sem atribuir o resultado | Zod/Yup | Valida uma coisa, grava outra |
| `include:` sem `select` aninhado | Prisma | Excessive data exposure |
| `SELECT *` em endpoint de API | SQL cru | Idem |
| `where: req.query.where` / filtro do cliente no ORM | Prisma/TypeORM | IDOR generalizado |
| `if (user.role === '...')` fora de um módulo de policy | todo o repo | Dispersão; conta quantas ocorrências |
| `catch { return true }`, `.catch(() => true)` | guards | Fail-open |
| `x !== 'blocked'` em campo possivelmente `undefined` | guards | Fail-open por comparação frouxa |
| `req.headers['x-tenant-id']`, `x-user-id`, `x-org` | middleware | Escopo controlado pelo cliente |
| `findFirst(...)` seguido de `update(...)` | serviços | Check-then-act → race |
| `count()` comparado a limite, depois `create` | serviços | Limit overrun |
| `SET app.tenant_id` sem `LOCAL` / `set_config(..., false)` | SQL/infra | Vazamento cross-tenant por pool |
| `USING (true)` em `CREATE POLICY` | migrations | Anula RLS (permissive = OR) |
| `ENABLE ROW LEVEL SECURITY` sem `FORCE` + app conecta como owner | migrations | RLS decorativa |
| Rota adicionada sem entrada no `matcher` do middleware | Next.js | BFLA |
| `preco`, `total`, `desconto`, `currency` no schema de entrada | DTOs | Manipulação de preço |
| `Float`/`number` para dinheiro | schema Prisma | Erro de arredondamento explorável |
| Webhook handler sem `constructEvent`/HMAC ou sem conferir valor | pagamentos | Pedido pago de graça |
| `let contexto` / singleton guardando dado de request | módulos | Vazamento cross-tenant sob concorrência |
| Job/fila recebendo só o ID do objeto | workers | Authz ausente fora do request |
| `role` em claim de JWT com TTL longo | auth | Revogação não surte efeito |

## Falsos positivos comuns

Reportar autorização quebrada onde ela não está quebrada queima a confiança de quem lê a revisão.
Antes de escrever o achado, elimine estes casos:

1. **O repository já injeta o escopo.** O handler faz `pedidoRepo.byId(id)` sem `if` nenhum — e está
   correto, porque `pedidoRepo` foi construído com `req.scope`. **Vá ler a construção do repo.** Este
   é, de longe, o falso positivo número um em código bem estruturado, e é exatamente o cenário em
   que o benchmark da Semgrep mediu 0% de acurácia para modelos.
2. **RLS ativa no banco.** Query sem `WHERE tenant_id` pode estar protegida por política do Postgres.
   Confirme com `\d+ tabela` / `pg_policies` antes de reportar — e aí o achado, se houver, é outro:
   a aplicação conecta como owner sem `FORCE`, ou existe `USING (true)`.
3. **Middleware/guard cobre o prefixo inteiro.** `@UseGuards(AdminGuard)` no controller, `fastify
   .register(rotasAdmin, { prefix: '/admin', preHandler: exigeAdmin })`, `router.use(requireAuth)`
   antes das rotas. Verifique a ordem de registro (em Express, `router.use` depois da rota não
   protege) e o escopo do prefixo.
4. **ID público por design.** Slug de post, ID de produto em e-commerce, ID de vídeo, avatar, perfil
   público. IDOR exige que o objeto *deveria* ser restrito.
5. **Endpoint interno atrás de mTLS ou service mesh**, não exposto pelo ingress. Confirme no
   manifesto/ingress antes de reportar — mas registre como "depende de controle de rede", porque um
   SSRF muda o veredito.
6. **`findUnique` por chave composta que já inclui o tenant**:
   `where: { tenantId_slug: { tenantId, slug } }` está correto e parece um `findUnique` cru.
7. **Race condition impossível porque o banco tem constraint.** `findFirst` + `create` com
   `UNIQUE (usuario_id, cupom_id)` no schema resulta em erro `P2002`, não em duplicata. Verifique o
   `schema.prisma` / a migration antes de reportar.
8. **Race condition irrelevante.** Duplicar um evento de analytics, um "visualizado em", um cache
   warm-up. Sem impacto de segurança, não vale o custo de um lock. Priorize por dinheiro, limite e
   permissão.
9. **`403` vs `404`**: devolver `403` onde você esperava `404` é decisão de produto, não
   vulnerabilidade — a menos que a existência do objeto seja sigilosa (documento privado, e-mail
   cadastrado). Reporte como oráculo de enumeração, severidade baixa, não como broken access control.
10. **Frontend escondendo o botão** *além* da checagem de servidor: isso é UX correta, não
    "segurança por obscuridade". Só é achado quando é a **única** camada.
11. **Admin com acesso total ao tenant.** Um `OWNER` que lê o pedido de qualquer membro do próprio
    tenant costuma ser requisito, não bug. Confirme a matriz de papéis antes.
12. **`Object.assign` sobre um DTO já validado**, não sobre `req.body`: se a origem é o resultado do
    `parse()`, não há mass assignment.

## Fontes

- [OWASP Top 10:2025 — A01 Broken Access Control](https://owasp.org/Top10/2025/A01_2025-Broken_Access_Control/)
  (40 CWEs, 32.654 CVEs; SSRF absorvida nesta categoria)
- [OWASP Top 10:2025 — índice das categorias](https://owasp.org/Top10/2025/)
- [OWASP API Security Top 10 2023 — API1 BOLA](https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/),
  [API3 BOPLA](https://owasp.org/API-Security/editions/2023/en/0xa3-broken-object-property-level-authorization/),
  [API5 BFLA](https://owasp.org/API-Security/editions/2023/en/0xa5-broken-function-level-authorization/)
- [OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)
- [OWASP Insecure Direct Object Reference Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Insecure_Direct_Object_Reference_Prevention_Cheat_Sheet.html)
- [OWASP Mass Assignment Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html)
- [OWASP Transaction Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Transaction_Authorization_Cheat_Sheet.html)
- [PortSwigger Web Security Academy — Access control vulnerabilities](https://portswigger.net/web-security/access-control)
- [PortSwigger Web Security Academy — Business logic vulnerabilities](https://portswigger.net/web-security/logic-flaws)
- [PortSwigger Web Security Academy — Race conditions](https://portswigger.net/web-security/race-conditions)
- [James Kettle — Smashing the state machine: the true potential of web race conditions](https://portswigger.net/research/smashing-the-state-machine)
  (Black Hat USA / DEF CON 31, 2023 — single-packet attack)
- [James Kettle — The single-packet attack: making remote race-conditions 'local'](https://portswigger.net/research/the-single-packet-attack-making-remote-race-conditions-local)
- [PostgreSQL — Row Security Policies](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [Prisma — client extension de Row Level Security (exemplo oficial)](https://github.com/prisma/prisma-client-extensions/tree/main/row-level-security)
- [Zod — guia de migração v4](https://zod.dev/v4/changelog) (`z.strictObject`, `.strict()` deprecado)
- [CVE-2025-29927 — Next.js middleware authorization bypass](https://nvd.nist.gov/vuln/detail/CVE-2025-29927)
  ([análise técnica, ProjectDiscovery](https://projectdiscovery.io/blog/nextjs-middleware-authorization-bypass))
- [CVE-2022-4037 — GitLab, race condition na troca de e-mail](https://nvd.nist.gov/vuln/detail/CVE-2022-4037)
- [Google Zanzibar: A Global Authorization System](https://research.google/pubs/pub48190/)
  · [SpiceDB — conceitos Zanzibar/ZedToken](https://authzed.com/docs/spicedb/concepts/zanzibar)
- [HackerOne — Hacker-Powered Security Report, 9ª edição (2025)](https://www.hackerone.com/report/hacker-powered-security)
- [Semgrep — Can LLMs Detect IDORs? Understanding the Boundaries of AI Reasoning (2025)](https://semgrep.dev/blog/2025/can-llms-detect-idors-understanding-the-boundaries-of-ai-reasoning/)
- CWE: [CWE-639](https://cwe.mitre.org/data/definitions/639.html) (Authorization Bypass Through
  User-Controlled Key), [CWE-862](https://cwe.mitre.org/data/definitions/862.html) (Missing
  Authorization), [CWE-863](https://cwe.mitre.org/data/definitions/863.html) (Incorrect
  Authorization), [CWE-915](https://cwe.mitre.org/data/definitions/915.html) (Mass Assignment),
  [CWE-367](https://cwe.mitre.org/data/definitions/367.html) (TOCTOU),
  [CWE-841](https://cwe.mitre.org/data/definitions/841.html) (Improper Enforcement of Behavioral
  Workflow)
