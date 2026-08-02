# Metodologia de revisão de segurança de código

Este arquivo é o **como trabalhar**, não o **o que é cada falha**. Ele cobre: como conduzir uma
revisão de ponta a ponta (diff/PR e auditoria de repositório), como se orientar em código que você
nunca viu, onde os bugs se concentram estatisticamente, o checklist por tipo de mudança, o mapa de
*defaults* e *sinks* por linguagem/framework, e — a parte que separa revisor útil de gerador de
ruído — como escrever o achado e como decidir que **não** é vulnerabilidade. O aprofundamento
técnico de cada classe de falha está nos arquivos irmãos, referenciados ao longo do texto.

Abra este arquivo quando o pedido for: "revise a segurança deste PR", "audita esse repositório",
"tem alguma vulnerabilidade aqui?", "escreve o relatório desse achado", ou quando você estiver
diante de um codebase desconhecido e precisar de um plano de ataque.

## Índice

- [Os dois modos de revisão](#os-dois-modos-de-revisão)
- [Orientação em código desconhecido](#orientação-em-código-desconhecido)
- [Onde os bugs se concentram](#onde-os-bugs-se-concentram)
- [Checklist por tipo de mudança](#checklist-por-tipo-de-mudança)
- [Mapa de linguagem e framework](#mapa-de-linguagem-e-framework)
- [Configuração e infra no repositório](#configuração-e-infra-no-repositório)
- [Como escrever o achado](#como-escrever-o-achado)
- [Calibração: quando NÃO é vulnerabilidade](#calibração-quando-não-é-vulnerabilidade)
- [Verificação do achado](#verificação-do-achado)
- [Sequência padrão para uma revisão de repositório](#sequência-padrão-para-uma-revisão-de-repositório)
- [Fontes](#fontes)

---

## Os dois modos de revisão

São métodos diferentes. Confundi-los é a causa mais comum de revisão ruim: aplicar método de
auditoria num PR de 40 linhas gera ruído; aplicar método de PR num repositório de 200 mil linhas
gera uma amostra aleatória disfarçada de auditoria.

### Modo 1 — revisão de diff/PR

**Escopo**: as linhas que mudaram. **Risco característico**: julgar uma mudança sem ver o controle
que existe três camadas acima — ou sem ver que ele *não* existe. O diff mostra o que mudou, nunca
o que já estava lá.

Antes de começar, obtenha (não presuma):

```bash
git diff --stat origin/main...HEAD          # tamanho e arquivos tocados
git diff origin/main...HEAD                 # o diff em si
git log origin/main..HEAD --oneline         # intenção declarada dos commits
```

Para cada arquivo tocado, **leia o arquivo inteiro, não só o hunk**. Um `hunk` que adiciona
`const user = await db.user.findUnique({ where: { id } })` é inofensivo ou é IDOR dependendo de
existir, 20 linhas acima, um `assertOwnership(session, id)`. O diff não te conta isso.

Três perguntas obrigatórias por PR:

1. **O que essa mudança acrescenta à superfície de ataque?** Nova rota, novo parâmetro aceito, novo
   campo persistido, nova dependência, nova chamada de saída, novo arquivo servido.
2. **Algum controle existente deixou de se aplicar?** Rota movida para fora do prefixo protegido
   pelo middleware, guard removido, validação relaxada, `catch` que virou `catch {}`, feature flag
   que passa a permitir um caminho novo.
3. **O dado novo chega a algum sink?** Se sim, rastreie até lá (veja
   [taint tracking manual](#o-princípio-central-siga-o-dado-até-o-sink)).

Precisão importa mais que recall no modo PR: você tem contexto limitado e o custo de um falso
positivo num PR é alto (o autor perde confiança e passa a ignorar seus comentários). Reporte o que
consegue sustentar; marque explicitamente o que é suspeita não confirmada.

### Modo 2 — auditoria de repositório

**Escopo**: tudo. **Restrição real**: ler tudo é inviável, então você precisa de uma *estratégia de
amostragem defensável* — e precisa declará-la no relatório, porque "auditei o repositório" sem dizer
o que foi olhado é falso.

Antes de começar, colete:

- Tamanho real: `tokei` ou `cloc`, ou `git ls-files | wc -l` e `rg --stats -c '' | tail -5`.
- O que o app faz e quem são os atores (usuário anônimo, autenticado, admin, serviço interno,
  webhook de terceiro). Sem modelo de atores não há como julgar autorização — veja
  `references/threat-modeling-e-severidade.md`.
- Se já existe SAST no CI (`.semgrep.yml`, `codeql-analysis.yml`, `.snyk`) e o que ele já cobre.
  Não gaste tempo procurando o que a ferramenta já acha — gaste no que ela estruturalmente não acha:
  autorização, lógica de negócio, confusão de identidade, race condition.
- Histórico de incidentes/segurança: `git log --grep -i -e 'security' -e 'CVE' -e 'vuln' --oneline`.

A amostragem prioriza, nesta ordem: (1) fronteira de confiança — tudo que recebe input externo;
(2) autenticação e autorização — o núcleo do controle; (3) sinks de alto impacto — SQL, shell,
deserialização, render; (4) hotspots históricos (`git log` de churn); (5) o resto, por diagonal.

| | Diff/PR | Auditoria |
|---|---|---|
| Unidade de análise | a mudança | a superfície de ataque |
| Ponto de partida | `git diff` | rotas + `package.json`/`go.mod` |
| Maior risco de erro | falso positivo por falta de contexto | falso negativo por não ter olhado |
| Entregável | comentários inline + veredito | relatório com escopo declarado |
| Tempo típico | 15–60 min | 4–16 h |

---

## Orientação em código desconhecido

A sequência abaixo é executável na ordem. Ela existe porque a alternativa — abrir arquivos ao acaso
— não converge.

### 1. Stack e versões

O que você procura: linguagem, framework HTTP, ORM, biblioteca de validação, biblioteca de auth,
runtime, e **versões** (para cruzar com CVE — veja `references/supply-chain-e-cicd.md`).

```bash
ls -a | head -50
cat package.json go.mod requirements.txt pyproject.toml pom.xml build.gradle \
    composer.json Gemfile *.csproj 2>/dev/null
rg -n '"(next|express|fastify|@nestjs/core|prisma|typeorm|zod|jsonwebtoken)"' package.json
cat Dockerfile docker-compose.yml 2>/dev/null
```

O que extrair de cada um:

| Arquivo | Sinais a extrair |
|---|---|
| `package.json` | framework HTTP, ORM, `zod`/`joi`/`yup`, `helmet`, `jsonwebtoken` vs `jose`, scripts de build, `engines.node` |
| `go.mod` | versão do Go, `gin`/`echo`/`chi`, `gorm`/`sqlx`, `gorilla/sessions` |
| `requirements.txt`/`pyproject.toml` | `django`/`flask`/`fastapi`, `sqlalchemy`, `pyyaml`, `pickle` indireto, `jinja2` |
| `pom.xml`/`build.gradle` | `spring-boot-starter-security` (presente?), `jackson-databind`, `thymeleaf`, `log4j` |
| `composer.json` | `laravel/framework` vs `symfony/*`, versão do PHP |
| `Dockerfile` | usuário final, base image, `COPY` amplo, multi-stage |

Ausência é sinal: um `pom.xml` de app web **sem** `spring-boot-starter-security` significa que não
há framework de autorização — todo controle é manual e vai faltar em algum lugar.

### 2. Mapear as entradas

Toda entrada é uma fronteira de confiança. Enumere todas antes de olhar qualquer implementação.

```bash
# Rotas HTTP (multi-stack)
rg -n -e 'app\.(get|post|put|patch|delete|all)\(' \
      -e 'router\.(get|post|put|patch|delete)\(' \
      -e 'fastify\.(get|post|put|delete|route)\(' \
      -e '@(Get|Post|Put|Patch|Delete)\(' \
      -e '@(Get|Post|Put|Patch|Delete)Mapping' \
      -e 'http\.HandleFunc|mux\.Handle|r\.(GET|POST|PUT|DELETE)\(' \
      -e '@(app|router)\.(get|post|put|delete)|path\(|re_path\(|urlpatterns' \
      -e 'Route::(get|post|put|delete|resource)' \
      -e 'resources :|get .*=>|post .*=>'

# Next.js App Router: cada route.ts é um endpoint; cada [param] é input do usuário
rg --files -g '**/route.ts' -g '**/route.js' -g '**/page.tsx' | rg '\['
rg -rn "'use server'" --glob '*.ts' --glob '*.tsx'   # server actions = endpoints POST públicos

# Entradas que não são HTTP
rg -n -e 'consume\(|@RabbitListener|@KafkaListener|sqs|@SqsListener|bull|bullmq|Queue\(' \
      -e 'cron|schedule\(|@Scheduled|node-cron' \
      -e 'webhook|/hooks/|stripe\.webhooks|verifySignature' \
      -e 'process\.argv|flag\.String|argparse|commander' \
      -e 'multer|busboy|FormData|MultipartFile|request\.FILES'
```

Monte a lista: método + caminho + arquivo:linha + quem pode chamar (anônimo/autenticado/admin).
Essa lista é o esqueleto do relatório e o índice do resto da revisão.

### 3. Mapear as saídas e os sinks

Sink é onde o dado deixa de ser dado e vira comando, marcação, caminho ou requisição.

```bash
# SQL
rg -n -e '\$queryRawUnsafe|\$executeRawUnsafe' \
      -e 'sequelize\.query\(|knex\.raw\(|\.query\(`|\.query\(.*\+' \
      -e 'FromSqlRaw|ExecuteSqlRaw|SqlQueryRaw' \
      -e '\.raw\(|RawSQL|\.extra\(|text\(' \
      -e 'createNativeQuery|createQuery\(.*\+' \
      -e 'DB::raw|whereRaw|selectRaw|orderByRaw|havingRaw' \
      -e 'fmt\.Sprintf\(.*(SELECT|INSERT|UPDATE|DELETE|WHERE)'

# Shell / comando
rg -n -e 'child_process|execSync|exec\(|spawn\(|shell\s*:\s*true' \
      -e 'os\.system|subprocess\.(run|call|Popen).*shell\s*=\s*True' \
      -e 'Runtime\.getRuntime\(\)\.exec|ProcessBuilder' \
      -e 'exec\.Command\("(sh|bash|cmd)"' \
      -e 'shell_exec|passthru|proc_open|`\$' \
      -e 'Process\.Start'

# Filesystem / path traversal
rg -n -e 'readFile|createReadStream|sendFile|res\.download|path\.join\(' \
      -e 'os\.path\.join|open\(|send_file|send_from_directory' \
      -e 'os\.Open|filepath\.Join|http\.ServeFile' \
      -e 'new File\(|Paths\.get\(|FileInputStream' \
      -e 'file_get_contents|fopen|include |require_once'

# HTTP de saída (SSRF)
rg -n -e 'fetch\(|axios\.|got\(|undici|http\.request|https\.get' \
      -e 'requests\.(get|post|put)|httpx\.|urllib' \
      -e 'http\.Get|http\.Post|client\.Do\(' \
      -e 'RestTemplate|WebClient|HttpClient' \
      -e 'curl_exec|Http::(get|post)'

# Render / HTML
rg -n -e 'dangerouslySetInnerHTML|innerHTML\s*=|outerHTML|insertAdjacentHTML|document\.write' \
      -e 'v-html|\{\{\{|\|\s*safe|mark_safe|render_template_string' \
      -e 'html_safe|\.raw\(|sanitize\(' \
      -e '\{!!|@verbatim' \
      -e 'template\.HTML\(|text/template' \
      -e 'Html\.Raw|MarkupString|th:utext'

# Deserialização / execução dinâmica
rg -n -e '\beval\(|new Function\(|vm\.runIn|require\(.*\+' \
      -e 'pickle\.loads|yaml\.load\((?!.*SafeLoader)|marshal\.loads' \
      -e 'ObjectInputStream|readObject|enableDefaultTyping|activateDefaultTyping|@JsonTypeInfo' \
      -e 'unserialize\(' \
      -e 'BinaryFormatter|TypeNameHandling'
```

Cada sink encontrado vira uma linha numa tabela: `arquivo:linha` → tipo de sink → de onde vem o
argumento. A terceira coluna é o trabalho real.

### 4. Localizar os controles

Antes de dizer "falta autorização", você precisa saber como a autorização é *normalmente* feita
neste repositório. Procure o padrão, depois procure quem foge dele.

```bash
rg -n -e 'requireAuth|isAuthenticated|ensureLogged|@UseGuards|AuthGuard' \
      -e '@PreAuthorize|@Secured|@RolesAllowed|SecurityFilterChain' \
      -e 'login_required|permission_required|IsAuthenticated|permission_classes' \
      -e 'before_action :authenticate|authorize!|Pundit|CanCan' \
      -e '\[Authorize\]|RequireAuthorization' \
      -e "middleware\(\['auth" \
      -e 'preHandler|onRequest|addHook|app\.use\('

# Validação de entrada
rg -n -e 'z\.object\(|schema:|joi\.|yup\.|class-validator|@IsString' \
      -e 'BaseModel|pydantic|serializers\.|forms\.Form' \
      -e '@Valid|@Validated|binding\.' \
      -e 'FormRequest|\$request->validate'

# Sanitização de HTML
rg -n 'DOMPurify|sanitize-html|bleach|OWASP.*sanitizer|HtmlSanitizer|Rails::Html'
```

Depois responda: o controle é **global** (middleware aplicado à raiz, `SecurityFilterChain` com
`anyRequest().authenticated()`, `permission_classes` default em `settings.py`) ou é **por rota**?

### 5. Procurar quem escapa do controle

Esta é a etapa que encontra bugs. Duas técnicas:

**Diferença de contagem.** Se há 87 rotas e 61 chamadas a `requireAuth`, existem no mínimo 26 rotas
sem ele. Liste-as:

```bash
rg -n --json 'router\.(get|post|put|delete)\(' | jq -r '.data.path.text' | sort -u > /tmp/rotas.txt
rg -l 'requireAuth' > /tmp/comauth.txt
comm -23 /tmp/rotas.txt /tmp/comauth.txt
```

**Allowlist de exclusão.** Middleware global quase sempre tem uma lista de caminhos públicos. Ela é
o lugar mais rentável do repositório inteiro:

```bash
rg -n -B3 -A15 -e 'publicPaths|PUBLIC_ROUTES|skipAuth|excludePaths|permitAll|@Public|csrf_exempt' \
      -e 'AllowAnonymous|login_exempt|unless:|except:'
```

Procure: prefixo em vez de caminho exato (`/api/public` casando com `/api/public-admin`), regex sem
âncora, comparação com `startsWith` sobre caminho não normalizado (`/api/admin/../public`).

### O princípio central: siga o dado até o sink

*Taint tracking* manual. Comece na entrada, não no sink — começar no sink faz você perder as
entradas que ninguém marcou como perigosas.

1. **Fonte**: `req.body.filename`, `params.id`, header, campo do JWT, valor lido do banco que foi
   escrito por outro usuário (essa é a fonte que revisor iniciante ignora — *stored* XSS e IDOR
   de segunda ordem vivem aí).
2. **Propagação**: a cada atribuição, chamada de função, spread (`...body`), serialização
   (`JSON.stringify`) e desserialização, o *taint* segue. Anote onde ele entra numa função:
   `rg -n 'function processUpload|const processUpload'` e continue lá dentro.
3. **Sanitizadores**: só limpam se forem apropriados ao *contexto do sink*. `escapeHtml` não
   protege sink de SQL; `parseInt` protege sink de SQL mas não de path traversal se o resultado
   virar índice de array de caminhos.
4. **Sink**: chegou. Agora a pergunta é o quanto o atacante controla — string inteira, sufixo,
   ou 8 caracteres de um subconjunto.

Se o caminho é longo demais para seguir de cabeça, escreva-o: `POST /api/report → body.format →
buildQuery() → ORDER BY ${format} → prisma.$queryRawUnsafe` — a cadeia escrita é metade do achado.

### A heurística mais rentável: opt-in versus opt-out

**Onde o controle é opt-in, vai existir um lugar onde esqueceram.** Isso é o suficiente para achar
bug em quase todo repositório grande.

- `@UseGuards(AuthGuard)` por controller (opt-in) → algum controller novo não tem.
- `csrf_exempt` (opt-out) é melhor: você audita a lista de exceções, que é curta.
- `SELECT` de campos explícitos por endpoint (opt-in) → algum endpoint faz `SELECT *` e vaza
  `password_hash`; a DTO opt-out (allowlist de serialização) não tem esse modo de falha.
- Escape manual no template (opt-in, PHP legado, `text/template` do Go) → esqueceram em um lugar.
- Autoescaping (opt-out, Django/Blade/Rails/React) → você audita só os `{!! !!}`, `|safe`,
  `html_safe`, `dangerouslySetInnerHTML`, que são poucos e grepáveis.

Corolário operacional: quando o controle é opt-in, **conte** as ocorrências e compare com o número
de lugares que precisam dele. A diferença é sua lista de trabalho.

---

## Onde os bugs se concentram

Priorização quando o tempo é finito. Cada item vem com o comando que o localiza.

**Código muito novo** — ainda não passou por olhos suficientes nem por pentest:

```bash
git log --since='3 months ago' --diff-filter=A --name-only --pretty=format: | sort -u | rg -v '^$'
```

**Código muito antigo** — escrito sob outro modelo de ameaça, com API depreciada, sem os controles
que hoje são padrão no repositório:

```bash
git ls-files | while read -r f; do
  printf '%s %s\n' "$(git log -1 --format=%ad --date=short -- "$f")" "$f"
done | sort | head -40
```

**Churn alto** — arquivo que muda toda semana acumula erro de merge e controle esquecido:

```bash
git log --since='1 year ago' --name-only --pretty=format: | sort | uniq -c | sort -rn | head -30
```

**O caminho de exceção e o `catch`** — o *happy path* é testado; o `catch` não. É onde vazam stack
traces (CWE-209), onde se faz `return null` que vira "autorizado", e onde o *fail-open* mora. É a
categoria A10:2025 (*Mishandling of Exceptional Conditions*):

```bash
rg -n -A4 -e 'catch\s*\(' -e 'except\b' -e 'rescue\b' -e 'if err != nil' | \
  rg -B1 -e 'return (true|null|nil|None)' -e 'pass$' -e 'continue$' -e '\{\s*\}'
rg -n -e 'catch\s*\{\s*\}' -e 'except:\s*pass' -e 'rescue\s*;?\s*end' -e '_ = err'
```

**Endpoints administrativos** — impacto máximo, revisão mínima, frequentemente protegidos por
convenção ("essa rota só o admin conhece") em vez de por código:

```bash
rg -n -i -e '/admin|/internal|/debug|/_|/ops|/management|/actuator' \
        -e 'isAdmin|is_staff|role.*admin|superuser'
```

**Migrações e scripts de manutenção** — rodam com credencial privilegiada, quase nunca são
revisados, frequentemente concatenam SQL e às vezes ficam expostos como endpoint:

```bash
rg --files -g '**/migrations/**' -g '**/scripts/**' -g '**/bin/**' -g '**/tasks/**' -g '*.sql'
```

**Integrações com terceiros** — webhook sem verificação de assinatura, SDK com `verify=False`,
callback de OAuth com `state` não checado, URL de terceiro montada com input:

```bash
rg -n -e 'webhook|callback|/oauth|redirect_uri|state=' \
      -e 'verify\s*=\s*False|rejectUnauthorized\s*:\s*false|InsecureSkipVerify\s*:\s*true' \
      -e 'constructEvent|verifySignature|hmac'
```

**Marcadores de dívida e supressões** — `nosec`/`nosemgrep`/`eslint-disable` são confissões:

```bash
rg -n -e 'TODO|FIXME|HACK|XXX|WORKAROUND|GAMBIARRA|temporar|por enquanto' \
      -e 'nosec|nosemgrep|codeql\[|eslint-disable|@ts-ignore|@ts-expect-error|noqa|#\[allow'
```

**Código escrito às pressas antes de deadline** — cruze commits com mensagens de urgência e o
horário/data:

```bash
git log --format='%h %ad %an %s' --date=format:'%Y-%m-%d %H:%M' | \
  rg -i -e 'hotfix|urgent|asap|quick|temp|wip|deadline|revert|band.?aid'
git log --format='%h %ad %s' --date=format:'%H' | awk '$2 >= 22 || $2 <= 5'   # commits de madrugada
git blame -L 100,160 --date=short caminho/do/arquivo.ts
```

**Import/export, relatório e "bulk"** — geram CSV (injeção de fórmula), aceitam XML (XXE),
aceitam ZIP (Zip Slip), constroem SQL dinâmico com nome de coluna vindo do usuário, e costumam
ignorar o filtro de tenant porque "é para o admin":

```bash
rg -n -i -e 'import|export|csv|xlsx|bulk|batch|report' -g '!*test*' -g '!*.lock' | rg -i 'route|handler|controller'
rg -n -e 'DocumentBuilderFactory|SAXParser|XMLReader|etree|libxml|simplexml' \
      -e 'ZipFile|AdmZip|unzip|extractall|extractTo'
```

**A fronteira entre dois times/serviços** — cada lado assume que o outro valida. Ache a fronteira
pelo dono do código:

```bash
git log --format='%ae' -- caminho/do/modulo | sort | uniq -c | sort -rn | head
cat CODEOWNERS .github/CODEOWNERS 2>/dev/null
```

Sinais de fronteira quebrada: chamada interna que confia em `X-User-Id` de header, serviço que
aceita `trusted=true` no body, mTLS "planejado" mas não implementado, gateway que valida JWT mas
serviço downstream que também aceita chamada direta.

---

## Checklist por tipo de mudança

Use no modo PR. Cada bloco é o mínimo verificável; o ponteiro leva ao aprofundamento.

**Nova rota/endpoint**
- [ ] Requer autenticação? Está coberto pelo middleware global ou depende de anotação por rota?
- [ ] Requer autorização de *recurso* (não só de papel)? Onde está o `ownerId === session.userId`?
- [ ] O método HTTP é adequado (mutação em `GET` = CSRF por `<img>` + cache + log de URL)?
- [ ] Entrada validada por schema, incluindo tipo, tamanho máximo e campos desconhecidos rejeitados?
- [ ] Rate limit para operação cara, envio de e-mail/SMS, ou endpoint de auth?
- [ ] Resposta expõe só o DTO ou devolve o registro inteiro do banco?
- [ ] Erro distingue "não existe" de "existe mas não é seu"? (enumeração)
- → `references/autorizacao-e-logica-de-negocio.md`, `references/api-e-graphql.md`

**Nova query de banco**
- [ ] Parametrizada? Concatenação de identificador (tabela/coluna/`ORDER BY`) usa allowlist?
- [ ] `LIKE` com input escapa `%` e `_`?
- [ ] Filtro de tenant/dono presente na *cláusula*, não aplicado depois em memória?
- [ ] `SELECT` de campos explícitos ou `SELECT *` que arrasta hash de senha e token?
- [ ] Ordenação/paginação com limite máximo (`take` sem teto = DoS)?
- → `references/injecao.md`

**Novo campo em modelo/DTO**
- [ ] Entra em mass assignment? (`...req.body`, `data: body`, sem `$fillable`, sem `strong params`)
- [ ] Se é campo de permissão (`role`, `isAdmin`, `plan`, `balance`), está explicitamente bloqueado?
- [ ] Sai na serialização para o cliente? Deveria?
- [ ] É PII/sensível? Precisa de criptografia em repouso, mascaramento em log, política de retenção?
- → `references/autorizacao-e-logica-de-negocio.md`, `references/criptografia-e-segredos.md`

**Novo upload**
- [ ] Tipo validado por conteúdo (*magic bytes*), não por extensão nem por `Content-Type` do cliente?
- [ ] Nome do arquivo regenerado no servidor (UUID) em vez de usar o nome enviado?
- [ ] Tamanho máximo e número máximo de arquivos por request?
- [ ] Armazenado fora do webroot ou em bucket, servido com `Content-Disposition: attachment` e
      `X-Content-Type-Options: nosniff`, idealmente em domínio separado?
- [ ] SVG e HTML tratados como executáveis (SVG carrega `<script>`)?
- [ ] Se o arquivo é processado (imagem, PDF, ZIP): a biblioteca tem CVE recente? Zip Slip tratado?
- → `references/injecao.md` (path traversal), `references/xss-e-navegador.md`

**Nova integração HTTP de saída**
- [ ] A URL é fixa no código ou o usuário influencia host/caminho/query? Se influencia, é SSRF até
      prova em contrário.
- [ ] Redirect seguido automaticamente? (`maxRedirects: 0` ou revalidar cada salto)
- [ ] Timeout definido? Sem timeout, é DoS por conexão pendurada.
- [ ] Segredo vai no header, não na query string (query string vaza em log e `Referer`)?
- [ ] TLS validado (nada de `rejectUnauthorized: false`)?
- [ ] Resposta do terceiro é tratada como não confiável antes de ir para um sink?
- → `references/ssrf-e-camada-http.md`

**Novo job/consumer (fila, cron)**
- [ ] A mensagem é entrada não confiável? Quem pode publicar na fila?
- [ ] O payload é desserializado com formato seguro (JSON) ou com `pickle`/`ObjectInputStream`?
- [ ] O job roda com identidade de sistema — ele reaplica a autorização do usuário que originou a
      ação ou assume que já foi checada?
- [ ] Idempotência: reprocessar duas vezes debita duas vezes?
- [ ] Erro no job silencia ou alerta? (A09:2025)

**Mudança em middleware de auth**
- [ ] Mudou a ordem de registro? Middleware registrado depois da rota não protege a rota.
- [ ] A lista de caminhos públicos usa igualdade ou prefixo/regex? Regex tem âncora `^...$`?
- [ ] O caminho comparado já foi normalizado (`..`, `%2e%2e`, barra dupla, case)?
- [ ] Falha de verificação retorna 401 ou cai num `catch` que segue adiante (*fail-open*)?
- [ ] Algoritmo do JWT fixado explicitamente? `kid`/`jku` não controlam a chave?
- → `references/autenticacao-e-sessao.md`

**Nova dependência**
- [ ] Quem mantém, última release, número de mantenedores, downloads? Typosquatting no nome?
- [ ] Tem `postinstall` script?
- [ ] Está pinada com integridade no lockfile?
- [ ] Traz transitivas com CVE conhecida? (`npm audit`, `osv-scanner`, `govulncheck`)
- [ ] Substitui código que já existia por algo com superfície maior?
- → `references/supply-chain-e-cicd.md`

**Mudança em configuração/infra**
- [ ] Porta nova exposta, `0.0.0.0` onde era `127.0.0.1`?
- [ ] `DEBUG`/`NODE_ENV`/`APP_DEBUG` ligado em ambiente que vai para produção?
- [ ] CORS: `origin` virou `*` ou reflete o `Origin` recebido? Com `credentials: true`?
- [ ] Segredo em plaintext no arquivo versionado?
- [ ] Headers de segurança removidos ou relaxados (CSP com `unsafe-inline` novo)?
- → [Configuração e infra](#configuração-e-infra-no-repositório)

**Novo template/render**
- [ ] Autoescaping ativo? O motor é contextual (Go `html/template`) ou só HTML-escape?
- [ ] Algum `raw`/`safe`/`html_safe`/`dangerouslySetInnerHTML`? De onde vem o conteúdo?
- [ ] Dado injetado dentro de `<script>`, de atributo de evento, de `href`, ou de CSS? Esses
      contextos não são cobertos por HTML-escape simples.
- [ ] Template compilado a partir de string com input do usuário? (SSTI)
- → `references/xss-e-navegador.md`

**Migração de banco**
- [ ] Cria coluna com default permissivo (`is_admin BOOLEAN DEFAULT true`, `visibility 'public'`)?
- [ ] Remove constraint/`NOT NULL`/`UNIQUE` que era controle de integridade?
- [ ] Faz backfill com SQL concatenado a partir de dado existente?
- [ ] Cria índice que expõe ordenação previsível de ID sequencial (facilita enumeração)?
- [ ] Roda com usuário superuser e deixa GRANT amplo?

**Feature flag**
- [ ] O caminho novo passa pelos mesmos controles do caminho antigo?
- [ ] A flag é lida do cliente (cookie, query, header) — o usuário liga a feature sozinho?
- [ ] Estado *off* é o seguro? Flag ausente/erro de avaliação cai em qual lado?
- [ ] Flag de "bypass" para teste (`skipPaymentCheck`, `testMode`) existe no código de produção?

```bash
rg -n -i -e 'featureFlag|isEnabled\(|unleash|launchdarkly|flagsmith' \
      -e 'skip(Auth|Payment|Validation)|testMode|bypass|DEV_ONLY|E2E_'
```

---

## Mapa de linguagem e framework

Duas colunas mentais por stack: **(a) o que o framework já protege** — para não gerar falso
positivo — e **(b) os sinks e escape hatches** — o que realmente se procura.

### Node.js / TypeScript

**Já protegido por padrão.** Nenhum framework Node protege muita coisa por padrão; a proteção vem
das bibliotecas. Prisma (query builder) e `pg`/`mysql2` com placeholders parametrizam. React
escapa por padrão no render. Express **não** define header de segurança nenhum sem `helmet`, **não**
tem CSRF (o `csurf` foi descontinuado — hoje se usa `csrf-csrf` ou double-submit próprio), e
`express.json()` sem `limit` aceita 100 kb por padrão (não é ilimitado, mas o default de `urlencoded`
com `extended: true` permite objetos aninhados — vetor de DoS de parsing). Fastify valida
*e serializa* por JSON Schema quando você declara `schema` na rota: a serialização por schema é uma
defesa real contra vazamento de campo (o que não está no schema de resposta não sai) — mas só se o
schema existir.

| Sink / escape hatch | Risco | Correção |
|---|---|---|
| `prisma.$queryRawUnsafe` / `$executeRawUnsafe` | SQL injection | `$queryRaw` com template tag (parametriza) |
| `prisma.$queryRaw` com `Prisma.raw(...)` no meio | SQL injection | `Prisma.sql` + allowlist para identificador |
| `db.query('SELECT ... ' + x)` (`pg`, `mysql2`) | SQL injection | `db.query('... $1', [x])` |
| `child_process.exec` / `execSync` | command injection | `execFile`/`spawn` com array de args, sem `shell: true` |
| `eval`, `new Function`, `vm.runInNewContext` | RCE | remover; `vm` **não é sandbox** |
| `require(variável)` / `import(variável)` | RCE / traversal | allowlist de módulos |
| `res.sendFile(path.join(base, req.params.p))` | path traversal | `path.resolve` + verificar `startsWith(base)` |
| `JSON.parse` em objeto que vira merge/`Object.assign` | prototype pollution | `Object.create(null)`, rejeitar `__proto__`/`constructor` |
| `serialize-javascript`/`JSON.stringify` dentro de `<script>` | XSS | escapar `<`, ` `, ` ` |
| `res.redirect(req.query.next)` | open redirect | allowlist de destino / caminho relativo validado |
| `helmet()` ausente | headers ausentes | *hardening*, não vulnerabilidade — veja calibração |

**Zod**: o default é **stripar** chaves desconhecidas em `z.object()` — bom. Mas `.passthrough()`
as mantém, e `z.record(z.any())` aceita qualquer coisa. `z.coerce.number()` transforma `"1abc"`? Não
— `Number("1abc")` é `NaN` e falha; mas `z.coerce.boolean()` transforma **qualquer string não vazia**
em `true`, inclusive `"false"`. Isso já causou bypass de flag. Procure:

```bash
rg -n 'z\.coerce\.boolean|\.passthrough\(\)|z\.any\(\)|z\.record\(z\.any' 
rg -n 'as unknown as|as any|@ts-ignore'   # onde o tipo mente, a validação não aconteceu
```

**NestJS**: `ValidationPipe` só remove campos extras com `whitelist: true`, e só rejeita com
`forbidNonWhitelisted: true` — sem isso, DTO decorado ainda aceita campo desconhecido no objeto.
Guards são opt-in por padrão; `APP_GUARD` global com `@Public()` opt-out é o padrão seguro.

```bash
rg -n 'new ValidationPipe\(' -A5
rg -c '@UseGuards' ; rg -c '@(Get|Post|Put|Patch|Delete)\('   # compare
```

**Next.js (App Router, v15/16)** — o que o framework garante e o que não garante:

- Server Actions exportadas são **endpoints POST públicos**, chamáveis por requisição direta mesmo
  sem UI. O Next gera IDs cifrados não determinísticos (recalculados a cada build, cache de no
  máximo 14 dias) e faz *dead code elimination* de actions não usadas — isso reduz a exposição, mas
  a documentação oficial é explícita: **trate toda action como endpoint público e verifique authn e
  authz dentro dela**. Verificação na página **não** cobre a action definida nela.
- CSRF: actions só aceitam `POST` e o Next compara `Origin` com `Host`/`X-Forwarded-Host`,
  abortando se divergirem. Por trás de proxy, isso exige `serverActions.allowedOrigins`.
- Variáveis capturadas por closure em action inline são enviadas ao cliente e **de volta**,
  cifradas com chave por build (`NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` para múltiplas instâncias).
  A doc desaconselha depender só disso para dado sensível.
- `NEXT_PUBLIC_*` vai para o bundle do cliente. Funções e classes são bloqueadas de atravessar a
  fronteira; objetos comuns não são — passar `user` inteiro do Server Component para um
  `'use client'` vaza todos os campos no payload RSC (visível no HTML/flight data, mesmo que a UI
  não renderize).
- `import 'server-only'` faz o build falhar se o módulo for importado no cliente. As Taint APIs
  (`experimental_taintObjectReference`, `experimental_taintUniqueValue`) exigem
  `experimental.taint: true` e são camada extra, não substituto do DTO.
- No Next 16, `middleware.ts` passou a ser `proxy.ts`. Auditoria dedicada: `proxy.ts` e `route.ts`
  concentram poder desproporcional.

```bash
rg -rn "'use server'" -l | xargs rg -Ln 'auth\(|getSession|requireUser'   # actions sem checagem
rg -rn "'use client'" -l | xargs rg -n 'interface .*Props' -A8            # props largas demais
rg -n 'NEXT_PUBLIC_' | rg -i 'key|secret|token|password'
rg -n 'searchParams|params\.' | rg -i 'isAdmin|role|userId|tenant'
```

### React e React Native

React escapa conteúdo em `{expressão}` no JSX — por isso XSS em React é quase sempre um destes:

| Sink | Risco | Nota |
|---|---|---|
| `dangerouslySetInnerHTML={{ __html: x }}` | XSS | só é seguro com DOMPurify **no mesmo lugar** |
| `href={userUrl}` / `src={userUrl}` | `javascript:` URI XSS | validar esquema (`http`/`https` allowlist) |
| `<a target="_blank">` sem `rel="noopener"` | tabnabbing | navegadores modernos já aplicam `noopener` implícito em `target=_blank`; achado de baixíssimo impacto |
| `ref.current.innerHTML = x` | XSS | escapa da proteção do React |
| `eval`/`Function` em código de tema/config | RCE no cliente | |
| React Native: `WebView` com `source={{ html }}` | XSS no contexto do app | `originWhitelist`, `javaScriptEnabled={false}` quando possível |
| React Native: `AsyncStorage` para token | segredo em claro | Keychain/Keystore — veja `references/mobile.md` |

O erro mais comum em React não é XSS, é **dado sensível no bundle ou no estado**: chave de API
embutida, resposta de API com campos demais chegando ao Redux, feature flag de admin avaliada no
cliente. Grepe `rg -n 'process\.env\.' src/ | rg -iv 'NODE_ENV'`.

### Go

**Já protegido.** `database/sql` parametriza com `?`/`$1`. `html/template` faz escaping
**contextual** — sabe distinguir HTML, atributo, URL, JS e CSS, e aplica o escape certo em cada um.
`net/http` não tem CSRF nem headers de segurança embutidos.

| Sink / escape hatch | Risco | Correção |
|---|---|---|
| `fmt.Sprintf("SELECT ... %s", x)` + `db.Query` | SQL injection | `db.Query("... WHERE id = $1", x)` |
| `text/template` para gerar HTML | XSS (zero escaping) | `html/template` |
| `template.HTML(x)`, `template.JS(x)`, `template.URL(x)`, `template.HTMLAttr(x)`, `template.CSS(x)`, `template.Srcset(x)` | XSS | são *asserções de confiança*; `template.URL` desliga inclusive o filtro de `javascript:` |
| `exec.Command("sh", "-c", cmd)` | command injection | `exec.Command("bin", arg1, arg2)` |
| `filepath.Join(base, userPath)` | path traversal | `filepath.Clean` + `strings.HasPrefix(abs, base)`; Go 1.24+ tem `os.Root` para confinar |
| `http.ServeFile(w, r, r.URL.Path)` | traversal | `http.ServeFile` já rejeita `..` no `r.URL.Path`, mas não em caminho vindo de query/body |
| `if err != nil` ausente / `_ = err` | fail-open | tratar |
| `encoding/gob` sobre dado de rede | deserialização | JSON com struct tipada |

Gin/Echo: `c.Param`, `c.Query`, `c.PostForm` são entradas cruas. `c.ShouldBindJSON` faz binding sem
validar a menos que a struct tenha tags `binding:"required,..."` — e binding em struct com campos
não esperados é mass assignment. `gin.Default()` inclui `Logger` e `Recovery`, não autenticação.
Rode sempre `govulncheck ./...` (analisa alcance real da função vulnerável, não só a versão).

### Python

**Já protegido.** Django: autoescaping em templates, `CsrfViewMiddleware` (habilitado no
`settings.py` padrão), ORM parametrizado, `XFrameOptionsMiddleware`, validação de `Host` por
`ALLOWED_HOSTS`, e — novidade do **Django 6.0** — suporte nativo a CSP com geração de nonce por
requisição. Flask não protege nada por padrão além do autoescaping do Jinja2 em arquivos `.html`
(strings passadas a `render_template_string` **não** têm a mesma garantia). FastAPI valida por
Pydantic quando você tipa o parâmetro, e não valida o que você não tipou.

| Sink / escape hatch | Risco | Correção |
|---|---|---|
| `Model.objects.raw(f"...{x}")`, `.extra(where=[...])`, `RawSQL` | SQL injection | `raw("... WHERE id = %s", [x])` |
| `cursor.execute("..." % x)` / `.format` / f-string | SQL injection | `cursor.execute("... %s", [x])` |
| SQLAlchemy `text("... " + x)`, `.filter(text(f"..."))` | SQL injection | `text("... :x").bindparams(x=x)` |
| `mark_safe`, `\|safe`, `{% autoescape off %}` | XSS | `format_html` com placeholders |
| `render_template_string(user_input)` | SSTI → RCE (Jinja2 `__class__`/`__subclasses__`) | template estático + contexto |
| `pickle.loads`, `yaml.load` sem `SafeLoader`, `marshal` | RCE | `json`, `yaml.safe_load` |
| `subprocess.run(cmd, shell=True)`, `os.system` | command injection | lista de args, `shell=False` |
| `os.path.join(BASE, user)` | traversal | `os.path.realpath` + `startswith` |
| `eval`, `exec`, `__import__` | RCE | |
| `@csrf_exempt` | CSRF | auditar cada ocorrência |
| DRF sem `DEFAULT_PERMISSION_CLASSES` | acesso aberto | default `IsAuthenticated`, opt-out explícito |
| `redirect(request.GET['next'])` | open redirect | `url_has_allowed_host_and_scheme` |
| `DEBUG = True` | vazamento total (settings, SQL, stack) | |

```bash
rg -n 'DEBUG\s*=\s*True|ALLOWED_HOSTS\s*=\s*\[\s*[\x27"]\*' 
rg -n 'DEFAULT_PERMISSION_CLASSES' -A3 settings*.py
rg -n '@csrf_exempt|@permission_classes\(\[AllowAny' 
```

### Java / Kotlin

**Já protegido.** Spring Security, quando presente, habilita **CSRF por padrão** para métodos
mutantes (POST/PUT/DELETE/PATCH; GET/HEAD/OPTIONS/TRACE ficam de fora, o que pressupõe que eles
sejam read-only de fato) e traz headers de segurança. JPA/Hibernate parametriza queries JPQL com
parâmetros nomeados. Thymeleaf escapa com `th:text`.

| Sink / escape hatch | Risco | Correção |
|---|---|---|
| `createQuery("... where n = '" + x + "'")` | JPQL/SQL injection | `setParameter("n", x)` |
| `createNativeQuery` com concatenação | SQL injection | idem |
| `JdbcTemplate.query(sql + x)` | SQL injection | `query(sql, args)` |
| `th:utext` | XSS | `th:text` |
| `Runtime.getRuntime().exec(cmd)`, `ProcessBuilder` com string única | command injection | array de args |
| `ObjectInputStream.readObject` sobre dado externo | RCE via gadget chain (Commons Collections etc.) | não desserializar Java nativo; se inevitável, `ObjectInputFilter` (JEP 290) |
| Jackson `enableDefaultTyping` / `activateDefaultTyping` / `@JsonTypeInfo(use = Id.CLASS)` | RCE por polymorphic deserialization | desligar; usar `@JsonSubTypes` explícito |
| `@JsonIgnoreProperties` ausente + `@RequestBody Entity` | mass assignment | DTO dedicado |
| `http.csrf().disable()` | CSRF | só aceitável em API stateless com token em header |
| `permitAll()` amplo / `antMatchers("/**")` | acesso aberto | ordem das regras importa: a primeira que casa vence |
| `DocumentBuilderFactory` default | XXE | `setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true)` e desabilitar DTD |
| `@PreAuthorize` como único controle | opt-in | falta em algum método novo |

```bash
rg -n 'csrf\(\)\.disable|permitAll|antMatchers|requestMatchers' -A2
rg -n 'enableDefaultTyping|activateDefaultTyping|@JsonTypeInfo|readObject|ObjectInputStream'
rg -n 'DocumentBuilderFactory|SAXParserFactory|XMLInputFactory' -A5
```

### PHP

**Laravel**: Blade escapa `{{ }}` via `htmlspecialchars`, com **double encoding ativado por
padrão** (desligável por `Blade::withoutDoubleEncoding()` — se você encontrar essa chamada, o
risco de duplo decode volta). Eloquent parametriza. CSRF via `VerifyCsrfToken` middleware no grupo
`web`. Mass assignment é controlado por `$fillable`/`$guarded` — `$guarded = []` desliga a proteção.

| Sink / escape hatch | Risco | Correção |
|---|---|---|
| `{!! $x !!}` | XSS | `{{ $x }}`, ou sanitizar antes |
| `{{ $arr }}` dentro de `<script>` | XSS por quebra de contexto | `{{ Js::from($arr) }}` |
| `DB::raw`, `whereRaw`, `orderByRaw`, `selectRaw`, `havingRaw` com concatenação | SQL injection | bindings: `whereRaw('x = ?', [$x])` |
| `$guarded = []` / `Model::unguard()` | mass assignment | `$fillable` explícito |
| `$except` em `VerifyCsrfToken` | CSRF | auditar a lista |
| `unserialize($input)` | object injection → RCE | `json_decode` |
| `shell_exec`, `system`, `passthru`, `proc_open`, crase | command injection | `escapeshellarg` ou evitar |
| `include`/`require` com variável | LFI/RFI | allowlist |
| `extract($_POST)` | sobrescrita de variável | remover |
| `==` comparando hash/token | type juggling (`"0e123" == "0e456"`) | `===` / `hash_equals` |

**Symfony**: Twig escapa por padrão (`autoescape html`); `|raw` é o escape hatch. Doctrine DQL
parametriza; `createQuery` com concatenação não. `security.yaml` com `access_control` mal ordenado
(regra genérica antes da específica) libera rota.

**PHP legado (sem framework)**: presuma que nada é protegido. Grepe `$_GET`, `$_POST`,
`$_REQUEST`, `$_COOKIE` e siga cada um até o sink. `register_globals` não existe mais desde o PHP
5.4, mas `extract()` reproduz o efeito.

### Ruby on Rails

**Já protegido.** `protect_from_forgery` é o default em apps novos
(`config.action_controller.default_protect_from_forgery = true`); `CookieStore` usa cookie
**cifrado**; ERB escapa por padrão; `Model.find(id)` e `find_by_x` parametrizam; Rails define
`X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff` e
`Referrer-Policy: strict-origin-when-cross-origin` por padrão. Rails 8 traz gerador de
autenticação com bcrypt e sessões.

| Sink / escape hatch | Risco | Correção |
|---|---|---|
| `where("name = '#{params[:name]}'")` | SQL injection | `where("name = ?", params[:name])` |
| `order(params[:sort])`, `pluck(params[:col])` | SQL injection por identificador | allowlist de colunas |
| `html_safe`, `raw()`, `<%== %>` | XSS | `sanitize` (allowlist) ou escapar |
| `params.permit!` / `update(params[:user])` sem `permit` | mass assignment | strong parameters explícitos |
| `skip_before_action :verify_authenticity_token` | CSRF | auditar |
| `redirect_to params[:url]` | open redirect | Rails 7+ exige `allow_other_host: true` para host externo — a ausência dessa flag já bloqueia; com ela, é achado |
| `send_file params[:path]`, `render file:` | traversal / LFI | allowlist |
| `Marshal.load`, `YAML.load` (não `safe_load`) | RCE | `YAML.safe_load` |
| `constantize`/`send` com input | RCE | allowlist |

Rode `brakeman -A` — é o SAST específico de Rails e tem taxa de sinal alta.

### C# / .NET

**Já protegido.** Razor (`@model.Prop`) HTML-encoda por padrão. EF Core parametriza LINQ.
Antiforgery token é automático em `<form>` do Razor Pages/MVC; APIs com `[ApiController]` fazem
validação de model automaticamente e retornam 400.

| Sink / escape hatch | Risco | Correção |
|---|---|---|
| `FromSqlRaw`, `ExecuteSqlRaw`, `SqlQueryRaw` | SQL injection | `FromSql`/`FromSqlInterpolated`/`ExecuteSql` (interpolação vira `DbParameter`) |
| `new SqlCommand("... " + x)` | SQL injection | `cmd.Parameters.AddWithValue` |
| `@Html.Raw(x)`, `MarkupString` (Blazor) | XSS | encodar |
| `BinaryFormatter` | RCE (obsoleto e removido no .NET 9) | `System.Text.Json` |
| `JsonSerializerSettings { TypeNameHandling = All }` (Newtonsoft) | RCE | `TypeNameHandling.None` |
| `[Authorize]` como opt-in | rota nova sem atributo | política global via `RequireAuthenticatedUser()` + `[AllowAnonymous]` opt-out |
| `[ValidateAntiForgeryToken]` ausente em POST de formulário | CSRF | `AutoValidateAntiforgeryTokenAttribute` global |
| `Process.Start` com string única | command injection | `ProcessStartInfo` com `ArgumentList` |
| `Path.Combine(root, userInput)` | traversal | `Path.GetFullPath` + verificar prefixo |

---

## Configuração e infra dentro do repositório

Achados de configuração são baratos de encontrar e frequentemente de severidade alta. Para
pipeline, dependência e assinatura de artefato, veja `references/supply-chain-e-cicd.md`.

**Dockerfile**

```bash
rg -n -e '^USER|^FROM|^COPY|^ADD|^ENV|--no-check-certificate|latest$' Dockerfile*
```

| Padrão | Risco |
|---|---|
| ausência de `USER` não-root | container roda como uid 0; escapada vira root no host se houver má configuração de runtime |
| `FROM ...:latest` | build não reproduzível; use digest `@sha256:` |
| `COPY . .` sem `.dockerignore` | `.env`, `.git`, chave SSH e credencial de CI vão para a imagem |
| `ENV API_KEY=...` ou `ARG SECRET` | segredo persiste na camada; `docker history` revela |
| `RUN ... && rm segredo` | não adianta: a camada anterior guarda o arquivo. Use `RUN --mount=type=secret` |
| build sem multi-stage | toolchain, `.git` e devDependencies na imagem final |
| `ADD http://...` | download sem verificação; `ADD` também extrai tar automaticamente |

**docker-compose**

```bash
rg -n -e 'ports:' -A2 -e 'password|POSTGRES_PASSWORD|MYSQL_ROOT_PASSWORD|privileged|network_mode' \
      -e '/var/run/docker.sock' docker-compose*.y*ml
```

`ports: "5432:5432"` publica o Postgres em todas as interfaces do host (use `"127.0.0.1:5432:5432"`
ou só `expose`). Senha default (`postgres/postgres`) em compose que também serve de staging.
Montar `/var/run/docker.sock` dentro de container é root no host, sem rodeios.

**Kubernetes**

```bash
rg -n -e 'privileged: true|allowPrivilegeEscalation: true|runAsUser: 0|hostNetwork|hostPID|hostPath' \
      -e 'kind: Secret' -A5 -e 'valueFrom:|env:' -e 'resources:' -e 'automountServiceAccountToken' \
      -g '*.yaml' -g '*.yml'
```

Procure: `privileged: true`, `hostPath` montando `/` ou `/var/run/docker.sock`, ausência de
`resources.limits` (DoS por vizinho barulhento), `Secret` com `stringData` versionado (base64 não é
cifra), segredo em `env` (aparece em `kubectl describe` e em crash dump) versus `volumeMount`,
`automountServiceAccountToken: true` desnecessário, RBAC com `verbs: ["*"]` e
`resources: ["*"]`, ausência de `NetworkPolicy` (tráfego leste-oeste livre).

**Terraform**

```bash
rg -n -e '0\.0\.0\.0/0|::/0' -e 'acl\s*=\s*"public-read"|public_access_block' \
      -e '"\*"' -e 'encrypted\s*=\s*false|skip_final_snapshot' \
      -e 'publicly_accessible\s*=\s*true' -g '*.tf'
```

`ingress` com `cidr_blocks = ["0.0.0.0/0"]` numa porta que não seja 443/80; política IAM com
`"Action": "*"` e `"Resource": "*"`; bucket S3 sem `aws_s3_bucket_public_access_block`;
`publicly_accessible = true` em RDS; `storage_encrypted = false`; e — o clássico — segredo em
variável sem `sensitive = true`, que sai no plan/log do CI. Além disso: `terraform.tfstate`
versionado contém **todos** os valores, inclusive senhas geradas.

**nginx / proxy**

Procure `proxy_pass` com variável (SSRF/request smuggling), `underscores_in_headers on`,
ausência de `proxy_set_header X-Forwarded-For` sanitizado (permite spoof de IP usado em rate limit
ou allowlist), `add_header` dentro de bloco que sobrescreve headers do bloco pai (herança do nginx:
um `add_header` em `location` cancela **todos** os do `server`), e alias sem barra final
(`location /files { alias /var/data; }` permite `/files../` → traversal).

**CORS e headers na configuração**

```bash
rg -n -i -e 'cors|Access-Control-Allow' -A5
rg -n 'helmet|contentSecurityPolicy|Strict-Transport-Security|X-Frame-Options'
```

O padrão perigoso é refletir o `Origin` recebido com `credentials: true` — isso é equivalente a
`*` com credenciais, que o navegador proíbe explicitamente. Também: `origin: true` no `cors` do
Express/Fastify reflete qualquer origem. Detalhes em `references/ssrf-e-camada-http.md` e
`references/xss-e-navegador.md`.

**Variáveis de ambiente e segredos**

```bash
rg -n -i -e 'password|passwd|secret|token|api[_-]?key|private[_-]?key|BEGIN .* PRIVATE KEY' \
      -g '!*.lock' -g '!node_modules' -g '!*.min.js'
git log --all --diff-filter=D --name-only | rg -i '\.env|\.pem|credential|secret'
git log -p --all -S 'BEGIN RSA PRIVATE KEY' --oneline | head
```

Segredo removido num commit posterior **continua no histórico** e deve ser tratado como vazado:
rotação, não `git rm`. Veja `references/criptografia-e-segredos.md`.

---

## Como escrever o achado

Achado mal escrito não vira correção. O leitor do relatório é um dev com 20 minutos e três outros
incêndios; ele precisa entender em 30 segundos por que isso importa e o que digitar.

Estrutura obrigatória:

1. **Título que diz o impacto**, não o nome da categoria. "SQL injection em `/api/report`" é fraco;
   "Qualquer usuário autenticado lê a tabela `users` inteira via parâmetro `sort` em `/api/report`"
   é acionável.
2. **Localização exata**: `arquivo:linha`, com o trecho citado.
3. **Cadeia de exploração em passos**: entrada → caminho → efeito. Cada passo verificável.
4. **Impacto no negócio**: quem consegue fazer o quê com o dado de quem.
5. **Severidade justificada**, com o raciocínio explícito (pré-requisitos, alcance). Metodologia em
   `references/threat-modeling-e-severidade.md`.
6. **Correção concreta**, em forma de patch aplicável.
7. **Como verificar** que a correção funciona.

### Template preenchido

> ### XSS armazenado em ticket permite escalar para admin
>
> **Severidade**: Alta (CVSS 8.0 — AV:N/AC:L/PR:L/UI:R/S:C/C:H/I:H/A:N). CWE-79 · A03:2025 Injection.
>
> **Local**: `apps/web/src/components/TicketBody.tsx:34`; entrada em
> `apps/api/src/routes/tickets.ts:58`.
>
> ```tsx
> // apps/web/src/components/TicketBody.tsx:34
> <div dangerouslySetInnerHTML={{ __html: ticket.description }} />
> ```
>
> A `description` é gravada sem sanitização (`tickets.ts:58` faz `data: { description: body.description }`
> após um `z.string().max(10000)` — que valida tamanho, não conteúdo) e renderizada sem sanitização
> no painel de suporte.
>
> **Cadeia de exploração**
> 1. Usuário com conta gratuita cria ticket com `description` contendo
>    `<img src=x onerror="fetch('/api/admin/users',{method:'POST',body:...})">`.
> 2. O valor é persistido íntegro em `tickets.description` (nenhum sanitizador no caminho —
>    confirmado por `rg -n 'sanitize|DOMPurify' apps/api` sem resultado).
> 3. Um agente de suporte (papel `admin`) abre `/admin/tickets/:id`; o React injeta o HTML no DOM
>    via `dangerouslySetInnerHTML`.
> 4. O script roda na origem `app.exemplo.com` com o cookie de sessão do admin (`HttpOnly` impede
>    ler o cookie, **não** impede fazer requisições autenticadas a partir da página).
>
> **Impacto**: qualquer pessoa que consiga criar um ticket — inclusive na conta gratuita — executa
> JavaScript na sessão de um administrador. Como `/api/admin/users` aceita criação de usuário com
> papel `admin` e é autorizada só por cookie de sessão, a cadeia resulta em criação de conta
> administrativa persistente. Não é vazamento de um ticket: é comprometimento do painel.
>
> **Correção**
> ```tsx
> import DOMPurify from 'isomorphic-dompurify'
>
> // ✅ sanitiza no ponto de render, com allowlist restrita
> <div dangerouslySetInnerHTML={{
>   __html: DOMPurify.sanitize(ticket.description, {
>     ALLOWED_TAGS: ['b','i','em','strong','a','p','br','ul','ol','li','code','pre'],
>     ALLOWED_ATTR: ['href','title'],
>     ALLOWED_URI_REGEXP: /^https?:/i,
>   })
> }} />
> ```
> Sanitizar **no render** e não na escrita: dado já gravado continua malicioso, e outro caminho de
> escrita (import de e-mail, migração) escaparia da sanitização na entrada. Como defesa em
> profundidade, adicionar CSP `script-src 'self' 'nonce-...'` na rota `/admin`
> (veja `references/xss-e-navegador.md`).
>
> **Verificação**
> ```bash
> # antes: retorna o payload íntegro no HTML do painel
> curl -s -H "Cookie: $ADMIN" http://localhost:3000/admin/tickets/$ID | rg 'onerror'
> ```
> Teste de regressão: `apps/web/src/components/__tests__/TicketBody.test.tsx` renderizando
> `<img src=x onerror=alert(1)>` e afirmando que `container.querySelector('img[onerror]')` é `null`.
> O teste falha no código atual e passa com o patch.

### O mesmo achado, mal escrito

> **XSS**
>
> Severidade: Crítica
>
> Encontrado uso de `dangerouslySetInnerHTML` no frontend. Isso pode permitir Cross-Site Scripting.
> Recomenda-se sanitizar todas as entradas do usuário e implementar uma política de segurança de
> conteúdo. Referência: OWASP Top 10.

O que está errado, item por item: não diz onde (o dev vai ter que procurar); não prova que existe
caminho da entrada até o sink (pode ser conteúdo estático, e aí é falso positivo); não diz quem
explora nem o que ganha; "Crítica" sem justificativa infla a severidade e desvaloriza os achados
realmente críticos; "sanitizar todas as entradas" é conselho genérico que não indica *onde* nem
*com qual allowlist*; e não há como verificar se foi corrigido. Achados assim geram uma reunião,
não um commit.

---

## Calibração: quando NÃO é vulnerabilidade

Falso positivo tem custo composto: consome tempo do time, ensina o time a ignorar seu relatório, e
enterra o achado verdadeiro que estava na página seguinte. Antes de escrever qualquer achado,
passe pelos quatro testes.

**1. Existe caminho real da entrada não confiável até o sink?**
Se o argumento do sink é literal do próprio código, constante de configuração, ou valor que o
servidor gerou (UUID, timestamp), não é injeção. `db.$queryRawUnsafe('SELECT 1')` é feio, não é
vulnerável. Se o dado vem do banco, pergunte quem o escreveu: dado escrito por outro usuário
**é** entrada não confiável; dado de seed não é.

**2. O atacante controla o suficiente?**
Controlar 4 dígitos numéricos após `parseInt` não permite injeção. Controlar um valor que passa por
`z.enum(['asc','desc'])` não permite injetar em `ORDER BY`. Controlar o *sufixo* de uma string já
prefixada e escapada geralmente não permite quebrar o contexto. Quantifique antes de reportar:
"o atacante controla a string inteira, sem filtro" versus "o atacante controla um inteiro entre 1 e
100".

**3. O controle já existe em outra camada?**
Antes de reportar autorização ausente num handler, verifique: middleware global, `SecurityFilterChain`,
`APP_GUARD`, decorator de classe, policy de rota, filtro de tenant no nível do ORM (Prisma
extensions, Rails `default_scope`, RLS no Postgres). Reportar "falta checagem de dono" onde há
Row Level Security ativa é o erro que mais rápido queima credibilidade.

**4. O impacto é real ou teórico?**
`Math.random()` para gerar o `key` de uma lista React não é fraqueza criptográfica. Falta de CSP
numa API que só devolve `application/json` com `X-Content-Type-Options: nosniff` tem impacto
próximo de zero. Timing attack em comparação de string de 1 byte não é explorável na prática pela
rede. Diga isso explicitamente em vez de listar como achado.

### Vulnerabilidade × hardening ausente × code smell

Separe em três listas e rotule cada item. Misturar destrói a leitura do relatório.

| Classe | Definição operacional | Exemplos |
|---|---|---|
| **Vulnerabilidade** | há cadeia de exploração descrevível com impacto concreto | IDOR em `/api/orders/:id`, SQL injection, auth ausente em rota admin |
| **Hardening ausente** | reduz o impacto de *outra* falha, mas sozinho não é explorável | falta de CSP, `helmet` ausente, ausência de `SameSite=Strict`, sem rate limit em endpoint barato, cookie sem `__Host-` prefix |
| **Code smell / risco futuro** | não é explorável hoje; aumenta a chance de virar bug | `any` em DTO, validação duplicada e divergente, `catch` genérico, dependência sem uso |

Um relatório com 3 vulnerabilidades e 14 itens de hardening claramente rotulados é lido. O mesmo
conteúdo como "17 vulnerabilidades encontradas" é descartado assim que o dev verificar o terceiro
item e concluir que você não sabe o que está falando.

### Falsos positivos comuns nesta disciplina

- **SQL montado com literal do próprio código** ou com identificador vindo de `z.enum`/allowlist.
- **`dangerouslySetInnerHTML` com conteúdo já sanitizado por DOMPurify** na mesma expressão, ou com
  markdown renderizado por biblioteca que escapa HTML por padrão.
- **`Math.random()` fora de contexto de segurança**: jitter de retry, `key` de lista, shuffle de UI.
- **CSRF em endpoint que só aceita `application/json`** e exige header customizado: o navegador não
  permite `Content-Type: application/json` cross-origin em formulário HTML sem preflight, e o
  preflight exige CORS permissivo. Verifique se o framework aceita `text/plain` como fallback antes
  de descartar — alguns parsers aceitam, e aí a proteção some.
- **Endpoint interno sem autenticação atrás de mTLS ou de `NetworkPolicy`** — confirme a topologia
  antes de reportar; se não conseguir confirmar, reporte como *incerteza*, não como achado.
- **`eval` em script de build** que roda com código do próprio repositório.
- **Dependência com CVE cuja função vulnerável não é alcançada** — reporte como higiene com
  severidade rebaixada e diga que a análise de alcance não foi feita, ou faça-a (`govulncheck`,
  `npm audit --omit=dev`, Snyk reachability). Veja `references/supply-chain-e-cicd.md`.
- **Ausência de `rel="noopener"`** em `target="_blank"`: navegadores aplicam `noopener` implícito
  desde 2021.
- **`X-XSS-Protection` ausente**: o header foi removido dos navegadores; recomendá-lo é sinal de
  checklist desatualizado.

### Como reportar incerteza honestamente

Você frequentemente não tem como confirmar tudo — não tem o ambiente, não vê a config de produção,
não sabe se o WAF filtra. Diga isso, com precisão sobre **o que** falta e **qual** é a conclusão em
cada cenário:

> **Não confirmado.** `apps/api/src/routes/internal.ts:22` não faz checagem de autenticação. Não
> consegui determinar se o middleware `requireServiceToken` (registrado em `server.ts:41`) se aplica
> a este prefixo: o registro usa `app.register(internalRoutes, { prefix: '/internal' })` e o hook é
> adicionado dentro de outro escopo. **Se** o hook não cobrir este escopo, qualquer requisição que
> alcance o processo lê dados de qualquer tenant (Alta). **Se** cobrir, não há achado. Verificação
> em um comando: `curl -s -o /dev/null -w '%{http_code}' localhost:3000/internal/tenants` — 401
> confirma cobertura; 200 confirma o achado.

Esse formato é útil porque converte incerteza em uma ação de 10 segundos. "Possivelmente vulnerável,
recomenda-se investigar" não é.

---

## Verificação do achado

Em ordem decrescente de valor entregue.

**1. Teste que falha antes e passa depois.** É o entregável de maior valor: prova a existência,
documenta o comportamento esperado e impede a regressão. Escreva-o no framework de teste que o
repositório já usa.

```ts
// apps/api/test/tickets.authz.test.ts — falha no código atual (retorna 200)
import { describe, it, expect } from 'vitest'
import { build } from '../src/app'

describe('GET /api/tickets/:id', () => {
  it('não permite ler ticket de outro tenant', async () => {
    const app = await build()
    const ticketDeOutroTenant = await seedTicket({ tenantId: 'tenant-b' })
    const res = await app.inject({
      method: 'GET',
      url: `/api/tickets/${ticketDeOutroTenant.id}`,
      headers: { authorization: `Bearer ${tokenDe('tenant-a')}` },
    })
    expect(res.statusCode).toBe(404) // 404, não 403: não confirmar existência
  })
})
```

Rode antes do patch (`vitest run tickets.authz` → falha) e depois (passa). Cite as duas execuções no
achado.

**2. Reprodução com `curl`.** Uma linha, copiável, contra ambiente local ou de teste autorizado.
Use variáveis para credencial em vez de colar token no relatório.

```bash
# IDOR — o token é do tenant A, o ticket é do tenant B
curl -i -H "Authorization: Bearer $TOKEN_A" http://localhost:3000/api/tickets/$ID_TENANT_B

# Injeção em ORDER BY — resposta com ordem diferente confirma que o input vira SQL
curl -s "http://localhost:3000/api/report?sort=name" | md5sum
curl -s "http://localhost:3000/api/report?sort=(CASE WHEN 1=1 THEN name ELSE id END)" | md5sum

# Verificação de escopo de middleware
for p in /internal/tenants /admin/users /api/health; do
  printf '%s %s\n' "$(curl -s -o /dev/null -w '%{http_code}' localhost:3000$p)" "$p"
done
```

**3. PoC mínima.** O menor payload que demonstra a falha e nada além dela: `' OR 1=1--` para provar
injeção, `<img src=x onerror=alert(1)>` para provar XSS, um `id` alheio para provar IDOR. Não
escreva exploit encadeado, não faça dump de tabela, não escale para RCE "para mostrar impacto" — a
existência do primitivo é a prova; a escalada é descrição textual.

**4. Quando é irresponsável testar.**

- **Produção**, sempre que o teste escreve, apaga, envia e-mail/SMS, cobra cartão, dispara webhook
  para terceiro, ou consome quota paga. Ler dado de produção que não é seu também não: é acesso não
  autorizado a dado pessoal, independentemente da intenção.
- **Dado de terceiro**: nunca use conta, documento, cartão ou PII de pessoa real. Use dados
  sintéticos e contas de teste criadas para isso.
- **Sistemas de terceiros** alcançados via SSRF: confirmar SSRF apontando para um domínio de
  colaboração próprio (ou `127.0.0.1`/`169.254.169.254` em ambiente de teste) é legítimo; usar o
  SSRF do cliente para tocar infraestrutura alheia não é.
- **DoS e força bruta**: demonstre a *ausência de limite* pela leitura do código e por um número
  pequeno de requisições, não derrubando o serviço.
- Sem escopo autorizado por escrito, não teste: descreva o achado a partir do código.

---

## Sequência padrão para uma revisão de repositório

Plano para quando o pedido for vago ("revise a segurança deste repositório"). Tempos são para um
codebase de porte médio (30–100 mil linhas); ajuste proporcionalmente e **diga ao usuário** qual
foi o escopo real coberto.

| # | Etapa | Tempo | Entregável |
|---|---|---|---|
| 1 | Reconhecimento: stack, versões, tamanho, existência de SAST, atores do sistema | 15 min | resumo de 5 linhas + lista de atores |
| 2 | Inventário de entradas: rotas, jobs, webhooks, CLI, uploads | 30–45 min | tabela método/caminho/arquivo/quem chama |
| 3 | Inventário de sinks: SQL, shell, FS, HTTP saída, render, deserialização | 30 min | tabela sink/arquivo/origem do argumento |
| 4 | Mapa de controles: authn, authz, validação, sanitização — global ou opt-in? | 30 min | descrição do padrão + lista de exceções |
| 5 | Varredura automatizada como rede de segurança (não como a revisão) | 15 min | saída triada, não colada crua |
| 6 | Análise dirigida: cruzar entradas × sinks × controles; seguir os caminhos | 2–5 h | rascunho dos achados com cadeia |
| 7 | Hotspots históricos: novo, antigo, churn, TODO, hotfix, admin, migração | 45 min | achados adicionais |
| 8 | Config e infra: Docker, compose, k8s, Terraform, CORS, headers, segredos | 45 min | achados de configuração |
| 9 | Calibração: descartar falso positivo, separar vulnerabilidade/hardening/smell | 30 min | listas rotuladas |
| 10 | Verificação: teste ou `curl` para os achados de severidade Alta+ | 45 min | prova por achado |
| 11 | Redação: severidade justificada, patch, ordem de correção | 45 min | relatório final |

Etapa 5, os comandos:

```bash
semgrep scan --config p/security-audit --config p/owasp-top-ten --config p/secrets .
# ou, para o conjunto curado padrão:
semgrep scan --config auto .

npm audit --omit=dev            # Node
govulncheck ./...               # Go (analisa alcance real, não só versão)
pip-audit                       # Python
brakeman -A                     # Rails
osv-scanner scan source -r .    # multi-ecossistema
gitleaks detect --no-git        # segredos na árvore
gitleaks detect                 # segredos no histórico
trivy fs --scanners vuln,secret,misconfig .   # imagem/IaC/segredo
checkov -d .                    # Terraform/k8s
```

Toda saída de ferramenta passa por triagem antes de entrar no relatório: para cada item, aplique os
quatro testes de [calibração](#calibração-quando-não-é-vulnerabilidade). Colar saída de SAST crua
não é revisão de segurança — é terceirizar a decisão para o usuário. Detalhes de configuração e
integração das ferramentas em `references/ferramentas.md`; integração no pipeline em
`references/supply-chain-e-cicd.md`.

Ordem de entrega do relatório: (1) veredito em uma frase — "encontrei 2 falhas de autorização
exploráveis por qualquer usuário autenticado"; (2) achados por severidade decrescente; (3) hardening;
(4) escopo coberto e **o que não foi revisado**; (5) ordem sugerida de correção. O item (4) é o que
torna o relatório honesto e o que impede que "revisado" seja lido como "seguro".

Nota sobre a fonte canônica: o **OWASP Code Review Guide v2.0 é de julho de 2017** e sua segunda
seção é baseada no Top 10 de 2013. A estrutura de processo dele continua válida; os exemplos de
código e as prioridades, não. Para prioridades atuais use o **OWASP Top 10:2025** (veja
`references/owasp-top10.md`) e o **CWE Top 25 de 2025** (publicado em 15/12/2025), cujos cinco
primeiros são CWE-79 (XSS), CWE-89 (SQL injection), CWE-352 (CSRF), CWE-862 (Missing Authorization)
e CWE-787 (Out-of-bounds Write) — note que CWE-352 saltou para 3º e que autorização (CWE-862,
CWE-863, CWE-284, CWE-639) ocupa quatro posições, o que confirma onde vale gastar o tempo de
revisão manual.

## Fontes

- [OWASP Code Review Guide v2.0 (2017)](https://owasp.org/www-project-code-review-guide/) — processo ainda útil, exemplos desatualizados
- [OWASP Web Security Testing Guide v4.2](https://owasp.org/www-project-web-security-testing-guide/) — o que testar por categoria
- [OWASP Top 10:2025](https://owasp.org/Top10/2025/) · [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)
- [2025 CWE Top 25 Most Dangerous Software Weaknesses](https://cwe.mitre.org/top25/archive/2025/2025_cwe_top25.html) (15/12/2025)
- [Next.js — How to think about data security](https://nextjs.org/docs/app/guides/data-security) · [Security and Server Actions (blog)](https://nextjs.org/blog/security-nextjs-server-components-actions)
- [React — `experimental_taintObjectReference`](https://react.dev/reference/react/experimental_taintObjectReference)
- [Django — Security in Django](https://docs.djangoproject.com/en/stable/topics/security/) · [Raw SQL / `raw()` e `extra()`](https://docs.djangoproject.com/en/stable/topics/db/sql/)
- [Ruby on Rails — Securing Rails Applications](https://guides.rubyonrails.org/security.html) · [Brakeman](https://brakemanscanner.org/)
- [Spring Security — CSRF](https://docs.spring.io/spring-security/reference/features/exploits/csrf.html) · [Authorization](https://docs.spring.io/spring-security/reference/servlet/authorization/index.html)
- [Go `html/template`](https://pkg.go.dev/html/template) · [`text/template`](https://pkg.go.dev/text/template) · [govulncheck](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck)
- [Laravel — Blade Templates (escaping)](https://laravel.com/docs/13.x/blade) · [Eloquent mass assignment](https://laravel.com/docs/13.x/eloquent#mass-assignment)
- [EF Core — SQL Queries e parametrização](https://learn.microsoft.com/en-us/ef/core/querying/sql-queries)
- [Prisma — Raw queries](https://www.prisma.io/docs/orm/prisma-client/using-raw-sql/raw-queries)
- [Semgrep — Running rules e rulesets](https://docs.semgrep.dev/running-rules) · [Semgrep Registry](https://semgrep.dev/explore)
- [PortSwigger Web Security Academy](https://portswigger.net/web-security) — laboratórios por classe de falha
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker) · [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
