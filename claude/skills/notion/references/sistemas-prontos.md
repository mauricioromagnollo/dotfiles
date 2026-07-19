# Sistemas prontos para montar no Notion

Blueprints implementáveis. Cada um traz: o problema real que resolve, o esquema completo de databases (nome, propriedade, tipo exato), o mapa de relations, as views com filtro/sort/group literais, o layout da página principal em ASCII, automações recomendadas e os erros que quase todo mundo comete.

Convenções usadas aqui:

- Nomes de databases, propriedades e views ficam **em inglês**. É o vocabulário nativo do produto, sobrevive a mudança de idioma da interface e evita ambiguidade em fórmula (`prop("Status")` não aceita apelido).
- Tipos de propriedade aparecem exatamente como o Notion os chama: `Title`, `Text`, `Number`, `Select`, `Multi-select`, `Status`, `Date`, `Person`, `Files & media`, `Checkbox`, `URL`, `Email`, `Phone`, `Formula`, `Relation`, `Rollup`, `Created time`, `Created by`, `Last edited time`, `Last edited by`, `ID`, `Button`, `Place`. Referência: [Database properties](https://www.notion.com/help/database-properties).
- Filtros são descritos como `Propriedade → operador → valor`, do jeito que aparecem no construtor de filtros ([Views, filters, sorts & groups](https://www.notion.com/help/views-filters-and-sorts)).
- Onde escrevo "data source", é no sentido pós-setembro/2025: um **database** é um container que pode abrigar **múltiplos data sources**, cada um com schema próprio ([Data sources](https://www.notion.com/help/data-sources-and-linked-databases)). Views continuam exibindo **um** data source por vez.

Antes de copiar qualquer blueprint: leia a seção final de cada sistema ("Erros comuns"). Ela vale mais que o esquema.

---

## Sumário de decisões que valem para todos os sistemas

| Decisão | Recomendação | Motivo |
|---|---|---|
| Um database gigante ou vários pequenos | Vários, ligados por `Relation` | Filtro e permissão ficam granulares; view fica rápida |
| `Select` ou `Status` para andamento | `Status` | Traz agrupamento nativo em To-do / In progress / Complete e board sem configuração |
| `Person` ou `Relation` para pessoas | `Person` para quem executa; `Relation` para People database quando precisa de perfil, capacidade, histórico | `Person` é gratuito e notifica; relation dá metadados |
| Data única ou intervalo | `Date` com **End date** ligado sempre que houver timeline | Timeline exige início e fim ([Timeline view](https://www.notion.com/help/timelines)) |
| Hierarquia de tarefa | `Sub-items` nativo, não relation manual | Sub-items já vêm com exibição aninhada nas views ([Sub-items & dependencies](https://www.notion.com/help/tasks-and-dependencies)) |
| Onde colocar o database | Um database **canônico** por conceito, em local fixo; em todo lugar mais use **linked view** | Cópia duplica verdade; view não |
| Arquivamento | Propriedade `Archived` (Checkbox) + filtro, nunca deletar | Trash tem prazo e relations quebram ([Duplicate, delete & restore](https://www.notion.com/help/duplicate-delete-and-restore-content)) |

---

## 1. Task manager pessoal (GTD-ish)

### Problema

Você tem tarefa espalhada em e-mail, WhatsApp, cabeça e três apps. O custo não é escrever a tarefa: é decidir, toda manhã, o que fazer agora. Um task manager pessoal bom responde três perguntas em menos de dez segundos: *o que entrou e ainda não processei?*, *o que é pra hoje?*, *qual é a próxima ação de cada projeto parado?*

### Databases

**`Tasks`** — o único lugar onde uma ação existe.

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | — |
| `Status` | Status | To-do: `Inbox`, `Next`, `Waiting`; In progress: `Doing`; Complete: `Done`, `Cancelled` |
| `Do date` | Date | Sem hora por padrão; hora só quando é compromisso |
| `Due date` | Date | Só quando existe prazo real e externo |
| `Priority` | Select | `P1`, `P2`, `P3` |
| `Context` | Select | `@computer`, `@phone`, `@errand`, `@home`, `@deep`, `@waiting` |
| `Estimate` | Select | `5m`, `15m`, `30m`, `1h`, `2h+` |
| `Project` | Relation → `Projects` | Two-way, limite 1 página |
| `Area` | Rollup | Relation `Project` → propriedade `Area` → Show original |
| `Energy` | Select | `High`, `Medium`, `Low` |
| `Archived` | Checkbox | — |
| `Created` | Created time | — |

**`Projects`** — resultado com mais de uma ação e um fim definido.

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | — |
| `Status` | Status | To-do: `Someday`, `Planned`; In progress: `Active`, `Paused`; Complete: `Done`, `Dropped` |
| `Area` | Relation → `Areas` | Two-way, limite 1 |
| `Tasks` | Relation → `Tasks` | Lado inverso de `Tasks.Project` |
| `Open tasks` | Formula | `prop("Tasks").filter(current.prop("Status") != "Done" and current.prop("Status") != "Cancelled").length()` |
| `Next action` | Formula | `prop("Tasks").filter(current.prop("Status") == "Next").first().prop("Name")` |
| `Target date` | Date | — |
| `Outcome` | Text | Uma frase: como você sabe que acabou |
| `Archived` | Checkbox | — |

Por que fórmula e não Rollup nessas duas: **a propriedade Rollup não filtra as páginas relacionadas** — ela só agrega o que a relation já traz (`Show original`, `Count`, `Sum`, `Percent`, `Earliest date`, etc.). Não existe UI de filtro dentro do rollup. Quem precisa de "só as não-concluídas" ou "só a próxima" filtra a relation em fórmula, com `prop("Relation").filter(...)`, como em `formulas.md` ([Relations & rollups](https://www.notion.com/help/relations-and-rollups)).

**`Areas`** — responsabilidade contínua, sem data de fim (Saúde, Finanças, Carreira, Casa).

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | — |
| `Type` | Select | `Personal`, `Work` |
| `Projects` | Relation → `Projects` | Lado inverso |
| `Active projects` | Rollup | Relation `Projects` → `Status` → Count, filtrando `Active` |
| `Review cadence` | Select | `Weekly`, `Monthly`, `Quarterly` |

### Mapa de relations

| Origem | Propriedade | Destino | Tipo | Limite | Inverso |
|---|---|---|---|---|---|
| `Tasks` | `Project` | `Projects` | Two-way | 1 página | `Projects.Tasks` |
| `Projects` | `Area` | `Areas` | Two-way | 1 página | `Areas.Projects` |
| `Tasks` | Sub-items | `Tasks` (self) | Nativo | — | Parent item |

Só isso. Três databases, duas relations. Toda relation adicional aqui é peso morto — veja o arquivo de armadilhas.

### Views

| View | Layout | Filtro | Sort | Group |
|---|---|---|---|---|
| `Inbox` | List | `Status is Inbox` AND `Archived is unchecked` | `Created` ascending | — |
| `Today` | List | `Archived is unchecked` AND `Status is not Done` AND `Status is not Cancelled` AND (`Do date is on or before Today` OR `Due date is on or before Today`) | `Priority` ascending, `Do date` ascending | — |
| `Next actions` | Board | `Status is Next` AND `Archived is unchecked` | `Priority` ascending | Group by `Context` |
| `Waiting on` | Table | `Status is Waiting` | `Created` ascending | — |
| `This week` | Calendar | `Archived is unchecked` AND `Status is not Done` | — | Calendar by `Do date` |
| `By project` | Table | `Status is not Done` AND `Status is not Cancelled` | `Do date` ascending | Group by `Project` |
| `Quick wins` | List | `Estimate is 5m` OR `Estimate is 15m`, AND `Status is Next` | `Priority` ascending | — |
| `Done this week` | List | `Status is Done` AND `Last edited time is within the past week` | `Last edited time` descending | — |

Duas notas de precisão. Primeira: `Today` usa **filtro relativo** (`is on or before` → `Today`), não data fixa; filtro relativo é o que faz a view continuar certa amanhã. Segunda: `Quick wins` existe porque tarefa curta trava tanto quanto tarefa longa e você precisa de um lugar pra varrer as curtas em quinze minutos.

### Layout da página principal

```
┌──────────────────────────────────────────────────────────────┐
│  🎯  Command Center                                          │
│  ────────────────────────────────────────────────────────    │
│  [ + Capture ]  [ + Project ]      ← buttons                 │
├───────────────────────────┬──────────────────────────────────┤
│  TODAY                    │  INBOX                           │
│  (linked view: Today)     │  (linked view: Inbox)            │
│  ▸ Ligar pro contador     │  ▸ ideia sobre podcast           │
│  ▸ Revisar proposta       │  ▸ trocar pneu                   │
│  ▸ Treino                 │  [ 3 items ]                     │
├───────────────────────────┴──────────────────────────────────┤
│  NEXT ACTIONS  — board agrupado por Context                  │
│  ┌─────────┬─────────┬─────────┬─────────┐                   │
│  │@computer│ @phone  │ @errand │ @deep   │                   │
│  │ ▸ ...   │ ▸ ...   │ ▸ ...   │ ▸ ...   │                   │
│  └─────────┴─────────┴─────────┴─────────┘                   │
├──────────────────────────────────────────────────────────────┤
│  ▸ Toggle: Waiting on (5)                                    │
│  ▸ Toggle: Active projects (linked view Projects/Active)     │
│  ▸ Toggle: Weekly review checklist                           │
└──────────────────────────────────────────────────────────────┘
```

Regra do layout: o que está aberto na primeira dobra é o que você olha todo dia. O resto vai pra toggle. Página inicial que exige rolagem vira página que você não abre.

### Automações e botões

- **Button `+ Capture`** — ação *Add page to* `Tasks`, definindo `Status = Inbox`. Nada mais. O ponto de captura tem que ser mais barato que pegar um papel; se o botão pede projeto e contexto, você para de capturar ([Buttons](https://www.notion.com/help/buttons)).
- **Database automation em `Tasks`**: trigger `Property edited` → `Status` is `Done` → ação *Edit property* → `Do date = Today`. Assim `Done this week` fica confiável sem depender de `Last edited time` ([Database automations](https://www.notion.com/help/database-automations)).
- **Automation recorrente**: trigger `Every week` (segunda, 08:00) → *Add page to* `Tasks` com `Name = Weekly review`, `Status = Next`, `Context = @deep`. Automação recorrente não pode ser combinada com outro trigger.
- **Database template** em `Tasks` chamado `Errand` já com `Context = @errand` e `Estimate = 30m` ([Database templates](https://www.notion.com/help/database-templates)).

Automações de database exigem plano pago (exceto notificação de Slack) — limites de plano mudam; confirme na doc oficial antes de prometer.

### Erros comuns

1. **`Due date` em tudo.** Se toda tarefa tem prazo, nenhuma tem. Reserve `Due date` para compromisso com terceiro; use `Do date` para intenção sua. Sem essa separação, a view `Today` vira lista de mentiras e você para de confiar nela em duas semanas.
2. **Inbox que nunca esvazia.** Inbox sem ritual de processamento é caixa de entulho. Ou você tem um bloco semanal fixo pra zerar, ou não crie o status `Inbox`.
3. **`Areas` com projeto que nunca morre.** Se um "projeto" está `Active` há oito meses sem tarefa concluída, ele é uma Area disfarçada. Reclassifique.
4. **Tentar filtrar dentro do rollup.** Rollup devolve *todas* as tarefas relacionadas e o campo vira ilegível — e não há como resolver no rollup, porque ele não tem filtro, só agregação. `Next action` e `Open tasks` precisam ser fórmula com `.filter()` sobre a relation.
5. **Sub-items usado como projeto.** Sub-item serve para decompor *uma* ação em passos de execução. Assim que houver um resultado com prazo próprio, é `Projects`.
6. **Muitos `Context`.** Acima de seis contextos você não escolhe, você navega. Comece com quatro.

---

## 2. Gestão de projetos de time

### Problema

Time com mais de três pessoas perde tempo em três lugares: ninguém sabe o que é prioridade desta semana, ninguém sabe quem está sobrecarregado, e o status reportado pra fora não bate com a realidade do board. Um sistema de projetos de time precisa produzir, sem trabalho manual, um board de execução e uma timeline de compromissos que sejam a mesma verdade.

### Databases

**`Projects`**

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | — |
| `Status` | Status | To-do: `Backlog`, `Scoping`; In progress: `In progress`, `At risk`, `Blocked`; Complete: `Shipped`, `Cancelled` |
| `Owner` | Person | Uma pessoa. Sempre uma |
| `Team` | Select | `Product`, `Eng`, `Design`, `GTM`, `Ops` |
| `Dates` | Date | Com **End date** ligado |
| `Priority` | Select | `P0`, `P1`, `P2` |
| `Tasks` | Relation → `Tasks` | Two-way |
| `Progress` | Rollup | Relation `Tasks` → `Status` → **Percent per group** (ou Count completo / Count all) |
| `Task count` | Rollup | Relation `Tasks` → `Name` → Count all |
| `Summary` | Text | Uma frase de status, escrita por humano |
| `Docs` | Relation → `Wiki` | Opcional |
| `Archived` | Checkbox | — |

**`Tasks`**

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | — |
| `Status` | Status | To-do: `Backlog`, `Ready`; In progress: `In progress`, `In review`, `Blocked`; Complete: `Done`, `Won't do` |
| `Assignee` | Person | — |
| `Project` | Relation → `Projects` | Two-way, limite 1 |
| `Sprint` | Relation → `Sprints` | Two-way, limite 1 |
| `Dates` | Date | Com End date, para timeline |
| `Estimate` | Number | Pontos ou horas — escolha um e não misture |
| `Type` | Select | `Feature`, `Bug`, `Chore`, `Spike` |
| `Blocked by` / `Blocking` | Dependency | Nativo, via sub-items & dependencies |
| `Sub-items` / `Parent item` | Nativo | — |
| `ID` | ID | Prefixo `TSK` |

**`Sprints`**

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | Ex.: `Sprint 42` |
| `Dates` | Date | Início e fim |
| `Status` | Status | `Future`, `Current`, `Past` |
| `Tasks` | Relation → `Tasks` | Lado inverso |
| `Committed points` | Rollup | Relation `Tasks` → `Estimate` → Sum |
| `Completed points` | Rollup | Relation `Tasks` → `Estimate` → Sum (com filtro `Status is Done`) |
| `Goal` | Text | Uma frase |

**`People`** (opcional; só crie se precisar de capacidade e perfil)

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | — |
| `Notion account` | Person | Liga o registro à conta real |
| `Role` | Select | — |
| `Team` | Select | — |
| `Capacity` | Number | Pontos por sprint |
| `Manager` | Relation → `People` (self) | Limite 1 |

### Mapa de relations

| Origem | Propriedade | Destino | Tipo | Limite | Inverso |
|---|---|---|---|---|---|
| `Tasks` | `Project` | `Projects` | Two-way | 1 | `Projects.Tasks` |
| `Tasks` | `Sprint` | `Sprints` | Two-way | 1 | `Sprints.Tasks` |
| `Tasks` | `Blocked by` | `Tasks` (self) | Dependency nativa | — | `Blocking` |
| `Projects` | `Docs` | `Wiki` | Two-way | Sem limite | `Wiki.Projects` |
| `People` | `Manager` | `People` (self) | One-way | 1 | — |

Note que `Tasks.Assignee` é `Person`, não relation para `People`. Person notifica, filtra por "Me" e não custa manutenção. Use a relation para `People` apenas se você fizer planejamento de capacidade de verdade.

### Views

Em `Tasks`:

| View | Layout | Filtro | Sort | Group |
|---|---|---|---|---|
| `Current sprint` | Board | `Sprint → Status is Current` | `Priority` asc | Group by `Status`, Subgroup by `Assignee` |
| `My tasks` | List | `Assignee contains Me` AND `Status is not Done` | `Dates` asc | — |
| `Backlog` | Table | `Sprint is empty` AND `Status is Backlog` | `Priority` asc | Group by `Project` |
| `Blocked` | Table | `Status is Blocked` OR `Blocked by is not empty` | — | Group by `Project` |
| `In review` | List | `Status is In review` | `Last edited time` asc | — |

Em `Projects`:

| View | Layout | Filtro | Sort | Group |
|---|---|---|---|---|
| `Roadmap` | Timeline | `Archived is unchecked` AND `Status is not Cancelled` | `Dates` asc | Group by `Team`, por trimestre |
| `Board` | Board | `Archived is unchecked` | `Priority` asc | Group by `Status` |
| `At risk` | Table | `Status is At risk` OR `Status is Blocked` | `Priority` asc | — |
| `By owner` | Table | `Status is In progress` | — | Group by `Owner` |
| `Shipped` | Gallery | `Status is Shipped` | `Dates` desc | — |

Em `Sprints`: uma view `Table` com `Committed points` e `Completed points` lado a lado, sort `Dates` descending. É seu histórico de velocidade sem planilha.

Dependências só ficam visíveis e arrastáveis em **Timeline view**; é lá que você conecta as setas e configura o *date shifting* automático ([Sub-items & dependencies](https://www.notion.com/help/tasks-and-dependencies)).

### Layout da página principal

```
┌───────────────────────────────────────────────────────────────┐
│  🚀  Team HQ                     Sprint 42 · termina em 4 dias │
├───────────────────────────────────────────────────────────────┤
│  callout: 🎯 Sprint goal — "Fechar o fluxo de checkout"       │
├──────────────┬──────────────┬─────────────────────────────────┤
│  Committed   │  Completed   │  At risk projects               │
│     34 pts   │     21 pts   │      2                          │
│  (chart / number widget)    │  (linked view: At risk)         │
├──────────────┴──────────────┴─────────────────────────────────┤
│  CURRENT SPRINT — board por Status, subgroup por Assignee     │
│  ┌────────┬─────────────┬───────────┬────────┐                │
│  │ Ready  │ In progress │ In review │  Done  │                │
│  └────────┴─────────────┴───────────┴────────┘                │
├───────────────────────────────────────────────────────────────┤
│  ROADMAP — timeline de Projects, agrupada por Team            │
│  Q3 ▓▓▓▓▓▓▓░░░░  Q4 ░░░░░░                                    │
├───────────────────────────────────────────────────────────────┤
│  ▸ Blocked (3)   ▸ Backlog   ▸ Sprint archive   ▸ Rituals     │
└───────────────────────────────────────────────────────────────┘
```

Nos planos Business e Enterprise, os três blocos de cima podem virar uma **Dashboard view** dentro do próprio database, com widgets de chart e number, até 4 por linha e 12 no total ([Dashboards view](https://www.notion.com/help/dashboards)).

### Automações e botões

- **Automation em `Tasks`**: `Property edited` → `Status` is `Blocked` → *Send Slack notification to* `#eng-blockers`, com menção ao `Project` e ao `Assignee`. Bloqueio que só aparece no board é bloqueio que dura três dias.
- **Automation em `Tasks`**: `Property edited` → `Status` is `Done` → *Edit property* `Completed on = Now` (propriedade `Date` extra). Necessário porque `Last edited time` muda a cada edição irrelevante.
- **Automation recorrente em `Sprints`**: `Every 2 weeks` → *Add page to* `Sprints` criando o próximo sprint. Depois mova o `Status` na mão; automação não sabe qual é o "current".
- **Button `Roll over`** na página do sprint: *Edit pages in* `Tasks`, filtrando `Sprint is este sprint` AND `Status is not Done`, setando `Sprint = próximo`. Cuidado: essa é a automação que mais mascara problema de escopo — algumas equipes preferem fazer na mão justamente pra sentir a dor.
- **Charts** para burndown aproximado: chart view sobre `Tasks` com eixo X em `Completed on` e Y em soma de `Estimate`. Chart não plota rollup, button, ID, arquivo nem fórmula complexa nos eixos ([Chart view](https://www.notion.com/help/charts)).

### Erros comuns

1. **Sprint como `Select` em vez de database.** Vira texto solto, sem datas, sem pontos comprometidos, sem histórico. Cinco minutos economizados agora custam o retrospectivo inteiro depois.
2. **`Estimate` misturando horas e pontos.** Rollup soma tudo igual e o número fica sem significado. Escolha a unidade uma vez e escreva no topo do database.
3. **Board agrupado por `Assignee` como view principal.** Vira placar de produtividade individual e destrói colaboração. Agrupe por `Status`, subagrupe por pessoa quando precisar.
4. **Timeline sem End date.** Sem `End date` na propriedade `Date`, tudo vira um ponto e a timeline não serve pra nada.
5. **Dependências decorativas.** Se ninguém reordena trabalho por causa de uma seta, apague as setas. O Notion não recalcula caminho crítico como um MS Project.
6. **`Progress` como fórmula sobre rollup sobre relation.** É o padrão mais caro de recalcular em databases grandes. Prefira o rollup nativo de percentual por grupo, sem fórmula em cima.
7. **Projeto sem `Owner` único.** "O time é dono" significa que ninguém é. Uma pessoa por projeto, sempre.

---

## 3. Wiki / base de conhecimento de empresa

### Problema

A informação existe, mas ninguém sabe se está certa. O sintoma clássico: alguém acha um doc, segue o que está escrito, e descobre que estava desatualizado há sete meses. Wiki bom não é wiki completo — é wiki **em que dá pra confiar**, e confiança vem de dois metadados: quem é dono e até quando aquilo foi verificado.

### Estrutura

Um wiki no Notion é uma **página convertida em wiki**, não um database ([Wikis & verified pages](https://www.notion.com/help/wikis-and-verified-pages)). A conversão dá três views padrão: **Home** (visão customizável), **All pages** (view de database do conteúdo) e **Pages I own**. Toda subpágina passa a ter `Owner` e `Verification`. Database não pode ser convertido em wiki.

**`Company Wiki`** (a wiki em si)

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | — |
| `Owner` | Person | Nativa da wiki. Configure para **um** owner e para atribuir automaticamente ao criador |
| `Verification` | Verification | Nativa. Verificação com prazo, não indefinida |
| `Category` | Select | `Policy`, `How-to`, `Reference`, `Onboarding`, `Decision`, `Postmortem` |
| `Audience` | Multi-select | `Everyone`, `Eng`, `Sales`, `Managers` |
| `Tags` | Multi-select | Máximo ~15 tags no workspace inteiro |
| `Related projects` | Relation → `Projects` | Two-way |
| `Last edited` | Last edited time | — |
| `Status` | Select | `Draft`, `Published`, `Deprecated` |
| `Supersedes` | Relation → `Company Wiki` (self) | Limite 1, para páginas que substituem outras |

A `Verification` mostra check azul quando a página é @-mencionada e nos resultados de busca; ao expirar, o owner recebe aviso no inbox e por e-mail. É recurso de **Business e Enterprise**.

### Mapa de relations

| Origem | Propriedade | Destino | Tipo | Limite | Inverso |
|---|---|---|---|---|---|
| `Company Wiki` | `Related projects` | `Projects` | Two-way | Sem limite | `Projects.Docs` |
| `Company Wiki` | `Supersedes` | `Company Wiki` (self) | One-way | 1 | — |

### Views

| View | Layout | Filtro | Sort | Group |
|---|---|---|---|---|
| `Home` | Página customizada | — | — | — |
| `All pages` | Table | `Status is not Deprecated` | `Name` asc | Group by `Category` |
| `Pages I own` | Table | `Owner contains Me` | `Verification` asc | — |
| `Needs review` | Table | `Verification is expired` OR `Verification is empty` | `Last edited` asc | Group by `Owner` |
| `New this month` | Gallery | `Created time is within the past month` | `Created time` desc | — |
| `Onboarding path` | List | `Category is Onboarding` | manual | — |
| `Deprecated` | Table | `Status is Deprecated` | `Last edited` desc | — |

`Needs review` é a única view que importa de verdade. É o painel de dívida de conhecimento.

### Layout da Home

```
┌───────────────────────────────────────────────────────────────┐
│  📚  Company Wiki                                             │
│  "Se não está verificado, confirme antes de agir."            │
├───────────────────────────────────────────────────────────────┤
│  🔎  [ barra de busca — /search ou atalho ]                   │
├──────────────────┬──────────────────┬─────────────────────────┤
│  START HERE      │  POLICIES        │  HOW-TOS                │
│  ▸ Primeiro dia  │  ▸ Férias        │  ▸ Deploy               │
│  ▸ Ferramentas   │  ▸ Reembolso     │  ▸ Acesso a prod        │
│  ▸ Glossário     │  ▸ Segurança     │  ▸ Onboard cliente      │
├──────────────────┴──────────────────┴─────────────────────────┤
│  ⚠️  NEEDS REVIEW — linked view, agrupada por Owner            │
│  Ana (3)  ·  Bruno (1)  ·  Carla (5)                          │
├───────────────────────────────────────────────────────────────┤
│  ▸ Toggle: Todas as páginas (por Category)                    │
│  ▸ Toggle: Depreciadas                                        │
│  ▸ Como escrever aqui (convenções de nome, tom, tamanho)      │
└───────────────────────────────────────────────────────────────┘
```

### Automações e botões

- **Automation**: `Property edited` → `Status` is `Deprecated` → *Edit property* `Verification = none` e *Send notification to* `Owner`. Página depreciada com selo verificado é o pior estado possível.
- **Automation recorrente**: `Every month` → *Send notification to* os owners com link para a view `Needs review`. Sem lembrete, a verificação decai em silêncio.
- **Database template `New doc`**: já com `Status = Draft`, `Owner = criador` e estrutura fixa — *Para quem é este doc / O que você consegue fazer depois de ler / Passos / Quem procurar*.
- **Button `Deprecate`** na própria página: *Edit pages in* setando `Status = Deprecated`, mais *Show confirmation* antes.

### Erros comuns

1. **Wiki sem owner.** Sem dono, ninguém revisa e a confiança na wiki inteira cai — inclusive nas páginas boas.
2. **Verificação indefinida.** "Verificado para sempre" é a mesma coisa que não verificado. Use prazo (90 ou 180 dias conforme a volatilidade).
3. **Hierarquia profunda.** Cinco níveis de subpágina e ninguém acha nada. Wiki se navega por **busca e propriedade**, não por árvore. Duas camadas bastam.
4. **Deletar página velha.** Delete e você quebra links, @-menções e o histórico da decisão. Use `Status = Deprecated` + `Supersedes` apontando para a nova.
5. **Doc de projeto dentro da wiki.** Wiki é conhecimento durável. Nota de reunião e spec de projeto vivem com o projeto; só o que sobrevive ao projeto sobe pra wiki.
6. **Tags demais.** Multi-select com 60 tags é um índice quebrado. Faça um teto explícito e revise trimestralmente.
7. **Achar que wiki resolve descoberta.** Se ninguém abre a wiki, o problema é ritual (onboarding, resposta em Slack apontando para o doc), não estrutura.

---

## 4. CRM leve

### Problema

Vendas em planilha perde o contexto: você sabe o valor do deal mas não sabe o que foi conversado, quem é o decisor e o que precisa acontecer depois. CRM leve no Notion serve bem até um punhado de vendedores e ciclos de venda consultivos. Alto volume, cadência de e-mail e enriquecimento automático: use um CRM de verdade.

Este é o caso de uso onde **múltiplos data sources dentro de um mesmo database** brilham — quatro data sources (`Companies`, `Contacts`, `Deals`, `Activities`) sob um container `CRM`, cada um com schema próprio ([Data sources](https://www.notion.com/help/data-sources-and-linked-databases)).

### Databases

**`Companies`**

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | — |
| `Website` | URL | — |
| `Industry` | Select | — |
| `Size` | Select | `1-10`, `11-50`, `51-200`, `201-1000`, `1000+` |
| `Owner` | Person | Account owner |
| `Status` | Status | `Prospect`, `Active`, `Churned`, `Disqualified` |
| `Contacts` | Relation → `Contacts` | Lado inverso |
| `Deals` | Relation → `Deals` | Lado inverso |
| `Open pipeline` | Rollup | Relation `Deals` → `Amount` → Sum (filtro: não fechado) |
| `Last activity` | Rollup | Relation `Activities` → `Date` → Latest date |
| `Location` | Place ou Text | — |

**`Contacts`**

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | — |
| `Email` | Email | — |
| `Phone` | Phone | — |
| `Role` | Text | — |
| `Company` | Relation → `Companies` | Two-way, limite 1 |
| `Persona` | Select | `Champion`, `Decision maker`, `Blocker`, `User` |
| `Deals` | Relation → `Deals` | Two-way |
| `LinkedIn` | URL | — |
| `Owner` | Person | — |

**`Deals`**

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | Formato: `Empresa — o que` |
| `Stage` | Status | To-do: `Lead`, `Qualified`; In progress: `Discovery`, `Proposal`, `Negotiation`; Complete: `Won`, `Lost` |
| `Amount` | Number | Formato moeda |
| `Probability` | Number | Percentual, definido por stage |
| `Weighted` | Formula | `prop("Amount") * prop("Probability")` |
| `Close date` | Date | Expectativa, revisada toda semana |
| `Company` | Relation → `Companies` | Two-way, limite 1 |
| `Contacts` | Relation → `Contacts` | Two-way |
| `Owner` | Person | — |
| `Source` | Select | `Inbound`, `Outbound`, `Referral`, `Event`, `Partner` |
| `Next step` | Text | Obrigatório enquanto o deal está aberto |
| `Lost reason` | Select | `Price`, `Timing`, `Competitor`, `No budget`, `No decision` |
| `Activities` | Relation → `Activities` | Lado inverso |

**`Activities`**

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | — |
| `Type` | Select | `Call`, `Meeting`, `Email`, `Demo`, `Note` |
| `Date` | Date | Com hora |
| `Deal` | Relation → `Deals` | Two-way, limite 1 |
| `Contact` | Relation → `Contacts` | Two-way |
| `Company` | Rollup | via `Deal` → `Company` |
| `Owner` | Person | — |
| `Outcome` | Text | — |

### Mapa de relations

| Origem | Propriedade | Destino | Tipo | Limite | Inverso |
|---|---|---|---|---|---|
| `Contacts` | `Company` | `Companies` | Two-way | 1 | `Companies.Contacts` |
| `Deals` | `Company` | `Companies` | Two-way | 1 | `Companies.Deals` |
| `Deals` | `Contacts` | `Contacts` | Two-way | Sem limite | `Contacts.Deals` |
| `Activities` | `Deal` | `Deals` | Two-way | 1 | `Deals.Activities` |
| `Activities` | `Contact` | `Contacts` | Two-way | Sem limite | `Contacts.Activities` |

`Activities.Company` é **rollup**, não relation — a empresa se deduz do deal. Relation redundante é a principal fonte de dados contraditórios em CRM caseiro.

### Views

Em `Deals`:

| View | Layout | Filtro | Sort | Group |
|---|---|---|---|---|
| `Pipeline` | Board | `Stage is not Won` AND `Stage is not Lost` | `Amount` desc | Group by `Stage` |
| `My deals` | Table | `Owner contains Me` AND stage aberto | `Close date` asc | — |
| `Closing this month` | Table | `Close date is this month` AND stage aberto | `Close date` asc | — |
| `Stale` | Table | `Activities → Date is before 14 days ago` OR `Next step is empty` | `Amount` desc | — |
| `Won` | Table | `Stage is Won` | `Close date` desc | Group by `Source` |
| `Loss analysis` | Chart | `Stage is Lost` | — | Donut por `Lost reason` |

Em `Companies`: `All accounts` (Table, group by `Status`) e `At risk` (`Last activity is before 30 days ago` AND `Status is Active`).

Em `Activities`: `This week` (Calendar por `Date`) e `Log` (Table, sort `Date` desc, limite visual pelos filtros).

### Layout da página principal

```
┌───────────────────────────────────────────────────────────────┐
│  💼  Sales                                                    │
├───────────────┬───────────────┬───────────────────────────────┤
│ Open pipeline │ Weighted      │ Closing this month            │
│   R$ 480k     │   R$ 190k     │   6 deals                     │
├───────────────┴───────────────┴───────────────────────────────┤
│  PIPELINE — board por Stage (cards mostram Amount + Next step)│
│  ┌──────┬───────────┬──────────┬─────────────┐                │
│  │ Lead │ Discovery │ Proposal │ Negotiation │                │
│  └──────┴───────────┴──────────┴─────────────┘                │
├───────────────────────────────────────────────────────────────┤
│  🔥 STALE (sem atividade há 14 dias ou sem next step)          │
│  (linked view)                                                │
├───────────────────────────────────────────────────────────────┤
│  ▸ Accounts   ▸ Contacts   ▸ Activity log   ▸ Loss analysis   │
└───────────────────────────────────────────────────────────────┘
```

### Automações e botões

- **Form view** em `Contacts` ou `Deals` para captura de lead — formulário nativo, sem ferramenta externa; conditional logic é Business/Enterprise ([Forms](https://www.notion.com/help/forms)).
- **Automation em `Deals`**: `Property edited` → `Stage` is `Won` → *Edit property* `Close date = Today`, *Send Slack notification to* `#wins`, e *Add page to* uma database de onboarding.
- **Automation em `Deals`**: `Property edited` → `Stage` → *Edit property* `Probability` conforme o estágio. Evita que a soma ponderada dependa de disciplina humana.
- **Button `Log activity`** na página do deal: *Add page to* `Activities` com `Deal` já preenchido e `Date = Now`. Custo de log tem que ser um clique.
- **Automation**: `Property edited` → qualquer campo do deal → *Edit property* `Last touched = Now`. Melhor que `Last edited time` porque você controla o que conta.

### Erros comuns

1. **Contato sem empresa.** Depois de 300 contatos você não sabe mais quem é de onde. Torne a relation obrigatória por convenção e cheque numa view `Orphan contacts` (`Company is empty`).
2. **Não ter `Next step`.** Sem próximo passo escrito, deal aberto é deal esquecido. É o campo mais importante do CRM e o mais ignorado.
3. **`Stage` como `Select`.** Perde board nativo e agrupamento por grupo de status.
4. **Amount em texto.** Sem tipo `Number` com formato moeda, não há soma nem rollup.
5. **Registrar toda troca de e-mail como Activity.** Vira ruído. Registre o que muda a decisão: reunião, demo, objeção, proposta.
6. **Achar que o Notion vai substituir cadência de outbound.** Sequência de e-mail, dial e enriquecimento não são o forte aqui. Ver o arquivo de armadilhas.
7. **Deletar deal perdido.** Perdido é dado. `Stage = Lost` com `Lost reason` é o que constrói sua análise de perda.

---

## 5. Content calendar / pipeline editorial

### Problema

Conteúdo morre em dois pontos: pauta que nunca vira rascunho e rascunho que nunca vira publicação. O sistema precisa mostrar, ao mesmo tempo, o funil (onde cada peça está) e o calendário (o que sai quando), sem que sejam dois lugares diferentes.

### Databases

**`Content`**

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Title` | Title | — |
| `Status` | Status | To-do: `Idea`, `Approved`; In progress: `Outline`, `Drafting`, `Editing`, `Ready`; Complete: `Published`, `Killed` |
| `Channel` | Multi-select | `Blog`, `Newsletter`, `YouTube`, `LinkedIn`, `Instagram`, `Podcast` |
| `Publish date` | Date | Com hora quando o canal exige |
| `Owner` | Person | Quem escreve |
| `Editor` | Person | Quem revisa |
| `Pillar` | Select | 3 a 5 temas fixos. Nunca mais que 5 |
| `Funnel stage` | Select | `TOFU`, `MOFU`, `BOFU` |
| `Campaign` | Relation → `Campaigns` | Two-way |
| `Assets` | Relation → `Assets` | Two-way |
| `Brief` | Text ou subpágina | — |
| `Target keyword` | Text | — |
| `URL` | URL | Preenchido ao publicar |
| `Repurposed from` | Relation → `Content` (self) | Limite 1 |
| `Performance` | Number | Views, opens ou o que importa no canal |

**`Campaigns`**

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | — |
| `Dates` | Date | Com End date |
| `Goal` | Text | — |
| `Content` | Relation → `Content` | Lado inverso |
| `Pieces` | Rollup | Count all de `Content` |
| `Published` | Rollup | Count de `Content` com `Status is Published` |

**`Assets`** (imagem, thumb, corte de vídeo)

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | — |
| `File` | Files & media | — |
| `Type` | Select | `Cover`, `Thumbnail`, `Clip`, `Diagram` |
| `Content` | Relation → `Content` | Two-way |
| `Status` | Status | `Requested`, `In progress`, `Approved` |

### Mapa de relations

| Origem | Propriedade | Destino | Tipo | Limite | Inverso |
|---|---|---|---|---|---|
| `Content` | `Campaign` | `Campaigns` | Two-way | Sem limite | `Campaigns.Content` |
| `Content` | `Assets` | `Assets` | Two-way | Sem limite | `Assets.Content` |
| `Content` | `Repurposed from` | `Content` (self) | One-way | 1 | — |

### Views

| View | Layout | Filtro | Sort | Group |
|---|---|---|---|---|
| `Calendar` | Calendar | `Status is not Killed` | — | Calendar by `Publish date` |
| `Pipeline` | Board | `Status is not Published` AND `Status is not Killed` | `Publish date` asc | Group by `Status` |
| `Idea bank` | Gallery | `Status is Idea` | `Created time` desc | Group by `Pillar` |
| `My drafts` | List | `Owner contains Me` AND `Status is Drafting` | `Publish date` asc | — |
| `Needs edit` | List | `Status is Editing` | `Publish date` asc | Group by `Editor` |
| `Late` | Table | `Publish date is before Today` AND `Status is not Published` | `Publish date` asc | — |
| `Published` | Table | `Status is Published` | `Publish date` desc | Group by `Channel` |
| `By pillar` | Chart | `Status is Published` | — | Donut por `Pillar` |

`Late` é a view que faz o sistema honesto. Sem ela, todo calendário editorial vira ficção otimista.

### Layout da página principal

```
┌───────────────────────────────────────────────────────────────┐
│  ✍️  Content HQ                                                │
│  [ + Nova pauta ]   [ + Pedir asset ]                         │
├───────────────────────────────────────────────────────────────┤
│  ⏰ LATE (2)  — linked view, callout vermelho se não vazio     │
├───────────────────────────────────────────────────────────────┤
│  CALENDAR — mês corrente, cards com Channel + Owner           │
│  ┌────┬────┬────┬────┬────┬────┬────┐                         │
│  │ S  │ T  │ Q  │ Q  │ S  │ S  │ D  │                         │
│  └────┴────┴────┴────┴────┴────┴────┘                         │
├──────────────────────────────┬────────────────────────────────┤
│  PIPELINE (board por Status) │  IDEA BANK (gallery por Pillar)│
├──────────────────────────────┴────────────────────────────────┤
│  ▸ Campaigns   ▸ Assets   ▸ Published archive   ▸ Guia de tom │
└───────────────────────────────────────────────────────────────┘
```

### Automações e botões

- **Automation**: `Property edited` → `Status` is `Editing` → *Send notification to* `Editor`. Handoff explícito, não por Slack solto.
- **Automation**: `Property edited` → `Status` is `Published` → *Edit property* `Publish date = Today` se estiver vazia.
- **Automation recorrente**: `Every week` (sexta) → *Send Slack notification* com o que sai na semana seguinte.
- **Button `Request asset`**: *Add page to* `Assets` com `Content` preenchido e `Status = Requested`.
- **Database templates** por canal: `Blog post`, `Newsletter`, `YouTube script` — cada um com a estrutura de rascunho e o checklist de publicação já dentro da página.

### Erros comuns

1. **Um database por canal.** Cinco databases significa cinco calendários e zero visão. Um `Content` com `Channel` multi-select resolve.
2. **Pauta e rascunho separados.** A ideia e o texto são a mesma peça em estágios diferentes. Separar cria trabalho de transcrição.
3. **`Pillar` com 12 opções.** Pilar demais é o mesmo que nenhum: você perde a capacidade de dizer "estamos publicando pouco sobre X".
4. **Não registrar `Performance`.** Sem número, todo debate de conteúdo vira gosto pessoal. Um campo simples, preenchido 30 dias depois, muda a conversa.
5. **Calendário sem hora nos canais que dependem de hora.** Publicação de LinkedIn às 07:00 e às 22:00 não são a mesma coisa.
6. **Killed virando delete.** Pauta descartada é sinal. Mantenha com `Status = Killed` e uma linha de motivo.

---

## 6. Habit tracker e journal diário

### Problema

Rastreador de hábito falha por atrito e por vergonha. Atrito: se registrar custa mais de dez segundos, você para. Vergonha: se o sistema só mostra falha, você foge dele. O desenho precisa ser barato de alimentar e generoso de ler.

### Databases

**`Daily Log`** — uma página por dia. Esta é a decisão central: um registro diário, não um registro por hábito.

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Date` | Title (formato `2026-07-19`) | Title como data facilita ordenação e busca |
| `Day` | Date | Redundante com o title, mas necessário para Calendar view |
| `Mood` | Select | `😄`, `🙂`, `😐`, `😕`, `😩` |
| `Energy` | Select | `High`, `Medium`, `Low` |
| `Sleep` | Number | Horas |
| `Workout` | Checkbox | — |
| `Read` | Checkbox | — |
| `Meditate` | Checkbox | — |
| `No alcohol` | Checkbox | — |
| `Deep work` | Number | Minutos |
| `Score` | Formula | Soma dos checkboxes (ver abaixo) |
| `Highlight` | Text | Uma frase: o melhor do dia |
| `Gratitude` | Text | — |
| `Week` | Formula | `formatDate(prop("Day"), "YYYY-[W]WW")` |
| `Month` | Formula | `formatDate(prop("Day"), "YYYY-MM")` |

Fórmula de `Score`:

```
toNumber(prop("Workout")) + toNumber(prop("Read"))
+ toNumber(prop("Meditate")) + toNumber(prop("No alcohol"))
```

Referência de sintaxe: [Formulas](https://www.notion.com/help/formulas).

**`Habits`** (opcional — só se você troca de hábito com frequência)

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | — |
| `Cue` | Text | Gatilho concreto |
| `Target` | Text | Ex.: `5x por semana` |
| `Status` | Select | `Active`, `Paused`, `Retired` |
| `Started` | Date | — |

O `Habits` **não** se relaciona com `Daily Log`. Cada hábito ativo vira uma coluna `Checkbox` no `Daily Log`. É deliberadamente menos elegante e muito mais rápido de usar e de ler. A alternativa "normalizada" (uma linha por hábito por dia) gera 1.500 registros por ano e transforma o registro diário em quatro cliques.

### Views

| View | Layout | Filtro | Sort | Group |
|---|---|---|---|---|
| `Today` | List | `Day is Today` | — | — |
| `This month` | Calendar | — | — | Calendar by `Day` |
| `Streak table` | Table | `Day is within the past month` | `Day` desc | — |
| `Weekly` | Chart | `Day is within the past 3 months` | — | Vertical bar: X = `Week`, Y = soma de `Score` |
| `Mood over time` | Chart | `Day is within the past 6 months` | — | Line: X = `Day`, Y = count por `Mood` |
| `Highlights` | List | `Highlight is not empty` | `Day` desc | — |
| `Sleep vs energy` | Table | `Day is within the past month` | `Day` desc | Group by `Energy` |

Chart view: até 200 grupos e 50 subgrupos por vez; um ano de dias no eixo X estoura o limite, então agregue por `Week` ou `Month`.

### Layout da página principal

```
┌───────────────────────────────────────────────────────────────┐
│  🌱  Daily                            terça, 19 de julho      │
│  [ + Registrar hoje ]   ← button que cria a página do dia     │
├───────────────────────────────────────────────────────────────┤
│  HOJE (linked view: Today, layout List, propriedades visíveis)│
│  Mood 🙂 · Sleep 7 · ☑ Workout ☐ Read ☑ Meditate ☑ No alcohol │
├──────────────────────────────┬────────────────────────────────┤
│  MÊS (calendar, mostra Score)│  SCORE POR SEMANA (bar chart)  │
│  ▓▓░▓▓▓░ ▓▓▓▓░░▓ ...         │  ▁▃▅▆▅▇▄                       │
├──────────────────────────────┴────────────────────────────────┤
│  ✨ HIGHLIGHTS — últimos 30 dias                               │
├───────────────────────────────────────────────────────────────┤
│  ▸ Hábitos ativos   ▸ Journal completo   ▸ Revisão mensal     │
└───────────────────────────────────────────────────────────────┘
```

### Automações e botões

- **Automation recorrente**: `Every day` às 06:00 → *Add page to* `Daily Log` com `Day = Today`. A página do dia já existe quando você acorda; você só marca. Isso sozinho resolve metade do problema de atrito.
- **Database template `Daily`** com a estrutura do journal (três perguntas fixas) no corpo da página.
- **Button `Registrar hoje`** como alternativa se você não tem plano pago: *Add page to* `Daily Log` com `Day = Now`.
- **Automation**: `Property edited` → `Score` → nada. Não crie automação de "parabéns". Gamificação artificial cansa em duas semanas.

### Erros comuns

1. **Rastrear dez hábitos de uma vez.** Três, no máximo quatro. Dez colunas de checkbox garantem que você abandona em dez dias.
2. **Streak como fórmula.** Calcular sequência de dias no Notion exige gambiarra com rollup sobre a própria database e fica lento. Se streak importa muito pra você, use um app de hábito dedicado e deixe o Notion pro journal.
3. **Journal e hábito em databases separados.** Você abre um lugar por dia, não dois.
4. **Title livre no `Daily Log`.** `"terça produtiva"` como título destrói a ordenação. Use a data em formato ISO.
5. **Registrar retroativamente uma semana inteira.** Os dados viram invenção. Se falhou três dias, deixe vazio — vazio também é dado.
6. **Calendar view com dezenas de propriedades no card.** Ilegível. Mostre `Score` e `Mood`, nada mais.

---

## 7. Reading list / biblioteca de recursos com highlights

### Problema

Você salva coisas e nunca volta. Duas causas: não há trigger de retorno, e o conteúdo salvo é o item inteiro (um livro de 300 páginas) em vez da ideia (um parágrafo). O sistema precisa separar **fonte** de **trecho**, e ter uma via de revisitação.

### Databases

**`Library`** — a fonte.

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Title` | Title | — |
| `Type` | Select | `Book`, `Article`, `Paper`, `Video`, `Podcast`, `Course` |
| `Author` | Text ou Relation → `Authors` | Text basta até ~200 itens |
| `Status` | Status | To-do: `Inbox`, `Queued`; In progress: `Reading`; Complete: `Finished`, `Abandoned` |
| `Rating` | Select | `⭐`, `⭐⭐`, `⭐⭐⭐`, `⭐⭐⭐⭐`, `⭐⭐⭐⭐⭐` |
| `URL` | URL | — |
| `Cover` | Files & media | Usado como capa em Gallery view |
| `Topics` | Multi-select | Máx. 15 no total |
| `Started` / `Finished` | Date | — |
| `Highlights` | Relation → `Highlights` | Lado inverso |
| `Highlight count` | Rollup | Count all de `Highlights` |
| `Note to self` | Text | Por que salvei isto |
| `Source` | Select | `Recommendation`, `Newsletter`, `Search`, `Random` |

**`Highlights`** — o trecho. Este é o database que dá valor ao sistema.

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Quote` | Title | O trecho, literal |
| `Source` | Relation → `Library` | Two-way, limite 1 |
| `My note` | Text | O que **você** pensou. Campo obrigatório por convenção |
| `Topics` | Multi-select | Independente do topic da fonte |
| `Location` | Text | Página, timestamp ou seção |
| `Type` | Select | `Idea`, `Fact`, `Quote`, `Method`, `Disagreement` |
| `Used in` | Relation → `Content` | Two-way, se você tem content calendar |
| `Surfaced` | Date | Última vez que revisitou |

### Mapa de relations

| Origem | Propriedade | Destino | Tipo | Limite | Inverso |
|---|---|---|---|---|---|
| `Highlights` | `Source` | `Library` | Two-way | 1 | `Library.Highlights` |
| `Highlights` | `Used in` | `Content` | Two-way | Sem limite | `Content.Highlights` |

### Views

Em `Library`:

| View | Layout | Filtro | Sort | Group |
|---|---|---|---|---|
| `Shelf` | Gallery | `Status is not Abandoned` | `Rating` desc | Group by `Status`, card preview = `Cover` |
| `Reading now` | List | `Status is Reading` | `Started` asc | — |
| `Queue` | Table | `Status is Queued` | `Created time` asc | Group by `Type` |
| `Inbox` | List | `Status is Inbox` | `Created time` desc | — |
| `Best of` | Gallery | `Rating is ⭐⭐⭐⭐` OR `⭐⭐⭐⭐⭐` | `Finished` desc | — |
| `Finished this year` | Table | `Finished is this year` | `Finished` desc | Group by `Type` |

Em `Highlights`:

| View | Layout | Filtro | Sort | Group |
|---|---|---|---|---|
| `All highlights` | Table | — | `Created time` desc | Group by `Topics` |
| `Unprocessed` | List | `My note is empty` | `Created time` asc | — |
| `Resurface` | List | `Surfaced is before 90 days ago` OR `Surfaced is empty` | aleatório na prática: `Created time` asc | — |
| `Ideas` | Gallery | `Type is Idea` | `Created time` desc | — |
| `Unused` | Table | `Used in is empty` AND `Type is Idea` | — | Group by `Topics` |

`Unprocessed` é o coração. Highlight sem nota sua é texto de outra pessoa ocupando seu espaço.

### Layout da página principal

```
┌───────────────────────────────────────────────────────────────┐
│  📖  Library                                                  │
│  [ + Salvar item ]   [ + Highlight ]                          │
├────────────────────────────────┬──────────────────────────────┤
│  READING NOW                   │  QUEUE (5)                   │
│  ▸ Thinking in Systems  p.140  │  ▸ ...                       │
├────────────────────────────────┴──────────────────────────────┤
│  SHELF — gallery com capas, agrupada por Status                │
│  [📕][📗][📘][📙]  [📕][📗][📘][📙]                              │
├───────────────────────────────────────────────────────────────┤
│  🔁 RESURFACE — 5 highlights que você não vê há 90 dias        │
│  ▸ "..."   ▸ "..."   ▸ "..."                                  │
├───────────────────────────────────────────────────────────────┤
│  ⚠️ UNPROCESSED (12) — highlights sem sua nota                 │
├───────────────────────────────────────────────────────────────┤
│  ▸ Por tópico   ▸ Best of   ▸ Abandoned (e por quê)           │
└───────────────────────────────────────────────────────────────┘
```

### Automações e botões

- **Web Clipper** do Notion para salvar artigo direto em `Library` com `Status = Inbox`.
- **Button `+ Highlight`** dentro da página do livro: *Add page to* `Highlights` com `Source` preenchido.
- **Automation recorrente**: `Every week` → *Send notification to* você com link para `Resurface`. É o único mecanismo que faz uma biblioteca virar memória.
- **Automation**: `Property edited` → `Status` is `Finished` → *Edit property* `Finished = Today`.
- **Import** de highlights de Kindle/Readwise via CSV ([Import data into Notion](https://www.notion.com/help/import-data-into-notion)) — mas revise o `My note` na mão; importação em massa sem processamento cria 4.000 registros que ninguém lê.

### Erros comuns

1. **Highlight sem nota.** É o erro que esvazia o sistema. Sem sua interpretação, o trecho é inútil daqui a um ano.
2. **Importar 3.000 highlights de uma vez.** Volume mata curadoria. Importe um livro por vez, processando.
3. **Não ter `Abandoned`.** Livro largado com status `Reading` há oito meses envenena a view `Reading now`. Abandonar é decisão legítima; registre e siga.
4. **Topics duplicando entre `Library` e `Highlights`.** Parece redundante, mas não é: o tópico de um trecho frequentemente difere do tópico do livro. Mantenha os dois.
5. **Gallery sem capa.** Biblioteca visual sem imagem é uma tabela feia. Preencha `Cover` ou use List.
6. **Confundir com wiki.** Isto é matéria-prima, não conhecimento estabelecido. Quando um conjunto de highlights vira entendimento seu, escreva uma página nova — não linke highlight cru.

---

## 8. Meeting notes conectado a projetos e action items

### Problema

Reunião produz decisão e tarefa. Sem sistema, os dois evaporam: a decisão vira "eu lembro que a gente combinou" e a tarefa nasce órfã no Slack. A nota de reunião precisa ser o lugar onde a tarefa **nasce**, e essa tarefa precisa viver no mesmo `Tasks` de todo o resto.

### Databases

**`Meetings`**

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | Formato: `YYYY-MM-DD · Assunto` |
| `Date` | Date | Com hora |
| `Type` | Select | `1:1`, `Standup`, `Weekly`, `Kickoff`, `Retro`, `Client`, `Interview` |
| `Attendees` | Person | — |
| `Project` | Relation → `Projects` | Two-way |
| `Tasks` | Relation → `Tasks` | Two-way — action items gerados aqui |
| `Open action items` | Rollup | Relation `Tasks` → `Status` → Count (não completos) |
| `Decisions` | Text | Ou seção fixa no corpo |
| `Recording` | URL ou Files | — |
| `Follow-up sent` | Checkbox | — |

Estrutura fixa do corpo da página (via database template):

```
## Agenda
-

## Notas
-

## Decisões
- [decisão] — decidido por [quem] em [data]

## Action items
(inline linked view de Tasks filtrada por esta reunião)
```

### Mapa de relations

| Origem | Propriedade | Destino | Tipo | Limite | Inverso |
|---|---|---|---|---|---|
| `Meetings` | `Project` | `Projects` | Two-way | Sem limite | `Projects.Meetings` |
| `Meetings` | `Tasks` | `Tasks` | Two-way | Sem limite | `Tasks.Meeting` |

Repare: **não existe** um database `Action items`. Action item é `Task`. Criar um database separado é o erro nº 1 deste sistema — você fica com duas listas de coisas a fazer e passa a checar as duas.

### Views

| View | Layout | Filtro | Sort | Group |
|---|---|---|---|---|
| `Upcoming` | List | `Date is after Today` | `Date` asc | — |
| `Recent` | List | `Date is within the past 2 weeks` | `Date` desc | Group by `Type` |
| `My meetings` | Calendar | `Attendees contains Me` | — | Calendar by `Date` |
| `Open follow-ups` | Table | `Open action items > 0` | `Date` asc | Group by `Project` |
| `By project` | Table | `Date is within the past 3 months` | `Date` desc | Group by `Project` |
| `1:1s` | Table | `Type is 1:1` | `Date` desc | Group by `Attendees` |

Em `Tasks`, adicione a view `From meetings`: filtro `Meeting is not empty` AND `Status is not Done`, agrupada por `Meeting`.

### Layout da página principal

```
┌───────────────────────────────────────────────────────────────┐
│  🗓  Meetings                                                  │
│  [ + Nova reunião ]  (abre template com agenda pronta)        │
├──────────────────────────────┬────────────────────────────────┤
│  UPCOMING                    │  OPEN FOLLOW-UPS               │
│  ▸ 20/07 Kickoff Projeto X   │  ▸ Weekly 12/07 — 3 abertos    │
│  ▸ 21/07 1:1 Ana             │  ▸ Client ACME — 1 aberto      │
├──────────────────────────────┴────────────────────────────────┤
│  RECENT — últimos 14 dias, agrupado por Type                  │
├───────────────────────────────────────────────────────────────┤
│  ▸ 1:1s   ▸ Por projeto   ▸ Arquivo   ▸ Como rodar reunião    │
└───────────────────────────────────────────────────────────────┘
```

### Automações e botões

- **AI Meeting Notes** transcreve e gera resumo com pontos-chave e action items; disponível em Business e Enterprise, com limite de 10 horas por usuário por dia, e permite definir um database padrão de destino em Settings → Notion AI ([AI Meeting Notes](https://www.notion.com/help/ai-meeting-notes)). Configure esse destino como o `Meetings` — caso contrário você acumula notas soltas fora do sistema.
- **Database template `Meeting`** com a estrutura de agenda/decisões/action items e uma inline linked view de `Tasks` já filtrada.
- **Button `+ Action item`** no corpo da nota: *Add page to* `Tasks` com `Meeting` preenchido e `Status = Next`.
- **Automation**: `Property edited` → `Follow-up sent` is checked → *Send mail to* participantes com o resumo. Só se o seu time realmente manda follow-up por e-mail.
- **Automation recorrente**: `Every week` → *Add page to* `Meetings` criando a weekly, com agenda pré-preenchida.

### Erros comuns

1. **Database separado de action items.** Já dito, e vale repetir: uma só lista de tarefas no workspace inteiro.
2. **Nota sem `Project`.** Sem a relation, a nota some. Todo projeto deve poder mostrar suas reuniões numa view embutida.
3. **Transcrição sem síntese.** Transcrição de 40 minutos é ilegível. A seção "Decisões" escrita por humano é o que sobrevive. IA ajuda no rascunho; o corte é seu.
4. **Título sem data no começo.** Ordenação alfabética e busca ficam ruins. `2026-07-19 · Kickoff` funciona em qualquer contexto.
5. **1:1 com notas sensíveis em teamspace aberto.** Verifique permissão antes ([Sharing & permissions](https://www.notion.com/help/sharing-and-permissions)). Notion também suporta acesso em nível de página dentro de database, então dá pra restringir linha a linha.
6. **Reunião recorrente com uma única página infinita.** Uma página por ocorrência. Página infinita não filtra, não agrupa e vira arquivo de 4.000 linhas lento de abrir.

---

## 9. OKRs e metas trimestrais

### Problema

OKR falha por dois excessos opostos: métrica demais (30 key results que ninguém acompanha) ou vaguidão (objetivo sem número). O sistema deve tornar caro criar um KR ruim e barato atualizar um KR bom.

### Databases

**`Objectives`**

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | Qualitativo e inspirador |
| `Quarter` | Select | `2026-Q1` … `2026-Q4` |
| `Owner` | Person | Uma pessoa |
| `Team` | Select | — |
| `Level` | Select | `Company`, `Team`, `Individual` |
| `Key results` | Relation → `Key Results` | Lado inverso |
| `Progress` | Rollup | Relation `Key Results` → `Progress` → Average, exibido como barra |
| `Status` | Formula | Ver abaixo |
| `Parent objective` | Relation → `Objectives` (self) | Limite 1 |
| `Narrative` | Text | Por que este objetivo, neste trimestre |

**`Key Results`**

| Propriedade | Tipo | Configuração |
|---|---|---|
| `Name` | Title | Sempre com número |
| `Objective` | Relation → `Objectives` | Two-way, limite 1 |
| `Owner` | Person | — |
| `Start value` | Number | — |
| `Current value` | Number | Atualizado semanalmente |
| `Target value` | Number | — |
| `Progress` | Formula | Ver abaixo |
| `Confidence` | Select | `On track`, `At risk`, `Off track` |
| `Unit` | Select | `%`, `R$`, `count`, `NPS` |
| `Update cadence` | Select | `Weekly`, `Biweekly` |
| `Last update` | Date | — |
| `Projects` | Relation → `Projects` | Two-way — o trabalho que move o KR |

Fórmula de `Progress` em `Key Results`:

```
if(
  prop("Target value") - prop("Start value") == 0,
  0,
  min(1, max(0,
    (prop("Current value") - prop("Start value"))
    / (prop("Target value") - prop("Start value"))
  ))
)
```

Formate como `Percent` e mostre como barra.

Fórmula de `Status` em `Objectives` (sobre o rollup `Progress`):

```
if(prop("Progress") >= 0.7, "🟢 On track",
  if(prop("Progress") >= 0.4, "🟡 At risk", "🔴 Off track"))
```

### Mapa de relations

| Origem | Propriedade | Destino | Tipo | Limite | Inverso |
|---|---|---|---|---|---|
| `Key Results` | `Objective` | `Objectives` | Two-way | 1 | `Objectives.Key results` |
| `Key Results` | `Projects` | `Projects` | Two-way | Sem limite | `Projects.Key results` |
| `Objectives` | `Parent objective` | `Objectives` (self) | One-way | 1 | — |

Atenção ao custo: `Objectives.Progress` é rollup de fórmula em outro database, e `Objectives.Status` é fórmula sobre esse rollup. Uma camada de encadeamento é aceitável. Duas (fórmula → rollup → fórmula → rollup) já degrada visivelmente com dezenas de linhas.

### Views

Em `Objectives`:

| View | Layout | Filtro | Sort | Group |
|---|---|---|---|---|
| `This quarter` | Table | `Quarter is 2026-Q3` | `Level` asc | Group by `Team` |
| `Company level` | Gallery | `Level is Company` AND `Quarter is atual` | `Progress` desc | — |
| `Off track` | Table | `Status contains 🔴` OR `Status contains 🟡` | `Progress` asc | — |
| `History` | Table | `Quarter is not atual` | `Quarter` desc | Group by `Quarter` |

Em `Key Results`:

| View | Layout | Filtro | Sort | Group |
|---|---|---|---|---|
| `Needs update` | Table | `Last update is before 7 days ago` AND quarter atual | `Last update` asc | Group by `Owner` |
| `By confidence` | Board | `Quarter atual` (via rollup do objective) | `Progress` asc | Group by `Confidence` |
| `My KRs` | Table | `Owner contains Me` | `Progress` asc | — |
| `Progress chart` | Chart | quarter atual | — | Horizontal bar: X = `Progress`, Y = `Name` |

### Layout da página principal

```
┌───────────────────────────────────────────────────────────────┐
│  🎯  OKRs — 2026 Q3                    semana 4 de 13         │
├───────────────────────────────────────────────────────────────┤
│  callout: "Confidence é declarada semanalmente. Silêncio      │
│  conta como Off track."                                        │
├───────────────────────────────────────────────────────────────┤
│  COMPANY OBJECTIVES                                           │
│  🟢 Dobrar retenção          ████████░░  78%                  │
│  🟡 Entrar no mercado LATAM  ████░░░░░░  41%                  │
│  🔴 Reduzir custo de infra   ██░░░░░░░░  18%                  │
├──────────────────────────────┬────────────────────────────────┤
│  KRs BY CONFIDENCE (board)   │  NEEDS UPDATE (por Owner)      │
│  On track │ At risk │ Off    │  Ana (2)  Bruno (1)            │
├──────────────────────────────┴────────────────────────────────┤
│  ▸ Por time   ▸ Projetos ligados aos KRs   ▸ Trimestres       │
│  ▸ Como escrevemos OKR aqui (regras + exemplos bons e ruins)  │
└───────────────────────────────────────────────────────────────┘
```

### Automações e botões

- **Automation recorrente**: `Every week` (segunda, 09:00) → *Send Slack notification to* `#okr` com link pra `Needs update`. É o ritual que sustenta o sistema.
- **Automation**: `Property edited` → `Current value` → *Edit property* `Last update = Today`. Sem isso, `Needs update` mede a coisa errada.
- **Automation**: `Property edited` → `Confidence` is `Off track` → *Send notification to* o `Owner` do `Objective` pai.
- **Button `Check in`** na página do KR: *Show confirmation*, depois *Edit pages in* pedindo `Current value` e `Confidence`.
- **Database template `Objective`** com o narrativa pré-estruturado: *Por que agora / Como sabemos que deu certo / O que não vamos fazer*.

### Erros comuns

1. **KR sem número.** "Melhorar a experiência do usuário" não é KR. Se não há `Start value` e `Target value`, a fórmula de progresso não roda — e essa é justamente a virtude do desenho: o sistema recusa KR ruim.
2. **Mais de 3–4 KRs por objetivo.** Progresso médio de 8 KRs é ruído estatístico.
3. **`Progress` calculado por "quantas tarefas fechei".** Isso mede atividade, não resultado. Ligue `Projects` ao KR para dar contexto, mas nunca derive progresso de contagem de tarefa.
4. **Rollup de rollup.** O Notion não permite rollup de rollup ([Relations & rollups](https://www.notion.com/help/relations-and-rollups)). Se você precisa disso, materialize um valor com automação em vez de tentar contornar.
5. **Quarter como `Date`.** Filtrar trimestre com data dá trabalho e erra em bordas. `Select` com `2026-Q3` é feio e funciona.
6. **Apagar OKR do trimestre passado.** O valor do sistema aparece no terceiro trimestre, quando você compara. Arquive por filtro.
7. **OKR individual para todo mundo.** Vira avaliação de desempenho disfarçada. Comece só com `Company` e `Team`.

---

## 10. Dashboard / home pessoal que amarra tudo

Ver também: layout, colunas e hierarquia visual em [`design-de-paginas.md`](./design-de-paginas.md) (padrão *Hub page*), e as views/filtros que alimentam a home em [`views-filtros-e-agrupamento.md`](./views-filtros-e-agrupamento.md) §6.

### Problema

Você tem seis sistemas ótimos e abre nenhum. A home resolve um problema de **entrada**, não de dados: ela é onde você começa, e por isso precisa responder em cinco segundos "o que eu faço agora" — e nada mais.

### Princípio de construção

A home **não tem database próprio**. Ela é composta exclusivamente de **linked views** dos databases canônicos, mais botões de captura. Se você se pegar criando um database "Dashboard", parou de fazer dashboard e começou a fazer cópia.

Linked view: `/linked view of database` ou `/create linked view` — cria uma janela para um data source existente, com filtro e sort próprios, sem duplicar dado ([Using database views](https://www.notion.com/help/guides/using-database-views)).

### O que entra

| Bloco | Origem | Filtro |
|---|---|---|
| Botões de captura | `Tasks`, `Library`, `Daily Log` | — |
| Hoje | `Tasks` | `Do date is on or before Today` AND aberta |
| Inbox count | `Tasks` | `Status is Inbox` |
| Reuniões de hoje | `Meetings` | `Date is Today` AND `Attendees contains Me` |
| Projetos ativos | `Projects` | `Status is Active` AND `Owner contains Me` |
| KRs meus | `Key Results` | `Owner contains Me` |
| Lendo agora | `Library` | `Status is Reading` |
| Registro do dia | `Daily Log` | `Day is Today` |
| Content late | `Content` | `Publish date is before Today` AND não publicado |

Nove blocos é o teto. Cada bloco extra reduz a chance de você usar qualquer um.

### Layout

```
┌───────────────────────────────────────────────────────────────┐
│                                                               │
│   Bom dia, Maurício.        terça, 19 de julho de 2026        │
│                                                               │
│   [ + Task ]  [ + Note ]  [ + Save ]  [ ✓ Log do dia ]        │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│  ⚡ AGORA                                                      │
│  ┌─────────────────────────┬─────────────────────────────┐    │
│  │ HOJE (Tasks)            │ AGENDA (Meetings, hoje)     │    │
│  │ ▸ P1 Revisar proposta   │ 10:00 1:1 Ana               │    │
│  │ ▸ P2 Ligar contador     │ 15:00 Weekly                │    │
│  │ ▸ P2 Treino             │                             │    │
│  └─────────────────────────┴─────────────────────────────┘    │
├───────────────────────────────────────────────────────────────┤
│  📌 EM ANDAMENTO                                               │
│  ┌──────────────┬──────────────┬──────────────────────────┐   │
│  │ PROJETOS (4) │ MEUS KRs (3) │ LENDO (2)                │   │
│  └──────────────┴──────────────┴──────────────────────────┘   │
├───────────────────────────────────────────────────────────────┤
│  ▸ Inbox (3)                     ← toggle, fecha depois       │
│  ▸ Semana (calendar de Tasks)                                 │
│  ▸ Weekly review                                              │
├───────────────────────────────────────────────────────────────┤
│  🧭 SISTEMAS                                                   │
│  Tasks · Projects · Areas · Wiki · CRM · Content · Library    │
│  (linha única de links, sem ícones grandes)                   │
└───────────────────────────────────────────────────────────────┘
```

Notas de construção:

- Use **colunas** (arraste um bloco pra lateral de outro) para os pares lado a lado; em telas estreitas o Notion empilha automaticamente.
- A linha de "SISTEMAS" é um único parágrafo com links inline, não seis cards com capa. Card com imagem ocupa quatro vezes mais espaço e não navega mais rápido. Isso vale **aqui**, numa home pessoal onde os sete destinos são conhecidos de cor: o dono já sabe o que tem em cada um. A grade de callouts-como-cards de [`design-de-paginas.md`](./design-de-paginas.md) (padrão *Hub page*) é a escolha certa no caso oposto — hub de time, três a cinco destinos, gente que ainda vai descobrir o que mora ali.
- Botões ficam **acima** da primeira view. O ato mais frequente merece a melhor posição.
- Sem imagem de capa pesada. Cover de 4 MB atrasa a abertura da página que você abre 30 vezes por dia.

### Automações e botões

- **Button `+ Task`** — *Add page to* `Tasks`, `Status = Inbox`. Um campo, nada mais.
- **Button `✓ Log do dia`** — *Open page* na página do dia criada pela automação recorrente do `Daily Log`.
- **Automation recorrente** (segunda, 08:00) — cria a tarefa `Weekly review` e notifica.
- **Synced block** com "princípios do trimestre" ou algo que você quer ver todo dia, sincronizado com a wiki para editar em um lugar só ([Synced blocks](https://www.notion.com/help/synced-blocks)).
- Considere fixar essa página como **home do workspace** e usar o atalho de busca rápida para tudo o mais ([Keyboard shortcuts](https://www.notion.com/help/keyboard-shortcuts)).

### Erros comuns

1. **Dashboard com 15 linked views.** Cada linked view é uma consulta. Quinze delas fazem a home levar segundos pra pintar, e você para de abrir.
2. **Widgets externos (clima, relógio, cotação).** Custam requisição, quebram, e nenhum deles muda uma decisão sua.
3. **Duplicar a view "Today" em vez de linká-la.** Cópia diverge. Sempre linked view.
4. **Home como índice de tudo.** Índice é a sidebar e a busca. Home é decisão.
5. **Redesenhar a home toda semana.** Sintoma clássico de fuga de trabalho — está detalhado no arquivo de armadilhas.
6. **Não colocar filtro relativo.** Se algum bloco tem data fixa, a home apodrece sozinha em uma semana.
7. **Gallery com cover pesada em vez de List.** Estética que custa performance na página mais acessada do workspace.

---

## Tabela final: qual sistema montar primeiro

| Se o seu problema é | Monte | Não monte ainda |
|---|---|---|
| Esquecer compromisso e tarefa | Task manager (1) | Tudo o resto |
| Time desalinhado sobre prioridade | Projetos de time (2) | OKR |
| Perguntas repetidas no Slack | Wiki (3) | CRM |
| Vender sem perder follow-up | CRM (4) | Content calendar |
| Publicar com irregularidade | Content calendar (5) | Library |
| Não saber onde o tempo vai | Habit/journal (6) | Dashboard |
| Salvar e nunca voltar | Library (7) | Wiki |
| Reunião sem consequência | Meeting notes (8) | — |
| Trabalho sem direção | OKR (9) | Antes disso, (1) e (2) funcionando |
| Ter tudo e não usar nada | Dashboard (10) | Mais um database |

Ordem defensável para uma pessoa sozinha: **1 → 8 → 7 → 10**. Para um time: **2 → 8 → 3 → 9**. Montar todos os dez antes de usar qualquer um é o modo mais comum de desperdiçar um mês.
