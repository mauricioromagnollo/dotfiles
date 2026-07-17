# Usabilidade Web/Mobile — Digest Acionável

Destilado de *Não me Faça Pensar* (Steve Krug). Cada princípio traz: **o princípio**, **por que**, **como aplicar** e **sinais de que foi violado**. No fim, um roteiro para rodar um teste de usabilidade barato.

Premissa central do livro: usabilidade é fazer com que uma pessoa de capacidade e experiência médias consiga usar a coisa para o que ela foi feita, **sem se frustrar**. Não é sobre o usuário "ideal" nem sobre o que você acha óbvio.

---

## 1. A Primeira Lei: "Não me faça pensar"

**Princípio.** Toda página, tela, botão, link e rótulo deve ser autoevidente — óbvio, autoexplicativo. O usuário deve entender o que é e como usar sem gastar nenhum esforço cognitivo. Quando algo não é autoevidente, no mínimo deve ser autoexplicativo (exige um pouquinho de raciocínio, mas trivial).

**Por que.** Cada vez que o usuário precisa parar para pensar — "Onde clico? Isso é clicável? Onde estou? Por que chamaram isso assim?" — você adiciona uma micro-carga cognitiva e consome uma parcela da paciência dele. Somadas, essas pausas fazem o site parecer difícil, e a percepção de dificuldade é o que faz as pessoas desistirem.

**Como aplicar.**
- A cada elemento, pergunte: "Uma pessoa vendo isso pela primeira vez saberia, sem pensar, o que é e o que fazer?"
- Prefira o rótulo literal e chato ("Vagas", "Preços") ao criativo ("Junte-se à Tribo").
- Elimine pontos de interrogação da cabeça do usuário: ambiguidade de nomes, links que não parecem links, instruções necessárias.
- Botões e links devem "gritar" clique-me: aparência clicável, texto que descreve o destino.

**Sinais de violação.** Você precisa explicar a interface. Usuários perguntam "e agora?". Há tooltips/legendas para compensar rótulos obscuros. Nomes "espertos" ou jargão interno. Elementos onde não dá para saber, à primeira vista, se são clicáveis.

---

## 2. Como as pessoas REALMENTE usam a web (os 3 fatos)

**Princípio.** Projete para o comportamento real, não para o idealizado. Três fatos:
1. **Não lemos páginas — examinamos (scanning).** Batemos o olho procurando palavras-chave que casem com nossa tarefa, e ignoramos o resto.
2. **Não fazemos a escolha ótima — satisfazemos (satisficing).** Clicamos na *primeira* opção razoável, não na melhor. É mais rápido, punição por erro é baixa (basta voltar) e adivinhar é mais divertido.
3. **Não descobrimos como as coisas funcionam — nos viramos (muddling through).** Usamos o que "parece funcionar", mesmo sem entender o modelo mental correto, e seguimos usando errado se der certo o suficiente.

**Por que.** Estamos com pressa, sabemos que não precisamos ler tudo para achar o que queremos, e somos bons em examinar. Consequência: o usuário quase nunca vê a página que você projetou — vê um recorte, na ordem que o olhar dele decidir.

**Como aplicar.**
- Escreva para escaneabilidade: títulos e subtítulos claros, parágrafos curtos, listas com marcadores, negrito nas palavras-chave, uma ideia por parágrafo.
- Garanta que a primeira opção "razoável" que a pessoa encontra leva a um caminho útil (não a um beco).
- Não confie que o usuário lerá instruções — desenhe para que a coisa certa aconteça mesmo sem lê-las.

**Sinais de violação.** Blocos densos de texto. Informação crítica enterrada no meio do parágrafo. Fluxo que só funciona se a pessoa ler tudo na ordem. Layout que exige leitura linear.

---

## 3. Billboard Design 101 — projete cada página como um outdoor

**Princípio.** Como o usuário examina em alta velocidade (feito quem passa de carro por um outdoor), a página precisa comunicar sua estrutura num piscar. Quatro alavancas:

**3a. Hierarquia visual clara.** A aparência da página deve refletir as relações entre as coisas: mais importante = mais destaque (tamanho, cor, contraste, posição no topo); coisas relacionadas agrupadas visualmente; coisas contidas em outras aninhadas visualmente. Uma boa hierarquia pré-processa a página para o usuário e reduz o trabalho dele.

**3b. Aproveite convenções.** Use os padrões que a web já estabeleceu (logo no topo à esquerda linkando à home; busca com caixa + botão; carrinho no canto superior direito; links sublinhados/coloridos). Convenções são amigas: quando você as segue, o usuário sabe usar sem aprender. Só quebre uma convenção se a alternativa for *claramente* melhor e autoevidente — na dúvida, não inove.

**3c. Deixe óbvio o que é clicável.** Diferencie visualmente o clicável do não-clicável de forma consistente. O usuário não deveria ter que passar o mouse para descobrir.

**3d. Minimize o ruído.** Reduza o "barulho visual" (excesso de elementos brigando por atenção, tudo em destaque, complexidade). Ruído esconde o que importa.

**Por que.** Se cada página exige decodificação, você viola a Primeira Lei em escala. Hierarquia, convenção e clareza são atalhos gratuitos que transferem trabalho do usuário para o projeto.

**Como aplicar.**
- Faça o teste do olhar de 5 segundos: o que salta primeiro? É o mais importante?
- Estabeleça e siga um sistema visual consistente (o que é título, link, botão, seção).
- Antes de inventar um padrão novo, procure a convenção existente e use-a.
- Se tudo está em destaque, nada está: recue o secundário.

**Sinais de violação.** Página onde tudo tem o mesmo peso. Elementos importantes visualmente iguais aos decorativos. Padrões reinventados sem ganho. Usuário "caça" o botão principal.

---

## 4. Omita palavras desnecessárias

**Princípio.** "Livre-se de metade das palavras de cada página. Depois livre-se de metade do que sobrou." Corte impiedosamente.

**Por que.** Menos texto = menos ruído, páginas mais escaneáveis, conteúdo útil mais visível, menos rolagem. Texto que ninguém lê só atrapalha quem examina.

**Como aplicar.**
- Elimine "texto de boas-vindas feliz" (prosa promocional que ninguém lê) e instruções óbvias.
- Corte o "happy talk" e o jargão corporativo. Vá direto ao ponto.
- Em instruções que restam: reduza ao mínimo absoluto; melhor ainda, redesenhe para não precisar delas.

**Sinais de violação.** Parágrafo de abertura genérico ("Bem-vindo ao nosso site, onde nos dedicamos a..."). Instruções longas antes de um formulário. Descrições redundantes.

---

## 5. Navegação: onde estou, o que tem aqui, como saio

**Princípio.** A web não tem senso de lugar (não há "peso" nas mãos como num livro). A navegação persistente é o que combate o "perdido no espaço". Ela precisa, em toda página, responder: **Que site é este?** (ID/logo), **Em que página estou?**, **Quais as seções principais?**, **Onde estou na hierarquia?**, **Como busco?**.

**Componentes acionáveis:**

**5a. Navegação persistente.** Um conjunto consistente de elementos em todas as páginas (menos, opcionalmente, no checkout): ID do site, seções principais, busca, utilidades. Consistência reduz o pensar.

**5b. Nome da página proeminente.** Toda página tem um nome, no lugar certo, em destaque, e ele **casa** com o link/palavra que a pessoa clicou para chegar ali. Se cliquei em "Vagas" e caio numa página "Trabalhe Conosco", eu paro para pensar.

**5c. "Você está aqui" (marcar a seção atual).** Destaque a seção/subseção corrente na navegação. Falha comum: o indicador é sutil demais. Use *mais de uma* distinção visual (cor + negrito, p.ex.). Regra prática: se você acha que o destaque está chamando atenção demais, provavelmente ele deveria ser o dobro mais proeminente.

**5d. Migalhas de pão (breadcrumbs).** Mostram o caminho da home até a página atual. Boas práticas: no topo; separador ">" entre níveis; fonte pequena (é acessório); incluir as palavras "Você está aqui"; **último item = nome da página atual, em negrito**. Não substituem a navegação principal.

**5e. Abas (tabs).** Quando bem-feitas, são autoevidentes, difíceis de errar e sugerem fisicamente "estou nesta seção". Exigem: cor/contraste que faça a aba ativa vir "à frente"; a aba ativa conectada ao conteúdo.

**Por que.** Navegação clara é metade da usabilidade de qualquer site com mais de um punhado de páginas — é como a pessoa forma o modelo mental do site e recupera o controle.

**Como aplicar.** Faça o **teste do porta-malas** (ver abaixo): pegue qualquer página do site fora de contexto e veja se responde às perguntas básicas.

**Sinais de violação.** Você chega numa página e não sabe onde está no site. O nome da página some ou não bate com o link clicado. O "você está aqui" é invisível. Migalhas quebradas ou ausentes em hierarquias profundas.

---

## 6. O Teste do Porta-Malas (auditoria rápida de navegação)

**Princípio.** Uma página bem navegável se sustenta sozinha, fora de contexto — como saber onde você está sendo jogado no porta-malas de um carro e aberto num lugar aleatório.

**Como aplicar (3 passos).**
1. Escolha uma página *qualquer* do site, aleatória, e imprima (ou olhe isolada).
2. Segure a um braço de distância / desfoque, para não conseguir estudá-la de perto.
3. O mais rápido possível, tente identificar e circular: **(1) ID do site, (2) nome da página, (3) seções e subseções, (4) navegação local, (5) indicador "Você está aqui", (6) busca.**

Repita numa dúzia de páginas de sites diferentes para calibrar o senso do que funciona.

**Sinais de violação.** Você não consegue circular um ou mais desses itens rapidamente em uma página tirada ao acaso.

---

## 7. Página inicial e tagline

**Princípio.** A home tem o trabalho mais difícil: em segundos, uma pessoa que chega precisa entender **o que é isto, o que dá para fazer aqui, e por que isso é bom** (melhor que as alternativas), além de saber onde começar. Ela precisa: mostrar o que procuro *e* o que eu nem sabia que queria; mostrar por onde começar; estabelecer credibilidade.

**A tagline (slogan do site).** Uma frase curta, logo junto ao logo/ID, que caracteriza o site inteiro. Atributos de uma boa tagline:
- **Clara e informativa** (diz o que o site faz), não vaga.
- **Grande apenas o suficiente**: ~6 a 8 palavras. Longa o bastante para um pensamento completo, curta o bastante para assimilar de relance.
- Comunica **diferenciação e um benefício claro** — por que este e não outro.
- Pode ser espirituosa, mas só se a inteligência *reforçar* o benefício, nunca se obscurecê-lo.
- **Não confunda tagline com declaração de missão.** Missão ("oferecemos soluções globais de blá-blá") ninguém lê. Não use missão como texto de boas-vindas.

**Por que.** A home é a única página que quase todo visitante vê e frequentemente a única chance de causar boa impressão. Todo mundo (até o CEO) tem opinião sobre ela e quer um pedaço dela — resista à tentação de promover *tudo*; use só o suficiente (no máximo ~4 destaques).

**Como aplicar.**
- Deixe óbvios os pontos de entrada: faça a busca *parecer* busca e a lista de seções *parecer* lista de seções, com rótulos claros ("Pesquisar", "Comece aqui").
- Não gaste mais espaço do que o necessário para passar a ideia.
- **Teste a home com gente de fora**: você não pode confiar no próprio julgamento sobre se ela cumpre a "questão-chave", porque quem é de dentro nunca percebe o que está faltando.

**Sinais de violação.** Visitante novo não sabe dizer o que o site faz nem por onde começar. Home entulhada de promoções gritando "clique aqui". Intro em Flash / carrossel que atrasa o acesso. Declaração de missão no lugar de tagline.

---

## 8. Reservatório de Boa Vontade (goodwill)

**Princípio.** Cada usuário chega ao seu site com uma reserva de boa vontade. Cada atrito, erro ou desrespeito **drena** a reserva; cada facilidade e cortesia a **reabastece**. Se esvazia, a pessoa vai embora — ou fica com imagem pior da sua organização.

**Propriedades da reserva.**
- **Idiossincrática**: cada pessoa começa com mais ou menos (não conte com reserva alta).
- **Situacional**: pressa ou má experiência anterior já reduzem a reserva na chegada.
- **Reabastecível**: mesmo depois de erros, dá para recuperar fazendo coisas que mostrem que você cuida dos interesses da pessoa.
- **Um único erro pode zerá-la**: p.ex. abrir um formulário enorme logo de cara.

**Coisas que DRENAM a boa vontade (não faça):**
- Esconder informação que eu quero (telefone de suporte, frete, preços).
- Me punir por não formatar dados do seu jeito (hífens no telefone, espaços no cartão) — aceite os formatos.
- Pedir dados que você não precisa de verdade.
- Me enganar / falsa sinceridade ("sua ligação é importante").
- Firulas: intro longa, páginas de marketing difíceis de atravessar.
- Aparência amadora (piegas, desorganizada) — corrói confiança.

**Coisas que REABASTECEM (faça):**
- Saber o que a maioria quer fazer e deixar isso óbvio e fácil.
- Dizer o que eu quero saber — seja direto sobre custos, prazos, taxas, interrupções.
- Poupar etapas sempre que possível (ex.: link de rastreio no e-mail de confirmação).
- Esforçar-se: dar informação precisa, útil, clara e bem organizada (ex.: bom suporte técnico que resolve sozinho).
- Antecipar dúvidas e respondê-las.
- Fazer o site parecer cuidado e profissional.

**Sinais de violação.** Taxas que aparecem só no fim. Formulário que rejeita "(11) 99999-9999". Pop-ups não convidados. Suporte escondido. Usuário abandona no meio do funil frustrado.

---

## 9. Acessibilidade (e por que ela ajuda todo mundo)

**Princípio.** Tornar o site acessível não é caridade nem só conformidade legal — o que é mais usável para "o resto de nós" costuma ser o que mais ajuda quem tem deficiência, e vice-versa. Comece pelo que tem maior impacto.

**Insight-chave — usuários de leitor de tela "examinam com os ouvidos".** Assim como quem enxerga não lê tudo, quem usa leitor de tela ouve só o começo de um link/linha/parágrafo e, se não parecer relevante, pula para o próximo — em velocidade altíssima. Por isso: coloque a palavra-chave *no início* de links e rótulos; links devem fazer sentido fora de contexto (evite "clique aqui").

**As coisas mais valiosas para fazer agora:**
1. **Conserte os problemas que confundem todo mundo.** Se algo confunde a maioria, confunde ainda mais quem tem deficiência e é mais difícil de se recuperar. Testar e corrigir clareza geral é o primeiro passo de acessibilidade.
2. **Aprenda o básico** (leia um bom artigo/livro sobre acessibilidade web e sobre leitores de tela).
3. **Use CSS de verdade** para separar estrutura de apresentação — ajuda leitores de tela e o controle de layout.
4. **Adote os fundamentos**: texto alternativo em imagens; formulários com labels associados; ordem de leitura lógica; navegação por teclado; contraste suficiente; títulos/headings estruturados.

**Por que.** Deficiência é um mercado grande, adaptações beneficiam todos, e muitas vezes é lei (ex.: Seção 508 / no Brasil, LBI e eMAG). Além disso, os mesmos ajustes ajudam mobile e situações de uso ruins (sol, pressa, conexão fraca).

**Sinais de violação.** Imagens sem alt. Links "clique aqui" / "saiba mais" repetidos. Formulário sem labels. Só dá para operar com mouse. Contraste baixo. Estrutura só visual, sem headings.

---

## 10. Formulários (aplicação direta dos princípios acima)

**Princípio.** Formulário é onde o usuário mais "pensa" e onde a reserva de boa vontade mais vaza. Reduza campos, dúvidas e punições.

**Como aplicar.**
- Peça só o essencial; cada campo extra custa boa vontade e conversão.
- Labels claros e sempre visíveis; não confie só em placeholder.
- Aceite variações de formato (telefone, cartão, CEP) em vez de exigir o "jeito do banco de dados".
- Deixe óbvio o que é obrigatório e o formato esperado *antes* do erro.
- Mensagens de erro específicas, próximas ao campo, dizendo *como* corrigir.
- Um caminho óbvio de ação principal (um botão primário claro).

**Sinais de violação.** Muitos campos. Erros genéricos ("dados inválidos"). Rejeição de formatos válidos. Reset acidental. Placeholder como único rótulo.

---

## 11. Mobile (estender "não me faça pensar" para tela pequena)

**Princípio.** Todos os princípios valem, ainda mais forte: menos espaço, mais pressa, mais interrupção, dedo em vez de mouse. A tolerância ao atrito é menor.

**Como aplicar.**
- Priorize implacavelmente: a tarefa principal precisa estar visível sem rolar/caçar. Corte ainda mais palavras.
- Alvos de toque grandes (mínimo ~44px) e bem espaçados; não há hover.
- Convenções mobile são convenções (menu, tab bar inferior, gestos padrão) — siga-as; não esconda funções essenciais atrás de gestos "espertos" não descobríveis.
- Deixe óbvio o que é tocável; feedback imediato ao toque.
- Não sacrifique clareza por "chrome" bonito; o conteúdo é a interface.
- Formulários mobile: teclado certo por campo, autofill, menos digitação.

**Sinais de violação.** Botões pequenos/colados. Função crítica só via gesto escondido. Texto minúsculo. Rolagem horizontal. Depender de hover. Ação principal abaixo da dobra.

---

## COMO RODAR UM TESTE DE USABILIDADE BARATO (o método do livro)

A técnica mais valiosa do livro. **"Testar um usuário é 100% melhor que testar nenhum."** E testar cedo (enquanto dá para mudar) vale mais que um teste sofisticado tarde demais. Não precisa de laboratório, especialista, verba nem grande público.

### Princípios do teste barato
- **3 usuários por rodada** (no máximo 4), não 8+. Os 3 primeiros acham quase todos os problemas grandes. É melhor fazer **mais rodadas** com poucos usuários do que uma rodada grande — porque você conserta entre as rodadas e a próxima trinca acha problemas novos.
- **Recrute livremente, "classifique numa curva".** Não importa muito *quem* você testa — basta gente que use a web o suficiente. Não perca tempo caçando o público-alvo perfeito. Os problemas sérios costumam atrapalhar quase qualquer pessoa.
- **Uma manhã por mês.** O ritmo ideal: uma manhã, 3–4 usuários, decidir o que consertar durante o almoço. Sem relatório de 20 páginas, sem reunião interminável.
- **Faça você mesmo.** Você mesmo pode facilitar. Rode antes um teste em sites parecidos (concorrentes) para criar "casca" e praticar sem pressão.
- **O objetivo não é provar/reprovar nem estatística** — é *informar seu julgamento*. Você observa, aprende, decide.

### Montagem mínima
- Uma sala/escritório com duas cadeiras, um computador com internet, e um lugar sem interrupção.
- Opcional: câmera + cabo/tela numa sala vizinha para a equipe observar (ou compartilhamento de tela). Grave a tela + voz (com permissão) para mostrar a quem não assistiu.
- Convide a equipe/gestão a assistir ao vivo — ver um usuário real travando convence mais que qualquer relatório.

### Roteiro da sessão (~1h por pessoa, ou menos)
1. **Introdução (deixe a pessoa à vontade).** Deixe claro: "estamos testando o *site*, não *você*; você não pode errar aqui; seja honesto, você não vai magoar ninguém; pense em voz alta enquanto usa." Peça permissão para gravar; explique NDA se houver (curto, em linguagem simples).
2. **Reações à página inicial.** Antes de qualquer tarefa: "olhe esta página e me diga o que acha que é, o que te chama atenção, e onde você clicaria primeiro. Não clique ainda — só pense em voz alta."
3. **Tarefas-chave.** Peça tarefas realistas ("encontre um livro que você queira comprar"), não instruções passo a passo. Também vale um **teste de compreensão** (a pessoa entende o propósito e a proposta de valor do site?).
4. **Facilitação neutra.** Peça sempre "pense em voz alta". Não ajude, não guie, não responda perguntas na hora ("o que você faria se eu não estivesse aqui?"). Fique quieto e observe onde a pessoa hesita, se confunde, escolhe o link errado.
5. **Debrief.** Ao final, aí sim responda dúvidas que ficaram.

### Depois: decidir o que consertar
- Junte a equipe logo após (no almoço) e alinhem os **problemas mais sérios**. Não gere "relatório barulhento".
- **Pegue a fruta mais baixa:** priorize (a) "tapas na testa" — problemas cuja causa e solução ficaram óbvias para todos que assistiram, dinheiro no chão, conserte já; e (b) "acertos baratos" — mudanças de baixo esforço e alto impacto visível.
- **Resista ao impulso de *adicionar* coisas.** Quando o usuário não acha algo, a reação instintiva é adicionar explicação/instrução — normalmente a solução certa é *remover* o que está obscurecendo, não empilhar mais.
- **Cuidado com pedidos de "novo recurso".** "Seria bom se fizesse X" costuma significar "gosto do que já existe" — investigue antes de construir.
- **Não jogue o bebê fora com a água do banho.** Ao mexer para consertar um problema, pense no que mais será afetado; conserte *sem* quebrar o que já funciona. Mudanças pequenas podem ter efeitos amplos.

### As 5 desculpas para não testar (e a resposta)
- "Não temos tempo" → testes pequenos economizam tempo (menos briga, menos retrabalho no fim).
- "Não temos dinheiro" → uma rodada custa quase nada; esqueça os laboratórios caros.
- "Não temos especialistas" → nunca vi um teste, mesmo mal conduzido, que não revelasse coisa útil.
- "Não temos laboratório" → só precisa de uma sala, um computador e duas cadeiras.
- "Não saberíamos interpretar" → os problemas sérios são óbvios demais para quem assistiu.

---

### Frase-síntese
Reduza o esforço de pensar em cada tela (clareza + convenção + hierarquia), escreva para quem examina e "satisfaz", cuide do reservatório de boa vontade, e **teste cedo, barato e com frequência** — três usuários e uma manhã por mês já mudam o jogo.
