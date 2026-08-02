# SSRF e camada HTTP

Este arquivo cobre **o servidor como cliente HTTP** (SSRF) e **os ataques que exploram a
infraestrutura entre o usuário e a aplicação**: proxy reverso, cache, CDN, load balancer e
filesystem. Abra-o quando o código faz uma requisição para uma URL que o usuário influencia,
quando você está revisando comportamento de cache/CDN, quando a aplicação lê ou grava caminho de
arquivo derivado de input, ou quando o bug envolve headers de encaminhamento (`Host`,
`X-Forwarded-*`).

No **OWASP Top 10:2025**, SSRF deixou de ser categoria própria: a antiga `A10:2021 – SSRF` foi
absorvida por [`A01:2025 – Broken Access Control`](https://owasp.org/Top10/2025/). Isso não
diminui o impacto — só reconhece que SSRF é, na prática, um bypass de controle de acesso de rede.
CWEs relevantes deste arquivo: CWE-918 (SSRF), CWE-444 (request smuggling), CWE-22 (path
traversal), CWE-434 (upload irrestrito), CWE-601 (open redirect), CWE-93/CWE-113 (CRLF /
response splitting), CWE-524/CWE-525 (cache).

Assuntos vizinhos, não repetidos aqui: XXE e injeção em geral (`references/injecao.md`), XSS
armazenado via SVG no navegador (`references/xss-e-navegador.md`), controle de acesso a nível de
objeto (`references/autorizacao-e-logica-de-negocio.md`), SSRF disparado por GraphQL/webhook de
API (`references/api-e-graphql.md`), SSRF em ferramenta de agente/MCP (`references/llm-e-ia.md`),
gestão de credencial exposta pelo metadata service (`references/criptografia-e-segredos.md`).

## Índice

- [Por que SSRF é crítico hoje](#por-que-ssrf-é-crítico-hoje)
- [Superfícies onde SSRF nasce](#superfícies-onde-ssrf-nasce)
- [Tipos: básico, semi-cego e cego](#tipos-básico-semi-cego-e-cego)
- [Bypasses de denylist e allowlist](#bypasses-de-denylist-e-allowlist)
- [DNS rebinding: por que "resolvi e validei" não basta](#dns-rebinding-por-que-resolvi-e-validei-não-basta)
- [Alvos internos: metadata service e localhost](#alvos-internos-metadata-service-e-localhost)
- [Defesa contra SSRF, em ordem de força](#defesa-contra-ssrf-em-ordem-de-força)
- [Implementação em Node/TypeScript](#implementação-em-nodetypescript)
- [HTTP request smuggling / desync](#http-request-smuggling--desync)
- [Web cache poisoning](#web-cache-poisoning)
- [Web cache deception](#web-cache-deception)
- [Host header attacks](#host-header-attacks)
- [Path traversal e manipulação de caminho](#path-traversal-e-manipulação-de-caminho)
- [Upload de arquivo](#upload-de-arquivo)
- [Open redirect e derivados](#open-redirect-e-derivados)
- [Miscelânea da camada HTTP](#miscelânea-da-camada-http)
- [Sinais em revisão de código](#sinais-em-revisão-de-código)
- [Falsos positivos comuns](#falsos-positivos-comuns)
- [Fontes](#fontes)

## Por que SSRF é crítico hoje

O motivo é arquitetural, não técnico: **a rede interna autoriza pela origem**. O Redis em
`localhost:6379` não pede senha porque "só a aplicação alcança". O painel `/admin` do serviço
interno confia porque o pacote veio de dentro da VPC. O metadata service da cloud entrega
credencial IAM para *qualquer* processo que consiga fazer um GET em `169.254.169.254`. Quando
você dá ao atacante a capacidade de escolher o destino de uma requisição feita pelo servidor,
você lhe empresta a identidade de rede da aplicação inteira.

Casos recentes que mostram a forma do impacto:

- **CVE-2025-61882 (Oracle E-Business Suite, CVSS 9.8)** — cadeia pré-autenticada explorada em
  massa pelo grupo Cl0p desde agosto/2025: SSRF em `/configurator/UiServlet` → CRLF injection
  dentro do payload SSRF (permite injetar headers arbitrários na requisição de saída) → abuso de
  conexão persistente → bypass do filtro de autenticação via path traversal → XSLT não confiável →
  RCE. É o arquétipo: SSRF é a *porta*, não o dano.
- **CVE-2026-5205 (Chatwoot 4.11.0–4.11.2)** — o disparo de webhook (`Webhooks::Trigger`) aceita o
  argumento `url` sem restringir o destino. SSRF **cego** e autenticado (CVSS 6.3): a resposta não
  volta ao chamador, o que o torna útil para alcançar serviço interno sem auth, não para ler
  metadata em banda.
- **CVE-2026-4789 (Kyverno)** — usuário com permissão namespace-scoped faz o admission controller
  emitir requisições arbitrárias, contornando o RBAC do Kubernetes inteiro.
- **CVE-2026-27826 (MCP Atlassian)** — SSRF não autenticado via headers `X-Atlassian-Jira-Url` /
  `X-Atlassian-Confluence-Url`; a correção inicial foi contornada por **DNS rebinding**.
- **CVE-2026-33626 (LMDeploy)** — o endpoint de vision-LLM busca a imagem por URL fornecida
  (`load_image`) e vira scanner da rede interna.

Note o padrão dos dois últimos: as superfícies de SSRF mais novas são **integrações e ferramentas
de agente**, onde "buscar uma URL" é a feature.

## Superfícies onde SSRF nasce

| Superfície | Por que aparece | Agravante |
| --- | --- | --- |
| URL de webhook fornecida pelo cliente | O usuário registra "para onde notificar" | O corpo é POST controlado; erro de entrega costuma ser exibido (semi-cego) |
| Importação por URL (CSV, JSON, OPML, imagem) | Feature de onboarding | Resposta frequentemente ecoada ao usuário → SSRF básico |
| "Gere um PDF/screenshot desta página" | Browser headless renderiza HTML/URL do usuário | **O vetor mais grave da lista** — veja abaixo |
| Avatar por URL / proxy de imagem | `GET url` e re-serve | Resposta ecoada, mas com `Content-Type` de imagem |
| Integração configurável (base URL de "seu servidor Jira/Grafana/S3-compatible") | Feature legítima multi-tenant | Autenticado ≠ seguro: qualquer tenant vira atacante |
| Parser de XML | XXE com entidade externa vira SSRF | Veja `references/injecao.md`; `SYSTEM "http://169.254.169.254/..."` |
| Preview de link / unfurling (chat, editor) | Busca `<title>`/OG tags | Assíncrono → normalmente cego |
| Verificação/ping de webhook ("testar conexão") | Endpoint que existe só para fazer requisição | Costuma ter menos validação que o fluxo real |
| Upload de SVG renderizado no servidor | `<image xlink:href="http://...">`, `<use href>` | Também XXE se o parser aceita DOCTYPE |
| `Referer` enviado a serviço de analytics | Analytics visita a URL logada | Clássico do PortSwigger; cego |
| Servidor de e-mail / resolvedor DNS próprio | MX/SPF/DKIM lookup com domínio do usuário | Baixo controle sobre payload |
| Health check / prova de propriedade de domínio | "vamos buscar `/.well-known/x` no seu domínio" | Redirect costuma ser seguido |

### Conversores HTML→PDF e browsers headless

Merece parágrafo próprio porque é a superfície com maior taxa de conversão em bug bounty. Quando
sua aplicação monta um HTML com dado do usuário e joga em `wkhtmltopdf`, Puppeteer ou Chromium
headless, o renderizador **é um browser completo rodando no seu servidor**, com privilégio de
processo do backend e sem as restrições do navegador do usuário:

- Uma simples HTML injection (o campo "nome da empresa" no cabeçalho da nota fiscal) vira SSRF:
  `<iframe src="http://169.254.169.254/latest/meta-data/iam/security-credentials/">` renderizado
  dentro do PDF entregue de volta ao atacante.
- O esquema `file://` funciona por padrão: `<iframe src="file:///etc/passwd">`,
  `<embed src="file:///proc/self/environ">`. `wkhtmltopdf` tem `--disable-local-file-access`
  (o próprio mantenedor avisa: *"Do not use wkhtmltopdf with any untrusted HTML"*).
  CVE-2022-35583 (CVSS 9.8) é exatamente esse padrão via iframe.
- JavaScript executa. `fetch('http://internal/api').then(r => r.text()).then(t =>
  document.body.textContent = t)` exfiltra a resposta *para dentro do PDF*, contornando qualquer
  "não ecoamos a resposta".

Mitigação real: rodar o renderizador em processo/container **sem rota para a rede interna**, com
`--disable-local-file-access` ou equivalente, sem credencial na instância, e — no Chromium —
bloqueando esquemas não-HTTP e interceptando requisições (`page.setRequestInterception(true)` no
Puppeteer, com allowlist de host). Não confie em sanitizar o HTML: a superfície é grande demais.

## Tipos: básico, semi-cego e cego

**Básico (in-band).** A resposta da requisição interna volta para o atacante, inteira ou parcial.
É o melhor cenário para quem ataca e o mais fácil de provar: peça `http://169.254.169.254/latest/meta-data/`
e veja a listagem. Impacto imediato de leitura.

**Semi-cego.** A resposta não volta, mas o comportamento observável difere. Oráculos úteis:

- **Tempo.** Porta fechada → `ECONNREFUSED` em milissegundos. Porta filtrada → timeout de vários
  segundos. Isso já permite varrer a rede interna (`10.0.0.0/8`, portas 22/80/443/6379/8080/9200).
- **Código/mensagem de erro.** "Invalid JSON" (algo respondeu HTTP) ≠ "connection refused"
  (nada ali) ≠ "unsupported content type" (respondeu, mas não é JSON).
- **Tamanho da resposta** de erro, quando ela inclui trecho do corpo remoto.
- **Amplificação por redirect.** Técnica de @shubs, #3 no *Top 10 Web Hacking Techniques of 2025*:
  encadear redirects incrementando o status code (301, 302, 303 … 307, 308, e os exóticos 305/306)
  faz certos clientes HTTP estourarem um caminho de tratamento de erro diferente, que **inclui a
  cadeia inteira de redirects e as respostas** na exceção logada ou devolvida — transformando SSRF
  cego em SSRF básico. Se você trata erro de HTTP client serializando o objeto de erro para o
  usuário, esse é o seu bug.

**Cego (out-of-band).** Nenhum sinal in-band. Detecta-se com um colaborador externo: aponte para
um host controlado e observe **DNS** (a resolução prova que o parser aceitou a URL, mesmo que a
conexão tenha sido bloqueada) e depois **HTTP** (prova que houve conexão de saída). O par
DNS-sim/HTTP-não é diagnóstico útil: indica que existe egress filtering, não que a validação
funciona. Ferramentas: Burp Collaborator, `interactsh`. SSRF cego ainda escala — POST em
`http://internal-redis:6379` sem ler resposta já é suficiente para escrita destrutiva.

## Bypasses de denylist e allowlist

A tabela existe para você **parar de escrever denylist**, não para virar checklist de correção.
Toda linha abaixo é um filtro que alguém já achou suficiente.

| Bypass | Exemplo | Contra o quê funciona |
| --- | --- | --- |
| Decimal | `http://2130706433/` | Regex `127\.0\.0\.1` |
| Octal | `http://017700000001/` | Idem; alguns parsers aceitam `0177.0.0.1` |
| Hexadecimal | `http://0x7f000001/` | Idem |
| Forma curta | `http://127.1/`, `http://10.1/` | Regex de 4 octetos |
| IPv6 loopback | `http://[::1]/`, `http://[::]/`, `http://[0:0:0:0:0:0:0:1]/` | Denylist só-IPv4 |
| IPv4-mapped em IPv6 | `http://[::ffff:127.0.0.1]/`, `http://[::ffff:7f00:1]/` | Validador que parseia como IPv6 e ignora |
| `0.0.0.0` | `http://0.0.0.0:8080/` | Denylist que só lista `127.0.0.0/8` |
| Domínio wildcard-DNS | `http://127.0.0.1.nip.io/`, `http://10-0-0-1.sslip.io/` | Validação sintática sem resolução |
| Domínio próprio apontando para interno | `A internal.attacker.com → 169.254.169.254` | Allowlist de esquema/formato |
| Redirect 302 | Host permitido responde `Location: http://169.254.169.254/` | Allowlist de host validada só na 1ª URL |
| Open redirect no próprio domínio | `https://app.com/r?to=http://169.254.169.254` | Allowlist de host que confia no próprio domínio |
| DNS rebinding | TTL 0, resposta alterna público/privado | Validação com `dns.lookup` antes de conectar |
| Credencial embutida | `http://allowed.com@169.254.169.254/` | `url.startsWith('http://allowed.com')` |
| Fragmento | `http://169.254.169.254#allowed.com` | `url.includes('allowed.com')` |
| Subdomínio confuso | `http://allowed.com.attacker.com/` | `hostname.startsWith('allowed.com')` |
| Sufixo confuso | `http://attackerallowed.com/` | `hostname.endsWith('allowed.com')` |
| Barra invertida | `http://allowed.com\@attacker.com/` | Parsers que divergem em `\` (WHATWG trata como `/`) |
| Encoding | `http://169.254.169.%32%35%34/`, duplo-encoding | Filtro que compara antes de decodificar |
| Ponto unicode | `http://169。254。169。254/` (`U+3002`) | Normalização IDN aplicada só na hora de conectar |
| Esquema alternativo | `file://`, `gopher://`, `dict://`, `ftp://`, `jar://`, `netdoc://` | Filtro que só checa host |

### Parser confusion

A raiz de metade da tabela é a mesma: **o parser que valida não é o parser que requisita**.
Orange Tsai formalizou isso em *A New Era of SSRF — Exploiting URL Parser in Trending Programming
Languages* (Black Hat USA 2017 / Black Hat Asia 2018), fuzzando os parsers de URL de Python, PHP,
Perl, Ruby, Java, JavaScript, `wget` e `curl` e encontrando divergências exploráveis em todos. Em
2025 o tema voltou como *Parser Differentials: When Interpretation Becomes a Vulnerability*
(@joernchen, #10 no Top 10 do ano).

Consequência prática, e a regra que você deve aplicar em revisão:

```ts
// ❌ vulnerável — valida com uma representação, requisita com outra
if (!userUrl.startsWith('https://api.parceiro.com')) throw new Error('host inválido')
const res = await fetch(userUrl)
// userUrl = 'https://api.parceiro.com@169.254.169.254/latest/meta-data/'
// startsWith passa; o WHATWG URL parser lê "api.parceiro.com" como userinfo.

// ✅ correto — parseie uma vez, valide o objeto parseado, requisite a partir dele
const u = new URL(userUrl)
if (u.protocol !== 'https:') throw new Error('esquema inválido')
if (u.hostname !== 'api.parceiro.com') throw new Error('host inválido')
if (u.username || u.password) throw new Error('credencial embutida')
if (u.port && u.port !== '443') throw new Error('porta inválida')
const res = await fetch(u)   // passe o objeto, não a string original
```

Compare **`u.hostname`** (nunca a string), com igualdade estrita ou `=== 'x' || endsWith('.x')`
— nunca `includes`/`startsWith`/regex.

### Esquemas alternativos

`file://` lê arquivo local — sempre bloqueie explicitamente. O interessante é `gopher://`:
o handler abre um TCP e envia **bytes arbitrários** contidos na própria URI, com CRLF
url-encodado. Isso transforma um SSRF que só faz GET em um cliente TCP genérico: dá para falar
o protocolo RESP do Redis (`SET`/`CONFIG SET dir`/`SLAVEOF`), SMTP, FastCGI, ou forjar um POST
HTTP completo com headers arbitrários — inclusive o `Metadata-Flavor: Google` que o GCP exige.
Exemplo recente: **CVE-2025-68437** (Craft CMS — a mutation GraphQL de upload de asset,
`save_<NomeDoVolume>_Asset`, aceita `url` no input `_file` e a busca via curl). `dict://` faz o
mesmo de forma mais limitada; `jar://` (Java) baixa e descompacta.

Em Node não há handler nativo para nenhum desses em `fetch`/`undici` — o risco entra por
bindings de libcurl (`node-libcurl`) e por chamar `curl` via shell. Em PHP/Java/Python o risco é
padrão. **Allowlist de esquema (`http:`/`https:` e nada mais) é obrigatória**, e não deve ser
implementada por denylist.

## DNS rebinding: por que "resolvi e validei" não basta

O padrão inseguro mais comum em correção de SSRF:

```ts
// ❌ vulnerável a TOCTOU / DNS rebinding
const { address } = await dns.promises.lookup(new URL(userUrl).hostname)
if (isPrivate(address)) throw new Error('destino interno')
const res = await fetch(userUrl)   // <- resolve DNS DE NOVO
```

Existem **duas resoluções**: a sua, na validação, e a do cliente HTTP, no `connect`. O atacante
controla o servidor autoritativo do domínio, publica TTL 0 e alterna as respostas: a primeira
consulta devolve `93.184.216.34` (público, passa na validação), a segunda devolve
`169.254.169.254`. A janela entre as duas resoluções é a vulnerabilidade — CWE-367 aplicado a
DNS. Não é teórico: é como o fix inicial do **CVE-2026-27826** (MCP Atlassian) foi contornado, e
está no advisory do Craft CMS (`GHSA-gp2f-7wcm-5fhx`, "Cloud Metadata SSRF Protection Bypass via
DNS Rebinding").

Só duas correções funcionam:

1. **Pinning**: resolver uma vez, validar o IP, e forçar o cliente a conectar **naquele IP**
   (mantendo o `Host`/SNI original). Em Node isso é o parâmetro `lookup`.
2. **Validar no `connect`**: interceptar a resolução do próprio cliente e reprovar ali. Como o
   valor validado é exatamente o valor usado, não há janela.

A opção 2 é mais simples de acertar e é a que o código abaixo implementa. E note o efeito
colateral bom: **ela também cobre redirects**, porque cada novo destino passa por um novo
`connect`.

## Alvos internos: metadata service e localhost

| Cloud | Endpoint | Proteção nativa |
| --- | --- | --- |
| AWS | `169.254.169.254`, IPv6 `[fd00:ec2::254]` | IMDSv2 (token via PUT + header) |
| GCP | `169.254.169.254`, `metadata.google.internal` | Header `Metadata-Flavor: Google` obrigatório desde 2019; requisições com `X-Forwarded-For` são rejeitadas |
| Azure | `169.254.169.254/metadata/instance?api-version=...` | Header `Metadata: true` obrigatório |
| Alibaba | `100.100.100.200` | Nenhuma por padrão (há modo hardened opt-in) |
| Kubernetes | `10.96.0.1` (kube-apiserver), Kubelet `:10250`, etcd `:2379` | RBAC/mTLS quando configurado; Kubelet read-only `:10255` costuma ser aberto |
| Docker | `/var/run/docker.sock`, `:2375` | Nenhuma; equivale a root no host |
| Serviços sem auth em `localhost` | Redis `:6379`, Elasticsearch/OpenSearch `:9200`, Consul `:8500`, Memcached `:11211`, Prometheus `:9090`, Actuator `:8080/actuator/env` | Nenhuma |

### IMDSv2 é a correção estrutural — exija-a

IMDSv1 é um GET sem header: qualquer SSRF, qualquer open proxy, qualquer HTML injection em
renderizador de PDF alcança. IMDSv2 muda três coisas ao mesmo tempo, e as três importam:

1. **É preciso um PUT** em `/latest/api/token` para obter o token. A esmagadora maioria dos
   primitivos de SSRF só produz GET.
2. **O PUT exige o header `X-aws-ec2-metadata-token-ttl-seconds`** (1–21600) e o GET seguinte
   exige `X-aws-ec2-metadata-token: <token>`. Headers customizados são o que um SSRF simples não
   consegue injetar — e é por isso que a combinação SSRF **+ CRLF injection** (como no
   CVE-2025-61882) continua perigosa.
3. **O TTL de rede da resposta do PUT é limitado por `HttpPutResponseHopLimit`** (1–64). Com o
   valor `1`, a resposta do token não sobrevive a **nenhum** salto extra — então um proxy reverso
   mal configurado ou um container em rede bridge não consegue repassar. Em ambiente de container
   com bridge, `1` costuma quebrar a aplicação legítima; o valor recomendado nesse caso é `2` —
   e nunca mais que o necessário.

Configuração (exija em revisão de IaC, veja também `references/supply-chain-e-cicd.md`):

```bash
# por instância
aws ec2 modify-instance-metadata-options \
  --instance-id i-0123456789abcdef0 \
  --http-tokens required \
  --http-put-response-hop-limit 1 \
  --http-endpoint enabled

# default da conta, por região (não afeta instâncias existentes)
aws ec2 modify-instance-metadata-defaults --http-tokens required

# enforcement: launches com http-tokens=optional passam a FALHAR
# (HttpTokensEnforced = enabled, avaliado depois da ordem de precedência)
```

Precedência dos valores no launch: **parâmetro do launch > default da conta na região > AMI**
(`imds-support=v2.0` na AMI força `HttpTokens=required` e hop limit 2). Restrinja também por IAM
com as condition keys `ec2:MetadataHttpTokens` e `ec2:MetadataHttpPutResponseHopLimit`. E se a
carga não usa credencial de instância, `--http-endpoint disabled` resolve o problema inteiro.

No GCP, o header obrigatório mata SSRF clássico — mas **não** se houver CRLF injection (permite
forjar o header) nem se os endpoints legados `v0.1`/`v1beta1` estiverem habilitados: eles não
exigem header algum. Desabilite-os explicitamente.

## Defesa contra SSRF, em ordem de força

1. **Separar a rede (a única defesa robusta).** O componente que busca URL do usuário roda em
   subnet própria, sem rota para `169.254.0.0/16`, sem rota para as subnets internas, sem
   credencial de instância, e sai obrigatoriamente por um **egress proxy** com allowlist de
   destino. Nesse desenho, um bypass de parser custa nada: o pacote não tem para onde ir. Tudo o
   que vem abaixo é mitigação de segunda linha.
2. **Allowlist de esquema + host + porta**, validada sobre o objeto `URL` parseado, com resolução
   e verificação **no momento da conexão** (não antes).
3. **Sem redirect**, ou redirect revalidado a cada salto pelo mesmo guard.
4. **Não ecoar a resposta** ao usuário — nem o corpo, nem os headers, nem o objeto de erro
   serializado (veja a técnica de redirect loop acima).
5. **Timeout curto e limite de tamanho** de resposta, para não virar oráculo de tempo nem DoS.
6. **Token de prova de intenção** para webhooks: o destino precisa devolver um nonce que você
   gerou, provando que é um endpoint que quer receber sua notificação. Recomendação explícita do
   OWASP SSRF Prevention Cheat Sheet quando não há allowlist possível.
7. **IMDSv2 obrigatório** e credencial de menor privilégio.

E a defesa que **sempre falha**: regex na string da URL. Falha porque a string não é o que o
cliente HTTP vai usar (parser confusion), porque a resolução DNS é dinâmica (rebinding), porque
a lista de representações de um IP é aberta, e porque redirects mudam o destino depois da
validação. Se você encontrar `if (/^https?:\/\/(?!127|10\.|192\.168)/.test(url))` em revisão,
trate como não-validação.

### O bug de configuração do axios que anula o filtro

```ts
// ❌ vulnerável — só um dos agentes é filtrado
await axios.get(userUrl, { httpsAgent: ssrfFilter(userUrl) })
// O servidor do atacante responde 302 de https:// para http://.
// O redirect usa o httpAgent DEFAULT, sem filtro nenhum. (Doyensec, 2023)

// ✅ correto — os dois agentes, sempre
await axios.get(userUrl, {
  httpAgent:  ssrfFilter(userUrl),
  httpsAgent: ssrfFilter(userUrl),
  maxRedirects: 0,
})
```

O pacote `request` era pior: apagava o agent (`delete request.agent`) ao trocar de protocolo,
removendo a proteção no meio do redirect (**CVE-2023-28155**). `node-fetch` falha fechado ao
trocar de protocolo. Prefira `undici`, onde `http` e `https` passam pelo mesmo dispatcher.

## Implementação em Node/TypeScript

Guard de conexão para `undici` (e portanto para o `fetch` global do Node, via `dispatcher`).
Valida **no `connect`**, o que fecha a janela de DNS rebinding e cobre cada salto de redirect.
Testado contra Node 22/24 LTS.

```ts
// safe-fetch.ts
import dns from 'node:dns'
import net from 'node:net'
import { Agent, request, type Dispatcher } from 'undici'

/** Faixas que nenhuma requisição de saída iniciada por input do usuário deve alcançar. */
const BLOQUEADOS = new net.BlockList()
// IPv4
BLOQUEADOS.addSubnet('0.0.0.0', 8)            // "this network" — 0.0.0.0 alcança o loopback
BLOQUEADOS.addSubnet('10.0.0.0', 8)           // RFC 1918
BLOQUEADOS.addSubnet('100.64.0.0', 10)        // CGNAT — usado por VPC/EKS/Alibaba metadata
BLOQUEADOS.addSubnet('127.0.0.0', 8)          // loopback
BLOQUEADOS.addSubnet('169.254.0.0', 16)       // link-local: IMDS de AWS/GCP/Azure
BLOQUEADOS.addSubnet('172.16.0.0', 12)        // RFC 1918
BLOQUEADOS.addSubnet('192.0.0.0', 24)         // IETF protocol assignments
BLOQUEADOS.addSubnet('192.168.0.0', 16)       // RFC 1918
BLOQUEADOS.addSubnet('198.18.0.0', 15)        // benchmarking
BLOQUEADOS.addSubnet('224.0.0.0', 4)          // multicast
BLOQUEADOS.addSubnet('240.0.0.0', 4)          // reservado + 255.255.255.255
// IPv6
BLOQUEADOS.addAddress('::', 'ipv6')
BLOQUEADOS.addAddress('::1', 'ipv6')
BLOQUEADOS.addSubnet('fc00::', 7, 'ipv6')     // unique local
BLOQUEADOS.addSubnet('fe80::', 10, 'ipv6')    // link-local
BLOQUEADOS.addSubnet('ff00::', 8, 'ipv6')     // multicast
BLOQUEADOS.addSubnet('64:ff9b::', 96, 'ipv6') // NAT64 — traduz para IPv4, inclusive privado
BLOQUEADOS.addSubnet('fd00:ec2::', 32, 'ipv6')// IMDS IPv6 da AWS

function ipPermitido(addr: string): boolean {
  const tipo = net.isIPv6(addr) ? 'ipv6' : 'ipv4'
  if (BLOQUEADOS.check(addr, tipo)) return false
  // IPv4-mapped: ::ffff:169.254.169.254 precisa ser reavaliado como IPv4
  if (tipo === 'ipv6') {
    const m = /^::ffff:(\d+\.\d+\.\d+\.\d+)$/i.exec(addr)
    if (m && BLOQUEADOS.check(m[1], 'ipv4')) return false
  }
  return true
}

/**
 * lookup custom: assinatura exigida pelo undici/net é (hostname, options, callback).
 * Resolvemos com all:true, descartamos o que for interno e devolvemos SÓ o que passou —
 * então o socket conecta exatamente no IP validado. Sem janela de TOCTOU.
 */
const lookupSeguro: typeof dns.lookup = ((hostname, options, callback) => {
  const cb = (typeof options === 'function' ? options : callback) as
    (err: NodeJS.ErrnoException | null, ...args: any[]) => void
  const opts = (typeof options === 'function' ? {} : options ?? {}) as dns.LookupOptions

  dns.lookup(hostname, { ...opts, all: true }, (err, enderecos) => {
    if (err) return cb(err)
    const ok = (enderecos as dns.LookupAddress[]).filter((a) => ipPermitido(a.address))
    if (ok.length === 0) {
      return cb(Object.assign(new Error(`destino interno bloqueado: ${hostname}`), {
        code: 'ESSRFBLOCKED',
      }))
    }
    return opts.all ? cb(null, ok) : cb(null, ok[0].address, ok[0].family)
  })
}) as typeof dns.lookup

export const agenteSeguro: Dispatcher = new Agent({
  connect: { lookup: lookupSeguro, timeout: 3_000 },
  headersTimeout: 5_000,
  bodyTimeout: 10_000,
})

const HOSTS_PERMITIDOS = new Set(['api.parceiro.com', 'hooks.slack.com'])
const TAMANHO_MAX = 5 * 1024 * 1024

export async function buscarUrlDoUsuario(entrada: string): Promise<string> {
  let u: URL
  try { u = new URL(entrada) } catch { throw new Error('URL inválida') }

  if (u.protocol !== 'https:') throw new Error('apenas https')
  if (u.username || u.password) throw new Error('credencial embutida na URL')
  if (u.port && u.port !== '443') throw new Error('porta não permitida')
  if (!HOSTS_PERMITIDOS.has(u.hostname)) throw new Error('host não permitido')

  const res = await request(u, {
    dispatcher: agenteSeguro,
    maxRedirections: 0,              // undici NÃO segue redirect por padrão; explicitamos
    signal: AbortSignal.timeout(10_000),
    headers: { accept: 'application/json' },
  })

  if (res.statusCode >= 300 && res.statusCode < 400) throw new Error('redirect recusado')

  let total = 0
  const partes: Buffer[] = []
  for await (const chunk of res.body) {
    total += chunk.length
    if (total > TAMANHO_MAX) { res.body.destroy(); throw new Error('resposta grande demais') }
    partes.push(chunk)
  }
  return Buffer.concat(partes).toString('utf8')
}
```

Pontos que costumam ser errados nessa implementação e valem checar em revisão:

- **`undici` ignora silenciosamente a opção `agent` do módulo `http`.** Um `http.Agent` custom
  com filtro não protege `fetch()`/`undici` — é preciso `dispatcher`. Esse é o bug do
  `GHSA-v42f-v8xc-j435` (Budibase, SSRF por DNS rebinding no conector REST).
- **`maxRedirections`** só existe no `undici`; `fetch()` global segue redirect por padrão
  (`redirect: 'follow'`). Com o guard no `connect`, seguir redirect é aceitável, mas a allowlist
  de host precisa ser reaplicada — use `redirect: 'manual'` e valide cada `Location`.
- **`net.BlockList.check` exige o `type` correto**; passar um IPv6 com `type: 'ipv4'` (default)
  retorna `false` silenciosamente.
- Se você precisa aceitar *qualquer* host público (proxy de imagem, unfurling), o allowlist de
  host cai, mas **todo o resto acima permanece** — e aí a separação de rede vira obrigatória, não
  opcional.

## HTTP request smuggling / desync

Origem: um único fluxo TCP entre front-end (CDN/proxy/LB) e back-end carrega várias requisições
por reuso de conexão. Se os dois discordam sobre **onde uma requisição termina**, o resto do que
o atacante enviou é interpretado como o *começo* da próxima requisição — que pode ser a de outro
usuário. CWE-444.

### Variantes

| Variante | Front-end usa | Back-end usa | Como surge |
| --- | --- | --- | --- |
| **CL.TE** | `Content-Length` | `Transfer-Encoding` | Front ignora TE |
| **TE.CL** | `Transfer-Encoding` | `Content-Length` | Back ignora TE |
| **TE.TE** | TE | TE | Um dos dois é enganado por TE ofuscado (`Transfer-Encoding: xchunked`, ` chunked`, `chunked\r\nTransfer-Encoding: x`, tab antes do valor) |
| **CL.0** | `Content-Length` | trata como 0 | Back-end ignora corpo em métodos/rotas que "não têm corpo" (arquivo estático, redirect) |
| **0.CL** | trata como 0 | `Content-Length` | Front ignora o corpo; precisa de *early-response gadget* para não travar |
| **H2.CL / H2.TE** | HTTP/2 | HTTP/1.1 após downgrade | O front reescreve a request h2 para h1 e confia em `content-length`/`transfer-encoding` vindos dos headers h2 |
| **Request tunnelling** | — | — | Não envenena outro usuário, mas permite ler a resposta da requisição embutida (útil quando o reuso de conexão é per-client) |
| **Client-side / browser-powered desync** | — | — | O desync acontece na conexão **do próprio navegador da vítima**, disparado por JavaScript de qualquer site; não exige servidor intermediário vulnerável |

Referências primárias, todas de James Kettle (PortSwigger):
*HTTP Desync Attacks: Request Smuggling Reborn* (2019),
*HTTP/2: The Sequel is Always Worse* (2021),
*Browser-Powered Desync Attacks* (2022) e
**[*HTTP/1 must die: the desync endgame*](https://portswigger.net/research/http1-must-die)
(6/ago/2025)** — o material atual. A tese: seis anos de correções pontuais mascararam, não
resolveram, uma falha de design do HTTP/1.1 upstream. O paper introduz **0.CL desync** com
*early-response gadgets* (por exemplo o nome reservado `/con` no IIS, que faz o servidor
responder antes de ler o corpo, quebrando o deadlock que tornava 0.CL inerte), **desync baseado
em `Expect`** — vanilla e ofuscado, produzindo 0.CL ou CL.0 em Akamai, Netlify e Cloudflare — e a
técnica **double-desync**, que converte um 0.CL em CL.0 armado envenenando a conexão em etapas.

### Impacto

Bypass de controle de acesso aplicado no front-end (`/admin` bloqueado na borda vira alcançável),
envenenamento de cache com resposta arbitrária, **captura da requisição de outro usuário**
(o prefixo smuggled faz a requisição da vítima virar corpo de um POST que sua aplicação armazena
e exibe — cookies de sessão inclusos), credential harvesting, e escalada para XSS/CSRF sem
interação. É a classe de bug que mais rende em bug bounty por unidade de esforço.

### Detecção

A técnica canônica é **por tempo**: envie um CL.TE malformado cujo corpo o back-end ficará
esperando; um atraso consistente de ~5–10s indica que o back-end travou aguardando bytes que o
front-end não vai mandar. Nunca faça isso em produção de terceiros sem autorização — pode
envenenar a conexão de usuários reais. Use a extensão **HTTP Request Smuggler** do Burp, que
implementa a detecção com as salvaguardas certas.

### Defesa

- **HTTP/2 fim a fim, sem downgrade.** Recomendação primária de Kettle. O framing binário do
  HTTP/2 tem tamanho explícito por frame; não há ambiguidade a explorar. O perigo é o front-end
  falar h2 com o cliente e h1 com o origin.
- **Rejeitar requisição ambígua** em vez de normalizar: `Content-Length` + `Transfer-Encoding`
  juntos, `Content-Length` duplicado com valores diferentes, `Transfer-Encoding` não-exatamente-
  `chunked`, corpo em método que não o requer.
- **Habilitar todas as opções de normalização e validação** no front-end **e** as de validação no
  back-end.
- **Evitar webservers de nicho** — Apache e nginx são de menor risco (recomendação literal do
  paper).
- **Desabilitar reuso de conexão upstream** se você não consegue garantir o resto (custo de
  performance real, mas elimina a classe).
- Em nginx: `proxy_http_version 1.1` com `Connection` controlado; a diretiva
  `underscores_in_headers` deve permanecer `off`; não use `ignore_invalid_headers off`.
  Em HAProxy: `option http-buffer-request` e o modo HTX (default em 2.x) já rejeitam boa parte
  das ambiguidades; `http-request deny if { req.hdr_cnt(content-length) gt 1 }` como reforço.
  ALB e Cloudflare rejeitam CL+TE simultâneos hoje, mas **isso não cobre 0.CL/`Expect`** — o
  paper de 2025 demonstra bypass em CDNs grandes.
- Em Node: o parser `llhttp` roda em modo estrito por padrão e rejeita headers malformados.
  **`insecureHTTPParser: true` (em `http.createServer` ou por requisição) desliga essa validação
  e é um achado sério em revisão** — só existe para interoperar com peer legado.

## Web cache poisoning

O cache decide o que é "a mesma resposta" usando a **cache key** — tipicamente método + host +
path + alguns query params. Tudo o que influencia a resposta mas **não** entra na chave é
*unkeyed input*, e é o material do ataque: o atacante envia a requisição com o input malicioso,
a resposta envenenada é armazenada sob a chave normal, e todo usuário subsequente recebe.

Inputs não-chaveados que funcionam com mais frequência:

| Header | Efeito típico |
| --- | --- |
| `X-Forwarded-Host` | Reescreve a base de URLs absolutas na resposta (aponta `<script src>` para o atacante) |
| `X-Forwarded-Scheme` / `X-Forwarded-Proto` | Força redirect para `http://` ou para host do atacante |
| `X-Host`, `X-Forwarded-Server` | Idem, em frameworks que os honram |
| `X-Original-URL`, `X-Rewrite-URL` | Sobrescreve o path visto pela aplicação, mantendo a chave do path original — **CVE-2018-14773** (Symfony honrava esses headers de IIS sem verificar se estava no IIS, permitindo bypass de restrição de acesso na borda) |
| Header customizado refletido | `X-Api-Version`, `X-Country` etc. injetados na resposta |
| `User-Agent` | Refletido em mensagem de erro/analytics |

Outras variantes:

- **Fat GET** — enviar corpo em um `GET`. O cache chaveia só o método+URL; a aplicação lê o corpo.
- **Cache key normalisation / cache key injection** — abusar da diferença entre como o cache e a
  origem normalizam a URL (encoding, delimitadores) para *escrever* em uma chave que não é a sua.
- **Parâmetro de query ignorado pela chave** — CDNs frequentemente removem ou reordenam params.
- **CPDoS (Cache Poisoned Denial of Service)** — não injetar payload, mas fazer a origem devolver
  erro e o cache guardá-lo. Variantes: HHO (header oversize), HMC (header meta character), HMO
  (method override). Uma resposta `400`/`404`/`204` cacheada derruba a página para todos.

Exemplos concretos e recentes, todos úteis para revisão de Next.js:

- **CVE-2024-46982** (Next.js 13.5.1–14.2.9, Pages Router, rotas SSR não dinâmicas): o header
  `x-now-route-matches` — combinado com `?__nextDataReq=1` ou com um GET em
  `/_next/data/{buildID}/pagina.json` — faz o framework classificar uma resposta SSR como SSG e
  trocar `Cache-Control: private, no-cache, no-store, max-age=0, must-revalidate` por
  `s-maxage=1, stale-while-revalidate`. Resultado: DoS (JSON servido como HTML) e XSS armazenado.
  Envenena o **cache interno** do Next, não só o CDN. Deploys na Vercel não afetados.
- **CVE-2025-49005** (Next.js 15.3.0–15.3.3, App Router, CWE-444): omissão do header `Vary` em
  cenários com middleware e redirect faz payload RSC ser cacheado e servido no lugar do HTML.
- **CVE-2025-49826** (Next.js 15.0.4-canary.51 → 15.1.8, CVSS 7.5): resposta HTTP `204` cacheada
  para página estática em `next start`/standalone com ISR, servida a todos — DoS. Corrigido em
  15.1.8.

### Defesa

1. **Resposta autenticada nunca é cacheável publicamente.** `Cache-Control: private, no-store`
   em tudo que dependa de sessão, aplicado por default no framework e não rota a rota.
2. **Não leia header de encaminhamento** para construir URL absoluta (veja a seção de Host).
   Se o framework os honra por padrão, desligue.
3. **Se um header influencia a resposta, ele precisa estar na cache key** — ou na chave custom do
   CDN, ou declarado em `Vary`. `Vary` errado é tão ruim quanto ausente: `Vary: *` desabilita o
   cache; `Vary: User-Agent` fragmenta a ponto de inutilizar.
4. **Não reflita input em resposta cacheável**, nem em header, nem em corpo.
5. Configure o CDN para **não cachear respostas de erro** (`4xx`, `5xx`, `204`) de rotas
   dinâmicas, ou com TTL de segundos.

## Web cache deception

O espelho do poisoning. Em vez de envenenar uma chave pública, o atacante faz a resposta
**privada** de outra pessoa ser guardada sob uma chave pública. O caminho clássico:

1. A vítima é induzida a abrir `https://app.com/perfil/conta.css`.
2. O CDN vê a extensão `.css`, decide "isso é estático", e cacheia — muitas vezes ignorando
   `Cache-Control` da origem, porque regras por extensão têm precedência.
3. A origem, que roteia por prefixo ou ignora o sufixo, serve `/perfil/conta` **com a sessão da
   vítima**, incluindo nome, e-mail, chave de API, token CSRF.
4. O atacante busca a mesma URL sem cookie e recebe a cópia cacheada.

O que torna isso possível é sempre uma **discrepância de parsing entre o proxy e a aplicação**:
delimitadores e normalização diferentes. A referência atual é
**[*Gotta cache 'em all: bending the rules of web cache exploitation*](https://portswigger.net/research/gotta-cache-em-all)**,
de Martin Doyhenard (PortSwigger, DEF CON 32, agosto/2024), que sistematizou a busca por
delimitadores em cada parser e mostrou que dá para chegar a **deception e poisoning arbitrários**
— não só nas rotas que por acaso toleram um sufixo. Delimitadores concretos catalogados:

| Delimitador | Onde a origem trata como fim do path | Consequência |
| --- | --- | --- |
| `;` | Spring (matrix variables) | `/perfil;x.css` → app lê `/perfil`, cache vê `.css` |
| `.` | Rails (format extension) | `/perfil.css` roteia para `/perfil` |
| `%00` | OpenLiteSpeed (trunca) | `/perfil%00.css` |
| `%0a` | nginx (regras de rewrite) | `/perfil%0a.css` |
| `%3F`, `%23` | Decodificação divergente entre Cloudflare, nginx e o parser do Node | Query/fragment "aparecem" só de um lado |
| `..%2f` | Normalização de dot-segment no cache mas não na origem (ou vice-versa) | Reescreve a cache key para um recurso popular → poisoning |

O trabalho anterior que introduziu path confusion por delimitador é *Cached and Confused: Web
Cache Deception in the Wild* (USENIX Security 2020, arXiv 1912.10190).

### Defesa

- **`Cache-Control: private, no-store` em toda resposta autenticada** — e verifique se o CDN
  respeita, porque regra por extensão de arquivo geralmente sobrepõe o header da origem.
- **Desligue no CDN o cache por extensão/tipo de arquivo** para paths dinâmicos; cacheie por
  allowlist de prefixo (`/_next/static/`, `/assets/`), nunca por sufixo.
- **Sirva estático de um host separado** (`static.app.com`) sem cookie de sessão. Elimina a
  classe inteira.
- **Faça a aplicação retornar 404 para path que não casa exatamente.** Se `/perfil/conta.css` não
  é uma rota, ela deve dar 404 — nunca servir `/perfil/conta`. Em Fastify isso é o
  comportamento padrão do router; em Rails/Spring o formato/matrix variable é o inimigo.

## Host header attacks

`Host` é input do usuário. Sempre. Em HTTP/2 o valor vem do pseudo-header `:authority`, e o Node
o expõe igualmente em `req.headers.host` — a mudança de protocolo não adiciona confiança.

### Password reset poisoning

O bug de maior impacto por menor complexidade da categoria:

```ts
// ❌ vulnerável — o link do e-mail é construído com input do atacante
app.post('/auth/reset', async (req, reply) => {
  const user = await db.user.findUnique({ where: { email: req.body.email } })
  if (!user) return reply.send({ ok: true })
  const token = await criarTokenDeReset(user.id)
  const link = `https://${req.headers.host}/reset?token=${token}`   // <-- aqui
  await enviarEmail(user.email, `Redefina sua senha: ${link}`)
  return reply.send({ ok: true })
})
```

O atacante dispara o reset **para o e-mail da vítima** com `Host: attacker.com`. A vítima recebe
um e-mail legítimo, vindo do remetente correto, e clica. O token vai para o servidor do atacante
no path da URL. Takeover de conta sem interação além do clique. Variantes: `X-Forwarded-Host`
(muitos frameworks o preferem sobre `Host`), `Host` duplicado, `Host` absoluto na request line
(`GET https://app.com/ HTTP/1.1` com um `Host:` diferente), e `X-Forwarded-Host` com valor
`app.com evil.com` quando o parsing quebra por espaço.

```ts
// ✅ correto — origem canônica vem da configuração, nunca da requisição
const BASE_URL = new URL(env.APP_PUBLIC_URL)   // ex.: https://app.exemplo.com
const link = new URL(`/reset?token=${token}`, BASE_URL).toString()
```

E, em defesa em profundidade, valide o `Host` na borda e na aplicação:

```ts
// Fastify — rejeita host desconhecido antes de qualquer handler
const HOSTS = new Set(['app.exemplo.com', 'www.app.exemplo.com'])
app.addHook('onRequest', async (req, reply) => {
  const host = (req.headers.host ?? '').split(':')[0].toLowerCase()
  if (!HOSTS.has(host)) return reply.code(421).send()  // 421 Misdirected Request
})
```

Outros usos do mesmo primitivo: **cache poisoning via Host** (a resposta cacheada passa a
referenciar scripts do atacante), **routing-based SSRF** (o front-end usa o `Host` para decidir
para qual back-end encaminhar — um `Host: 169.254.169.254` faz o *proxy* fazer o SSRF por você),
**virtual host confusion** (alcançar um vhost interno que compartilha o mesmo IP), e **bypass de
autenticação** em código que trata `Host: localhost` como "requisição interna, pode".

Regras de revisão: `Host`/`X-Forwarded-Host` nunca constrói link em e-mail, nunca vira
`redirect`, nunca decide autorização, nunca entra em resposta cacheável. Configure o vhost
default do nginx/ALB para **rejeitar** (`return 444`) em vez de cair no primeiro `server` block.

## Path traversal e manipulação de caminho

CWE-22. Ainda aparece o tempo todo, principalmente em três lugares: API de download por nome de
arquivo, extração de arquivo comprimido, e servir estático com `root` errado.

### Payloads que passam por filtros ingênuos

| Técnica | Exemplo |
| --- | --- |
| Básico | `../../../../etc/passwd` |
| Path absoluto | `/etc/passwd` (quando o código concatena mas o `path.join` do destino permite) |
| Traversal aninhado | `....//....//etc/passwd` — sobrevive a um `replace('../','')` não recursivo |
| Encoding simples | `..%2f..%2fetc/passwd` |
| Duplo encoding | `..%252f..%252fetc/passwd` — passa por proxy que decodifica uma vez |
| UTF-8 overlong | `..%c0%af..%c0%af` (`%c0%af` = `/` inválido, aceito por decoders permissivos) |
| Barra invertida | `..\..\windows\win.ini` (e `%5c`) |
| Base folder exigida | `/var/www/images/../../../etc/passwd` |
| Extensão exigida + null byte | `../../../etc/passwd%00.png` — relevante em C/PHP legado e em bindings nativos; em Node moderno `fs` rejeita `\0` com `ERR_INVALID_ARG_VALUE` |

### A correção certa em Node

O erro conceitual comum é validar a *string de entrada*. A validação tem que ser feita no
**caminho resolvido**, depois de `path.resolve` — e, se symlinks importam, depois de `realpath`.

```ts
import path from 'node:path'
import fs from 'node:fs/promises'

const BASE = path.resolve('/var/app/uploads')

// ❌ vulnerável — join não impede escapar quando o input começa com ../ ou é absoluto
const alvo = path.join(BASE, req.params.nome)

// ❌ ainda vulnerável — startsWith em string casa /var/app/uploads-evil
if (!path.resolve(BASE, nome).startsWith(BASE)) throw new Error('nope')

// ✅ correto
export async function caminhoSeguro(nome: string): Promise<string> {
  const resolvido = path.resolve(BASE, nome)
  const rel = path.relative(BASE, resolvido)
  if (rel === '' || rel.startsWith('..') || path.isAbsolute(rel)) {
    throw new Error('caminho fora da base')
  }
  // symlink dentro de BASE pode apontar para fora: revalide o caminho real
  const real = await fs.realpath(resolvido)
  const relReal = path.relative(await fs.realpath(BASE), real)
  if (relReal.startsWith('..') || path.isAbsolute(relReal)) {
    throw new Error('symlink escapa da base')
  }
  return real
}
```

Ainda melhor: **não aceite nome de arquivo**. Guarde o arquivo com um UUID gerado pelo servidor,
persista `(id, nome_original, dono)` no banco, e faça o download por `id` — assim o traversal
some junto com a IDOR (`references/autorizacao-e-logica-de-negocio.md`).

### Em Go

Go ganhou primitivas próprias, e são a resposta certa desde 2025:

```go
// Go 1.20+: rejeita caminho absoluto, ".." e nomes reservados do Windows
if !filepath.IsLocal(nome) {
    return errors.New("caminho não local")
}

// Go 1.24+: os.Root faz o confinamento no nível do syscall (openat2/O_BENEATH),
// resistente inclusive a symlink e a TOCTOU — prefira isto a checagem de string.
root, err := os.OpenRoot("/var/app/uploads")
if err != nil { return err }
defer root.Close()
f, err := root.Open(nome)   // nunca escapa da raiz, mesmo com ../ ou symlink
```

### Servir estático

- **Express**: `express.static(root)` e `res.sendFile(p, { root })` normalizam e recusam escapar
  do `root` — o pacote `send` faz a checagem. O bug entra quando alguém passa um caminho absoluto
  montado à mão para `res.sendFile(path.join(__dirname, req.params.f))` **sem** `root`. Use
  sempre a opção `root` e `dotfiles: 'deny'`.
- **`@fastify/static`**: `root` é obrigatório e o plugin recusa sair dele; `serveDotFiles`
  (default `false`) controla arquivos ocultos; `allowedPath` permite um predicado extra. Vários
  `root` em array são permitidos — cada um é validado.
- Se o arquivo é servido por nginx, a armadilha clássica é `location /static { alias /var/www/app/; }`
  **sem a barra final no `location`**: `GET /static../etc/passwd` escapa. Use
  `location /static/ { alias /var/www/app/; }` com as duas barras, ou `root` em vez de `alias`.

### Traversal em upload e em `Content-Disposition`

O `filename` do multipart é do cliente e pode conter `../` ou `\`. Nunca use como caminho —
gere o nome. Do lado da resposta, `Content-Disposition: attachment; filename="..."` com nome
não escapado permite injeção de aspas e de CRLF; use o parâmetro `filename*` de RFC 6266 com
codificação `UTF-8''` e percent-encoding, ou deixe o framework montar (`reply.download()`).

### Zip Slip e amigos

**Zip Slip** (Snyk, 2018): um arquivo dentro do zip/tar chamado `../../../../etc/cron.d/x`.
A biblioteca de extração concatena o nome à pasta de destino e escreve fora dela — de leitura de
arquivo a RCE, se você escrever em `~/.ssh/authorized_keys`, `.bashrc` ou num diretório servido.
Afetou dezenas de bibliotecas em Java, JS, Go, Python, Ruby.

```ts
// ✅ extração segura — valide CADA entry contra a base, e recuse symlink
for await (const entry of zip) {
  const destino = path.resolve(DEST, entry.fileName)
  const rel = path.relative(DEST, destino)
  if (rel.startsWith('..') || path.isAbsolute(rel)) throw new Error('zip slip')
  if (entry.isSymbolicLink?.() || entry.type === 'SymbolicLink') throw new Error('symlink no arquivo')
  if (totalDescomprimido + entry.uncompressedSize > LIMITE) throw new Error('bomba de descompressão')
  // ...
}
```

Três armadilhas além do traversal: **symlink dentro do arquivo** (extrair `link -> /etc` e depois
`link/passwd` escreve fora sem nenhum `..`), **hardlink**, e **decompression bomb** (o `42.zip`
tem 42 KB e expande para 4,5 PB). Sempre limite tamanho descomprimido total, número de entries e
profundidade de aninhamento — e prefira extrair em diretório temporário descartável dentro de um
container com quota.

## Upload de arquivo

CWE-434. É onde tudo converge: traversal, XSS armazenado, SSRF, XXE, RCE por parser, e DoS.

### Por que cada validação isolada falha

| Validação | Por que não basta |
| --- | --- |
| Extensão | É do cliente. E o parsing de extensão varia por servidor: `x.php.jpg` (Apache com `AddHandler` multi-extensão executa), `x.asp;.jpg` (IIS legado), `x.php%00.jpg`, `x.pHp`, `x.php.`, `x.php ` (espaço/ponto final removidos no Windows), `x.phtml`/`.php5`/`.phar` |
| `Content-Type` do multipart | É do cliente, texto livre |
| Magic bytes | Um **polyglot** satisfaz os dois formatos: GIFAR (GIF + JAR válidos), `GIF89a;<?php system($_GET[0]);?>` passa em `getimagesize()`, PDF que também é JavaScript válido. Magic bytes provam que *começa* como imagem, não que *é só* imagem |
| Antivírus | Pega malware conhecido, não webshell nova nem SVG com `<script>` |

Nenhuma dessas é inútil — todas juntas ainda não são suficientes se o arquivo puder ser servido
como conteúdo ativo. **A arquitetura é a defesa; a validação é a redução de ruído.**

### Tipos de arquivo perigosos por natureza

- **SVG** — é XML e é documento HTML-adjacente ao mesmo tempo: `<script>`, `on*` handlers,
  `<foreignObject>`, `<animate attributeName="href">`, CDATA com script; `<!DOCTYPE ... SYSTEM>`
  para XXE se o renderizador do servidor parseia com DTD ligado; e `xlink:href`/`<image href>`
  apontando para `http://169.254.169.254` para SSRF durante a geração de thumbnail. Se precisa
  aceitar SVG, sanitize no servidor (DOMPurify sobre jsdom com o perfil SVG, ou `svg-sanitizer`)
  **e** persista só a saída sanitizada **e** sirva de domínio separado.
- **HTML / SVG / XML** servidos do mesmo origin = XSS armazenado direto
  (`references/xss-e-navegador.md`).
- **`.htaccess` / `web.config`** — se o diretório de upload é servido por Apache/IIS, enviar um
  desses reconfigura o servidor: `AddType application/x-httpd-php .jpg` transforma todo upload
  anterior em código. Bloqueie por allowlist de extensão, não por denylist.
- **PDF** — pode conter JavaScript e ações de rede; abra só como download.
- **Arquivo comprimido** — Zip Slip e bomba (acima).

### Parsers como superfície de RCE

Se você chama ImageMagick, ffmpeg, ExifTool, Ghostscript ou LibreOffice em arquivo do usuário,
**esses binários são parte da sua superfície de ataque e precisam de patch como se fossem
dependência de aplicação** (`references/supply-chain-e-cicd.md`):

- **ImageTragick / CVE-2016-3714** (ImageMagick): delegado `https:` executava shell com o nome do
  arquivo; `push graphic-context ... 'https://x/x"|curl ...'`. Resposta correta: `policy.xml`
  restritivo desabilitando coders `MSL`, `MVG`, `EPHEMERAL`, `URL`, `HTTPS`, `TEXT`, `SHOW`,
  `WIN`, `PLT`, e limites de recurso.
- **CVE-2021-22204** (ExifTool): execução de código arbitrário ao processar anotação DjVu — usada
  em cadeia real contra GitLab.
- **ffmpeg** — demuxers HLS/concat permitem que uma "playlist" referencie `file:///etc/passwd` ou
  `http://interno/`, embutindo o conteúdo no vídeo de saída: SSRF e leitura de arquivo com o
  arquivo de entrada disfarçado de mídia. Restrinja com `-protocol_whitelist file,crypto` e
  `-f <formato esperado>`, nunca deixe autodetecção livre.

Rode todos em processo isolado, com timeout, limite de memória, sem rede e sem credencial.

### A arquitetura correta

1. **Armazene fora do webroot** — idealmente em object storage (S3/GCS), nunca em diretório
   servido diretamente pelo webserver.
2. **Nome gerado pelo servidor** (UUID). Guarde o nome original só como metadado para exibir.
3. **Extensão por allowlist**, derivada do tipo detectado no servidor (magic bytes via
   `file-type`), e reescreva a extensão para a canônica do tipo.
4. **Sirva de um domínio/bucket separado, sem cookie de sessão** (`usercontent-exemplo.net`).
   É o que neutraliza XSS armazenado: mesmo que o arquivo execute, executa em outra origem.
5. **Headers na entrega**: `Content-Disposition: attachment`, `X-Content-Type-Options: nosniff`,
   `Content-Type` derivado do tipo detectado (nunca do cliente), e
   `Content-Security-Policy: sandbox` para HTML/SVG que precisem ser exibidos.
6. **Limites**: tamanho por arquivo, número de arquivos por requisição e por usuário, tamanho
   total. No Fastify, `@fastify/multipart` com `limits: { fileSize, files, fields, parts }` —
   e trate o evento de truncamento, porque exceder o limite **não** rejeita a requisição
   automaticamente.
7. **Reprocessar em vez de confiar**: re-encodar a imagem (decode + re-encode) descarta payload
   embutido e metadado EXIF junto — é a melhor defesa contra polyglot.

### Upload direto para S3 com URL pré-assinada

Padrão certo (o arquivo não passa pela sua aplicação), mas com armadilhas específicas:

- **Presigned PUT não valida nada que você não tenha assinado.** Se você não incluiu
  `Content-Type` e `Content-Length` na assinatura, o cliente envia o que quiser, do tamanho que
  quiser. Para restringir de verdade, use **presigned POST com policy**, que suporta as
  condições `["content-length-range", 1, 5242880]` e `["starts-with", "$Content-Type", "image/"]`.
- **Nunca aceite a key vinda do cliente** — é traversal/sobrescrita de objeto alheio. Gere
  `uploads/{userId}/{uuid}`.
- **Block Public Access ligado na conta e no bucket**; ACLs desabilitadas (Object Ownership =
  *Bucket owner enforced*, default para buckets criados desde abril/2023). Política do bucket sem
  `Principal: "*"`.
- **Valide depois do upload**: um evento S3 → função que baixa, checa magic bytes, tamanho e
  re-encoda, e só então marca o registro como `disponível`. Antes disso, nada é servido.
- Expiração curta na URL pré-assinada (minutos) e escopo de uma única key.

## Open redirect e derivados

CWE-601. Sozinho, severidade baixa (phishing convincente sob o seu domínio). Em cadeia, alto:
bypass de allowlist de SSRF, roubo de token OAuth, exfiltração de token em `Referer`, e — se o
esquema não for validado — XSS via `javascript:`.

Onde nasce: `?next=`, `?returnUrl=`, `?redirect=`, `?url=`, `?dest=`, `?continue=`,
`redirect_uri` de OAuth, `RelayState` de SAML, e o redirect pós-logout.

Bypasses de validação, na ordem em que costumam funcionar:

| Payload | Contra |
| --- | --- |
| `//evil.com` | `if (!url.startsWith('http'))` — o browser trata `//` como protocol-relative |
| `/\evil.com`, `\/evil.com`, `/\/evil.com` | Parsers que normalizam `\` para `/` (WHATWG faz) |
| `https:evil.com`, `https:/evil.com` | Checagem de `//` literal |
| `https://app.com@evil.com` | `startsWith('https://app.com')` |
| `https://evil.com#app.com`, `?x=app.com` | `includes('app.com')` |
| `https://app.com.evil.com` | `startsWith(host)` |
| `https://evilapp.com` | `endsWith('app.com')` |
| `https://app.com%252eevil.com`, IDN homográfico | Decodificação divergente |
| `javascript:alert(1)`, `data:text/html,...` | Validação que só olha o host |

```ts
// ❌ vulnerável
reply.redirect(req.query.next as string)

// ✅ correto (caso comum) — só caminho relativo do próprio app
function destinoSeguro(next: unknown): string {
  if (typeof next !== 'string') return '/'
  // recusa scheme, protocol-relative, backslash e controle
  if (!/^\/[^/\\]/.test(next)) return '/'
  return next
}
reply.redirect(destinoSeguro(req.query.next))

// ✅ correto (quando precisa sair do domínio) — mapeie por identificador
const DESTINOS = { billing: 'https://billing.exemplo.com/', docs: 'https://docs.exemplo.com/' }
reply.redirect(DESTINOS[req.query.to as keyof typeof DESTINOS] ?? '/')
```

Se precisar mesmo de allowlist de domínio, valide `new URL(next, BASE).origin` contra um `Set` de
origins exatos — nunca a string. E para OAuth: **`redirect_uri` exige comparação de string exata
com o valor registrado**, sem wildcard, sem prefix match, sem porta variável. É requisito
normativo do RFC 9700 (*Best Current Practice for OAuth 2.0 Security*, jan/2025) e da OAuth 2.1;
um open redirect em qualquer path do client registrado vira roubo de `code` ou de `access_token`
(veja `references/autenticacao-e-sessao.md`).

## Miscelânea da camada HTTP

### CRLF injection e response splitting

Injetar `\r\n` em um valor que vai para header de resposta permite adicionar headers (`Set-Cookie`
de sessão fixada, `Location`) e, com `\r\n\r\n`, iniciar um corpo — a resposta "partida" pode ser
armazenada pelo cache como uma segunda resposta. Em Node, `res.setHeader()` valida e lança
`TypeError [ERR_INVALID_CHAR]` para CR/LF no valor; Fastify e Express herdam essa proteção. Então
o risco real em Node está **fora** do `setHeader`: escrita crua no socket, geração de headers em
um proxy/edge function, e — mais importante — **CRLF na requisição de *saída*** de um SSRF, que é
exatamente o elo 2 do CVE-2025-61882. Em outras linguagens (Java `HttpServletResponse` antigo,
PHP `header()` legado) a validação pode não existir.

### `Expect: 100-continue`

Historicamente ignorado em revisão; hoje é vetor de desync de primeira linha (Kettle, 2025):
front-end e back-end discordam sobre quem responde `100 Continue` e sobre se o corpo já pode ser
lido, gerando 0.CL ou CL.0 mesmo em CDNs grandes. Se você controla o edge, normalize ou remova
`Expect` na borda; se você escreve um proxy, trate `Expect` com valor diferente de exatamente
`100-continue` como requisição inválida (`417`/`400`), não como header desconhecido.

### `Range` / `Content-Range`

`Range` é parsing de input não confiável em código raramente auditado. Padrão de bug: DoS por
complexidade quadrática na mesclagem de ranges (CVE-2025-62727 em Starlette; CVE-2024-26141 e
CVE-2022-44570 em Rack, onde um `Range` bem construído faz o servidor gerar resposta
desproporcionalmente grande ou gastar CPU). Limite o número de ranges por requisição (1–2),
rejeite ranges sobrepostos, e rejeite `Range` em rotas dinâmicas.

### Headers de encaminhamento confiados sem proxy à frente

Bug comum e sério: `X-Forwarded-For` usado como base de rate limit, de IP allowlist, de
geolocalização ou de log de auditoria, em aplicação onde o cliente pode falar direto com ela — ou
onde o proxy **anexa** ao valor existente em vez de sobrescrever. `proxy_set_header X-Forwarded-For
$proxy_add_x_forwarded_for;` no nginx concatena: o cliente manda `X-Forwarded-For: 1.2.3.4` e o
nginx entrega `1.2.3.4, <ip-real>`. Se o framework pega o **primeiro** elemento, o atacante
escolheu o próprio IP — rate limit e allowlist evaporam.

```ts
// ❌ Fastify — confia em toda a cadeia; req.ip vira o valor mais à esquerda
const app = Fastify({ trustProxy: true })

// ✅ Fastify — confie apenas nos IPs/CIDRs dos SEUS proxies
const app = Fastify({ trustProxy: env.PROXY_CIDRS })      // ex.: '10.0.0.0/8,172.16.0.0/12'
// alternativa: número de saltos, quando a cadeia tem comprimento fixo
const app2 = Fastify({ trustProxy: 1 })
```

No Express, `app.set('trust proxy', ...)` aceita: `false` (default — usa
`req.socket.remoteAddress`), `true` (**perigoso**: pega o item mais à esquerda de
`X-Forwarded-For`; só é seguro se o último proxy **sobrescreve** `X-Forwarded-For`,
`X-Forwarded-Host` e `X-Forwarded-Proto`), lista de IPs/CIDRs ou os nomes pré-definidos
`loopback` (`127.0.0.1/8`, `::1/128`), `linklocal` (`169.254.0.0/16`, `fe80::/10`) e
`uniquelocal` (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `fc00::/7`), um número de saltos,
ou uma função `(ip) => boolean`. Com lista/nome, o Express caminha o `X-Forwarded-For`
**da direita para a esquerda** e para no primeiro endereço não confiável — que é o
comportamento correto.

Regra geral: para rate limit de segurança, prefira uma chave que o cliente não controla —
identidade autenticada, ou o IP da conexão quando não há proxy. Se precisar do IP real atrás de
CDN, use o header **proprietário e sobrescrito pela CDN** (`CF-Connecting-IP`,
`True-Client-IP`, `X-Azure-ClientIP`) **e** restrinja a origem por IP da CDN — caso contrário o
header é falsificável direto.

O padrão do RFC 7239 é o header **`Forwarded`**, com os parâmetros `by`, `for`, `host`, `proto`
(`Forwarded: for=192.0.2.60;proto=http;by=203.0.113.43`). Suporta identificador ofuscado, que
**deve** começar com `_` e conter só `ALPHA`, `DIGIT`, `.`, `_` e `-`. Vale conhecer porque é o
que aparece em ambiente Azure e em alguns ingress controllers; as mesmas regras de confiança
valem.

### `OPTIONS`

Dois problemas distintos. (1) Responder `OPTIONS` com `Access-Control-Allow-Origin` refletido e
`Access-Control-Allow-Credentials: true` é o bug de CORS clássico — assunto de
`references/api-e-graphql.md`. (2) `OPTIONS *` e `TRACE` habilitados expõem informação e, no caso
do `TRACE`, permitem Cross-Site Tracing; desabilite no webserver. Verifique também se o
framework responde `OPTIONS` **antes** do middleware de autenticação e se isso vaza a existência
de rotas.

## Sinais em revisão de código

| Sinal (`grep -rn`) | Suspeita | O que verificar |
| --- | --- | --- |
| `fetch(`, `axios.`, `got(`, `request(`, `http.get(`, `undici` com variável na URL | SSRF | A URL vem de input? Há allowlist sobre `new URL(...).hostname`? Redirect desligado? |
| `new URL(` seguido de `startsWith`/`includes`/`endsWith`/regex | Parser confusion | Comparação deve ser sobre `.hostname` com igualdade |
| `dns.lookup` / `dns.resolve` seguido de `fetch`/`axios` | DNS rebinding (TOCTOU) | A validação precisa estar no `connect` (`lookup` custom), não antes |
| `httpsAgent:` sem `httpAgent:` (ou vice-versa) | Bypass por redirect cross-protocol | Ambos, sempre |
| `maxRedirects`, `redirect: 'follow'`, `followRedirect` | SSRF por redirect | Deve ser `0`/`manual` ou revalidar cada salto |
| `puppeteer`, `playwright`, `wkhtmltopdf`, `chrome-headless`, `html-pdf` | SSRF/LFI por renderizador | Rede isolada, `file://` bloqueado, interceptação de request |
| `req.headers.host`, `req.hostname`, `x-forwarded-host` | Host header attack | Nunca em link de e-mail, redirect ou decisão de auth |
| `trustProxy: true`, `trust proxy', true` | Spoof de `X-Forwarded-For` | Deve ser CIDR dos proxies ou número de saltos |
| `x-forwarded-for` lido manualmente, `.split(',')[0]` | IP falsificável | Ver seção de headers de encaminhamento |
| `path.join(` com valor de `req.` | Path traversal | Precisa de `path.resolve` + `path.relative` + `realpath` |
| `res.sendFile(` sem opção `root` | Path traversal | Use `root` |
| `alias` no nginx sem barra final | Path traversal | `location /x/ { alias /y/; }` |
| `unzip`, `extract`, `tar.x`, `AdmZip`, `decompress` | Zip Slip / bomba | Validar cada entry, recusar symlink, limitar tamanho |
| `file.originalname`, `filename` do multipart usado como caminho | Traversal / sobrescrita | Nome gerado pelo servidor |
| `mimetype ===`, `.endsWith('.jpg')` como única validação | Upload perigoso | Magic bytes + allowlist + servir de outro domínio |
| `imagemagick`, `gm(`, `sharp` com `svg`, `exiftool`, `ffmpeg` | RCE por parser | Versão, `policy.xml`, `-protocol_whitelist`, isolamento |
| `redirect(` com valor de `req.query` | Open redirect | Caminho relativo ou mapa de identificadores |
| `Cache-Control` ausente em rota autenticada | Cache deception | `private, no-store` |
| `s-maxage`, `stale-while-revalidate` em resposta que varia por usuário | Cache poisoning | Header precisa estar na cache key ou em `Vary` |
| `insecureHTTPParser` | Request smuggling | Achado sério; remover |
| `X-Original-URL`, `X-Rewrite-URL` lidos pela app | Bypass de controle na borda | Remover suporte |
| `setHeader` com concatenação de input | CRLF / response splitting | Node bloqueia CR/LF; verifique proxies e outras linguagens |

Regra Semgrep de partida (as regras públicas `javascript.lang.security.audit.ssrf.*` já cobrem
`axios.get/post`, `fetch`, `http.get/request`, `needle`, `got`, `superagent`, `bent`,
`net.connect`): o valor é como *triagem*, não como veredito — o falso positivo mais comum é input
do usuário que vai no **corpo** ou no **path** de uma URL de base fixa, não no host.

## Falsos positivos comuns

- **URL de base fixa com path concatenado.** `fetch(\`https://api.interna/v1/users/${id}\`)` não
  é SSRF se `id` não pode conter `/`, `@`, `#`, `?` nem `..`. Valide o formato do `id` (UUID,
  numérico) e siga em frente. Só vira bug se o `id` puder escapar do path.
- **URL vinda de configuração ou de variável de ambiente.** Não é input do usuário. Exceção real:
  configuração *editável por tenant* em produto multi-tenant — aí volta a ser SSRF.
- **Webhook para URL cadastrada por admin em ambiente single-tenant confiável**, com rede
  segmentada e sem credencial de instância. É risco aceito, não achado — documente e siga.
- **`req.headers.host` usado só para log ou métrica.** Não constrói link nem decide nada.
  Não reporte.
- **`trustProxy` ligado atrás de um LB que sobrescreve `X-Forwarded-For`** (ALB e Cloudflare
  sobrescrevem/anexam de forma controlada) e com o framework caminhando da direita para a
  esquerda. Confirme a configuração do proxy antes de reportar.
- **`path.join` com literal do próprio código** ou com valor de um `enum`/`Set` fechado.
- **Upload sem validação de conteúdo, mas armazenado em bucket privado com key gerada pelo
  servidor e nunca servido de volta como HTML.** Continua valendo re-encodar, mas o impacto é
  baixo — não é "RCE por upload".
- **Cache sem `Cache-Control` em rota pública e não autenticada** que serve o mesmo conteúdo para
  todos. Não é cache deception.
- **Redirect para caminho relativo** (`reply.redirect('/dashboard')`) não é open redirect,
  mesmo se o valor vier de um `switch` sobre input.
- **SSRF "confirmado" só por resolução DNS no colaborador**, sem conexão HTTP. Prova que o parser
  aceitou o hostname; **não** prova que há egress. Reporte como informativo até conseguir a
  conexão ou um oráculo de tempo.
- **`Content-Length` e `Transfer-Encoding` juntos rejeitados pelo proxy** — se o edge devolve
  `400`, não há desync; teste antes de escrever o relatório.

## Fontes

- OWASP Top 10:2025 — https://owasp.org/Top10/2025/
- OWASP SSRF Prevention Cheat Sheet — https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html
- OWASP File Upload Cheat Sheet — https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html
- OWASP Unrestricted File Upload — https://owasp.org/www-community/vulnerabilities/Unrestricted_File_Upload
- OWASP WSTG, Testing for Bypassing Authorization Schema — https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/05-Authorization_Testing/02-Testing_for_Bypassing_Authorization_Schema
- PortSwigger Academy — SSRF: https://portswigger.net/web-security/ssrf
- PortSwigger Academy — Request smuggling: https://portswigger.net/web-security/request-smuggling
- PortSwigger Academy — Web cache poisoning: https://portswigger.net/web-security/web-cache-poisoning
- PortSwigger Academy — Web cache deception: https://portswigger.net/web-security/web-cache-deception
- PortSwigger Academy — Host header attacks: https://portswigger.net/web-security/host-header
- PortSwigger Academy — File upload: https://portswigger.net/web-security/file-upload
- PortSwigger Academy — Path traversal: https://portswigger.net/web-security/file-path-traversal
- James Kettle, *HTTP/1 must die: the desync endgame* (2025) — https://portswigger.net/research/http1-must-die
- James Kettle, *Browser-Powered Desync Attacks* (2022) — https://portswigger.net/research/browser-powered-desync-attacks
- James Kettle, *HTTP/2: The Sequel is Always Worse* (2021) — https://portswigger.net/research/http2
- James Kettle, *HTTP Desync Attacks: Request Smuggling Reborn* (2019) — https://portswigger.net/research/http-desync-attacks-request-smuggling-reborn
- Martin Doyhenard, *Gotta cache 'em all* (DEF CON 32, 2024) — https://portswigger.net/research/gotta-cache-em-all
- *Cached and Confused: Web Cache Deception in the Wild* (USENIX Security 2020) — https://arxiv.org/pdf/1912.10190
- PortSwigger, *Top 10 web hacking techniques of 2025* — https://portswigger.net/research/top-10-web-hacking-techniques-of-2025
- Assetnote/Searchlight, *Novel SSRF technique involving HTTP redirect loops* — https://slcyber.io/research-center/novel-ssrf-technique-involving-http-redirect-loops/
- Orange Tsai, *A New Era of SSRF* (Black Hat USA 2017) — https://blackhat.com/docs/us-17/thursday/us-17-Tsai-A-New-Era-Of-SSRF-Exploiting-URL-Parser-In-Trending-Programming-Languages.pdf
- Doyensec, *SSRF Cross Protocol Redirect Bypass* — https://blog.doyensec.com/2023/03/16/ssrf-remediation-bypass.html
- Snyk, *Zip Slip* — https://security.snyk.io/research/zip-slip-vulnerability
- AWS, Configure the Instance Metadata Service options — https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-options.html
- AWS, Transition to using IMDSv2 — https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-metadata-transition-to-version-2.html
- Node.js `net.BlockList` — https://nodejs.org/api/net.html#class-netblocklist
- Node.js `path` — https://nodejs.org/api/path.html
- Node.js `dns.lookup` — https://nodejs.org/api/dns.html#dnslookuphostname-options-callback
- undici `Client`/`Agent` (opção `connect`, `lookup`) — https://github.com/nodejs/undici/blob/main/docs/docs/api/Client.md
- Express, *Behind proxies* (`trust proxy`) — https://expressjs.com/en/guide/behind-proxies.html
- Go, `filepath.IsLocal` — https://pkg.go.dev/path/filepath#IsLocal
- Go, `os.OpenRoot` / `os.Root` (Go 1.24) — https://pkg.go.dev/os#OpenRoot
- RFC 7239, *Forwarded HTTP Extension* — https://www.rfc-editor.org/rfc/rfc7239.html
- RFC 9700, *Best Current Practice for OAuth 2.0 Security* — https://www.rfc-editor.org/rfc/rfc9700.html
- CVE-2025-61882 (Oracle EBS, SSRF→RCE) — https://labs.watchtowr.com/well-well-well-its-another-day-oracle-e-business-suite-pre-auth-rce-chain-cve-2025-61882well-well-well-its-another-day-oracle-e-business-suite-pre-auth-rce-chain-cve-2025-61882/
- CVE-2026-27826 (MCP Atlassian SSRF + DNS rebinding) — https://github.com/advisories/GHSA-489g-7rxv-6c8q
- CVE-2024-46982 (Next.js cache poisoning) / CVE-2025-49005 / CVE-2025-49826 — https://github.com/advisories/GHSA-r2fc-ccr8-96c4
