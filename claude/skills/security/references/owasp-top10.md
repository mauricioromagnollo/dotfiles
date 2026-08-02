# OWASP Top 10 e o ecossistema OWASP — mapa de navegação

Este arquivo é o **mapa do território OWASP**: a edição vigente do Top 10 (2025), a tradução entre
as numerações 2021 e 2025, as outras listas (API, Mobile, LLM, CI/CD), os projetos que são
ferramenta de trabalho (ASVS, WSTG, MASVS, Cheat Sheets) e — o mais importante — a tabela que
converte um sintoma observado no código em categoria OWASP e no arquivo desta skill que aprofunda.
Abra este arquivo quando precisar: classificar um achado com o código correto (`A01:2025`,
`API1:2023`, `CWE-639`), traduzir um checklist antigo que ainda usa numeração 2021, decidir qual
lista/padrão OWASP serve para um alvo específico, ou encontrar em qual arquivo irmão está o
aprofundamento técnico. O aprofundamento de cada falha **não** está aqui — está nos arquivos
referenciados em cada seção.

## Índice

- [OWASP Top 10:2025 — a edição vigente](#owasp-top-102025--a-edição-vigente)
- [Tradução 2021 → 2025](#tradução-2021--2025)
- [O que o Top 10 NÃO é](#o-que-o-top-10-não-é)
- [Como o Top 10 é construído (e o que isso esconde)](#como-o-top-10-é-construído-e-o-que-isso-esconde)
- [As outras listas OWASP — qual usar para cada alvo](#as-outras-listas-owasp--qual-usar-para-cada-alvo)
- [Projetos OWASP que são ferramenta, não lista](#projetos-owasp-que-são-ferramenta-não-lista)
- [Tabela de tradução: sintoma → categoria → arquivo desta skill](#tabela-de-tradução-sintoma--categoria--arquivo-desta-skill)
- [Falsos positivos comuns de classificação](#falsos-positivos-comuns-de-classificação)
- [Fontes](#fontes)

## OWASP Top 10:2025 — a edição vigente

Release candidate em novembro de 2025, **versão final em 24 de dezembro de 2025**
([owasp.org/Top10/2025](https://owasp.org/Top10/2025/)). É a edição vigente; a anterior é a de
2021. Se você encontrar material citando a numeração de 2025 e divergindo do que está aqui,
provavelmente ele foi escrito contra o RC. Visão geral antes do detalhe:

| # | Categoria (nome oficial, em inglês) | Movimento vs 2021 |
|---|---|---|
| A01:2025 | Broken Access Control | mantém #1; **absorve SSRF** (ex-A10:2021) |
| A02:2025 | Security Misconfiguration | sobe de #5 |
| A03:2025 | Software Supply Chain Failures | **nova** (expansão de A06:2021) |
| A04:2025 | Cryptographic Failures | cai de #2 |
| A05:2025 | Injection | cai de #3 |
| A06:2025 | Insecure Design | cai de #4 |
| A07:2025 | Authentication Failures | mantém #7; renomeada |
| A08:2025 | Software or Data Integrity Failures | mantém #8; "and" → "or" |
| A09:2025 | Security Logging and Alerting Failures | mantém #9; "Monitoring" → "Alerting" |
| A10:2025 | Mishandling of Exceptional Conditions | **nova** |

### A01:2025 — Broken Access Control

O que agrupa: toda falha em que o servidor **não verifica se quem pede pode pedir** — IDOR/BOLA
(trocar o `id` do recurso), escalada horizontal e vertical, falta de checagem de role em endpoint
de função privilegiada (BFLA), CSRF, path traversal, open redirect e, desde 2025, **SSRF**
(CWE-918), que deixou de ser categoria própria porque na prática é "o servidor acessa o que não
devia em nome do usuário". Continua sendo a categoria #1 em incidência real (3,73% das aplicações
testadas) e é de longe a classe mais paga em bug bounty.

CWEs principais: CWE-284, CWE-285, CWE-639 (IDOR), CWE-862 (missing authorization), CWE-863
(incorrect authorization), CWE-352 (CSRF), CWE-22 (path traversal), CWE-601 (open redirect),
CWE-918 (SSRF).

No código do dia a dia: handler que faz `findUnique({ where: { id: req.params.id } })` sem
`AND userId = session.userId`; middleware de auth aplicado por rota (e a rota nova ficou de fora)
em vez de por padrão; role check feito no frontend; `fetch(req.body.url)` para webhook/preview.

Aprofundamento: `veja references/autorizacao-e-logica-de-negocio.md` (IDOR, BFLA, multi-tenancy),
`references/ssrf-e-camada-http.md` (SSRF, path traversal, open redirect),
`references/xss-e-navegador.md` (CSRF).

### A02:2025 — Security Misconfiguration

O que agrupa: o software está íntegro, mas **configurado de forma insegura** — credencial/config
default, feature de debug ligada em produção, headers de segurança ausentes, CORS permissivo,
parser XML com entidades externas habilitadas (XXE, CWE-611, que mora aqui desde 2021, não em
Injection), stack de cloud com bucket público, listagem de diretório, permissões largas. Subiu
para #2 porque aplicações modernas são cada vez mais "configuração sobre plataforma" (cloud, IaC,
SaaS): o erro migrou do código para o YAML.

CWEs principais: CWE-16 (configuration), CWE-611 (XXE), CWE-1004 (cookie sem `HttpOnly`), CWE-614
(cookie sem `Secure`), CWE-756 (página de erro default), CWE-942 (CORS permissivo).

No código do dia a dia: `app.use(cors({ origin: true, credentials: true }))`; `NODE_ENV` ausente
(Express assume development e vaza stack trace); `synchronize: true` do TypeORM em produção;
`libxmljs`/parser Java com `external-general-entities` ligado; Dockerfile rodando como root.

Aprofundamento: `veja references/xss-e-navegador.md` (headers, CORS, cookies),
`references/injecao.md` (XXE), `references/supply-chain-e-cicd.md` (containers, IaC),
`references/criptografia-e-segredos.md` (TLS mal configurado).

### A03:2025 — Software Supply Chain Failures

O que agrupa: a expansão de "Vulnerable and Outdated Components" (A06:2021) para a **cadeia
inteira** — dependências diretas e transitivas vulneráveis, pacote malicioso/typosquatting,
comprometimento do build e do CI/CD, update sem verificação de integridade, tooling de
desenvolvedor inseguro. Entrou em #3 **pelo voto da comunidade** (50% dos respondentes a
colocaram em #1 — o maior consenso da pesquisa), não pelos dados de teste: tem a maior taxa média
de incidência do dataset (5,72%), mas só 11 CVEs mapeados, porque comprometimento de supply chain
não vira CVE da *sua* aplicação — vira incidente.

CWEs principais: CWE-1104 (componente não mantido), CWE-1395 (dependência de componente
vulnerável), CWE-1329 (componente não atualizável), CWE-829 (funcionalidade de fonte não
confiável).

No código do dia a dia: `package.json` com ranges largos e sem lockfile commitado; CI que roda
`npm install` com scripts de pós-instalação em PR de fork; imagem base `latest`; dependência
transitiva com CVE crítico que ninguém enxerga porque só se audita as diretas.

Aprofundamento: `veja references/supply-chain-e-cicd.md`.

### A04:2025 — Cryptographic Failures

O que agrupa: dado sensível **sem proteção criptográfica ou com criptografia quebrada** —
transmissão em claro, algoritmo/modo obsoleto (MD5, SHA-1 para senha, ECB), chave hardcoded,
gerador aleatório previsível em contexto de segurança, senha com hash sem custo computacional.
Caiu de #2 para #4, mas continua sendo a categoria por trás da maioria dos vazamentos de dados
com multa (o dado vazou *e* estava legível).

CWEs principais: CWE-327 (algoritmo quebrado), CWE-328 (hash fraco), CWE-330/CWE-338 (aleatório
previsível), CWE-311/CWE-319 (dado em claro), CWE-312 (armazenamento em claro), CWE-916 (hash de
senha sem esforço computacional), CWE-798 (credencial hardcoded).

No código do dia a dia: `crypto.createHash('md5').update(password)`; `Math.random()` para token
de reset; `aes-256-ecb`; TLS desabilitado "só no ambiente interno";
`rejectUnauthorized: false`.

Aprofundamento: `veja references/criptografia-e-segredos.md`; armazenamento de senha
especificamente em `references/autenticacao-e-sessao.md`.

### A05:2025 — Injection

O que agrupa: dado não confiável **interpretado como código/sintaxe** por um interpretador — SQL
injection, NoSQL injection, command injection, LDAP, Expression Language, SSTI e também **XSS**
(CWE-79 está nesta categoria desde 2021; XSS não é categoria própria desde 2017). Caiu para #5
em incidência, mas lidera disparado em CVEs mapeados (62.445 na edição 2025) — é a categoria mais
"ferramentável" e mais documentada da história.

CWEs principais: CWE-79 (XSS), CWE-89 (SQLi), CWE-78 (OS command injection), CWE-77, CWE-94 (code
injection), CWE-917 (EL injection), CWE-943 (query injection genérica, cobre NoSQLi).

No código do dia a dia: template string dentro de `$queryRawUnsafe`/`knex.raw`;
`child_process.exec(\`convert ${filename}\`)`; `$where`/objeto não validado indo direto para o
Mongo; `dangerouslySetInnerHTML` com dado de usuário; template engine renderizando string
controlada pelo usuário.

Aprofundamento: `veja references/injecao.md` (SQLi, NoSQLi, command injection, SSTI) e
`references/xss-e-navegador.md` (XSS).

### A06:2025 — Insecure Design

O que agrupa: falhas que **não são bug de implementação** — a arquitetura nunca previu o controle.
Ausência de limite em fluxo de negócio abusável, fluxo de recuperação de conta baseado em
perguntas adivinháveis, confiança em invariante que o cliente pode violar, ausência de threat
modeling. A distinção operacional: Insecure Design não se corrige com patch em uma linha; exige
mudar o desenho. Se a correção é "adicionar a checagem que faltou", é A01/A07; se é "esse fluxo
não deveria existir assim", é A06.

CWEs principais: CWE-840 (business logic errors, categoria), CWE-841 (fluxo comportamental),
CWE-1173 (validação mal arquitetada), CWE-522 (credencial insuficientemente protegida por design).

No código do dia a dia: checkout que confia no preço vindo do carrinho do cliente; convite de
tenant sem expiração; "esqueci minha senha" que confirma existência de e-mail; qualquer fluxo em
que duas requisições paralelas quebram o invariante (o race condition em si aprofunda-se em outro
arquivo).

Aprofundamento: `veja references/threat-modeling-e-severidade.md` (como prevenir por design) e
`references/autorizacao-e-logica-de-negocio.md` (lógica de negócio abusável, race conditions).

### A07:2025 — Authentication Failures

O que agrupa: confirmação de identidade quebrada — credential stuffing sem rate limit, senha
fraca permitida, recuperação de conta insegura, sessão que não expira nem é regenerada, MFA
ausente ou contornável, JWT aceito sem verificação. Renomeada de "Identification and
Authentication Failures" (2021) de volta para o nome curto; posição inalterada (#7). Nota: os
dados de 2025 destacam ataques híbridos — credential stuffing combinado com variações de senha.

CWEs principais: CWE-287 (autenticação imprópria), CWE-307 (sem limite de tentativas), CWE-384
(session fixation), CWE-521 (política de senha fraca), CWE-613 (expiração de sessão
insuficiente), CWE-620, CWE-640 (recuperação de senha fraca).

No código do dia a dia: `jwt.decode()` onde deveria ser `jwt.verify()`; login sem rate limit nem
detecção de stuffing; `req.session` mantido após login (fixation); comparação de token com `==`
em vez de `crypto.timingSafeEqual`.

Aprofundamento: `veja references/autenticacao-e-sessao.md`.

### A08:2025 — Software or Data Integrity Failures

O que agrupa: código e dados aceitos **sem verificação de integridade** — desserialização
insegura de dado controlável (CWE-502: `pickle`, `ObjectInputStream`, gadget chains), prototype
pollution (CWE-1321), auto-update sem assinatura, pipeline de CI/CD que aceita artefato não
verificado, plugin/CDN de fonte não confiável sem SRI. Sobrepõe-se a A03 (supply chain): a regra
prática é A03 = *a dependência/o fornecedor foi comprometido*, A08 = *seu código aceita
código/dado sem verificar integridade*.

CWEs principais: CWE-502 (desserialização), CWE-1321 (prototype pollution), CWE-345 (verificação
de autenticidade insuficiente), CWE-494 (download de código sem checagem de integridade),
CWE-915 (mass assignment / modificação de atributos dinamicamente determinada).

No código do dia a dia: `node-serialize`/`pickle.loads` sobre input; merge recursivo de JSON do
cliente (`lodash.merge` pré-4.17.21) alcançando `__proto__`; workflow do GitHub Actions com
`pull_request_target` rodando código do fork.

Aprofundamento: `veja references/injecao.md` (desserialização, prototype pollution) e
`references/supply-chain-e-cicd.md` (integridade de CI/CD e updates).

### A09:2025 — Security Logging and Alerting Failures

O que agrupa: o ataque acontece e **ninguém fica sabendo** — eventos de segurança (login falho,
falha de autorização, transação de alto valor) não logados; logs sem contexto suficiente para
forense; log poluível (log injection, CWE-117); dado sensível dentro do log (CWE-532); e — a
mudança de nome de "Monitoring" para "Alerting" é deliberada — logs que existem mas não geram
alerta acionável para ninguém. Não é vulnerabilidade explorável diretamente; é o multiplicador de
dano de todas as outras.

CWEs principais: CWE-778 (logging insuficiente), CWE-117 (log injection), CWE-532 (informação
sensível em log), CWE-223 (omissão de informação relevante).

No código do dia a dia: `console.log(req.body)` no handler de login (senha no log); nenhum evento
de auditoria em mudança de permissão; string do usuário concatenada crua na linha de log
(permite forjar entradas com `\n`).

Aprofundamento: PII em logs em `references/criptografia-e-segredos.md`; o que logar por evento em
`references/threat-modeling-e-severidade.md`; sinks de log por linguagem em
`references/revisao-de-codigo.md`.

### A10:2025 — Mishandling of Exceptional Conditions

O que agrupa: **nova em 2025** (segunda escolha da pesquisa comunitária). Comportamento do
programa quando algo sai do caminho feliz: erro que vaza stack trace/versão/SQL na resposta
(CWE-209), `catch` que engole falha de verificação e segue como sucesso — *failing open*
(CWE-636), parâmetro ausente não tratado (CWE-234), privilégio insuficiente mal tratado
(CWE-274), NULL dereference (CWE-476), transação que falha no meio e não faz rollback completo.
Consolida o que antes se espalhava como "code quality". 24 CWEs mapeados; incidência média de
2,95%.

No código do dia a dia: `catch (e) {}` vazio em volta de verificação de assinatura/permissão;
handler global de erro que serializa `err` inteiro para o cliente; `Promise.allSettled` usado
para ignorar falha de checagem de segurança; débito de saldo sem transação atômica.

Aprofundamento: `veja references/revisao-de-codigo.md` (padrões de erro por linguagem) e
`references/autorizacao-e-logica-de-negocio.md` (fail open em autorização, consistência
transacional).

## Tradução 2021 → 2025

Quase toda a documentação de mercado, checklist de auditoria, regra de SAST e política de
conformidade escrita entre 2021 e 2025 usa a numeração antiga. Traduza assim:

| 2021 | 2025 | O que aconteceu |
|---|---|---|
| A01:2021 Broken Access Control | A01:2025 Broken Access Control | mantém #1; agora inclui SSRF |
| A02:2021 Cryptographic Failures | A04:2025 Cryptographic Failures | caiu 2 posições |
| A03:2021 Injection | A05:2025 Injection | caiu 2 posições |
| A04:2021 Insecure Design | A06:2025 Insecure Design | caiu 2 posições |
| A05:2021 Security Misconfiguration | A02:2025 Security Misconfiguration | subiu de #5 para #2 |
| A06:2021 Vulnerable and Outdated Components | A03:2025 Software Supply Chain Failures | renomeada e **muito** ampliada (build, CI/CD, distribuição) |
| A07:2021 Identification and Authentication Failures | A07:2025 Authentication Failures | só renomeada |
| A08:2021 Software and Data Integrity Failures | A08:2025 Software or Data Integrity Failures | "and" → "or", escopo igual |
| A09:2021 Security Logging and Monitoring Failures | A09:2025 Security Logging and Alerting Failures | "Monitoring" → "Alerting" (ênfase em alerta acionável) |
| A10:2021 Server-Side Request Forgery | — (absorvida por A01:2025) | SSRF deixou de ser categoria própria |
| — | A10:2025 Mishandling of Exceptional Conditions | nova (via pesquisa comunitária) |

Armadilhas de tradução ao ler material antigo:

- **"A03" sem ano é ambíguo**: em texto de 2021–2025 significa Injection; em texto pós-2025
  significa Supply Chain. Sempre cite com ano: `A03:2021` vs `A03:2025`.
- **Material de 2017 ainda circula** (cursos, políticas corporativas): lá XSS era categoria
  própria (A7:2017), XXE era categoria própria (A4:2017) e desserialização insegura era A8:2017.
  Hoje: XSS → Injection (A05:2025), XXE → Security Misconfiguration (A02:2025), desserialização →
  Integrity Failures (A08:2025).
- **SSRF**: um relatório que classifica SSRF como "A10" está usando 2021. Em 2025, classifique
  como A01:2025 (CWE-918 continua sendo o identificador estável — na dúvida, **o CWE é sempre a
  referência que não muda de número entre edições**).

## O que o Top 10 NÃO é

O próprio OWASP repete isso em toda edição, e o mercado ignora em toda edição:

- **Não é checklist de auditoria.** São 10 *categorias* guarda-chuva sobre ~250 CWEs — "verificamos
  os OWASP Top 10" não descreve nenhum procedimento verificável. Um pentest pode "cobrir o Top 10"
  e não testar IDOR em nenhum endpoint.
- **Não é padrão de conformidade.** Não há critério de aprovação/reprovação, nível, nem requisito
  testável. Quando um contrato, um PCI DSS assessor ou um cliente pede "conformidade com OWASP",
  o artefato correto a oferecer é o **ASVS** (veja abaixo): requisitos numerados, individualmente
  verificáveis, em 3 níveis. O Top 10 serve para conscientização e priorização de treinamento;
  o ASVS serve para verificação; o WSTG serve para *como* testar cada requisito.
- **Não é ranking de severidade para o seu app.** A ordem vem de prevalência estatística em
  milhões de apps de terceiros. No seu sistema, um IDOR no endpoint de faturas vale mais que dez
  headers ausentes, independente da posição na lista. Severidade de achado individual usa CVSS +
  contexto de negócio — `veja references/threat-modeling-e-severidade.md`.

Regra prática: **Top 10 para conversar e priorizar; ASVS para exigir e verificar; WSTG/MASTG para
testar; Cheat Sheets para implementar; CWE para classificar o achado individual.**

## Como o Top 10 é construído (e o que isso esconde)

Metodologia da edição 2025 (importa porque explica os pontos cegos):

- **Dados de teste**: contribuições de fornecedores e consultorias cobrindo ~2,8 milhões de
  aplicações testadas, mapeadas para o maior conjunto de CWEs já usado (quase 590 CWEs distintos).
  A métrica é **taxa de incidência** — % de aplicações com ≥1 ocorrência do CWE — e não
  frequência, para que um scanner que cospe 5.000 XSS num app só conte uma vez.
- **Exploitability/impacto**: ~175 mil registros de CVE mapeados a CWEs, ~156 mil com CVSSv3,
  usados para ponderar os fatores de exploit e impacto de cada categoria.
- **8 categorias vêm dos dados; 2 vêm de pesquisa de opinião com praticantes** (em 2025:
  A03 Software Supply Chain Failures e A10 Mishandling of Exceptional Conditions). A pesquisa
  existe precisamente porque o OWASP reconhece o viés dos dados.

O viés estrutural, dito pelo próprio OWASP: **os dados só contêm o que a indústria consegue
testar de forma automatizada e em escala**. Consequências práticas para quem revisa código:

- **Falhas de lógica de negócio e race conditions são sub-representadas** — nenhum scanner acha
  "o cupom pode ser aplicado duas vezes em paralelo". Nos programas de bug bounty e em pentest
  manual, access control + lógica de negócio dominam os pagamentos; na lista, lógica de negócio
  fica diluída em A06 sem destaque. Não conclua que algo é raro por estar mal representado.
- **É indicador atrasado**: os dados refletem apps testados nos anos anteriores, muitos legados.
  Técnica nova (request smuggling, cache poisoning, ataque a agentes LLM) demora anos para
  aparecer — acompanhe o "Top 10 web hacking techniques" anual da PortSwigger para o leading
  indicator.
- **Categoria com CWE "escaneável" sobe** (Injection tem 62 mil CVEs); categoria de incidente
  raro-porém-catastrófico depende do voto da comunidade para entrar (foi exatamente o caso de
  supply chain).

## As outras listas OWASP — qual usar para cada alvo

O Top 10 "clássico" é sobre aplicações web genéricas. Para outros alvos, existem listas próprias
— e usá-las é obrigatório para classificar direito (chamar BOLA de "A01" num pentest de API
funciona, mas `API1:2023` é o vocabulário que o cliente de API espera).

| Meu alvo é… | Use esta lista | Edição vigente | Aprofundamento na skill |
|---|---|---|---|
| Aplicação web / backend em geral | OWASP Top 10 | 2025 | este arquivo + irmãos |
| API REST/GraphQL/gRPC | [API Security Top 10](https://owasp.org/API-Security/editions/2023/en/0x11-t10/) | 2023 | `references/api-e-graphql.md` |
| App mobile (Android/iOS/RN/Flutter) | [Mobile Top 10](https://owasp.org/www-project-mobile-top-10/) | 2024 (final) | `references/mobile.md` |
| App com LLM / agente de IA | [Top 10 for LLM Applications](https://owasp.org/www-project-top-10-for-large-language-model-applications/) (GenAI Security Project) | 2025 | `references/llm-e-ia.md` |
| Pipeline de CI/CD | [Top 10 CI/CD Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks/) | v1 (2022) — IDs `CICD-SEC-1..10` | `references/supply-chain-e-cicd.md` |
| Guiar devs no que *construir* (não no que evitar) | [Top 10 Proactive Controls](https://top10proactive.owasp.org/) | 2024 — IDs `C1..C10` | `references/revisao-de-codigo.md` |
| Abuso automatizado (bots, fraude, scraping) | [Automated Threats (OAT)](https://owasp.org/www-project-automated-threats-to-web-applications/) | handbook, IDs `OAT-001..021` | `references/autorizacao-e-logica-de-negocio.md` |

Resumo do que cada uma cobre, para não confundir com o Top 10 clássico:

**API Security Top 10 (2023)** — `API1` Broken Object Level Authorization (BOLA), `API2` Broken
Authentication, `API3` Broken Object Property Level Authorization (funde mass assignment +
excessive data exposure), `API4` Unrestricted Resource Consumption, `API5` Broken Function Level
Authorization, `API6` Unrestricted Access to Sensitive Business Flows, `API7` SSRF, `API8`
Security Misconfiguration, `API9` Improper Inventory Management (shadow/zombie APIs), `API10`
Unsafe Consumption of APIs. Note que as 3 primeiras + a 5ª são todas autorização/autenticação —
em API, o problema dominante é access control, não injection.

**Mobile Top 10 (2024)** — `M1` Improper Credential Usage, `M2` Inadequate Supply Chain Security,
`M3` Insecure Authentication/Authorization, `M4` Insufficient Input/Output Validation, `M5`
Insecure Communication, `M6` Inadequate Privacy Controls, `M7` Insufficient Binary Protections,
`M8` Security Misconfiguration, `M9` Insecure Data Storage, `M10` Insufficient Cryptography.
Primeira atualização desde 2016 — material que cite "M10: Extraneous Functionality" é da lista
velha.

**Top 10 for LLM Applications (2025)** — `LLM01` Prompt Injection, `LLM02` Sensitive Information
Disclosure, `LLM03` Supply Chain, `LLM04` Data and Model Poisoning, `LLM05` Improper Output
Handling, `LLM06` Excessive Agency, `LLM07` System Prompt Leakage, `LLM08` Vector and Embedding
Weaknesses, `LLM09` Misinformation, `LLM10` Unbounded Consumption.

**CI/CD Security Risks** — `CICD-SEC-1` Insufficient Flow Control Mechanisms, `-2` Inadequate
Identity and Access Management, `-3` Dependency Chain Abuse, `-4` Poisoned Pipeline Execution
(PPE), `-5` Insufficient PBAC, `-6` Insufficient Credential Hygiene, `-7` Insecure System
Configuration, `-8` Ungoverned Usage of 3rd Party Services, `-9` Improper Artifact Integrity
Validation, `-10` Insufficient Logging and Visibility.

**Proactive Controls (2024)** — o Top 10 "invertido", para construir: `C1` Implement Access
Control, `C2` Use Cryptography the proper way, `C3` Validate all Input & Handle Exceptions, `C4`
Address Security from the Start, `C5` Secure By Default Configurations, `C6` Keep your Components
Secure, `C7` Implement Digital Identity, `C8` Leverage Browser Security Features, `C9` Implement
Security Logging and Monitoring, `C10` Stop Server Side Request Forgery. Útil como estrutura de
guideline interna de time.

**Automated Threats (OAT)** — vocabulário para abuso que não é "vulnerabilidade": `OAT-008`
Credential Stuffing, `OAT-011` Scraping, `OAT-005` Scalping, `OAT-001` Carding, `OAT-021` Denial
of Inventory. Use quando o achado for "o endpoint permite abuso em escala" e não "o endpoint tem
um bug".

## Projetos OWASP que são ferramenta, não lista

### ASVS — o padrão verificável

[Application Security Verification Standard](https://github.com/OWASP/ASVS), versão **5.0**
(maio/2025): ~350 requisitos numerados em **17 capítulos** (V1 Encoding and Sanitization, V2
Validation and Business Logic, V3 Web Frontend Security, V4 API and Web Service, V5 File
Handling, V6 Authentication, V7 Session Management, V8 Authorization, V9 Self-contained Tokens,
V10 OAuth and OIDC, V11 Cryptography, V12 Secure Communication, V13 Configuration, V14 Data
Protection, V15 Secure Coding and Architecture, V16 Security Logging and Error Handling, V17
WebRTC). Novidades relevantes da 5.0: JWT (V9) e OAuth/OIDC (V10) viraram capítulos de primeira
classe.

Níveis (cumulativos — L2 inclui L1; L3 inclui tudo):

- **L1** — mínimo para qualquer aplicação; verificável de fora, sem acesso ao código. Use como
  piso universal e para apps sem dado sensível.
- **L2** — alvo padrão para qualquer app com dado sensível (login, PII, pagamento). É o nível a
  exigir em contrato para a maioria dos sistemas de negócio; pressupõe acesso a código e docs.
- **L3** — sistemas onde falha é catastrófica (financeiro, saúde, infraestrutura crítica);
  exige revisão de design e defesa em profundidade.

Quando abrir: quando precisar de critério objetivo ("o requisito V6.x.y passa ou não passa") para
auditoria, contrato, definition of done de segurança, ou para responder "o que exatamente eu
verifico sobre sessão/JWT/upload".

### WSTG — como testar

[Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/), versão
estável **4.2**. Cada teste tem ID `WSTG-<CATEGORIA>-<NN>`; as categorias: `INFO` (recon), `CONF`
(configuração), `IDNT` (identidade), `ATHN` (autenticação), `ATHZ` (autorização), `SESS`
(sessão), `INPV` (input validation), `ERRH` (erros), `CRYP` (cripto), `BUSL` (lógica de negócio),
`CLNT` (client-side), `APIT` (API, ex.: `WSTG-APIT-01` GraphQL). Exemplos úteis para citar em
relatório: `WSTG-ATHZ-04` (IDOR), `WSTG-INPV-05` (SQLi), `WSTG-SESS-05` (CSRF). Quando abrir:
quando souber *o que* testar mas não *como* — cada página traz procedimento e payloads.

### MASVS + MASTG — o par mobile

[MASVS](https://mas.owasp.org/MASVS/) (padrão verificável, 8 grupos de controle:
`MASVS-STORAGE`, `-CRYPTO`, `-AUTH`, `-NETWORK`, `-PLATFORM`, `-CODE`, `-RESILIENCE`,
`-PRIVACY`) e [MASTG](https://mas.owasp.org/MASTG/) (o guia de teste correspondente, com técnicas
por plataforma). O equivalente mobile do par ASVS+WSTG. `veja references/mobile.md`.

### Cheat Sheet Series — a resposta de implementação

[cheatsheetseries.owasp.org](https://cheatsheetseries.owasp.org/) — mantidas, revisadas, e quase
sempre a melhor resposta curta para "como implemento X direito". As que mais valem abrir:

| Pergunta | Cheat sheet |
|---|---|
| Como parametrizo/escapo SQL | [SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html) |
| Onde escapar output HTML/JS/CSS | [XSS Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html) + [DOM based XSS Prevention](https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html) |
| Defesa CSRF (tokens, SameSite) | [CSRF Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html) |
| Hash de senha (Argon2id, bcrypt, parâmetros) | [Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html) |
| Fluxo de login/registro/recuperação | [Authentication](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html) + [Forgot Password](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html) |
| Cookies, timeout, rotação de sessão | [Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) |
| Modelo de autorização (RBAC/ABAC, deny by default) | [Authorization](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html) |
| Upload de arquivo seguro | [File Upload](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html) |
| Onde guardar segredos/chaves | [Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) |
| Algoritmos e modos de cripto | [Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html) |
| Endurecer API REST | [REST Security](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html) |
| Endurecer GraphQL | [GraphQL](https://cheatsheetseries.owasp.org/cheatsheets/GraphQL_Cheat_Sheet.html) |
| Desserialização segura | [Deserialization](https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html) |
| Prevenir SSRF | [SSRF Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html) |
| O que e como logar | [Logging](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html) |

Existe também um índice cruzado oficial [Top 10 → cheat sheets](https://cheatsheetseries.owasp.org/IndexTopTen.html).

### Os demais que valem conhecer

- **SAMM** ([owaspsamm.org](https://owaspsamm.org/), versão 2) — modelo de maturidade do
  *programa* de segurança (5 funções de negócio × 15 práticas, 3 níveis de maturidade). Use para
  responder "quão maduro é nosso AppSec como organização", não para avaliar um app.
- **Dependency-Check** — SCA gratuito (CVEs via NVD) para o build. Comparação com alternativas em
  `references/ferramentas.md`.
- **Juice Shop** ([owasp.org/www-project-juice-shop](https://owasp.org/www-project-juice-shop/)) —
  aplicação deliberadamente vulnerável (Node/Angular) cobrindo o Top 10 inteiro; o melhor alvo
  legal para praticar payloads e validar regras de scanner antes de usar em código real.

## Tabela de tradução: sintoma → categoria → arquivo desta skill

A porta de entrada da skill. Sintoma observado no código/comportamento → categoria vigente (com
CWE quando útil) → onde está o aprofundamento.

| Sintoma observado | Categoria | Arquivo |
|---|---|---|
| Usuário vê pedido de outro trocando o `id` na URL/body | A01:2025 (IDOR/BOLA, CWE-639) — em API: API1:2023 | `references/autorizacao-e-logica-de-negocio.md` |
| Endpoint admin responde para usuário comum (falta role check) | A01:2025 (BFLA, CWE-862) — em API: API5:2023 | `references/autorizacao-e-logica-de-negocio.md` |
| `PATCH /me` aceita `role`/`isAdmin` vindos do body | A01/A08 (mass assignment, CWE-915) — em API: API3:2023 | `references/autorizacao-e-logica-de-negocio.md` |
| Servidor faz `fetch` de URL fornecida pelo usuário (webhook, preview, import) | A01:2025 (SSRF, CWE-918) | `references/ssrf-e-camada-http.md` |
| Form que muda estado sem token anti-CSRF e cookie sem `SameSite` | A01:2025 (CWE-352) | `references/xss-e-navegador.md` |
| `?next=`/`?redirect=` aceita URL externa | A01:2025 (open redirect, CWE-601) | `references/ssrf-e-camada-http.md` |
| Nome de arquivo do usuário chega em `fs.readFile`/`path.join` | A01:2025 (path traversal, CWE-22) | `references/ssrf-e-camada-http.md` |
| SQL montado com template string / concatenação | A05:2025 (SQLi, CWE-89) | `references/injecao.md` |
| Objeto do body vai direto para query Mongo (`$where`, `$gt`) | A05:2025 (NoSQLi, CWE-943) | `references/injecao.md` |
| Input do usuário em `exec`/`spawn` com shell | A05:2025 (command injection, CWE-78) | `references/injecao.md` |
| String do usuário renderizada como template server-side | A05:2025 (SSTI, CWE-94/1336) | `references/injecao.md` |
| Input refletido em HTML sem escape / `dangerouslySetInnerHTML` cru | A05:2025 (XSS, CWE-79) | `references/xss-e-navegador.md` |
| Parser XML aceita DOCTYPE/entidades externas | A02:2025 (XXE, CWE-611) | `references/injecao.md` |
| CORS reflete `Origin` com `credentials: true` | A02:2025 (CWE-942) | `references/xss-e-navegador.md` |
| Cookie de sessão sem `HttpOnly`/`Secure`/`SameSite` | A02:2025 / A07:2025 | `references/autenticacao-e-sessao.md` |
| Sem CSP, sem `X-Content-Type-Options`, headers default | A02:2025 | `references/xss-e-navegador.md` |
| Bucket/storage público, IaC com permissão larga, container root | A02:2025 | `references/supply-chain-e-cicd.md` |
| Dependência com CVE conhecido; lockfile ausente; pacote typosquatting | A03:2025 (CWE-1395) — pipeline: CICD-SEC-3 | `references/supply-chain-e-cicd.md` |
| CI executa código de PR de fork com acesso a secrets | A03:2025 / CICD-SEC-4 (PPE) | `references/supply-chain-e-cicd.md` |
| Senha com MD5/SHA-1/sem salt; `Math.random()` para token | A04:2025 (CWE-916, CWE-338) | `references/criptografia-e-segredos.md` |
| Chave de API/senha commitada no repositório | A04:2025 (CWE-798) | `references/criptografia-e-segredos.md` |
| TLS desligado ou `rejectUnauthorized: false` | A04:2025 (CWE-319) | `references/criptografia-e-segredos.md` |
| JWT com `alg: none`, `decode` sem `verify`, segredo fraco | A07:2025 (CWE-287/345) | `references/autenticacao-e-sessao.md` |
| Login sem rate limit / sem proteção contra credential stuffing | A07:2025 (CWE-307) + OAT-008 | `references/autenticacao-e-sessao.md` |
| Sessão não regenerada após login; logout não invalida no servidor | A07:2025 (CWE-384/613) | `references/autenticacao-e-sessao.md` |
| `pickle.loads`/`ObjectInputStream`/`node-serialize` sobre dado externo | A08:2025 (CWE-502) | `references/injecao.md` |
| Merge recursivo de JSON do cliente alcança `__proto__` | A08:2025 (prototype pollution, CWE-1321) | `references/injecao.md` |
| Duas requisições paralelas usam o mesmo cupom/saldo (TOCTOU) | A06:2025 / lógica de negócio (CWE-362/840) | `references/autorizacao-e-logica-de-negocio.md` |
| Preço/desconto calculado no cliente e aceito pelo servidor | A06:2025 (lógica de negócio) — em API: API6:2023 | `references/autorizacao-e-logica-de-negocio.md` |
| Stack trace, SQL ou versão de framework na resposta de erro | A10:2025 (CWE-209) | `references/revisao-de-codigo.md` |
| `catch` vazio em volta de verificação de assinatura/permissão (fail open) | A10:2025 (CWE-636) | `references/revisao-de-codigo.md` |
| Senha/PII/token aparecendo em log; login falho sem log | A09:2025 (CWE-532/778) | `references/criptografia-e-segredos.md` |
| GraphQL com introspecção aberta, sem limite de profundidade/custo | API8/API4:2023 | `references/api-e-graphql.md` |
| Upload aceita qualquer extensão/content-type e serve do mesmo host | A02/A05 (CWE-434) | `references/ssrf-e-camada-http.md` |
| LLM executa instrução embutida em dado (página, e-mail, tool result) | LLM01:2025 (prompt injection) | `references/llm-e-ia.md` |
| App mobile guarda token/PII em SharedPreferences/plist sem proteção | M9:2024 (Insecure Data Storage) | `references/mobile.md` |

## Falsos positivos comuns de classificação

Erros de *rotulagem* que geram achado inválido ou severidade errada — os falsos positivos
técnicos de cada falha estão nos arquivos irmãos:

- **"Dependência com CVE" ≠ vulnerabilidade explorável.** É A03:2025 como higiene, mas a
  severidade real depende de o código alcançar a função vulnerável (reachability). Não reporte
  CVSS 9.8 da CVE como severidade do achado sem análise de alcance — `veja
  references/supply-chain-e-cicd.md`.
- **Header ausente ≠ finding crítico.** CSP ausente em API JSON pura sem renderização de HTML tem
  impacto próximo de zero; em app server-rendered, importa. Classifique como A02:2025 com
  severidade contextual, não como "XSS".
- **Stack trace em ambiente de dev/staging fechado** não é A10:2025 reportável; em produção, é.
  Verifique o ambiente antes de reportar CWE-209.
- **`Math.random()` fora de contexto de segurança** (jitter de retry, ID de log, shuffle de UI)
  não é A04:2025. Só é achado quando o valor protege algo (token, senha temporária, chave).
- **SSRF "para URL fixa do próprio código"** não é SSRF — a categoria exige que o atacante
  influencie o destino, o caminho ou parte da URL.
- **Rotular tudo de "Insecure Design".** Se a correção é adicionar uma checagem pontual, é
  A01/A07/A10; A06 é reservado para quando o *desenho do fluxo* precisa mudar. A06 usado como
  balde genérico esvazia o relatório.
- **Citar categoria sem ano** ("isso é A03") em relatório: ambíguo desde novembro de 2025. Cite
  `A0X:2025` + CWE. O CWE é o identificador estável; a categoria OWASP é o agrupamento didático.

## Fontes

- [OWASP Top 10:2025](https://owasp.org/Top10/2025/) e [Introdução/metodologia](https://owasp.org/Top10/2025/0x00_2025-Introduction/)
- [A03:2025 Software Supply Chain Failures](https://owasp.org/Top10/2025/A03_2025-Software_Supply_Chain_Failures/) · [A10:2025 Mishandling of Exceptional Conditions](https://owasp.org/Top10/2025/A10_2025-Mishandling_of_Exceptional_Conditions/)
- [OWASP API Security Top 10 (2023)](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)
- [OWASP Mobile Top 10 (2024)](https://owasp.org/www-project-mobile-top-10/)
- [OWASP Top 10 for LLM Applications (2025) — GenAI Security Project](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
- [OWASP Top 10 CI/CD Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks/)
- [OWASP Top 10 Proactive Controls (2024)](https://top10proactive.owasp.org/)
- [OWASP Automated Threats to Web Applications](https://owasp.org/www-project-automated-threats-to-web-applications/)
- [OWASP ASVS 5.0](https://github.com/OWASP/ASVS) (release 30/05/2025)
- [OWASP WSTG v4.2](https://owasp.org/www-project-web-security-testing-guide/)
- [OWASP MASVS](https://mas.owasp.org/MASVS/) · [MASTG](https://mas.owasp.org/MASTG/)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/) · [índice por Top 10](https://cheatsheetseries.owasp.org/IndexTopTen.html)
- [OWASP SAMM](https://owaspsamm.org/) · [Juice Shop](https://owasp.org/www-project-juice-shop/)
- [CWE-1445 — categoria A10:2025 no MITRE](https://cwe.mitre.org/data/definitions/1445.html)
- Análises comparativas 2021→2025: [Equixly](https://equixly.com/blog/2025/12/01/owasp-top-10-2025-vs-2021/), [Fastly](https://www.fastly.com/blog/new-2025-owasp-top-10-list-what-changed-what-you-need-to-know)
