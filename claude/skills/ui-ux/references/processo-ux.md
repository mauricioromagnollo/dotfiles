# Processo de UX aplicado — digest acionável

Baseado em "UX e Usabilidade aplicados em Mobile e Web" (Caelum, curso WD-41). Foco no PROCESSO (o que fazer, em que ordem) e nas especificidades de mobile. As técnicas aparecem no livro em formato "gamestorming" (dinâmicas de time com tempo definido, post-its e votação com bolinhas), o que as torna diretamente executáveis.

---

## 0. Mapa mental do processo (visão macro)

O livro organiza a experiência em 5 planos (Jesse James Garret, *Elements of UX*), do **abstrato** ao **concreto** — cada decisão de um plano superior depende do inferior:

1. **Estratégia** — por que estamos fazendo isto? (objetivos do negócio × necessidades do usuário)
2. **Escopo** — o que faremos? (requisitos funcionais + requisitos de conteúdo)
3. **Estrutura** — como as funcionalidades/dados se encaixam? (design de interação + arquitetura de informação)
4. **Esqueleto** — como apresentar os elementos na tela? (design de interface, navegação, informação)
5. **Superfície** — o look and feel final (design visual)

Fluxo prático de trabalho que emerge do livro (ordem recomendada):

**Descoberta → Pesquisa → Personas → Modelagem de requisitos → Design (rabisco→wireframe→protótipo) → Avaliação (heurísticas + teste de usabilidade) → iterar.**

Princípios-chave da ISO 9241-210 que regem tudo:
- Projeto baseado em entendimento explícito de usuários, tarefas e ambientes.
- Usuários envolvidos em todo o projeto.
- Projeto conduzido e refinado por avaliações centradas no usuário.
- **O processo é iterativo.**
- Aborda toda a experiência do usuário.
- Equipe multidisciplinar.

---

## 1. Pesquisa (fase de descoberta)

Investigar, por várias fontes, o potencial do produto, seus usuários e ambientes. Métodos podem ser quantitativos/qualitativos e **exploratórios** (início do projeto, entender necessidades) ou **avaliativos** (analisar qualidade de algo já existente).

### Onde buscar informação (entrevistar)
- **Stakeholders** (executivos, negócio, marketing, devs) → visão preliminar do produto, orçamento/cronograma, limitações técnicas, objetivos do negócio, percepção sobre os usuários.
- **SMEs** (especialistas de domínio) → úteis em domínios complexos.
- **Clientes** (nem sempre = usuário) → objetivos de compra, frustrações com soluções atuais, processo de decisão.
- **Usuários** → problemas/frustrações atuais, contexto real de atividades, tarefas atuais, objetivos e motivações.

### Métodos por propósito (tabela do livro)
- **Demográfico** ("quem são?"): questionários, análise de registros, banco de dados.
- **Comportamental** ("como fazem?"): pesquisa de campo, entrevistas contextuais, card sorting, etnografia → alimenta estratégia, features, design de interação, arquitetura de informação.
- **Motivacional** ("por que fazem?"): pesquisa de campo, entrevistas contextuais, questionários → estratégia, estruturação da experiência, marca.
- **Avaliativo** ("como funciona pra eles?"): teste de usabilidade, feedback, teste A/B → design de interação, fluxo, layout, nomenclaturas.

### Checklist — Entrevista
- [ ] Ter **empatia** (colocar-se no lugar do outro), não simpatia (projetar a própria experiência). Verificar constantemente se entendeu, pedindo feedback.
- [ ] Construir **rapport** (laço, sentir que você o entende).
- [ ] Roteiro baseado em objetivos definidos pelo time.
- [ ] Explicar o projeto no início; agradecer no fim.
- [ ] Dinâmica sugerida: entrevista curta (~2 min) com objetivo claro; destilar depois.

### Card Sorting (arquitetura de informação / navegação)
Resolve problemas de organização e navegação; valida como o conteúdo deve ser agrupado.
- **Aberto**: participante cria e nomeia os grupos.
- **Fechado**: categorias pré-definidas, participante encaixa os cartões.
- Passos: (1) decidir o que aprender → (2) escolher método → (3) escolher conteúdo → (4) convidar participantes → (5) rodar e registrar → (6) analisar → (7) aplicar no projeto.
- Ajuda o time a chegar a consenso sobre a organização da informação.

### Checklist — Recrutamento
- [ ] Definir o **perfil de usuário** desejado com clareza (mesmo terceirizando).
- [ ] Manter lista de interessados (questionário no site, mídias sociais, eventos).
- [ ] Criar questionário de **screening** (telefone, e-mail ou online) para filtrar.
- [ ] Convidar **muito mais** candidatos que o alvo (alta taxa de não comparecimento).
- [ ] Incentivar participação (ajuda de custo, brindes, descontos, ambiente agradável).

### Destilar a pesquisa
Dados crus são inúteis se não estruturados. Agrupar em blocos que tenham ligação e deem significado (planilhas, tabelas, post-its em quadro).

Ferramentas de analytics citadas: Crazy Egg, Google Analytics, Kiss Metrics, Hotjar.

---

## 2. Personas (consolidar a pesquisa em pessoas)

Modelos descritivos de usuários baseados em dados de pesquisa: como se comportam, o que pensam, desejam e **por quê**. Mantêm o usuário em mente e criam linguagem comum no time. Ajudam o processo **inteiro** (não uma fase específica). **Não** representam: média estatística, pessoas reais, segmentos de mercado, nem job descriptions.

- **Regra de ouro do número**: mínimo 2, máximo 11 personas.
- **Proto-persona**: variante barata baseada em hipótese/conhecimento do time (não validada) — bom para introduzir cultura de DCU. "Melhor uma proto-persona na mão que duas voando." Layout comum em 4 quadrantes: identidade/personalidade, comportamentos, dados demográficos, necessidades e objetivos.
- **Persona simples (cartão)**: "[Nome] é um ___ (quem) que precisa ___ (o quê) e quer que a experiência seja ___ (como) porque valoriza ___ (por quê)".

### Os 7 passos para criar personas (Alan Cooper, *About Face 3*)
1. Identificar variáveis **comportamentais** e demográficas (atividades, atitudes, aptidões, motivações, habilidades). ~20–30 variáveis.
2. **Mapear** entrevistados nas variáveis (posição relativa importa mais que absoluta; use quadro-branco).
3. Identificar **padrões** de comportamento (agrupamentos que aparecem juntos em 6–8 variáveis); cuidado com falsos padrões.
4. Listar **características e objetivos** relevantes. Objetivos são o foco — eles guiam o design. Tipos (Norman/Cooper):
   - **Objetivos de experiência** (visceral): como quer se sentir ("sentir-me inteligente"). ~0–1 por persona.
   - **Objetivos finais** (comportamental): o que quer realizar ("terminar até 17h"). 3–5 por persona — os mais úteis para o design.
   - **Objetivos de vida** (reflexivo): motivação profunda ("me aposentar aos 45"). ~0–1.
5. Checar o conjunto para **eliminar redundâncias** (personas devem diferir em ≥1 comportamento).
6. Desenvolver a **narrativa** (agrupar itens → parágrafos → adicionar personalidade e citações; 1–2 detalhes pessoais só). Evitar caricaturas.
7. Determinar **tipos**: primária (precisa ser atendida de todo jeito; se feliz, as outras não ficam tristes), secundária, suplementar, negativa, served persona. Identifique a primária por eliminação: "se eu desenhar pra esta persona, as outras ficam insatisfeitas?"

### Mapa de empatia (6 quadrantes) — alternativa rápida ao perfil do usuário
Penso · Escuto · Vejo · Falo e faço · Dores · Necessidades. Escolher nome e idade para dar credibilidade.

---

## 3. Modelando e identificando requisitos

Depois da pesquisa, o designer produz modelos para visualizar/analisar o aprendido. Documentar só o necessário ("o bom senso deve prevalecer").

- **Modelo mental**: como a pessoa imagina que algo funciona (nem sempre o mecanismo real). Muda lentamente, reaproveitável entre projetos; validado pelas personas. Ex.: o "carrinho de compras" evoca um container físico → a interface deve permitir colocar/tirar itens.
- **Cenários**: narrativas que descrevem interações previsíveis do usuário com o sistema — "protótipos construídos de palavras". Comece pelo **cenário de primeira utilização**. Tipos: cenário de contexto (alto nível, "mágico") → cenário de caminho-chave (com vocabulário de design). Demarcam a entrada no plano de escopo (extraem requisitos).
- **Análise de tarefas**: lista as tarefas que o design terá que suportar, categorizadas por importância (primária/secundária/terciária/dispensável).
- **Fluxo de tarefas**: diagrama de como o usuário completa cada tarefa do começo ao fim. Sugere a ordem das telas e as conexões lógicas que virarão wireframes. É o início da concretização dos requisitos.
- **Sintetizar requisitos**: separar **ações (verbos)** e **objetos (substantivos)** dos cenários/fluxos → viram **dados** (o que o usuário precisa ver) e **funcionalidades** (operações/controles). Organizar em tabela por tipo (dados, funcionalidades, contexto).
- **User Stories**: pedido de valor com 3 informações — por que é importante, que tipo de usuário se beneficia, o que o software faz. Escrever de forma fluente e do ponto de vista de quem realmente se beneficia.

### Equilíbrio cliente × usuário — UX Canvas
Ferramenta visual (inspirada no Business Model Canvas) para alinhar visões. Blocos: Cliente / Objetivos do cliente / Requerimentos | Artefato-Ideia | Usuário / Objetivos do usuário / Cenários de uso e pontos de contato | Recursos — tudo em volta do coração: **Proposta de Experiência** (qual experiência o artefato deve proporcionar).

### Features e priorização
Feature = descrição de uma interação/ação com o sistema; **toda feature deve atender um objetivo** ligado a uma persona. Priorizar por 4 valores:
- **Valor pro usuário** (entrar no modelo mental — pequeno/médio/grande)
- **Valor pro negócio** (resultado financeiro pro cliente)
- **Esforço técnico** (levantado com o time técnico)
- **MVP** = mínimo de features que agrega valor a usuário e negócio e pode ir a produção.

Dinâmica de priorização: matriz proto-personas (eixo Y) × objetivos (eixo X), postar features com post-its, votar valor com bolinhas e cruzar com esforço.

---

## 4. Dos requisitos ao design (esqueleto)

Processo **incremental**, refinado a cada iteração. Analogia da casa: primeiro os cômodos e a disposição, não as dimensões exatas.

### Estrutura geral
- Definir estrutura de navegação e interações macro.
- Considerar: forma (tela alta-resolução? celular? quiosque?), padrão postural (transitório × soberano), método de entrada (teclado, mouse, voz, **toque na tela**).
- Identificar as **visões** (estados principais da tela). Para cada visão: "fase de retângulos" — dividir em áreas retangulares (painéis, barras, menus), nomear e mapear como uma área influencia as outras.
- Começar em papel/guardanapo/quadro-branco; migrar para ferramenta quando algo estiver fechado.

### Escada de fidelidade (o coração do "fazer design")
1. **Rabiscoframe** (rascunho à mão) — informal, rápido.
2. **8 Steps / Crazy Eights** (Google, Design Sprint) — folha dividida em 8 partes = 8 telas; foca em **ideias, não em detalhes/arte**; resolve uma história por vez mostrando o fluxo de navegação. Time acorda cores (ex.: preta=desenho, azul=mouse, verde=touch, vermelha=teclado). Gerar muitas ideias rápido.
3. **Wireframe** — visão detalhada de uma parte do produto: todos os componentes de uma tela e como se encaixam. Esboça forma, conteúdo, funcionalidades e navegação. Conteúdo pode ser placeholder ("X") ou real. Tudo que não for óbvio precisa de **anotação**. Serve como comunicação com clientes/devs/designer visual. Ferramentas: Axure, Just in Mind, OmniGraffle, Balsamiq, iRise, Gliffy, SmartDraw.
4. **Protótipo** — modelo manipulável (não sistema completo). Usado para **exploração** (descobrir o que falta) e **validação** (testar interações-chave antes de construir; evita decisões por opinião). Quanto antes, menor o custo de corrigir o rumo.

### Fidelidade do protótipo é multidimensional
Dimensões: **visual**, **funcional** e **conteúdo**. Combinações: BFV, BFF, AFV, AFF.
- **Alta Fidelidade Visual (AFV)**: quando testar se o visual não prejudica a usabilidade, ou quando usuários/clientes ficam confusos com wireframes crus.
- **Alta Fidelidade Funcional (AFF)**: quando precisa saber se interações-chave funcionam / produto complexo com muitas interações.
- **Conteúdo** ruim gera resultado ruim → sempre usar conteúdo **plausível**.
- Ferramentas: papel&caneta → wireframe → HTML/CSS/JS. Não se limitar a uma só; começar barato e subir fidelidade conforme o design amadurece.

---

## 5. Padrões e princípios de design de interação

### As 10 heurísticas de Nielsen (checklist de avaliação)
1. Visibilidade do estado do sistema
2. Correspondência entre o sistema e o mundo real
3. Liberdade e controle do usuário
4. Consistência e padrões
5. Prevenção de erros (design defensivo)
6. Reconhecimento em vez de memorização
7. Flexibilidade e eficiência de uso
8. Estética e design minimalista
9. Ajudar a reconhecer, diagnosticar e recuperar-se de erros
10. Ajuda e documentação

Dinâmica: metade do time vira "consultores de usabilidade", percorre outra interface com as 10 heurísticas e marca problemas (post-it de uma cor) e soluções (post-it de outra cor).

---

## 6. Especificidades de MOBILE (capítulo dedicado)

Pensar mobile **não é diferencial, é o essencial** — e desde o início do planejamento. ~60% dos usuários abandonam uma página com experiência mobile ruim.

### Lei de Fitts (tamanho e distância dos alvos)
Tempo para atingir um alvo depende da distância e da **área de superfície** do alvo. No mobile, "corpo" = **dedo/polegar**.
- **Touch targets grandes**: alvos maiores = mais fáceis de acertar.
- **Área clicável ampliada**: em checkbox, a área clicável deve incluir o **texto ao lado**, não só o quadradinho.
- Considerar **orientação** (retrato × paisagem) e com qual mão o usuário interage. Pesquisa citada: ~50% usam uma mão, ~15% as duas — mas confirme com testes no seu projeto.

### Lei de Hick (número de opções)
O tempo para decidir aumenta com o número de opções. **Menos escolhas = experiência mais agradável.** Eliminar opções desnecessárias; valorizar simplicidade (ex.: reduzir tipos de investimento numa tela de "6 opções" para "2").

### Thumb Zones (Steven Hoober, *Designing Mobile Interfaces*)
Área confortável para toque com **uma mão só** (polegar). ~49% interagem com uma mão. Mapa de conforto muda com o **tamanho da tela** (verde=confortável, amarelo=+/-, vermelho=desconfortável) — telas maiores (iPhone 6/6 Plus) empurram o topo para a zona vermelha.
- Colocar **call to action e navegação principal na parte inferior** da tela.
- Ex. reais: Material Design (Google) coloca CTA embaixo; Alura coloca o burger icon no canto **inferior direito** — descobriram por pesquisa que usuários usam mais a mão esquerda (thumb zone espelhado).
- Apple justificou telas menores pela thumb zone; solução do "descer a interface" (reachability) com dois toques no home.

### Checklist mobile
- [ ] Mobile-first desde o planejamento (não deixar para o fim do prazo).
- [ ] Touch targets grandes; área de clique incluindo rótulos.
- [ ] CTA e ações principais na thumb zone (parte inferior).
- [ ] Reduzir número de opções por tela (Hick).
- [ ] Testar orientação e mão predominante com usuários reais do projeto.
- [ ] Tipografia legível: escolher família adequada ao contexto; atenção a serifa × sem serifa (má escolha torna o conteúdo ilegível).

### Microinterações (Dan Saffer) — enriquecer sem criar nova funcionalidade
Pequenas tarefas do cotidiano (aumentar volume, abrir torneira) transpostas para o produto (adicionar ao carrinho, navegar carrossel). Melhoram a experiência apoiando 2 heurísticas de Nielsen: dar **feedback** e ser **próximo do mundo real**. Fluxo de 4 partes:
1. **Trigger** — o que inicia (mouseover, click, toque na tela).
2. **Rules** — o que acontece (regras, muitas vezes invisíveis).
3. **Feedback** — o que é apresentado ao usuário quando aciona a regra (inclui som de erro; ex. Duolingo mostra a palavra errada ao "Verificar").
4. **Loops & Modes** — de quanto em quanto tempo/repetição; modos diferentes da mesma microinteração afetados por interação do usuário.

---

## 7. Design visual (superfície)

- **Princípio C.R.A.P.**: Contraste, Repetição, Alinhamento, Proximidade.
- Cores comunicam identidade de marca, criam contraste/uniformidade e servem de dica de função/importância. Percepção de cor é **individual e cultural** (branco = pureza no Ocidente, morte no Oriente).
- **Teoria das cores** (círculo cromático): combinações harmônicas são um conjunto **finito** — complementares, análogas, triádicas, meio-complementares, retângulo, quadrado.
- Escolher cor-base por **psicologia das cores** (azul=inovação/tecnologia, laranja=juventude, roxo=criatividade) ou identidade de marca. Ferramenta: **Adobe Color** (color.adobe.com).
- Eliminar do layout qualquer informação irrelevante para o público.
- **Especificação**: nível depende da proximidade com o time de dev e cultura da empresa. Protótipo AFF já serve como especificação de fluxo; anotações no próprio wireframe; planilha para mensagens (erro/alerta/info/ajuda). Nada substitui o designer sentado perto do dev (papel de QA).

---

## 8. Avaliação / métricas de UX — Teste de usabilidade

Técnica de **caixa-preta**: observar usuários reais usando o produto (mesmo incompleto; protótipos servem) para descobrir problemas e pontos de melhoria.

### O que é medido (4 áreas)
- **Desempenho** — quanto tempo e quantos passos para completar tarefas básicas.
- **Precisão** — quantos erros; foram fatais ou a pessoa se recuperou?
- **Lembrança** — quanto retém depois de períodos sem usar.
- **Resposta emocional** — como se sentiu ao terminar; confiante ou estressada? Recomendaria a um amigo?

### Como conduzir
- **"Pensar alto"**: usuário verbaliza a intenção ao agir.
- **Envolvidos**: participante + **moderador** (dá instruções e tarefas) + **observador** (o designer; manter o mínimo para não constranger). Gerente/dev podem observar para ganhar visão real.
- **Local**: ambiente real do participante (vê recursos, resolução, interrupções reais) **ou** laboratório (eficiência, sem interrupções, gravação, eye tracking, espelhos para observadores ocultos).
- Rankings, follow, avaliações/comentários e status de usuário são padrões de interação comportamentais úteis para comunidades (gamification/engajamento).

---

## Sequência mínima recomendada (resumo executável)

1. Entrevistar stakeholders e usuários; escolher método por propósito; destilar dados.
2. Consolidar em personas (ou proto-personas) com **objetivos finais** claros; eleger a persona primária.
3. Definir modelo mental, cenários (começar pelo de 1ª utilização), fluxo de tarefas; sintetizar dados+funcionalidades.
4. Alinhar cliente×usuário (UX Canvas); priorizar features (valor usuário/negócio × esforço → MVP).
5. Rabiscoframe → 8 steps → wireframe (com anotações) → protótipo (fidelidade conforme a pergunta a responder).
6. Aplicar mobile: thumb zone (CTA embaixo), Fitts (alvos/área grandes), Hick (menos opções), microinterações (trigger→rules→feedback→loops/modes).
7. Avaliar: 10 heurísticas de Nielsen + teste de usabilidade (pensar alto, 4 métricas). **Iterar.**
