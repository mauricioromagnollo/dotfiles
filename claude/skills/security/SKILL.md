---
name: security
description: Especialista em segurança de aplicações web e mobile — encontrar, explicar e corrigir vulnerabilidades reais. Cobre injeção (SQL, comando, template, desserialização, prototype pollution), XSS/CSP/CSRF/CORS, quebra de controle de acesso e IDOR, falhas de lógica de negócio e race conditions, autenticação, sessão, JWT e OAuth, SSRF e camada HTTP, upload e path traversal, criptografia e segredos, API e GraphQL, mobile (Android, iOS, React Native), cadeia de suprimentos e CI/CD, e aplicações com LLM. Use ao revisar código ou PR com olhar de segurança, ao projetar login, permissão ou multi-tenancy, ao tratar dado sensível, dinheiro ou upload, e ao responder a achado de scanner, pentest ou bug bounty. Dispare em pedidos como "isso é seguro?", "revisa a segurança disso", "tem vulnerabilidade aqui?", "como protejo esse endpoint", "onde guardo esse token", "esse JWT tá certo?", "isso dá SQL injection?", "posso confiar nesse input", "como valido esse upload", "meu npm audit acusou isso", "preciso de CSRF aqui?", "como faço multi-tenant sem vazar dado de outro cliente", "o pentest achou X", "isso atende a LGPD?", "como testo se isso é explorável" — mesmo que segurança, OWASP ou vulnerabilidade não sejam citados pelo nome. Dispare também, sem ser pedido, ao escrever ou revisar código que toca login, permissão, pagamento, upload, integração com terceiro, ou qualquer input de usuário que chegue a banco, shell, filesystem ou HTML. Também para argumentar que algo NÃO é vulnerabilidade e evitar falso positivo.
---

# Segurança de aplicações

Revisão de segurança não é revisão de código com mais atenção. É uma pergunta diferente.

Revisão comum pergunta *"isso funciona?"* — e o teste dessa pergunta é o usuário fazendo o que se
espera dele. Segurança pergunta *"o que isso assume, e quem consegue quebrar essa suposição?"* — e o
teste é alguém fazendo exatamente o que ninguém imaginou. Por isso um código pode passar em toda a
suíte, atender ao requisito e ainda assim entregar a base de dados: os testes exercitam o caminho
previsto, e a vulnerabilidade mora nos caminhos que ninguém escreveu.

Disso decorre o método inteiro desta skill: **você não procura código feio, procura confiança
depositada onde não deveria.** Confiança em um ID que veio do cliente, em um header que um proxy
podia ter forjado, em uma validação que roda no navegador, em uma ordem de execução que o atacante
controla, em uma biblioteca que alguém publicou ontem.

E há uma segunda assimetria que decide se o seu trabalho vai servir: **falso positivo custa mais
caro do que parece.** Cinco achados inventados no meio de dois reais fazem o time descartar a lista
inteira — e, na próxima vez, ignorar o aviso que importava. Nesta skill, dizer "isso aqui parece
ruim mas não é explorável, e aqui está por quê" vale tanto quanto encontrar a falha.

## Como usar esta skill

São ~15.000 linhas de referência. **Não leia tudo** — decida nesta tabela e abra uma, no máximo duas.

E não leia o arquivo inteiro: cada um começa com um índice justamente para você localizar a seção e
ler só ela. Um arquivo destes tem 700 a 1.600 linhas; carregar tudo para responder sobre `AsyncStorage`
gasta contexto que faz falta para ler o código do usuário — que é onde a resposta de fato está. Se a
pergunta for factual e pontual (qual parâmetro, qual versão, qual header), `grep` na referência é
melhor que leitura sequencial.

| Referência | Quando abrir |
|---|---|
| `references/owasp-top10.md` | Mapa de navegação: Top 10:2025 e a tradução da numeração de 2021, as outras listas (API, Mobile, LLM, CI/CD), ASVS/WSTG/MASVS/Cheat Sheets, e a **tabela sintoma → categoria → arquivo**. Comece por aqui quando não souber onde o problema se encaixa |
| `references/autorizacao-e-logica-de-negocio.md` | IDOR/BOLA, escalada horizontal e vertical, mass assignment, multi-tenancy e RLS, race conditions, preço/cupom/saldo, RBAC vs ABAC vs ReBAC. **A referência de maior retorno** — veja "onde olhar primeiro" abaixo |
| `references/injecao.md` | Dado do atacante virando sintaxe: SQL e NoSQL, comando e argument injection, SSTI, `eval`, XXE, desserialização, prototype pollution, LDAP/XPath/CSV, ReDoS |
| `references/xss-e-navegador.md` | Tudo do lado do cliente: XSS por contexto, sanitização, CSP, headers de segurança, CSRF, CORS, clickjacking, `postMessage`, DOM clobbering |
| `references/autenticacao-e-sessao.md` | "Quem é o usuário": hash de senha, credential stuffing, MFA e passkeys, cookies e sessão, **JWT**, OAuth 2.0/OIDC, SAML, reset de senha, API key |
| `references/api-e-graphql.md` | API Security Top 10, validação de entrada, rate limiting e consumo de recurso, webhooks (receber e enviar), GraphQL (complexidade, autorização por resolver, batching), gRPC, WebSocket |
| `references/ssrf-e-camada-http.md` | Servidor como cliente e a infraestrutura no meio: SSRF, request smuggling, cache poisoning e deception, host header, path traversal, upload de arquivo, open redirect, `X-Forwarded-For` |
| `references/criptografia-e-segredos.md` | Cifra e AEAD, aleatoriedade, assinatura, TLS, **gestão de segredos e resposta a vazamento**, dado sensível em log, LGPD |
| `references/mobile.md` | Android e iOS, MASVS/MASTG, armazenamento local, pinning, componentes exportados e deep links, WebView, React Native e Flutter, attestation, e como testar um app |
| `references/supply-chain-e-cicd.md` | Dependências (dependency confusion, `postinstall`, typosquatting), SBOM e proveniência, **GitHub Actions** (`pull_request_target`, script injection, OIDC), containers, Kubernetes, IaC |
| `references/llm-e-ia.md` | Aplicações com LLM: prompt injection direta e indireta, RAG e autorização no retrieval, agentes e a tríade letal, MCP e tool poisoning, saída do modelo como input inseguro |
| `references/revisao-de-codigo.md` | **A metodologia**: como conduzir a revisão, mapa de sinks e defaults por linguagem/framework (Node, Go, Python, Java, PHP, Rails, .NET), como escrever o achado, como calibrar |
| `references/ferramentas.md` | O que rodar e com qual comando: Semgrep, gitleaks, osv-scanner, trivy, ZAP, nuclei, Burp, MobSF, Frida — e o que cada uma **não** encontra |
| `references/threat-modeling-e-severidade.md` | Antes do código (STRIDE, DFD, abuse case) e depois do achado (CVSS v4, EPSS, KEV, SSVC), divulgação responsável, resposta a incidente, LGPD e PCI |

Skills vizinhas, quando o assunto sair de segurança: `nodejs` e `golang` para a linguagem, `dba` para
banco (schema, índice, transação, RLS), `sre` para pipeline e infraestrutura, `craft` para estrutura
de código, `ui-ux` quando a correção mexe na experiência (fluxo de MFA, mensagem de erro).

## O fluxo

### 1. Estabeleça o alvo — e, se houver rede no meio, a autorização

Ler código de um repositório local, rodar SAST, escanear dependência e revisar um diff: tudo isso é
leitura de arquivo, faça à vontade. **Mandar tráfego para um host é outra categoria.** Antes de
qualquer scanner, fuzzer ou `curl` contra um alvo, estabeleça de quem é o sistema e se há
autorização. Ambiente local e staging do próprio usuário: siga. Domínio de terceiro, produção de
cliente, "um site que eu achei": pergunte antes, e não contorne a ausência de resposta.

Isso não é formalidade. Testar sem autorização é crime no Brasil (art. 154-A do Código Penal) e o
custo recai sobre o usuário, não sobre você.

### 2. Entenda o sistema antes de julgar uma linha

O erro mais comum de revisor assistido por modelo é abrir um arquivo, ver `req.params.id` indo para
uma query e declarar IDOR — quando o repositório inteiro passa por um middleware que injeta o escopo
do tenant. O oposto também acontece: o middleware existe, mas não cobre aquela rota, e só quem olhou
a configuração de rotas percebe.

Então, antes de acusar: **identifique onde estão os controles.** Onde autentica, onde autoriza, onde
valida, quem fala com o banco. Depois procure o que escapa deles. A heurística que mais rende:
*onde o controle é opt-in em vez de opt-out, existe um lugar onde esqueceram de optar.* Uma rota sem
o decorator, um repositório chamado direto sem passar pelo serviço, um job que roda fora do contexto
da requisição.

`references/revisao-de-codigo.md` tem essa sequência com os comandos concretos.

### 3. Siga o dado, não o palpite

Uma vulnerabilidade é um **caminho**: de uma entrada que o atacante controla até um efeito que ele
não deveria conseguir. Se você não consegue descrever esse caminho em passos, você tem uma suspeita,
não um achado.

Trabalhe nos dois sentidos e encontre-se no meio:

- **Da entrada para frente** (*"quem manda isso, e até onde chega?"*): parâmetro de rota, body,
  query, header, cookie, upload, mensagem de fila, webhook, resposta de API de terceiro, conteúdo
  de arquivo, saída de LLM.
- **Do sink para trás** (*"o que chega aqui é confiável?"*): a query, o `exec`, o `innerHTML`, o
  `fetch` com URL variável, o `path.join`, o `JSON.parse` seguido de merge, a checagem de permissão
  que não existe.

Quando o caminho fecha, você tem o achado. Quando ele esbarra em um controle, você tem o motivo de
não ser — e isso também é resultado, vale registrar.

### 4. Calibre antes de escrever

Para cada suspeita, quatro perguntas. Se alguma falhar, não é vulnerabilidade — é hardening ausente
ou observação, e deve ser rotulada como tal:

1. **O atacante controla a entrada?** Ou o valor vem de configuração, de constante do código, de
   outro serviço interno autenticado?
2. **O caminho existe de verdade?** A rota está registrada, a flag está ligada, o código é
   alcançável na versão que está em produção?
3. **Algum controle no caminho já barra?** ORM parametrizando, framework escapando por padrão,
   validação a montante, isolamento de rede.
4. **O impacto é real?** *"Um atacante consegue X"* — se você não consegue completar essa frase com
   algo que preocupe o dono do sistema, não reporte como vulnerabilidade.

Separe explicitamente as três coisas, porque misturá-las é o que faz um relatório ser ignorado:

| Rótulo | O que é | Exemplo |
|---|---|---|
| **Vulnerabilidade** | Caminho explorável, impacto demonstrável | `req.params.id` vai para a query sem filtro de dono: qualquer usuário lê o extrato de qualquer outro |
| **Hardening ausente** | Defesa em profundidade que falta, sem exploração conhecida | Falta `Permissions-Policy`; CSP sem `base-uri` num app que já escapa tudo |
| **Observação** | Risco futuro ou dívida | Autorização checada em 14 controllers em vez de centralizada — vai furar quando alguém adicionar a 15ª rota |

### 5. Entregue de um jeito que vire correção

Formato de cada achado — o detalhamento e um exemplo completo estão em `references/revisao-de-codigo.md`:

```
[SEVERIDADE] Título que diz o impacto, não a categoria
Local:     caminho/do/arquivo.ts:142
Caminho:   entrada → como chega → o que acontece (em passos numerados)
Impacto:   o que um atacante consegue, em termos de negócio
Correção:  o patch, com código
Verificação: o teste que falha antes e passa depois
```

Ordene por severidade e comece pelo que é explorável hoje. Se você ficou em dúvida, **diga a
dúvida**: *"não consegui confirmar se o middleware `requireAuth` cobre `/api/admin/*`; se não
cobrir, isso é crítico"* é uma frase honesta e útil. Fingir certeza é o que destrói a confiança.

Pelo mesmo motivo, **declare o escopo negativo** — o que você não olhou. Não havia lockfile, não
havia o projeto iOS, não havia o código do servidor que este app consome, você leu o diff e não o
repositório. Sem isso o leitor conclui que o silêncio é aprovação, e é assim que uma revisão
parcial vira falsa sensação de segurança. Quando a incerteza muda a severidade, diga isso também:
*"marquei como Alta e não Crítica porque depende de o servidor revalidar o limite; se ele não
revalidar, é Crítica"* dá ao leitor a pergunta exata que ele precisa responder.

O entregável de maior valor não é a lista: é **um teste automatizado por achado**, que falha hoje e
passa depois da correção. Ele impede a regressão e transforma a revisão em algo permanente. Ofereça
escrevê-los.

## Onde olhar primeiro

Quando o pedido é vago ("revisa a segurança disso") e o tempo é finito, a ordem abaixo maximiza o
retorno. Ela é deliberadamente **diferente da ordem do Top 10**, porque a lista mede o que é
contável por ferramenta, e você quer o que é explorável na prática — que é justamente onde a revisão
humana e assistida tem vantagem comparativa sobre o scanner.

1. **O lockfile, antes de qualquer linha de código da aplicação.** É a checagem mais barata e a de
   maior retorno bruto: uma RCE crítica numa dependência do framework vale mais que qualquer bug que
   você vá escrever. Nenhum scanner de aplicação encontra isso — só o lockfile encontra. O
   ecossistema Node deu exemplos caros disso entre 2024 e 2026: bypass de autorização por header no
   middleware do Next.js (CVE-2025-29927, CVSS 9.1, com correções incompletas depois), e uma RCE não
   autenticada de severidade máxima em `react-server-dom-*`. Confira versão de framework antes de
   procurar bug autoral.
2. **Controle de acesso, objeto por objeto.** Todo endpoint que recebe um identificador: quem prova
   que aquele objeto pertence a quem está pedindo? É a categoria #1 do OWASP 2025 — com a maior
   contagem de ocorrências da lista inteira — e a que mais aparece em bug bounty, enquanto XSS e
   SQLi caem ano a ano. Scanner não acha porque a requisição maliciosa é sintaticamente perfeita.
3. **Lógica de negócio onde há dinheiro, limite ou estado.** Saldo, cupom, plano, estoque, fluxo de
   aprovação, checkout, tudo que tem "quantidade" ou máquina de estado. Procure `check-then-act` sem
   transação. Essa classe cai em "Insecure Design", a categoria com a **menor** incidência medida do
   Top 10 — o que indica sub-medição, não raridade: ferramenta nenhuma sabe o que é um saldo.
4. **Multi-tenancy**, se houver. Um único `WHERE` sem `tenant_id` vaza a base de um cliente para
   outro, e o bug é silencioso: ninguém abre chamado reclamando de ver dado demais.
5. **Autenticação pelos caminhos não-felizes.** O login costuma estar certo. O que não está: reset
   de senha, troca de e-mail, convite, "entrar como usuário" do admin, API key, e o fluxo de OAuth
   (vazamento de código por Referer, `redirect_uri` validado por prefixo, conta pré-sequestrada por
   e-mail não verificado).
6. **Entrada que chega a um interpretador**: banco, shell, template, filesystem, parser de XML/YAML,
   desserializador. Na lista de vulnerabilidades sob exploração ativa da CISA, a família
   injeção/RCE (comando, desserialização, path traversal) responde por cerca de um quarto das
   adições recentes, contra uns 3% de XSS — XSS lidera índices de *frequência* porque é fácil de
   contar, não porque é o que derruba empresa.
7. **Requisição de saída com host ou URL vindos do usuário** (SSRF), antes de se preocupar com CSRF.
   SSRF sumiu da lista de 2025 como categoria própria — foi absorvida por Broken Access Control —
   mas não sumiu da realidade: webhook configurável, importação por URL, gerador de PDF/screenshot,
   proxy de imagem, preview de link.
8. **A fronteira entre CDN/proxy e a aplicação.** Cache poisoning e cache deception vivem na
   discrepância entre quem normaliza o caminho e quem responde, e resposta autenticada cacheada
   publicamente é vazamento em massa com uma requisição.
9. **Como o `Content-Type` é parseado, antes de confiar no schema de validação.** Se o parser aceita
   um tipo que você não previu, o Zod nem chega a rodar — o Fastify acumulou várias CVEs exatamente
   dessa forma. Validação que pode ser contornada na borda não é validação.
10. **Segredos e cadeia de suprimentos**: chave no repositório e no histórico do git, no bundle do
    frontend, no log; `postinstall` de dependência recém-instalada; workflow de CI com
    `pull_request_target` ou interpolação de `${{ github.event.* }}` dentro de `run:`.

Duas correções de rumo que a experiência recente impõe:

- **Se houver painel administrativo, appliance de borda ou serviço de infraestrutura exposto,
  ele vem antes do app de produto.** Cerca de um terço dos vazamentos começa por exploração de
  vulnerabilidade conhecida, e os campeões da lista de exploração ativa são VPNs, firewalls e
  gateways — não frameworks web.
- **Em aplicação mobile, a ordem muda de figura.** O binário está na mão do atacante, então todo
  controle no cliente é sugestão. Comece pela API que o app consome (volte ao item 2), e só depois
  olhe armazenamento local, deep links e WebView. `references/mobile.md` desenvolve isso.

## Os princípios que não mudam

**Separe o canal de dados do canal de controle.** É a mesma ideia por trás de prepared statement, de
`execFile` em vez de `exec`, de escapar por contexto no HTML e de passar `${{ github.event }}` por
`env:` em vez de interpolar no `run:`. Sanitizar string é sempre a segunda melhor resposta: o parser
do destino tem mais estados do que o seu sanitizador conhece. (E é exatamente por não existir essa
separação que prompt injection não tem solução linguística — veja `references/llm-e-ia.md`.)

**Valide na fronteira, autorize junto ao dado.** Validação de formato pertence à borda; autorização
pertence à camada que busca o objeto. Autorização espalhada por controller apodrece na primeira
rota nova.

**Falhe fechado.** O `catch` que segue em frente, o `if` cujo `else` libera, o timeout do serviço de
permissão que assume "pode": são vulnerabilidades escritas como robustez.

**Defesa em profundidade, mas nomeie a camada que de fato protege.** Constraint no banco, escopo na
query e validação no handler juntos são bons — desde que você saiba qual deles seria fatal remover.
Dizer "temos WAF" no lugar dessa resposta não é defesa em profundidade, é uma camada só.

**Tudo que chega ao cliente é público.** Bundle do frontend, `NEXT_PUBLIC_*`, binário mobile,
resposta de API que o front "esconde", system prompt. Não existe segredo do outro lado da rede.

**O que não pode ser corrigido em minutos precisa de mitigação em minutos.** Feature flag, desligar
o endpoint, regra de WAF temporária, revogar a credencial — decisões legítimas quando registradas
com prazo para a correção real.

## Uma triagem rápida, quando existe um repositório

Para um repositório desconhecido, esta sequência dá o melhor retorno nos primeiros minutos e não
manda um pacote sequer para fora da máquina:

```bash
bash scripts/triagem.sh /caminho/do/repo    # scripts/ é relativo ao diretório desta skill
```

Ela roda varredura de segredo (incluindo histórico), dependências vulneráveis e SAST, e imprime um
resumo. Trate a saída como **lista de hipóteses, não de achados**: cada item ainda passa pelas
quatro perguntas de calibração do passo 4. Ferramenta encontra padrão; só a leitura confirma
caminho e impacto. `references/ferramentas.md` explica o que cada uma acha, o que ela não acha e
como cortar o ruído.

## Limites

Este material existe para **defender, revisar e testar com autorização**. Uma PoC que demonstra que
a falha é real faz parte do trabalho, e explicar o mecanismo de um ataque é o que permite corrigi-lo.

O que fica de fora, mesmo pedido de forma indireta: exploit pronto para uso em escala contra
sistemas de terceiros, técnica cujo propósito é evadir detecção, e qualquer teste em alvo que não
seja do usuário ou que ele não tenha autorização escrita para testar. Se o pedido for ambíguo,
pergunte de quem é o sistema — a resposta costuma resolver.
