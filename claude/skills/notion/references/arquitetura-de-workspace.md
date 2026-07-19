# Arquitetura de Workspace no Notion

Este documento trata do problema real do Notion: não é difícil criar páginas, é difícil **encontrá-las seis meses depois**. Todo workspace abandonado tem a mesma história — começou limpo, virou um depósito de páginas órfãs com nomes como "Notas", "Notas 2" e "Rascunho importante (final)".

A causa raiz quase nunca é falta de recurso. É arquitetura: profundidade demais, sidebar sem curadoria, permissões improvisadas e ausência de convenção de nomes. Este arquivo é opinativo de propósito.

---

## 1. A hierarquia real do Notion

O Notion tem exatamente quatro níveis estruturais, e só dois deles são "de verdade":

| Nível | O que é | Quantos você deveria ter |
|---|---|---|
| **Workspace** | O contêiner de faturamento, membros e configurações. Um workspace = uma organização (ou uma pessoa). | 1, quase sempre |
| **Teamspace** | Subdivisão do workspace com membros e permissões próprias. Só existe em workspaces colaborativos. | 3 a 8 num time de 30 pessoas |
| **Página** | A unidade real de conteúdo. Tudo é página — inclusive database, wiki e form. | Quantas precisar |
| **Subpágina** | Uma página aninhada dentro de outra. **Não é um tipo diferente** — é só uma página cujo pai é outra página. | O menos possível |

O ponto que quase todo mundo erra: **subpágina não é uma pasta**. O Notion não tem pastas. Tem páginas que contêm páginas. Isso significa que a "pasta" também é um documento editável, com conteúdo próprio, histórico e permissões. Tratá-la como pasta vazia é desperdiçar o mecanismo.

Referência oficial: [Intro to workspaces](https://www.notion.com/help/intro-to-workspaces).

### Por que profundidade excessiva mata a navegação

Notion não impõe limite prático de aninhamento. Você pode fazer página > página > página > página > página > página. E é exatamente por isso que as pessoas fazem.

O custo é concreto e mensurável:

**1. Custo de cliques.** Para chegar num documento no nível 6, você expande 5 toggles na sidebar. Cada expansão é um clique e uma releitura visual. O usuário desiste no nível 3 e usa a busca — o que significa que sua hierarquia inteira virou decoração.

**2. Custo de breadcrumb.** O breadcrumb do topo da página trunca. Com 6 níveis, você vê `Workspace / ... / Página atual`. O contexto do meio some. O leitor não sabe onde está.

**3. Custo de mudança.** Mover uma página de nível 5 para nível 4 quebra o modelo mental de todo mundo que memorizou o caminho, e não quebra nenhum link (links do Notion são por ID, não por caminho) — o que é pior, porque a bagunça é invisível.

**4. Custo de permissão.** Permissão herda do pai. Uma página no nível 6 tem 5 ancestrais que podem alterar seu acesso. Auditar isso é impraticável.

**Regra que eu aplico:** três níveis abaixo do teamspace. Se precisar de um quarto, o conteúdo não é hierárquico — é **relacional**, e deve virar database com propriedades, não subpágina.

```
Teamspace: Engineering            ← nível 0
└─ Runbooks                       ← nível 1 (índice)
   └─ Deploy                      ← nível 2 (página real)
      └─ Rollback de emergência   ← nível 3 (limite)
```

Se você se pega criando `Engineering / Runbooks / Deploy / Kubernetes / Produção / us-east-1 / Rollback`, pare. Isso é um database `Runbooks` com propriedades `Sistema`, `Ambiente`, `Região`. Uma página, sete filtros, zero cliques de expansão.

### Quando profundidade é legítima

- **Wiki de empresa** onde a hierarquia é o produto (política > subpolítica). Ainda assim, 4 níveis no máximo.
- **Projetos com estrutura fixa e conhecida** (cliente > projeto > entrega), onde cada nível tem cardinalidade baixa.
- **Nunca** para categorizar por atributo. Atributo é propriedade de database.

---

## 2. Teamspaces

Teamspace é o único mecanismo de organização de nível alto que o Notion oferece a times. Entender os três tipos evita 90% dos problemas de permissão.

| Tipo | Visível na busca/browse? | Quem entra | Plano |
|---|---|---|---|
| **Open** | Sim | Qualquer membro do workspace entra sozinho | Todos |
| **Closed** | Sim (vê que existe, não vê o conteúdo) | Só por convite de owner ou member | Todos |
| **Private** | Não (invisível para quem não está dentro) | Só por convite | **Business e Enterprise** |

Texto oficial, em [Intro to teamspaces](https://www.notion.com/help/intro-to-teamspaces):

> **Open:** "Anyone can join and view the content inside this teamspace."
> **Closed:** "Everyone can see that this teamspace exists, but can't join unless they're invited by an owner or member."
> **Private:** "Only members or owners of this teamspace can invite other people, and it won't be visible to people who are not added."

**Veredito prático:** use `Open` como padrão. A tentação de fechar tudo é forte e quase sempre errada — conhecimento trancado é conhecimento que ninguém encontra, e o custo de alguém ler um doc que não precisava é muito menor que o custo de reescrever um doc que já existia. Reserve `Closed` para People/RH e Finance. `Private` só quando houver obrigação contratual ou legal de confidencialidade (M&A, jurídico, dados de folha).

### Default teamspaces

Você pode marcar um teamspace como **default**: todo membro atual e futuro do workspace entra nele automaticamente.

A doc é explícita sobre a dosagem:

> "Most likely, you'll only need one default teamspace, and we'd recommend no more than three default, even for large workspaces."

Um default teamspace bem feito é o **General** / **Company Home** — onde vive o onboarding, o handbook, os feriados, os links de ferramentas. Se você marca 6 teamspaces como default, cada novo funcionário abre o Notion e vê 6 seções que não significam nada para ele. Você acabou de recriar o problema que o teamspace resolvia.

### Criar um teamspace novo ou só uma página?

Essa é a decisão mais consequente da arquitetura, e o critério é **permissão + permanência**, não volume de conteúdo.

Crie um **teamspace** quando as três forem verdadeiras:
1. Existe um grupo estável de pessoas que precisa de acesso diferente do resto.
2. O grupo produz conteúdo continuamente (não é um projeto que acaba).
3. O grupo tem dono claro (alguém responsável por arrumar aquilo).

Crie uma **página** quando:
- É um projeto com data de fim.
- O acesso é o mesmo do teamspace pai.
- É um esforço de uma pessoa ou de uma dupla.

| Situação | Teamspace ou página? |
|---|---|
| Time de Engenharia (12 pessoas, permanente) | Teamspace |
| Squad temporário para migrar o billing (3 meses) | Página dentro de Engineering |
| Documentação de produto lida pela empresa toda | Teamspace `Product`, Open |
| Reuniões 1:1 de um gestor | Página privada, não teamspace |
| Comitê de segurança com dados sensíveis | Teamspace Private (Business+) |
| "Ideias de blog" | Database dentro do teamspace de Marketing |

**Anti-padrão comum:** um teamspace por projeto. Você acaba com 40 teamspaces, sidebar impossível, e ninguém arquiva nada porque deletar um teamspace parece grave demais. Projeto é linha de database, não teamspace.

Docs relevantes: [Create, join & leave teamspaces](https://www.notion.com/help/browse-join-and-create-teamspaces), [Intro to teamspaces](https://www.notion.com/help/intro-to-teamspaces), [What are Teamspaces? A guide for Notion admins](https://www.notion.com/help/guides/what-are-teamspaces-a-guide-for-notion-admins).

### Papéis dentro do teamspace

| Papel | Pode |
|---|---|
| **Teamspace owner** | Acesso total a todas as páginas do teamspace por padrão + acesso às configurações do teamspace |
| **Teamspace member** | Acesso às páginas conforme o owner definir; **sem** acesso às configurações |

Em teamspaces `Closed` e `Private`, o owner escolhe se qualquer member pode convidar ou se só owners podem.

**Regra operacional:** todo teamspace precisa de pelo menos dois owners. Um único owner que sai da empresa gera um teamspace órfão que só o workspace owner consegue destravar.

---

## 3. Private vs Shared

Além dos teamspaces, cada usuário tem uma seção **Private** na sidebar. É espaço pessoal — ninguém vê, nem workspace owner (ele pode acessar via exportação/admin em planos altos, mas não navegando).

O erro clássico: **trabalho da empresa vivendo em Private**. É a maior fonte de perda de conhecimento em workspaces corporativos. A pessoa sai, e três anos de documentação vão junto.

| Vai em Private | Vai em Teamspace |
|---|---|
| Rascunho de ideia sua | Qualquer coisa que outra pessoa vá precisar |
| Anotações de carreira, 1:1 como liderado | Notas de reunião de projeto |
| Lista pessoal de leituras | Especificação técnica, mesmo incompleta |
| Sandbox de teste de fórmula | Runbook, política, processo |

**Heurística:** se você hesitaria em deletar o conteúdo ao sair da empresa, ele não deveria estar em Private.

Mover de Private para um teamspace é trivial (arrastar na sidebar ou `Move to`). Fazer isso semanalmente, como hábito, é o que separa workspace saudável de arqueologia.

---

## 4. Sidebar: o que aparece e o que não

A sidebar é a única superfície de navegação persistente. Ela é o mapa. Se ela tem 40 itens de topo, você não tem mapa — tem um índice remissivo.

Ordem canônica que funciona (de cima para baixo):

1. **Search / Ask Notion** — fixo pelo produto
2. **Favorites** — no máximo 7 itens, curados por cada pessoa
3. **Teamspaces** — 3 a 8, ordenados por frequência de uso, não alfabeticamente
4. **Shared** — páginas compartilhadas com você fora de teamspaces
5. **Private** — seu espaço
6. **Templates / Trash / Settings**

### Favorites

Favorites é pessoal, não compartilhado. É o único lugar onde a curadoria individual importa mais que a coletiva.

**O que merece favorite:** a página que você abre todo dia (o database de tasks, o dashboard do time, o doc de sprint atual).

**O que não merece:** qualquer coisa que você abre uma vez por mês. Isso é busca.

Se seus Favorites têm 20 itens, eles pararam de ser favoritos e viraram uma segunda sidebar. Limpe trimestralmente.

### O que nunca deve estar no topo da sidebar

- Páginas de projeto individual (viram linha de database)
- Notas de reunião soltas (viram linha de um database `Meetings`)
- Rascunhos (vão em Private)
- Databases que já estão embutidos em outra página (duplicar na sidebar é ruído)

Guia oficial sobre isso: [Structure your sidebar for more focused work with teamspaces](https://www.notion.com/help/guides/structure-sidebar-focused-work-teamspaces).

---

## 5. Permissões e compartilhamento

### Níveis de acesso a uma página

| Nível | Pode ler | Pode comentar | Pode editar | Pode compartilhar/alterar permissão |
|---|---|---|---|---|
| **Full access** | Sim | Sim | Sim | **Sim** |
| **Can edit** | Sim | Sim | Sim | Não |
| **Can comment** | Sim | Sim | Não | Não |
| **Can view** | Sim | Não | Não | Não |

A distinção que as pessoas ignoram é entre **Full access** e **Can edit**. `Can edit` deixa a pessoa mudar tudo no conteúdo, mas não deixa ela abrir a página para mais gente. Em documentação sensível, dar `Can edit` em vez de `Full access` é o controle certo.

Guia oficial: [Sharing & permissions](https://www.notion.com/help/guides/sharing-and-permissions).

### Herança de permissão

Permissão flui **de cima para baixo**. Uma subpágina herda o acesso do pai automaticamente.

Você pode **restringir** uma subpágina (dar acesso a menos gente que o pai). Isso quebra a herança para aquele ramo. Toda mudança futura no pai não se propaga mais para lá.

```
Teamspace Engineering (todos os 12)
└─ Runbooks                    → herda: 12 pessoas
   └─ Credenciais de prod      → restrito: 3 pessoas   ← herança quebrada
      └─ Rotação de chaves     → herda de "Credenciais": 3 pessoas
```

**Armadilha real:** quebras de herança são invisíveis na navegação. Você só descobre quando alguém reclama que não acha uma página. Auditá-las exige abrir o menu `Share` de cada página, uma a uma.

**Recomendação forte:** quebre herança no **máximo uma vez** por ramo, e o mais alto possível na árvore. Se você precisa de três níveis de confidencialidade dentro do mesmo teamspace, você precisa de teamspaces separados.

### Members vs Guests

| | Member | Guest |
|---|---|---|
| Acesso | Ao workspace, teamspaces que participa | **Só às páginas específicas** compartilhadas com ele |
| Conta na fatura | Sim, cobra por assento | **Não** cobra assento |
| Vê a sidebar do workspace | Sim | Não — vê só o que foi compartilhado |
| Limite | Conforme plano | Free: 10 · Plus/Business/Enterprise: ilimitado |

Guest é o mecanismo certo para cliente, freelancer, contador, agência. Você não paga assento e a pessoa não navega no seu workspace.

**Cuidado:** guest com `Full access` numa página pode compartilhar aquela página com terceiros. Para colaboração externa, `Can edit` ou `Can comment` é quase sempre o nível certo.

### Compartilhar na web (public pages)

Qualquer página pode ser publicada com `Share → Publish`. Ao publicar:

- A página ganha uma URL pública `*.notion.site`
- Você escolhe se permite **duplicar como template**, **editar**, **comentar**
- Você escolhe se permite **indexação por buscadores** (search engine indexing)

**Indexação:** ligada, o Google eventualmente rastreia a página. Desligada, o Notion emite `noindex`. Mas atenção — **desligar indexação não é controle de acesso**. A URL continua acessível por qualquer um que a tenha. Se o conteúdo é confidencial, não publique; compartilhe por permissão.

Subpáginas de uma página publicada **também ficam públicas**. Esse é o vazamento mais comum do Notion: alguém publica um roadmap, esquece que dentro dele há uma subpágina com números de receita.

**Checklist antes de publicar qualquer página:**
1. Abra todas as subpáginas e confira o conteúdo.
2. Confira databases embutidos — todas as linhas ficam visíveis, inclusive as que você filtrou fora da view? (Views filtram exibição, não acesso ao dado subjacente em alguns casos de linked view — teste como anônimo.)
3. Abra a URL numa janela anônima. Sempre.

Docs: [Publish a Notion Site](https://www.notion.com/help/public-pages-and-web-publishing), [Publishing Notion pages to the web](https://www.notion.com/help/notion-academy/lesson/publishing-notion-pages-to-the-web).

### Links de convite

- **Convite por e-mail:** o caminho controlado. A pessoa entra com o papel que você definiu.
- **Link de convite do workspace:** gera um link que qualquer um com acesso pode usar para entrar. Útil em onboarding em lote, perigoso se vazar.
- **Domínio verificado (allowed email domains):** em planos pagos, você permite que qualquer pessoa com e-mail `@suaempresa.com` entre sozinha. É o mecanismo certo para empresas — elimina o gargalo de convite manual.

---

## 6. Planos: o que cada um libera de verdade

Números confirmados em [notion.com/pricing](https://www.notion.com/pricing), julho de 2026.

| | Free | Plus | Business | Enterprise |
|---|---|---|---|---|
| Preço (anual) | $0 | $10/membro/mês | $20/membro/mês | Sob consulta |
| Upload de arquivo | **5 MB por arquivo** | Ilimitado (~5 GB/arquivo) | Ilimitado | Ilimitado |
| Histórico de página | **7 dias** | 30 dias | 90 dias | **Ilimitado** |
| Guests | **10** | Ilimitado | Ilimitado | Ilimitado |
| Private teamspaces | Não | Não | **Sim** | Sim |
| Forms | Básico | Custom (sem marca Notion) | Custom + **lógica condicional** | Idem |
| Charts | **1 por workspace** | Ilimitado | Ilimitado | Ilimitado |
| Sites publicados | Ilimitado, 1 domínio `notion.site` | Ilimitado, até 5 domínios `notion.site` | Idem | Idem |
| Analytics | Básico | Básico | Advanced page analytics | Workspace analytics |
| Notion AI | Respostas cortesia (limitadas) | Respostas cortesia (limitadas) | **Incluído** | Incluído + zero data retention |
| SAML SSO | Não | Não | Sim | Sim |
| SCIM, audit log | Não | Não | Não | Sim |
| Retenção de dados customizada | Não | Não | Não | Sim |

### Os limites que realmente doem

**Upload de 5 MB no Free.** Este é o limite que quebra o Free na prática. Um PDF de apresentação, um screenshot de retina, um vídeo curto — tudo estoura. Se você trabalha com anexos, o Free não serve.

**7 dias de histórico no Free.** Alguém apaga metade de uma página numa sexta e você descobre na segunda seguinte: recuperável. Descobre em duas semanas: perdido.

**Notion AI de uso contínuo só em Business.** Todo mundo consegue *experimentar* o Notion AI — Free e Plus recebem um número limitado de respostas de cortesia —, mas usar de verdade, no dia a dia, exige upgrade para Business ou Enterprise. Esta é a mudança mais relevante de 2026 e a que mais quebra expectativa de quem conhecia o Notion de antes. A doc oficial em [What is Notion AI?](https://www.notion.com/help/notion-ai-faqs) diz:

> "Notion AI is only available on Business and Enterprise Plans. Users on the Free and Plus Plans get a limited number of complimentary AI responses so they can try Notion AI features out."

Ou seja: **AI deixou de ser add-on comprável em cima de qualquer plano e virou parte do Business**. O caminho mais barato para AI de verdade hoje é $20/membro/mês. Ver [Notion AI complimentary responses](https://www.notion.com/help/complimentary-ai-responses).

**Private teamspaces só em Business.** Se sua estrutura depende de compartimentar RH e Finance de forma invisível, Plus não resolve.

### Como escolher

| Perfil | Plano |
|---|---|
| Uso individual, notas e projetos pessoais | **Free** — o limite de blocos não se aplica a uso solo |
| Individual que anexa arquivos grandes ou quer histórico | **Plus** |
| Time de 3 a 10, sem necessidade de AI ou compartimentação | **Plus** |
| Time que quer AI, Agents, ou private teamspaces | **Business** |
| Empresa com compliance, SCIM, audit log, SSO obrigatório | **Enterprise** |

---

## 7. Métodos de organização aplicados ao Notion — veredito honesto

O Notion atrai gente que gosta de sistema. Isso é uma armadilha: o tempo gasto montando o sistema muitas vezes excede o valor que ele gera. Aqui vai o julgamento honesto de cada método.

### PARA (Projects, Areas, Resources, Archives)

Quatro buckets de topo: projetos com prazo, áreas de responsabilidade contínuas, referências e arquivo.

**Veredito: o melhor custo-benefício para o Notion.** Mapeia diretamente para a estrutura nativa — quatro páginas de topo ou quatro teamspaces, e a decisão "onde guardo isso?" tem resposta em três segundos. O bucket `Archive` resolve o problema mais crônico do Notion, que é ninguém saber o que pode sumir.

**Para quem:** uso individual e times pequenos. Implementável numa tarde.

**Onde falha:** em time grande, "Areas" vira ambíguo entre departamentos. E a distinção Project/Area gera debate improdutivo em casos de fronteira.

**Implementação enxuta:**
```
📌 Projects   → database, propriedades: Status, Deadline, Owner, Area (relation)
🔁 Areas      → database, uma linha por área contínua
📚 Resources  → database, propriedades: Tipo, Tags, Fonte
🗄️ Archive    → não é database; é a propriedade Archived (Checkbox) + filtro nas views
```
Sim: `Archive` deve ser uma **propriedade**, não um lugar. Mover páginas entre databases é atrito; marcar um checkbox é um clique. Use Checkbox e não um valor no `Status`: arquivar é ortogonal ao ciclo de vida, e você arquiva tanto o concluído quanto o cancelado (ver `boas-praticas-e-armadilhas.md`).

### GTD (Getting Things Done)

Captura, esclarece, organiza, reflete, executa. Contextos (@computador, @telefone), next actions, listas someday/maybe.

**Veredito: bom para a camada de tarefas, ruim como arquitetura de workspace.** GTD é um sistema de gestão de ação, não de gestão de conhecimento. Tentar organizar sua documentação por contexto GTD não funciona.

**Para quem:** quem já pratica GTD fora do Notion e quer trazer o inbox e as next actions para dentro. O `Inbox` do GTD combina muito bem com um botão de captura rápida.

**Onde falha:** GTD exige revisão semanal disciplinada. Sem ela, seu database de tarefas vira um cemitério de 400 itens `Not started`. O Notion não força ritual; se você não faz a weekly review, não use GTD.

### Zettelkasten

Notas atômicas, densamente interligadas, sem hierarquia, com índices emergentes.

**Veredito: o Notion é uma ferramenta medíocre para Zettelkasten.** Faltam duas coisas centrais: **backlinks visuais de qualidade** e **grafo**. O Notion tem backlinks (a seção de menções no rodapé), mas descobrir conexões não-óbvias — que é o ponto inteiro do método — é praticamente impossível sem visualização de grafo.

**Para quem:** quase ninguém. Se Zettelkasten é o seu método central, use Obsidian ou Logseq e conecte com o Notion só onde precisar colaborar.

**O que aproveitar:** a ideia de **nota atômica** (uma ideia por página, título que é uma afirmação, não um substantivo). Isso melhora qualquer workspace, independente de método.

### Second Brain / BASB

Metodologia guarda-chuva de Tiago Forte; na prática é PARA + progressive summarization + captura.

**Veredito: PARA com marketing melhor.** A parte estrutural útil já está no PARA. A "progressive summarization" (destacar em camadas) é razoável mas gera trabalho manual que a busca por AI hoje torna redundante — o Q&A do Notion encontra o trecho relevante sem você ter destacado nada.

**Para quem:** quem consome muito conteúdo (artigos, papers, cursos) e quer um pipeline de captura → destilação. Para os demais, é overhead.

### O veredito global

| Método | Vale a pena? | Para quem |
|---|---|---|
| **PARA** | **Sim** | Todo mundo. Comece aqui. |
| GTD | Parcial | Só a camada de tarefas, só com weekly review real |
| Zettelkasten | Não no Notion | Use outra ferramenta |
| Second Brain | Redundante | PARA já entrega o essencial |

**A verdade desconfortável:** o método importa muito menos que dois hábitos — (a) uma convenção de nomes consistente e (b) uma limpeza trimestral. Um workspace sem método nenhum, mas com esses dois hábitos, é mais saudável que um PARA impecável abandonado.

---

## 8. Três padrões de arquitetura

### Padrão A — Workspace pessoal

Sem teamspaces (não existem em workspace individual). Tudo em Private, curadoria via Favorites.

```
⭐ Favorites
   Dashboard
   Tasks

🔒 Private
   🏠 Dashboard              ← página única, linked views dos databases
   ✅ Tasks                  ← database: Status, Do date, Due date, Project(relation), Area
                             (Do date = quando você faz; Due date = prazo com terceiro)
   📌 Projects               ← database: Status, Deadline, Area(relation)
   🔁 Areas                  ← database: Saúde, Finanças, Carreira, Casa
   📚 Resources              ← database: Tipo, Tags, URL
   📓 Journal                ← database: Date, Mood, Notas
   🧪 Sandbox                ← rascunhos, esvaziar mensalmente
```

**Sete páginas de topo. Não mais.** Tudo o mais é linha de database. O `Dashboard` é a única página que você abre por hábito; ele agrega linked views filtradas ("tarefas de hoje", "projetos ativos").

### Padrão B — Time pequeno (5 a 25 pessoas)

```
Teamspaces:
  🏢 Company (default, Open)
     Handbook · Onboarding · Feriados · Ferramentas · All-hands
  🛠️ Product (Open)
     Roadmap · Specs (db) · Discovery (db)
  💻 Engineering (Open)
     Runbooks (db) · ADRs (db) · Postmortems (db) · On-call
  📣 Go-to-market (Open)
     Campanhas (db) · Conteúdo (db) · Contas (db)
  👥 People (Closed)
     Contratação (db) · Políticas · Avaliações
```

**Decisões deliberadas nesse desenho:**
- Um único default teamspace (`Company`).
- Quase tudo `Open` — a fricção de descoberta custa mais que o risco de leitura indevida.
- `People` é `Closed`, não `Private`, para o time saber que existe e pedir acesso.
- Cada teamspace tem **no máximo 5 itens de topo**, e a maioria é database.

### Padrão C — Wiki de empresa (50+ pessoas)

Aqui a hierarquia vira produto e a manutenção vira problema real.

```
🏢 Company Wiki (default, Open) — página convertida em wiki
   ├─ Como trabalhamos       (verificada, owner: Chief of Staff)
   ├─ Benefícios e políticas (verificada, owner: People)
   ├─ Segurança              (verificada, owner: Security, expira 90d)
   ├─ Glossário              (database)
   └─ Índice de teamspaces   (quem faz o quê, onde fica)

+ um teamspace por departamento (Open salvo exceção)
+ Enterprise: audit log, SCIM, retenção customizada
```

O elemento crítico é o **Índice de teamspaces**: uma página que lista todos os teamspaces, o que cada um faz e quem é o owner. Sem isso, ninguém em uma empresa de 200 pessoas descobre onde a informação vive.

---

## 9. Wikis e páginas verificadas

Converter uma página em wiki (`•••` → `Turn into wiki`) transforma suas subpáginas num database navegável. Você ganha três views automáticas:

- **Home** — exibição customizável de todas as páginas
- **All pages** — view de database de tudo
- **Pages I own** — só o que é seu

E ganha duas propriedades que não existem em páginas normais: **Owner** e **Verification**.

Só páginas podem virar wiki — databases não.

### Verificação

Uma página verificada exibe um selo azul em menções e resultados de busca. Você define a duração: por tempo determinado ou indefinida. Quando expira, o **owner recebe notificação**.

**Este é o recurso mais subestimado do Notion.** Ele resolve o problema de "esse doc ainda é verdade?" — que é a razão número um pela qual as pessoas param de confiar em wikis internos.

**Como usar bem:**

| Tipo de conteúdo | Duração da verificação |
|---|---|
| Política de férias, benefícios | 12 meses |
| Runbook de produção | 90 dias |
| Arquitetura de sistema | 180 dias |
| Guia de ferramenta de terceiros | 90 dias |
| Página histórica (postmortem) | **Não verificar** — é um registro, não um doc vivo |

Verificação de páginas individuais fora de wikis exige **Business ou Enterprise**. Dentro de wikis funciona mais amplamente. Você também pode adicionar verificação como propriedade de um database inteiro.

Gerencie tudo em `Settings → Verified pages`, com filtro por owner.

Doc: [Wikis and verified pages](https://www.notion.com/help/wikis-and-verified-pages).

---

## 10. Nomenclatura e convenções

Convenção de nome é o investimento de maior retorno e menor custo em qualquer workspace. Cinco minutos de decisão, anos de benefício.

### Regras

**1. O título diz o que é, não o que a pasta é.**
Ruim: `Notas` dentro de `Reunião de Produto`.
Bom: `2026-07-15 — Produto: priorização do Q3`.
Motivo: o título é o que aparece na busca, no `@mention` e no link. Ele viaja sozinho, sem o contexto do pai.

**2. Data no formato ISO, sempre no início, quando a ordem cronológica importa.**
`2026-07-19 — Postmortem: outage do checkout`
Ordena corretamente em qualquer sort alfabético, e é inequívoco entre BR e US.

**3. Prefixo de tipo só quando resolve ambiguidade real.**
`RFC — Migração para eventos` é útil. `Doc — Onboarding` é ruído.

**4. Nada de sufixos de versão.** `v2`, `final`, `novo`, `(atualizado)` são sintomas de que você não confia no histórico de versão. Confie. Uma página, um nome, o histórico cuida do resto.

**5. Databases no plural, páginas no singular.**
`Projects` (database) contém `Migração do billing` (página).

**6. Verbo no infinitivo para runbooks e how-tos.**
`Rotacionar credenciais de produção` — a pessoa está buscando pela ação.

### Ícones

Ícones não são decoração; são a única pista visual rápida na sidebar e nos resultados de busca.

| Convenção | Uso |
|---|---|
| Ícone **consistente por tipo** | Todo runbook usa 🔧, todo postmortem usa 🔥, todo spec usa 📐 |
| Ícone **distinto por teamspace** | Cada teamspace tem sua identidade visual |
| **Sem ícone** | Sinaliza rascunho / não terminado. Útil como estado. |

**Anti-padrão:** ícone diferente para cada página. Vira ruído colorido e perde-se a função de reconhecimento de padrão.

Cover images: use com moderação. Elas empurram o conteúdo para baixo e custam scroll. Reserve para páginas de topo (dashboards, home de teamspace).

---

## 11. Search e como estruturar para ser encontrável

A busca do Notion indexa título e conteúdo. O `Ask Notion` (Q&A por AI, Business+) responde em linguagem natural sobre o workspace.

**O que melhora a encontrabilidade, em ordem de impacto:**

1. **Títulos descritivos e específicos.** Peso maior no ranking. Um doc chamado `Processo` é invisível.
2. **Sinônimos no corpo.** Se o time diz "deploy" e a doc diz "publicação", inclua ambos numa linha do texto. A busca é lexical em boa parte.
3. **Menos duplicatas.** Três páginas parecidas sobre onboarding significam que a busca retorna três e o usuário escolhe a errada. Consolide, não crie.
4. **Verificação.** Páginas verificadas ganham selo e destaque nos resultados.
5. **Arquivar o obsoleto.** Conteúdo velho compete com conteúdo bom no resultado. Em Business/Enterprise, páginas **arquivadas** continuam acessíveis mas ficam ocultas da busca por padrão — é exatamente a ferramenta certa.

**Estrutura que ajuda o Q&A por AI:** parágrafos curtos, headings reais (H1/H2/H3, não texto em negrito fingindo de heading), tabelas em vez de listas quando o dado é tabular. A AI extrai muito melhor de estrutura semântica.

---

## 12. Auditoria e limpeza de um workspace bagunçado

Se você herdou um workspace caótico, não reorganize — **audite primeiro**. Reorganizar sem dados é como refatorar sem testes.

### Passo 1 — Medir

Em Business/Enterprise, use **page analytics** e **workspace analytics** para ver views por página nos últimos 90 dias. É o dado que decide tudo.

Sem plano com analytics, use como proxy a data de `Last edited` — disponível como propriedade em qualquer database e visível em qualquer página.

### Passo 2 — Classificar

Passe cada página de topo e cada database por esta matriz:

| Editada nos últimos 90d? | Tem views? | Ação |
|---|---|---|
| Sim | Sim | **Manter.** Considere verificar. |
| Não | Sim | **Revisar.** Gente usa mas ninguém mantém — risco alto de desinformação. Atribuir owner. |
| Sim | Não | **Investigar.** Alguém mantém algo que ninguém lê. Provável duplicata ou trabalho desperdiçado. |
| Não | Não | **Arquivar.** |

A célula "não editada + com views" é a mais perigosa do workspace: documentação desatualizada que as pessoas ainda confiam.

### Passo 3 — Arquivar, não deletar

| Situação | Ação |
|---|---|
| Conteúdo obsoleto mas com valor histórico (postmortems, decisões antigas, projetos entregues) | **Arquivar** (Business+) ou mover para um teamspace `Archive` |
| Duplicata exata | **Deletar** — mas primeiro coloque um link para a versão canônica na página que vai morrer, e espere 30 dias |
| Rascunho abandonado de alguém que saiu | **Deletar** |
| Template de teste, sandbox | **Deletar** |
| Qualquer coisa com dado pessoal/financeiro sem dono | **Escalar para o owner do workspace**, não decidir sozinho |

**Regra de ouro:** na dúvida, arquive. O custo de armazenar é zero; o custo de destruir conhecimento é irrecuperável.

### Passo 4 — Trash e recuperação

Números confirmados em [Duplicate, delete & restore content](https://www.notion.com/help/duplicate-delete-and-restore-content):

- Conteúdo deletado vai para **Trash e fica 30 dias** antes da deleção permanente.
- Após a remoção permanente do Trash, o item fica inacessível a todos (inclusive workspace owners) por **mais 30 dias**.
- O Notion mantém backups de banco que permitem restaurar snapshot dos **últimos 30 dias** via suporte.
- **Enterprise** pode customizar esses períodos de retenção.

Restauração de página individual: `•••` → `Version history`, e você pode restaurar **blocos individuais** ou a versão inteira. Janela conforme o plano: Free 7d, Plus 30d, Business 90d, Enterprise ilimitado.

**Para deleção em massa acidental:** não tente consertar página a página. Contate o suporte via `?` na sidebar — eles restauram snapshot. Mas só dentro da janela de 30 dias.

### Passo 5 — Prevenir a recaída

Auditoria é inútil sem ritual. Três coisas, e só três:

1. **Owner obrigatório** em todo database e toda página de topo. Sem dono, sem manutenção.
2. **Revisão trimestral de 30 minutos** por teamspace owner, com a matriz do passo 2.
3. **Verificação com expiração** nas 10 a 20 páginas mais críticas. O Notion te lembra; você não precisa lembrar.

---

## 13. Migração para o Notion

Se você está trazendo conteúdo de outra ferramenta:

| Origem | Como | Cuidado |
|---|---|---|
| Confluence, Evernote, Word, HTML, CSV | Import nativo (`Settings → Import`) | Formatação complexa quebra; tabelas aninhadas viram texto |
| Google Docs | Exportar como `.docx` e importar, ou copiar e colar | Colar preserva mais formatação do que o import em muitos casos |
| Planilhas | Importar CSV como database | Defina os tipos de propriedade **antes**; corrigir 2000 linhas depois é doloroso |
| Outra ferramenta sem export | Copiar e colar em Markdown | O Notion converte Markdown ao colar |

**A regra que economiza semanas:** não migre tudo. Migre o que foi acessado nos últimos 6 meses. O resto fica na ferramenta antiga em modo leitura, ou vai para um PDF de arquivo. Migração completa é a forma mais rápida de nascer com um workspace já bagunçado — você importa a desorganização junto com o conteúdo.

---

## 14. Checklist de arquitetura saudável

- [ ] Um workspace, não três
- [ ] Entre 3 e 8 teamspaces, cada um com owner nomeado (dois, idealmente)
- [ ] Exatamente um default teamspace (no máximo três)
- [ ] Máximo 3 níveis de profundidade abaixo do teamspace
- [ ] Máximo 5 itens de topo por teamspace
- [ ] Nada de trabalho de empresa vivendo em Private
- [ ] Herança de permissão quebrada no máximo uma vez por ramo
- [ ] Toda página publicada na web foi aberta em janela anônima
- [ ] Convenção de nome escrita numa página e linkada no onboarding
- [ ] Ícones consistentes por tipo de conteúdo
- [ ] Páginas críticas verificadas com expiração
- [ ] Revisão trimestral agendada no calendário, com dono
- [ ] Projetos são linhas de database, não teamspaces nem subpáginas

---

## Fontes

- [Intro to workspaces](https://www.notion.com/help/intro-to-workspaces)
- [Intro to teamspaces](https://www.notion.com/help/intro-to-teamspaces)
- [Create, join & leave teamspaces](https://www.notion.com/help/browse-join-and-create-teamspaces)
- [What are Teamspaces? A guide for Notion admins](https://www.notion.com/help/guides/what-are-teamspaces-a-guide-for-notion-admins)
- [Structure your sidebar for more focused work with teamspaces](https://www.notion.com/help/guides/structure-sidebar-focused-work-teamspaces)
- [Grant the right level of access with teamspaces and groups](https://www.notion.com/help/guides/grant-access-teamspaces)
- [Sharing & permissions](https://www.notion.com/help/guides/sharing-and-permissions)
- [Publish a Notion Site](https://www.notion.com/help/public-pages-and-web-publishing)
- [Publishing Notion pages to the web](https://www.notion.com/help/notion-academy/lesson/publishing-notion-pages-to-the-web)
- [Wikis and verified pages](https://www.notion.com/help/wikis-and-verified-pages)
- [Duplicate, delete & restore content](https://www.notion.com/help/duplicate-delete-and-restore-content)
- [What is Notion AI?](https://www.notion.com/help/notion-ai-faqs)
- [Notion AI complimentary responses](https://www.notion.com/help/complimentary-ai-responses)
- [Notion Pricing](https://www.notion.com/pricing)
