# Ferramental de segurança — o que rodar, com qual comando, e o que a saída vale

Este é o arquivo **executável** da skill. Ele não explica vulnerabilidade — explica **ferramenta**:
qual usar para cada artefato que você tem em mãos (código-fonte, URL, APK, imagem de container,
Terraform), o comando exato de primeira execução no macOS, o que a ferramenta encontra, o que ela
**não** encontra, e quanto ruído esperar. Abra este arquivo quando precisar: começar uma revisão em
um repositório desconhecido, escolher entre duas ferramentas que parecem fazer a mesma coisa,
escrever uma regra de Semgrep, montar o pipeline de CI, ou decidir se um achado de scanner é real.

Todo comando aqui é real e testado contra a documentação oficial. Onde a sintaxe mudou de versão
(gitleaks 8.19, osv-scanner v2, schemathesis v4, ZAP no ghcr.io), o texto diz qual é a atual e qual
é a antiga — comando desatualizado é a forma mais rápida de destruir a confiança em um arquivo como
este. As versões citadas foram conferidas em agosto de 2026.

## Índice

- [Regra zero: duas classes de ferramenta](#regra-zero-duas-classes-de-ferramenta)
- [Tabela de decisão: o que eu tenho → o que eu rodo](#tabela-de-decisão-o-que-eu-tenho--o-que-eu-rodo)
- [O combo de 5 minutos](#o-combo-de-5-minutos)
- [SAST: Semgrep em profundidade](#sast-semgrep-em-profundidade)
- [SAST: o resto do arsenal](#sast-o-resto-do-arsenal)
- [Calibração de SAST: por que "zerar" não é a meta](#calibração-de-sast-por-que-zerar-não-é-a-meta)
- [SCA: dependências vulneráveis](#sca-dependências-vulneráveis)
- [Triagem de SCA: EPSS + KEV + alcançabilidade](#triagem-de-sca-epss--kev--alcançabilidade)
- [Segredos: varrer o disco e o histórico](#segredos-varrer-o-disco-e-o-histórico)
- [Container e IaC](#container-e-iac)
- [CLASSE REDE: DAST e teste de aplicação em execução](#classe-rede-dast-e-teste-de-aplicação-em-execução)
- [Mobile](#mobile)
- [Fuzzing e teste de propriedade](#fuzzing-e-teste-de-propriedade)
- [Montar o pipeline](#montar-o-pipeline)
- [Política de falha: o que decide o sucesso](#política-de-falha-o-que-decide-o-sucesso)
- [Laboratórios para praticar e validar ferramenta](#laboratórios-para-praticar-e-validar-ferramenta)
- [Falsos positivos comuns do ferramental](#falsos-positivos-comuns-do-ferramental)
- [Fontes](#fontes)

## Regra zero: duas classes de ferramenta

A distinção mais importante deste arquivo não é técnica, é jurídica. Toda ferramenta aqui cai em uma
de duas classes, e confundi-las é a diferença entre revisar código e atacar um sistema.

---

> ### CLASSE LOCAL — leitura de arquivo
>
> SAST, SCA, secret scanning, análise de IaC, decompilação de binário que você possui. **Só lê
> bytes do disco.** Não abre socket para o alvo, não gera log no servidor de ninguém, não consome
> quota de API alheia. Se você tem permissão de ler o repositório, tem permissão de rodar isso.
> Rode à vontade, inclusive em código de terceiros que você baixou legitimamente.
>
> Semgrep · CodeQL · ESLint · gosec · bandit · brakeman · njsscan · osv-scanner · trivy fs ·
> govulncheck · gitleaks · trufflehog (sem `--only-verified`) · hadolint · checkov · zizmor ·
> jadx · apktool

---

> ### CLASSE REDE — tráfego contra um alvo
>
> DAST, scanner de porta, fuzzer de API, descoberta de conteúdo, enumeração de subdomínio,
> exploração automatizada. **Gera requisições contra um sistema.** Isso é indistinguível de um
> ataque do ponto de vista do defensor: aparece no WAF, no SIEM, no rate limiter, e pode derrubar
> um endpoint frágil. Rode **apenas** contra:
>
> 1. alvo que você mesmo hospeda (localhost, seu staging, um laboratório da lista no fim deste
>    arquivo), **ou**
> 2. alvo coberto por **autorização escrita** — contrato de pentest com escopo definido, ou o
>    escopo publicado de um programa de bug bounty (e o escopo é literal: `*.exemplo.com` não
>    inclui `exemplo.net`, e um endpoint fora da lista é fora da lista).
>
> No Brasil isso é o art. 154-A do Código Penal (invasão de dispositivo informático, Lei
> 12.737/2012, com pena agravada pela Lei 14.155/2021). Nos EUA, o CFAA. Na UE, a Diretiva
> 2013/40. Nenhum desses tem exceção para "eu só estava testando". Autorização escrita é o que
> converte o teste em trabalho legítimo.
>
> OWASP ZAP · Burp Scanner · nuclei · ffuf · feroxbuster · sqlmap · nikto · schemathesis ·
> RESTler · amass/subfinder (enumeração ativa) · trufflehog `--only-verified` (valida a credencial
> chamando a API do provedor — isso é tráfego)

---

Uma exceção que confunde: `trufflehog` com verificação ativa faz uma chamada à API do provedor
(`sts:GetCallerIdentity` para uma chave AWS, por exemplo) para checar se a credencial está viva.
Isso é rede, e usa a credencial encontrada. É legítimo quando a credencial é da sua organização;
não é quando você achou a chave de um terceiro num repositório público.

## Tabela de decisão: o que eu tenho → o que eu rodo

| Tenho | Primeira ferramenta | Segunda | O que isso não vai achar |
|---|---|---|---|
| **Código-fonte** (repo local) | `semgrep scan --config p/default` | `osv-scanner scan source -r .` + `gitleaks git .` | Falha de lógica de negócio, IDOR, race condition |
| **Código-fonte Go** | `govulncheck ./...` | `gosec ./...` + `staticcheck ./...` | Vulnerabilidade em dependência não alcançada (por design) |
| **Código-fonte Python** | `uvx bandit -r . -ll` | `uvx pip-audit` | Type confusion, uso inseguro de `pickle` fora dos sinks conhecidos |
| **Monorepo poliglota** | `trivy fs --scanners vuln,misconfig,secret .` | `semgrep --config auto` | Tudo que exige contexto de negócio |
| **Só a URL** (app rodando) | ZAP baseline (**exige autorização**) | Burp Suite manual + nuclei | Qualquer coisa atrás de auth que o scanner não sabe fazer |
| **URL + spec OpenAPI** | `zap-api-scan.py -f openapi` | `schemathesis run` (**exige autorização**) | BOLA/IDOR — nenhum scanner conhece seu modelo de permissão |
| **APK / IPA** | MobSF (docker, análise estática) | `jadx -d out app.apk` + grep | Comportamento em runtime, pinning real, lógica do servidor |
| **Imagem de container** | `trivy image <img>` | `grype <img>` + `dockle <img>` | Config do runtime (capabilities, seccomp) — isso é `trivy k8s` |
| **Dockerfile** | `hadolint Dockerfile` | `trivy config .` | Se a imagem base já vem comprometida |
| **Terraform / CloudFormation** | `checkov -d .` | `trivy config .` | Drift entre o código e o que está de fato na conta |
| **Manifests Kubernetes** | `kube-score score *.yaml` | `trivy k8s` / `polaris audit` | RBAC efetivo do cluster real |
| **GitHub Actions** | `zizmor .github/workflows/` | `actionlint` + `pinact run --check` | Segredo exposto em log de execução passada |
| **Binário Go/ELF sem fonte** | `govulncheck -mode binary ./bin` | `syft` → `grype` sobre o SBOM | Praticamente tudo que não seja dependência conhecida |
| **Só um PR / diff** | `semgrep ci --baseline-commit <base>` | `gitleaks git --log-opts="<base>..HEAD"` | Regressão introduzida em arquivo não tocado |

Uma linha que vale repetir: **nenhuma ferramenta desta tabela encontra falha de autorização.**
IDOR, BOLA, escalação horizontal e bypass de máquina de estados exigem conhecer o modelo de
permissões da aplicação — leia `references/autorizacao-e-logica-de-negocio.md`. Scanner encontra
padrão sintático e CVE conhecida; a categoria #1 do OWASP Top 10 continua sendo trabalho humano.

## O combo de 5 minutos

Repositório desconhecido, na sua máquina, sem autorização especial (tudo aqui é **CLASSE LOCAL**).
Esta é a sequência com melhor retorno por minuto investido. Rode na raiz do repositório.

```bash
# 0. pré-requisitos, uma vez só
brew install semgrep gitleaks osv-scanner trivy zizmor

cd /caminho/do/repo

# 1. SEGREDOS NO HISTÓRICO INTEIRO — 10 a 90 s. Achado aqui costuma ser o de maior severidade
#    real do dia, porque credencial commitada já vazou mesmo que o commit tenha sido removido.
gitleaks git . --redact -v

# 2. DEPENDÊNCIAS VULNERÁVEIS, TODOS OS ECOSSISTEMAS DE UMA VEZ — 10 a 40 s.
#    Lê lockfiles (package-lock.json, pnpm-lock.yaml, go.sum, poetry.lock, Cargo.lock, pom.xml...).
osv-scanner scan source -r .

# 3. SAST — 1 a 4 min. p/default é o conjunto curado de alta confiança; p/owasp-top-ten amplia.
semgrep scan --config p/default --config p/owasp-top-ten --metrics=off .

# 4. MISCONFIG (Dockerfile, Terraform, k8s, GitHub Actions) + segredos em arquivo — 20 a 60 s.
trivy fs --scanners misconfig,secret --severity HIGH,CRITICAL .

# 5. GITHUB ACTIONS — 2 s. Barato demais para pular se .github/workflows existe.
zizmor .github/workflows/
```

Depois dos cinco, gaste dez minutos de olho humano naquilo que scanner nenhum vê:

```bash
# Onde estão os endpoints e quais deles não têm middleware de auth?
rg -n "app\.(get|post|put|patch|delete)|fastify\.(get|post|route)|@(Get|Post|Put|Delete)\(" --type ts

# Toda checagem de permissão do projeto — e depois: quais rotas NÃO aparecem aqui?
rg -n "requireAuth|isAuthenticated|preHandler|can\(|authorize|abilities|casl|ownerId" --type ts

# Sinks de alto valor, um grep que sempre paga
rg -n "queryRawUnsafe|executeRawUnsafe|dangerouslySetInnerHTML|child_process|eval\(|new Function\(|rejectUnauthorized" --type ts
```

Ordem importa: rodar `gitleaks` primeiro porque um segredo vivo muda a prioridade de tudo mais
(vira incidente, não achado), e rodar `semgrep` por último porque é o mais lento.

## SAST: Semgrep em profundidade

> **CLASSE LOCAL.** Semgrep 1.171.0 via `brew install semgrep`. Alternativas sem instalar:
> `uvx semgrep scan ...` (Python) ou `docker run --rm -v "$PWD:/src" semgrep/semgrep semgrep scan`.

Semgrep é a ferramenta mais útil deste arquivo porque combina três coisas que raramente coexistem:
casa padrão **sintático** (não regex — ele parseia a linguagem, então `foo(1,2)` casa `foo( 1 , 2 )`
e ignora comentário), tem um registry grande de regras curadas, e a linguagem de regra é escrevível
em cinco minutos. O ponto fraco é o inverso: a versão open source faz análise **intra-arquivo** por
padrão. Fluxo de dado que atravessa arquivos (o `req.query.id` que passa por três camadas até o
`exec()`) é território de CodeQL ou do Semgrep Pro Engine (pago).

### Comandos que importam

```bash
# Varredura local, sem conta, sem telemetria
semgrep scan --config p/default --metrics=off .

# Vários rulesets ao mesmo tempo (--config é repetível)
semgrep scan --config p/security-audit --config p/owasp-top-ten --config p/secrets .

# `auto` busca o ruleset adequado ao projeto no registry — CUIDADO: ele autentica contra o
# Semgrep Registry usando a URL do seu projeto, o que envia metadado. Em código sensível,
# prefira --config explícito.
semgrep --config auto .

# Só o que o PR introduziu (o modo que realmente é usável em CI)
semgrep scan --config p/default --baseline-commit "$(git merge-base origin/main HEAD)" .

# SARIF para o GitHub Code Scanning
semgrep scan --config p/default --sarif --output semgrep.sarif .

# Falhar o build só em ERROR
semgrep scan --config p/default --severity ERROR --error .

# Aplicar autofix das regras que têm chave `fix:` (revise o diff antes de commitar)
semgrep scan --config p/default --autofix --dryrun .
```

`semgrep scan` é o comando local; `semgrep ci` é o comando de pipeline — ele lê `SEMGREP_APP_TOKEN`,
aplica a política da organização e faz diff-aware automaticamente contra a branch base. Sem token,
`semgrep ci` funciona mas roda tudo. Em projeto sem conta Semgrep, use `semgrep scan
--baseline-commit`, que dá o mesmo efeito sem SaaS.

### Rulesets que valem para um stack TypeScript/Node

| Ruleset | O que traz | Ruído |
|---|---|---|
| `p/default` | conjunto curado de alta confiança, multi-linguagem | baixo — é o que rodar primeiro |
| `p/security-audit` | amplo, focado em segurança | **alto** — pensado para auditoria manual, não para gate de CI |
| `p/owasp-top-ten` | regras mapeadas às categorias OWASP | médio |
| `p/javascript`, `p/typescript` | regras de linguagem | médio |
| `p/react` | `dangerouslySetInnerHTML`, `href` com `javascript:`, refs inseguras | baixo |
| `p/nodejs` | `child_process`, path traversal, `fs` com input dinâmico | médio |
| `p/secrets` | credencial em código (sobrepõe gitleaks; use um dos dois) | médio |
| `p/docker`, `p/terraform`, `p/github-actions` | IaC/CI (mas `checkov` e `zizmor` são melhores nisso) | médio |

Regra prática: **`p/default` no gate bloqueante, `p/security-audit` no relatório nightly.** Colocar
`p/security-audit` como bloqueante em PR é a forma mais rápida de fazer o time desabilitar o
Semgrep inteiro.

### Escrever regra custom

A sintaxe mínima exige `id`, `message`, `languages`, `severity` e exatamente um operador de padrão
(`pattern`, `patterns`, `pattern-either` ou `pattern-regex`). `severity` aceita a nomenclatura
clássica `INFO`/`WARNING`/`ERROR` e, nas versões atuais, também `LOW`/`MEDIUM`/`HIGH`/`CRITICAL`.

**Gotcha que economiza uma hora:** metavariável em Semgrep é `$` seguido de **maiúsculas**
(`$X`, `$SQL`, `$REQ`). Por isso `prisma.$queryRawUnsafe(...)` — que tem `$` no nome do método —
é lido como **código literal**, e o pattern funciona sem escape. Se o método se chamasse
`$QUERYRAW`, você teria um problema.

Salve como `.semgrep/regras.yml` e rode com `semgrep scan --config .semgrep/ .`

```yaml
rules:
  # ── 1. Prisma raw SQL com interpolação ──────────────────────────────────────
  - id: prisma-raw-unsafe-com-interpolacao
    languages: [typescript, javascript]
    severity: ERROR
    message: >-
      $queryRawUnsafe/$executeRawUnsafe recebe string montada por template literal ou
      concatenação. O dado vira sintaxe SQL. Use a tagged template `$queryRaw` (que
      parametriza) ou, se o identificador for dinâmico, valide contra uma allowlist.
    metadata:
      cwe: "CWE-89: Improper Neutralization of Special Elements used in an SQL Command"
      owasp: "A03:2025 - Injection"
      confidence: HIGH
      references:
        - https://www.prisma.io/docs/orm/prisma-client/using-raw-sql/raw-queries
    patterns:
      - pattern-either:
          - pattern: $DB.$queryRawUnsafe($SQL, ...)
          - pattern: $DB.$executeRawUnsafe($SQL, ...)
      - metavariable-pattern:
          metavariable: $SQL
          patterns:
            - pattern-either:
                - pattern: |
                    `...${...}...`
                - pattern: $A + $B
      # literal puro e constante importada não são achado
      - pattern-not: $DB.$queryRawUnsafe("...", ...)

  # ── 2. dangerouslySetInnerHTML sem sanitizador ───────────────────────────────
  - id: react-inner-html-sem-sanitizacao
    languages: [typescript, javascript]
    severity: ERROR
    message: >-
      dangerouslySetInnerHTML com valor que não passa por sanitizador conhecido.
      Envolva com DOMPurify.sanitize() ou sanitize-html antes de atribuir.
    metadata:
      cwe: "CWE-79: Improper Neutralization of Input During Web Page Generation"
      owasp: "A03:2025 - Injection"
      confidence: MEDIUM
    patterns:
      - pattern: <$EL dangerouslySetInnerHTML={{__html: $HTML}} />
      - pattern-not: <$EL dangerouslySetInnerHTML={{__html: DOMPurify.sanitize(...)}} />
      - pattern-not: <$EL dangerouslySetInnerHTML={{__html: $D.sanitize(...)}} />
      - pattern-not: <$EL dangerouslySetInnerHTML={{__html: sanitizeHtml(...)}} />
      - pattern-not: <$EL dangerouslySetInnerHTML={{__html: "..."}} />

  # ── 3. verificação de TLS desligada ──────────────────────────────────────────
  - id: tls-verificacao-desligada
    languages: [typescript, javascript]
    severity: ERROR
    message: >-
      Verificação de certificado TLS desativada. A conexão continua criptografada, mas
      qualquer MITM com certificado próprio é aceito — na prática o TLS deixa de autenticar
      o servidor. Se o problema é CA interna, adicione o CA ao trust store (NODE_EXTRA_CA_CERTS)
      em vez de desligar a verificação.
    metadata:
      cwe: "CWE-295: Improper Certificate Validation"
      owasp: "A02:2025 - Security Misconfiguration"
      confidence: HIGH
    pattern-either:
      - pattern: |
          {..., rejectUnauthorized: false, ...}
      - pattern: process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"
      - pattern: process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0'
      - pattern: |
          {..., strictSSL: false, ...}
    fix: |
      { rejectUnauthorized: true }
```

Para fluxo de dado dentro de um arquivo, o **modo taint** vale muito mais que pattern isolado —
ele só reporta quando existe caminho de uma fonte até um sink, e respeita sanitizador:

```yaml
rules:
  - id: input-de-request-ate-exec
    languages: [typescript, javascript]
    severity: ERROR
    mode: taint
    message: >-
      Dado controlado pelo cliente chega a child_process.exec (shell). Use execFile/spawn com
      array de argumentos, que não invoca shell, ou valide contra allowlist.
    metadata:
      cwe: "CWE-78: OS Command Injection"
      owasp: "A03:2025 - Injection"
    pattern-sources:
      - pattern-either:
          - pattern: $REQ.query
          - pattern: $REQ.body
          - pattern: $REQ.params
          - pattern: $REQ.headers
    pattern-sanitizers:
      - pattern: shellQuote.quote(...)
      - pattern: parseInt(...)
      - pattern: Number(...)
    pattern-sinks:
      - pattern-either:
          - pattern: child_process.exec(...)
          - pattern: child_process.execSync(...)
          - pattern: exec($CMD, ...)
```

Teste a regra antes de commitá-la. Semgrep tem um formato de teste embutido: escreva
`regras.ts` ao lado de `regras.yml` com comentários `// ruleid: <id>` na linha que deve casar e
`// ok: <id>` na que não deve, e rode `semgrep --test --config .semgrep/`. Regra sem teste
apodrece.

### Suprimir achado

```ts
// nosemgrep
const html = untrusted

// melhor: suprimir só a regra específica, com justificativa
// nosemgrep: react-inner-html-sem-sanitizacao -- conteúdo vem do CMS, já sanitizado no ingest
<div dangerouslySetInnerHTML={{ __html: cmsHtml }} />
```

`# nosemgrep` nu desliga **todas** as regras naquela linha, inclusive as que ainda não existem. Em
revisão, um `# nosemgrep` sem ID nem comentário é por si só um achado: sinaliza que alguém calou o
scanner sem entender o alerta. Para excluir caminhos inteiros, use `.semgrepignore` (mesma sintaxe
de `.gitignore`) ou `--exclude 'test/**'` — e note que Semgrep já ignora por padrão o que está no
`.gitignore`.

## SAST: o resto do arsenal

> **CLASSE LOCAL** — tudo nesta seção.

### CodeQL — quando vale o custo

CodeQL compila o código em um banco de dados relacional e roda queries sobre ele. É a única
ferramenta gratuita desta lista com **análise interprocedural de verdade**: ele segue o dado de
`req.params.id` no controller, através do service, até o `db.query()` no repositório. Isso é o que
o Semgrep OSS não faz.

O custo: criar o banco é lento (minutos a dezenas de minutos), consome bastante RAM, e para
linguagem compilada exige que o build funcione. E o licenciamento: o CodeQL CLI é gratuito para
**análise de repositórios open source**; usar em código proprietário exige GitHub Advanced Security.

```bash
# Instalação: baixe o bundle de github/codeql-action/releases (traz CLI + queries),
# ou `gh extension install github/gh-codeql` e use `gh codeql ...`

# Linguagens interpretadas: sem --command
codeql database create ./codeql-db --language=javascript-typescript --source-root .

# Linguagens compiladas: CodeQL precisa observar o build
codeql database create ./codeql-db --language=java-kotlin --command="./gradlew clean build"

codeql database analyze ./codeql-db \
  codeql/javascript-queries:codeql-suites/javascript-security-extended.qls \
  --format=sarif-latest --output=codeql.sarif
```

Identificadores de linguagem atuais: `javascript-typescript`, `java-kotlin`, `c-cpp`, `csharp`,
`go`, `python`, `ruby`, `rust`, `swift`, `actions`. As suites vão de `-code-scanning.qls` (padrão,
menos ruído) a `-security-extended.qls` (mais cobertura, mais falso positivo) e
`-security-and-quality.qls` (inclui qualidade — quase sempre ruído demais para segurança).

Quando vale: repositório grande e de vida longa, onde vale pagar 20 min de CI nightly para pegar
taint flow que o Semgrep não vê. Quando não vale: repositório pequeno, ou gate de PR (é lento
demais).

### ESLint com plugins de segurança — e a honestidade sobre o ruído

```bash
npm i -D eslint-plugin-security eslint-plugin-no-unsanitized
```

```js
// eslint.config.js (flat config, ESLint 9+)
import security from 'eslint-plugin-security'
import noUnsanitized from 'eslint-plugin-no-unsanitized'

export default [
  security.configs.recommended,
  { plugins: { 'no-unsanitized': noUnsanitized },
    rules: {
      'no-unsanitized/method': 'error',   // insertAdjacentHTML, document.write
      'no-unsanitized/property': 'error', // innerHTML, outerHTML
      // desligue a regra que gera 90% do ruído do plugin:
      'security/detect-object-injection': 'off',
    } },
]
```

Os próprios mantenedores do `eslint-plugin-security` escrevem no README que ele "encontra muitos
falsos positivos que precisam de triagem humana". Isso é literal. `detect-object-injection` dispara
em **qualquer** `obj[chave]` com chave variável — em um projeto TypeScript real isso são centenas de
ocorrências, quase todas inofensivas. `detect-non-literal-fs-filename` e `detect-unsafe-regex` são
mais úteis, mas ainda barulhentos.

O plugin que realmente vale é `eslint-plugin-no-unsanitized`: ele é focado, mantido pela Mozilla,
e as duas regras (`method` e `property`) pegam exatamente os sinks de DOM XSS com pouquíssimo falso
positivo. Se for adotar só um, adote esse.

### Por linguagem

```bash
# Go — gosec 2.28.0 (padrões inseguros) e staticcheck (correção; pega bug que vira falha)
brew install gosec staticcheck
gosec -fmt=sarif -out=gosec.sarif ./...
gosec -exclude=G104 ./...      # G104 = erro não tratado: ruidoso, trate no code review
staticcheck ./...

# Python — bandit
uvx bandit -r . -ll -f sarif -o bandit.sarif   # -ll = só MEDIUM e acima
# suprimir: `subprocess.call(cmd)  # nosec B602`

# Ruby on Rails — brakeman (o melhor SAST específico de framework que existe; entende rotas,
# controllers e o modelo do Rails, então tem taxa de falso positivo baixíssima)
gem install brakeman
brakeman -A --format sarif -o brakeman.sarif

# Node — njsscan (equipe do MobSF; regras Semgrep + padrões próprios)
uvx njsscan --sarif -o njsscan.sarif .

# Mobile (código-fonte Android/iOS) — mobsfscan
uvx mobsfscan --sarif -o mobsfscan.sarif .
```

`brakeman` merece destaque: por conhecer o framework, ele distingue `params[:id]` usado em `find`
(seguro) de `params[:q]` interpolado em `where` (injection). Ferramenta genérica não consegue fazer
isso. A lição transferível: **SAST específico de framework bate SAST genérico** sempre que existir.

## Calibração de SAST: por que "zerar" não é a meta

Um SAST recém-instalado em repositório maduro produz centenas de achados. A reação errada é uma
task de "zerar o SAST". A reação certa é este ciclo:

1. **Rode e conte.** `semgrep scan --config p/security-audit --json . | jq '.results | length'`.
2. **Amostre 20 achados aleatórios e classifique** cada um em: verdadeiro-explorável,
   verdadeiro-não-explorável (o caminho existe mas o dado não é controlável), falso positivo.
3. **Agrupe por `check_id`.** Quase sempre 3 ou 4 regras respondem por 70% do volume. Uma regra com
   >80% de falso positivo na sua base de código não é útil na sua base de código — desligue-a por
   `--exclude-rule <id>` ou no `.semgrepignore`, e **registre a decisão** num arquivo versionado.
4. **Estabeleça o baseline.** `--baseline-commit` congela o passivo existente e faz o gate falhar
   só no que o PR introduziu. Isso é o que torna o SAST adotável sem parar a entrega.
5. **Reavalie a cada trimestre**, não a cada PR.

"Zerar" não é a meta por dois motivos. Primeiro, boa parte do backlog é verdadeiro-não-explorável:
consertar dá trabalho e não reduz risco, e a energia estaria melhor gasta em revisar autorização.
Segundo, a métrica que importa não é "achados abertos", é **"achado novo introduzido por PR",** que
deve tender a zero. Um repositório com 200 achados históricos e zero achados novos há seis meses
está em situação melhor que um com 20 achados e três novos por semana.

Duas coisas que nenhum SAST desta seção encontra, e que precisam entrar no seu checklist manual:
falha de autorização (`references/autorizacao-e-logica-de-negocio.md`) e falha de lógica de negócio
(cupom acumulável, saldo com race condition). Se o seu processo é "passou no SAST, aprovado", você
não cobre a categoria #1 do OWASP Top 10.

## SCA: dependências vulneráveis

> **CLASSE LOCAL** — leem lockfile e consultam banco de vulnerabilidades público.

### osv-scanner — o melhor default hoje

```bash
brew install osv-scanner       # 2.4.0

# Varre o diretório recursivamente, todos os ecossistemas com lockfile suportado
osv-scanner scan source -r .

# Imagem de container (analisa camadas e atribui o pacote à camada que o introduziu)
osv-scanner scan image node:22-alpine

# SARIF para CI
osv-scanner scan source -r . --format sarif --output osv.sarif

# Licenças das dependências
osv-scanner scan source -r . --licenses

# Sugestão de upgrade minimizando quebra (experimental)
osv-scanner fix --non-interactive --strategy=in-place -M go.mod -L go.sum
```

**Atenção à sintaxe:** o v1 usava `osv-scanner -r .`. O v2 introduziu subcomandos —
`osv-scanner scan source` e `osv-scanner scan image`. A forma antiga ainda funciona por
compatibilidade, mas está a caminho da remoção.

Por que é o melhor default: consulta o [OSV.dev](https://osv.dev/), que agrega GitHub Advisory
Database, RustSec, PyPA, Go vuln DB, Alpine SecDB e outros, com dados de **intervalo de versão
afetada em nível de commit** — muito mais preciso que o mapeamento CPE do NVD, que erra bastante em
ecossistema de linguagem. E cobre npm, Go, PyPI, Maven, NuGet, RubyGems, crates.io, Packagist,
Hex e mais num comando só.

O que ele não faz: **alcançabilidade**. Ele diz "a versão X de `lodash` no seu lockfile tem
CVE-YYYY-NNNN"; não diz se o seu código chama a função vulnerável.

### npm audit — por que é ruidoso e frequentemente inacionável

```bash
npm audit --omit=dev                    # exclui devDependencies (--production está deprecado)
npm audit --audit-level=high            # exit != 0 só a partir de high
npm audit --json | jq '.metadata.vulnerabilities'
npm audit fix                           # respeita seu range de versão
npm audit fix --force                   # PODE FAZER UPGRADE MAJOR E QUEBRAR O BUILD
npm audit signatures                    # verifica assinaturas de integridade do registry
```

Valores válidos de `--audit-level`: `info`, `low`, `moderate`, `high`, `critical`, `none`.

O problema estrutural do `npm audit` é que ele reporta por **presença no grafo**, não por
exploração possível. Três consequências práticas:

- **Dependência transitiva sem caminho de exploração.** O caso clássico é uma ReDoS numa lib de
  parsing usada só pelo bundler, em tempo de build, sobre input que você mesmo escreveu. Severidade
  "high" no relatório, risco zero na prática. Se a vulnerabilidade está sob `devDependencies` e nunca
  roda em produção, `--omit=dev` é o filtro certo.
- **Vulnerabilidade sem fix disponível.** O `npm audit` a mantém no relatório indefinidamente. Não
  há como marcá-la como aceita no CLI nativo — só via `overrides` no `package.json` (que força uma
  versão) ou migrando para uma ferramenta com suporte a ignore file.
- **`npm audit fix --force` quebra build.** Ele instala fora do seu range declarado, incluindo
  major. Nunca rode isso em CI automaticamente.

Nos outros gerenciadores:

```bash
pnpm audit --prod --audit-level=high
pnpm audit --fix                  # escreve `overrides` no package.json
yarn npm audit --environment production --severity high
```

`overrides` (npm/pnpm) e `resolutions` (yarn) são a ferramenta certa quando a dependência direta
ainda não atualizou a transitiva vulnerável. Cuidado: forçar versão de transitiva pode quebrar em
runtime de formas que o teste não pega.

### govulncheck — o único que checa alcançabilidade

```bash
go install golang.org/x/vuln/cmd/govulncheck@latest
govulncheck ./...
govulncheck -show verbose ./...        # inclui os módulos vulneráveis mas não alcançados
govulncheck -format sarif ./... > govulncheck.sarif
govulncheck -mode binary ./bin/servidor   # sem fonte, sobre o binário compilado
```

Este é qualitativamente diferente dos outros. `govulncheck` constrói o **call graph** do seu
programa e só reporta a vulnerabilidade se existir caminho de chamada do seu código até a **função**
vulnerável — não o pacote, a função. Na prática isso corta de 70% a 90% dos achados que um SCA
tradicional produziria no mesmo módulo, e os que sobram vêm com o stack trace do caminho:

```
Vulnerability #1: GO-2024-2687
  ...
  #1: net/http.Handler.ServeHTTP calls x/net/http2.Server.ServeConn
```

Por que isso importa tanto: transforma "142 CVEs no seu `go.sum`" em "3 vulnerabilidades que o seu
binário de fato consegue executar". A primeira lista é ignorada; a segunda é corrigida na
mesma semana. Alcançabilidade é o multiplicador de acionabilidade do SCA.

Os limites, documentados pelo próprio projeto: chamada via **reflection** é invisível à análise
estática (falso **negativo**); chamada via interface ou ponteiro de função é analisada de forma
conservadora (falso positivo); `unsafe` pode esconder caminho; e no modo `-mode binary` não há call
graph, então a precisão cai para o nível de símbolo. Não existe mecanismo de supressão — não dá
para silenciar um achado individual.

### Os demais

```bash
# Multi-ecossistema, também faz misconfig e secret na mesma passada
brew install trivy                                    # 0.72.0
trivy fs --scanners vuln,secret,misconfig .
trivy repo https://github.com/org/repo
trivy fs --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 .
trivy fs --format sarif --output trivy.sarif .
# Ignorar CVE específica: crie .trivyignore com uma linha `CVE-2024-1234 exp:2026-12-31`

# Python
uvx pip-audit                       # lê o ambiente ou -r requirements.txt
uvx pip-audit -r requirements.txt --fix

# Rust
cargo install cargo-audit && cargo audit

# Java/.NET/multi (lento, banco NVD local de ~1 GB, mas cobre ecossistemas que os outros não)
brew install dependency-check
dependency-check --scan ./ --format SARIF --out ./reports --nvdApiKey "$NVD_API_KEY"

# A partir de SBOM
brew install syft grype                               # 1.49.0 / 0.116.0
syft dir:. -o cyclonedx-json=sbom.json
grype sbom:sbom.json --fail-on high
grype dir:. --only-fixed
```

`dependency-check` exige chave da API do NVD desde 2023 (sem ela, a primeira atualização do banco
leva horas). Peça em `nvd.nist.gov/developers/request-an-api-key`.

Automação de atualização — **Dependabot** (nativo do GitHub, `.github/dependabot.yml`) e
**Renovate** (mais configurável: agrupa PRs, respeita janela de manutenção, tem `minimumReleaseAge`
para não puxar versão publicada há duas horas — defesa direta contra pacote comprometido). Para o
raciocínio de supply chain — typosquatting, dependency confusion, ataque a maintainer, SBOM,
proveniência — veja `references/supply-chain-e-cicd.md`.

## Triagem de SCA: EPSS + KEV + alcançabilidade

CVSS sozinho é um mau priorizador. Ele mede a severidade **teórica** de uma falha isolada, sem saber
se existe exploit, se alguém está usando, ou se o seu código chega lá. O resultado é a pilha de
"criticals" que ninguém trata. A ordem correta de triagem:

| Sinal | O que responde | Onde consultar |
|---|---|---|
| **Alcançabilidade** | O meu código executa a função vulnerável? | `govulncheck` (Go), Semgrep Supply Chain, Snyk Reachability |
| **CISA KEV** | Está sendo explorado **agora**, comprovadamente? | [catálogo KEV](https://www.cisa.gov/known-exploited-vulnerabilities-catalog) — feed JSON: `https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json` |
| **EPSS** | Qual a probabilidade de exploração nos próximos 30 dias? | [FIRST EPSS](https://www.first.org/epss/) — API: `https://api.first.org/epss/v2/scores?cve=CVE-2021-44228` |
| **Exposição** | O componente atende tráfego não autenticado da internet? | Só você sabe. É o multiplicador mais forte. |
| **CVSS** | Quão ruim seria, se explorada? | NVD — use como desempate, não como ordenador |

Regra operacional: **em KEV → corrija esta semana, independentemente de CVSS.** EPSS acima de ~0.1
(percentil ~90) em componente exposto → sprint atual. Alcançabilidade negativa comprovada → registre
e agende, não interrompa ninguém. CVSS 9.8 em dependência de build, não alcançada, sem exploit
público → backlog.

Um triador rápido, usando a API do EPSS sobre a saída do osv-scanner:

```bash
osv-scanner scan source -r . --format json \
  | jq -r '.results[].packages[].vulnerabilities[].aliases[]? | select(startswith("CVE-"))' \
  | sort -u | paste -sd, - \
  | xargs -I{} curl -s "https://api.first.org/epss/v2/scores?cve={}" \
  | jq -r '.data[] | [.cve, .epss, .percentile] | @tsv' | sort -k2 -rn | head -20
```

O formalismo para registrar "não me afeta" é o **VEX** (Vulnerability Exploitability eXchange).
`govulncheck -format openvex` já emite VEX; anexar VEX ao SBOM é a forma padronizada de dizer ao
consumidor da sua imagem que aquela CVE está presente mas não é explorável.

## Segredos: varrer o disco e o histórico

> **CLASSE LOCAL** — exceto `trufflehog --only-verified`, que faz chamada de API com a credencial
> encontrada (**CLASSE REDE**).

### gitleaks

```bash
brew install gitleaks       # 8.30.1

gitleaks git . -v                       # varre o HISTÓRICO via `git log -p`
gitleaks dir . -v                       # varre arquivos no disco, ignora .git
gitleaks git . --redact=100 --report-format json --report-path gitleaks.json
gitleaks git . --log-opts="origin/main..HEAD"      # só o que o branch introduziu
gitleaks git . --baseline-path baseline.json       # ignora achados já conhecidos
cat arquivo.env | gitleaks stdin
```

**Sintaxe mudou:** `gitleaks detect` e `gitleaks protect` foram **depreciados na v8.19.0** — ainda
funcionam mas saíram do `--help`. Os comandos atuais são `git`, `dir` e `stdin`. O papel que
`protect --staged` cumpria agora é do hook de pre-commit (`gitleaks git --pre-commit --staged`,
ou o hook oficial do framework `pre-commit`).

Configuração em `.gitleaks.toml` na raiz (herda as ~170 regras padrão com `[extend] useDefault =
true` e permite acrescentar regra própria e allowlist por regex/path). Supressão inline:

```ts
const chaveDeExemplo = 'sk_test_' + '4eC39HqLyjWDarjtT1zdp7dc' // gitleaks:allow — chave de teste pública do Stripe
```

O que gitleaks acha: string com **alta entropia** ou que casa padrão conhecido (`AKIA[0-9A-Z]{16}`,
`ghp_...`, `sk_live_...`, chave privada PEM). O que ele **não** acha: senha fraca que parece palavra
(`Senha123`), segredo em variável de ambiente do CI (não está no repo), segredo já commitado num
submódulo, e credencial em formato proprietário sem regra. E ele **não verifica** se a credencial
está viva — todo achado é candidato, não confirmação.

### trufflehog — o diferencial é a verificação

```bash
brew install trufflehog      # 3.96.0

trufflehog git file://. --results=verified,unknown
trufflehog filesystem . --only-verified
trufflehog github --repo=https://github.com/org/repo --only-verified
trufflehog git file://. --since-commit=origin/main --branch=HEAD
docker run --rm -v "$PWD:/pwd" trufflesecurity/trufflehog:latest git file:///pwd --only-verified
```

O diferencial: para ~800 tipos de credencial, o trufflehog tem um **detector com verificação
ativa** — ele chama a API do provedor para checar se a chave funciona. Para AWS é um
`sts:GetCallerIdentity`; para GitHub, um `GET /user`. Isso muda a natureza do achado: `--only-verified`
não tem falso positivo por construção. Se saiu na lista, a credencial está **viva agora**.

Isso é ouro para triagem (varredura de repositório grande sai com zero ruído) e é exatamente o
motivo pelo qual esse modo é CLASSE REDE: você está autenticando contra serviços de terceiros com
credenciais achadas. Use `--only-verified` em credenciais da sua própria organização. Em código de
terceiro, use `--results=unknown` (sem verificar).

### detect-secrets (Yelp) — o modelo de baseline

```bash
uvx detect-secrets scan > .secrets.baseline    # linha de base do que já existe
uvx detect-secrets audit .secrets.baseline     # marca cada achado como verdadeiro/falso
uvx detect-secrets scan --baseline .secrets.baseline   # depois: só reporta o que é NOVO
```

O valor dele não é a detecção (gitleaks e trufflehog detectam melhor) e sim o **fluxo de baseline
auditada**: você percorre o passivo uma vez, marca `is_secret: false` no que é falso, versiona o
baseline, e daí em diante o hook só grita em segredo novo. É o mesmo princípio do
`--baseline-commit` do Semgrep, aplicado a segredo.

### GitHub secret scanning e push protection

O secret scanning do GitHub roda no lado do servidor com os **padrões de parceiros** — quando ele
acha uma chave de um provedor participante (AWS, Stripe, Slack, npm, OpenAI, Google Cloud...), ele
**notifica o provedor**, que costuma revogar automaticamente em minutos. Isso é uma proteção que
nenhuma ferramenta local oferece.

**Push protection** bloqueia o `git push` que contém um padrão conhecido, antes do commit chegar ao
servidor. Desde 2024 o secret scanning e o push protection são **gratuitos para todo repositório
público**; em repositório privado exigem GitHub Advanced Security / Secret Protection.

```bash
gh api repos/{owner}/{repo}/secret-scanning/alerts --jq '.[] | [.number,.secret_type,.state] | @tsv'
```

### O que fazer com o achado — a ordem importa

Achou credencial viva? A sequência é **revogar → rotacionar → limpar histórico → investigar uso**,
nessa ordem, e a maioria das pessoas inverte as duas últimas:

1. **Revogar** a credencial no provedor. Agora. Antes de qualquer coisa.
2. **Rotacionar** — emitir a nova, colocar no cofre (Vault, AWS Secrets Manager, 1Password), fazer
   deploy.
3. **Limpar o histórico** com `git filter-repo` ou BFG — e entenda que isso é a etapa **menos**
   importante: reescrever histórico não desfaz o vazamento (forks, clones, caches do GitHub,
   mirrors). Serve para não vazar de novo, não para conter.
4. **Investigar uso indevido** nos logs do provedor (CloudTrail, audit log) no período entre o
   commit e a revogação.

O detalhe de implementação de cofre, rotação e derivação de chave está em
`references/criptografia-e-segredos.md`.

## Container e IaC

> **CLASSE LOCAL.**

```bash
# ── Imagem de container ─────────────────────────────────────────────────────
trivy image --severity HIGH,CRITICAL --ignore-unfixed minha-app:latest
trivy image --scanners vuln,secret,misconfig --format sarif -o trivy.sarif minha-app:latest
grype minha-app:latest --only-fixed --fail-on critical
docker scout quickview minha-app:latest
docker scout cves --only-severity critical,high minha-app:latest
docker scout recommendations minha-app:latest   # sugere imagem base melhor

# ── Dockerfile ──────────────────────────────────────────────────────────────
brew install hadolint         # 2.14.0
hadolint Dockerfile
docker run --rm -i hadolint/hadolint < Dockerfile
hadolint --ignore DL3008 --ignore DL3059 Dockerfile

# ── Boas práticas de imagem (CIS Docker Benchmark) ──────────────────────────
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock goodwithtech/dockle minha-app:latest

# ── Terraform / CloudFormation / ARM / Helm ─────────────────────────────────
brew install checkov          # 3.3.0
checkov -d . --compact
checkov -d . --framework terraform -o sarif --output-file-path .
checkov -d . --skip-check CKV_AWS_18,CKV_AWS_21
trivy config .                # o motor de misconfig do Trivy (absorveu o tfsec)
terrascan scan -i terraform -d .

# ── Kubernetes ──────────────────────────────────────────────────────────────
brew install kube-score polaris
kube-score score k8s/*.yaml
polaris audit --audit-path ./k8s --format pretty
docker run --rm -i kubesec/kubesec:v2 scan /dev/stdin < deployment.yaml
trivy k8s --report summary cluster        # exige kubeconfig com acesso de leitura

# ── GitHub Actions ──────────────────────────────────────────────────────────
brew install actionlint zizmor pinact     # 1.7.12 / 1.28.0 / 4.1.0
actionlint
zizmor .github/workflows/
zizmor --persona=auditor --min-confidence=low .github/workflows/
zizmor --format sarif .github/workflows/ > zizmor.sarif
pinact run --check                        # verifica se as actions estão pinadas por SHA
```

Notas de escolha:

- **`tfsec` foi absorvido pelo Trivy** (mesma empresa, Aqua). O repositório está em manutenção e
  aponta para `trivy config`. Não comece projeto novo com tfsec.
- **`checkov` vs `trivy config`**: checkov tem catálogo maior de políticas AWS/Azure/GCP e entende
  módulo Terraform com variável; `trivy config` é mais rápido e já está no binário que você usa para
  tudo mais. Rode checkov em pipeline de IaC, `trivy config` no combo rápido.
- Supressão inline no checkov, dentro do recurso Terraform:
  `#checkov:skip=CKV_AWS_20:bucket é servido por CloudFront OAC, acesso direto já bloqueado`
- **`zizmor` é obrigatório** se você tem GitHub Actions. Ele encontra a classe de bug que mais dá
  comprometimento real de CI: injeção de template (`${{ github.event.pull_request.title }}` dentro
  de `run:`, que executa como shell), uso de `pull_request_target` com checkout do código do PR,
  `permissions` excessivas, e credential persistence no checkout. As personas controlam o ruído:
  `regular` (padrão) é o de alta confiança; `auditor` mostra tudo, inclusive falso positivo.
- `hadolint` DL3008 (pin de versão em `apt-get install`) é a regra que mais gera discussão. Ela está
  certa em termos de reprodutibilidade, mas em imagem que é reconstruída semanalmente o pin impede
  patch de segurança. É um dos poucos casos em que ignorar é defensável — documente.
- `dockle` e `trivy image` não se sobrepõem: trivy acha **CVE em pacote**; dockle acha **prática
  ruim de imagem** (rodando como root, `setuid` sobrando, credencial em variável de ambiente da
  imagem, sem `HEALTHCHECK`).

---

## CLASSE REDE: DAST e teste de aplicação em execução

> # ⛔ PARE E LEIA
>
> **Tudo desta seção gera tráfego contra um alvo.** Antes de qualquer comando abaixo, você precisa
> de uma das duas coisas:
>
> - o alvo é seu (localhost, seu staging, um dos laboratórios listados no fim deste arquivo), **ou**
> - você tem **autorização escrita** que cobre explicitamente aquele host, aquele ambiente e
>   aquela janela de tempo.
>
> Em bug bounty, "autorização" é o **escopo publicado do programa**, e ele é literal: leia o que é
> in-scope e o que é out-of-scope, respeite as regras de rate limit e de testes proibidos
> (normalmente DoS, engenharia social e ataque a terceiro são proibidos), e use o header de
> identificação que o programa pedir (`X-Bug-Bounty: <handle>`). Testar fora do escopo não é
> pesquisa, é intrusão — o programa não protege você.
>
> Antes de rodar, sempre: avise o time responsável, prefira ambiente de staging, e limite a taxa.
> Scanner com concorrência default derruba serviço pequeno.

---

### OWASP ZAP

ZAP 2.17.0 (`brew install --cask zap`). A imagem Docker mudou: **`owasp/zap2docker-*` foi
descontinuada** e as imagens atuais são `ghcr.io/zaproxy/zaproxy:stable` (ou `zaproxy/zap-stable`
no Docker Hub).

```bash
# BASELINE — só spider + passive scan. Não envia payload de ataque. É o mais próximo de
# "seguro" que um DAST chega, e o único que faz sentido rodar em CI de rotina.
docker run --rm -v "$PWD:/zap/wrk/:rw" -t ghcr.io/zaproxy/zaproxy:stable \
  zap-baseline.py -t https://staging.exemplo.com -r baseline.html -J baseline.json -I

# FULL SCAN — inclui ACTIVE SCAN: envia payloads reais (SQLi, XSS, injeção de comando).
# Pode criar dados, disparar e-mail, apagar registro. NUNCA em produção.
docker run --rm -v "$PWD:/zap/wrk/:rw" -t ghcr.io/zaproxy/zaproxy:stable \
  zap-full-scan.py -t https://staging.exemplo.com -r full.html -m 5

# API SCAN — a partir de OpenAPI, SOAP ou GraphQL. Não faz spider (a spec já é o mapa) e pula
# checagens específicas de navegador.
docker run --rm -v "$PWD:/zap/wrk/:rw" -t ghcr.io/zaproxy/zaproxy:stable \
  zap-api-scan.py -t /zap/wrk/openapi.json -f openapi -O https://staging.exemplo.com -r api.html
```

Códigos de saída dos scripts empacotados: `0` sucesso, `1` pelo menos um FAIL, `2` pelo menos um
WARN e nenhum FAIL, `3` outra falha. `-I` faz o script não falhar em WARN — é o que torna o baseline
usável em CI sem quebrar o build toda semana. `-c arquivo.conf` define o tratamento por regra
(`10015 IGNORE (Incomplete or No Cache-control Header)`), que é como você silencia as regras de
header informativo que dominam o relatório.

Para cenário com autenticação, os scripts empacotados não bastam — use o **Automation Framework**,
que é o modo declarativo e o caminho recomendado hoje:

```yaml
# plan.yaml
env:
  contexts:
    - name: app
      urls: ["https://staging.exemplo.com/"]
      includePaths: ["https://staging.exemplo.com/.*"]
      excludePaths: ["https://staging.exemplo.com/logout.*"]
      authentication:
        method: "json"
        parameters:
          loginPageUrl: "https://staging.exemplo.com/login"
          loginRequestUrl: "https://staging.exemplo.com/api/auth/login"
          loginRequestBody: '{"email":"{%username%}","password":"{%password%}"}'
        verification:
          method: "response"
          loggedInRegex: '\Q"authenticated":true\E'
      sessionManagement:
        method: "headers"
        parameters:
          Authorization: "Bearer {%json:token%}"
      users:
        - name: "tester"
          credentials:
            username: "tester@exemplo.com"
            password: "${SENHA_TESTE}"
  parameters:
    failOnError: true
    progressToStdout: true

jobs:
  - type: passiveScan-config
    parameters: { maxAlertsPerRule: 10 }
  - type: openapi
    parameters:
      apiFile: "/zap/wrk/openapi.json"
      targetUrl: "https://staging.exemplo.com"
  - type: spider
    parameters: { context: app, user: tester, maxDuration: 5 }
  - type: passiveScan-wait
  - type: activeScan
    parameters: { context: app, user: tester, maxRuleDurationInMins: 3 }
  - type: report
    parameters:
      template: "traditional-html"
      reportDir: "/zap/wrk"
      reportFile: "zap-report.html"
```

```bash
docker run --rm -v "$PWD:/zap/wrk/:rw" -e SENHA_TESTE -t ghcr.io/zaproxy/zaproxy:stable \
  zap.sh -cmd -autorun /zap/wrk/plan.yaml
```

O que ZAP encontra bem: headers de segurança ausentes, cookie sem flag, conteúdo misto, XSS
refletido óbvio, SQLi por erro, path traversal, arquivo exposto, versão de servidor vazando. O que
ele não encontra: **qualquer falha de autorização**, lógica de negócio, XSS que exige interação de
usuário, e a maior parte do que está atrás de um fluxo com estado. Em aplicação SPA moderna, a
cobertura do spider costuma ser ruim — daí a importância de alimentá-lo com a spec OpenAPI ou com um
HAR gravado.

### Burp Suite

`brew install --cask burp-suite` (Community 2026.7.1). O fluxo de trabalho:

1. **Proxy** — navegue a aplicação com o browser embutido do Burp. Isso popula o **site map** e o
   **HTTP history** com tudo, incluindo XHR. Esse é o insumo de todo o resto.
2. **Repeater** (`Ctrl-R` a partir de qualquer requisição) — a ferramenta mais usada em pentest de
   verdade. Edite uma requisição e reenvie quantas vezes quiser. É onde se testa IDOR (trocar o ID),
   mass assignment (adicionar campo), e bypass de autorização (remover o header).
3. **Intruder** — automatiza a variação de um ponto da requisição (sniper, cluster bomb, pitchfork).
   **Na Community é fortemente throttled** (limite artificial de velocidade), o que a torna
   inviável para lista grande.
4. **Scanner** — só no **Professional**. É a diferença principal entre as edições: Community não tem
   scanner ativo nem passivo.

Community vs Professional, na prática: Community serve perfeitamente para trabalho manual (proxy,
Repeater, decoder, comparer) e é o suficiente para aprender. Professional adiciona scanner,
Intruder sem throttle, salvar projeto em disco, e o Collaborator (o servidor que detecta interação
out-of-band — indispensável para SSRF cega e XXE cega; veja `references/ssrf-e-camada-http.md`).

Extensões da BApp Store que mudam o jogo:

| Extensão | O que faz | Quando |
|---|---|---|
| **Autorize** | Reenvia cada requisição com o token de um usuário de menor privilégio e compara a resposta. Encontra IDOR/BOLA em escala | O melhor custo-benefício de todos para A01:2025 |
| **Param Miner** | Descobre parâmetros e headers não documentados por brute force com detecção diferencial | Cache poisoning, parâmetro escondido, mass assignment |
| **Turbo Intruder** | Motor HTTP próprio, scriptável em Python, dezenas de milhares de req/s; suporta single-packet attack | Race condition (TOCTOU em cupom, saldo, convite) |
| **JWT Editor** | Edita e reassina JWT no Repeater; testa `alg:none`, confusão RS256→HS256, `jku`/`kid` injection | Todo endpoint com Bearer token |
| **Logger++** | Log unificado, filtrável e exportável de tudo que passou pelo Burp | Achar aquela requisição que você viu há 40 minutos |

Recursos recentes que valem conhecer: **Bambdas** (snippets Java para filtro e coluna custom no
proxy history — ex.: destacar toda resposta com `Set-Cookie` sem `HttpOnly`), **DOM Invader** (no
browser embutido; instrumenta o DOM para achar sink de DOM XSS e prototype pollution
automaticamente — veja `references/xss-e-navegador.md`), e o **Collaborator**.

### nuclei

```bash
brew install nuclei          # 3.11.0
nuclei -update-templates     # ~10.000 templates comunitários

nuclei -u https://staging.exemplo.com
nuclei -l alvos.txt -severity critical,high -rl 20 -c 10
nuclei -u https://staging.exemplo.com -tags cve,exposure -jsonl -o nuclei.jsonl
nuclei -u https://staging.exemplo.com -t ~/nuclei-templates/http/misconfiguration/
nuclei -u https://staging.exemplo.com -sarif-export nuclei.sarif
```

nuclei é um motor de **assinatura**: cada template é um YAML com requisição + matcher. Ele é
excelente em uma coisa — verificar rapidamente, contra muitos hosts, se algum deles tem uma CVE
conhecida, um painel administrativo exposto, um `.git/` servido, um `.env` acessível, uma S3
pública. Ele não faz spider, não entende sessão complexa e não encontra nada que não esteja num
template. Zero achado do nuclei diz muito pouco sobre a segurança da aplicação.

Uso responsável: `-rl` (rate limit, requisições por segundo) e `-c` (concorrência de templates) não
são opcionais contra alvo real. O default é agressivo. E `-tags dos,fuzz` inclui templates que
podem derrubar serviço — não rode sem intenção explícita.

### Descoberta de conteúdo e superfície

```bash
# Wordlists (SecLists não está no brew; clone)
git clone --depth 1 https://github.com/danielmiessler/SecLists ~/SecLists

brew install ffuf feroxbuster     # 2.2.1 / 2.13.1

# ffuf — o FUZZ marca o ponto de injeção; funciona em path, parâmetro, header, subdomínio
ffuf -u https://staging.exemplo.com/FUZZ \
     -w ~/SecLists/Discovery/Web-Content/raft-medium-directories.txt \
     -mc 200,204,301,302,401,403 -ac -rate 30 -t 20 -o ffuf.json -of json

# feroxbuster — recursivo por padrão, saída mais legível, bom default
feroxbuster -u https://staging.exemplo.com \
            -w ~/SecLists/Discovery/Web-Content/raft-medium-directories.txt \
            --depth 2 --rate-limit 30 --extract-links

# Superfície (subdomínio → hosts vivos)
brew install subfinder httpx amass       # 2.14.0 / 1.10.0 / 5.1.1
subfinder -d exemplo.com -silent | httpx -silent -title -status-code -tech-detect
amass enum -passive -d exemplo.com       # -passive não toca o alvo; `amass enum -active` toca
```

`-ac` (auto-calibrate) do ffuf é o que separa saída útil de 40.000 falsos positivos: ele manda
requisições para paths sabidamente inexistentes, aprende como é a resposta 404 real da aplicação
(que pode vir com status 200) e filtra por tamanho/palavras automaticamente. Sem `-ac` você vai
querer `-fs <tamanho>` ou `-fw <palavras>` manualmente.

**Cuidado de escopo**: `subfinder` e `amass -passive` consultam fontes públicas (certificate
transparency, DNS agregado) e **não tocam o alvo** — isso é OSINT e é a parte menos arriscada. Mas
o resultado inclui hosts que podem não estar no escopo do programa, e apontar `httpx` ou `nuclei`
para essa lista inteira é como sair do escopo por acidente. Filtre a lista contra o escopo antes.

### sqlmap

```bash
brew install sqlmap          # 1.10.7

# A partir de uma requisição salva do Burp (o modo correto: preserva headers, cookies e método)
sqlmap -r requisicao.txt --batch

sqlmap -u "https://staging.exemplo.com/produto?id=1" -p id --batch

# POST com corpo, cookie de sessão e o parâmetro a testar explícito
sqlmap -u "https://staging.exemplo.com/busca" \
  --data='q=camisa&categoria=3' -p q --cookie='session=abc123' --batch

# Escalada de enumeração — só DEPOIS de confirmar a injeção, e um passo por vez
sqlmap -r requisicao.txt --batch --dbs                        # lista os bancos
sqlmap -r requisicao.txt --batch -D loja --tables             # tabelas de um banco
sqlmap -r requisicao.txt --batch -D loja -T usuarios --columns
sqlmap -r requisicao.txt --batch -D loja -T usuarios -C email,senha_hash --dump
```

`--batch` responde toda pergunta interativa com o default — bom para reprodutibilidade, mas leia o
que o default de cada pergunta significa antes de confiar nele. O modo canônico é `-r requisicao.txt`
(uma requisição salva do Repeater/Proxy do Burp): preserva método, headers, cookies e corpo exatos, e
você marca o ponto de injeção com um `*` no arquivo. `-u` com querystring serve para GET simples; para
qualquer coisa com sessão, use `-r`.

**`--risk` e `--level`: os defaults 1/1 são os certos, e subir tem custo real.** `--level` (1 a 5,
default 1) controla *onde* o sqlmap procura: nível 1 testa só parâmetros GET/POST; nível 2 acrescenta
o header `Cookie`; nível 3, `User-Agent` e `Referer`; nível 5, todos os headers (inclusive `Host`) e o
maior conjunto de payloads. `--risk` (1 a 3, default 1) controla *quão agressivo* é o payload: risco 1
é inócuo; risco 2 acrescenta testes time-based com query pesada (consome CPU do banco); risco 3 inclui
injeções `OR`, e é aqui que mora o perigo — um payload `OR`-based dentro de um contexto `UPDATE` ou
`DELETE` pode casar **todas as linhas** da tabela, não só a que você pretendia. Por isso o default é 1,
e por isso `--risk 3` não é "mais completo", é "potencialmente destrutivo". Subir para `--level 5
--risk 3` multiplica o número de requisições por uma ordem de grandeza (de dezenas para milhares por
parâmetro): faz sentido quando você já sabe que há uma injeção difícil e está num alvo autorizado e
resiliente; é imprudente como primeira passada. Comece em 1/1 e suba só se a detecção falhar e você
tiver motivo para insistir.

`--technique=BEUSTQ` (default: todas) seleciona as classes de injeção testadas — **B**oolean-based
blind, **E**rror-based, **U**nion query, **S**tacked queries, **T**ime-based blind, inline **Q**uery.
Restringir (ex.: `--technique=BEU`) acelera e reduz ruído quando você já sabe o tipo. `--tamper=<script>`
aplica transformações ao payload (`--tamper=space2comment,between`) para contornar WAF ou filtro de
entrada; existe e é legítimo em teste autorizado onde um WAF interfere na *detecção* da falha real,
mas o propósito é evasão de filtro — não é assunto para detalhar aqui, e usá-lo contra um alvo é um
sinal claro de que você precisa ter certeza da sua autorização.

> **Aviso de escopo — sqlmap é a ferramenta mais fácil de usar acidentalmente fora de autorização.**
> Um `--dbs` já é uma sequência de injeções bem-sucedidas contra um banco real. Um `--dump` é
> **exfiltração de dado de produção**: se a tabela `usuarios` tem PII, você acabou de copiar PII para
> o seu disco, e no Brasil isso é tratamento de dado pessoal sob a LGPD além de eventual acesso não
> autorizado (art. 154-A do CP). Não existe `--dump` "só para confirmar": a confirmação da injeção é o
> `--is-dba` ou o `--current-user`, não a extração dos dados. Em bug bounty, quase todo programa
> proíbe explicitamente `--dump` de dado real — a prova de conceito aceita é extrair a versão do banco
> (`--banner`) ou um valor claramente sintético, nunca registros de usuários. Pare na menor demonstração
> que prova a falha.

### nikto

```bash
brew install nikto           # 2.5.0

nikto -h https://staging.exemplo.com
nikto -h staging.exemplo.com -ssl -port 443
nikto -h https://staging.exemplo.com -Tuning 123bde -o nikto.html -Format htm
nikto -h https://staging.exemplo.com -maxtime 120s -Pause 1   # limita duração e insere pausa
```

nikto é um scanner de **assinatura** para servidor web, veterano e barulhento. Ele acha: arquivo e CGI
perigoso conhecido, arquivo default deixado no servidor (`/phpinfo.php`, `/server-status`,
`/.git/config`), versão de servidor/software desatualizada anunciada em header, opção de método HTTP
insegura (`PUT`, `TRACE`), header de segurança ausente. O que ele **não** acha: qualquer coisa da
aplicação em si — sem entender rota, sessão ou lógica, ele só bate numa lista de ~7.000 caminhos
conhecidos. Em app moderno (SPA + API) o retorno é baixo; o valor real de nikto hoje é em servidor
legado ou host exposto que ninguém revisou. `-Tuning` filtra as classes de teste (`123bde` = arquivos
interessantes + misconfig + divulgação de informação, sem os testes de injeção que geram mais ruído).
É CLASSE REDE e nada discreto — cada execução são milhares de requisições com User-Agent óbvio.

### testssl.sh / sslyze

```bash
# testssl.sh — script bash, sem dependência além de um OpenSSL recente
brew install testssl         # 3.2
testssl.sh https://exemplo.com
testssl.sh --severity HIGH --jsonfile tls.json exemplo.com:443
testssl.sh -U exemplo.com    # -U = testa todas as vulnerabilidades conhecidas (Heartbleed, ROBOT, etc.)

# sslyze — mesma classe, escrito em Python, mais rápido e com saída estruturada melhor
pipx install sslyze          # 6.2.0
sslyze exemplo.com:443
sslyze --json_out tls.json --mozilla_config=intermediate exemplo.com:443
```

Ambos inspecionam a configuração de TLS de um endpoint: protocolos habilitados (alertam sobre SSLv3,
TLS 1.0/1.1, que deveriam estar desligados), suítes de cifra fracas, qualidade e validade do
certificado e da cadeia, suporte a `HSTS`, e vulnerabilidades de protocolo históricas (Heartbleed,
ROBOT, BEAST, POODLE). `sslyze --mozilla_config=intermediate` compara direto contra o perfil
recomendado da Mozilla e falha se a config ficar aquém — é o modo mais acionável para CI. São
tecnicamente CLASSE REDE (fazem handshakes TLS contra o alvo), mas de baixa invasividade: só negociam
conexão, não enviam payload de ataque nem tocam a aplicação. Ainda assim, rode contra alvo seu ou
autorizado. O que eles cobrem é só a camada TLS; a política de header HTTP (CSP, cookie flags) é da
aplicação e sai no ZAP/Burp — veja `references/ssrf-e-camada-http.md` para a interpretação dos achados.

## Mobile

Analisar um app tem duas metades. A **estática** — decompilar o APK/IPA que você tem em mãos e ler o
código, os recursos e o manifesto — é **CLASSE LOCAL**: só lê bytes de um arquivo que você possui. A
**dinâmica** — instrumentar o app rodando, interceptar o tráfego, inspecionar o armazenamento no
dispositivo — é teste do **seu próprio app no seu próprio dispositivo** (emulador ou aparelho de teste
que você controla). Nada aqui autoriza mexer no app ou no backend de terceiro. O raciocínio de
*vulnerabilidade* mobile (armazenamento inseguro, pinning, deep link, WebView, MASVS) está em
`references/mobile.md`; aqui é só o ferramental.

### MobSF — o canivete estático (e dinâmico)

```bash
# Sobe a interface web + REST API em http://localhost:8000 (login default mobsf/mobsf)
docker run -it --rm -p 8000:8000 opensecurity/mobile-security-framework-mobsf:latest
```

MobSF (Mobile Security Framework) é o ponto de partida para qualquer APK, IPA ou APPX. Suba o
container, faça upload do binário pela UI e ele roda a **análise estática** inteira: decompila,
extrai o `AndroidManifest.xml` (permissões, componentes exportados, `android:debuggable`,
`usesCleartextTraffic`), casa padrões de código inseguro (crypto fraca, WebView com JS habilitado,
segredo hardcoded), verifica a config de `network_security_config` e gera um relatório com score. A
**API REST** (a chave fica em *API Docs* na própria UI, ou via `MOBSF_API_KEY`) é o que integra ao
CI: `curl -F 'file=@app.apk' http://localhost:8000/api/v1/upload -H "Authorization: $KEY"` seguido de
`/api/v1/scan`. A **análise dinâmica** existe mas exige um emulador Android conectado (o container não
faz sozinho): ele instrumenta o app com Frida, captura tráfego e lê o armazenamento em runtime. Para
iOS a dinâmica precisa de um dispositivo com jailbreak. MobSF é a melhor relação esforço/cobertura do
mobile — comece sempre por ele, e use as ferramentas abaixo para ir fundo no que ele apontar.

### Estática, ferramenta a ferramenta

> **CLASSE LOCAL** — tudo abaixo opera sobre o arquivo do app.

```bash
# ── Android: decompilar para Java legível ───────────────────────────────────
brew install jadx            # 1.5.3
jadx -d saida/ app.apk                 # decompila DEX → Java em saida/sources
jadx-gui app.apk                       # navegação interativa, busca de string, xrefs
rg -n "http://|password|secret|BEGIN RSA|AES/ECB|setJavaScriptEnabled" saida/sources

# ── Android: recursos + smali (o que o jadx não reconstrói) ──────────────────
brew install apktool         # 2.11.1
apktool d app.apk -o app_decoded/     # AndroidManifest.xml legível + smali + res/
# depois de editar smali/recursos, reconstruir para reinstalar num aparelho seu:
apktool b app_decoded -o app_mod.apk

# ── Android: DEX → JAR (para abrir em JD-GUI/Ghidra quando o jadx falha) ─────
brew install dex2jar
d2j-dex2jar app.apk -o app.jar

# ── iOS: cabeçalhos Objective-C a partir do Mach-O ──────────────────────────
brew install class-dump
class-dump -H App.app/App -o headers/  # reconstrói @interface de classes ObjC
# (Swift moderno não sai no class-dump; use os símbolos com nm e a análise do MobSF)

# ── iOS/macOS: metadados do binário Mach-O ──────────────────────────────────
otool -L App.app/App                   # bibliotecas dinâmicas linkadas
otool -l App.app/App | grep -A4 LC_ENCRYPTION_INFO   # cryptid=1 → binário ainda cifrado (FairPlay)
otool -Iv App.app/App                  # tabela de símbolos importados
nm -u App.app/App                      # símbolos indefinidos (o que ele chama de fora)
codesign -d --entitlements :- App.app  # entitlements (keychain sharing, app groups, etc.)
```

`class-dump` só enxerga a runtime Objective-C; em app majoritariamente Swift ele volta quase vazio, e
aí o caminho é a análise do MobSF ou desmontagem no Ghidra/Hopper. O `cryptid` do `otool` responde uma
pergunta prática: se o IPA veio da App Store, o binário está cifrado com FairPlay e você precisa de um
dump descriptografado (de um dispositivo com jailbreak, do seu app) antes de qualquer análise estática
render alguma coisa.

### Dinâmica: instrumentar o seu app

```bash
# ── Frida + objection: hooking em runtime ───────────────────────────────────
pipx install frida-tools objection      # frida 17.x
frida-ps -Ua                            # apps rodando no dispositivo/emulador USB conectado
objection -g com.exemplo.app explore    # REPL de instrumentação sobre o app
#   dentro do objection, comandos que valem:
#     android hooking list activities            # componentes e classes
#     android keystore list                      # chaves no KeyStore
#     android hooking search classes crypto      # onde o app faz cripto
#     ios keychain dump                          # itens do Keychain (iOS)

# ── mitmproxy: ver o tráfego do app ─────────────────────────────────────────
brew install mitmproxy       # 12.x
mitmweb --listen-port 8080              # UI web em http://localhost:8081
#   1. aponte o proxy do dispositivo para <ip-do-mac>:8080
#   2. instale o CA do mitmproxy no dispositivo (http://mitm.it a partir do device)
#   3. no Android 7+ o app só confia no seu CA se você o injetar como system CA
#      (aparelho com root) OU adicionar <trust-anchors> no network_security_config de
#      um build de debug do PRÓPRIO app. É exatamente a proteção que o pinning reforça.

# ── adb: inspeção do dispositivo ────────────────────────────────────────────
adb shell pm list packages -3                          # pacotes de terceiros instalados
adb shell dumpsys package com.exemplo.app              # permissões + componentes exportados
adb shell run-as com.exemplo.app ls -la /data/data/com.exemplo.app/shared_prefs
adb shell run-as com.exemplo.app cat /data/data/com.exemplo.app/databases/app.db  # (só app debuggable)
adb shell am start -n com.exemplo.app/.DeepLinkActivity -d "app://pagar?valor=1"   # testar componente exportado
adb logcat --pid=$(adb shell pidof -s com.exemplo.app)  # log do app (segredo em log é achado comum)

# ── drozer: mapear a superfície de ataque exportada ─────────────────────────
pipx install drozer          # requer o drozer-agent.apk instalado no dispositivo
drozer console connect
#   run app.package.attacksurface com.exemplo.app     # activities/services/providers exportados
#   run app.provider.finduri com.exemplo.app          # content providers acessíveis
#   run scanner.provider.injection -a com.exemplo.app # SQLi em content provider exportado
```

`adb run-as` só funciona se o app for `android:debuggable="true"` — em build de produção ele falha, o
que é o comportamento correto. Por isso a inspeção de armazenamento interno se faz sobre um build de
debug do seu app, ou num emulador. O achado mais frequente dessa bateria é banal e recorrente: token
ou PII em `shared_prefs` em texto claro, segredo escrito em `logcat`, e componente exportado sem
`permission` que aceita `Intent` de qualquer app. Cruze tudo com `references/mobile.md` para a
interpretação e a correção.

## Fuzzing e teste de propriedade

Fuzzing e property-based testing atacam a mesma lacuna: o teste de exemplo cobre os casos em que você
pensou, e a falha mora nos que você não pensou. As duas técnicas geram entrada e procuram a que quebra
um invariante. São **CLASSE LOCAL** — rodam o seu código na sua máquina.

### Fuzzing nativo do Go

```go
// fuzz_test.go — a função DEVE começar com Fuzz e receber *testing.F
func FuzzParseCupom(f *testing.F) {
    f.Add("ABC-10")            // semente do corpus (opcional, mas ajuda a cobertura)
    f.Fuzz(func(t *testing.T, s string) {
        c, err := ParseCupom(s)
        if err != nil {
            return             // erro é resultado válido; o que não pode é panic ou invariante quebrada
        }
        if c.Desconto < 0 || c.Desconto > 100 {
            t.Fatalf("desconto fora de faixa para entrada %q: %d", s, c.Desconto)
        }
    })
}
```

```bash
go test -run=^$ -fuzz=FuzzParseCupom -fuzztime=60s ./...
# a entrada que quebrou é gravada em testdata/fuzz/FuzzParseCupom/ e vira caso de regressão
# permanente: `go test ./...` (sem -fuzz) re-executa esse corpus para sempre.
```

O fuzzing do Go é o melhor ponto de entrada para a técnica: está na toolchain padrão, o corpus de
falha vira teste versionado automaticamente, e o alvo ideal é qualquer função que **parseia entrada
não confiável** — decoder, parser de token, validação de upload, desserialização.

### JVM e Python

```bash
# Jazzer (JVM) — fuzzing guiado por cobertura, integra ao JUnit 5
#   dependência: com.code-intelligence:jazzer-junit  → escreva @FuzzTest
#   procura NullPointer/OOB, mas também detecção de SSRF, SQLi, path traversal e desserialização
#   via "sanitizers" (BugDetectors) — é fuzzing com olhar de segurança embutido.

# Atheris (Python) — fuzzing com cobertura, do Google, sobre libFuzzer
pip install atheris
```

```python
import atheris, sys
with atheris.instrument_imports():
    from meu_modulo import parse

def TestOneInput(data):
    fdp = atheris.FuzzedDataProvider(data)
    try:
        parse(fdp.ConsumeUnicodeNoSurrogates(256))
    except ValueError:
        pass                    # exceção esperada; unhandled é o bug

atheris.Setup(sys.argv, TestOneInput)
atheris.Fuzz()
```

### A partir da spec OpenAPI

```bash
pipx install schemathesis      # 4.x — CLASSE REDE: gera requisições contra o alvo (exige autorização)
st run openapi.yaml --url https://staging.exemplo.com \
  --checks all -H "Authorization: Bearer $TOKEN_TESTE" --max-examples 200 --report junit
```

`schemathesis` lê a spec e gera requisições que **violam** o contrato (tipo errado, string gigante,
inteiro negativo, campo faltando) para ver se a API retorna 500, viola o próprio schema de resposta,
ou aceita o que deveria rejeitar. O check `response_schema_conformance` é o de maior valor: encontra
divergência entre o que a API documenta e o que ela devolve — que é onde mora dado vazando a mais. É o
fuzzing de melhor retorno para quem tem OpenAPI. **RESTler** (Microsoft) é o primo mais pesado: infere
a ordem de dependência entre endpoints a partir da spec (cria recurso → usa o id retornado → deleta) e
faz fuzzing stateful de sequência, achando bug que só aparece numa cadeia de chamadas. Custa mais para
configurar; vale em API grande e madura. Os dois são CLASSE REDE.

### Property-based no TypeScript: fast-check

```ts
import fc from 'fast-check'
import { test } from 'vitest'

test('parseValor nunca produz NaN nem negativo para entrada válida', () => {
  fc.assert(
    fc.property(fc.string(), (entrada) => {
      const r = parseValor(entrada)
      if (r.ok) {
        // o invariante que precisa valer para QUALQUER string que passe na validação
        return Number.isFinite(r.valor) && r.valor >= 0
      }
      return true
    }),
    { numRuns: 1000 },
  )
}
```

`fast-check` (`npm i -D fast-check`) é o primo acessível e imediatamente útil no stack do usuário:
roda no Vitest/Jest, sem infra, e quando um caso falha ele faz **shrinking** — reduz o contra-exemplo
ao menor input que ainda quebra, então em vez de uma string aleatória de 300 caracteres você recebe o
`"-0"` ou o `"\ufeff"` exato que expôs o bug. O alvo certo são invariantes de lógica: idempotência de
uma operação, `parse(stringify(x)) === x`, e principalmente **checagens de segurança que precisam valer
para toda entrada** — "nenhuma string de nome de usuário passa na validação e ainda contém `<`".

## Montar o pipeline

O princípio é escalonar por custo e por invasividade: o que é rápido e local roda cedo e sempre; o que
é lento ou toca a rede roda tarde e agendado. Quatro estágios.

**Pre-commit (segundos, sem rede, só CLASSE LOCAL).** Roda no `git commit`, no que está *staged*. Só o
que é rápido e de baixíssimo falso positivo — o objetivo é impedir o erro óbvio antes de virar commit,
não auditar. Segredo é o alvo número um aqui, porque uma vez commitado já vazou.

```yaml
# .pre-commit-config.yaml — framework pre-commit (pipx install pre-commit && pre-commit install)
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1
    hooks: [{ id: gitleaks }]
  - repo: https://github.com/semgrep/semgrep
    rev: v1.171.0
    hooks:
      - id: semgrep
        args: ["--config", "p/default", "--error", "--skip-unknown-extensions"]
```

**PR (minutos, diff-aware).** O gate real. SAST **só no diff** (`--baseline-commit`), SCA nas
dependências, segredos no range do branch. Tudo emite SARIF para o GitHub Code Scanning, que vira
comentário inline no PR. A regra de ouro: **falha só no que o PR introduziu**, nunca no passivo
histórico.

**Nightly / semanal (lento, pode tocar a rede).** Full scan sem baseline (`p/security-audit`, CodeQL,
`trivy` completo), e o DAST — ZAP baseline contra **staging** (nunca produção, e é CLASSE REDE:
autorização já resolvida por ser ambiente seu). Resultado vira issue/dashboard, não bloqueia merge.

**Release (SBOM + assinatura).** Gera o SBOM (`syft`), assina imagem e artefatos (`cosign`), anexa
proveniência/atestado. É a base para responder "essa versão em produção contém a lib X vulnerável?"
sem adivinhação — veja `references/supply-chain-e-cicd.md`.

Um workflow de GitHub Actions completo e funcional, cobrindo PR (diff-aware) e o full scan semanal:

```yaml
# .github/workflows/security.yml
name: security

on:
  pull_request:
  push:
    branches: [main]
  schedule:
    - cron: '0 3 * * 1'        # segunda 03:00 UTC — full scan semanal

# menor privilégio no GITHUB_TOKEN; security-events:write é o que libera o upload de SARIF
permissions:
  contents: read

concurrency:
  group: security-${{ github.ref }}
  cancel-in-progress: true

jobs:
  # ── SAST: Semgrep, diff-aware no PR, full no schedule ─────────────────────
  semgrep:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    container:
      image: semgrep/semgrep:1.171.0    # pinar por digest (@sha256:...) em produção
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0                # baseline-commit precisa do histórico
      - name: Semgrep (SARIF)
        run: |
          BASE=""
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            BASE="--baseline-commit ${{ github.event.pull_request.base.sha }}"
          fi
          semgrep scan --config p/default --config p/owasp-top-ten \
            --sarif --output semgrep.sarif --metrics=off $BASE .
      - name: Upload SARIF
        if: always()
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: semgrep.sarif
          category: semgrep

  # ── SCA: osv-scanner via workflow reutilizável oficial ────────────────────
  sca:
    uses: google/osv-scanner-action/.github/workflows/osv-scanner-reusable.yml@v2.4.0
    permissions:
      contents: read
      security-events: write
      actions: read

  # ── Segredos: todo o histórico do branch ──────────────────────────────────
  secrets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2   # falha o job se achar segredo novo
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  # ── Misconfig de IaC/container + GitHub Actions ───────────────────────────
  config:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@v4
      - name: Trivy config
        uses: aquasecurity/trivy-action@0.28.0
        with:
          scan-type: config
          format: sarif
          output: trivy.sarif
          severity: HIGH,CRITICAL
      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: trivy.sarif
          category: trivy-config
      - name: zizmor (workflows)
        run: |
          pipx run zizmor --format sarif .github/workflows/ > zizmor.sarif || true
      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: zizmor.sarif
          category: zizmor

  # ── DAST: só no full scan semanal, contra STAGING (nunca produção) ────────
  dast-staging:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: ZAP baseline (passivo)
        uses: zaproxy/action-baseline@v0.14.0
        with:
          target: 'https://staging.exemplo.com'   # ambiente seu = autorização resolvida
          fail_action: false                       # relatório, não gate
```

Todas as `uses:` acima deveriam, em produção, ser **pinadas por SHA** e não por tag — é exatamente o
que o `zizmor`/`pinact` (seção de GitHub Actions acima) verifica, e uma tag mutável é uma via de
supply-chain. As versões de action citadas eram as vigentes em agosto de 2026; confira a atual antes de
copiar. O elo que amarra tudo é o **SARIF**: cada ferramenta exporta SARIF, o `upload-sarif` manda para
o **GitHub Code Scanning**, e o Code Scanning é quem deduplica, mostra inline no PR, rastreia o estado
(aberto/corrigido/dispensado) e aplica a regra de "só falhar em achado novo". Sem SARIF, cada
ferramenta é uma ilha de log que ninguém lê.

## Política de falha: o que decide o sucesso

Este é o ponto que mais determina se o pipeline sobrevive. **Um pipeline que grita por tudo é
desligado pelo time em duas semanas** — e um scanner desligado tem cobertura zero, pior que um scanner
calibrado. A regra única: **bloqueie o merge só no que é acionável**, e reporte o resto sem bloquear.

Bloqueia (o desenvolvedor consegue e deve resolver antes do merge):

- **Segredo verificado ou novo** no diff. Sempre. É o achado de maior sinal e menor falso positivo.
- **Achado de SAST *novo*** de severidade alta introduzido pelo PR (via `--baseline-commit`). O passivo
  histórico não bloqueia; a regressão sim.
- **Dependência com CVE que tem fix disponível, é alcançável, e está em KEV ou com EPSS alto.** Os
  quatro predicados juntos — "crítico" no NVD sozinho não basta (veja a seção de triagem de SCA).
- **Misconfig crítica** com correção óbvia (bucket público, `rejectUnauthorized:false`, secret em env
  da imagem).

Não bloqueia (reporta em dashboard/issue, entra no fluxo normal de trabalho):

- Passivo histórico de SAST — congelado pelo baseline.
- CVE **sem fix disponível**, ou em dependência de build, ou comprovadamente não alcançada.
- Achado de `p/security-audit`, `detect-object-injection` e afins — alto ruído por design.
- Todo resultado de DAST/nightly: é insumo de triagem, não gate.

Dois mecanismos operacionais tornam isso real. O **baseline** (`--baseline-commit` no Semgrep,
`.secrets.baseline` no detect-secrets, `.trivyignore` com data de expiração) separa "novo" de "velho",
e é o que permite ligar um scanner num repositório maduro sem parar a entrega no primeiro dia. E o
**exit code deliberado**: rode as ferramentas em modo relatório (exit 0, sempre sobe SARIF) e deixe o
gate para uma regra explícita — no GitHub, isso é a *Code Scanning* configurada para falhar só em
severidade `error`/`critical` *nova*. Nunca use o exit-code default de um scanner como política; quase
todos falham em qualquer achado, e é assim que se treina o time a apertar "merge anyway" sem ler.

A métrica de saúde não é "achados abertos" (essa só cresce), é **"achado novo por PR tende a zero"** e
**"tempo até corrigir um achado bloqueante"**. Um repositório com 200 achados históricos e zero novos
há meses é mais seguro que um com 20 e três novos por semana.

## Laboratórios para praticar e validar ferramenta

Todo alvo desta lista é **projetado para ser atacado** — é onde você calibra uma ferramenta nova (vê o
que ela pega e o que ela deixa passar) e pratica sem risco legal. Rode localmente; o que você sobe na
sua máquina é seu.

| Lab | Foco | Como subir |
|---|---|---|
| **OWASP Juice Shop** | Web moderno (SPA Angular + API REST), gamificado, cobre o Top 10 inteiro | `docker run --rm -p 3000:3000 bkimminich/juice-shop` |
| **OWASP WebGoat** | Web com lições guiadas e explicação de cada aula | `docker run --rm -p 8080:8080 -p 9090:9090 webgoat/webgoat` |
| **DVWA** | PHP/MySQL clássico, com níveis low/medium/high para ver a mesma falha mitigada | `docker run --rm -p 8080:80 vulnerables/web-dvwa` |
| **PortSwigger Web Security Academy** | Labs hospedados de graça, os melhores do mundo em profundidade por tema | Só browser + conta grátis em portswigger.net/web-security |
| **VAmPI** | API REST deliberadamente vulnerável — o alvo certo para testar `schemathesis`/ZAP API scan e BOLA | `docker run --rm -p 5000:5000 erev0s/vampi` |
| **crAPI** | API de plataforma automotiva com BOLA, mass assignment e JWT quebrado — cobre o OWASP API Top 10 | `git clone` + `docker compose up` (stack multi-container) |
| **DVIA-v2** | iOS deliberadamente vulnerável — armazenamento inseguro, pinning, runtime | Build do projeto num dispositivo/simulador seu |
| **InsecureBankv2** | Android deliberadamente vulnerável — o par do DVIA para calibrar jadx/objection/drozer | APK do repositório num emulador seu |

O uso preciso deles é dobrado: aprender a *classe* de vulnerabilidade (para isso, comece pelo Juice
Shop e pela PortSwigger Academy), e **calibrar a ferramenta** — rode o seu ZAP contra o Juice Shop e o
seu `schemathesis` contra o VAmPI/crAPI para ver, num alvo de gabarito conhecido, exatamente o que cada
scanner encontra e o que ele silenciosamente não encontra. Essa segunda parte é o que te dá calibragem
honesta para o "o que isso não vai achar" de cada ferramenta.

## Falsos positivos comuns do ferramental

Antes dos falsos positivos, o falso *negativo* estrutural, que é mais perigoso: **nenhuma ferramenta
deste arquivo encontra as três categorias que mais causam breach real.** Vale repetir porque um
processo de "passou nos scanners, aprovado" ignora exatamente onde estão os bugs caros:

- **Autorização quebrada** (IDOR/BOLA, escalação horizontal e vertical) — a categoria #1 do OWASP Top
  10 e a #1 do API Top 10. Scanner acha padrão sintático e CVE; ele não conhece o seu modelo de
  permissão, então não sabe que `GET /pedido/123` deveria checar se o pedido é seu. É trabalho humano —
  `references/autorizacao-e-logica-de-negocio.md`.
- **Lógica de negócio** — cupom acumulável, refund maior que a compra, pular etapa do checkout,
  preço negociado no cliente. Não há assinatura para "essa regra de negócio está errada".
- **Race condition / TOCTOU** — saldo debitado duas vezes, convite usado N vezes. Precisa de
  ferramenta de concorrência (Turbo Intruder, single-packet attack) *e* de hipótese humana sobre onde a
  janela existe; o SAST vê o código, não a corrida.

Os falsos *positivos* recorrentes, que queimam confiança se você não os antecipar:

- `npm audit`/`osv-scanner` sinalizando **CVE em devDependency ou em dependência de build** que nunca
  toca input não confiável nem roda em produção. "High" no relatório, risco nulo. Filtre com `--omit=dev`
  e triagem de alcançabilidade.
- `eslint-plugin-security` `detect-object-injection` disparando em **todo `obj[chave]`** — centenas de
  ocorrências, quase todas inofensivas. Desligue a regra.
- **Semgrep casando `$queryRawUnsafe("literal constante")`** — a chamada é a "perigosa", mas o argumento
  é uma string literal do próprio código, sem interpolação. Não é injeção. A regra custom deste arquivo
  já exclui esse caso com `pattern-not`.
- ZAP/nikto reportando **header ausente** (`X-Frame-Options`, cache-control) num endpoint de API que só
  serve JSON e nunca é renderizado como página — severidade inflada para o contexto.
- `gitleaks` marcando **chave de teste pública documentada** (a `sk_test_...` de exemplo do Stripe) como
  segredo. É um falso positivo legítimo — suprima com `gitleaks:allow` e um comentário.
- `trufflehog` sem `--only-verified` listando **credencial já revogada** que ainda está no histórico:
  presente, mas morta. A verificação ativa é o que separa "existe no git" de "funciona agora".

A regra que unifica os dois lados: **scanner responde "existe esse padrão?", não "isso é explorável
aqui?".** A segunda pergunta é sua. Calibre cada ferramenta num lab de gabarito conhecido (seção
acima), aprenda o formato de ruído dela, e trate todo achado como hipótese a confirmar — não como
veredito.

## Fontes

- OWASP Top 10 (2025): https://owasp.org/Top10/
- OWASP Web Security Testing Guide (WSTG): https://owasp.org/www-project-web-security-testing-guide/
- OWASP MASVS / MASTG (mobile): https://mas.owasp.org/
- Semgrep — docs e registry de regras: https://semgrep.dev/docs/
- CodeQL — docs do CLI: https://docs.github.com/en/code-security/codeql-cli
- OSV-Scanner: https://google.github.io/osv-scanner/ · OSV.dev: https://osv.dev/
- govulncheck: https://go.dev/blog/govulncheck · https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck
- Trivy: https://trivy.dev/ · Grype/Syft: https://github.com/anchore
- gitleaks: https://github.com/gitleaks/gitleaks · trufflehog: https://github.com/trufflesecurity/trufflehog
- CISA KEV: https://www.cisa.gov/known-exploited-vulnerabilities-catalog · FIRST EPSS: https://www.first.org/epss/
- checkov: https://www.checkov.io/ · zizmor: https://docs.zizmor.sh/
- OWASP ZAP — docs e Automation Framework: https://www.zaproxy.org/docs/
- Burp Suite — docs: https://portswigger.net/burp/documentation · Web Security Academy: https://portswigger.net/web-security
- nuclei: https://docs.projectdiscovery.io/tools/nuclei · ffuf: https://github.com/ffuf/ffuf
- sqlmap: https://github.com/sqlmapproject/sqlmap/wiki · nikto: https://github.com/sullo/nikto
- testssl.sh: https://testssl.sh/ · sslyze: https://nabla-c0d3.github.io/sslyze/documentation/
- MobSF: https://mobsf.github.io/docs/ · jadx: https://github.com/skylot/jadx · Frida: https://frida.re/docs/ · objection: https://github.com/sensepost/objection · drozer: https://github.com/WithSecureLabs/drozer
- mitmproxy: https://docs.mitmproxy.org/ · Android network security config: https://developer.android.com/privacy-and-security/security-config
- Go fuzzing: https://go.dev/security/fuzz/ · Jazzer: https://github.com/CodeIntelligenceTesting/jazzer · Atheris: https://github.com/google/atheris · fast-check: https://fast-check.dev/
- schemathesis: https://schemathesis.readthedocs.io/ · RESTler: https://github.com/microsoft/restler-fuzzer
- SARIF: https://sarifweb.azurewebsites.net/ · GitHub Code Scanning: https://docs.github.com/en/code-security/code-scanning
- Sigstore/cosign: https://docs.sigstore.dev/ · Syft SBOM: https://github.com/anchore/syft
- OWASP Juice Shop: https://owasp.org/www-project-juice-shop/ · WebGoat: https://owasp.org/www-project-webgoat/ · crAPI: https://github.com/OWASP/crAPI · VAmPI: https://github.com/erev0s/VAmPI