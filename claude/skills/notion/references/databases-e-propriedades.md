# Databases e propriedades

Este arquivo cobre o modelo de dados do Notion e cada tipo de propriedade. A tese central: **a maior parte dos workspaces ruins não sofre de falta de recursos, sofre de modelagem errada.** Gente cria vinte databases quando precisava de duas, ou enfia tudo numa database só quando precisava separar. Antes de escolher um tipo de propriedade, decida o que é uma "linha" no seu sistema.

---

## 1. O modelo de dados atual (pós-setembro/2025)

Desde a atualização de 2025, o Notion tem **três** conceitos que muita gente ainda confunde, e boa parte do conteúdo que você encontra na internet está desatualizado porque foi escrito quando só existiam dois.

| Conceito | O que é | Analogia relacional |
|---|---|---|
| **Database** | O bloco/container que aparece na página. É o que você vê, o que tem abas de views, o que você compartilha. | O "schema" ou o arquivo de banco |
| **Data source** | Um conjunto de páginas com um schema de propriedades próprio. Toda database tem pelo menos uma. | A tabela |
| **Page (item)** | Uma página que vive dentro de uma data source. Tem propriedades e um corpo de página. | A linha (mas com um documento inteiro dentro) |

A novidade que quebra o modelo mental antigo: **uma database pode conter múltiplas data sources**, cada uma com seu próprio conjunto de propriedades. Antes de 2025, database e data source eram a mesma coisa e a distinção nem existia na UI.

Para gerenciar isso: clique no ícone de sliders no topo da database → **Manage data sources** → **Add data source** (cria uma nova) ou **Link existing data source** (aponta para uma que já existe em outro lugar).

Documentação: <https://www.notion.com/help/data-sources-and-linked-databases>

### Quando usar múltiplas data sources numa database

Os casos que a própria Notion cita e que realmente se sustentam:

- **CRM**: contacts, companies, deals e activities num único bloco, alternando por abas. O usuário final vê "o CRM", não quatro databases espalhadas.
- **Gestão de projetos**: team members, projects, tasks e resources num container só.
- **Recruiting**: candidates, open roles, departments, interview schedules.

O padrão comum aos três: são entidades **distintas** (schemas diferentes, não dá para unificar) mas que são **consumidas juntas** pela mesma pessoa, no mesmo momento, no mesmo lugar.

### Quando NÃO usar múltiplas data sources

Não use como substituto de organização de página. Se as entidades são consumidas em momentos diferentes por pessoas diferentes, agrupá-las num bloco só só cria uma navegação de abas gorda que ninguém entende. Duas databases separadas na mesma página, com títulos claros, comunicam melhor.

Também não use para agrupar coisas que deveriam ser **uma** data source com uma propriedade `Type`. Se "Bugs" e "Features" têm 90% das propriedades iguais, isso é uma data source `Work items` com um select `Type`, não duas data sources. A regra: **schemas diferentes justificam data sources diferentes; schemas iguais com rótulos diferentes justificam um select.**

### Permissões e o pegadinha do compartilhamento

Aqui há duas camadas que não coincidem, e as fontes oficiais divergem. **Pela API**, permissão é no nível do *database*, não da data source: a doc de upgrade diz literalmente que "user and bot permissions are managed at the database level, not per data source" e que o nível de acesso de um usuário ou conexão é o mesmo em todas as data sources do container ([Upgrade FAQs 2025-09-03](https://developers.notion.com/docs/upgrade-faqs-2025-09-03)). **Na UI**, o menu Share aparenta expor algum controle por data source — não confirmado por fonte oficial direta. Na dúvida, verifique no seu próprio workspace em vez de assumir qualquer um dos dois comportamentos.

Independente de qual camada vale no seu caso, a recomendação prática não muda: se o time de vendas deve ver `Deals` mas não `Compensation`, faça duas databases separadas. Depender de granularidade de permissão dentro de um container para proteger dado sensível é frágil demais para o risco envolvido.

Além disso, quando você compartilha uma página que contém linked data sources, quem recebe precisa ter acesso à database original para ver o conteúdo. Não existe "compartilhar só a view".

### Inline vs full-page database

| | Inline | Full-page |
|---|---|---|
| O que é | Um bloco dentro de uma página existente | Uma página cujo conteúdo inteiro é a database |
| Tem título editável na página | Sim, junto com outro conteúdo | O título da página é o título da database |
| Aparece na sidebar | Não (a página pai aparece) | Sim, como item próprio |
| Quando usar | Databases auxiliares, dashboards, listas de apoio dentro de um doc | A database "de verdade", a fonte canônica dos dados |

O erro comum é o inverso: criar tudo inline dentro de uma página de projeto, e seis meses depois não conseguir achar onde a database mora. **Regra prática:** toda database que é fonte de verdade (Tasks, Projects, People, Clients) deve ser full-page e viver num lugar estável. Tudo que aparece em outros lugares deve ser *linked view* daquela, nunca uma cópia inline nova.

Converter é trivial: clique nos `•••` do bloco → **Turn into page** / **Turn into inline**.

---

## 2. Todos os tipos de propriedade

Referência oficial: <https://www.notion.com/help/database-properties>. Limite: **500 propriedades por database**.

### Title

A primeira coluna, obrigatória, não removível, não duplicável. É o nome da página. Sempre existe, mesmo que você a renomeie de "Name" para "Task" ou "Cliente".

**Quando é a escolha certa:** você não escolhe, ela é imposta. Mas você escolhe *o que colocar nela*.

**Erro comum:** usar o title como campo estruturado. `[P1] 2026-03 — Refatorar auth (Maurício)` é um antipadrão gritante. Cada um desses pedaços deveria ser uma propriedade: priority, date, assignee. O title deve ser a frase que um humano diria em voz alta para se referir àquilo. Se você está usando separadores no title, você está simulando propriedades em texto e perdendo filtro, sort, group e rollup.

### Text

Texto rich-formatted, livre. Aceita negrito, itálico, links, menções.

**Quando é certo:** conteúdo genuinamente livre e não-agregável — uma nota curta, um resumo, um endereço não normalizado, um ID externo.

**Erro comum:** usar Text onde deveria ser Select. Se o campo tem um conjunto finito e conhecido de valores, e você digita eles à mão, você garantiu que vai ter "Em andamento", "em andamento" e "Em Andamento " como três valores distintos. Text é o campo onde os dados vão morrer.

Segundo erro: usar Text para conteúdo longo. Se é mais que uma frase ou duas, isso pertence ao **corpo da página**, não a uma propriedade. Propriedade é metadado, corpo é conteúdo.

### Number

Aceita valores numéricos, com opções de formatação relevantes.

**Formatos disponíveis:** Number, Number with commas, Percent, e uma lista longa de moedas (Dollar, Euro, Pound, Yen, Real, Yuan, Rupee, Won, Franc, Peso, etc.).

**Modos de exibição (Show as):**

| Modo | O que mostra | Quando usar |
|---|---|---|
| **Number** | O número cru | Padrão. Valores, contagens, orçamentos |
| **Bar** | Barra de progresso horizontal | Percentuais e progressões lineares — "% concluído", "orçamento consumido" |
| **Ring** | Anel/donut | O mesmo que Bar, mas compacto — bom em gallery e board cards |

Bar e Ring pedem um **Divide by** (o denominador, ex.: 100) e permitem escolher cor e mostrar/esconder o número.

**Quando é certo:** qualquer coisa que você vai somar, tirar média, ordenar numericamente ou usar em rollup.

**Erro comum #1:** guardar valor monetário como Text para "manter o formato". Você perde soma, média e sort. Use Number com formato de moeda.

**Erro comum #2:** usar Number com Bar para progresso e preencher à mão. Progresso quase sempre é derivado (subtarefas concluídas / total), então deveria ser uma **Formula** com Bar, não um Number digitado que ninguém atualiza.

### Select

Uma opção de uma lista fechada. Cada opção tem cor.

**Quando é certo:** dimensão categórica **mutuamente exclusiva** e de cardinalidade baixa (até ~15 opções). Priority, Type, Category, Environment.

**Erro comum:** usar Select para status de fluxo de trabalho. Existe um tipo dedicado (Status) que dá grupos, ordenação semântica e integração melhor com board. Use Status.

Segundo erro: deixar todo mundo criar opção nova. Select permite que qualquer editor crie uma opção digitando. Em duas semanas você tem `Bug`, `bug`, `Bugs` e `🐛 Bug`. Trate a lista de opções como schema: defina, documente, e faça faxina periódica.

### Multi-select

Zero ou mais opções de uma lista fechada.

**Quando é certo:** tags genuinamente múltiplas e não hierárquicas — `Skills`, `Topics`, `Platforms afetadas`.

**Quando NÃO usar (o erro clássico):** quando as opções têm dados próprios. Se você quer saber "quantas tarefas cada tag tem", ou a tag tem um dono, uma descrição, uma cor de marca, um link — isso não é multi-select, é **Relation** para uma database de tags. Multi-select é um rótulo burro; ele não tem página, não tem propriedade, não pode ser filtrado por atributo dele mesmo.

**Regra de decisão select vs multi-select vs relation:**

| Pergunta | Resposta → tipo |
|---|---|
| O item pode ter mais de um valor? | Não → Select ou Status |
| Sim, e o valor é só um rótulo, sem dados próprios, e a lista é curta e estável? | Multi-select |
| Sim, e o valor tem atributos próprios, ou a lista é grande, ou você precisa navegar do valor de volta para os itens? | Relation |

O sinal mais confiável de que multi-select virou relation: você começou a querer uma "página sobre" cada opção.

### Status

Como um select, mas com as opções organizadas obrigatoriamente em **três grupos**: `To-do`, `In progress`, `Complete`.

Isso não é decorativo. Os grupos dão:

- Filtro por grupo inteiro (`Status is not Complete`) sem enumerar cada opção — então adicionar uma opção nova de "In progress" não quebra nenhum filtro existente.
- Semântica de "concluído" que outros recursos entendem.
- Ordenação natural no board (a esquerda→direita já é o fluxo).
- Um ícone de progresso circular na UI.

**Quando é certo:** o campo que representa o ciclo de vida do item. Cada database deve ter **um e só um** Status.

**Erro comum:** ter Status *e* um checkbox `Done`. Agora você tem duas fontes de verdade que divergem. Se você precisa de um booleano, derive com fórmula.

Outro erro: criar dez opções em `In progress`. Se o fluxo tem dez estados, ou o fluxo está errado, ou parte desses estados é outra dimensão (ex.: "Aguardando cliente" é um *blocker*, não um estágio — modele como checkbox `Blocked` ou um select `Blocked reason`).

### Date

Aceita uma data ou um intervalo, com hora opcional.

Opções relevantes:

- **End date** — transforma em range. Necessário para timeline com barras de duração.
- **Include time** — adiciona hora. Só ligue se você realmente usa; senão vira ruído visual e cria dor de fuso.
- **Time zone** — quando `Include time` está ligado, você pode fixar um fuso na data. Essencial em times distribuídos; sem isso a data é renderizada no fuso do leitor e reuniões "somem".
- **Remind** — lembrete relativo à data (no dia, 1 dia antes, etc.). Notifica quem está mencionado/assinado.
- **Formato de exibição** — Month/Day/Year, Day/Month/Year, Year/Month/Day, Relative.

**Quando é certo:** prazos, datas de execução, eventos, janelas de sprint.

**Erro comum #1:** uma única propriedade `Date` fazendo o trabalho de três. Deadline, data de início e data de conclusão real são coisas diferentes. Se você quer medir atraso, precisa de `Due date` **e** `Completed on` separados — senão você sobrescreve o prazo com a realidade e perde a métrica.

**Erro comum #2:** usar range quando você queria duas datas independentes. Range é bom para timeline; ruim para calcular "atrasou quantos dias", porque `dateEnd` do range é a data planejada de fim, não a data real.

### Person

Referência a membros ou grupos do workspace.

**Quando é certo:** responsabilidade e atribuição. `Assignee`, `Reviewer`, `Owner`.

**Detalhe que quase ninguém usa:** você pode filtrar por **Person is Me**, o que torna a mesma view útil para todo mundo do time sem duplicar. É a base de qualquer "Minhas tarefas". Detalhe: essa filtragem funciona porque o filtro é avaliado por leitor.

**Erro comum:** permitir múltiplas pessoas em `Assignee`. Se três pessoas são responsáveis, ninguém é. Deixe `Assignee` como uma pessoa (por convenção — o Notion não força limite aqui) e crie `Collaborators` separado se precisar.

Segundo erro: usar Person para gente que não está no workspace (clientes, fornecedores). Isso é uma Relation para uma database `People` que você controla.

### Files & media

Upload de arquivos e imagens, ou links externos.

**Quando é certo:** anexos que pertencem ao item — capa, PDF do contrato, logo, mockup. Também é a fonte do **card preview** em gallery e board.

**Erro comum:** usar como repositório de documentos. O Notion não é um DMS: não tem versionamento decente de arquivo nem busca dentro de binários. Se o documento é editado com frequência, ele deveria ser uma página Notion ou um link para o Drive/Figma.

### Checkbox

Booleano. Marcado ou não.

**Quando é certo:** flags binárias e genuinamente independentes: `Billable`, `Blocked`, `Archived`, `Needs review`.

**Erro comum:** usar como status. Checkbox `Done` compete com Status e não tem estados intermediários. Além disso, checkbox no Notion **não tem estado vazio** — ele é `false` por padrão, o que significa que você não distingue "não" de "ninguém avaliou ainda". Quando essa distinção importa, use um Select com `Yes`/`No`.

### URL

Link. Clicável, abre em nova aba.

**Quando é certo:** exatamente um link canônico por item — repositório, doc externo, página do produto.

**Erro comum:** múltiplos links empilhados num campo Text separados por vírgula. Se são vários links de naturezas diferentes, são várias propriedades URL (`Repo`, `Design`, `Prod`). Se são vários links da mesma natureza, isso é conteúdo do corpo da página.

### Email

Endereço de e-mail. Clicar abre o cliente de e-mail.

**Quando é certo:** databases de pessoas/contatos. O tipo dedicado dá o comportamento de clique e permite `email()` em fórmulas quando combinado com Person.

### Phone

Telefone. Clicar tenta discar no dispositivo.

Mesma lógica do Email. Não faz validação de formato — se você precisa de consistência, padronize por convenção documentada ou valide com fórmula.

### Formula

Calcula um valor a partir de outras propriedades. Detalhado em `formulas.md`.

**Quando é certo:** qualquer valor **derivado**. Se um humano pode calcular olhando outros campos, ele não deveria estar digitando.

**Erro comum:** fórmula que replica algo que um rollup já faz. Rollup é mais barato e mais legível. Use fórmula quando precisa de lógica condicional, formatação ou combinação de várias fontes.

### Relation

Conecta páginas entre data sources (ou dentro da mesma).

Referência: <https://www.notion.com/help/relations-and-rollups>

**One-way vs two-way.** Relations nascem **one-way** por padrão. Ligando `Two-way relation`, o Notion cria automaticamente a propriedade espelho na outra ponta, e edições em qualquer lado refletem no outro.

| | One-way | Two-way |
|---|---|---|
| Cria propriedade na outra database | Não | Sim |
| Você pode navegar do outro lado | Não | Sim |
| Permite rollup a partir do outro lado | Não | Sim |
| Polui o schema da outra database | Não | Sim |

**Regra:** use two-way sempre que você for querer rollups do outro lado ou navegar em ambas as direções — que é a maioria dos casos de Projects↔Tasks. Use one-way para referências de conveniência que não devem sujar a database de destino (ex.: uma tarefa que aponta para um artigo da wiki — a wiki não precisa de uma coluna "Tarefas que me citam").

**Self-relation.** Relacionar uma database com ela mesma. Este é o padrão para hierarquias: `Parent task` / `Sub-task`, `Blocked by` / `Blocking`, `Related pages`. A documentação recomenda **desligar** two-way em self-relations quando ela seria essencialmente duplicada — mas atenção: para *hierarquia* (pai/filho) você **quer** two-way, porque os dois lados significam coisas diferentes. Para "related pages" (relação simétrica), one-way basta e evita duas colunas redundantes.

Na prática, Sub-items e Dependencies (seção 4) já implementam self-relations prontas — use elas em vez de rolar a sua.

**Limit.** Você pode restringir a relação a `1 page` ou `No limit`. Use `1 page` sempre que a cardinalidade for realmente 1 (uma tarefa pertence a um projeto). Isso não é cosmético: impede que alguém coloque três projetos numa tarefa e quebre todos os seus rollups de esforço.

**Erro comum:** relation onde bastava select. Se o alvo não tem página com conteúdo, não tem propriedades próprias, e você nunca vai olhar "do outro lado", você criou uma database de manutenção sem ganho. Relation custa cliques a cada item criado — cobre esse custo com valor real.

**Erro oposto e mais grave:** multi-select onde precisava de relation. Descobre-se tarde, quando você quer "quantas horas gastamos por cliente" e o cliente é uma tag.

### Rollup

Agrega ou exibe propriedades das páginas relacionadas. Depende de uma Relation existir.

Configuração: escolha a **Relation**, a **Property** da database relacionada, e o **Calculate**.

**Cálculos disponíveis:**

| Categoria | Opções |
|---|---|
| Gerais | Show original, Show unique values, Count all, Count values, Count unique values, Count empty, Count not empty, Percent empty, Percent not empty |
| Só numéricas | Sum, Average, Median, Min, Max, Range |
| Só datas | Earliest date, Latest date, Date range |
| Só checkbox | Checked, Unchecked, Percent checked, Percent unchecked |

**Padrões que valem decorar:**

- `Count all` sobre a relation de sub-tasks → total de subtarefas.
- `Percent not empty` sobre `Completed on` das subtarefas → progresso real.
- `Sum` de `Estimate` das tasks → esforço do projeto.
- `Latest date` de `Due date` das tasks → data de término real do projeto (melhor que digitar à mão).
- `Show original` de `Status` do projeto, dentro da task → herdar contexto sem duplicar dado.

**Erro comum #1:** tentar fazer rollup de rollup. Não é permitido. O Notion nem oferece a propriedade rollup como alvo na configuração de um outro rollup — a doc oficial é explícita: *"Unfortunately not, as this could create unintended loops."* ([Relations & rollups](https://www.notion.com/help/relations-and-rollups)).

Para atravessar duas relations, materialize o valor intermediário numa propriedade que o rollup consiga ler:

- **Automação de database:** gatilho `Property edited` na propriedade do rollup → ação **Edit property** gravando o valor num campo Number/Text comum. O rollup de cima aponta para esse campo.
- **Fórmula sobre a relation:** uma fórmula que percorre a relation direto (`prop("Tasks").map(...)`) já enxerga um nível a mais sem depender do rollup intermediário — ver `formulas.md`.

**Erro comum #2:** usar `Show original` e depois querer filtrar. Rollups do tipo `Show original` são listas e o filtro sobre eles é limitado. Se você vai filtrar, prefira um cálculo que produza número ou use uma fórmula que leia a relation diretamente (ver `formulas.md`).

### Created time / Created by / Last edited time / Last edited by

Automáticos, não editáveis, sempre corretos.

**Quando é certo:** auditoria, faxina ("itens não tocados há 90 dias"), métricas de throughput, e a coluna de sort padrão de qualquer inbox.

**Erro comum:** usar `Last edited time` como "data da última atualização de status". Ele muda quando alguém corrige um typo no corpo da página. Se você quer rastrear mudança de estado, use uma automação de database que grava numa propriedade Date dedicada.

Também: `Created time` de itens importados/duplicados é a data da importação, não a original. Migrações destroem esse campo silenciosamente.

### ID

Gera um número único e sequencial por item. Não editável, não reutilizado.

Aceita um **prefix** configurável — `TASK-1`, `BUG-42`, `ENG-7`.

**Quando é certo:** qualquer coisa que gente vai citar por escrito fora do Notion — em Slack, em commit message, em call. "Fecha o BUG-42" é infinitamente melhor que colar uma URL de 60 caracteres.

**Erro comum:** achar que o ID é estável entre databases duplicadas. Ao duplicar uma database, os IDs são regerados. Não use ID como chave de integração externa.

### Place

Aceita localizações — nome de lugar, endereço, ou via serviço de localização. Tipo relativamente novo.

**Quando é certo:** databases com dimensão geográfica real — visitas, imóveis, lojas, eventos presenciais, restaurantes.

**Erro comum:** usar Place onde Text bastava. Se você só quer escrever "São Paulo" para agrupar, isso é um Select. Place carrega dados de geocodificação e faz sentido quando você quer o mapa/link, não quando quer uma categoria.

### Button

Executa ações com um clique, direto da linha da database.

Ações disponíveis (as mesmas do button block, ver <https://www.notion.com/help/buttons>):

- **Insert blocks** — insere conteúdo na página
- **Add page to** — cria página numa database com propriedades pré-preenchidas
- **Edit pages in** — edita páginas e propriedades existentes
- **Send notification to** — notifica até 20 membros ou pessoas de uma People property
- **Send mail to** — e-mail via Gmail (planos pagos)
- **Send webhook** — POST HTTP (planos pagos)
- **Show confirmation** — tela de confirmação antes de executar
- **Open page or URL**
- **Send Slack notification to** — Plus/Business/Enterprise
- **Define variables** — variáveis com menções e fórmulas, usadas nas outras ações

**Quando é certo:** transições de estado de múltiplos campos ao mesmo tempo. Um botão `Concluir` que marca Status = Done, preenche `Completed on` com hoje e notifica o solicitante economiza três interações e elimina inconsistência.

**Erro comum:** botão para uma ação de um campo só. Clicar no botão custa o mesmo que editar o campo — você adicionou uma coluna sem ganho. Botão vale a pena a partir de duas ações.

Segundo erro: usar botão onde uma **database automation** era melhor. Botão exige alguém lembrar de clicar. Se a regra é "sempre que X, faça Y", isso é automação, não botão. Ver <https://www.notion.com/help/database-automations>.

---

## 3. Quando NÃO usar uma database

Esta é a seção mais importante do arquivo e a mais ignorada.

O Notion recompensa criar databases — é rápido, parece organizado, dá views bonitas. O custo aparece depois: cada database é um schema para manter, um lugar a mais para procurar, e uma fonte a mais de dado desatualizado.

**Não crie database quando:**

| Situação | O que fazer em vez disso |
|---|---|
| Menos de ~10 itens que não crescem | Uma lista de bullets ou uma tabela simples (bloco Table, não database) |
| Você nunca vai filtrar, ordenar ou agrupar | Tabela simples |
| Os itens não têm conteúdo próprio (só um rótulo) | Multi-select ou uma lista na página |
| A "database" tem exatamente uma view e você nunca a alterou | Provavelmente era uma lista |
| Você criou para "organizar" mas ninguém consulta | Delete. Sério |

O sintoma de databaseficação: uma database `Links úteis` com três itens e uma propriedade URL, que ninguém abriu desde que foi criada. Isso é um bloco de bookmarks disfarçado.

**Teste de decisão:** uma database se justifica se você consegue nomear, agora, **duas views diferentes** que pessoas diferentes usariam. Se você só consegue nomear uma, é uma lista.

Contra-exemplo importante: itens poucos mas **com conteúdo de página relevante** justificam database mesmo em volume baixo. Cinco projetos, cada um com um doc rico dentro e propriedades de status/owner/prazo — isso é database, porque a estrutura vale mesmo com cinco linhas.

---

## 4. Modelagem: o que realmente funciona

### Uma database grande com filtros vs. várias databases

A pergunta chega assim: "faço uma database de Tasks para o time todo, ou uma por time?"

**Quase sempre: uma database grande.** Motivos:

1. Views resolvem a separação, e views são grátis. Um filtro `Team is Engineering` dá exatamente a database do time de engenharia, sem duplicar schema.
2. Rollups e relations só funcionam dentro de um universo compartilhado. Com cinco databases de Tasks, você não consegue "todas as minhas tarefas" nem "carga do time" sem gambiarra.
3. Mudança de schema acontece uma vez, não cinco.

**Separe em databases distintas quando** (e só quando):

- Os **schemas divergem de verdade**. Se `Tasks de engenharia` tem sprint, story points e repo, e `Tarefas de RH` tem candidato e etapa, forçar as duas numa database só cria uma tabela cheia de colunas vazias.
- **Permissão exige.** Como já dito, a API trata permissão no nível do database e a granularidade por data source na UI não é confirmada. Dado sensível mora em database separada.
- **Volume gigante.** Databases muito grandes ficam lentas para carregar views complexas. Não há um número mágico publicado, mas na casa das dezenas de milhares de páginas com fórmulas e rollups pesados, você sente.

A alternativa intermediária hoje é justamente **uma database com múltiplas data sources**: schemas diferentes, container único, navegação por abas. É a resposta certa para o caso "divergem no schema mas são consumidas juntas".

### O padrão "master database"

A recomendação da própria Notion, na linguagem deles: em vez de databases separadas por time, use **uma database company-wide** e crie **views dentro dos team spaces**.

Na prática:

1. `Tasks` full-page, mora num espaço central (`Company OS` ou similar).
2. Cada team space tem uma página `Home` com **linked views** dessa Tasks, filtradas pelo time.
3. Ninguém cria uma Tasks nova. Nunca.

O ganho: um único schema, um único lugar onde o dado vive, e ainda assim cada time vê só o que importa. O custo: você precisa de disciplina de governança, porque a database central vira propriedade de todos e de ninguém. Nomeie um dono.

Ver também: <https://www.notion.com/help/guides/using-database-views>

### Modelando Áreas → Projetos → Tarefas

O esqueleto que funciona em 90% dos casos:

```
Areas          (poucas, estáveis, ~5-15)
  ↑ relation (two-way)
Projects       (dezenas, com início e fim)
  ↑ relation (two-way)
Tasks          (centenas/milhares, atômicas)
  ↑ self-relation via Sub-items
Sub-tasks
```

Propriedades mínimas por nível:

| Database | Propriedades essenciais |
|---|---|
| **Areas** | Title, Owner (Person), Status (Active/Paused), Rollup `Count` de Projects ativos |
| **Projects** | Title, Status, Area (Relation), Owner (Person), Dates (range), Rollup `Percent not empty` de tasks concluídas, Rollup `Latest date` de Due date |
| **Tasks** | Title, Status, Assignee (Person), Due date, Project (Relation, limit 1 page), Priority (Select), Sub-items |

Decisões que costumam ser tomadas erradas nesse desenho:

- **Tarefa relacionada a Área diretamente?** Não. Deixe a área ser derivada via rollup do projeto. Ter as duas relations permite que elas divirjam, e elas vão divergir.
- **Uma database só para "Projetos e Tarefas"?** Tentador (uma self-relation resolveria), mas os schemas e os ciclos de vida divergem o bastante — projeto tem stakeholder, orçamento, marco; tarefa tem estimativa e assignee. Separe.
- **Sub-tarefa como database separada?** Nunca. Use Sub-items, que é self-relation nativa e aparece corretamente em table/list/timeline.

### Relations vs subpáginas

Quando um item "contém" outros, você tem duas opções: relation, ou aninhar páginas dentro do corpo.

| | Subpágina (aninhada no corpo) | Relation |
|---|---|---|
| Aparece em views/filtros | Não (não é item de database) | Sim |
| Tem propriedades próprias | Não, a menos que também esteja numa database | Sim |
| Rollup possível | Não | Sim |
| Custo de criação | Zero | Um clique a mais |
| Bom para | Anotações, rascunhos, docs de apoio de um item específico | Qualquer coisa que você vai querer contar, filtrar ou agregar |

**Regra:** se você algum dia vai perguntar "quantos?" ou "quais estão atrasados?", é relation. Se é conteúdo que só faz sentido dentro daquele item e nunca será listado transversalmente, é subpágina.

O erro clássico: notas de reunião como subpáginas do projeto. Funciona até alguém perguntar "todas as reuniões desta semana, de todos os projetos". Aí você descobre que precisava de uma database `Meeting notes` com relation para Projects.

---

## 5. Sub-items e Dependencies

Duas self-relations nativas que você habilita em vez de construir.

Referência: <https://www.notion.com/help/tasks-and-dependencies>

**Habilitar:** menu de configurações no topo da database → **More settings** → **Sub-items** / **Dependencies**.

**Sub-items** criam a hierarquia pai/filho. Exibição configurável por view:

- **Nested in toggle** — hierarquia real, com toggles que abrem/fecham. Padrão para table e list.
- **Flattened list** — pais e filhos no mesmo nível. Útil quando você quer que os filtros peguem tudo sem se preocupar com aninhamento.

**Dependencies** conectam tarefas linearmente (A bloqueia B). As setas só aparecem em **timeline view** — em table você vê as propriedades `Blocking` / `Blocked by`, mas não a visualização. Para criar: passe o mouse sobre o item na timeline e arraste a seta que aparece à direita.

Opções de deslocamento automático de datas:

| Opção | Comportamento |
|---|---|
| **Shift only when dates overlap** | Só empurra a tarefa dependente quando as datas realmente colidem |
| **Shift & maintain time between items** | Preserva o intervalo — se A atrasa uma semana, B atrasa uma semana |

**Quando usar dependencies:** projetos com sequenciamento real e crítico (lançamento, obra, migração). O valor é ver o efeito cascata de um atraso.

**Quando NÃO usar:** backlog de produto e trabalho de fluxo contínuo. Dependência é caro de manter — cada mudança de escopo exige religar setas — e num backlog priorizado a ordem já é a dependência. Se ninguém olha a timeline semanalmente, dependencies viram lixo desatualizado.

---

## 6. Database templates

Referência: <https://www.notion.com/help/database-templates>

Templates de página dentro da database: estruturas de página + propriedades pré-preenchidas, criadas com um clique. Acesse pelo dropdown ao lado do botão **New** → **New template**.

**O que pré-preencher:**

- Status inicial (`Backlog`, `Not started`)
- Priority padrão (`P2`)
- Select de tipo (`Bug`, `Meeting note`)
- Person fixo quando faz sentido (o PM responsável por todos os bug reports)
- Estrutura do corpo: headings, toggles, checklists, callouts

**O que NÃO pré-preencher:** propriedades **Relation**. A documentação avisa explicitamente — todo item criado pelo template vai apontar para as mesmas páginas relacionadas, o que quase nunca é o desejado e é chato de limpar depois.

Também evite pré-preencher datas fixas. Se você quer "vence em 7 dias", isso é uma fórmula ou automação, não um template.

### Templates recorrentes

Templates podem se repetir automaticamente — criam uma cópia nova na cadência escolhida: **daily, weekly, monthly, yearly**, com data de início configurável.

**Casos que valem:** weekly review, daily standup note, relatório mensal, retro de sprint. Qualquer ritual com cadência fixa e estrutura fixa.

**Limitações reais:**

- Não dá para aninhar um template dentro de um template que recorre **diariamente**. Aninhamento só funciona em weekly/monthly/yearly.
- Máximo de **três níveis** de aninhamento por database template.

**Erro comum:** template recorrente diário numa database que ninguém consulta todo dia. Você vai gerar 365 páginas vazias por ano e poluir todas as views. Só ative recorrência quando o ritual realmente existe e alguém preenche.

**Dica de higiene:** combine template recorrente com uma view filtrada por `Created time is this week`. Sem isso, a database recorrente vira um cemitério.

---

## 7. Checklist de modelagem

Antes de criar qualquer database, responda:

1. **O que é uma linha?** Se você não consegue completar "cada linha é um(a) ___" com um substantivo concreto, pare.
2. **Duas views distintas, para duas pessoas distintas?** Se não, é uma lista.
3. **Quais são as dimensões categóricas?** Cada uma vira Select (exclusiva) ou Multi-select (múltipla) ou Relation (tem dados próprios).
4. **Qual é o Status?** Um só, com grupos To-do/In progress/Complete bem distribuídos.
5. **O que é derivado?** Tudo que pode ser calculado deve ser fórmula ou rollup, nunca campo digitado.
6. **Onde ela mora?** Full-page, num lugar estável. Todo o resto é linked view.
7. **Quem é o dono do schema?** Uma pessoa nomeada. Sem isso a lista de opções apodrece em três meses.

---

## Leituras oficiais

- Intro a databases: <https://www.notion.com/help/intro-to-databases>
- Criar uma database: <https://www.notion.com/help/create-a-database>
- Propriedades: <https://www.notion.com/help/database-properties>
- Data sources e linked databases: <https://www.notion.com/help/data-sources-and-linked-databases>
- O que mudou nas databases: <https://www.notion.com/help/guides/databases-reimagined-whats-changed>
- Relations e rollups: <https://www.notion.com/help/relations-and-rollups>
- Sub-items e dependencies: <https://www.notion.com/help/tasks-and-dependencies>
- Database templates: <https://www.notion.com/help/database-templates>
- Configurações de database: <https://www.notion.com/help/customize-your-database>
- Buttons: <https://www.notion.com/help/buttons>
- Automations: <https://www.notion.com/help/database-automations>
