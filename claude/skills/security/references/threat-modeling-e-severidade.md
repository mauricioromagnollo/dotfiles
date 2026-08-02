# Threat modeling e severidade — decidir o que importa

Este arquivo é sobre **priorização**: modelar ameaça antes de existir código, classificar severidade
depois de achar o bug, e o processo em volta (SDLC, divulgação, incidente, conformidade). Os outros
arquivos da skill dizem *como uma falha funciona*; este diz *se vale a pena gastar tempo com ela*.
Abra-o quando precisar decidir onde investir esforço de segurança, pontuar um achado (CVSS, EPSS,
KEV), planejar segurança numa feature nova, responder "isso é crítico?", montar um processo de
divulgação/`security.txt`, ou reagir às primeiras horas de um incidente. Ele existe para impedir que
a skill vire só um catálogo de vulnerabilidades sem senso de proporção.

Para a mecânica de cada classe de falha, veja os arquivos irmãos: `owasp-top10.md`, `injecao.md`,
`xss-e-navegador.md`, `autenticacao-e-sessao.md`, `autorizacao-e-logica-de-negocio.md`,
`api-e-graphql.md`, `ssrf-e-camada-http.md`, `criptografia-e-segredos.md`, `mobile.md`. Para *como
ler código procurando bug* e o formato do achado, veja `revisao-de-codigo.md` — aqui cobrimos a
severidade e o processo em volta, não a leitura. Para SAST/DAST e pipeline, veja `ferramentas.md` e
`supply-chain-e-cicd.md`.

## Índice

- [Threat modeling que cabe numa sessão](#threat-modeling-que-cabe-numa-sessão)
- [Modelar o atacante](#modelar-o-atacante)
- [Severidade: CVSS com competência e ceticismo](#severidade-cvss-com-competência-e-ceticismo)
- [Vetores CVSS calculados passo a passo](#vetores-cvss-calculados-passo-a-passo)
- [Onde o CVSS erra e o que corrige](#onde-o-cvss-erra-e-o-que-corrige)
- [Priorizar correção quando não dá para corrigir tudo](#priorizar-correção-quando-não-dá-para-corrigir-tudo)
- [Segurança no ciclo de desenvolvimento](#segurança-no-ciclo-de-desenvolvimento)
- [Divulgação responsável e bug bounty](#divulgação-responsável-e-bug-bounty)
- [O lado legal: teste sem autorização é crime](#o-lado-legal-teste-sem-autorização-é-crime)
- [Resposta a incidente, no recorte do desenvolvedor](#resposta-a-incidente-no-recorte-do-desenvolvedor)
- [Conformidade no que afeta decisão técnica](#conformidade-no-que-afeta-decisão-técnica)
- [Métricas que valem a pena](#métricas-que-valem-a-pena)
- [Fontes](#fontes)

## Threat modeling que cabe numa sessão

Threat modeling não é um documento de 40 páginas nem um workshop de dois dias. Na prática que um time
consegue sustentar, são as **quatro perguntas de Adam Shostack**, respondidas em ordem, com um
diagrama feito no quadro branco. Elas funcionam porque não exigem cerimônia:

1. **O que estamos construindo?** — Desenhe o sistema. Sem diagrama, o resto vira adivinhação.
2. **O que pode dar errado?** — Enumere ameaças contra o diagrama. STRIDE é a mnemônica que
   estrutura isso.
3. **O que vamos fazer a respeito?** — Para cada ameaça: mitigar, eliminar, transferir, ou aceitar
   (documentado). "Aceitar" é uma resposta legítima; "ignorar" não é.
4. **Fizemos um bom trabalho?** — Revise. O diagrama cobre o que foi construído? As mitigações
   entraram no backlog com dono? Alguém validou?

O erro clássico é pular a pergunta 1 e ir direto para "quais ataques existem", produzindo uma lista
genérica que serve para qualquer sistema e por isso não serve para nenhum.

### O DFD rápido e a fronteira de confiança

Um **Data Flow Diagram (DFD)** de nível 1 tem cinco tipos de elemento, e só isso:

| Elemento | Notação | Exemplo |
|---|---|---|
| **Entidade externa** | retângulo | usuário no browser, app terceiro, gateway de pagamento |
| **Processo** | círculo | seu servidor API, um worker, uma Lambda |
| **Armazenamento (data store)** | duas linhas paralelas | Postgres, S3, Redis, fila |
| **Fluxo de dados** | seta rotulada | `POST /login {email,senha}`, `SELECT ... FROM users` |
| **Fronteira de confiança** | linha tracejada | borda internet↔servidor, servidor↔banco, app↔SO, tenant A↔tenant B |

A **fronteira de confiança** (*trust boundary*) é a única parte que não dá para pular. Toda
vulnerabilidade de verdade acontece quando dado cruza uma fronteira e é tratado com mais confiança do
que merece. SQL injection é dado do usuário cruzando a fronteira browser→servidor e virando sintaxe
no banco. SSRF é uma URL cruzando a fronteira servidor→rede-interna. IDOR é um identificador cruzando
sem que a autorização seja reavaliada do outro lado. Se você desenhou as fronteiras, você desenhou o
mapa dos ataques — cada seta que atravessa uma linha tracejada é um ponto onde perguntar "e se esse
dado for hostil?".

Onde as fronteiras costumam estar (e são esquecidas): entre dois microsserviços seus (um confia
cegamente no header `X-User-Id` que o outro mandou); entre seu código e uma biblioteca de terceiro;
entre o processo web e um job em background que lê da mesma fila; entre dois tenants no mesmo banco;
entre o cliente mobile e sua API (o cliente **não** é uma fronteira interna — veja `mobile.md`).

### STRIDE por elemento

STRIDE (Microsoft) dá seis categorias de ameaça. O truque é aplicá-la **por elemento** do DFD, não
ao sistema inteiro: para cada processo, fluxo e store, pergunte quais das seis letras se aplicam.
Cada letra é a violação de uma propriedade de segurança e tem uma família de controle correspondente:

| Letra | Ameaça | Propriedade violada | Exemplo web/mobile | Controle |
|---|---|---|---|---|
| **S** | *Spoofing* | Autenticidade | atacante se passa por outro usuário reusando token; app mobile aceita servidor sem validar cert | autenticação forte, MFA, cert pinning, mTLS entre serviços |
| **T** | *Tampering* | Integridade | manipular preço/`role` no request; alterar JWT com `alg:none`; modificar dado em trânsito | assinatura/HMAC, validação server-side, TLS, checagem de integridade |
| **R** | *Repudiation* | Não-repúdio | usuário nega ter feito transação; falta de log de quem aprovou o quê | log de auditoria assinado, trilha imutável, timestamps confiáveis |
| **I** | *Information Disclosure* | Confidencialidade | IDOR expõe dado de outro; stack trace vaza query; segredo em log | autorização por objeto, mascaramento, criptografia, controle de erro |
| **D** | *Denial of Service* | Disponibilidade | ReDoS, upload gigante, query sem limite, zip bomb | rate limit, quotas, timeouts, validação de tamanho, circuit breaker |
| **E** | *Elevation of Privilege* | Autorização | usuário comum chega a rota de admin; RCE por desserialização | checagem de autorização em todo endpoint, menor privilégio, sandbox |

Uma entidade externa normalmente sofre **S** e **R**; um data store sofre **T, I, D** (e **R** se
guarda logs); um processo sofre as seis; um fluxo de dados sofre **T, I, D**. Essa correspondência
(o "STRIDE-per-element" da Microsoft) evita a paralisia de olhar para uma letra que não faz sentido
naquele ponto.

### As outras metodologias, e por que STRIDE+DFD costuma bastar

- **PASTA** (*Process for Attack Simulation and Threat Analysis*) — sete estágios, orientado a risco
  de negócio e centrado no atacante. Bom quando você precisa amarrar ameaça técnica a impacto
  financeiro para um comitê. Pesado demais para uma feature.
- **LINDDUN** — o STRIDE da **privacidade**: *Linkability, Identifiability, Non-repudiation,
  Detectability, Disclosure of information, Unawareness, Non-compliance*. Use quando o risco central
  é dado pessoal e conformidade (LGPD/GDPR), não invasão. Complementa STRIDE, não substitui.
- **Attack trees** — a raiz é o objetivo do atacante ("roubar saldo"), os galhos são os caminhos.
  Ótimo para aprofundar **uma** ameaça já identificada; ruim para descobrir ameaças do zero.
- **Cyber Kill Chain** (Lockheed Martin) e **MITRE ATT&CK** — modelam as *fases* de uma intrusão
  (recon → weaponization → delivery → exploitation → C2 → ação). Servem para detecção e resposta
  (mapear onde seus controles pegam o atacante), não para modelar uma feature no design.

Para 90% das features de aplicação web/mobile, **DFD com fronteiras de confiança + STRIDE por
elemento** produz a lista de ameaças que importa em uma sessão. Chame PASTA/LINDDUN quando o contexto
específico (risco de negócio alto, privacidade crítica) justificar o custo.

### Feature vs. sistema, e o formato de 30 minutos

Modelar o **sistema inteiro** é um exercício grande, feito uma vez e revisado a cada mudança
arquitetural relevante. O que um time realmente faz toda semana é modelar **uma feature**, e o
formato que funciona é:

1. (5 min) Desenhe o DFD só da feature — o que entra, o que processa, onde persiste, quais fronteiras
   cruza.
2. (15 min) Rode STRIDE nas setas que cruzam fronteira. Anote cada ameaça em uma linha.
3. (10 min) Para cada ameaça: já existe controle? Falta? Vira ticket com dono. Aceita com
   justificativa registrada?

Faça isso no design, antes do código. O achado mais barato é o que nunca foi escrito. Um threat model
de feature que cabe em meia página vale mais que um documento perfeito que ninguém revisa.

**Ferramentas** (todas opcionais — quadro branco basta): **OWASP Threat Dragon** (web/desktop,
gratuito, desenha DFD e sugere STRIDE); **pytm** (threat model como código Python, integra em CI);
**Microsoft Threat Modeling Tool** (Windows, forte em STRIDE-per-element, gera relatório).

## Modelar o atacante

Antes de listar ameaças, defina **quem** ameaça esta aplicação — porque isso muda diretamente a
resposta de "vale a pena corrigir?". Uma falha explorável só por um estado-nação com acesso físico
importa menos, num app de e-commerce, que um IDOR que qualquer usuário logado dispara trocando um
número na URL.

Perfis de atacante e o que cada um muda:

- **Usuário autenticado curioso** — o mais subestimado e o mais real. Tem conta legítima e testa
  limites: troca IDs, edita o corpo do request, chama endpoints que a UI esconde. É por isso que
  IDOR e broken access control lideram bug bounty. Se seu app tem login, **este é seu atacante
  principal**.
- **Ex-funcionário** — conhece a arquitetura, pode ter token/chave que não foi revogada. Justifica
  rotação de credencial no offboarding e log de acesso.
- **Concorrente** — quer dados (preços, lista de clientes, catálogo) via scraping ou API exposta.
  Muda a prioridade de rate limit e de autorização em endpoints de leitura em massa.
- **Fraudador financeiro** — busca dinheiro direto: manipular preço, cupom, saldo, cashback,
  race condition em saque. É lógica de negócio, não injeção — veja `autorizacao-e-logica-de-negocio.md`.
- **Crime organizado** — automatiza fraude em escala (credential stuffing, carding, laranjas). Muda
  a prioridade de defesa anti-bot, MFA e detecção de anomalia.
- **Script kiddie com scanner** — roda Nuclei/Nessus/ZAP e explora o que achar automatizado. Pega
  CVE conhecido não corrigido e config default. Justifica manter dependências atualizadas e não
  expor painel/admin.
- **Insider** — funcionário atual com acesso legítimo abusando dele. Controle é menor privilégio,
  segregação de função e auditoria — prevenção pura não resolve.
- **Estado-nação** — recursos altos, 0-day, persistência. Só é modelo de ameaça realista para alvos
  específicos (infra crítica, governo, alvo político). Para a maioria dos apps, projetar contra ele é
  gastar orçamento no lugar errado.

**Ativos — o que o atacante quer**: dado (PII, credencial, cartão, propriedade intelectual);
dinheiro (transação, saldo, fraude de reembolso); computação (minerar cripto, virar proxy/botnet);
acesso (pivô para sistema mais valioso, movimento lateral); reputação (defacement, vazamento
constrangedor); disponibilidade (extorsão por DDoS, ransomware). Nomear o ativo por trás de cada
fluxo do DFD é o que transforma "isso é explorável?" em "isso vale ser explorado?".

**Suposições de confiança que costumam estar erradas** — cada uma já foi a causa-raiz de breaches
reais:

- "A rede interna é segura" — a base do modelo *zero trust* nascer. Um SSRF ou uma dependência
  comprometida põe o atacante lá dentro; serviços internos sem auth caem na hora.
- "O cliente mobile é nosso código, então confio nele" — o atacante controla o device, faz root,
  descompila o APK, intercepta o tráfego com Frida. Toda validação tem de ser server-side. Veja
  `mobile.md`.
- "O parceiro/gateway valida a entrada antes de mandar" — nunca assuma validação a montante. Valide
  na sua fronteira.
- "O admin é confiável" — insider e conta de admin comprometida são vetores reais; log e menor
  privilégio valem mesmo para admin.
- "O job em background não recebe input externo" — ele lê de uma fila/tabela que foi **alimentada**
  por input externo. O dado hostil chega assíncrono. Trate a fila como fronteira de confiança.

## Severidade: CVSS com competência e ceticismo

O **CVSS (Common Vulnerability Scoring System)**, mantido pelo **FIRST**, é o padrão de fato para
pontuar severidade técnica de 0.0 a 10.0. A versão vigente é a **v4.0**, publicada em
novembro de 2023 (documento de especificação revisado em 2024). Na prática, os feeds — NVD, avisos de
fornecedor, scanners — ainda estão majoritariamente em **v3.1**, então você precisa ler as duas. Saber
pontuar à mão é a única forma de auditar o número que um scanner cospe.

Faixas qualitativas (iguais em v3.1 e v4.0):

| Faixa | Rótulo |
|---|---|
| 0.0 | None |
| 0.1–3.9 | Low |
| 4.0–6.9 | Medium |
| 7.0–8.9 | High |
| 9.0–10.0 | Critical |

### Os quatro grupos de métricas da v4.0

**Base** (intrínseco, não muda com o tempo nem o ambiente) — é o que quase todo mundo reporta:

- **Exploitability**: `AV` Attack Vector (**N**etwork / **A**djacent / **L**ocal / **P**hysical),
  `AC` Attack Complexity (**L**ow / **H**igh), `AT` Attack Requirements (**N**one / **P**resent —
  *novo na v4*, separa "condições de execução exigidas" da complexidade), `PR` Privileges Required
  (**N**one / **L**ow / **H**igh), `UI` User Interaction (**N**one / **P**assive / **A**ctive — a v4
  desdobrou o antigo "Required" em passivo vs. ativo).
- **Vulnerable System Impact**: `VC`/`VI`/`VA` (Confidentiality/Integrity/Availability do sistema
  vulnerável — **H**/**L**/**N**).
- **Subsequent System Impact**: `SC`/`SI`/`SA` (impacto em sistemas *seguintes*, além do vulnerável —
  **H**/**L**/**N**). Isto **substituiu o Scope (S) da v3.1**: em vez do binário "changed/unchanged",
  a v4 modela explicitamente o impacto no que vem depois da fronteira.

**Threat** (muda com o tempo): `E` Exploit Maturity (**X** Not Defined / **A** Attacked / **P**
Proof-of-Concept / **U** Unreported). Substitui e simplifica os antigos Exploit Code Maturity /
Remediation Level / Report Confidence da v3.1.

**Environmental** (específico do *seu* ambiente): requisitos de segurança `CR`/`IR`/`AR` e overrides
das métricas base para o seu contexto — é onde você diz "aqui a disponibilidade importa mais que a
confidencialidade".

**Supplemental** (*novo na v4*, não altera o score — é contexto): `SAFETY`, `AUTOMATABLE`,
`RECOVERY`, `VALUE_DENSITY`, `VULNERABILITY_RESPONSE_EFFORT`, `PROVIDER_URGENCY`. Ajuda a decidir sem
mexer no número.

**Nomenclatura** (v4): `CVSS-B` = só Base; `CVSS-BT` = Base+Threat; `CVSS-BE` = Base+Environmental;
`CVSS-BTE` = tudo. Quando alguém diz "o CVSS é 7.5", quase sempre é `CVSS-B` puro — o menos útil para
decisão, porque ignora se está sendo explorado e o que vale no seu ambiente.

## Vetores CVSS calculados passo a passo

Pontuar é escolher cada métrica com justificativa. Abaixo, quatro achados típicos com o vetor v4.0
completo e o porquê de cada letra. (Os números finais dependem da calculadora oficial da FIRST — o
que importa aqui é o raciocínio da escolha, que é o que se aprende.)

### 1. IDOR autenticado que expõe dado de outro usuário

`GET /api/invoices/1042` retorna a fatura de qualquer ID; basta trocar o número. Precisa estar logado.

```
CVSS:4.0/AV:N/AC:L/AT:N/PR:L/UI:N/VC:H/VI:N/VA:N/SC:N/SI:N/SA:N
```

- `AV:N` — explorável pela internet (é uma API HTTP).
- `AC:L` — sem condição especial; incrementar um inteiro.
- `AT:N` — nenhum pré-requisito de execução.
- `PR:L` — precisa de conta comum (privilégio baixo). Se fosse acessível sem login seria `PR:N` e o
  score subiria.
- `UI:N` — nenhuma interação de vítima.
- `VC:H` — vaza dado sensível de qualquer usuário (confidencialidade alta). `VI:N`/`VA:N` — só lê,
  não altera nem derruba.
- `SC/SI/SA:N` — não há sistema seguinte impactado além do próprio app.

Isso pontua na faixa **Medium/High** dependendo da calculadora. Se o mesmo IDOR **alterasse** a
fatura, `VI:H` e o score sobe.

### 2. XSS armazenado num campo de perfil

O `nome` do usuário é renderizado sem escape; um `<script>` roda no browser de quem vê o perfil.

```
CVSS:4.0/AV:N/AC:L/AT:N/PR:L/UI:P/VC:L/VI:L/VA:N/SC:L/SI:L/SA:N
```

- `PR:L` — precisa de conta para salvar o payload. `UI:P` — a vítima só precisa **ver** a página
  (interação passiva), não clicar em nada; por isso `P` e não `N`.
- `VC:L/VI:L` — no contexto do app, o script pode ler/alterar dentro da sessão da vítima; "L" é
  conservador. Se roubar sessão de admin e permitir tomada de conta, justifica-se `H`.
- `SC:L/SI:L` — o browser da vítima é o "sistema seguinte" impactado. XSS que pivota para outro
  sistema (ex.: painel interno) sobe esses valores.

Note como a v4 modela XSS melhor que a v3.1: o impacto no browser da vítima cai naturalmente em
`SC/SI` (sistema subsequente), o que na v3.1 exigia o hack do `Scope:Changed`.

### 3. SSRF que alcança o metadata endpoint da cloud

O servidor busca uma URL fornecida pelo usuário sem validar destino; o atacante aponta para
`http://169.254.169.254/latest/meta-data/` e extrai credencial da instância. Veja `ssrf-e-camada-http.md`.

```
CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:L/VA:N/SC:H/SI:L/SA:N
```

- `PR:N` — se o endpoint que faz a requisição é acessível sem login. Frequentemente é (um preview de
  link, um webhook de importação).
- `VC:H` — vaza credencial da cloud, dado altamente sensível.
- `SC:H` — o **sistema seguinte** (a conta cloud inteira, via credencial roubada) é gravemente
  impactado. É exatamente para isso que serve o eixo Subsequent System: o dano real do SSRF não é no
  app, é no que a credencial destrava. `SI:L` reflete a possibilidade de agir com essa credencial.

Este é o caso onde a v4 é claramente superior: a distinção Vulnerable vs. Subsequent System captura
que "o bug está no app, mas a catástrofe é na cloud".

### 4. RCE por desserialização insegura

Endpoint aceita um objeto serializado (Java `ObjectInputStream`, `pickle` Python, `unserialize` PHP)
e uma cadeia de gadget conhecida leva a execução de comando. Veja `injecao.md` para a mecânica.

```
CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:H/VA:H/SC:H/SI:H/SA:H
```

Todos os impactos em `H`: RCE compromete confidencialidade, integridade e disponibilidade do sistema
vulnerável **e** do que estiver alcançável a partir dele. `PR:N/UI:N/AC:L` — se o endpoint é público e
o gadget é confiável, não há barreira. Isto pontua **Critical (9.0+)**. Adicione a métrica Threat
`E:A` (Attacked) se houver exploração ativa e o `CVSS-BT` confirma urgência máxima.

Esses quatro cobrem o espectro: um Medium autenticado, dois de impacto contido no cliente/app, e um
Critical de servidor. O padrão a internalizar: **`PR` e `UI` derrubam o score** (barreiras para o
atacante), **os seis impactos o levantam**, e **`SC/SI/SA` é onde SSRF e RCE mostram por que são
piores do que parecem no app**.

## Onde o CVSS erra e o que corrige

O CVSS mede o **pior caso técnico de uma vulnerabilidade isolada**. Ele não sabe nada do seu negócio.
Um `CVSS-B` de 6.5 ("Medium") numa falha de reset de senha de um app com 2 milhões de usuários pode
custar mais que um 8.1 ("High") numa ferramenta interna com 3 usuários atrás de VPN. Tratar o número
base como ordem de prioridade é o erro mais comum de programa de segurança imaturo. Correções:

### EPSS — probabilidade de exploração

O **EPSS (Exploit Prediction Scoring System)**, também da FIRST, estima a **probabilidade de uma CVE
ser explorada nos próximos 30 dias** (0 a 1 / 0% a 100%). A versão vigente é a **v4**, lançada em
17 de março de 2025, que monitora exploração real de mais de 10 mil vulnerabilidades por mês e agrega
telemetria de EDR, análise de malware e centenas de fontes. É o antídoto direto para o "corrigir tudo
que é high": a maioria das CVEs High **nunca** é explorada. Regra prática comum: uma CVE com EPSS
alto (ex.: > 0.1, i.e. > 10%) merece atenção mesmo com CVSS médio; um CVSS 9 com EPSS 0.001 pode
esperar. Estudos da FIRST mostram redução de mais de 8× no esforço de remediação quando se prioriza
por EPSS em vez de CVSS puro.

### CISA KEV — o que está sendo explorado agora

O **CISA Known Exploited Vulnerabilities (KEV) Catalog** lista CVEs com **exploração confirmada em
campo**. Se algo está no KEV, o debate de priorização acabou: corrija. É o sinal de maior confiança
que existe (não é predição como o EPSS — é fato observado). Para órgãos federais dos EUA o KEV vem com
prazo mandatório (BOD 22-01); para o resto, é a melhor lista de "pare tudo e olhe isso".

### SSVC — a árvore de decisão da CISA

O **SSVC (Stakeholder-Specific Vulnerability Categorization)**, do SEI/CMU com a CISA, é a alternativa
séria ao ranking por número. Em vez de um score, você percorre uma **árvore de decisão** e chega a uma
**ação**. A árvore da CISA usa cinco pontos de decisão:

1. **Exploitation** — *None / PoC / Active* (o KEV alimenta o "Active").
2. **Automatable** — o atacante consegue automatizar a cadeia (recon→exploração) de ponta a ponta?
   *Yes / No*.
3. **Technical Impact** — *Partial / Total*.
4. **Mission Prevalence** — quão essencial é o sistema afetado para a missão da organização.
5. **Public Well-being Impact** — dano potencial a pessoas (segurança física, financeira).

O resultado é uma de quatro decisões: **Track** (acompanhe, sem ação imediata), **Track\*** (acompanhe
de perto), **Attend** (traga para a supervisão, aja mais cedo), **Act** (aja já, prioridade alta). A
vantagem do SSVC é forçar a conversa certa — "isso é explorável de forma automatizada e o sistema é
crítico?" — em vez de discutir se o número é 7.3 ou 7.6.

### Risco = probabilidade × impacto, e o teatro da matriz de calor

O modelo mental mais simples continua válido: **risco = probabilidade × impacto**. EPSS/KEV informam a
probabilidade; o valor do ativo e o alcance informam o impacto. O cuidado é com a **matriz de calor**
(*heat map* vermelho/amarelo/verde 5×5): ela dá aparência de rigor a números inventados. "Probabilidade
3, impacto 4" quase sempre é chute com verniz. Se a matriz não é alimentada por dados reais (EPSS,
histórico de incidente, valor do ativo), ela é teatro — serve para reunião, não para decisão.

### A escala interna simples que ganha do CVSS puro

Na prática, uma escala interna de quatro níveis com **SLA de correção** costuma bater CVSS puro:

| Nível | Critério (exemplo) | SLA |
|---|---|---|
| **Crítico** | RCE, auth bypass, dado sensível em massa, no KEV, exposto na internet | 24–72h |
| **Alto** | IDOR/XSS explorável, escalada de privilégio, exposto e autenticado | 7 dias |
| **Médio** | requer condição rara, impacto limitado, só interno | 30 dias |
| **Baixo** | teórico, defense-in-depth, sem impacto direto | 90 dias / backlog |

Funciona porque combina CVSS **com** alcançabilidade, exposição e valor do ativo — que é o que o CVSS
base não vê — e amarra a um prazo com dono. O número CVSS é insumo, não veredicto.

## Priorizar correção quando não dá para corrigir tudo

Nenhum time corrige tudo. A ordem se decide por seis fatores, nesta lógica:

- **Alcançabilidade real** — o código vulnerável está num caminho executável com input controlável?
  Uma CVE numa dependência que você importa mas nunca chama na função afetada é *reachable = no*.
  Ferramentas de SCA modernas fazem *reachability analysis*; isso corta a maior parte do ruído. Veja
  `supply-chain-e-cicd.md`.
- **Exploit público existe?** — Metasploit/exploit-db/PoC no GitHub muda tudo. Sem exploit, o custo do
  atacante é alto; com exploit em uma linha, qualquer script kiddie roda.
- **Exposição** — internet > autenticado > interno atrás de VPN/mTLS. Um bug idêntico muda de
  prioridade só pela superfície onde vive.
- **Dado afetado** — PII/cartão/credencial/segredo > dado público. Amarra a impacto e a conformidade
  (LGPD, PCI).
- **Esforço da correção** — um one-liner de baixo risco pode ir na frente de algo mais grave porém
  arriscado de mexer, se libera capacidade. Não é a regra, mas conta.
- **Mitigação temporária** — nem toda resposta é "corrigir o código agora". Bloquear via **WAF**,
  desligar por **feature flag**, ou **desativar o endpoint** são decisões legítimas **quando
  registradas** com prazo para a correção real. WAF como *permanente* é dívida disfarçada; como
  ponte de 2 semanas até o deploy, é engenharia responsável. O que não vale é mitigar e esquecer.

**Dívida de segurança**: achados aceitos/adiados viram dívida. Ela vira backlog eterno quando não tem
(a) dono, (b) prazo, (c) revisão periódica. Trate cada aceite de risco como um item com data de
reavaliação; sem isso, "aceito por ora" vira "esquecido para sempre" — e é exatamente o achado
esquecido que aparece no relatório de breach.

## Segurança no ciclo de desenvolvimento

Segurança barata é segurança cedo. Onde cada atividade entra:

| Fase | Atividade | Custo se pular |
|---|---|---|
| **Design** | threat model da feature (as 4 perguntas) | falha de arquitetura, cara de refazer |
| **História/backlog** | requisito de segurança + abuse case | controle esquecido vira achado no pentest |
| **Codificação** | linters de segurança, secrets scanning no commit | segredo no histórico do git |
| **Pull request** | SAST no PR, revisão de segurança (`revisao-de-codigo.md`) | bug entra no main |
| **CI** | SCA (dependências), DAST em staging, testes de segurança automatizados | regressão silenciosa |
| **Pré-go-live** | pentest de features de alto risco | vai para produção com falha crítica |
| **Produção** | bug bounty, monitoramento, resposta a incidente | descoberta pelo atacante primeiro |

O princípio geral é *shift-left*, com ressalva: shift-left sem shift-right (bounty, monitoração)
deixa buraco. As duas pontas se complementam.

### Frameworks para estruturar isso

- **OWASP SAMM (Software Assurance Maturity Model)**, versão **2.x** (a linha atual é a 2.0.x, com a
  2.1 em evolução) — mede maturidade em 5 funções de negócio (Governance, Design, Implementation,
  Verification, Operations), cada uma com práticas em 3 níveis. Use como **autoavaliação**: onde
  estamos, para onde ir. É prescritivo o suficiente para virar roadmap sem ser burocracia.
- **NIST SSDF — SP 800-218 (Secure Software Development Framework)** — quatro grupos de práticas:
  **PO** (Prepare the Organization), **PS** (Protect the Software), **PW** (Produce Well-Secured
  Software), **RV** (Respond to Vulnerabilities). É a referência que contratos federais dos EUA e
  a Executive Order 14028 exigem; útil como checklist de "temos processo para X?". Mais leve de citar
  que de implementar por inteiro — pegue as práticas PW (as de codificação) primeiro.

### ASVS como fonte de requisito verificável

O **OWASP ASVS (Application Security Verification Standard)** é a lista de requisitos de segurança
*verificáveis*. A versão vigente é a **5.0**, lançada em 30 de maio de 2025 (a revisão mais
substancial da história do padrão) — reestruturada, com melhor suporte a automação e arquiteturas
cloud-native. O ASVS organiza requisitos por capítulo (autenticação, controle de acesso, validação,
criptografia, etc.), e a forma prática de usá-lo é: **pegue o capítulo relevante à sua feature e use
os itens como critério de aceite**. Fazendo uma feature de login? O capítulo de autenticação do ASVS
vira a definition-of-done de segurança daquela história — cada requisito ("a aplicação bloqueia
tentativas repetidas de login", "sessão expira após inatividade") é um teste que passa ou falha. Isso
transforma "seja seguro" (impossível de verificar) em uma lista objetiva.

### Security champion e por que revisão centralizada não escala

Um time de segurança central não consegue revisar todo PR de toda squad — vira gargalo e a segurança
passa a ser vista como o setor do "não". O modelo que escala é o **security champion**: um dev *dentro*
de cada squad que recebe treinamento extra, é o primeiro filtro de segurança, e faz a ponte com o time
central. A segurança vira responsabilidade distribuída; o time central vira consultoria e ferramenta,
não portão. Revisão centralizada continua para o que é crítico (design de auth, cripto), mas o volume
do dia a dia fica na squad.

### Abuse case junto com a história funcional

Para cada história funcional, escreva o **abuse case** — o mesmo formato, ponto de vista do atacante:

> **História**: Como usuário, quero redefinir minha senha por e-mail.
>
> **Abuse case**: Como atacante, quero **enumerar contas** pela mensagem de "e-mail não encontrado";
> quero **reusar o token de reset**; quero **forçar bruta** o token de 6 dígitos; quero **envenenar o
> header Host** para o link apontar para meu domínio.

Cada abuse case vira um critério de aceite ("a resposta é idêntica para e-mail existente e
inexistente", "o token expira em 15 min e é de uso único", "há rate limit no envio"). É threat modeling
na granularidade da história, e cabe na mesma cerimônia de refinamento.

## Divulgação responsável e bug bounty

Quando alguém de fora acha um bug no seu sistema, você precisa de um canal e uma política — senão o
pesquisador desiste (e o próximo achador pode não ser tão amigável).

### security.txt (RFC 9116)

Publique um arquivo em **`/.well-known/security.txt`** (o local canônico; `/security.txt` na raiz é
fallback). Definido pela **RFC 9116**. Só dois campos são **obrigatórios**:

- **`Contact:`** — como reportar. Ao menos um `mailto:`, `https:` ou `tel:` URI. Pode repetir.
- **`Expires:`** — data ISO 8601 depois da qual o arquivo é considerado obsoleto. Force revisão.

Campos recomendados: `Encryption:` (chave PGP), `Policy:` (link para a política de divulgação),
`Acknowledgments:` (hall da fama), `Preferred-Languages:` (ex.: `pt, en`), `Canonical:` (URL canônica
do próprio arquivo). Para produção, o arquivo deve ser assinado com PGP (`Signature`). Exemplo:

```
Contact: mailto:security@exemplo.com.br
Contact: https://exemplo.com.br/security
Expires: 2027-01-01T00:00:00.000Z
Preferred-Languages: pt, en
Policy: https://exemplo.com.br/security-policy
Canonical: https://exemplo.com.br/.well-known/security.txt
```

### Política e prazos

A **Coordinated Vulnerability Disclosure (CVD)** é o modelo padrão: o pesquisador reporta em privado,
você corrige, e a divulgação pública acontece de forma coordenada. O prazo mais citado é **90 dias**
(o padrão do Google Project Zero) — tempo para corrigir antes da divulgação. Variações: +14 dias de
carência se um patch está a caminho; divulgação imediata (0-day) se já há exploração ativa; prazos mais
curtos (7 dias) para algo já sendo explorado. Ter a política escrita evita atrito: diz ao pesquisador o
que esperar e o que você espera dele.

### Solicitar CVE

Se a falha é em software que **você** publica (biblioteca, produto), atribua um **CVE** para que
consumidores rastreiem. O ID vem de uma **CNA (CVE Numbering Authority)** — grandes fornecedores são
CNAs próprios; para o resto, o **MITRE** age como CNA de última instância (formulário no cve.org).
Quando o achado é em software de **terceiro**, você não atribui CVE — você **reporta ao mantenedor** via
o canal de segurança dele (o `security.txt` dele, um programa de bounty, ou a CNA do projeto), e ele
coordena o CVE. A diferença prática: no seu software você controla o cronograma de correção e
divulgação; no de terceiro você depende dele, e o prazo de 90 dias é sua alavanca.

### Bug bounty

Um programa de recompensa (HackerOne, Bugcrowd, Intigriti, ou self-hosted) formaliza a relação com
pesquisadores. Elementos que definem se funciona:

- **Escopo** — o que está dentro (domínios, apps) e explicitamente fora (subdomínios de terceiros,
  DoS, engenharia social, ambientes de teste de outros clientes). Escopo mal definido gera briga.
- **Safe harbor** — a cláusula que promete não processar quem testa **dentro das regras**. Sem ela,
  pesquisador sério não participa (veja a seção legal abaixo). É o item mais importante do documento.
- **Triagem** — validar, reproduzir, classificar severidade, deduplicar. É trabalho real; muitos
  programas terceirizam a triagem para a plataforma.
- **Duplicata** — o primeiro a reportar leva; os seguintes são marcados como duplicata (sem
  recompensa). Transparência no timestamp evita ressentimento.

## O lado legal: teste sem autorização é crime

Isto vale para o pesquisador e para você. **Testar segurança de um sistema sem autorização é crime**,
não "pesquisa". A skill inteira é para **defesa, revisão de código próprio e teste autorizado**.

### Brasil

- **Lei 12.737/2012** (*Lei Carolina Dieckmann*), de 30 de novembro de 2012, tipificou os crimes
  informáticos e **inseriu o art. 154-A no Código Penal**.
- **Art. 154-A do Código Penal** — *"Invadir dispositivo informático de uso alheio, conectado ou não à
  rede de computadores, com o fim de obter, adulterar ou destruir dados ou informações sem autorização
  expressa ou tácita do usuário do dispositivo ou de instalar vulnerabilidades para obter vantagem
  ilícita"*. A redação atual (após a **Lei 14.155/2021**) prevê **pena de reclusão de 1 a 4 anos e
  multa** — a 14.155 aumentou a pena original (que era detenção de 3 meses a 1 ano) e removeu o antigo
  requisito de "violação indevida de mecanismo de segurança" do núcleo. **§ 2º**: pena aumenta de 1/3 a
  2/3 se resulta prejuízo econômico. **§ 3º**: reclusão de 2 a 5 anos se resulta obtenção de
  comunicações privadas, segredos comerciais/industriais, informações sigilosas ou **controle remoto**
  não autorizado do dispositivo.
- **LGPD (Lei 13.709/2018)** entra em cena sempre que há **dado pessoal** envolvido no teste ou no
  incidente — tratar dado sem base legal é ilícito administrativo com multa, independentemente do
  crime penal.
- Conclusão prática: você só testa o que é seu, ou o que tem **autorização escrita** (contrato de
  pentest, escopo de bounty com safe harbor). "Só olhei" não é defesa.

### Estados Unidos

- **CFAA (Computer Fraud and Abuse Act)** — a lei federal que criminaliza acesso "não autorizado" ou
  "que excede autorização". Historicamente vaga e usada de forma agressiva; *Van Buren v. United
  States* (2021) estreitou o "exceeds authorized access". Ainda assim, testar sem permissão é risco
  criminal real.
- O **safe harbor** de um programa de bug bounty é o que converte um teste potencialmente ilegal em
  autorizado — por isso a cláusula importa tanto. O DOJ, desde 2022, orienta não processar pesquisa de
  segurança de boa-fé, mas isso é política, não imunidade.

Antes de afirmar qualquer coisa jurídica num achado, **verifique o texto vigente** — leis mudam
(a 14.155 alterou a 12.737 nove anos depois). Os links estão nas Fontes.

## Resposta a incidente, no recorte do desenvolvedor

Quando a exploração é ativa, o desenvolvedor entra no ciclo. A referência é o **NIST SP 800-61
Revisão 3** (abril de 2025), que reformulou o guia clássico e o mapeou às seis funções do NIST CSF 2.0
(Govern, Identify, Protect, Detect, Respond, Recover). O ciclo tradicional em fases continua o modelo
mental útil:

1. **Preparação** — antes do incidente: runbook, contatos, acesso de emergência, logs centralizados e
   *retidos*, backup testado. Sem preparação, as outras fases improvisam.
2. **Detecção e análise** — identificar que há um incidente e seu escopo. É onde log de qualidade
   paga.
3. **Contenção** — parar a hemorragia sem destruir a evidência (ver abaixo).
4. **Erradicação** — remover a causa (fechar a falha, remover o acesso do atacante, o backdoor).
5. **Recuperação** — restaurar operação limpa, monitorando reincidência.
6. **Lições aprendidas (post-mortem)** — o que falhou no processo, não em quem.

### As primeiras horas

Ao descobrir exploração ativa:

- **Não reinicie nem "limpe" a máquina por instinto.** Reiniciar apaga memória, processos, conexões
  ativas, `/tmp` — exatamente a evidência de como o atacante entrou e o que fez. O impulso de "resolver
  reinstalando" destrói a investigação e você fica sem saber o escopo (e volta a ser invadido pela mesma
  porta).
- **Preserve evidência**: snapshot do disco/volume, dump de memória se possível, cópia dos logs
  *antes* que rotacionem, lista de processos e conexões. Trabalhe em cópias.
- **Contenha isolando, não apagando**: tire a instância da rede (security group / firewall), revogue
  a sessão, mas mantenha o estado para análise. Isolar ≠ destruir.
- **Ordem de revogação de credencial**: primeiro as de maior privilégio e maior alcance — chaves de
  cloud (IAM) e credenciais de serviço/CI (podem estar sendo usadas para pivô), depois tokens de
  admin, depois sessões de usuário. Rode rotação assumindo que **tudo que a máquina comprometida podia
  ler vazou** (variáveis de ambiente, arquivos de config, tokens montados).

### Escopo do comprometimento pelo log

Determinar até onde o atacante chegou é trabalho de log: correlacione o horário do primeiro indício
com logs de acesso (o IP/UA do atacante), de aplicação (quais endpoints, quais IDs acessados), de
banco (queries anômalas, dumps), de auth (logins, criação de conta, escalada). Procure a **primeira**
ocorrência do padrão hostil — é o marco do comprometimento; tudo depois é suspeito. Log ausente ou de
retenção curta é o que transforma "sabemos o que aconteceu" em "não fazemos ideia" — por isso retenção
de log é decisão de segurança, não só de observabilidade.

### Comunicação e prazos legais

- **Interna**: quem precisa saber (jurídico, liderança, comms), cedo.
- **Clientes**: transparência tempestiva — atraso vira dano de reputação maior que o incidente.
- **ANPD (LGPD)**: pela **Resolução CD/ANPD nº 15/2024** (Regulamento de Comunicação de Incidente de
  Segurança), quando o incidente afeta dado pessoal e pode acarretar risco/dano relevante ao titular,
  a comunicação à ANPD **e** aos titulares deve ser feita em **até 3 dias úteis** contados do
  conhecimento pelo controlador de que o incidente afetou dados pessoais, via formulário eletrônico da
  ANPD. Informações podem ser complementadas em até 20 dias úteis. O registro do incidente (mesmo os
  não comunicados) deve ser mantido por no mínimo 5 anos. Confirme o texto vigente antes de agir — o
  prazo mudou com a Resolução 15/2024 (antes era "prazo razoável").

### Post-mortem sem culpa

O post-mortem *blameless* pergunta "que condições do sistema permitiram isso?", não "quem errou?".
Pessoas que temem punição escondem informação, e você perde o aprendizado. Cada incidente gera itens
de ação concretos com dono e prazo — e, idealmente, **um teste automatizado que reproduziria a falha**
(a métrica de ouro da próxima seção).

## Conformidade no que afeta decisão técnica

Conformidade **não é segurança** — um sistema pode passar em auditoria e ser inseguro, e vice-versa.
Mas ela **força prazo e orçamento** que a segurança sozinha não consegue arrancar da diretoria. Saber
usar isso é habilidade prática. O que afeta decisão técnica de fato:

- **LGPD (Lei 13.709/2018)** — o que muda no código: você precisa de **base legal** para cada
  tratamento (consentimento, execução de contrato, legítimo interesse, etc. — 10 bases no art. 7º);
  **dado pessoal sensível** (origem racial, saúde, biometria, orientação sexual, etc.) tem regras mais
  estritas; o titular tem **direitos** (acesso, correção, portabilidade, eliminação) que viram
  *endpoints* reais no seu sistema; **DPO/encarregado** é obrigatório; **transferência internacional**
  tem requisitos. Na arquitetura: minimização (não colete o que não usa), pseudonimização, e o direito
  de eliminação obrigam a saber *onde* cada dado pessoal vive.
- **GDPR** (UE) — o parente da LGPD; diferenças que importam para quem atende a Europa: multas maiores
  (até 4% do faturamento global), prazo de notificação de breach de **72 horas** à autoridade, e
  exigências de DPO e DPIA mais formais. Se você tem usuário na UE, o GDPR se aplica extraterritorialmente.
- **PCI-DSS v4.x** (atual **v4.0.1**, com os 51 requisitos "future-dated" **obrigatórios desde 31 de
  março de 2025** — em 2026 não há versão anterior válida) — se você processa/transmite/armazena dado
  de cartão, os 12 requisitos se aplicam ao seu *ambiente de dados do titular (CDE)*. A decisão de
  arquitetura que evita quase tudo: **não armazenar o PAN**. Use tokenização e um provedor
  (Stripe/Adyen/etc.) que assume o CDE — o cartão nunca toca seu servidor, e seu escopo PCI encolhe de
  "auditoria completa" para "SAQ A". "Não guardar o número do cartão" é a única decisão de PCI que a
  maioria dos apps precisa acertar.
- **SOC 2** — relatório de auditoria (Type I = ponto no tempo; Type II = período) sobre controles de
  segurança/disponibilidade/confidencialidade. Não é lei, é exigência **comercial** (clientes B2B
  pedem antes de assinar). Afeta o time obrigando log, controle de acesso e change management
  documentados.
- **ISO 27001** — norma internacional de sistema de gestão de segurança da informação (ISMS).
  Certificação organizacional; afeta o dev via políticas e o Anexo A de controles.
- **HIPAA** (EUA, saúde) — protege dados de saúde (PHI); se você toca prontuário de paciente americano,
  exige criptografia, controle de acesso e trilha de auditoria específicos.

O ponto central: quando um requisito de segurança "não tem prioridade", amarrá-lo a uma obrigação de
conformidade (LGPD, PCI, contrato SOC 2) é o que consegue o orçamento. Conformidade é a alavanca
política da segurança.

## Métricas que valem a pena

Meça para melhorar decisão, não para gerar slide. As que ajudam e as que enganam:

- **Tempo médio de correção por severidade** (aderência ao SLA) — a métrica mais acionável: seus
  críticos fecham no prazo? Se não, o problema é capacidade ou priorização, e o número mostra qual.
- **Cobertura de threat model** — % de features novas que passaram por threat model no design.
  Preventiva; mede se o processo mais barato está acontecendo.
- **Taxa de escape para produção** — achados que chegaram à produção vs. pegos antes (no PR, no CI, no
  pentest). Subindo = seus controles à esquerda estão furando.
- **MTTD / MTTR** (mean time to detect / to respond) — quanto tempo entre comprometimento e detecção,
  e entre detecção e contenção. Mede a maturidade de resposta; log ruim explode o MTTD.
- **Proporção de achados que viram teste automatizado** — **a que mais importa na prática**. Um bug
  corrigido sem teste volta. Um bug que virou teste de regressão nunca mais é o mesmo bug. Essa razão
  mede se você está *aprendendo* com os achados ou só apagando incêndio repetidamente.

E a métrica que **engana**: **densidade de achados por KLOC** (bugs por mil linhas). Parece científica
e é ruim — pune quem procura mais (mais achados = "pior", incentivo perverso), depende de quanto
esforço de teste foi aplicado (não da qualidade real), e KLOC é péssima medida de tamanho. Contagem
bruta de vulnerabilidades tem o mesmo defeito: cai quando você para de olhar. Prefira métricas de
*fluxo* (tempo de correção, taxa de escape) e de *aprendizado* (achado→teste) sobre métricas de
*estoque* (quantos bugs existem).

## Fontes

- Shostack, *Threat Modeling: Designing for Security* — as 4 perguntas e STRIDE-per-element. Resumo em
  OWASP: <https://cheatsheetseries.owasp.org/cheatsheets/Threat_Modeling_Cheat_Sheet.html>
- OWASP Threat Modeling Process: <https://owasp.org/www-community/Threat_Modeling_Process>
- STRIDE (Microsoft): <https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats>
- OWASP Threat Dragon: <https://owasp.org/www-project-threat-dragon/> · pytm: <https://github.com/OWASP/pytm>
- LINDDUN (privacidade): <https://linddun.org/>
- CVSS v4.0 — spec da FIRST: <https://www.first.org/cvss/v4.0/specification-document> · calculadora:
  <https://www.first.org/cvss/calculator/4.0> · user guide: <https://www.first.org/cvss/v4.0/user-guide>
- EPSS (v4, mar/2025): <https://www.first.org/epss/> · modelo: <https://www.first.org/epss/model>
- CISA KEV: <https://www.cisa.gov/known-exploited-vulnerabilities-catalog>
- CISA SSVC: <https://www.cisa.gov/stakeholder-specific-vulnerability-categorization-ssvc> · calculadora:
  <https://www.cisa.gov/ssvc-calculator>
- OWASP ASVS 5.0 (mai/2025): <https://owasp.org/www-project-application-security-verification-standard/>
  · <https://github.com/OWASP/ASVS>
- OWASP SAMM: <https://owaspsamm.org/> · OWASP Top 10:2025: <https://owasp.org/Top10/>
- NIST SSDF SP 800-218: <https://csrc.nist.gov/pubs/sp/800/218/final>
- NIST SP 800-61 Rev. 3 (abr/2025): <https://csrc.nist.gov/pubs/sp/800/61/r3/final>
- RFC 9116 (security.txt): <https://www.rfc-editor.org/rfc/rfc9116> · <https://securitytxt.org/>
- Google Project Zero (política de 90 dias): <https://googleprojectzero.blogspot.com/p/vulnerability-disclosure-policy.html>
- CVE / CNA (MITRE): <https://www.cve.org/> · <https://www.cve.org/ProgramOrganization/CNAs>
- Lei 12.737/2012 (Carolina Dieckmann): <https://www.planalto.gov.br/ccivil_03/_ato2011-2014/2012/lei/l12737.htm>
- Lei 14.155/2021 (alterou o art. 154-A): <https://www.planalto.gov.br/ccivil_03/_ato2019-2022/2021/lei/l14155.htm>
- Código Penal, art. 154-A: <https://www.planalto.gov.br/ccivil_03/decreto-lei/del2848compilado.htm>
- LGPD (Lei 13.709/2018): <https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm>
- Resolução CD/ANPD nº 15/2024 (comunicação de incidente): <https://www.gov.br/anpd/pt-br>
- CFAA (18 U.S.C. § 1030): <https://www.law.cornell.edu/uscode/text/18/1030>
- PCI-DSS v4.0.1: <https://www.pcisecuritystandards.org/document_library/>
