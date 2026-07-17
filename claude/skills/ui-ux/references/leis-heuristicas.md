# Leis e Heurísticas de UX — Digest Acionável

Referência densa e prática para decisões de design de interface. Cada item traz
**definição curta** e **como aplicar** (concreto, em UI). Fontes ao final.

---

## Parte 1 — As 10 Heurísticas de Usabilidade de Jakob Nielsen (NN/g, 1994/2020)

Regras de bolso de alto nível (não são regras rígidas). Servem como checklist
para avaliação heurística: identificar onde o usuário provavelmente se perde,
se frustra ou se surpreende.

### 1. Visibilidade do status do sistema
**Definição:** o sistema deve sempre manter o usuário informado sobre o que está
acontecendo, com feedback apropriado em tempo razoável.
**Como aplicar:** mostre spinners/skeletons durante carregamento; barra de
progresso em uploads e checkouts; estado de "salvo/salvando"; badge de itens no
carrinho; confirmação visível após uma ação (toast). Nunca deixe a tela "morta"
após um clique — dê retorno em até ~1s.

### 2. Correspondência entre o sistema e o mundo real
**Definição:** fale a língua do usuário — palavras, frases e conceitos
familiares, não jargão interno. Siga convenções do mundo real, informação em
ordem natural e lógica.
**Como aplicar:** use "Carrinho", "Finalizar compra" em vez de nomes internos;
ícones reconhecíveis (lixeira = excluir); datas no formato local; termos do
domínio do usuário obtidos via pesquisa. Evite códigos e siglas de engenharia
na UI.

### 3. Controle e liberdade do usuário
**Definição:** usuários erram; precisam de uma "saída de emergência" claramente
marcada para desfazer a ação indesejada sem processo extenso.
**Como aplicar:** ofereça Desfazer/Refazer (undo é melhor que diálogo de
confirmação); botão Cancelar/Fechar sempre visível; "voltar" que não perde
dados de formulário; permita sair de fluxos (wizards) sem punição.

### 4. Consistência e padrões
**Definição:** o usuário não deve ter que adivinhar se palavras, situações ou
ações diferentes significam a mesma coisa. Siga convenções de plataforma e do
setor.
**Como aplicar:** consistência interna (mesmo botão primário, mesma cor de
perigo, mesma nomenclatura em todo o produto) e externa (padrões de iOS/Android/
web). Um design system com componentes reutilizáveis é a materialização desta
heurística.

### 5. Prevenção de erros
**Definição:** melhor que boas mensagens de erro é impedir que o problema
ocorra.
**Como aplicar:** desabilite o botão de envio até o form estar válido; use
constraints e bons defaults; máscaras de input (telefone, cartão); confirmação
antes de ações destrutivas; sugestões/autocomplete para evitar digitação
errada; validação inline enquanto digita.

### 6. Reconhecer em vez de memorizar
**Definição:** minimize a carga de memória tornando elementos, ações e opções
visíveis. O usuário não deve ter que lembrar informação de uma parte da
interface para outra.
**Como aplicar:** mostre opções em menus/dropdowns em vez de exigir comandos
decorados; buscas com histórico e sugestões; breadcrumbs; mantenha o contexto
visível entre etapas; rótulos que persistem (não placeholders que somem).

### 7. Flexibilidade e eficiência de uso
**Definição:** aceleradores — ocultos do novato — podem agilizar o expert,
atendendo aos dois perfis.
**Como aplicar:** atalhos de teclado; gestos; ações em massa; macros/templates;
personalização (favoritos, atalhos, dashboards configuráveis). O novato ignora;
o avançado ganha velocidade.

### 8. Estética e design minimalista
**Definição:** interfaces não devem conter informação irrelevante ou raramente
necessária. Cada unidade extra compete com as relevantes e reduz sua
visibilidade relativa.
**Como aplicar:** priorize conteúdo essencial ao objetivo principal; remova
distrações; use hierarquia visual e espaço em branco; esconda opções avançadas
em "mais opções". Menos, porém mais claro.

### 9. Ajudar a reconhecer, diagnosticar e recuperar de erros
**Definição:** mensagens de erro em linguagem simples (sem códigos), indicando
o problema com precisão e sugerindo solução construtiva.
**Como aplicar:** "O e-mail deve conter @" em vez de "erro 422"; texto de erro
próximo ao campo; cor/ícone tradicionais (vermelho, alerta); ofereça ação de
recuperação ("Reenviar", "Tentar novamente", link para o passo correto).

### 10. Ajuda e documentação
**Definição:** o ideal é o sistema dispensar explicação; ainda assim, pode ser
preciso documentar como concluir tarefas.
**Como aplicar:** ajuda contextual no momento da necessidade (tooltips, "?"
inline, empty states instrutivos); documentação pesquisável, focada na tarefa,
com passos concretos. Evite manuais longos desconectados do fluxo.

---

## Parte 2 — Laws of UX (lawsofux.com, Jon Yablonski)

Organizadas em heurísticas, princípios de Gestalt, vieses cognitivos e
princípios gerais. Cada lei: definição + implicação prática.

### Fitts's Law (Lei de Fitts)
**Definição:** o tempo para atingir um alvo é função da distância até ele e do
seu tamanho.
**Aplicar:** alvos de toque grandes (mín. ~44x44px); botões primários maiores;
aproxime ações do ponto de foco/cursor; use cantos e bordas da tela (alvos
"infinitos"); não coloque ações críticas em alvos minúsculos e distantes.

### Hick's Law (Lei de Hick)
**Definição:** o tempo de decisão cresce com o número e a complexidade das
opções.
**Aplicar:** reduza opções por tela; quebre tarefas complexas em passos
(progressive disclosure); destaque a ação recomendada; agrupe e categorize
menus. Menos escolhas = decisão mais rápida.

### Jakob's Law (Lei de Jakob)
**Definição:** os usuários passam a maior parte do tempo em *outros* sites, logo
esperam que o seu funcione como os que já conhecem.
**Aplicar:** siga convenções (logo no topo-esquerda leva à home, carrinho no
topo-direita, link sublinhado). Inove no valor, não na mecânica básica. Ao mudar
padrões, ofereça transição/coexistência.

### Miller's Law (Lei de Miller)
**Definição:** a pessoa média retém cerca de 7 (±2) itens na memória de trabalho.
**Aplicar:** use *chunking* — agrupe conteúdo (telefone/cartão em blocos); não
tome "7 itens" como limite mágico de menu, e sim como argumento para organizar e
segmentar informação em pedaços digeríveis.

### Tesler's Law (Lei da Conservação da Complexidade)
**Definição:** todo sistema tem uma quantidade de complexidade que não pode ser
eliminada, apenas movida — do usuário para o sistema/desenvolvedor, ou
vice-versa.
**Aplicar:** absorva a complexidade no produto para simplificar a vida do
usuário (ex.: preencher endereço automaticamente pelo CEP, defaults inteligentes,
detecção de bandeira do cartão). Não empurre trabalho evitável ao usuário.

### Doherty Threshold (Limiar de Doherty)
**Definição:** a produtividade dispara quando computador e usuário interagem num
ritmo (<400ms) em que nenhum espera pelo outro.
**Aplicar:** responda em menos de 400ms; use feedback otimista, skeleton
screens, pré-carregamento e animações de transição que "escondem" latência.
Percepção de velocidade importa tanto quanto velocidade real.

### Peak-End Rule (Regra do Pico e Fim)
**Definição:** as pessoas julgam uma experiência pelo seu momento mais intenso
(pico) e pelo final, não pela média.
**Aplicar:** capriche nos momentos de pico (sucesso de uma ação) e no
encerramento (tela de confirmação/agradecimento, microdelícias); cuide de picos
negativos (erros, esperas) para não dominarem a memória da experiência.

### Serial Position Effect (Efeito de Posição Serial)
**Definição:** as pessoas lembram melhor o primeiro (primazia) e o último
(recência) itens de uma lista.
**Aplicar:** coloque itens/ações mais importantes no início e no fim de menus e
navegações; o meio é a zona de menor retenção. Em navegação inferior/lateral,
ancore itens-chave nas pontas.

### Von Restorff Effect (Efeito de Isolamento)
**Definição:** quando há vários objetos similares, o que difere é o mais
lembrado.
**Aplicar:** destaque a ação principal com cor/tamanho/forma distintos; realce o
plano "recomendado" numa tabela de preços. Cuidado: não confie só na cor
(acessibilidade) e não crie destaques demais — se tudo se destaca, nada se
destaca.

### Aesthetic-Usability Effect (Efeito Estética-Usabilidade)
**Definição:** usuários percebem designs esteticamente agradáveis como mais
usáveis — e toleram melhor pequenos problemas.
**Aplicar:** invista em acabamento visual (tipografia, espaçamento, consistência)
— aumenta confiança e percepção de qualidade. Ressalva: estética pode mascarar
problemas reais em testes de usabilidade; não a use como desculpa para ignorar
falhas funcionais.

### Postel's Law (Lei de Postel / Princípio da Robustez)
**Definição:** seja liberal no que aceita, conservador no que envia.
**Aplicar:** aceite entradas em formatos variados (telefone com/sem traço,
maiúsculas/minúsculas, datas flexíveis) e normalize internamente; seja tolerante
com o usuário e rígido com a saída/validação de dados. Antecipe entradas
imperfeitas.

### Goal-Gradient Effect (Efeito Gradiente de Objetivo)
**Definição:** a motivação aumenta à medida que a pessoa se aproxima do
objetivo.
**Aplicar:** mostre progresso (barra de etapas, "faltam 2 passos"); dê a
sensação de avanço já iniciado (cartão de fidelidade que começa com carimbos);
reduza o número percebido de passos restantes para aumentar a conclusão.

### Zeigarnik Effect (Efeito Zeigarnik)
**Definição:** tarefas incompletas ou interrompidas são lembradas melhor do que
as concluídas.
**Aplicar:** indicadores de "perfil 60% completo", checklists de onboarding,
tarefas pendentes visíveis — a tensão da incompletude motiva a finalizar. Use
com parcimônia para não gerar ansiedade.

---

## Parte 3 — Princípios de Gestalt aplicados a UI

O cérebro organiza estímulos visuais em padrões e todos coerentes ("o todo é
diferente da soma das partes"). Usados para criar hierarquia e agrupamento sem
poluir a tela.

### Lei da Proximidade (Proximity)
**Definição:** elementos próximos entre si são percebidos como um grupo.
**Aplicar:** use espaçamento para agrupar (rótulo junto do seu campo; itens
relacionados de um card próximos; separe grupos com mais espaço em vez de
linhas). Espaço em branco é a ferramenta principal de agrupamento.

### Lei da Região Comum (Common Region)
**Definição:** elementos dentro de um mesmo limite/contêiner são percebidos como
grupo, mesmo que distantes.
**Aplicar:** cards, painéis, caixas com fundo ou borda para agrupar conteúdo
relacionado; um contêiner é um sinal de agrupamento mais forte que a proximidade.

### Lei da Similaridade (Similarity)
**Definição:** elementos que compartilham características visuais (cor, forma,
tamanho) são vistos como relacionados.
**Aplicar:** links todos na mesma cor; botões da mesma categoria com o mesmo
estilo; ícones consistentes. Similaridade sinaliza função equivalente; diferença
sinaliza função diferente.

### Lei de Prägnanz / Boa Forma (Simplicidade)
**Definição:** o olho interpreta imagens ambíguas/complexas da forma mais
simples possível.
**Aplicar:** prefira formas e layouts simples e limpos; reduza ruído visual;
logos e ícones minimalistas são processados mais rápido e memorizados melhor.

### Lei da Conexão Uniforme (Uniform Connectedness)
**Definição:** elementos visualmente conectados (por linha, seta ou contêiner)
são percebidos como mais relacionados do que os apenas próximos ou similares.
**Aplicar:** conecte passos de um fluxo com linhas; use divisores e conectores
para mostrar relação; agrupe toolbar de ações com um fundo comum.

### Figura-Fundo (Figure/Ground)
**Definição:** percebemos objetos como em primeiro plano (figura) ou fundo.
**Aplicar:** modais com overlay escurecido separam figura (diálogo) do fundo;
contraste e sombra elevam elementos interativos; garanta contraste suficiente
para o conteúdo "saltar" do fundo.

### Continuidade (Continuity)
**Definição:** o olho segue caminhos, linhas e curvas contínuas.
**Aplicar:** alinhe elementos numa linha/grade para guiar a leitura; carrosséis
e listas alinhadas sugerem "há mais na mesma direção"; use grids para fluxo
visual previsível.

### Fechamento (Closure)
**Definição:** a mente completa formas incompletas, percebendo o todo.
**Aplicar:** ícones e ilustrações minimalistas com formas sugeridas; loaders
circulares parciais; logos que usam espaço negativo. Menos traços, mesma
mensagem.

---

## Notas de uso prático

- **Heurísticas de Nielsen** = lente de avaliação (o que revisar num produto).
- **Laws of UX** = justificativa baseada em pesquisa para decisões de layout,
  fluxo e microinteração.
- **Gestalt** = ferramentas de organização visual (agrupar, hierarquizar, reduzir
  ruído).
- Elas se reforçam: minimalismo (Nielsen 8) + Prägnanz + Hick; consistência
  (Nielsen 4) + Jakob + Similaridade; prevenção de erro (Nielsen 5) + Postel +
  Tesler.
- Trade-offs a lembrar: Von Restorff x acessibilidade de cor; Aesthetic-Usability
  pode mascarar falhas; Zeigarnik/Goal-Gradient podem virar dark patterns se
  forçarem conclusão.

---

## Fontes

- Nielsen Norman Group — "10 Usability Heuristics for User Interface Design"
  (Jakob Nielsen, 1994; atualizado 2020): https://www.nngroup.com/articles/ten-usability-heuristics/
- NN/g — "How to Conduct a Heuristic Evaluation":
  https://www.nngroup.com/articles/how-to-conduct-a-heuristic-evaluation/
- NN/g — "10 Usability Heuristics Applied to Complex Applications":
  https://www.nngroup.com/articles/usability-heuristics-complex-applications/
- Laws of UX — Jon Yablonski (lawsofux.com), lista completa de leis e definições:
  https://lawsofux.com/
- Laws of UX (livro), Jon Yablonski, O'Reilly, 2020.
- Interaction Design Foundation — "The Laws of UX" e verbetes de Gestalt:
  https://www.interaction-design.org/literature/topics/laws-of-ux
- Interaction Design Foundation — "Gestalt Principles":
  https://www.interaction-design.org/literature/topics/gestalt-principles
- Smashing Magazine — artigos de referência sobre princípios de Gestalt e
  psicologia aplicada a UI: https://www.smashingmagazine.com/
