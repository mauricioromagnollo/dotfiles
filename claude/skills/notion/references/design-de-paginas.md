# Design de páginas

O Notion é um péssimo editor gráfico e um excelente sistema de documentos. Quase toda página feia do Notion está feia porque alguém tentou fazer design *gráfico* nele — gradientes, banners, quinze cores, ícones de cinco estilos diferentes — em vez de design *editorial*, que é o que a ferramenta faz bem.

O que o Notion oferece é ridiculamente pouco: três fontes, dez cores, dois níveis de largura, três níveis de heading. Essa escassez é uma vantagem. Com poucas variáveis, consistência é fácil e o resultado parece profissional quase por acidente — desde que você use as variáveis com significado em vez de com entusiasmo.

A regra que governa este arquivo inteiro: **página bonita no Notion é página que se lê rápido.** Estética é subproduto da legibilidade, nunca o contrário. Se você precisa escolher entre "mais bonito" e "mais rápido de entender", a segunda opção é sempre a certa, e quase sempre acaba sendo também a mais bonita.

---

## Hierarquia visual: a única coisa que importa de verdade

Um leitor decide em dois segundos se a página serve para ele. Nesses dois segundos ele processa, nessa ordem: **ícone, título, primeira linha, formato geral do bloco de texto**. Cor não entra. Callout não entra. O que decide é se a página *parece* ter estrutura.

Hierarquia no Notion se faz com três instrumentos, e só:

**Tamanho** — headings. Você tem três degraus. Use-os como degraus reais: H2 para seções, H3 para subseções, H1 apenas em documentos longos onde ele separa grandes partes. Nunca comece a página com H1 — o título já é o H1 visual, e um segundo H1 logo abaixo cria duas raízes brigando.

**Espaço** — divider e o espaçamento natural entre tipos de bloco. O Notion tem um sistema de espaçamento consciente de vizinhança: itens de lista adjacentes ficam compactos entre si, e ganham respiro quando encostam num bloco de outro tipo. Isso é automático e bem calibrado. Detalhado em [Updating the design of Notion pages](https://www.notion.com/blog/updating-the-design-of-notion-pages). Confie nele e pare de adicionar blocos vazios.

**Peso** — negrito, callout, cor de fundo. Este é o instrumento mais barato e o mais desperdiçado. Peso funciona por contraste: uma coisa em destaque numa tela é destaque; cinco coisas em destaque numa tela é uma tela sem destaque.

A pergunta de diagnóstico, e ela resolve a maioria dos casos de "essa página tá feia": **feche os olhos, abra, e olhe a página por meio segundo. O que salta?** Se a resposta for "nada" ou "tudo", o problema é hierarquia, não estética. Nenhuma quantidade de emoji conserta isso.

---

## Largura, fonte e tamanho de texto

Três configurações no menu `•••` do topo direito. Documentadas em [Customize and style your content](https://www.notion.com/help/customize-and-style-your-content).

### Full width

Encolhe as margens e alarga a área de conteúdo até a largura da janela.

**Ative para:** dashboards, páginas com colunas, databases full page, galerias, qualquer coisa que seja uma *interface*.

**Não ative para:** documentos de leitura. A largura padrão do Notion não é limitação, é decisão tipográfica — linhas de 60 a 80 caracteres são o que o olho lê confortavelmente. Um documento de texto em full width numa tela de 27 polegadas produz linhas de 200 caracteres, e o leitor perde a linha ao voltar para a esquerda. Isso é fisiologia, não gosto.

A regra: **full width para grade, largura padrão para prosa.** Se a página tem colunas, provavelmente quer full width. Se tem parágrafos, quase certamente não.

### Small text

Reduz o tamanho da fonte de todo o texto da página.

Serve para densidade em páginas de referência e dashboards — tabelas, listas de links, metadados. Não serve para documento que alguém vai ler por dez minutos. E cuidado com o efeito colateral: small text piora o contraste percebido, o que agrava qualquer problema de cor que a página já tenha (ver a seção de cor adiante).

Small text + full width juntos é a combinação típica de dashboard. Small text + largura padrão + parágrafos longos é hostilidade.

### As três fontes

`Default` (sans-serif), `Serif`, `Mono`.

**Default** é o certo em 95% dos casos. É o que o time reconhece, o que renderiza melhor em todos os dispositivos, e o que não chama atenção para si.

**Serif** funciona para documentos longos de leitura contínua: um post, um ensaio interno, uma política, uma retrospectiva escrita. Serif comunica "isso é para ler", e é surpreendentemente eficaz em fazer as pessoas realmente lerem. Não use em dashboard, database ou página de referência — em texto curto e fragmentado, serif fica pretensioso.

**Mono** é uma armadilha quase sempre. Ele parece "técnico" e é tentador para documentação de engenharia, mas monospace em texto corrido é mais lento de ler, ocupa mais espaço horizontal e cansa. Se você quer que o código pareça código, use code block e inline code — não transforme o documento inteiro em mono. O uso legítimo de Mono é uma página que é literalmente uma listagem: configurações, comandos, tabela de constantes.

**A consistência importa mais que a escolha.** Um workspace onde metade das páginas é serif e metade default parece descuidado mesmo que cada página isolada esteja boa. Escolha uma convenção — por exemplo, "default sempre, serif só em long-form" — e aplique.

---

## Ícones e covers

### Ícones

Todo página tem ícone, e o ícone é a coisa que o leitor processa primeiro — na sidebar, na busca, no breadcrumb, nos cards de gallery, nas menções inline. Um workspace com ícones bons navega visualmente; um sem ícones é uma lista de texto cinza.

Três opções:

| Tipo | Quando |
|---|---|
| **Emoji** | Padrão. Rápido, universal, renderiza em todo lugar |
| **Ícone da biblioteca do Notion** | Quando você quer um sistema visual coerente e sóbrio |
| **Upload custom** | Logos, ícones de marca, sets externos (Icons8, Feather, Lucide, Phosphor, Notion Icon Sets) |

A biblioteca nativa de ícones do Notion é subutilizada e é a melhor opção para wikis e workspaces corporativos: são ícones de linha, com **cor configurável**, e o resultado é imediatamente mais profissional que emoji. A vantagem decisiva é que todos compartilham o mesmo estilo — o que emoji nunca garante, porque emoji renderiza diferente em cada sistema operacional.

Para upload, o tamanho ideal é **280 x 280 pixels**.

**A regra de ouro dos ícones é consistência de sistema, não beleza individual.** Escolha um esquema e mantenha:

- *Por categoria*: todas as páginas de projeto usam 📁, todas de reunião usam 🗓️, todas de doc técnico usam 📄. O ícone vira tipo, e a sidebar vira legível de relance.
- *Por cor*: usando a biblioteca do Notion, cada teamspace tem uma cor de ícone. Navegação por cor funciona mais rápido que por forma.
- *Por nada*: emoji aleatório escolhido por gosto no momento da criação. É o padrão de fato na maioria dos workspaces, e é por isso que a maioria das sidebars é ilegível.

Misturar emoji e ícone de linha na mesma sidebar é o erro mais visível de todos. Emoji é colorido e arredondado; ícone de linha é monocromático e geométrico. Lado a lado, parecem duas ferramentas diferentes.

Nota lateral: o [Notion Faces](https://www.notion.com/help/notion-faces) (faces.notion.com) gera retratos no estilo da marca, pensado para foto de perfil. Bom para páginas de pessoas e diretórios de time.

### Cover images

A faixa no topo da página. Largura mínima recomendada: **1.500 pixels**.

Cover é o elemento mais mal usado do Notion. Ele existe para dar identidade e ajudar reconhecimento — não para ser bonito. Três usos que funcionam e um que não:

**Funciona: cor sólida ou gradiente sutil.** As cores nativas do Notion (a galeria de gradientes) são discretas de propósito. Uma cor por teamspace ou por tipo de página cria reconhecimento instantâneo sem competir com o conteúdo.

**Funciona: textura ou abstrato de baixo contraste.** Unsplash está integrado direto no seletor de cover. Busque por "texture", "gradient", "abstract", "minimal" — não por "office", "teamwork", "success". Foto genérica de banco de imagens envelhece mal e não comunica nada.

**Funciona: cover como banner informativo.** Uma imagem 1500x300 feita no Figma/Canva com o nome do sistema e nada mais. Em hub pages e homepages isso substitui bem um título gigante.

**Não funciona: foto detalhada e contrastada.** O ícone da página fica sobreposto ao cover, e a transição para o título abaixo precisa ser calma. Uma foto de paisagem com muita informação transforma o topo da página numa competição visual onde o título perde.

Cover pode ser reposicionado (`Reposition`) — use isso, porque o crop automático quase nunca acerta.

**Quando não usar cover:** páginas operacionais que você abre vinte vezes por dia. O cover empurra o conteúdo para baixo e custa um scroll toda vez. Numa página de tarefas diárias, o cover é 200 pixels de nada entre você e o trabalho. Reserve covers para páginas de entrada — hubs, homepages, wikis — e deixe as páginas de trabalho sem.

---

## A paleta de cores

O Notion tem **9 cores nomeadas + Default**, disponíveis tanto como cor de texto quanto como cor de fundo (background):

`Default` · `Gray` · `Brown` · `Orange` · `Yellow` · `Green` · `Blue` · `Purple` · `Pink` · `Red`

Aplicáveis a texto selecionado, a blocos inteiros (via `⋮⋮` → cor, ou `Cmd/Ctrl + /`), a callouts, a ícones da biblioteca nativa e a tags de database. Também via slash: `/red`, `/blue background` etc.

### A regra que separa workspace profissional de workspace de amador

**Cor deve significar alguma coisa, e a mesma coisa em todo lugar.**

Se amarelo quer dizer "atenção" numa página e "em andamento" na outra e "destaque genérico" numa terceira, amarelo não quer dizer nada — e o leitor aprende, em uma semana, a ignorar cor completamente. A partir daí você perdeu o instrumento: quando algo for realmente urgente, colorir não vai adiantar.

Um sistema de cor que funciona precisa ser declarado e curto. Exemplo de convenção defensável:

| Cor | Significado | Onde aparece |
|---|---|---|
| Red | Bloqueio, risco, ação destrutiva | Callout de aviso, status `Blocked` |
| Yellow | Atenção, pendente, em revisão | Callout de nota, status `In review` |
| Green | Concluído, aprovado, saudável | Status `Done`, callout de sucesso |
| Blue | Informação, link, referência | Callout de contexto, categoria `Doc` |
| Gray | Secundário, arquivado, metadado | Texto de apoio, itens desativados |
| Default | Todo o resto | Corpo do texto |

Cinco cores com significado batem dez cores decorativas. **Se você não consegue escrever a tabela acima para o seu workspace, use uma cor só.**

### Cor de texto vs cor de fundo

São instrumentos diferentes e são confundidos o tempo todo.

**Cor de texto** é sutil. Funciona para diferenciar sem destacar — um texto cinza para metadado, um azul para link visual, um vermelho discreto para um número negativo. É apropriada para uso frequente porque não grita.

**Cor de fundo** é destaque forte. Ela pinta o bloco inteiro e cria um bloco visual. Deve ser rara: um a dois por tela. Background em muitos blocos transforma a página numa colcha de retalhos e destrói qualquer hierarquia que os headings tenham estabelecido.

O erro característico: usar background para "organizar" — cada seção com sua cor de fundo. O resultado é uma página onde tudo tem a mesma importância (nenhuma) e que fica ilegível no dark mode.

### Contraste, acessibilidade e o problema do dark mode

As cores de texto do Notion no light mode têm contraste aceitável na maioria dos casos. **Amarelo é a exceção óbvia**: texto amarelo em fundo branco é praticamente ilegível, e continua sendo o erro mais comum de cor no Notion. Se você quer amarelo, use como *background* com texto default, nunca como cor de texto.

O dark mode (`Cmd/Ctrl + Shift + L`) inverte fundos e ajusta as cores automaticamente — e o ajuste é bom, mas não é perfeito. O que quebra:

- **Imagens PNG com fundo branco** viram retângulos brancos gritantes no meio da página escura. Diagramas, logos e screenshots com fundo claro são o problema número um do dark mode em Notion. Solução: exportar com fundo transparente, ou aceitar e padronizar um fundo claro consistente.
- **Cor de texto colada de fora.** Texto que veio de Google Docs ou Word carrega cor explícita (geralmente preto puro `#000`), que o Notion não converte no dark mode. O resultado é texto preto em fundo escuro — invisível. Isso não aparece para quem escreveu (light mode) e afeta metade do time. Solução: colar sem formatação (`Cmd/Ctrl + Shift + V`) sempre.
- **Covers e banners feitos com fundo branco** ficam com uma borda dura contra a página escura.
- **Contraste de cores claras** — amarelo e verde claro perdem legibilidade sobre fundo escuro.

**Sempre teste no dark mode antes de considerar uma página pronta.** É um atalho de teclado e leva três segundos. Cerca de metade dos usuários de Notion está em dark mode, e eles são invisíveis para você até reclamarem.

---

## Callouts como elementos de UI

O callout é o único bloco do Notion que funciona como *container visual*: tem borda, fundo, ícone e aceita conteúdo aninhado. Isso o torna a peça central de qualquer interface montada no Notion — e também o bloco mais abusado.

### O uso comum (aviso)

Callout com ícone e cor comunicando um tipo de mensagem. Funciona, desde que o vocabulário seja consistente:

```
💡 Dica          → fundo Gray ou Blue
⚠️ Atenção       → fundo Yellow
🚫 Não faça      → fundo Red
✅ Confirmado    → fundo Green
📌 Contexto      → fundo Default (sem cor)
```

Repare no último: **callout sem cor de fundo existe e é subestimado**. Ele dá estrutura (ícone + recuo) sem gritar. Numa página que já tem um callout colorido, os demais deveriam ser sem cor.

### O uso interessante (container de UI)

Callouts aceitam blocos aninhados: dê `Enter` dentro do callout e continue escrevendo, ou arraste blocos para dentro. Com isso, um callout vira um **card**:

```
┌─────────────────────────────────────┐
│ 🚀  Deploy                          │  ← ícone + heading dentro do callout
│                                     │
│     • Checklist pré-deploy          │  ← lista dentro
│     • Runbook de rollback           │
│     • Canal #deploys                │
│                                     │
│     [Abrir pipeline]                │  ← botão dentro
└─────────────────────────────────────┘
```

Três desses lado a lado em colunas viram uma grade de cards de navegação — o padrão visual mais eficaz para uma homepage de Notion, e feito só com blocos nativos.

Variação: callout com fundo `Gray` contendo apenas links e um heading pequeno vira uma "sidebar" quando colocado numa coluna estreita à direita.

### Quando NÃO usar callout

- **Quando tudo é callout.** Se três blocos seguidos são callouts, nenhum deles destaca nada. Vira um padrão de listras coloridas.
- **Para citação literal.** Isso é `quote`. Callout é para voz do documento; quote é para voz de outra pessoa.
- **Para o conteúdo principal.** Callout envolvendo o parágrafo mais importante da página é redundante: se é o principal, ele já está no topo, e o topo já é destaque.
- **Aninhado em três níveis.** Callout dentro de callout dentro de toggle come margem, quebra no mobile e é insuportável de editar.

**O teste:** se você remover o callout e o conteúdo continuar fazendo sentido no mesmo lugar, o callout provavelmente é decoração. Callout legítimo é aquele cuja remoção faria alguém perder uma informação de contexto ou cometer um erro.

---

## Columns: layout e o precipício do mobile

Colunas são a única ferramenta real de layout do Notion. Criam-se arrastando um bloco pelo `⋮⋮` até o lado de outro, seguindo a guia azul vertical, ou por `/column`. Redimensionam-se arrastando a divisória. Ver [Columns, headings, and dividers](https://www.notion.com/help/columns-headings-and-dividers).

### O fato que decide tudo

**Colunas não existem no celular.** Em tablet sim; em telefone, o conteúdo da coluna direita simplesmente é empilhado abaixo do da esquerda. A doc é explícita: *"Columns are available on tablet but not mobile."*

Isso significa que todo layout de colunas tem uma segunda versão — a versão empilhada — e você é responsável por ela mesmo sem vê-la. Duas consequências de projeto:

1. **A ordem das colunas é a ordem de leitura no mobile.** Coloque na esquerda o que precisa ser visto primeiro. Um layout com "navegação | conteúdo" fica correto; um com "conteúdo | navegação" faz o usuário de celular rolar todo o conteúdo antes de encontrar a navegação.
2. **Colunas com dependência visual quebram.** Uma coluna com o gráfico e outra com a legenda, lado a lado, viram gráfico-depois-legenda separados por uma tela de scroll.

### Quantas colunas

| Colunas | Uso | Veredito |
|---|---|---|
| 2 | Conteúdo + apoio, comparação, texto + imagem | Seguro sempre |
| 3 | Grade de cards, dashboard, hub | Teto confortável |
| 4 | Grade de ícones/links curtos | Só com conteúdo curtíssimo |
| 5+ | — | Não |

E dentro de cada coluna, o conteúdo fica estreito: um code block com linhas longas numa coluna de 1/3 da largura vira scroll horizontal dentro de uma caixa dentro de uma coluna, que é a pior experiência de leitura possível no Notion. **Code block, tabela larga e imagem detalhada querem largura total.**

Colunas assimétricas (arrastar a divisória para fazer 70/30) são quase sempre melhores que colunas iguais para "conteúdo + apoio". Duas colunas de 50% dão a impressão de que os dois lados têm a mesma importância — o que raramente é verdade.

### Para remover colunas

Arraste o conteúdo da direita de volta para baixo do da esquerda até aparecer a guia azul de largura total. É desajeitado e é assim mesmo.

---

## Toggle headings e densidade

Este é o instrumento mais poderoso de design de página no Notion, e o menos usado.

O problema que ele resolve: documentação completa e documentação legível são objetivos em conflito. Você quer registrar tudo — e quer que a página caiba numa tela. Toggle heading resolve o conflito literalmente: tudo está lá, colapsado, e a página inteira vira um índice navegável.

O contraste é brutal. Uma página de runbook com 12 seções:

```
SEM toggle headings              COM toggle headings
─────────────────────            ─────────────────────
## Pré-requisitos                ▸ Pré-requisitos
(18 linhas)                      ▸ Acesso e credenciais
## Acesso e credenciais          ▸ Deploy normal
(24 linhas)                      ▸ Rollback
## Deploy normal                 ▸ Incidente P1
(31 linhas)                      ▸ Incidente P2
## Rollback                      ▸ Contatos de plantão
(12 linhas)                      ▸ Métricas e alertas
...                              ▸ Pós-mortem
                                 ▸ FAQ
= 400 linhas de scroll           ▸ Histórico de mudanças
                                 ▸ Referências
                                 = 12 linhas, uma tela
```

Na versão da direita, quem precisa de rollback às 3h da manhã encontra em dois segundos. Na da esquerda, rola por um minuto entrando em pânico.

**Use toggle heading quando:** o conteúdo é consultado por seção, não lido em sequência. Runbook, FAQ, glossário, onboarding, referência de API, changelog, documentação de processo.

**Não use quando:** o documento é narrativo e deve ser lido do início ao fim (uma proposta, um post, um pós-mortem). Colapsar uma narrativa esconde o argumento.

**A armadilha crítica:** conteúdo dentro de toggle fechado **não é encontrado pelo `Cmd/Ctrl + F`** da página até você expandir. Se a informação é a que alguém procura em emergência — o telefone do plantão, o comando de rollback, a senha do cofre — ela fica **fora** de toggle, no topo, em callout. Progressive disclosure é para o que pode esperar um clique.

Toggle heading também aparece corretamente no `Table of contents`, ao contrário de toggle list. Se você quer índice + colapso, é toggle heading.

---

## Dividers e respiro

Divider (`---`) é o bloco mais barato do Notion e o mais mal calibrado.

**Não use divider antes de um heading.** O heading já separa — visualmente e semanticamente. Divider + heading é redundância que adiciona uma linha de ruído em toda transição de seção. Essa é a causa mais comum de página que "parece cheia" sem ter muito conteúdo.

**Use divider para separar blocos do mesmo nível** onde não há heading: entre uma grade de cards e o rodapé, entre o hero e o conteúdo, entre grupos de links dentro de uma mesma seção. Divider marca uma pausa dentro de um nível, não entre níveis.

Sobre espaço em branco: **não crie blocos vazios para gerar respiro.** O Notion gerencia espaçamento entre tipos de bloco de forma consciente de vizinhança e faz isso bem. Blocos vazios aparecem na navegação por teclado, sujam o export e criam espaçamento inconsistente entre light e dark mode. Se a página parece apertada, o problema é falta de heading — não falta de linha em branco.

---

## Padrões de layout

Cinco esquemas que cobrem quase tudo que se monta em Notion. Copie a estrutura e adapte o conteúdo.

### 1. Hub page (homepage de time ou pessoal)

Ver também: a regra de construção da home — sem database próprio, teto de ~9 blocos — em [`sistemas-prontos.md`](./sistemas-prontos.md) §10, e as linked views que a preenchem em [`views-filtros-e-agrupamento.md`](./views-filtros-e-agrupamento.md) §6.

Largura: **full width**. Fonte: default. Cover: sim, sóbrio.

```
┌──────────────────────────────────────────────────────────┐
│  [ COVER — cor sólida ou gradiente, 1500x300 ]           │
│  🏠                                                       │
│  Engenharia                                               │
│  Tudo que o time precisa, em um lugar.        ← 1 linha  │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐               │
│  │ 📘        │  │ 🚀        │  │ 🔧        │  ← callouts │
│  │ Wiki      │  │ Deploys   │  │ Runbooks  │    como     │
│  │ • Onbo... │  │ • Pipe... │  │ • Incid...│    cards    │
│  │ • Padrões │  │ • Ambien..│  │ • Plantão │             │
│  └──────────┘  └──────────┘  └──────────┘               │
│                                                           │
│  ───────────────────────────────────────────             │
│                                                           │
│  ## Em andamento                                          │
│  [ linked view: Projetos, filtro Status = Active,        │
│    board agrupado por Owner, 5 itens ]                    │
│                                                           │
│  ## Precisa de atenção                                    │
│  [ linked view: Tasks, filtro Blocked, list, 3 itens ]   │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

Princípios: o hero (ícone + título + uma linha) diz o que é. A grade de cards é navegação. As linked views abaixo são o estado atual, filtradas para caber sem scroll. **Nada aqui deveria exigir rolar mais de uma tela e meia.**

O erro típico: hub com dez linked views empilhadas. Isso não é hub, é um relatório — e é lento de carregar.

**Grade de cards ou linha de links inline?** A grade se justifica quando os destinos são **poucos (3 a 5), heterogêneos e nem todo mundo sabe o que tem dentro** — é o caso de um hub de time, onde o card carrega ícone, nome e duas linhas de conteúdo, e o custo de espaço compra descoberta. Quando os destinos são **muitos, homogêneos e você já sabe de cor onde clicar** — a lista de databases da sua home pessoal, por exemplo — a grade só empurra o conteúdo útil para baixo da dobra: aí a resposta certa é uma linha única de links inline, como em [`sistemas-prontos.md`](./sistemas-prontos.md) §10. Regra curta: **card para quem vai descobrir, link inline para quem vai voltar.**

### 2. Wiki / documentação de referência

Largura: **padrão**. Fonte: default ou serif. Cover: opcional.

```
┌────────────────────────────────────────────┐
│  📄  Guia de code review                    │
│                                             │
│  💡 Última revisão: jul/2026 · Owner: @Mau │ ← callout de metadado
│                                             │
│  [ /toc ]                                   │
│  ───────────────────────────────────────    │
│                                             │
│  Um parágrafo dizendo para que serve.      │
│                                             │
│  ## Como funciona                           │
│  (texto)                                    │
│                                             │
│  ## Checklist do revisor                    │
│  ▸ Antes de abrir o PR                     │ ← toggle headings
│  ▸ Durante a revisão                       │
│  ▸ Antes de aprovar                        │
│                                             │
│  ## Casos especiais                         │
│  ▸ Hotfix                                  │
│  ▸ Mudança de schema                       │
│                                             │
└────────────────────────────────────────────┘
```

O callout de metadado no topo (dono + data da última revisão) é o detalhe que separa wiki viva de wiki abandonada. Sem ele, ninguém sabe se a página ainda vale. Ver também [Wikis and verified pages](https://www.notion.com/help/wikis-and-verified-pages), que traz a marcação oficial de página verificada com data de expiração.

### 3. Dashboard

Largura: **full width**. Fonte: default. **Small text: sim.** Cover: não.

```
┌──────────────────────────────────────────────────────────┐
│  📊  Painel — Semana                                      │
├──────────────────────────────────────────────────────────┤
│  ┌────────────┐  ┌────────────┐  ┌────────────┐         │
│  │ Abertas    │  │ Bloqueadas │  │ Vencendo   │  ← 3 col│
│  │ [view, 5]  │  │ [view, 3]  │  │ [view, 4]  │         │
│  └────────────┘  └────────────┘  └────────────┘         │
│  ───────────────────────────────────────────             │
│  ┌──────────────────────┐  ┌──────────────────────┐     │
│  │ [ chart: por status ]│  │ [ calendar: sprint ] │     │
│  └──────────────────────┘  └──────────────────────┘     │
└──────────────────────────────────────────────────────────┘
```

Regras de dashboard, e elas são inegociáveis: **cada view mostra poucos itens** (limite de itens visíveis + filtro apertado), **nenhuma view tem scroll interno**, e **a página inteira cabe em uma tela e meia**. Dashboard que exige rolar não é dashboard, é uma lista de listas.

Em Business/Enterprise existe a **Dashboard view** nativa, que junta widgets num painel (máximo 12 widgets, até 4 por linha) — `/dash`. Ver [Dashboards](https://www.notion.com/help/dashboards). Nos planos menores, o padrão acima com linked views é a única opção, e funciona.

Sobre performance: cada linked view é uma query. Oito views numa página é uma página que demora a abrir todo dia. Três a cinco é o razoável.

### 4. Doc de projeto

Largura: **padrão**. Cover: opcional.

```
┌────────────────────────────────────────────┐
│  🚢  Migração para Postgres 17              │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ Status: 🟡 Em andamento             │   │ ← callout de header
│  │ Owner: @Mau · Prazo: 30/ago          │   │
│  │ Doc técnico ↗ · Canal #db-migration │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ## Contexto                                │
│  (2 parágrafos — por que estamos fazendo)  │
│                                             │
│  ## Decisões                                │
│  (lista curta, cada uma com o porquê)      │
│                                             │
│  ## Plano                                   │
│  [ database inline: tarefas, filtro deste  │
│    projeto, agrupado por fase ]             │
│                                             │
│  ## Riscos                                  │
│  ⚠️ (callout por risco relevante)          │
│                                             │
│  ▸ Histórico e notas de reunião            │ ← colapsado
└────────────────────────────────────────────┘
```

O callout de header substitui um bloco de propriedades soltas e é a diferença entre "consigo saber o estado em três segundos" e "preciso ler". Contexto e decisões vêm antes do plano porque o leitor novo precisa entender antes de acompanhar. O histórico fica colapsado porque ninguém quer ele, até querer.

### 5. Landing interna (anúncio, lançamento, onboarding)

Largura: **full width**. Cover: sim, forte.

```
┌──────────────────────────────────────────────────────────┐
│  [ COVER — banner com o nome, feito no Figma/Canva ]     │
│  🎉                                                       │
│  Novo processo de deploy                                  │
│  A partir de 1/ago, todo deploy passa pelo pipeline.     │
│                                                           │
│  [ ▸ Ler o guia completo ]  ← botão, Open page           │
│  ───────────────────────────────────────────             │
│  ## O que muda                                            │
│  ┌────────────────┐  ┌────────────────┐                 │
│  │ ❌ Antes        │  │ ✅ Agora        │  ← 2 colunas    │
│  │ (3 bullets)    │  │ (3 bullets)    │                 │
│  └────────────────┘  └────────────────┘                 │
│                                                           │
│  ## Perguntas                                             │
│  ▸ E se eu precisar de hotfix?                           │
│  ▸ Quem aprova?                                          │
│  ▸ O que acontece com o processo antigo?                 │
│                                                           │
│  ❓ Dúvidas: #deploys ou @Mau                            │
└──────────────────────────────────────────────────────────┘
```

Aqui o botão faz sentido de verdade: há uma ação principal e ela merece peso. Comparação antes/depois em duas colunas é o padrão mais eficaz para comunicar mudança de processo. FAQ em toggle porque cada pessoa tem uma dúvida diferente.

---

## Gallery view como grid visual

A gallery é a ponte entre database e design. Configurações em [Galleries](https://www.notion.com/help/galleries):

| Opção | Efeito |
|---|---|
| `Card preview: Page cover` | Usa o cover da página no card |
| `Card preview: Page content` | Mostra o primeiro bloco (se for imagem/vídeo, mostra ele) |
| `Card preview: File & media property` | Usa imagem de uma propriedade |
| `Card preview: None` | Card só de texto — vira lista de cards limpa |
| `Fit image` ligado | Imagem inteira dentro do frame, com reposicionamento |
| `Fit image` desligado | Imagem cortada preenchendo o card |
| `Card size` | Small / Medium / Large |

Três receitas:

**Moodboard puro:** `Page cover` + `Fit image` desligado + **`Name` desligado** nas propriedades. Sobram só as imagens. A própria doc do Notion sugere isso.

**Grid de navegação:** `Page cover` + `Name` ligado + uma propriedade de tag. É o padrão de "biblioteca de recursos", "catálogo de templates", "índice de projetos". Substitui com vantagem uma lista de links, porque o cover dá reconhecimento visual.

**Cards de status:** `Card preview: None` + `Card size: Small` + duas ou três propriedades. Vira um grid compacto de informação, mais legível que uma table quando cada item tem poucos campos.

A gallery é o principal motivo para se preocupar com cover das páginas *dentro* de uma database: em gallery, o cover não é decoração, é o elemento de identificação primário.

---

## Imagens, banners e separadores gráficos

**Banners horizontais** feitos fora do Notion (Figma, Canva, 1500x200 ou 1500x300) e inseridos como bloco de imagem em largura total funcionam como separadores de seção fortes em hubs e landings. Funcionam bem em quantidade pequena — um ou dois por página. Dez banners é um site do começo dos anos 2000.

**Cuidado com o dark mode**: banner com fundo branco vira um bloco luminoso na página escura. Se você vai usar banners, faça-os com fundo transparente ou com uma cor que funcione nos dois temas.

**Separadores gráficos** (linhas decorativas, ornamentos em PNG) são quase sempre pior que um `---`. Eles não escalam, não respondem ao tema, e envelhecem rápido.

**Screenshots** merecem três cuidados: recorte só o necessário (screenshot de tela inteira força o leitor a procurar), adicione caption dizendo o que olhar, e coloque em largura total se tiver detalhe fino. Screenshot pequeno dentro de coluna é ilegível e o leitor não vai clicar para ampliar.

**Imagens em coluna** precisam de atenção ao alinhamento: duas imagens de proporções diferentes lado a lado em colunas iguais parecem desalinhadas. Use imagens de mesma proporção ou aceite o desalinhamento e não tente consertar com blocos vazios.

---

## Botões e links como navegação

Três formas de navegar, com pesos diferentes:

| Elemento | Peso visual | Quando |
|---|---|---|
| `@página` inline | Mínimo | Citação no meio do texto |
| `Link to page` (bloco) | Médio | Item de índice; **cria aninhamento na sidebar** |
| Callout com links dentro | Alto | Grupo de navegação, card de hub |
| Button (`Open page or URL`) | Máximo | Uma ação principal por página |

A hierarquia importa. Uma página com cinco botões não tem ação principal. **Um botão por página**, no máximo dois, e só quando existe de fato uma ação que você quer que a pessoa tome.

Lembre que `Link to page` tem efeito colateral estrutural: a página linkada aparece aninhada na sidebar sob a página onde você inseriu o bloco. Isso é ótimo quando é intencional (montar um hub que reflete a navegação real) e péssimo quando não é (a sidebar passa a mentir sobre a organização). Se você só quer um link visual sem mexer na hierarquia, use `@página` ou um `Web bookmark`.

Detalhe de permissão de botões: quem clica precisa das permissões da ação, não quem criou. Botão que cria página numa database restrita falha silenciosamente para quem não tem acesso. Ver [Buttons](https://www.notion.com/help/buttons).

---

## Erros comuns de design, em ordem de frequência

**1. Parede de texto.** Página com 40 parágrafos, zero headings, largura padrão. Ninguém lê. É o erro mais comum e o mais fácil de consertar: adicione um heading a cada 3-5 parágrafos e a página vira legível instantaneamente. Se você não consegue nomear a seção, é porque ela não tem um assunto — e esse é um problema de escrita, não de formatação.

**2. Callout de tudo.** Cada informação num callout colorido diferente. O resultado é uma página listrada onde nada destaca. Regra: no máximo dois callouts por tela visível.

**3. Cor sem significado.** Sete cores numa página porque cada uma pareceu certa naquele momento. Se você não consegue escrever a tabela "cor → significado" do seu workspace, use uma cor.

**4. Colunas demais.** Quatro ou cinco colunas com conteúdo longo. Funciona no seu monitor, quebra no notebook e desaparece no celular. Duas colunas resolve quase tudo.

**5. Ícones inconsistentes.** Emoji aleatório em cada página, misturado com ícones de linha, misturado com uploads. A sidebar vira ruído colorido em vez de mapa. Escolha um sistema.

**6. Cover em todas as páginas.** Incluindo as operacionais que você abre vinte vezes por dia, onde ele só custa scroll. Cover é para páginas de entrada.

**7. Blocos vazios como espaçamento.** Cinco `Enter` para "dar respiro". O Notion já espaça; o que falta é heading.

**8. Full width em texto corrido.** Linhas de 200 caracteres num monitor grande. Full width é para grade, não para prosa.

**9. Toggle escondendo o essencial.** O comando de emergência dentro de um toggle fechado, invisível ao `Cmd/Ctrl + F`. Progressive disclosure é para o dispensável.

**10. Nunca testar no dark mode e no mobile.** Dois atalhos de teclado e um celular no bolso. Metade dos seus leitores está numa dessas condições, e você não faz ideia do que eles estão vendo.

**11. Small text por padrão em tudo.** Parece mais elegante nas primeiras horas e vira cansaço visual em documentos de leitura. Small text é para densidade, não para estilo.

**12. Design antes de conteúdo.** Duas horas escolhendo o emoji certo numa página cujo texto ainda não está claro. Escreva primeiro, formate depois — inclusive porque o Notion torna a formatação posterior barata de propósito.

---

## O checklist de "essa página está pronta"

Passe por essas oito perguntas antes de considerar qualquer página finalizada:

1. **Em dois segundos, dá para saber o que é essa página?** (ícone + título + primeira linha)
2. **O que salta visualmente é o que mais importa?** Se nada salta ou tudo salta, ajuste hierarquia.
3. **Tem heading a cada 3-5 parágrafos?**
4. **Cada cor usada tem significado, e o mesmo em todo o workspace?**
5. **No dark mode (`Cmd/Ctrl + Shift + L`) está legível?** Imagens, texto colado, banners.
6. **No mobile, a ordem de leitura ainda faz sentido?** As colunas empilham na ordem certa?
7. **O que está dentro de toggle é dispensável na primeira leitura?**
8. **Dá para remover alguma coisa?** Se a resposta for sim — e quase sempre é — remova.

A última pergunta é a que mais rende. Em Notion, a intervenção de design de maior retorno é quase invariavelmente a que tira alguma coisa: um callout a menos, uma cor a menos, uma coluna a menos, uma view a menos. A página que parece profissional não é a que tem mais elementos bem escolhidos — é a que tem poucos elementos e nenhum sobrando.
