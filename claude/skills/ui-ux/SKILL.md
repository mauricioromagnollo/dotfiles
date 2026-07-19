---
name: ui-ux
description: Projetar, construir e revisar interfaces com foco em usabilidade, experiência e design visual — fundamentado em Norman, Krug, Gestalt, heurísticas de Nielsen, Laws of UX, acessibilidade (WCAG) e padrões modernos de UI. Use ao criar ou alterar qualquer tela, componente, formulário, fluxo, navegação, landing page ou estado de UI (loading/vazio/erro); ao escolher layout, tipografia, cor, espaçamento ou hierarquia; ao decidir copy de botão, label ou mensagem de erro; ao revisar uma interface. Dispare em pedidos como "melhore essa tela", "isso está confuso", "está feio", "a UX está ruim", "revise a usabilidade", "isso é acessível?", "qual o melhor padrão para X", "onde coloco esse botão", "faça a home", "design desse card/modal/menu" — mesmo sem citar UX, UI, usabilidade ou acessibilidade pelo nome. Dispare ao revisar UI com muitos cliques, hierarquia confusa ou contraste baixo. Também para justificar NÃO redesenhar e seguir uma convenção existente.
---

# UI/UX

Interface não é enfeite sobre a lógica. É **o modelo de como o produto funciona, materializado** — a única parte que o usuário realmente vê, e portanto a única que, para ele, existe. Cada decisão de tela ou aumenta ou diminui a distância entre a intenção da pessoa e a ação que o sistema espera dela.

O erro caro em UI raramente é "ficou feio". É **fazer o usuário pensar** onde ele não deveria: um botão que não parece clicável, um label ambíguo, um fluxo com um passo a mais, um erro que não diz o que fazer. Beleza sem clareza é decoração; clareza sem beleza ainda funciona. Quando precisar escolher, **escolha clareza** — e depois torne bonito o que já é claro.

Esta skill é conservadora por padrão. A maior parte do valor vem de **remover** — palavras, passos, opções, elementos — não de adicionar. E vem de **seguir convenções** que o usuário já aprendeu em outros produtos, não de inventar. Redesenhe quando houver evidência de fricção; até lá, o padrão consagrado vence a ideia original.

## As duas perguntas que vêm antes de qualquer decisão

Antes de desenhar ou revisar qualquer coisa, responda:

1. **Qual é a UMA tarefa desta tela?** Toda tela tem um trabalho principal. Se você não consegue nomeá-lo em uma frase, o usuário também não vai descobrir. Tudo que não serve a essa tarefa compete com ela por atenção — e atenção é o recurso mais escasso da interface.

2. **O que o usuário já sabe / espera aqui?** As pessoas passam a maior parte do tempo em *outros* produtos (Lei de Jakob). Elas trazem expectativas prontas: onde fica o logo, o que um link sublinhado faz, onde está o carrinho, o que um X no canto fecha. Atender a essa expectativa é presente grátis; contrariá-la sem motivo forte é cobrar um imposto cognitivo de cada usuário, para sempre.

Se a resposta a essas duas perguntas não estiver clara, **pergunte ou defina explicitamente antes de projetar** — não desenhe em cima de uma suposição não dita.

## A espinha dorsal: reduza os dois golfos (Norman)

Todo problema de usabilidade é uma de duas distâncias grandes demais:

- **Golfo da execução** — "como eu faço isso?". A pessoa tem uma intenção mas não sabe qual ação leva a ela. Fecha-se com **affordances e significantes** (o elemento parece o que faz), **mapeamento** (o controle corresponde espacialmente ao efeito) e **restrições** (só deixe fazer o que faz sentido).
- **Golfo da avaliação** — "deu certo?". A pessoa agiu mas não sabe o que aconteceu. Fecha-se com **feedback imediato e visível** e um **modelo conceitual** coerente (o sistema se comporta como a pessoa imagina que deveria).

Quando algo estiver confuso, diagnostique qual golfo está aberto. Isso aponta direto para a correção. Detalhe em `references/design-cognitivo.md`.

## Hierarquia de qualidade de uma interface

Mire cada elemento nesta ordem — cada nível pressupõe o anterior:

1. **Funciona e é acessível** — cumpre a tarefa, operável por teclado, contraste suficiente, alvos de toque adequados. Não negociável (`references/acessibilidade.md`).
2. **É autoevidente** — o usuário entende *sem pensar* e sem explicação. Meta padrão (Krug). Se não der, que seja no mínimo **autoexplicativo** (a explicação está ali, no momento certo).
3. **É eficiente** — o caminho mais comum é o mais curto; nada de passos, cliques ou campos supérfluos.
4. **É agradável e coerente** — hierarquia visual, ritmo, tipografia e cor reforçam a compreensão e constroem confiança (efeito estético-usabilidade).

Não pule para o nível 4 antes de garantir 1–3. Uma tela linda que esconde o botão principal falhou.

## Como trabalhar (o loop)

- **Comece pelo conteúdo e pela tarefa, não pelo layout.** O layout serve à hierarquia da informação; defina o que é mais importante primeiro, depois onde ele fica.
- **Projete os estados, não só o "tudo certo".** Toda tela que carrega ou envia dados tem no mínimo quatro estados: vazio, carregando, erro e ideal (com dados). O estado vazio e o de erro são onde a experiência mais frequentemente quebra — desenhe-os de propósito (`references/ui-moderno.md`).
- **Escreva a copy como parte do design.** Label, texto de botão, placeholder, mensagem de erro e microcopy são interface. "Salvar alterações" > "Enviar"; "E-mail ou senha incorretos" > "Erro 401". Corte toda palavra que não carrega significado (Krug).
- **Prefira revelar a esconder, mas esconda o secundário.** Divulgação progressiva: mostre o essencial, revele o avançado sob demanda — sem enterrar o que é comum.
- **Teste barato, cedo e com pouca gente.** Três usuários tentando usar o fluff pegam a maioria dos problemas graves. Não precisa de laboratório; precisa de alguém que não seja você tentando completar a tarefa (`references/processo-ux.md`).
- **Revise contra as convenções e as leis, não contra o seu gosto.** Antes de defender uma escolha, cheque as heurísticas e leis em `references/leis-heuristicas.md`.

## Quando NÃO redesenhar / NÃO adicionar

O viés desta skill é intervir de menos, não de mais:

- **Não quebre uma convenção** que funciona só para parecer original. O custo é pago por todo usuário; o benefício quase nunca compensa.
- **Não adicione uma opção, tooltip, banner ou animação** sem um trabalho claro para ela fazer. Cada adição rouba atenção do que importa e aumenta a carga cognitiva.
- **Não persiga pixel-perfection** em algo que ninguém vê ou que o usuário nunca alcança. Gaste o esforço no caminho principal.
- **Não confie no seu próprio "está óbvio".** Você conhece o sistema; o usuário não. "Óbvio para quem construiu" é a origem da maioria dos problemas de usabilidade.
- **Não use animação/movimento** sem respeitar `prefers-reduced-motion` nem cor como único portador de informação.

Quando decidir manter algo como está, diga **por quê** (qual convenção, qual evidência) — isso é uma decisão de design tão legítima quanto mudar.

## Material de referência

Carregue o arquivo relevante quando a tarefa entrar no tema. Não leia todos de uma vez — vá ao que a decisão atual exige.

| Situação | Leia |
|---|---|
| Algo está confuso, "não intuitivo", parece quebrado; affordance/feedback/modelo mental | `references/design-cognitivo.md` (Norman) |
| Usabilidade, clareza, navegação, copy, "não me faça pensar", teste barato | `references/usabilidade.md` (Krug) |
| Escolher/avaliar um padrão de UI (nav, form, tabela, modal, busca, onboarding…) | `references/padroes-interface.md` |
| Tipografia, cor (método HSB), espaçamento, grid, hierarquia visual, escalas | `references/design-visual.md` |
| Definir o processo: pesquisa, personas, jornada, wireframe, protótipo, mobile | `references/processo-ux.md` |
| Justificar/ranquear uma decisão por lei/heurística; princípios de Gestalt | `references/leis-heuristicas.md` |
| Acessibilidade, WCAG, contraste, teclado, foco, ARIA, alvo de toque | `references/acessibilidade.md` |
| Design system, tokens, estados de UI, formulários, mobile, dark mode, microinterações | `references/ui-moderno.md` |
| Ideação: destravar ou evoluir uma solução, gerar alternativas | `references/ideacao.md` |

Regra prática de roteamento: **"por que está ruim?"** → Norman/Krug/leis-heuristicas. **"como faço parecer bom?"** → design-visual/ui-moderno. **"qual componente uso?"** → padroes-interface. **"posso construir?"** → acessibilidade (sempre). **"por onde começo o projeto?"** → processo-ux.
