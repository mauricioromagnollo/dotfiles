# Editor, atalhos e markdown

A diferença entre alguém que usa o Notion e alguém que é rápido no Notion não é conhecimento de recursos — é não tirar a mão do teclado. Quem clica no `+`, escolhe no menu, clica no bloco, clica no `⋮⋮`, escolhe `Turn into`, escolhe `Heading 2` gastou seis interações para fazer o que `## ` + espaço faz em três teclas. Multiplique por um dia de trabalho.

Este arquivo é sobre operar o editor com fluência. A referência oficial completa é [Keyboard shortcuts](https://www.notion.com/help/keyboard-shortcuts), acessível também dentro do app pelo `?` no canto inferior direito.

---

## Slash commands

Digite `/` em qualquer lugar e o menu de blocos aparece. O Notion faz busca fuzzy, então você quase nunca digita o nome inteiro: `/cal` acha `Callout`, `/tog` acha `Toggle`, `/quo` acha `Quote`.

O detalhe que muda tudo: **o slash command funciona no meio de uma linha vazia, mas também converte o bloco atual**. Se você já digitou o texto e depois quer virar heading, `/h2` no início da linha resolve — não precisa apagar nada. Ver [Using slash commands](https://www.notion.com/help/guides/using-slash-commands).

Existem quatro famílias de slash command, e a maioria das pessoas só conhece a primeira:

**1. Inserção de bloco** — `/callout`, `/code`, `/toggle`, `/image`, `/embed`, `/button`, `/toc`, `/breadcrumb`, `/divider`, `/math`, `/table`, `/board`, `/gallery`, `/calendar`, `/timeline`, `/chart`, `/dash`, `/page`, `/link`, `/bookmark`, `/file`, `/video`, `/audio`, `/pdf`, `/quote`, `/todo`, `/bullet`, `/num`, `/h1`, `/h2`, `/h3`.

**2. Conversão** — `/turn` seguido do tipo. `/turnbullet` converte o bloco atual em bullet, `/turntodo` em to-do, e assim por diante. Útil quando você já tem o texto e a mão está no teclado.

**3. Cor** — `/red`, `/blue`, `/gray`, `/yellow`... aplicam cor de texto. Para background, `/red background`, `/blue background` etc. Esta é a forma mais rápida de colorir sem passar pelo menu de seleção, e quase ninguém usa.

**4. Ação no bloco** — `/comment` abre comentário, `/duplicate` duplica, `/delete` apaga, `/moveto` move a página para outro lugar. Ações que normalmente exigiriam abrir o menu `⋮⋮`.

Duas notas práticas. Primeiro: se você quer digitar uma barra literal (uma data como `19/07`, um caminho como `/usr/bin`), o menu aparece e atrapalha — `Esc` fecha o menu e mantém a barra. Segundo: em databases, o `/` dentro de uma célula de texto não abre o menu de blocos; ele só funciona dentro de páginas e do corpo de páginas de database.

---

## Markdown durante a digitação

O Notion não é um editor Markdown — é um editor de blocos que aceita atalhos de Markdown como gatilho. A diferença importa: o que você digita vira bloco imediatamente e o texto do atalho some. Não existe "modo Markdown" para editar depois.

### No início da linha (bloco novo)

| Você digita | Vira |
|---|---|
| `# ` | Heading 1 |
| `## ` | Heading 2 |
| `### ` | Heading 3 |
| `- ` `* ` `+ ` | Bulleted list |
| `1. ` `a. ` `i. ` | Numbered list (com o estilo correspondente) |
| `[] ` | To-do checkbox |
| `> ` | **Toggle list** |
| `" ` | Quote |
| `---` | Divider |
| ` ``` ` | Code block |
| `$$` | Inline equation |

**A pegadinha número um do Notion:** `> ` cria **toggle**, não quote. Todo mundo que vem de Markdown, GitHub, Slack ou qualquer editor normal digita `> ` esperando uma citação e ganha um triângulo colapsável. Quote é `" ` + espaço. Não existe forma de mudar isso, e você vai errar por meses até internalizar.

### Durante a digitação (inline)

| Você digita | Vira |
|---|---|
| `**texto**` | **negrito** |
| `*texto*` | *itálico* |
| `` `texto` `` | `código inline` |
| `~texto~` | ~~riscado~~ |

Esses funcionam em qualquer lugar do texto, não só no início. Formatar durante a escrita com `**` é mais rápido que selecionar e apertar `Cmd+B`, porque não exige voltar e selecionar.

### O que o Notion NÃO aceita como markdown

Não existe atalho de digitação para: link (`[texto](url)` não vira link automaticamente ao digitar — mas **funciona ao colar**, ver adiante), tabela (`|---|` não faz nada), imagem (`![]()`), nem heading 4+.

---

## Atalhos de teclado essenciais

A convenção: **Mac usa `Cmd`, Windows/Linux usa `Ctrl`**. Para os atalhos de conversão de bloco, Mac usa `Cmd + Option` e Windows/Linux usa `Ctrl + Shift`.

### Formatação (com texto selecionado)

| Ação | Mac | Windows/Linux |
|---|---|---|
| Negrito | `Cmd + B` | `Ctrl + B` |
| Itálico | `Cmd + I` | `Ctrl + I` |
| Sublinhado | `Cmd + U` | `Ctrl + U` |
| Riscado | `Cmd + Shift + S` | `Ctrl + Shift + S` |
| Código inline | `Cmd + E` | `Ctrl + E` |
| Link | `Cmd + K` | `Ctrl + K` |
| Equação inline | `Cmd + Shift + E` | `Ctrl + Shift + E` |
| Comentário | `Cmd + Shift + M` | `Ctrl + Shift + M` |

`Cmd/Ctrl + K` com texto selecionado abre o campo de link. Mas o truque melhor é: **selecione o texto e cole a URL** (`Cmd/Ctrl + V`) — o Notion transforma automaticamente a seleção em hyperlink. Isso é mais rápido que qualquer atalho e funciona sempre.

`Cmd/Ctrl + E` para código inline é o atalho que mais compensa aprender se você escreve documentação técnica. Nome de arquivo, comando, variável, endpoint — tudo isso fica em `code`, e fazer isso com crases exige duas mãos e interrompe o fluxo.

### Conversão de bloco

Com o cursor no bloco (não precisa selecionar):

| Vira | Mac | Windows/Linux |
|---|---|---|
| Text | `Cmd + Option + 0` | `Ctrl + Shift + 0` |
| Heading 1 | `Cmd + Option + 1` | `Ctrl + Shift + 1` |
| Heading 2 | `Cmd + Option + 2` | `Ctrl + Shift + 2` |
| Heading 3 | `Cmd + Option + 3` | `Ctrl + Shift + 3` |
| To-do | `Cmd + Option + 4` | `Ctrl + Shift + 4` |
| Bulleted list | `Cmd + Option + 5` | `Ctrl + Shift + 5` |
| Numbered list | `Cmd + Option + 6` | `Ctrl + Shift + 6` |
| Toggle list | `Cmd + Option + 7` | `Ctrl + Shift + 7` |
| Code block | `Cmd + Option + 8` | `Ctrl + Shift + 8` |
| Nova página | `Cmd + Option + 9` | `Ctrl + Shift + 9` |

Esses funcionam também com **múltiplos blocos selecionados**, que é onde ganham valor de verdade: você cola dez linhas de texto de um e-mail, seleciona todas, `Cmd + Option + 5`, e virou uma lista. Fazer isso bloco a bloco levaria um minuto.

### Manipulação de blocos

| Ação | Mac | Windows/Linux |
|---|---|---|
| Selecionar o bloco atual | `Esc` ou `Cmd + A` | `Esc` ou `Ctrl + A` |
| Expandir seleção | `Shift + ↑/↓` | `Shift + ↑/↓` |
| Duplicar | `Cmd + D` | `Ctrl + D` |
| Mover bloco | `Cmd + Shift + ↑/↓` | `Ctrl + Shift + ↑/↓` |
| Aninhar / desaninhar | `Tab` / `Shift + Tab` | `Tab` / `Shift + Tab` |
| Deletar seleção | `Backspace` / `Delete` | `Backspace` / `Delete` |
| Editar bloco selecionado | `Enter` | `Enter` |
| Menu do bloco | `Cmd + /` | `Ctrl + /` |
| Quebra de linha no bloco | `Shift + Enter` | `Shift + Enter` |

**O fluxo mais valioso do editor inteiro:** `Esc` → `Shift + ↓` (várias vezes) → `Cmd/Ctrl + Shift + ↑/↓`. Isso é: sair do modo de digitação, selecionar um conjunto de blocos, e mover o conjunto inteiro para cima ou para baixo. Reestruturar um documento assim é dez vezes mais rápido que arrastar com o mouse, e não tem o risco de soltar o bloco dentro de uma coluna por acidente.

**`Cmd/Ctrl + /`** com o cursor num bloco abre o menu de ações daquele bloco (turn into, cor, mover, duplicar, comentar, copiar link). É o `⋮⋮` sem o mouse.

`Cmd/Ctrl + A` tem comportamento progressivo: primeira vez seleciona o texto do bloco, segunda vez seleciona o bloco inteiro, terceira seleciona todos os blocos da página. Útil para "seleciona tudo e converte".

### Drag & drop e multi-seleção

Arrastar pelo `⋮⋮` funciona, e as guias azuis indicam onde o bloco vai cair: linha horizontal = acima/abaixo, linha vertical = cria coluna. **A guia vertical é onde nasce 90% das colunas acidentais do Notion** — você queria mover um bloco para baixo e criou um layout de duas colunas sem perceber.

Multi-seleção por mouse: clique e arraste no espaço vazio à esquerda dos blocos (fora do texto) para desenhar uma seleção retangular. Com blocos selecionados, você pode arrastar todos juntos, aplicar cor de uma vez, converter em conjunto ou transformar em toggle/synced block.

Segurar `Shift` ao clicar em outro bloco estende a seleção. Segurar `Cmd/Ctrl` ao clicar seleciona blocos não contíguos.

### Navegação

| Ação | Mac | Windows/Linux |
|---|---|---|
| Buscar na página | `Cmd + F` | `Ctrl + F` |
| Busca global / quick find | `Cmd + P` ou `Cmd + K` | `Ctrl + P` ou `Ctrl + K` |
| Voltar | `Cmd + [` | `Ctrl + [` |
| Avançar | `Cmd + ]` | `Ctrl + ]` |
| Subir um nível na hierarquia | `Cmd + Shift + U` | `Ctrl + Shift + U` |
| Copiar URL da página | `Cmd + L` | `Ctrl + L` |
| Alternar dark/light mode | `Cmd + Shift + L` | `Ctrl + Shift + L` |
| Nova página (desktop) | `Cmd + N` | `Ctrl + N` |
| Nova janela | `Cmd + Shift + N` | `Ctrl + Shift + N` |
| Nova aba (desktop) | `Cmd + T` | `Ctrl + T` |
| Zoom | `Cmd + +` / `Cmd + -` | `Ctrl + +` / `Ctrl + -` |
| Imagem em tela cheia | `Space` (com bloco selecionado) | `Space` |

`Cmd/Ctrl + P` é o atalho que substitui a sidebar. Se você navega clicando na árvore lateral, está perdendo tempo — a busca rápida chega em qualquer página em duas ou três teclas, e funciona por conteúdo, não só por título.

`Cmd/Ctrl + Shift + U` (subir um nível) é o complemento: navegar para baixo por busca, para cima por atalho. A sidebar vira o que deveria ser — um mapa para consultar quando você se perdeu, não a via de acesso principal.

`Option/Alt + Shift + clique` num link abre em nova janela; `Cmd/Ctrl + clique` abre em nova aba (desktop). Ler documentação comparando duas páginas lado a lado depende disso.

---

## Colar links: as opções de paste

Quando você cola uma URL numa página, o Notion oferece um menu com opções. **Essa é uma decisão de design, não uma formalidade** — e o menu some se você continuar digitando, deixando o padrão (link simples).

| Opção | Resultado | Quando |
|---|---|---|
| `Dismiss` | Link de texto simples | URL no meio de uma frase |
| `Paste as mention` | Chip inline compacto com favicon e título | Vários links num parágrafo |
| `Create bookmark` | Card com título, descrição e imagem | Referência que merece destaque |
| `Create embed` | Iframe interativo do conteúdo | O leitor vai *usar* o conteúdo |
| `Preview` | Visualização viva e autenticada | Jira, GitHub, Figma, Linear (ver [Link previews](https://www.notion.com/help/link-previews)) |

Com **texto selecionado**, colar uma URL não abre menu nenhum: transforma a seleção em hyperlink. É o comportamento mais útil e o menos conhecido.

Colar **Markdown** de outra fonte funciona: o Notion converte headings, listas, negrito, links e code blocks automaticamente. Colar de Google Docs, Word ou uma página web também preserva boa parte da formatação — às vezes preserva demais, trazendo fontes e cores estranhas. Nesse caso, **`Cmd/Ctrl + Shift + V` cola sem formatação**, e você reformata do jeito certo. Para texto vindo de fora, colar sem formatação e reconstruir com atalhos é quase sempre mais rápido que limpar o que veio.

Colar uma **imagem do clipboard** (screenshot) cria bloco de imagem com upload direto. Colar múltiplas linhas de texto cria múltiplos blocos, um por linha — o que é o que você quer 90% das vezes, e é irritante nos outros 10%. Para colar várias linhas dentro de um mesmo bloco, cole e depois junte com `Backspace` no início de cada linha, ou cole dentro de um code block.

### Colar dentro de uma database

Colar um bloco de células de planilha (Excel, Google Sheets) **dentro de uma table view** de database faz o Notion distribuir os valores nas células correspondentes, criando linhas conforme necessário. É a forma mais rápida de popular uma database existente sem passar por importação de CSV — e preserva o schema que você já configurou, ao contrário do import, que cria uma database nova.

O contrário também funciona: selecionar linhas de uma database e copiar gera texto tabulado que cola limpo em planilha.

---

## Modos de página e opções do `•••`

O menu `•••` no topo direito concentra configurações que mudam bastante a experiência da página e que muita gente nunca abriu:

| Opção | O que faz | Quando importa |
|---|---|---|
| `Style` (fonte) | Default / Serif / Mono | Documentos longos ganham com Serif |
| `Small text` | Reduz o tamanho do texto | Dashboards e páginas de referência |
| `Full width` | Remove as margens laterais | Colunas, databases, dashboards |
| `Lock page` | Impede edição acidental | Página de referência estável, template |
| `Customize page` | Backlinks, comentários de página | Wiki com muito ruído de comentário |
| `Move to` | Move a página na hierarquia | Reorganização |
| `Duplicate` | Cópia da página e subpáginas | Base para nova página do mesmo tipo |
| `Undo` | Desfazer no nível da página | — |
| `Version history` | Histórico de versões | Ver adiante |
| `Export` | Markdown / PDF / HTML | Ver adiante |
| `Import` | Traz conteúdo externo para dentro | Ver adiante |

**`Lock page` é subutilizado.** Numa wiki, a diferença entre "documento de referência" e "rascunho coletivo" é justamente essa trava. Ela não impede edição — quem tem permissão destrava com um clique — mas força o gesto consciente, e isso elimina a maior parte das alterações acidentais (o `Backspace` errado, o bloco arrastado sem querer). Página bloqueada também não aceita `Suggest edits`.

**`Customize page`** permite desligar backlinks e discussões por página. Desligar backlinks numa página muito referenciada (um glossário, por exemplo) limpa um contador que não ajuda ninguém. Desligar comentários numa página de política evita que a discussão aconteça no lugar errado.

---

## Importação

O Notion importa de várias origens, com limites que variam por plano. Referência: [Import data into Notion](https://www.notion.com/help/import-data-into-notion).

### Formatos de arquivo

| Formato | O que vira | Limite (Free / Pago) |
|---|---|---|
| **Markdown / Text** | Páginas, múltiplos arquivos | 5 MB / 50 MB |
| **CSV** | **Database** | 5 MB / — |
| **Word (.docx)** | Página com texto, headings, listas, imagens, tabelas | — |
| **HTML** | Páginas, múltiplos arquivos | 5 MB / 50 MB |
| **PDF** | Página(s) | 5 MB / 20 MB |
| **ZIP** | Estrutura de pastas → páginas | Até 5 GB, com limite de contagem de arquivos |
| **Excel** | Precisa converter para CSV antes | — |

**CSV vira database, não tabela.** Isso é o comportamento certo na maioria das vezes, mas significa que importar uma planilha simples cria uma database com todo o overhead que isso implica. Se você só queria a tabela visual, importe e converta, ou monte simple table manualmente.

A importação de CSV **infere tipos de propriedade** — e infere mal com frequência. Datas em formato brasileiro (`19/07/2026`) frequentemente viram texto. Números com vírgula decimal viram texto. Sempre revise o schema depois de importar e corrija os tipos antes de adicionar dados novos.

### Aplicações

| Origem | O que vem | Limitação declarada |
|---|---|---|
| **Evernote** | Notebooks e notas | Confiável até ~5.000 notas; acima disso pode falhar |
| **Trello** | Boards, listas, cards | Confiável até ~5.000 cards por board |
| **Confluence** | Espaços e páginas | Ver [Import from Confluence](https://www.notion.com/help/import-from-confluence) |
| **Google Docs** | Um documento por vez | 5 MB (Free) / 50 MB (pago) |
| **Quip** | Página individual por vez | Sem bulk, sem live apps, polls ou spreadsheets |
| **Dropbox Paper** | Individual ou em lote, como Word | — |
| **WorkFlowy** | Texto plano | — |
| **Hackpad** | Markdown em ZIP | — |

A frase que resume toda importação, e é da própria doc: *"Complex layouts, styling, and app-specific features often need cleanup in Notion."* Traduzindo o que isso significa na prática: **importação traz o conteúdo, não a estrutura.** Você vai reorganizar. Planeje o tempo de limpeza como parte da migração, não como surpresa — normalmente é maior que o tempo da importação em si.

Para migrações grandes, o padrão que funciona é importar num teamspace de staging, limpar lá, e só então mover para o lugar definitivo. Importar direto na estrutura final significa conviver com a bagunça enquanto arruma.

---

## Exportação

`•••` no topo da página → `Export`. Referência: [Export your content](https://www.notion.com/help/export-your-content).

| Formato | O que gera | Bom para |
|---|---|---|
| **Markdown & CSV** | Páginas viram `.md`, databases viram `.csv` | Backup, migração, versionar em Git |
| **PDF** | Documento paginado, com opções de tamanho e escala | Compartilhar externamente, arquivar |
| **HTML** | Páginas em HTML, **inclui comentários** (de página e de bloco) | Arquivamento com fidelidade visual |

Opções disponíveis: `Include content` (tudo ou excluindo arquivos e imagens), `Include subpages`, `Page format` (tamanho do papel, PDF), `Scale percent` (PDF).

### As limitações reais

Esta é a parte que ninguém lê antes de precisar:

- **`Include subpages` é recurso de Business/Enterprise.** Nos planos menores você exporta página por página. Para um workspace com centenas de páginas, isso é inviável na prática.
- **Export do workspace inteiro também é Business/Enterprise.**
- **Não dá para exportar uma `Form view` de database.**
- **Emojis customizados não aparecem no PDF.**
- **Database full page não imprime direto do navegador** — exporte para PDF primeiro pelo app desktop.
- **O link de export expira em 7 dias.**
- **Windows tem o problema do limite de 260 caracteres de caminho** — exports de hierarquias profundas com títulos longos falham ao descompactar.
- **Workspaces Enterprise podem ter export desabilitado pelo admin.**
- **Guests precisam de `Full access` para exportar.**
- **Você não recria o workspace re-subindo o export.** Isso é declarado pela própria Notion. O export é backup de *conteúdo*, não de *sistema*: relations quebram, views se perdem, fórmulas viram texto, automações desaparecem.

O que isso significa estrategicamente: **o Notion não tem uma saída barata.** Se a portabilidade dos dados é requisito real do seu contexto, saiba disso antes de colocar cinco anos de conhecimento institucional lá dentro. Ver também [Back up your data](https://www.notion.com/help/back-up-your-data).

O export de Markdown é o mais fiel para texto e o único que dá para versionar. Ele preserva headings, listas, links, code blocks e imagens (como arquivos em pasta paralela). Perde: cores, callouts (viram blockquote ou texto), colunas (viram sequência linear), synced blocks (comportamento imprevisível), toggles (viram `<details>` ou listas), e toda a configuração de database.

---

## Turn into e Turn into page

`⋮⋮` → `Turn into` converte o bloco atual em outro tipo. Funciona com múltiplos blocos selecionados, o que é onde ele brilha: selecionar quinze parágrafos e virar bullets de uma vez.

`Turn into page` é diferente e mais interessante: converte o bloco (e o conteúdo aninhado nele) numa **subpágina**, deixando no lugar original um link. É o movimento natural do documento que cresce: você escreve um item de lista, ele vira três parágrafos, você percebe que merece um doc — `Turn into page` e pronto, sem copiar, colar ou perder histórico.

O inverso não existe de forma limpa. Não há "turn page into block" — você abre a página, seleciona tudo, recorta e cola de volta. Por isso, na dúvida, **prefira não criar a subpágina cedo demais**: promover um bloco a página é trivial, rebaixar uma página a bloco é trabalho manual.

Ver [Transforming content blocks in Notion](https://www.notion.com/help/guides/transforming-content-blocks-in-notion).

---

## Comentários, discussões e sugestões

Três mecanismos diferentes de colaboração, com propósitos distintos. Referência: [Comments, mentions, and reactions](https://www.notion.com/help/comments-mentions-and-reminders).

### Inline comments

Selecione texto → `Comment` no menu que aparece, ou `Cmd/Ctrl + Shift + M`. O comentário fica ancorado naquele trecho.

Use para feedback pontual: "essa data está certa?", "falta o link aqui". Resolvê-lo (`✔️`) tira da visão e arquiva. O painel de comentários (ícone 💬 no topo) lista tudo e permite filtrar por pessoa e por status — que é como você acha os comentários abandonados de seis meses atrás.

**Comentário em bloco que depois é deletado some junto.** Se a discussão importa, ela vira decisão registrada no corpo do documento, não fica só no comentário.

### Page discussions (top-level)

Passe o mouse no topo da página → `Add comment`. É a conversa sobre o documento como um todo, não sobre um trecho.

Use para feedback de alto nível ("acho que falta a seção de riscos") e para o registro de aprovação. Elas podem ser desabilitadas por página nas opções de layout — o que faz sentido em página de referência que não é para ser discutida.

### Suggested edits

`•••` no topo da página → `Suggest edits`. Você entra num modo onde digitar propõe adições e deletar propõe remoções, e o autor decide. Referência: [Suggested edits](https://www.notion.com/help/suggested-edits).

Requisitos e limites que importam:

- Precisa de acesso **`Can comment` ou superior**.
- A página **não pode estar locked**.
- **Não funciona em peek view de database inline nem em propriedades de database.**
- **Só funciona em: text, to-do, headings, bulleted list e numbered list.** Callout, código, imagem, tabela, toggle — nada disso aceita sugestão. Isso limita bastante o uso em documentação técnica de verdade.

O dono da página recebe notificação no inbox e responde com `✔️` (aceitar), `✗` (rejeitar), emoji ou comentário.

**Quando usar cada um:** comentário para perguntar, suggested edit para propor a correção. A regra social que funciona em time: se você sabe qual é o texto certo, sugira; se você só sabe que algo está errado, comente. Comentário dizendo "acho que a palavra está errada" quando você sabe a palavra certa é trabalho empurrado para outra pessoa.

### Reações

Selecione texto → `🙂`, ou passe o mouse num comentário e escolha um emoji. Serve para o "concordo" e o "vi" sem gerar mais uma notificação de comentário. Subestimado como redutor de ruído.

---

## Histórico de versões

`•••` no topo da página → `Version history`.

Uma nova versão é gravada **a cada 10 minutos de edição ativa**, e mais uma **2 minutos após a última edição**. A retenção depende do plano:

| Plano | Retenção de versões |
|---|---|
| Free | 7 dias |
| Plus | 30 dias |
| Business | 90 dias |
| Enterprise | Ilimitada |

Documentado em [Duplicate, delete, and restore content](https://www.notion.com/help/duplicate-delete-and-restore-content). Enterprise pode customizar a retenção — ver [Notion's data retention settings](https://www.notion.com/help/guides/notions-data-retention-settings) — e o histórico completo de quem alterou o quê aparece no plano Enterprise.

Duas formas de usar o histórico, e a segunda é a boa:

1. **Restaurar a versão inteira** — o botão `Restore`. É reversível: depois de restaurar, você ainda pode voltar para qualquer outra versão dentro da janela de retenção.
2. **Copiar blocos de uma versão antiga e colar na atual** — muito mais cirúrgico. Alguém apagou uma seção há três dias e o resto da página evoluiu desde então; restaurar a versão inteira perderia as evoluções. Copiar só a seção resolve sem colateral.

### Trash e recuperação

Páginas deletadas vão para o **Trash**, onde ficam **30 dias** antes da deleção permanente. Dá para buscar e filtrar no trash por último editor, localização e teamspace — o que salva quando alguém apagou "alguma coisa" e ninguém lembra o nome. Depois da deleção permanente, ainda há **30 dias adicionais** de retenção interna antes de a página ficar inacessível para todos, inclusive workspace owners.

Note que isso é retenção do lado da Notion, não uma lixeira que você acessa: recuperar nessa janela pode exigir contato com o suporte.

Para arquivar sem deletar, existe [Archive pages](https://www.notion.com/help/archive-pages) — tira da navegação sem entrar no relógio de 30 dias.

### Page analytics

Ícone 🕘 (`View all updates`) no topo direito → aba `Analytics`. Mostra visualizações e, em **Business e Enterprise**, quem criou a página e a lista de todos que editaram. Ver [Page analytics](https://www.notion.com/help/page-analytics).

O uso real disso não é vaidade — é **auditoria de wiki**. Página com muitas visualizações e nenhuma edição há um ano é a mais perigosa do workspace: muita gente confia nela e ninguém verificou se ainda é verdade. Página com zero visualizações em seis meses é candidata a arquivamento. Ver [Tips to keep your team's Notion pages up to date](https://www.notion.com/help/guides/tips-to-keep-your-teams-notion-pages-up-to-date).

---

## Fluxos que valem automatizar na memória muscular

Alguns encadeamentos que resolvem tarefas comuns muito mais rápido que o caminho óbvio.

**Reestruturar um documento longo:**
`Esc` → `Shift + ↓` para pegar a seção → `Cmd/Ctrl + Shift + ↑/↓` até a posição → `Esc`. Sem mouse, sem risco de criar coluna acidental.

**Transformar texto colado em documento estruturado:**
Cole com `Cmd/Ctrl + Shift + V` (sem formatação) → selecione tudo (`Cmd/Ctrl + A` três vezes) → converta o grosso em bullets → volte nas linhas de título e faça `## ` nelas. Mais rápido que limpar formatação herdada.

**Quebrar uma página que cresceu demais:**
Selecione a seção → `Turn into page` → repita. A página original vira índice de links automaticamente.

**Extrair um trecho para outra página sem perder o link:**
`Cmd/Ctrl + /` no bloco → `Copy link to block` → cole na página de destino como mention. O leitor navega para o ponto exato.

**Documentar uma decisão sem interromper o texto:**
Selecione o trecho → `Cmd/Ctrl + Shift + M` → escreva o contexto no comentário. A decisão fica registrada e o corpo do texto continua limpo. Se depois ela virar regra, promova para o corpo.

**Achar aquela página que você não lembra o nome:**
`Cmd/Ctrl + P` e digite qualquer palavra do *conteúdo*, não do título. A busca do Notion indexa o corpo. Ver [Search](https://www.notion.com/help/search).

**Converter uma lista bagunçada em database:**
Selecione os itens → copie → crie uma table view → cole na primeira célula. Cada linha vira uma entrada. Muito mais rápido que digitar de novo, e mais confiável que exportar CSV e reimportar.

**Colar uma reunião do Slack/Meet e transformar em ata:**
`Cmd/Ctrl + Shift + V` para tirar a formatação → selecione as linhas de decisão e converta em to-do → transforme os nomes em `@menção` para que as pessoas sejam notificadas. Dois minutos, e a ata sai com responsáveis notificados.

---

## Editor no mobile

O editor mobile não é o desktop com tela menor — ele tem um modelo de interação diferente, e isso muda o que faz sentido escrever no telefone. Ver [Notion for mobile](https://www.notion.com/help/notion-for-mobile).

O que muda:

- **Não existe `/` prático.** O acesso a blocos é pela barra acima do teclado (`+` e a fileira de atalhos de formatação). Ela cobre os blocos comuns e nada além.
- **Colunas não são renderizadas.** O conteúdo da coluna direita aparece empilhado abaixo do da esquerda.
- **Arrastar blocos é impreciso.** Reordenação séria não se faz no celular.
- **Markdown de digitação funciona** — `#`, `-`, `[]`, `>` continuam valendo, e é a forma mais rápida de estruturar no telefone.
- **Databases ficam limitadas.** Views complexas com muitas propriedades são desconfortáveis; edição de propriedade funciona bem.

A consequência prática: **o mobile é para capturar e consultar, não para estruturar.** Escrever a ideia, marcar a tarefa como feita, ler o runbook. Montar a página, configurar a view, organizar colunas — desktop. Tentar fazer design de página no celular é frustração garantida, e o resultado costuma quebrar no desktop.

---

## O que não fazer no editor

**Não formate enquanto escreve o primeiro rascunho.** Escreva tudo em texto puro, depois passe convertendo. Formatar durante a escrita é a forma mais eficiente de escrever menos e demorar mais — e o editor do Notion torna a conversão posterior barata justamente para isso.

**Não use `Enter` para criar espaço vertical.** Blocos vazios são blocos: aparecem na navegação por teclado, quebram o export, e o Notion já gerencia espaçamento entre tipos de bloco automaticamente. Se você precisa de mais respiro, o problema é falta de heading ou divider, não falta de linha em branco.

**Não confie no comportamento de colar sem verificar.** Colar de fora traz sujeira invisível — cor de texto herdada, fonte diferente, tamanho estranho. Isso não aparece no light mode e explode no dark mode. `Cmd/Ctrl + Shift + V` por padrão para conteúdo externo.

**Não use o mouse para navegar.** `Cmd/Ctrl + P` é mais rápido que a sidebar em todos os casos onde você sabe o que procura, que são quase todos.

**Não confie no export como backup de sistema.** Ele preserva texto. Não preserva a estrutura que você levou meses construindo. Se o workspace é crítico, a estratégia de backup precisa considerar isso — e não existe solução perfeita, o que é uma informação que vale saber antes e não depois.
