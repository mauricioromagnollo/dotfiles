# Blocos e elementos

Tudo no Notion é bloco. Um parágrafo é bloco, uma imagem é bloco, uma página inteira é bloco dentro de outra página. Essa uniformidade é a razão de o editor parecer mágico no começo e virar uma bagunça depois: se tudo pode virar qualquer coisa, nada tem forma natural, e a disciplina precisa vir de você. A doc oficial resume o conceito em [What is a block?](https://www.notion.com/help/what-is-a-block) e cataloga os tipos em [Types of content blocks](https://www.notion.com/help/guides/types-of-content-blocks).

Duas consequências práticas dessa arquitetura, que valem mais que qualquer lista de blocos:

**Todo bloco vira outro bloco.** `Turn into` no menu `⋮⋮` converte texto em heading, bullet em to-do, qualquer coisa em página. Isso significa que você nunca precisa apagar e redigitar — e que o custo de escolher errado no começo é quase zero. Escreva primeiro em texto puro, formate depois. Ver [Transforming content blocks](https://www.notion.com/help/guides/transforming-content-blocks-in-notion).

**Todo bloco tem endereço próprio.** `Copy link to block` no menu do bloco gera uma URL com âncora que abre a página já posicionada naquele ponto. É o recurso mais subutilizado do Notion para documentação: em vez de mandar "olha na página X, seção Y", você manda o link exato. Ver [Create links and backlinks](https://www.notion.com/help/create-links-and-backlinks).

O menu de blocos aparece com `/` (slash command) ou com o `+` na margem esquerda. Nos exemplos abaixo, o comando listado é o atalho mais curto que funciona — o Notion faz busca fuzzy, então `/cal` já acha `Callout`.

---

## Blocos de texto

### Text (parágrafo)

O bloco padrão. Todo `Enter` cria um novo. Slash: `/text`. Atalho de conversão: `Cmd/Ctrl + Option/Shift + 0`.

A armadilha aqui não é o bloco, é o uso: `Enter` cria um bloco novo, `Shift + Enter` cria uma quebra de linha *dentro* do mesmo bloco. A diferença importa mais do que parece. Um endereço de três linhas deve ser um bloco com dois `Shift + Enter`, não três blocos — porque três blocos podem ser reordenados, comentados e arrastados separadamente, e você não quer isso. Regra: se as linhas só fazem sentido juntas, é um bloco.

### Headings (H1, H2, H3)

Slash: `/h1`, `/h2`, `/h3`. Markdown: `#`, `##`, `###` + espaço. Atalhos: `Cmd/Ctrl + Option/Shift + 1/2/3`.

Três níveis, e só. O Notion não tem H4. Se você sente falta de um quarto nível, sua página está funda demais e o certo é quebrá-la em subpáginas — não simular hierarquia com texto em negrito.

O erro clássico é usar H1 no corpo da página. O título da página já é o H1 visual; começar o conteúdo com outro H1 cria duas raízes competindo. **Comece em H2.** Reserve H1 para páginas longas de verdade, onde ele separa grandes partes (não seções). Numa página típica de time, H2 para seções e H3 para subseções cobre 100% dos casos.

Headings também alimentam o `Table of contents` e a navegação por busca — então heading com nome genérico ("Informações", "Outros") não é só feio, é um índice inútil.

### Toggle headings

Um heading que colapsa o conteúdo abaixo dele. Não tem slash command direto óbvio — cria-se pelo `Turn into` → `Toggle heading 1/2/3`, ou digitando o markdown do heading e depois convertendo. Documentado em [Columns, headings, and dividers](https://www.notion.com/help/columns-headings-and-dividers).

Este é, de longe, o bloco mais importante para páginas longas — e o mais ignorado. Ele resolve o dilema entre "quero tudo documentado" e "ninguém lê página de 3 mil linhas": tudo continua lá, mas colapsado. O leitor vê a estrutura inteira em uma tela e abre só o que precisa.

**Use quando:** documentação de referência, FAQ, runbook, onboarding, changelog, qualquer página onde seções são consultadas isoladamente.

**Não use quando:** o conteúdo precisa ser lido em sequência (um tutorial), ou quando é curto o bastante para caber sem colapsar. Toggle em página de 20 linhas é fricção sem benefício.

**Armadilha real:** conteúdo dentro de toggle colapsado **não aparece no `Cmd/Ctrl + F`** da página até você expandir, e não é impresso/exportado para PDF de forma previsível se estiver fechado. Se a informação é crítica em emergência (o número de plantão, o comando de rollback), ela não vai dentro de um toggle.

### Quote

Slash: `/quote`. Markdown: `"` + espaço.

Uma barra vertical à esquerda com texto ligeiramente maior. Serve para citação literal — fala de cliente, trecho de contrato, resposta de suporte. Não serve para "destacar algo importante": para isso existe callout, e misturar os dois destrói o significado de ambos.

### Callout

Slash: `/callout`. Bloco com ícone, fundo colorido e conteúdo dentro.

O bloco mais abusado do Notion. Callout funciona por contraste: um callout numa página de texto salta aos olhos; seis callouts numa página são seis retângulos coloridos que o cérebro aprende a pular. A regra que funciona é **no máximo um a dois callouts por tela visível**, cada um com significado declarado (ícone + cor consistentes ao longo do workspace).

O que quase ninguém sabe: **callout aceita conteúdo aninhado**. Você pode colocar listas, headings, imagens, toggles e até outros blocos dentro dele — basta dar `Enter` dentro do callout e usar `Tab`, ou arrastar blocos para dentro. Isso transforma o callout de "caixinha de aviso" em container de UI, que é o uso mais interessante dele para montar interfaces. Um callout cinza com um heading, três links e um divider dentro vira um "card" visual.

Ícone do callout: pode ser emoji, ícone da biblioteca do Notion, ou upload próprio. Cor de fundo: qualquer uma da paleta (ver `design-de-paginas.md`). Callout com fundo `Default` (sem cor) e ícone é uma opção subestimada — dá estrutura sem gritar.

**Armadilha:** callout dentro de callout dentro de toggle. Aninhamento profundo em Notion é caro visualmente (cada nível come margem) e horrível no mobile. Dois níveis é o teto prático.

### Divider

Slash: `/divider`. Markdown: `---` (três hifens).

Uma linha horizontal fina. É o bloco mais barato de todos e o mais eficaz para dar respiro. O erro é usar divider onde bastaria espaço em branco: se você já tem um H2, não precisa de divider antes dele — o heading já separa. Divider ganha valor quando separa blocos do *mesmo* nível hierárquico (fim de uma seção de cards, antes do rodapé da página).

### Listas: bulleted, numbered, to-do

| Bloco | Slash | Markdown | Atalho |
|---|---|---|---|
| Bulleted list | `/bullet` | `-`, `*` ou `+` + espaço | `Cmd/Ctrl + Option/Shift + 5` |
| Numbered list | `/num` | `1.`, `a.` ou `i.` + espaço | `Cmd/Ctrl + Option/Shift + 6` |
| To-do list | `/todo` | `[]` + espaço | `Cmd/Ctrl + Option/Shift + 4` |

`Tab` aninha, `Shift + Tab` desaninha. Numbered list renumera sozinha e muda de estilo por nível (1. → a. → i.), o que é um detalhe bonito que quase ninguém percebe.

A escolha entre bulleted e numbered não é estética: **numbered comunica sequência e contagem**. Se a ordem não importa, numerar é mentir para o leitor. Se importa (um procedimento, um ranking), bullet joga fora informação.

To-do list é o ponto de fricção clássico entre "página" e "database". To-do em página é perfeito para uma checklist efêmera dentro de um doc (checklist de deploy, itens de uma reunião). É péssimo para gestão de tarefas de verdade: não filtra, não agrega, não tem prazo, e some quando a página é arquivada. O momento de migrar para database é quando alguém pergunta "quais tarefas estão abertas em todos os projetos?" — pergunta que checklist em página nunca responde.

**Detalhe de espaçamento que mudou:** o Notion reformulou o espaçamento dos blocos para que itens de lista adjacentes fiquem mais compactos entre si e mais espaçados quando vizinhos de um bloco de tipo diferente. Isso é automático e afeta checklists, bullets, numbered e toggles. Explicado em [Updating the design of Notion pages](https://www.notion.com/blog/updating-the-design-of-notion-pages).

### Toggle list

Slash: `/toggle`. Markdown: `>` + espaço. Atalho: `Cmd/Ctrl + Option/Shift + 7`.

Cuidado com o markdown: `>` cria **toggle**, não quote — ao contrário do que quase todo mundo espera vindo de Markdown padrão. Quote é `"` + espaço. Isso está documentado nos [Keyboard shortcuts](https://www.notion.com/help/keyboard-shortcuts) e é a pegadinha de markdown número um do Notion.

Toggle list é o irmão menor do toggle heading. Use toggle list para itens dentro de uma seção (uma pergunta de FAQ, um item de glossário); use toggle heading quando o colapsável *é* a seção. Visualmente a diferença é grande: toggle heading tem peso tipográfico e aparece no `Table of contents`; toggle list não.

---

## Blocos de mídia

Todos aceitam **caption** (legenda) — e caption é subutilizada. Uma imagem sem legenda numa doc é uma imagem que ninguém sabe por que está ali.

### Image

Slash: `/image`. Aceita upload, link ou busca no Unsplash direto do bloco.

Alinhamento (esquerda, centro, direita), redimensionamento por arrastar as bordas, e — recurso mais recente — **crop e masking em formatos** (círculo, etc.), além de **alt text** para acessibilidade e possibilidade de transformar a imagem em hyperlink. Ver [Images, files, and media](https://www.notion.com/help/images-files-and-media).

Limites de upload: no plano Free, **5 MB por arquivo**; em planos pagos, PNG/JPG até 5 MB e PDF até 20 MB. Formatos aceitos incluem HEIC, JPEG, PNG, GIF, SVG, PDF, MP3, MP4, WAV, OGG.

**Armadilha:** imagem colada da web (não uploadada) é um link para o servidor de origem. Se aquele servidor cair ou mudar a URL, sua página fica com um retângulo quebrado — e você só descobre meses depois. Para qualquer imagem que importa, faça upload.

**Armadilha 2:** imagem muito grande não renderiza. A doc oficial sugere subir como bloco `File` nesse caso, mas a solução real é redimensionar antes de subir. Screenshot de monitor 5K numa página é 8 MB de nada.

### Video, Audio

Slash: `/video`, `/audio`. Upload direto ou embed de YouTube, Vimeo e outros.

Vídeo hospedado no Notion consome cota de storage e não tem controle de qualidade adaptativo. Para qualquer vídeo maior que um GIF de demonstração, hospede fora (YouTube não listado, Loom, Vimeo) e embede. Loom em particular é o padrão de facto para demo assíncrona em doc de produto.

### File

Slash: `/file`. Um anexo genérico com ícone e nome.

Use para o que não tem preview útil: `.zip`, `.xlsx`, `.pptx`, binários. Para PDF, prefira o bloco de PDF, que renderiza inline.

**Armadilha crítica:** arquivo anexado em Notion não tem versionamento nem controle de acesso granular. Se três pessoas editam o mesmo `.xlsx` anexado, você tem três verdades. Anexo em Notion serve para artefato final e imutável — para arquivo vivo, link para o Drive/SharePoint.

### PDF

Slash: `/pdf`. Renderiza o PDF inline, com scroll dentro do bloco.

Ótimo para contrato, one-pager, slide deck exportado. Ruim para PDF de 80 páginas: o bloco vira um poço de scroll no meio da página. Nesse caso, `File` com link ou um `Web bookmark` é mais honesto.

---

## Blocos de código e matemática

### Code

Slash: `/code`. Atalho: `Cmd/Ctrl + Option/Shift + 8`. Markdown: ` ``` ` (três crases).

Seleciona a linguagem clicando no nome no canto superior esquerdo do bloco. Suporta dezenas de linguagens com syntax highlighting, além de **caption**, botão **Copy** ao hover e opção **Wrap code** (quebra de linha automática, evitando scroll horizontal). Ver [Code blocks](https://www.notion.com/help/code-blocks).

Detalhe de permissão que pega gente desprevenida: os botões de **Copy** e **Caption** ficam ocultos para quem tem apenas acesso `Can view`.

**Sempre ligue o Wrap** em blocos de código dentro de colunas ou em páginas que serão lidas no mobile. Scroll horizontal dentro de um bloco dentro de uma coluna é a pior experiência possível de leitura.

**Armadilha:** usar code block como "caixa cinza para destacar texto". Isso quebra a busca (código não é indexado igual), quebra o export para Markdown e confunde qualquer pessoa técnica. Para destacar texto, use callout ou background color.

Para código curto no meio de uma frase, use **inline code**: `Cmd/Ctrl + E` na seleção, ou crases simples durante a digitação.

### Equation (KaTeX)

- **Block equation:** `/math` ou `/equation`. Ocupa a linha inteira, centralizada.
- **Inline equation:** `Cmd/Ctrl + Shift + E` na seleção, ou digitar `$$expressão$$`, ou o botão `√x` no menu de seleção.

O Notion usa **KaTeX**, que suporta um subconjunto grande do LaTeX — letras gregas, operadores, frações, matrizes, e notação química via extensão `mhchem`. Não suporta tudo: o ambiente `align` não existe, use `aligned`. A lista completa está na [documentação do KaTeX](https://katex.org/docs/supported.html), e o guia do Notion é [Math equations](https://www.notion.com/help/math-equations).

Uso realista fora da academia: notação de fórmula em doc de engenharia de dados, definição de métrica (`\text{CAC} = \frac{\text{gasto}}{\text{novos clientes}}`), spec de algoritmo. Fora isso, é enfeite.

---

## Links, referências e navegação

### Mentions (`@`)

O `@` é uma família de quatro recursos diferentes que compartilham um gatilho. Documentado em [Comments, mentions, and reminders](https://www.notion.com/help/comments-mentions-and-reminders).

| Menção | Como | O que faz |
|---|---|---|
| `@pessoa` | `@` + nome | Notifica a pessoa e cria um chip clicável com o avatar |
| `@página` | `@` + título da página | Link inline **e cria um backlink** na página de destino |
| `@data` | `@today`, `@tomorrow`, `@1/12` | Timestamp inline; referências relativas se atualizam sozinhas |
| `@remind` | `@remind tomorrow 9am` | Lembrete com notificação por inbox, push e e-mail |

O `@página` é o mecanismo que faz um workspace virar wiki. Cada menção alimenta os **backlinks** da página de destino — a lista de "quem me referencia", acessível clicando no contador embaixo do título. Você só vê backlinks de páginas às quais tem acesso.

Alternativas de sintaxe para linkar página: `[[` + nome (também oferece criar subpágina nova) e `+` + nome. Os três levam ao mesmo lugar; `[[` é o mais rápido de digitar sem tirar a mão da posição.

**Reminders:** não existe lembrete recorrente. Isso é limitação declarada em [Reminders](https://www.notion.com/help/reminders). Para recorrência, o caminho é database com date property e automação, ou o Notion Calendar. Mencionar alguém junto do reminder (`@Camille @remind next Thursday 4pm`) notifica aquela pessoa, não você.

**Armadilha:** `@pessoa` notifica de verdade. Mencionar cinco pessoas numa doc "só para dar contexto" gera cinco notificações que treinam o time a ignorar o inbox. Mencione quem precisa agir.

### Link to page

Slash: `/link`. Um bloco de linha inteira com ícone e título da página.

A diferença crucial em relação ao `@página`: **`Link to page` cria uma relação hierárquica**. A página linkada aparece na sidebar *aninhada sob a página onde você inseriu o bloco*, exatamente como uma subpágina. `@página` é só um hyperlink.

Isso importa para arquitetura: se você quer que a sidebar reflita a estrutura de navegação, use `Link to page`. Se você só está citando algo no meio de um parágrafo, use `@`. Confundir os dois é como o Notion de muita gente acaba com a sidebar mentindo sobre a organização real.

### Subpágina

Slash: `/page`. Atalho: `Cmd/Ctrl + Option/Shift + 9`. Ou `Turn into` → `Page` em qualquer bloco de texto.

Converter um bloco de texto em página é o movimento mais útil do editor: você escreve uma linha, percebe que ela merece um documento, e converte sem perder nada. Ver [Create a subpage](https://www.notion.com/help/create-a-subpage).

**Regra de profundidade:** três níveis de subpágina é confortável, quatro é o limite, cinco significa que ninguém vai achar nada. Quando você está indo para o quinto nível, o problema é de arquitetura de workspace, não de página.

### Web bookmark vs Embed vs Link preview

Três formas diferentes de trazer conteúdo externo, e escolher errado é comum.

| Recurso | Slash | O que é | Quando usar |
|---|---|---|---|
| **Link inline** | colar + `Dismiss` | Só o texto virando hyperlink | Citação no meio de frase |
| **Web bookmark** | `/bookmark` ou `/web` | Card com título, descrição e favicon | Referência externa que merece destaque visual |
| **Embed** | `/embed` | Iframe do conteúdo real, interativo | Quando o conteúdo precisa ser *usado*, não só apontado |
| **Link preview** | colar + `Preview` | Visualização viva e autenticada | Jira, GitHub, Figma, Linear — conteúdo de ferramenta conectada |
| **Mention** | colar + `Paste as mention` | Chip inline compacto com ícone | Muitos links no meio de texto |

**Web bookmark** é o padrão certo para links externos em documentação: dá peso visual sem carregar nada. Três bookmarks em coluna viram uma linha de cards de referência decente.

**Embed** funciona com mais de 1.900 domínios via Iframely — Figma, Miro, Loom, CodePen, GitHub Gist, Google Maps, Typeform, Excalidraw, Replit, Spotify, YouTube, Vimeo, TikTok, GIPHY, Canva, Tableau e por aí vai. Google Drive, Google Calendar, Slack e Zoom têm integrações especiais. Lista e detalhes em [Embed and connect other apps](https://www.notion.com/help/embed-and-connect-other-apps).

Limitações reais de embed, e são pesadas: alguns sites bloqueiam embedding; **embeds que exigem login no site de origem não funcionam nos apps desktop e mobile do Notion**; e o Iframely e o app embedado recebem o IP de quem visualiza. Além disso, todo embed carrega um iframe — cinco embeds numa página é uma página lenta.

**Link preview** é diferente de embed: exige autenticação OAuth uma vez, e depois mostra conteúdo vivo e sincronizado de mais de 19 plataformas (GitHub, Jira, Slack, Asana, Trello, Linear, Zoom, Figma, Dropbox, OneDrive, SharePoint, ClickUp, Zendesk...). O detalhe de segurança que muita gente ignora: *depois de você autenticar, qualquer pessoa que vê sua página vê o conteúdo correspondente*. Ver [Link previews](https://www.notion.com/help/link-previews).

**Armadilha de embed do Figma/Miro:** o embed renderiza a versão publicada com as permissões do arquivo original. Se o Figma é privado, seu leitor vê uma tela de "solicitar acesso" — e o embed continua ali, ocupando 600px de altura, comunicando nada. Sempre teste o embed numa janela anônima antes de considerar a página pronta.

---

## Estrutura e layout

### Columns

Não tem slash command tradicional na versão clássica — cria-se arrastando um bloco pelo `⋮⋮` até o lado de outro, seguindo as guias azuis. Versões recentes também oferecem `/column` com número de colunas. Documentado em [Columns, headings, and dividers](https://www.notion.com/help/columns-headings-and-dividers).

Você pode criar quantas colunas quiser ao longo da largura da página, e redimensionar arrastando as bordas.

**O comportamento mobile é a informação mais importante sobre columns**, e é a que mais causa páginas quebradas: colunas existem em tablet mas **não em celular**. No telefone, o conteúdo da coluna direita simplesmente aparece empilhado embaixo do da coluna esquerda. Isso significa que um layout de três colunas com "menu | conteúdo | metadados" no desktop vira, no celular, "menu, conteúdo, metadados" numa pilha vertical — geralmente na ordem errada de importância.

Regra prática: **duas colunas é seguro, três é o teto, quatro só para grids de cards curtos.** E sempre coloque na coluna da esquerda o que precisa ser lido primeiro no mobile.

Para remover colunas, arraste o conteúdo da direita de volta para baixo do da esquerda até aparecer a guia azul de largura total.

### Simple table

Slash: `/table`. Uma tabela de texto puro, sem propriedades, sem filtros, sem views.

Suporta header row e header column, e — adição recente — **merge de células**, permitindo cabeçalhos que abrangem várias colunas ou agrupamentos de linhas. Ver [Tables](https://www.notion.com/help/tables).

A decisão simple table vs database é uma das mais consequentes do Notion:

| Use **simple table** quando | Use **database** quando |
|---|---|
| É uma matriz de texto que se lê inteira | Você vai filtrar, ordenar ou agrupar |
| Cada célula é conteúdo, não dado | Cada linha é uma entidade com atributos |
| Comparação lado a lado (specs, preços, prós/contras) | Cada linha merece uma página própria |
| Não vai crescer muito | Vai crescer indefinidamente |
| Vive dentro de um documento maior | É a coisa em si |

A pergunta que decide: **"eu vou querer ver isso filtrado de outra forma algum dia?"** Se sim, database. Se não, simple table — e você acabou de economizar todo o overhead de manutenção que uma database cobra.

**Armadilha:** simple table larga não cabe na tela e vira scroll horizontal, especialmente dentro de coluna ou no mobile. Cinco colunas é o conforto; oito é sofrimento.

### Table of contents

Slash: `/toc`. Um índice gerado automaticamente a partir dos headings da página.

Só vale a pena em página longa de verdade — digamos, mais de duas telas de conteúdo com pelo menos quatro seções. Numa página curta é ruído que empurra o conteúdo real para baixo da dobra.

O uso mais elegante: `/toc` dentro de uma coluna estreita à direita, ao lado do conteúdo, virando uma navegação lateral fixa visualmente. Só lembre que essa coluna desaparece na ordem errada no mobile.

Depende inteiramente de headings bem nomeados. Um `Table of contents` cheio de "Contexto", "Detalhes", "Mais informações" prova que os headings estão ruins.

### Breadcrumb

Slash: `/breadcrumb`. Mostra o caminho hierárquico da página atual até o topo.

Útil em wikis grandes e páginas profundas, onde o leitor chegou por busca ou link direto e não faz ideia de onde está. Inútil em página de primeiro nível (o breadcrumb mostra um item só) e redundante se a página já tem navegação explícita no topo.

### Synced block

Não tem slash direto — seleciona os blocos, `⋮⋮` → `Turn into` → `Synced block`. Depois copia o bloco e cola onde quiser. Documentado em [Synced blocks](https://www.notion.com/help/synced-blocks).

O bloco original aparece marcado como `ORIGINAL`. Todas as cópias apontam para ele; editar qualquer instância atualiza todas.

**Quando usar, de verdade:** conteúdo que precisa ser idêntico em vários lugares e mudar junto. Aviso de política vigente, bloco de contatos de plantão, disclaimer legal, banner de navegação que se repete no topo de várias páginas de um hub, definição canônica de um termo. É o recurso que evita o pior problema de wiki: cinco versões divergentes da mesma informação.

**Quando NÃO usar** — e aqui está a maior parte dos casos:

*Permissões.* Quem não tem acesso à página do bloco original **não vê o conteúdo** — vê um placeholder pedindo acesso. Isso quebra silenciosamente: você monta uma página pública ou de outro teamspace, cola o synced block, e para você funciona perfeitamente enquanto metade do time vê um vazio. Sempre teste o synced block com uma conta que só tenha acesso à página de destino.

*Edição.* Para editar um synced block, a pessoa precisa de acesso de edição à página *original*. Você acaba com blocos que parecem editáveis e não são.

*Perda de dados.* Se um synced block tem **mais de 10 cópias**, deletar o original ou usar `Unsync all` remove todas as cópias permanentemente — e **`Undo` não desfaz isso**. Esse é um dos poucos lugares no Notion onde você pode destruir conteúdo de forma irreversível com um clique.

*Export.* Synced blocks no export para Markdown/PDF se comportam de forma pouco previsível — geralmente o conteúdo aparece duplicado ou não aparece.

Para desfazer: `Unsync` numa cópia solta só aquela; `Unsync all` no original solta todas (com o risco acima).

**Heurística:** se você tem menos de três lugares onde o conteúdo se repete, copiar e colar manualmente é mais seguro. Synced block só compensa a partir de quatro ou cinco pontos de uso, e apenas se todos tiverem o mesmo perfil de permissão.

---

### Table of contents dentro de coluna: o padrão de navegação lateral

Vale destacar como padrão porque é o layout de documentação mais eficaz que se monta com blocos nativos:

```
┌──────────────────────────────┬──────────────┐
│  ## Seção 1                  │  [ /toc ]    │
│  (conteúdo)                  │              │
│                              │  Seção 1     │
│  ## Seção 2                  │  Seção 2     │
│  (conteúdo)                  │  Seção 3     │
│                              │              │
│  ## Seção 3                  │  ───         │
│  (conteúdo)                  │  📌 Owner    │
│                              │  📅 jul/26   │
└──────────────────────────────┴──────────────┘
       coluna 75%                 coluna 25%
```

A coluna estreita à direita concentra o índice e os metadados (dono, data de revisão, links relacionados). Funciona muito bem no desktop e desaparece de forma aceitável no mobile — o índice vai para o fim da página, o que não é ideal mas também não quebra a leitura.

O inverso (índice à esquerda) fica melhor no mobile mas empurra o conteúdo para a direita, o que atrapalha a leitura no desktop. Escolha sabendo o trade-off.

---

## Blocos interativos

### Button

Slash: `/button`. Documentado em [Buttons](https://www.notion.com/help/buttons).

Botões evoluíram muito e hoje são o mecanismo de automação mais acessível do Notion. As ações disponíveis:

| Ação | O que faz | Restrição |
|---|---|---|
| `Insert blocks` | Insere blocos prontos na página | — |
| `Add page to` | Cria entrada em database com propriedades preenchidas | Quem clica precisa ser editor da database alvo |
| `Edit pages in` | Altera páginas e propriedades existentes | Idem |
| `Send notification to` | Notifica até 20 membros ou pessoas de uma property | — |
| `Send mail to` | Envia e-mail via Gmail | Planos pagos |
| `Send webhook` | Dispara requisição HTTP | Planos pagos |
| `Send Slack notification` | Alerta um canal | Plus/Business/Enterprise |
| `Open page or URL` | Navega para página ou link externo | — |
| `Show confirmation` | Diálogo de confirmação antes de executar | — |
| `Define variables` | Cria variáveis para as demais ações | — |

Botões encadeiam ações em sequência, o que permite coisas como "cria a página do projeto a partir do template, notifica o time e abre a página criada" num clique só.

Para navegação pura, `Open page or URL` num botão é uma alternativa visualmente mais forte que um link — vale para o CTA principal de uma homepage. Para navegação secundária, botão é peso demais e link basta.

**Armadilha:** quem clica precisa das permissões, não quem criou. Um botão que cria página numa database restrita simplesmente falha para quem não tem acesso — sem mensagem clara.

### Template button

O antecessor dos botões atuais. Ainda existe e ainda funciona: insere um conjunto pré-definido de blocos na página.

**Não use para nada novo.** Tudo que o template button faz, a ação `Insert blocks` de um botão moderno faz melhor, e o botão moderno faz muito mais. A única razão para conhecê-lo é reconhecer e migrar quando encontrar em página antiga.

Se o que você quer é criar *páginas* estruturadas repetidamente, nem botão nem template button são a resposta: são **database templates**, que criam uma entrada completa com propriedades e conteúdo. Ver [Database templates](https://www.notion.com/help/database-templates).

### HTML block

Adição recente (Notion 3.6, julho de 2026): blocos HTML interativos, criados principalmente pelo Notion Agent. Permitem coisas que nenhum bloco nativo permitia — calculadora de ROI, quiz interativo, visualização de organograma — vivendo dentro da página e editáveis por qualquer pessoa do time. Anunciado em [Notion 3.6](https://www.notion.com/releases/2026-07-01).

Trate como recurso de exceção. É poderoso e é exatamente o tipo de coisa que vira dívida: um widget custom que só uma pessoa entende, num lugar onde ninguém espera encontrar código. Vale para o widget que realmente não tem equivalente nativo; não vale para "fazer um card mais bonito".

---

## Databases como blocos

Toda database pode ser **inline** (dentro de uma página, entre outros blocos) ou **full page** (a página inteira é a database). Slash: `/table`, `/board`, `/calendar`, `/gallery`, `/list`, `/timeline`, `/chart`, `/dash` — e as variantes `inline` de cada um.

Isso é território de `databases-e-propriedades.md` e `views-filtros-e-agrupamento.md`, mas duas notas pertencem aqui, porque são decisões de *bloco*:

**Inline vs full page** é decisão de composição de página. Inline quando a database é parte de um documento maior (tarefas de um projeto dentro da página do projeto). Full page quando a database é o assunto. Database inline com 200 linhas dentro de uma página de texto é a receita de página lenta e ilegível — nesse caso, full page com uma linked view filtrada no documento.

**Gallery view** merece menção como elemento visual, não só como database: com `Card preview` = `Page cover` e o `Name` desligado, uma gallery vira um grid de imagens puro — o padrão de moodboard. Com cover + título + uma property, vira um grid de cards de navegação, que é a base de quase todo dashboard bonito de Notion. Opções em [Galleries](https://www.notion.com/help/galleries): `Card preview` (Page cover / Page content / File & media property), `Card size`, e `Fit image` (ligado encaixa a imagem inteira; desligado corta para preencher).

**Dashboard view** é uma adição de 2026: um tipo de view que junta widgets (tables, boards, calendars, charts, timelines) num painel único. Limitado a **12 widgets, até 4 por linha**, e disponível apenas em **Business e Enterprise**. Slash `/dash`. Ver [Dashboards](https://www.notion.com/help/dashboards). Antes disso, "dashboard" no Notion era uma página com linked views empilhadas — que continua sendo a única opção nos planos menores.

---

## Embeds: o guia por serviço

O embed genérico funciona com mais de 1.900 domínios, mas o comportamento varia bastante. Os que aparecem na prática:

| Serviço | Comportamento | Veredito |
|---|---|---|
| **Figma** | Renderiza o frame, navegável e com zoom | Ótimo — **desde que o arquivo esteja com link público** |
| **Miro / FigJam** | Board navegável dentro do iframe | Bom, mas pesado; prefira link em doc que abre muito |
| **Loom** | Player embutido, funciona bem | O melhor embed do Notion para demo assíncrona |
| **YouTube / Vimeo** | Player nativo | Sem ressalvas |
| **GitHub Gist** | Código com highlight | Bom para snippet que vive fora do Notion |
| **CodePen / Replit / Excalidraw** | Interativo de verdade | Bom, mas cada um é um iframe pesado |
| **Google Drive / Docs / Sheets** | Integração especial; preview do arquivo | Depende de permissão do Drive — teste anônimo |
| **Google Maps** | Mapa navegável | Ver também o bloco nativo de [Maps](https://www.notion.com/help/maps) |
| **Typeform** | Formulário preenchível inline | Funciona; considere [Forms](https://www.notion.com/help/forms) nativo antes |
| **Tweet / X** | Card do post | Frágil — muda de comportamento com frequência |
| **Spotify** | Player | Funciona; uso decorativo |
| **Canva / Tableau / Pitch** | Preview do design/dashboard | Varia por permissão de publicação |

**A regra que vale para todos:** o embed renderiza com as permissões do arquivo original, não com as da página do Notion. Um Figma privado embedado numa página pública mostra "solicitar acesso" e ocupa 600 pixels comunicando nada. **Sempre teste em janela anônima antes de considerar a página pronta** — esse é o teste que ninguém faz e que pega quase todo embed quebrado.

E a segunda regra: **embeds que exigem login no site de origem não funcionam nos apps desktop e mobile do Notion**, só no navegador. Isso é limitação declarada em [Embed and connect other apps](https://www.notion.com/help/embed-and-connect-other-apps) e é a causa mais comum de "funciona no meu navegador e não no app do time".

Sobre performance: cada embed é um iframe com carregamento próprio. Uma página com cinco embeds demora visivelmente para ficar utilizável, e a lentidão é sentida toda vez que alguém abre. Numa página consultada com frequência, prefira bookmark + link — o leitor clica quando precisa, e a página abre instantaneamente para todos os outros.

Sobre privacidade: o Iframely e o app embedado **recebem o IP de quem visualiza a página**. Isso raramente importa, mas importa em contextos regulados.

---

## Tabela-resumo de referência rápida

| Bloco | Slash | Markdown / Atalho | Serve para | Armadilha principal |
|---|---|---|---|---|
| Text | `/text` | — / `Cmd+Opt+0` | Corpo do texto | `Enter` vs `Shift+Enter` |
| Heading 1/2/3 | `/h1` `/h2` `/h3` | `#` `##` `###` / `Cmd+Opt+1/2/3` | Hierarquia e TOC | Usar H1 no corpo; nomes genéricos |
| Toggle heading | `Turn into` | — | Progressive disclosure | Conteúdo fechado escapa do `Cmd+F` |
| Bulleted list | `/bullet` | `-` `*` `+` / `Cmd+Opt+5` | Itens sem ordem | Usar quando a ordem importa |
| Numbered list | `/num` | `1.` `a.` `i.` / `Cmd+Opt+6` | Sequência, ranking | Numerar o que não é sequência |
| To-do | `/todo` | `[]` / `Cmd+Opt+4` | Checklist efêmera | Virar gestor de tarefas |
| Toggle list | `/toggle` | `>` / `Cmd+Opt+7` | Esconder detalhe | `>` não é quote |
| Quote | `/quote` | `"` | Citação literal | Usar como destaque |
| Callout | `/callout` | — | Aviso, container de UI | Callout demais = callout nenhum |
| Divider | `/divider` | `---` | Respiro entre seções | Redundante antes de heading |
| Code | `/code` | ` ``` ` / `Cmd+Opt+8` | Código, comandos | Usar como caixa cinza decorativa |
| Inline code | — | crases / `Cmd+E` | Termo técnico na frase | — |
| Block equation | `/math` | — | Fórmula em destaque | KaTeX ≠ LaTeX completo |
| Inline equation | — | `$$…$$` / `Cmd+Shift+E` | Notação na frase | — |
| Image | `/image` | — | Screenshot, diagrama | Imagem por link quebra sozinha |
| Video / Audio | `/video` `/audio` | — | Demo, gravação | Hospedar vídeo pesado no Notion |
| File | `/file` | — | Anexo sem preview | Sem versionamento |
| PDF | `/pdf` | — | Documento inline | PDF longo vira poço de scroll |
| Web bookmark | `/bookmark` | — | Referência externa com peso | — |
| Embed | `/embed` | — | Conteúdo interativo externo | Não funciona se exige login; pesa a página |
| Link preview | colar → `Preview` | — | Jira, GitHub, Figma vivos | Quem vê a página vê o conteúdo |
| Link to page | `/link` | — | Navegação hierárquica | Cria aninhamento na sidebar |
| Mention página | — | `@` `[[` `+` | Referência inline + backlink | — |
| Mention pessoa | — | `@nome` | Notificar alguém | Notifica de verdade |
| Mention data | — | `@today` | Timestamp vivo | — |
| Reminder | — | `@remind …` | Lembrete pontual | Não existe recorrência |
| Subpágina | `/page` | `Cmd+Opt+9` | Documento filho | Profundidade > 4 níveis |
| Columns | arrastar / `/column` | — | Layout lado a lado | **Não existem no mobile** |
| Simple table | `/table` | — | Matriz de texto | Larga demais = scroll horizontal |
| Table of contents | `/toc` | — | Índice de página longa | Inútil em página curta |
| Breadcrumb | `/breadcrumb` | — | Orientação em wiki profunda | Redundante no nível 1 |
| Synced block | `Turn into` | — | Conteúdo idêntico em N lugares | Permissões e perda irreversível >10 cópias |
| Button | `/button` | — | Ação em um clique | Permissão é de quem clica |
| Template button | `/template` | — | Legado | Substituído por Button |
| HTML block | — | — | Widget interativo custom | Dívida técnica escondida |
| Database inline | `/table inline` etc. | — | Dados dentro de um doc | Muitas linhas = página lenta |
| Gallery | `/gallery` | — | Grid visual de cards | — |
| Dashboard view | `/dash` | — | Painel de widgets | Business/Enterprise, máx. 12 widgets |

---

## Escolhendo o bloco certo: as três perguntas

Quase toda dúvida de "que bloco uso" se resolve com três perguntas em ordem:

**1. Isso é conteúdo ou é dado?** Conteúdo se lê; dado se filtra. Texto, listas e tabelas simples para conteúdo. Database para dado. A maior parte das páginas ruins do Notion nasce de tratar conteúdo como dado — e virar administrador de um sistema que existe para guardar três parágrafos.

**2. Isso precisa ser visto agora ou estar disponível?** Visto agora fica no corpo da página, acima da dobra. Disponível vai para toggle heading, subpágina ou callout recolhido. Página que trata tudo como "precisa ser visto agora" não tem hierarquia — e sem hierarquia, nada é visto.

**3. Isso vai mudar em mais de um lugar?** Se sim, e se todos os lugares compartilham permissão, synced block ou linked database view. Se não, cópia simples é mais barata e mais segura que qualquer mecanismo de sincronização.

E a regra que resume o resto: **o bloco mais simples que funciona é o certo.** Um parágrafo bem escrito supera um callout colorido com o mesmo texto. Uma lista supera uma tabela quando não há colunas de verdade. Um link supera um embed quando ninguém vai interagir com o conteúdo. O Notion recompensa restrição — e pune, com juros compostos de manutenção, cada elemento que você adiciona porque podia.
