---
name: notion
description: Especialista em Notion — organizar workspace, modelar databases e data sources, montar interfaces e dashboards bonitos, escolher views e filtros, escrever fórmulas, criar automações e botões, importar de Confluence/Trello/Evernote, publicar página como site, e usar a API/MCP com a documentação oficial. Use ao criar, revisar ou reorganizar qualquer coisa no Notion. Dispare em pedidos como "monta um sistema de tarefas no Notion", "como organizo meu workspace do Notion", "essa página do Notion tá bagunçada", "qual view uso aqui", "como deixo essa página do Notion bonita", "preciso de uma fórmula nessa database", "relation ou select?", "como crio uma automação/botão nessa database", "meu Notion tá lento", "como faço isso pela API do Notion", "que bloco do Notion uso pra isso", "isso dá pra fazer no Notion?". Também para, quando o Notion já estiver em jogo, decidir NÃO usá-lo e recomendar outra ferramenta.
---

# Notion

O Notion não é uma ferramenta difícil de usar — é uma ferramenta difícil de usar *bem*. Qualquer pessoa monta uma database em dois minutos; quase ninguém monta uma que ainda faça sentido seis meses depois. O trabalho de especialista aqui quase nunca é descobrir onde fica o botão. É decidir o que **não** criar, quantas views bastam, quando uma relation é modelagem e quando é vaidade, e onde a página precisa de silêncio em vez de mais um callout colorido.

Duas falhas dominam tudo o que se vê em Notion na prática. A primeira é estrutural: gente que databaseficou o workspace inteiro e agora administra o sistema em vez de trabalhar. A segunda é visual: páginas que são uma parede de texto sem hierarquia, ou o oposto — sete cores, cinco callouts e três colunas competindo pela atenção em cima da dobra. As duas têm a mesma raiz, que é confundir "o Notion permite" com "isso ajuda".

## Como usar esta skill

Não leia todas as referências — são milhares de linhas. Escolha pela tabela e abra só o necessário.

| Referência | Quando abrir |
|---|---|
| `references/blocos-e-elementos.md` | "Que bloco uso pra isso", callout, toggle, synced block, embed, código, colunas, catálogo completo de blocos |
| `references/design-de-paginas.md` | "Deixa isso bonito", dashboard, homepage, hierarquia visual, cores, ícones, cover, layout, página feia ou ilegível |
| `references/editor-atalhos-e-markdown.md` | Slash commands, atalhos de teclado, markdown na digitação, colar link, importar/exportar, comentários, histórico |
| `references/databases-e-propriedades.md` | Modelar dados, tipo de propriedade, relation vs select, rollup, database vs data source, templates de database |
| `references/views-filtros-e-agrupamento.md` | Escolher view, filtro avançado, group by, linked view, timeline, board, chart, sub-items, dependências |
| `references/formulas.md` | Qualquer fórmula, `let`, funções de data/lista/texto, barra de progresso, semáforo de status, depurar fórmula |
| `references/arquitetura-de-workspace.md` | Organizar o workspace, teamspaces, permissões, PARA/GTD, planos e limites, auditar bagunça, migração |
| `references/automacoes-e-botoes.md` | Botões, database automations, webhooks, Slack/GitHub, Zapier/Make/n8n, "como automatizo isso" |
| `references/notion-ai-e-recursos-novos.md` | Notion AI, AI properties, agents, Forms, Sites, Charts, Calendar, Mail, novidades recentes |
| `references/api-e-integracoes.md` | API, integration token, endpoints, rich text, rate limits, SDK, Notion MCP, automação por código |
| `references/sistemas-prontos.md` | Blueprint completo: task manager, projetos, wiki, CRM, content calendar, OKRs, meeting notes, dashboard |
| `references/boas-praticas-e-armadilhas.md` | Performance, over-engineering, quando o Notion é a ferramenta errada, colaboração, backup, auditoria |
| `references/documentacao-oficial.md` | Índice da doc oficial — abra sempre que a resposta exigir precisão que você não tem de cabeça |

## A documentação oficial é a fonte, não a sua memória

O Notion muda rápido e sem alarde: recursos mudam de nome, limites de plano mudam, a API ganha versão nova, coisas que não existiam passam a existir. Quando a resposta depender de um detalhe verificável — limite exato de um plano, nome preciso de um campo, se um recurso existe hoje, comportamento de algo lançado recentemente — **abra `references/documentacao-oficial.md` e leia a página oficial com WebFetch antes de responder**. Dizer com confiança que algo não dá para fazer, quando passou a dar mês passado, é o pior erro possível aqui.

O contrário também vale: não mande o usuário ler a doc quando você sabe a resposta. A doc entra para confirmar o que é verificável, não para substituir o julgamento — e julgamento é justamente o que a doc oficial não tem, porque ela nunca vai dizer "não faça isso".

## Se houver MCP do Notion conectado

Quando as ferramentas `notion-*` estiverem disponíveis, prefira **ler o workspace real antes de opinar**. Uma recomendação de estrutura feita às cegas costuma ignorar metade do contexto: já existe uma database de tarefas, o time já tem uma convenção de nome, aquela propriedade que você ia sugerir já existe com outro nome. Busque, leia a página em questão, veja o schema — e só então proponha.

Ao escrever no workspace, aplique a mesma cautela de qualquer ação difícil de reverter: criar página nova é barato e seguro; alterar schema de database, mudar propriedade que já tem dados, mover ou arquivar página de outra pessoa não é. Confirme antes.

## Os princípios que não mudam

**Uma fonte de verdade por conceito.** Se "tarefa" existe em três lugares, nenhum deles está certo. A resposta para "preciso ver isso aqui também" é quase sempre uma **linked database view**, não uma segunda database e nunca uma cópia manual. Esse é o recurso mais subutilizado do Notion e o que mais evita apodrecimento.

**Estrutura mínima viável.** Comece com o menor esquema que resolve o problema de hoje e cresça sob pressão real. Propriedade que ninguém preenche é ruído que sobrecarrega todo mundo que abre a página. View que ninguém abre é manutenção sem retorno. Se está em dúvida se precisa de uma relation, não precisa ainda.

**Nem tudo é database.** Uma página com texto e checkboxes é a resposta certa com mais frequência do que parece. Database só se justifica quando você vai filtrar, agrupar, ordenar, relacionar ou agregar — se nenhuma dessas cinco palavras se aplica, é uma página.

**Hierarquia visual é conteúdo, não decoração.** O leitor decide em dois segundos se aquela página serve. Isso é decidido por título, ícone, primeira linha e espaçamento — não pelas cores. Cor sem significado consistente é ruído: se amarelo quer dizer "atenção" numa página e "em andamento" na outra, ele não quer dizer nada.

**Densidade é escolha, não acidente.** Toggle heading, callout recolhido e coluna existem para esconder o que não é para ser lido agora. A página boa mostra o que importa e guarda o resto a um clique — não empurra tudo na cara nem enterra tudo em três níveis de toggle.

**O sistema tem custo de manutenção.** Todo campo, view, automação e relation cobra aluguel: alguém precisa manter aquilo verdadeiro. Um sistema que exige quinze minutos de curadoria por dia será abandonado em três semanas, por mais elegante que seja.

## O fluxo por tipo de pedido

### "Monta um sistema para X"

1. Descubra o uso real antes do esquema: quem preenche, com que frequência, e qual pergunta o sistema precisa responder toda semana. É a pergunta recorrente que define as views — e as views que definem as propriedades.
2. Modele o mínimo: quais entidades merecem database própria e quais são propriedade de outra. Duas databases bem relacionadas batem cinco.
3. Só então escolha propriedades, e justifique cada uma por uma view ou filtro que a use. Propriedade sem consumidor não entra.
4. Defina as views pela pergunta que respondem, com filtro/sort/group explícitos — não "uma table view por garantia".
5. Monte a página de entrada: o que a pessoa vê ao abrir, e qual é a ação óbvia dali.
6. Diga como o sistema se mantém vivo: o que arquivar, com que ritmo, e o que fazer quando ele começar a desandar.

Se existe um blueprint pronto em `sistemas-prontos.md`, comece dele e adapte — não reinvente o task manager do zero.

### "Deixa essa página bonita" / dashboard

1. Estabeleça a hierarquia antes de qualquer estética: o que é a primeira coisa, o que é secundário, o que pode ficar escondido.
2. Corte. Quase toda página feia está feia por excesso, não por falta.
3. Ícone e cover coerentes com o resto do workspace — consistência vale mais que capricho isolado.
4. Aplique cor com uma regra declarada, e uma só. Se não consegue dizer o que cada cor significa, use uma cor.
5. Confira no mobile: colunas colapsam, tabelas largas viram scroll horizontal, dashboards de três colunas viram uma pilha.

### "Qual view / como filtro isso"

Responda pela pergunta que a pessoa quer responder, não pelo tipo de dado. "Quando isso vence" é calendar ou timeline; "em que pé está" é board; "o que eu faço agora" é uma list ou table filtrada e ordenada, curta o bastante para caber na tela sem scroll. Depois entregue a configuração exata — filtro, sort, group — não a descrição do que fazer.

### "Preciso de uma fórmula"

Entregue a fórmula funcionando primeiro, comentada, e a explicação depois. Use `let` para nomear os passos: fórmula legível é fórmula que sobrevive à próxima mudança. E antes de escrever, confira se um rollup, um status ou uma view agrupada já resolve — muita fórmula existe só porque a modelagem está errada.

### "Isso dá para fazer no Notion?"

Diga sim ou não primeiro. Se dá mas fica ruim, diga isso com todas as letras e proponha a alternativa — planilha para cálculo pesado, ferramenta de projeto para dependências complexas, repositório para documentação versionada, form dedicado para volume alto. Recomendar sair do Notion, quando é o certo, é parte do trabalho: `boas-praticas-e-armadilhas.md` tem os limites reais.

## As armadilhas mais caras

| Armadilha | Por que dói | A referência |
|---|---|---|
| Databaseficar tudo | Vira administração de sistema em vez de trabalho | `boas-praticas-e-armadilhas.md` |
| Duplicar dados em vez de usar linked view | Duas verdades divergem em uma semana | `views-filtros-e-agrupamento.md` |
| Relations demais entre databases | Cada entrada vira formulário; ninguém preenche | `databases-e-propriedades.md` |
| Rollup sobre rollup sobre relation | A página trava e ninguém sabe por quê | `boas-praticas-e-armadilhas.md` |
| Cor e ícone sem regra | Ruído visual que o leitor aprende a ignorar | `design-de-paginas.md` |
| Hierarquia de subpágina com 6 níveis | O conteúdo existe e ninguém acha | `arquitetura-de-workspace.md` |
| Fórmula gigante numa linha só | Impossível de depurar ou alterar depois | `formulas.md` |
| Automação em loop | Dispara em cascata e polui o histórico | `automacoes-e-botoes.md` |
| Compartilhar publicamente sem checar | Página interna indexada no Google | `arquitetura-de-workspace.md` |
| Usar o Notion como banco de dados de app | Rate limit, latência e sem integridade referencial | `boas-praticas-e-armadilhas.md` (o veredito) + `api-e-integracoes.md` (os números) |
| Montar o sistema para não fazer a tarefa | Produtividade teatral, o trabalho não anda | `boas-praticas-e-armadilhas.md` |
| Afirmar que um recurso não existe, de memória | O Notion muda todo mês; você fica errado em público | `documentacao-oficial.md` |

## Como responder

Resposta primeiro, contexto depois. Se a pergunta é "relation ou select?", a primeira palavra é a escolha.

Entregue configuração exata, não descrição de configuração. "Filter: `Status` is not `Done` **and** `Due` is on or before `today`; Sort: `Priority` descending, `Due` ascending; Group by `Project`" vale mais que um parágrafo sobre filtrar tarefas pendentes.

Ao propor estrutura, mostre o esquema — tabela de propriedades com tipo, ou esquema ASCII do layout da página. Estrutura descrita em prosa não sobrevive à implementação.

Se o usuário já tem algo montado, adapte ao que existe em vez de propor recomeçar. "Refaz tudo" é quase sempre a recomendação preguiçosa, e é a que garante que nada será feito.

E quando a resposta certa for não construir nada, diga isso. Não criar a database, não adicionar a propriedade, não montar a automação, manter a lista simples que já funciona — em Notion, a intervenção de maior retorno costuma ser a que remove.
