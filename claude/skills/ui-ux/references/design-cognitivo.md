# Design Cognitivo — Digest acionável de "O Design do Dia a Dia" (Donald Norman)

> Filosofia central: **a culpa não é sua, é do design.** Quando alguém não consegue
> usar algo, a falha é do designer que não comunicou como a coisa funciona. Todo
> design é um **ato de comunicação** entre designer e usuário — e a única via de
> comunicação é a própria aparência do objeto. "Aprenda a observar." Em interface
> digital: se o usuário precisa de manual, tour, tooltip explicativo ou de perguntar,
> o design já falhou. Bom design não sacrifica beleza por usabilidade nem vice-versa.

---

## 1. Affordances (e Signifiers)

**Definição.** Affordance é a propriedade percebida de um objeto que sugere como ele
pode ser usado. Cadeira → sentar; chapa plana → empurrar; maçaneta → girar; ranhura →
inserir. O *signifier* é o sinal visível que comunica essa affordance ao usuário.

**Por que importa.** Quando as affordances são exploradas, o usuário sabe o que fazer
só de olhar — sem rótulos, sem instruções. "Objetos simples não devem precisar de
imagens, rótulos ou instruções. Quando precisam, o design fracassou."

**Como aplicar em UI digital.**
- Botão deve *parecer* clicável: elevação/sombra, área de toque, estado hover/pressed,
  cursor pointer. Um botão "flat" sem nenhum signifier obriga o usuário a adivinhar.
- Campos de formulário devem parecer editáveis (borda, fundo, placeholder). Um input
  sem borda que parece texto estático não convida à digitação.
- Link deve se diferenciar de texto comum (cor + sublinhado/affordance consistente).
- Área arrastável, deslizável ou expansível precisa de sinal visível (handle, chevron,
  "grip dots"). Se nada indica que dá pra arrastar, ninguém arrasta.
- Affordances *sugerem* possibilidades; restrições *limitam* alternativas. Use os dois.

**Exemplo memorável.** A "psicologia dos materiais" da British Rail: abrigos de vidro
eram estilhaçados por vândalos; de madeira, eram rabiscados e entalhados. Cada material
oferecia a affordance para o "mau uso" correspondente. O material comunica seu uso.

**Erros comuns que este princípio previne:** botões invisíveis/ambíguos; elementos
clicáveis que não parecem clicáveis (e vice-versa: texto decorativo que parece botão);
ícones sem significado; interfaces "limpas demais" que escondem toda interatividade.

---

## 2. Mapeamento (Mapping)

**Definição.** Relação entre controles e seus efeitos. O *mapeamento natural* explora
analogias físicas e culturais: a disposição espacial dos controles espelha a disposição
do que eles controlam.

**Por que importa.** Mapeamento natural elimina a necessidade de memorizar, de rótulos
e de tentativa-e-erro. Mapeamento ruim gera erro permanente.

**Como aplicar em UI digital.**
- Slider de volume/brilho: para cima/direita = mais. Não inverta a convenção.
- Ordem espacial dos controles = ordem do que afetam. Se há 3 painéis e 3 botões,
  o botão da esquerda controla o painel da esquerda.
- Setas de navegação, toggles e steppers devem mover na direção esperada.
- Controles próximos do objeto que afetam (edição inline > painel distante).
- "Compatibilidade de resposta": o movimento do controle deve ser análogo ao efeito.

**Exemplo memorável.** O fogão com 4 bocas dispostas em quadrado e 4 botões numa
fileira: qual botão liga qual boca? Impossível sem rótulos. Solução: dispor os botões
espelhando a posição das bocas. O mesmo vale para interruptores de luz na parede: um
painel que reproduz a planta baixa do ambiente resolve o mapeamento.

**Erros comuns que este princípio previne:** controles que exigem legenda para funcionar;
sliders invertidos; toggles ambíguos (ligado ou desligado?); disposição arbitrária de
botões de ação sem relação com o que operam.

---

## 3. Feedback (Retorno de informações)

**Definição.** Dar a cada ação um efeito visível e imediato. O sistema deve informar,
a cada momento, o que está acontecendo em resposta ao que o usuário fez.

**Por que importa.** Sem feedback o usuário não sabe se a ação funcionou. Ele repete o
comando (ação executada em dobro), desiste, ou conclui erroneamente que falhou.
Ausência de feedback também gera **falsa causalidade** e superstição de uso.

**Como aplicar em UI digital.**
- Todo clique/submit precisa de resposta em < 100ms: estado de loading, spinner,
  botão desabilitado, barra de progresso.
- Confirme resultado de ações destrutivas/importantes com toast/mensagem clara.
- Formulário: validação inline mostrando sucesso e erro no campo, não só no submit.
- Nunca deixe o usuário no escuro esperando; se demora, mostre progresso real.
- Feedback deve corresponder à *intenção* do usuário e ser fácil de interpretar
  (prefira gráfico/visual a texto cru de estado).

**Exemplo memorável.** O banheiro na Holanda com exaustor "invisível": o arquiteto
escondeu tão bem a ventilação que não havia som nem sinal. O usuário apertava o botão
(que só acendia uma luz enganosa) e não tinha como saber se o exaustor ligou. Um simples
ruído resolveria — o som é feedback quando a informação visual é impossível.

**Erros comuns que este princípio previne:** duplo-submit de formulários/pagamentos;
usuário clicando várias vezes por não ver resposta; ansiedade de "travou?"; ações
silenciosas cujo efeito o usuário nunca percebe.

---

## 4. Modelos conceituais e Modelos mentais

**Definição.** O *modelo conceitual* é a explicação simplificada de como o sistema
funciona. O usuário constrói na cabeça um *modelo mental* a partir do que vê. Três peças
(fig. 7.1): **modelo de design** (o que o designer tem em mente), **modelo do usuário**
(o que o usuário deduz) e **imagem do sistema** (tudo que o produto expõe: aparência,
comportamento, textos, docs). O designer só fala com o usuário através da imagem do
sistema — nunca diretamente.

**Por que importa.** Um bom modelo conceitual permite prever os efeitos das ações. Se a
imagem do sistema é incoerente, o usuário forma um modelo mental errado e erra.

**Como aplicar em UI digital.**
- A estrutura visível da UI deve refletir o modelo real: navegação, hierarquia e nomes
  precisam expor como o sistema realmente opera.
- Consistência total entre telas, termos e comportamentos: mesma ação, mesmo resultado.
- Nomes de menus/botões devem casar com funções que o usuário já conhece (relacione o
  novo ao familiar).
- Se você precisa de um manual para explicar o fluxo, a imagem do sistema está falhando.

**Exemplo memorável.** A geladeira de dois controles ("freezer" e "alimentos frescos")
que na verdade tem um só termostato e um mecanismo de resfriamento. O rótulo sugere dois
sistemas independentes (modelo falso); ajustar a temperatura fica impossível porque o
modelo mental não corresponde à realidade. O mesmo com o termostato tratado como
"válvula/acelerador" quando é só liga/desliga.

**Erros comuns que este princípio previne:** IA/fluxo que o usuário não consegue prever;
inconsistência entre telas; recursos que "funcionam de um jeito estranho"; rótulos que
mentem sobre o que o botão faz.

---

## 5. Restrições (Constraints): físicas, culturais, semânticas, lógicas

**Definição.** "A maneira mais segura de tornar algo fácil de usar, com poucos erros, é
tornar impossível fazê-lo de outro modo." Quatro classes (do exemplo da moto de Lego):
- **Físicas** — o mundo impede a ação errada (um pino grande não entra num furo pequeno).
- **Semânticas** — o significado da situação limita as opções (o para-brisa protege o
  rosto, logo vai na frente).
- **Culturais** — convenções aprendidas (vermelho = traseira/parar; azul piscando = polícia).
- **Lógicas** — dedução ("sobrou uma peça, só há um lugar para ela").

**Por que importa.** Restrições reduzem o número de alternativas *antes* de qualquer
ação, prevenindo o erro em vez de corrigi-lo depois.

**Como aplicar em UI digital.**
- **Físicas** → desabilite/oculte botões inválidos no contexto; inputs com máscara
  (data, telefone, cartão) que só aceitam o formato certo; date picker em vez de texto
  livre; limite de caracteres imposto pelo campo.
- **Semânticas/lógicas** → só mostre opções que fazem sentido no estado atual;
  wizards que revelam o próximo passo apenas quando o anterior é válido.
- **Culturais** → siga convenções da web: X fecha, logo leva à home, carrinho no canto
  superior direito, vermelho = erro/destrutivo, verde = sucesso. Não reinvente.
- Combine affordances (sugerem o possível) + restrições (eliminam o inválido).

**Exemplo memorável.** A moto de Lego de 13 peças que qualquer adulto monta sem
instruções: restrições físicas dizem o que encaixa onde; semânticas põem o para-brisa na
frente; culturais posicionam as luzes (vermelha atrás); lógicas colocam a última peça no
único lugar que sobra. O design foi cuidadosamente projetado para guiar sem manual.

**Erros comuns que este princípio previne:** dados inválidos em formulários; usuário
executando ação impossível no estado atual; erros de formato; passos fora de ordem.

---

## 6. Os dois Golfos: Execução e Avaliação

**Definição.** Entre a mente do usuário e o estado físico do sistema há duas lacunas:
- **Golfo da execução** — o sistema oferece ações que correspondem à intenção do usuário?
  Quão fácil é *fazer* o que quero, sem esforço extra?
- **Golfo da avaliação** — o sistema mostra seu estado de forma fácil de perceber e
  interpretar? Quão fácil é *entender* se consegui o que queria?

**Por que importa.** Toda dificuldade de uso mora num desses golfos. O trabalho do design
é *encurtá-los ou eliminá-los*.

**Como aplicar em UI digital.**
- Golfo da execução: reduza passos, ofereça atalhos, autocomplete, ações diretas
  (arrastar em vez de configurar), defaults inteligentes. A ação que o usuário quer deve
  estar disponível e óbvia.
- Golfo da avaliação: torne o estado visível e legível — status claro, resultado imediato,
  representações visuais em vez de códigos crus.

**Exemplo memorável.** Carregar filme no projetor de cinema: sequência longa e obscura
(golfo de execução enorme) e, com o filme dentro, impossível saber se foi colocado certo
(golfo de avaliação). O videocassete "encurtou" o golfo: enfia a fita e aperta um botão.

**Erros comuns que este princípio previne:** fluxos com passos excessivos; funcionalidade
existente mas escondida; usuário sem saber em que estado o sistema está.

---

## 7. Os Sete Estágios da Ação

**Definição.** Modelo aproximado do que acontece quando alguém faz algo — 1 estágio de
meta, 3 de execução, 3 de avaliação:
1. Formalizar a **meta** (o que quero atingir)
2. Formalizar a **intenção**
3. Especificar a **ação**
4. **Executar** a ação
5. **Perceber** o estado do mundo
6. **Interpretar** esse estado
7. **Avaliar** o resultado (comparar com a meta)

Muitas ações são *oportunistas* (disparadas pelo ambiente), não planejadas — e o ciclo
pode começar em qualquer ponto.

**Por que importa.** É um checklist de design: cada estágio pode dar errado. Cada um vira
uma pergunta (fig. 2.7): "Consigo descobrir a função? / determinar quais ações são
possíveis? / o mapeamento? / executar a ação? / saber em que estado está? / interpretar o
resultado?".

**Como aplicar em UI digital.** Para cada tela/fluxo, percorra os 7 estágios e pergunte:
o usuário descobre o que é possível? sabe como fazer? consegue executar? vê o que
aconteceu? entende? sabe se atingiu a meta? Onde a resposta for "não", há um defeito.

**Exemplo memorável.** A própria história do projetor mapeada nos estágios: os usuários
não tinham problema de *entender a meta* — tinham problema de mapeamento (estágio 3) e de
feedback (estágios 5–6).

**Erros comuns que este princípio previne:** telas onde o usuário não descobre a próxima
ação, não sabe se acertou, ou não entende o resultado.

---

## 8. Conhecimento na cabeça vs. no mundo

**Definição.** O comportamento correto não exige que tudo esteja memorizado: o
conhecimento pode estar *no mundo* (visível na interface) ou *na cabeça* (memorizado).
Conhecimento no mundo é fácil de usar mas precisa ser procurado; na cabeça é rápido mas
exige aprendizado e é falível.

**Por que importa.** Não confie na memória do usuário. "As pessoas não conseguem lembrar
nem os próprios números de telefone." Ponha a informação necessária na tela.

**Como aplicar em UI digital.**
- **Reconhecer > lembrar**: mostre opções (menus, listas, autocomplete) em vez de exigir
  que o usuário decore comandos ou códigos.
- Limite de memória de curto prazo: ~5 itens. Não peça que ele guarde dados entre telas —
  exiba resumo, mantenha o que foi digitado, preserve contexto ao interromper.
- Ofereça auxiliares mnemônicos: rascunhos salvos, histórico, "recentes", breadcrumbs.
- Permita alternar: usuário experiente internaliza (atalhos), novato usa o que está no
  mundo (menus). Suporte os dois sem que um atrapalhe o outro.

**Exemplo memorável.** O bilhete no carro emprestado: "para tirar a chave, o carro tem de
estar em marcha à ré". Sem essa dica escrita, o conhecimento teria de existir na cabeça —
e a chave ficaria presa para sempre. O carro não dava nenhuma indicação física.

**Erros comuns que este princípio previne:** interfaces que exigem decorar comandos;
perda de dados ao voltar/interromper; sobrecarga cognitiva; dependência de memória.

---

## 9. Simplificar a estrutura das tarefas

**Definição.** Reestruture tarefas para minimizar planejamento e resolução de problemas.
Tarefas do quotidiano devem ser *rasas* (poucas decisões independentes) ou *estreitas*
(poucas alternativas por passo) — nunca amplas E profundas como um jogo de xadrez.

**Por que importa.** Memória de curto prazo, longo prazo e atenção são limitadas. Tarefa
complexa demais quebra em qualquer um desses limites.

**Como aplicar em UI digital.**
- Quebre fluxos longos em passos curtos e lineares (wizard), cada um com uma decisão.
- Use tecnologia para reduzir carga mental: preencha automaticamente, calcule por trás,
  sugira defaults, elimine campos deriváveis.
- Automatize o tedioso — mas mantenha o usuário no controle e ciente do que acontece
  (cuidado com superautomatização, que torna o usuário "escravo do sistema").
- Torne visível o invisível para simplificar decisões (mostre implicações, previews).

**Exemplo memorável.** Sinalização de rodovias "M" britânicas: 6 placas em sequência
apresentam a informação da saída lenta e gradualmente, linearizando a decisão do motorista
para minimizar a carga mental. Bom design distribui a complexidade no tempo.

**Erros comuns que este princípio previne:** formulários gigantes de uma tela só;
fluxos que exigem o usuário planejar/lembrar demais; sobrecarga de opções simultâneas.

---

## 10. Erro humano: Lapsos (slips) vs. Enganos (mistakes)

**Definição.** Duas categorias fundamentais de erro:
- **Lapso (slip)** — a *intenção estava certa*, mas a execução saiu errada (ação
  automática/subconsciente descarrilou). Fácil de detectar (se houver feedback).
- **Engano (mistake)** — a *intenção estava errada*: meta ou plano inadequado, avaliação
  equivocada da situação. Difícil de detectar; a ação executada "combina" com a meta errada.

Seis tipos de lapso úteis para design:
- **Captura** — uma sequência muito praticada "sequestra" a pretendida (você ia trocar de
  roupa e se descobre deitado na cama).
- **Descrição** — ação certa no objeto errado, quando dois objetos são parecidos/próximos
  (joga a camisa suada no vaso em vez do cesto).
- **Base em dados** — um gatilho sensorial dispara ação não pretendida (disca o número que
  está na frente dos olhos em vez do que queria).
- **Ativação associativa** — um pensamento interno dispara a ação errada (atende o telefone
  e grita "entre!").
- **Perda de ativação** — esquece o que ia fazer no meio do caminho.
- **Erro de modo** — a mesma ação significa coisas diferentes em modos diferentes (o botão
  que ilumina o mostrador também zera o cronômetro).

**Por que importa.** "Se um erro é possível, alguém o cometerá." Presuma que todos os erros
possíveis vão ocorrer e projete para minimizá-los, detectá-los e reverter.

**Como aplicar em UI digital.**
- **Erros de modo**: minimize modos ou torne-os *muito visíveis* (indicador claro de que
  você está no modo "editar"/"insert"/"admin"). Grande fonte de erro em editores.
- **Erros de descrição**: diferencie visualmente ações parecidas (ícone, cor, forma,
  posição). Não alinhe botões idênticos "Salvar" e "Excluir" lado a lado.
- **Confirmação não basta** para lapsos: o usuário confirma a *ação*, não relê o *objeto*
  ("Excluir 'Meu trabalho mais importante'?" → "Sim" → "Mas que droga"). Prefira **tornar
  reversível**: soft delete/lixeira/undo em vez de diálogo de confirmação.
- **Enganos**: dê bom modelo conceitual e feedback rico para o usuário perceber que a
  interpretação está errada antes de agir.
- Torne o erro fácil de detectar (discrepância visível), de consequências mínimas e
  reversível. Não force ações irreversíveis.

**Exemplo memorável.** As secretárias que apertavam "retorno" em vez de "enter" e perdiam
o trabalho: elas *culpavam a si mesmas* e não reclamavam, então o defeito de design nunca
era detectado. As duas teclas tinham funções parecidas e ficavam próximas — um erro de
captura/descrição induzido pelo layout.

**Erros comuns que este princípio previne:** exclusões/ações destrutivas irreversíveis;
confusão de modo; cliques no botão errado; perda de trabalho; diálogos de confirmação
inúteis que o usuário aprova no automático.

---

## 11. Visibilidade

**Definição.** As peças certas precisam estar visíveis e transmitir a mensagem certa:
quais ações são possíveis e qual o estado atual do sistema.

**Por que importa.** "A história da porta ilustra um dos princípios mais importantes: a
visibilidade." Falta de visibilidade torna aparelhos controlados por computador difíceis;
excesso de visibilidade (mil botões) intimida.

**Como aplicar em UI digital.**
- Torne visível o modelo conceitual, as ações disponíveis e os resultados.
- Não esconda funções críticas atrás de estética "limpa" (o botão liga/desliga escondido
  atrás, o menu hambúrguer que oculta a navegação principal).
- Equilíbrio: visível o que importa, oculto o irrelevante. Nem esconder tudo, nem exibir
  tudo. Progressive disclosure para o resto.
- Use som/haptics quando o visual não basta (feedback de sucesso, alerta).

**Exemplo memorável.** As **portas de Norman**: a porta de empurrar bonita e "limpa", sem
nenhum signifier, faz a pessoa puxar. A solução é uma chapa vertical do lado que se empurra
e nada do outro — ou barra horizontal para puxar. A estética escondeu a informação de uso.

**Erros comuns que este princípio previne:** funções escondidas que ninguém descobre;
navegação enterrada; estado do sistema opaco; "limpeza" que sacrifica descoberta.

---

## Síntese: os 7 princípios do Design Centrado no Usuário (cap. 7)

O design deve garantir que **(1) o usuário descubra o que fazer** e **(2) saiba o que está
acontecendo**. Para transformar tarefas difíceis em simples:

1. **Usar conhecimento no mundo E na cabeça** — não confie só na memória; ponha a
   informação na interface, mas permita ao experiente internalizar.
2. **Simplificar a estrutura das tarefas** — reduza planejamento e carga mental.
3. **Tornar as coisas visíveis** — encurte os golfos de execução e avaliação.
4. **Fazer corretamente os mapeamentos** — intenção→ação, ação→efeito, estado→percepção.
5. **Explorar o poder das restrições** naturais e artificiais — reduza as opções à certa.
6. **Projetar para o erro** — presuma que todo erro ocorrerá; torne reversível e detectável.
7. **Quando tudo o mais falhar, padronizar** — se não dá pra usar affordance/mapeamento
   natural, adote um padrão consistente (e siga convenções da plataforma/web).

> **Regra de ouro para checar qualquer interface:** se, ao usar, o usuário pensar "Como
> vou conseguir me lembrar disso?" ou precisar de instrução para uma ação simples, o design
> falhou. Uso fácil não acontece por acaso — alguém projetou com cuidado.
