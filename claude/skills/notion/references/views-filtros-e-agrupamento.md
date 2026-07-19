# Views, filtros e agrupamento

Uma database é um conjunto de dados. Uma **view** é uma pergunta feita a esses dados. Quase todo problema de "meu Notion está bagunçado" é, na verdade, um problema de views: gente demais olhando a mesma tabela crua e tentando enxergar o próprio trabalho no meio de tudo.

A regra que organiza este arquivo inteiro: **você não organiza dados no Notion movendo coisas de lugar. Você organiza criando a view certa.**

---

## 1. Os tipos de view

Hoje existem **oito** layouts. A lista mudou nos últimos anos — Chart entrou em 2024, Form também.

| View | O que ela realmente faz bem | Exige |
|---|---|---|
| **Table** | Densidade. Ver muitas propriedades de muitos itens ao mesmo tempo | — |
| **Board** | Fluxo. Mostrar em que estágio cada coisa está e mover entre estágios | Uma propriedade para agrupar |
| **Timeline** | Duração e sequência. Quem começa quando, o que colide, o que bloqueia o quê | Date com End date |
| **Calendar** | Data pontual. O que acontece em tal dia | Date |
| **List** | Leitura. Uma pilha de documentos para abrir | — |
| **Gallery** | Reconhecimento visual. Escolher pela imagem, não pelo texto | Imagem (cover, conteúdo ou Files) |
| **Chart** | Agregação. Responder "quantos" e "qual a tendência" sem exportar nada | — |
| **Form** | Entrada de dados por quem não deveria mexer na database | — |

Referências: <https://www.notion.com/help/views-filters-and-sorts> e <https://www.notion.com/help/guides/when-to-use-each-type-of-database-view>

### Table

O default e, honestamente, o certo na maioria das vezes. Se você não sabe qual view usar, é table.

O que configurar:

- **Properties** — mostrar/esconder colunas e reordenar. Esta é a alavanca mais subestimada: a mesma table com 5 colunas ao invés de 18 é uma view completamente diferente e infinitamente mais útil.
- **Wrap columns** — quebra o texto em várias linhas ao invés de truncar. Ligue quando o title for longo; desligue quando quiser densidade máxima.
- **Freeze column** — congela uma coluna (normalmente o title) para ela ficar visível durante o scroll horizontal. Obrigatório em tables com muitas propriedades.
- **Open pages in** — Side peek, Center peek ou Full page. Side peek é o padrão certo para triagem (você continua vendo a lista); full page para trabalho profundo.
- **Sub-items** — Nested in toggle ou Flattened list.
- **Calculations** no rodapé de cada coluna (ver seção 7).

**Quando NÃO usar table:** quando a pergunta é "em que pé está?" (isso é board) ou "quando?" (timeline/calendar). Table responde "o que existe", não "como vai".

### Board

Kanban. Agrupa em colunas por uma propriedade e você arrasta entre elas.

O que configurar:

- **Group by** — a propriedade que define as colunas. Deve ser **Status** em 95% dos casos. Select, Person, Multi-select e Checkbox também funcionam.
- **Card preview** — None, Page cover, Page content, ou uma propriedade Files & media.
- **Card size** — Small, Medium, Large.
- **Fit image** — ligado, a imagem inteira cabe no card; desligado, ela é cortada para preencher. Ligue quando a imagem tem informação nas bordas (screenshots, diagramas); desligue quando é decorativa (fotos).
- **Properties** visíveis no card. Segure-se: 2-4 propriedades. Um card com oito propriedades não é um card, é uma linha de tabela mal desenhada.
- **Color columns** — colore as colunas conforme as cores das opções.
- **Sub-group** — cria raias horizontais (ver seção 5).

**Quando usar board:** trabalho que atravessa estágios discretos e onde a transição é a ação principal. Sprint, pipeline de vendas, editorial.

**Quando NÃO usar board:** quando o volume por coluna passa de ~20 itens. Um board com 200 cards em "Backlog" não comunica nada e é um inferno de scroll. Nesse caso: table filtrada, ou board com um filtro que restringe o backlog aos priorizados.

Segundo antipadrão: agrupar board por Person. Vira um painel de vigilância de carga, não uma ferramenta de fluxo. Se a intenção é ver carga, use board agrupado por Status **sub-agrupado** por Person, ou um chart.

### Timeline

Gantt. Barras horizontais numa linha do tempo.

O que configurar:

- **Date property** — qual date desenha a barra. Se a propriedade tem End date, a barra tem duração; se não, vira um marco pontual.
- **Separate start and end dates** — permite usar duas propriedades Date distintas como início e fim, em vez de um range único. Útil quando `Start` e `Due date` são campos separados.
- **Zoom** — Hours, Days, Weeks, Bi-weeks, Months, Quarters, Years. O zoom certo depende do horizonte: sprint = Days; roadmap = Months ou Quarters.
- **Show table** — painel de tabela à esquerda da timeline, com as propriedades que você escolher. Combinação poderosa: você lê os dados e vê a duração no mesmo lugar.
- **Group by** — cria raias (por time, por projeto, por owner). É o que transforma uma timeline confusa numa timeline legível.
- **Dependencies** — as setas de bloqueio só aparecem aqui.
- **Sub-items** — Nested in toggle ou Flattened list.

**Quando usar:** planejamento com duração real e sequência. Roadmap, lançamento, cronograma de obra.

**Quando NÃO usar:** trabalho de fluxo contínuo sem datas de início confiáveis. Se metade dos itens não tem data, a timeline mente por omissão — ela simplesmente não os mostra. Isso é perigoso: parece completo e não é.

### Calendar

Grade de mês (ou semana).

O que configurar:

- **Show calendar as** — **Month** (padrão) ou **Week**. A view de semana é a que quase ninguém usa e é a melhor para planejamento operacional.
- **Date property** — quando há várias datas, você escolhe qual comanda o calendário. Vale ter duas views: uma por `Due date`, outra por `Published on`.
- **Properties** visíveis no card do dia — mantenha em 1 ou 2, o espaço é minúsculo.
- Início da semana (domingo/segunda) é configuração de **conta** (Settings → Preferences), não da view.

**Quando usar:** eventos e prazos pontuais que precisam ser lidos em contexto de "que dia da semana é isso".

**Quando NÃO usar:** trabalho com duração. Uma tarefa de duas semanas num calendário mensal ocupa a tela inteira e esconde o resto — isso é timeline.

### List

Uma pilha vertical de páginas, com pouquíssimas propriedades.

O que configurar: essencialmente só **quais propriedades aparecem** (à direita de cada linha) e sub-items.

**Quando usar:** conteúdo que é lido, não gerenciado. Notas de reunião, artigos de wiki, documentos, posts. A ausência de colunas é o recurso — ela sinaliza "abra isso e leia".

**Quando NÃO usar:** qualquer coisa que precise de comparação entre itens. List é a view menos informativa por pixel do Notion, propositalmente.

### Gallery

Grade de cards com imagem.

O que configurar:

- **Card preview** — `Page cover`, `Page content` (mostra o primeiro bloco; se for imagem/vídeo, ele aparece) ou uma propriedade **Files & media**.
- **Card size** — Small, Medium, Large.
- **Fit image** — mesma lógica do board. Com Fit ligado dá para reposicionar a imagem manualmente.
- **Properties** — e, detalhe elegante: dá para **esconder o próprio Name**, desligando `Name` no menu de propriedades, quando a imagem já diz tudo (moodboards, design systems).

Referência: <https://www.notion.com/help/galleries>

**Quando usar:** quando a escolha é visual. Biblioteca de assets, mood board, diretório de pessoas, catálogo de produtos, templates.

**Quando NÃO usar:** quando não há imagem. Gallery sem imagem é uma list feia que ocupa quatro vezes mais espaço. Se metade dos itens não tem cover, use list.

### Chart

Visualização agregada, nativa desde 2024.

Referência: <https://www.notion.com/help/charts>

**Tipos de gráfico:** Vertical bar, Horizontal bar, Line, Donut, Number.

| Tipo | Para que serve |
|---|---|
| **Vertical bar** | Comparar categorias; com sub-grupo, comparar duas dimensões (status × tipo) |
| **Horizontal bar** | Mesma coisa, mas quando os rótulos das categorias são longos |
| **Line** | Progressão ao longo do tempo; aceita sub-grupos para comparar séries |
| **Donut** | Composição de um todo — proporção entre poucas categorias |
| **Number** | Um único valor grande. KPI de dashboard |

**Configuração:**

- **X axis** — a dimensão categórica ou temporal (só bar e line têm eixos configuráveis; donut e number são configurados de forma diferente).
- **Y axis** — a agregação. **Count** e **Sum** são as principais; há também opção de acumulado (cumulative) para linhas.
- **Group by / sub-group** — a segunda dimensão, que vira as séries.
- **Customização:** cores, altura, linhas de grade, rótulos de dados, nomes dos eixos, legenda.
- **Interação:** hover mostra rótulos, clique faz drill-down num ponto específico, clique na legenda liga/desliga categorias.
- **Export:** PNG ou SVG.

**Limites reais:** até **200 grupos e 50 sub-grupos** por vez. No plano Free você tem **um** chart; nos pagos, ilimitado — limites de plano mudam; confirme na doc oficial.

**Quando usar:** dashboards executivos e retros. Um chart de "tarefas concluídas por semana" numa retro vale mais que dez minutos de discussão.

**Quando NÃO usar:** para responder pergunta que uma calculation de rodapé já responde. Se você quer "quantos itens abertos", isso é um `Count` no rodapé de uma table, ou um Number chart — não um donut.

Segundo antipadrão: chart sobre dados sujos. Um gráfico de "tarefas por prioridade" onde 60% está sem prioridade é pior que nenhum gráfico, porque parece autoridade.

### Form

Um formulário público ou interno que grava direto na database.

Referência: <https://www.notion.com/help/forms>

Criação: `+` ao lado das views → **Form**. As respostas caem, por padrão, numa table view chamada **Responses**.

Configuração relevante:

- Cada propriedade vira uma pergunta. Tipos suportados incluem single-select, multi-select, text, date, person, files & media, number, entre outros.
- Por pergunta (`•••`): **Required** e **Description**.
- **Share form** → **Who can fill out**: `Anyone at {workspace} with link` ou `Anyone on the web with link`.

**Quando usar:** intake. Pedido de acesso, solicitação de design, report de bug por não-técnicos, inscrição em evento. O valor é que você recebe dados **estruturados** de gente que nunca deveria ter permissão de editar a database.

**Quando NÃO usar:** para o próprio time preencher no dia a dia. Um form adiciona fricção e esconde o contexto do que já existe. O time deve criar itens direto na database, preferencialmente por template ou button.

---

## 2. Filtros

Onde a maior parte do valor mora.

### Simple filters

Selecione propriedade e critério. Rápido, encadeado com AND implícito.

Detalhe crucial pós-2025: filtros criados rapidamente são **pessoais por padrão** — só afetam o que você vê. Para aplicá-los à view para todo mundo, clique em **Save for everyone**.

Isso é uma mudança de comportamento importante. Antes, alterar um filtro numa view compartilhada bagunçava a visão de todo o time em tempo real. Agora você pode explorar sem medo. Mas também significa que, se você configurou um filtro e o time não está vendo, provavelmente você esqueceu de salvar.

### Advanced filters

Permitem **filter groups** com lógica AND/OR aninhada em até **três camadas**.

Para converter um filtro simples: `•••` no filtro → **Add to advanced filter**.

Exemplo de estrutura de três camadas, para "meu trabalho relevante desta semana":

```
Status is not Complete
AND
( Assignee is Me  OR  Reviewer is Me )
AND
( Due date is within next week
  OR ( Priority is P0 AND Status is not Backlog ) )
```

**Erro comum:** empilhar OR no nível raiz. `A OR B AND C` no Notion não é ambíguo (ele exige que você agrupe), mas gente cria grupos errados e depois não entende por que a view mostra o mundo inteiro. Quando um filtro não faz sentido, leia-o de dentro para fora, grupo por grupo.

Segundo erro: filtro com dez condições. Isso quase sempre significa que faltou uma propriedade. Se você filtra por seis Selects para chegar em "trabalho ativo do meu time", crie uma fórmula booleana `Is active` e filtre por ela. Um filtro legível é um filtro que sobrevive.

### Filtros por data relativa

O que torna uma view perene em vez de precisar de manutenção manual. As opções relativas de Date incluem: `Today`, `Tomorrow`, `Yesterday`, `One week ago`, `One week from now`, `One month ago`, `One month from now`, além de `Is before`, `Is after`, `Is on or before`, `Is on or after`, `Is within` (com janelas como "the past week", "the next month") e `Is empty` / `Is not empty`.

As janelas de `Is within` são **relativas a hoje**, não a um calendário:

| Filtro | O que cobre de verdade |
|---|---|
| `is Today` / `Tomorrow` / `Yesterday` | Um dia só |
| `is within the past week` | Os 7 dias que terminam hoje |
| `is within the next week` | Os 7 dias que começam hoje |
| `is within the past month` / `the next month` | 30 dias móveis para trás / para frente |
| `is within the past year` / `the next year` | 365 dias móveis |
| `is on or before Today` | Tudo até hoje, inclusive atrasado |

**Não existe filtro nativo de "semana corrente" (seg–dom).** `the next week` é uma janela móvel de 7 dias a partir de hoje: na quinta-feira ela já invadiu a semana seguinte. Três saídas, em ordem de custo:

1. **Aceitar a janela móvel.** Para trabalho pessoal ela costuma ser melhor mesmo — o que importa é "os próximos 7 dias", não onde o domingo cai.
2. **Calendar ou Timeline em modo semana.** A view desenha a semana calendário sem filtro nenhum. É a resposta certa quando o recorte semanal é para *olhar*, não para filtrar.
3. **Fórmula de início de semana**, quando você precisa mesmo filtrar/agrupar por semana calendário. Propriedade Checkbox `Esta semana`:

```
lets(
  inicio, dateSubtract(today(), mod(day(today()) + 6, 7), "days"),
  fim, dateAdd(inicio, 6, "days"),
  d, prop("Do date"),
  not empty(d)
    and dateBetween(d, inicio, "days") >= 0
    and dateBetween(d, fim, "days") <= 0
)
```

`day()` devolve o dia da semana com 0 = domingo, daí o `mod(day(today()) + 6, 7)` para ancorar na segunda ([`formulas.md`](./formulas.md)). Trocando por `mod(day(today()), 7)` a semana passa a começar no domingo.

**Nunca** codifique uma data fixa num filtro de view recorrente. `Due date is before 2026-08-01` funciona por dez dias e depois mente para sempre.

**Combinação que vale ouro:** `Due date is on or before Today` **AND** `Status is not Complete` = atrasados + de hoje. Esta é a única lista que a maioria das pessoas realmente precisa ver de manhã.

### Filtros vinculados à pessoa atual

Filtros de propriedade **Person** aceitam o valor especial **Me**, avaliado por quem está olhando.

Isso significa que **uma única view serve o time inteiro**. `Assignee contains Me` numa view chamada "Minhas tarefas" mostra coisas diferentes para cada pessoa, sem duplicação.

Isso é o antídoto para o antipadrão mais caro do Notion: criar uma view por pessoa. Com dez pessoas você tem dez views que precisam ser mantidas em sincronia manualmente e que ninguém atualiza quando alguém entra ou sai.

Complemento: `Created by is Me` para "coisas que eu abri" e `Last edited by is Me` para "onde eu mexi por último".

---

## 3. Sorts

Ordenação em múltiplos níveis, arrastáveis para reordenar a precedência.

Comportamento por tipo: texto ordena alfabeticamente, números numericamente, e **Select/Multi-select/Status ordenam pela ordem em que você definiu as opções** — não alfabeticamente. Isso é um recurso, não um bug: arraste as opções de Priority para `P0, P1, P2, P3` e o sort passa a ser semanticamente correto.

**Sorts de três níveis que funcionam:**

| Contexto | Sort |
|---|---|
| Lista de trabalho diário | 1. Due date ascending · 2. Priority ascending · 3. Created time ascending |
| Backlog priorizado | 1. Priority ascending · 2. Score (formula) descending · 3. Created time ascending |
| Inbox de triagem | 1. Created time descending (o mais novo primeiro) |
| Biblioteca de docs | 1. Last edited time descending |

**Erro comum:** ordenar por `Last edited time descending` numa lista de trabalho. Parece útil ("o que está quente"), mas a ordem muda toda hora e ninguém consegue formar memória espacial da lista. Reserve para bibliotecas.

**Detalhe importante:** aplicar um sort a uma view **desabilita** o arraste manual naquela view. Se a ordem manual é a informação (uma lista de prioridade curada), não coloque sort nenhum.

---

## 4. Group by

Agrupar quebra a view em seções por valor de propriedade. Funciona em table, board, list, gallery e timeline.

Opções ao agrupar:

- **Sort groups** — manual, ascendente ou descendente.
- **Hide empty groups** — esconde grupos sem itens. Ligue em quase tudo; grupos vazios são ruído. Exceção: no board, colunas vazias são úteis porque você precisa de um lugar para arrastar o card.
- **Group by date** — quando o grupo é uma Date, você escolhe a granularidade: dia, semana, mês, ano, e também **relativa** (Today, Tomorrow, Last week...). Agrupar por data relativa é o segredo de uma view "próximos dias" legível.

**O que agrupar por quê:**

| Agrupar por | Resultado |
|---|---|
| Status | Kanban (em board) ou table seccionada por estágio |
| Person | Carga por pessoa — bom para planning, ruim para uso diário |
| Date (por semana) | Planejamento de curto prazo |
| Project (relation) | Trabalho contextualizado por projeto |
| Formula booleana | Bipartição customizada ("Atrasado" / "No prazo") |

**Erro comum:** agrupar por uma propriedade de alta cardinalidade. Agrupar 400 tarefas por `Due date` no nível de **dia** produz 200 grupos de duas linhas. Use granularidade de semana.

---

## 5. Sub-group

Uma segunda camada de agrupamento, aninhada dentro da primeira. Disponível em board e table.

No **board**, sub-group cria raias horizontais: colunas = grupo, linhas = sub-grupo. A matriz mais útil que existe:

- Group by `Status` · Sub-group by `Person` → quem está com o quê, em que estágio. Este é o board de daily.
- Group by `Status` · Sub-group by `Priority` → onde os P0 estão travados.
- Group by `Sprint` · Sub-group by `Status` → progresso comparado entre sprints.

**Quando NÃO usar sub-group:** quando qualquer uma das duas dimensões tem mais de ~8 valores. A matriz vira ilegível rápido. Se você precisa de mais dimensões, isso é um chart, não um board.

---

## 6. Linked database views

A peça mais subutilizada do Notion, por larga margem.

Uma **linked view** é uma view de uma database que existe em outro lugar. Você a insere com `/linked` (ou `/create linked view of database`) em qualquer página. Ela mostra os mesmos dados vivos, mas com **filtros, sorts, grupos e propriedades visíveis independentes** — e, como a documentação afirma, "views, filters, sorts, and groups you create and delete will not affect the views on the original database".

Traduzindo: **você pode montar quantas visões quiser, onde quiser, sem tocar na database original nem duplicar dado.**

Referência: <https://www.notion.com/help/data-sources-and-linked-databases> e <https://www.notion.com/help/guides/using-database-views>

### Por que isso muda tudo

Sem linked views, o instinto é criar uma database nova toda vez que um contexto novo aparece. Aí você tem `Tasks`, `Tasks do time de design`, `Tarefas do projeto X`, e nenhuma conversa entre elas.

Com linked views, existe **uma** `Tasks` e N janelas para ela. A página do projeto X tem uma linked view filtrada por `Project is X`. A home do time de design tem uma linked view filtrada por `Team is Design`. Minha página pessoal tem uma filtrada por `Assignee is Me`. O dado é um só.

### Montando um dashboard de verdade

Ver também: layout e hierarquia visual da home em [`design-de-paginas.md`](./design-de-paginas.md) (padrão *Hub page*), e a regra de construção — home não tem database próprio, teto de ~9 blocos — em [`sistemas-prontos.md`](./sistemas-prontos.md) §10.

Um dashboard no Notion é, quase inteiramente, uma coleção de linked views bem filtradas. Receita para uma "Home" pessoal:

1. **Hoje** — linked view de `Tasks`, list, filtro `Assignee is Me` AND `Do date is on or before Today` AND `Status is not Complete`, sort por Priority.
2. **Esta semana** — mesma database, table, filtro `Assignee is Me` AND `Do date is within the next week`, group by `Do date` (granularidade dia).
3. **Meus projetos** — linked view de `Projects`, gallery, filtro `Owner is Me` AND `Status is Active`, card preview = Page cover.
4. **Aguardando** — linked view de `Tasks`, list, filtro `Created by is Me` AND `Assignee is not Me` AND `Status is not Complete`. Esta é a view que ninguém cria e que resolve metade dos follow-ups esquecidos.
5. **Números** — linked view de `Tasks` em Chart (Number), Count com filtro de atrasados. Um único número vermelho.

As views de trabalho diário filtram por **`Do date`** (quando *você* decidiu fazer), não por `Due date` (prazo com terceiro). Filtrar o dia a dia por `Due date` obriga a inventar prazo para tudo, e a view `Today` vira uma lista em que você para de acreditar — a distinção está detalhada em [`sistemas-prontos.md`](./sistemas-prontos.md), erros comuns do blueprint GTD. `Due date` continua sendo o filtro certo para a view de atrasados (item 5).

Note que nenhuma dessas cinco criou dado novo. É tudo a mesma `Tasks`.

### Detalhes que pegam as pessoas

- Linked views respeitam a **permissão da database original**. Se o leitor não tem acesso à `Tasks`, ele vê um bloco vazio. Isso não é um bug — não dá para usar linked view como mecanismo de compartilhamento parcial.
- Editar o **título, as propriedades ou as páginas** através de uma linked view **altera a fonte**. Só a *configuração de view* é independente. Renomear uma propriedade numa linked view renomeia para todo mundo.
- Uma linked view pode apontar para uma data source específica de uma database com múltiplas data sources.

---

## 7. Calculations (agregações no rodapé)

No rodapé de cada coluna de uma table (e no cabeçalho de cada grupo, quando há grouping) você pode escolher um cálculo. Passe o mouse na base da coluna → **Calculate**.

Opções, por família:

| Família | Opções |
|---|---|
| Contagem | Count all, Count values, Count unique values, Count empty, Count not empty, Percent empty, Percent not empty |
| Numérico | Sum, Average, Median, Min, Max, Range |
| Data | Earliest date, Latest date, Date range |
| Checkbox | Checked, Unchecked, Percent checked, Percent unchecked |

Isso é a mesma família de cálculos dos rollups, e vale a mesma lógica.

**Uso mais valioso e menos praticado:** com `Group by Status` ativo e `Sum` de `Estimate` no rodapé, você lê o esforço por estágio direto na table. Isso é capacity planning sem planilha.

Outro: `Percent checked` numa coluna de checkbox agrupada por sprint = burndown grosseiro, de graça.

---

## 8. Locked views e lock de database

Dois travamentos diferentes, frequentemente confundidos:

| Trava | O que impede | Onde |
|---|---|---|
| **Lock view** | Impede alterar filtros, sorts, grupos e propriedades daquela view | `•••` da view → Lock |
| **Lock database** | Pessoas ainda inserem dados, mas não mudam views nem propriedades | Menu de settings da database → Lock database |

Nenhum dos dois é uma trava de permissão — qualquer editor pode destravar. É um **freio de mão contra acidente**, não segurança.

**Quando travar:** qualquer view compartilhada que é usada em ritual (o board da daily, o roadmap que vai para a diretoria, o dashboard da home do time). Sem trava, alguém vai "ajustar rapidinho um filtro" às 9h e o board da daily vai amanhecer errado.

**Quando não travar:** views pessoais e de exploração. Trava demais gera pedidos de destravar e as pessoas param de usar.

Configurações de database: <https://www.notion.com/help/customize-your-database>

---

## 9. Padrões prontos

Configurações exatas. Copie e ajuste os nomes das propriedades.

### "Minhas tarefas de hoje"

Uma view, todo o time, zero manutenção.

```
Database: Tasks
Layout:   List
Filter:   Assignee            contains  Me
   AND    Status              is not    Complete   (grupo Complete inteiro)
   AND    ( Due date          is on or before  Today
             OR  Priority     is        P0 )
Sort:     1. Due date   ascending
          2. Priority   ascending
Properties visíveis: Due date, Priority, Project
Group by: nenhum
```

Por que list e não table: esta view é para ser lida em cinco segundos e clicada. Colunas atrapalham.

Por que `Priority is P0` no OR: um P0 sem data ainda precisa aparecer. Sem essa cláusula, urgências sem prazo somem.

### "Board de sprint"

```
Database: Tasks
Layout:   Board
Filter:   Sprint    is        Current sprint   (ou Sprint is not empty + relation ao sprint ativo)
   AND    Status    is not    Cancelled
Group by:     Status          (hide empty groups: OFF — precisa das colunas para arrastar)
Sub-group by: Assignee        (hide empty groups: ON)
Sort:     1. Priority ascending
Card preview: None
Card size:    Small
Properties no card: Assignee, Estimate, Due date  (máximo 3)
Calculations: Sum de Estimate por grupo
Lock view:    ON
```

Sub-group por Assignee é o que faz esse board valer a daily: em vez de "temos 14 coisas em progresso", você vê "o Pedro tem 5 em progresso".

`Card preview: None` e `Card size: Small` são deliberados — num board de sprint, densidade é a virtude.

### "Roadmap trimestral"

```
Database: Projects
Layout:   Timeline
Date property: Dates  (range: start + end)
Zoom:     Months  (ou Quarters se o horizonte for anual)
Filter:   Status    is not    Complete
   AND    Status    is not    Cancelled
   AND    Dates     is within the next 6 months   (ou is not empty)
Group by: Team      (raias horizontais por time)
Show table: ON — colunas: Name, Owner, Status
Dependencies: ON
Sort:     1. Dates ascending
Lock view: ON
```

`Group by Team` é o que separa um roadmap útil de um espaguete. Sem raias, dez projetos paralelos viram uma sopa de barras.

Cuidado declarado: itens **sem data não aparecem**. Mantenha, ao lado, uma table de `Projects sem data` como rede de segurança — senão a timeline vai parecer completa enquanto esconde metade do trabalho.

### "Backlog priorizado"

```
Database: Tasks
Layout:   Table
Filter:   Status   is        Backlog        (ou: Status is To-do group)
   AND    Sprint   is empty
   AND    Archived is        Unchecked
Sort:     1. Priority       ascending
          2. Score          descending      (fórmula: valor ÷ esforço, ver formulas.md)
          3. Created time   ascending
Group by: Priority   (hide empty groups: ON)
Properties: Name, Priority, Estimate, Score, Project, Created time
Freeze column: Name
Calculations: Count all por grupo · Sum de Estimate por grupo
```

O `Sum de Estimate` por grupo de prioridade responde a pergunta que importa em refinamento: "temos 340 pontos de P1 no backlog e a velocidade é 40 por sprint". Isso encerra discussões.

`Created time ascending` como terceiro sort é o desempate justo — o que está esperando há mais tempo sobe.

### "Aguardando resposta"

A view que quase ninguém cria e que economiza mais tempo por linha configurada.

```
Database: Tasks
Layout:   List
Filter:   Created by  is        Me
   AND    Assignee    is not    Me
   AND    Status      is not    Complete
   AND    Last edited time  is before  One week ago
Sort:     1. Last edited time ascending
Properties: Assignee, Due date, Last edited time
```

O `Last edited time is before One week ago` é o truque: só aparece o que está genuinamente parado.

### "Faxina" (higiene de database)

```
Database: qualquer
Layout:   Table
Filter:   Last edited time  is before  Three months ago   (ou One month ago)
   AND    Status            is not     Complete
Sort:     1. Last edited time ascending
Properties: Name, Status, Assignee, Last edited time, Created time
```

Rode isso uma vez por mês. Tudo que aparece aqui ou volta a viver ou é arquivado. Databases apodrecem porque ninguém tem uma view que mostre o apodrecimento.

### "Dashboard de diretoria"

Página com quatro linked views, sem nenhuma table crua:

1. Chart **Number** — Count de `Projects` com `Status is At risk`. Um número.
2. Chart **Vertical bar** — `Projects` no eixo X por `Team`, Y = Count, sub-group por `Status`.
3. Chart **Line** — `Tasks` concluídas por semana (X = `Completed on` agrupado por semana, Y = Count, cumulative se quiser burnup).
4. Timeline de `Projects` filtrada por `Status is Active`, zoom Quarters, group by Team, **locked**.

Regra desse tipo de página: **zero interação necessária**. Se o leitor precisa filtrar algo para entender, o dashboard falhou.

---

## 10. Erros de view mais caros

| Erro | Custo | Correção |
|---|---|---|
| Uma view por pessoa | Manutenção linear no tamanho do time | Filtro `is Me` numa view só |
| Database nova em vez de linked view | Dados divergentes, nenhum rollup possível | Linked view da database canônica |
| Nenhum filtro na view padrão | Ninguém acha nada, todos criam a própria database | Filtre a view padrão para "trabalho ativo" |
| Data fixa no filtro | A view mente a partir da semana seguinte | Filtros de data relativa |
| Board com 200 cards numa coluna | Board inutilizável | Filtro que restringe o backlog visível |
| Timeline como fonte de verdade | Itens sem data desaparecem sem aviso | View companheira de "sem data" |
| Views compartilhadas destravadas | Alguém quebra o ritual do time | Lock view |
| Todas as propriedades visíveis | Ruído, scroll horizontal infinito | 4-6 propriedades por view |

---

## Leituras oficiais

- Views, filtros, sorts e grupos: <https://www.notion.com/help/views-filters-and-sorts>
- Quando usar cada tipo de view: <https://www.notion.com/help/guides/when-to-use-each-type-of-database-view>
- Usando database views: <https://www.notion.com/help/guides/using-database-views>
- Table view: <https://www.notion.com/help/tables>
- Board view: <https://www.notion.com/help/boards>
- Timeline view: <https://www.notion.com/help/timelines>
- Calendar view: <https://www.notion.com/help/calendars>
- List view: <https://www.notion.com/help/lists>
- Gallery view: <https://www.notion.com/help/galleries>
- Chart view: <https://www.notion.com/help/charts>
- Forms: <https://www.notion.com/help/forms>
- Data sources e linked databases: <https://www.notion.com/help/data-sources-and-linked-databases>
- Sub-items e dependencies: <https://www.notion.com/help/tasks-and-dependencies>
- Configurações de database: <https://www.notion.com/help/customize-your-database>
