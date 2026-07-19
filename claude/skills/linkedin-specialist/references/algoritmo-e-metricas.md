# Algoritmo e métricas do LinkedIn

## Antes de qualquer coisa: um aviso de epistemologia

Ninguém fora do time de engenharia do LinkedIn conhece o algoritmo de distribuição do feed. Isso inclui todo consultor, todo criador de conteúdo com 200 mil seguidores e todo curso de "hackeando o LinkedIn". Inclui este arquivo.

O que existe, na prática, são três categorias de conhecimento, e elas não têm o mesmo valor:

| Categoria | O que é | Confiança | Como tratar |
|---|---|---|---|
| Mecanismo publicado | O que a própria LinkedIn descreve no blog de engenharia, na documentação de produto ou em declarações públicas de gente do time | Alta, mas geralmente genérica demais para virar tática | Use como âncora. Quando algo contradiz isso, o algo está errado. |
| Inferência de amostra | Padrões observados por quem analisou muitos posts (agências, ferramentas de analytics, criadores com histórico longo) | Média. Correlação sem controle, viés de sobrevivência forte | Trate como hipótese. Teste no seu próprio perfil antes de acreditar. |
| Folclore | "O LinkedIn pune link externo em 70%", "poste às 8h12 de terça", "comente em 5 minutos ou morre" | Baixa a nula. Números com falsa precisão são a assinatura do gênero | Ignore, ou teste com desconfiança ativa. |

Este arquivo inteiro respeita essa separação. Onde algo for mecanismo bem estabelecido, está dito. Onde for inferência razoável, está dito. Onde for mito, está dito e desmontado.

Um segundo aviso, mais importante que o primeiro: o algoritmo muda. Ele é reajustado continuamente, e às vezes de forma grande. Qualquer tática que funcione *por causa* de uma peculiaridade do ranking tem prazo de validade curto. Qualquer coisa que funcione *porque as pessoas gostam de ler* dura. Essa é a razão real pela qual "hackear o algoritmo" é uma perda de tempo: você está otimizando contra um alvo móvel e opaco, quando poderia estar otimizando contra um alvo estável e legível, que é o ser humano do outro lado.

Terceiro aviso, específico para o público deste material: se o seu objetivo é conseguir uma vaga remota no exterior, o alcance é um meio, não um fim. Um post com 400 impressões que fez um engineering manager de Berlim te mandar mensagem vale mais que um post com 80 mil impressões que gerou 300 curtidas de brasileiros procurando a mesma coisa que você. Guarde isso, porque a metade final deste arquivo é construída em cima dessa frase.

---

## Como a distribuição funciona, em termos gerais

O que é seguro dizer sobre o pipeline, sem inventar detalhe:

**1. Filtro de qualidade e spam.** Antes de qualquer distribuição, o conteúdo passa por classificadores que separam spam claro, conteúdo de baixa qualidade e conteúdo aceitável. Isso é mecanismo publicado — a LinkedIn já descreveu publicamente ter uma etapa de classificação de qualidade. O que não é público é o que exatamente cai em cada balde. Post que é só link, post gerado em massa, post com padrão de engajamento artificial e conteúdo repetido são candidatos plausíveis a rebaixamento.

**2. Teste inicial com uma fatia da rede.** O post não vai para todos os seus contatos de uma vez. Ele é mostrado a um subconjunto — plausivelmente enviesado para quem interage com você com frequência e para quem está online naquele momento. Essa é a fase que define quase tudo.

**3. Avaliação da resposta.** O sistema observa como essa fatia reage. Não só se reagiu, mas *como*: parou para ler, comentou algo substancial, compartilhou, ignorou, escondeu, denunciou. É aqui que a diferença entre curtida e comentário longo aparece.

**4. Expansão.** Se a resposta for boa, o post é oferecido a públicos progressivamente mais distantes: mais gente da 1ª conexão, depois 2º grau via interações de quem já engajou, depois seguidores e usuários fora da sua rede que têm afinidade com o tópico. Cada rodada de expansão é uma nova avaliação. Se a resposta cai, a expansão para.

**5. Ranking contínuo do feed.** Mesmo distribuído, o post ainda compete por espaço. O feed de cada pessoa é ordenado por relevância prevista para *aquela* pessoa. Seu post pode ter sido entregue e nunca ter chegado ao topo do feed de ninguém.

Resumido em tabela, com o nível de confiança de cada etapa:

| Etapa | O que acontece | Confiança | O que você controla |
|---|---|---|---|
| Classificação de qualidade | Separação entre spam, baixa qualidade e conteúdo apto | Mecanismo publicado, critérios opacos | Não ser spam. Isso é quase tudo |
| Distribuição de teste | Amostra da rede, provavelmente enviesada por afinidade e por quem está online | Inferência forte | Horário, e a composição da sua rede |
| Avaliação de resposta | Leitura dos sinais gerados pela amostra | Inferência forte | O gancho, o corpo, sua presença respondendo |
| Expansão em ondas | Oferta a públicos progressivamente mais distantes | Inferência razoável | Quase nada, a esta altura |
| Ranking por pessoa | Ordenação individual do feed de cada usuário | Mecanismo publicado | Nada |

A leitura útil dessa tabela: quase toda a sua alavancagem está nas duas primeiras colunas de controle — quem está na sua rede e o que você escreveu. A partir da etapa de expansão, você é passageiro. Táticas que prometem influenciar o que acontece depois do teste inicial estão vendendo controle sobre algo que ninguém controla.

### Uma consequência que quase ninguém tira

Se a fase decisiva é o teste com uma fatia pequena da sua rede, então o alcance de um post é, em boa medida, uma propriedade da *rede*, não do post. O mesmo texto publicado por duas pessoas diferentes tem destinos completamente diferentes. Isso explica por que copiar o formato de quem tem audiência grande quase nunca funciona: você copiou a parte visível e não a parte que estava fazendo o trabalho.

### O mito das 24 horas

"O post morre em 24 horas" é folclore. Não há evidência pública de um decaimento em degrau nesse ponto. O que existe é decaimento por novidade — conteúdo recente tende a ser priorizado — e ele é gradual, não uma parede.

Mais interessante: posts ressuscitam. Um post de duas semanas atrás pode voltar a receber impressões porque alguém comentou nele hoje, porque alguém o compartilhou, ou porque o sistema encontrou uma audiência nova por afinidade de tópico. Isso é observado com frequência suficiente para ser considerado real, ainda que o mecanismo exato não seja público. Consequência prática: não apague um post porque "flopou" em duas horas. E vale a pena responder um comentário que chega no sétimo dia — ele pode reabrir a distribuição.

---

## Os sinais que plausivelmente pesam

A ordem abaixo é inferência razoável, não peso publicado. Ninguém de fora tem os coeficientes. Mas a direção é consistente entre amostras grandes e com o que faz sentido para um sistema que quer maximizar tempo e satisfação na plataforma.

| Sinal | Por que pesa | Nível de confiança |
|---|---|---|
| Tempo de permanência (dwell time) | Mede interesse real sem depender de o usuário clicar em nada. A LinkedIn já falou publicamente em otimizar por conversas significativas e valor percebido, não por cliques. É o sinal mais difícil de falsificar. | Alta |
| Comentário longo e resposta ao comentário | Custa esforço, indica conversa, e gera mais conteúdo para o feed dos outros. Uma troca de três mensagens vale muito mais que três comentários isolados. | Alta |
| Compartilhamento com texto próprio | Alguém colocou a própria reputação em cima do seu conteúdo e abriu uma nova árvore de distribuição. | Alta |
| Salvar | Sinal privado e desinteressado. Ninguém salva para agradar você. | Média-alta |
| Clique em "ver mais" | Prova que o gancho funcionou. Correlaciona diretamente com dwell time. | Média |
| Reação (curtida e variantes) | Barata, quase reflexa, frequentemente dada sem leitura. Conta, mas pouco. | Média |
| Clique em link externo | Tira a pessoa da plataforma. Provavelmente não é recompensado. | Baixa/negativa |
| Esconder post, "não quero ver isso", denúncia | Sinal negativo forte, e provavelmente pesa mais que vários positivos. | Alta |

### Dwell time merece um parágrafo próprio

Se você só puder otimizar uma coisa, otimize isto. Tempo de permanência é o sinal mais informativo que um feed pode coletar porque é caro de falsificar, não exige ação consciente do usuário e correlaciona diretamente com a única coisa que a plataforma quer maximizar: atenção.

O que ele implica na prática, para quem escreve:

- As primeiras duas linhas fazem quase todo o trabalho. Elas decidem entre rolar e parar. Um post excelente com abertura burocrática é um post que ninguém leu.
- Texto que exige "ver mais" e entrega algo depois do clique produz o padrão ideal: clique, permanência, leitura completa.
- Densidade importa mais que tamanho. Um texto de 15 linhas sem gordura retém melhor que um de 8 linhas cheio de frase de efeito.
- Imagem que não acrescenta nada custa espaço de rolagem sem gerar permanência.
- Conteúdo que exige pensar — um trade-off real, um caso limite, um erro caro — retém. Conteúdo que confirma o óbvio não.

Isso é a razão pela qual "escreva bem" não é um conselho preguiçoso, e sim a tática mais alinhada ao mecanismo que existe.

### Por que curtida vale pouco

Porque é ruído. Curtir custa um toque, é frequentemente feito na rolagem sem leitura, e é sistematicamente inflado por reciprocidade social. Um sinal fácil de emitir é um sinal fácil de manipular, e qualquer sistema de ranking decente desconta sinais manipuláveis.

### Por que "Ótimo post!" vale quase nada

Comentário de duas palavras tem o custo de uma curtida e a mesma capacidade de discriminar qualidade: nenhuma. Sistemas de ranking modernos analisam o texto do comentário, não só a existência dele. Comentários genéricos, repetitivos ou claramente automatizados provavelmente são descontados — e, num cenário de engagement pod, provavelmente sinalizam o contrário do que quem os escreveu queria.

O corolário incômodo para quem publica: se o seu post só gera "muito bom!", ele não gerou conversa. Não é falha do algoritmo. É falha do post, que provavelmente não disse nada discutível.

---

## Afinidade, relevância e o teto do seu alcance

Três ideias que explicam mais sobre o seu alcance do que qualquer tática.

**Afinidade.** Quem interage com você repetidamente passa a ver você mais. É simetricamente verdadeiro: quando você comenta, curte e conversa com alguém, você aumenta a probabilidade de aparecer no feed dela. Isso é mecanismo bem estabelecido em qualquer feed social e coerente com o que a LinkedIn descreve. Implicação prática: relacionamento consistente com 50 pessoas relevantes vale mais que 5 mil conexões frias.

**Relevância de tópico.** O sistema tenta inferir do que o seu conteúdo trata e quem se interessa por aquilo. Publicar sobre o mesmo campo semântico de forma consistente ajuda essa inferência. Alternar entre Kubernetes, motivação, política e receita de bolo degrada. Isso não significa monotema — significa território reconhecível. "Backend distribuído e carreira internacional em tech" é um território. "Coisas que eu penso" não é.

**O teto da rede.** Este é o ponto que quase todo mundo ignora. A distribuição inicial vem da sua rede. Se a sua rede é quase toda brasileira e você escreve em inglês mirando o mercado americano, o teste inicial é feito com um público que não é o seu alvo, responde pouco, e o post não expande. Não é o algoritmo te punindo. É a matemática de quem você deixou entrar.

Um perfil com 800 conexões certas alcança mais gente certa que um perfil com 12 mil conexões erradas. Quem quer vaga remota no exterior tem, quase sempre, um problema de composição de rede antes de ter um problema de conteúdo.

---

## O que reduz alcance: comprovado, plausível e boato

| Fator | Status | O que é razoável concluir |
|---|---|---|
| Link externo no corpo do post | Plausível, magnitude exagerada | O LinkedIn quer reter usuários; conteúdo que exporta atenção provavelmente é menos favorecido. Não há evidência pública de penalidade fixa, e números como "70% menos alcance" são inventados. Mitigação sensata: link no primeiro comentário ou no post, dependendo do objetivo. Se o clique é o objetivo, às vezes vale ter menos alcance e mais clique. |
| Editar depois de publicar | Boato, principalmente | Não há evidência pública de penalidade por edição. O que existe é confusão de causa: gente edita posts que já estavam indo mal. Corrija erro de digitação sem medo. Reescrever o gancho inteiro 40 minutos depois muda o post, não o castigo. |
| Excesso de hashtags | Plausível, efeito pequeno | Muitas hashtags parecem spam para classificadores e para humanos. Três é uma convenção razoável. Dez não vão te salvar. |
| Marcar gente que não responde | Plausível e ruim | Marcação sem resposta é sinal fraco ou negativo, e marcação em massa parece spam. Marque quem realmente tem a ver e provavelmente vai interagir. Nunca marque dez pessoas "para dar alcance". |
| Publicar em rajada | Real, mas por outra razão | Dois posts em poucas horas competem entre si pelo mesmo público e diluem a fatia de teste. Não é punição; é canibalização. |
| Engagement pod | Comprovadamente contraproducente a médio prazo | Padrões de engajamento coordenado são detectáveis, e a LinkedIn já declarou publicamente combater engajamento artificial. Além do risco de rebaixamento, o pod entrega o sinal errado: engajamento vindo de gente sem afinidade real com o tópico ensina o sistema a te mostrar para o público errado. |
| Conteúdo repetido ou reaproveitado sem mudança | Plausível | Republicar o mesmo texto tende a render menos. Reaproveitar a mesma ideia com abordagem nova é outra coisa e é legítimo. |
| Post que ninguém termina de ler | Real, e é o mais importante da tabela | Dwell time baixo é o sinal negativo mais direto que existe. Texto longo não é problema; texto longo que não sustenta atenção é. |

Note o padrão: quase todo "fator de penalidade" que realmente importa é uma reformulação de "as pessoas não gostaram o suficiente". As exceções são as que envolvem manipulação. Isso é uma pista sobre onde investir esforço.

---

## Hashtags

O que elas fazem hoje, na prática: pouco.

Houve uma época em que seguir hashtag era um mecanismo relevante de descoberta no LinkedIn e páginas de hashtag tinham peso. Esse papel foi encolhendo à medida que o sistema passou a inferir tópico diretamente do texto. Hoje a hashtag é, na melhor das hipóteses, um sinal fraco de categorização que o classificador provavelmente já teria extraído sozinho.

Recomendação prática, sem cerimônia:

- Use de zero a três hashtags.
- Prefira termos que descrevem o assunto de verdade e que alguém poderia seguir, não termos genéricos de motivação.
- Coloque no final. Hashtag no meio da frase atrapalha a leitura, e leitura é o que importa.
- Não gaste mais de dez segundos nisso.

A razão de existir uma seção sobre hashtags aqui não é que elas importem. É que a discussão sobre elas consome uma quantidade absurda de atenção — há mais conteúdo publicado sobre "quantas hashtags usar" do que sobre "como escrever um primeiro parágrafo que faz alguém parar". Essa desproporção é diagnóstica do gênero inteiro de conselho sobre LinkedIn: as pessoas preferem discutir variáveis fáceis de ajustar a variáveis difíceis de melhorar.

---

## Horário e frequência

### O que realmente muda

**O fuso da sua audiência.** Este é o único fator de horário que importa de verdade, e ele não é sobre o relógio universal — é sobre quando as pessoas que você quer alcançar estão no aplicativo.

**As primeiras horas.** A janela em que a fatia de teste está sendo avaliada — a duração exata não é pública, e "a primeira hora" é aproximação, não número. Publicar quando você não pode estar presente desperdiça a única hora em que a sua presença muda algo.

**Consistência.** Publicar com regularidade dá ao sistema mais amostras para aprender quem se interessa por você, e dá à sua rede o hábito de te ver. Uma cadência sustentável (uma a três vezes por semana) supera uma explosão de dez posts seguida de silêncio de dois meses.

### O que é mito

O horário mágico universal. "Terça às 9h" é um artefato estatístico de amostras agregadas de audiências majoritariamente americanas e de horário comercial. Não se aplica a você mecanicamente, e mesmo na amostra original a diferença entre horários bons é pequena comparada à diferença entre conteúdo bom e ruim.

Também é mito que o algoritmo "prefere" um horário. Ele prefere gente disponível. Horário é proxy de disponibilidade.

### O caso brasileiro escrevendo em inglês para os EUA

Esta é a situação concreta do público deste material, então vale a matemática.

Brasília está tipicamente 4 ou 5 horas à frente do Pacífico e 1 ou 2 horas à frente do Leste dos EUA, dependendo do horário de verão americano (o Brasil não adota mais horário de verão, então a diferença muda duas vezes por ano — verifique antes de montar rotina).

Cenário comum, com Leste dos EUA a 2 horas atrás de Brasília:

| Horário em Brasília | Leste dos EUA | Pacífico | Situação da audiência americana |
|---|---|---|---|
| 09h00 | 07h00 | 04h00 | Costa Leste começando; Oeste dormindo |
| 10h30 | 08h30 | 05h30 | Boa janela para a Costa Leste |
| 12h00 | 10h00 | 07h00 | Leste em ritmo pleno; Oeste acordando |
| 14h00 | 12h00 | 09h00 | Melhor cobertura das duas costas |
| 17h00 | 15h00 | 12h00 | Ainda razoável; atenção caindo no Leste |
| 20h00 | 18h00 | 15h00 | Leste saindo; Oeste ainda ativo |

Conclusão prática: para audiência americana ampla, a faixa entre meio-dia e 15h de Brasília tende a cobrir melhor as duas costas. Se o alvo é Europa, a conta inverte — manhã de Brasília é meio da tarde em Berlim, e a faixa das 7h às 10h fica boa.

E o ponto que mais importa: a golden hour tem que caber na sua vida. Publicar às 14h de Brasília e estar em reunião até 16h é pior do que publicar às 10h e estar livre. Escolha o horário em que você pode responder.

### Frequência

Uma a três vezes por semana é uma faixa saudável para alguém que tem um emprego e não quer virar criador de conteúdo. Todo dia funciona se você tiver coisa real para dizer todo dia — quase ninguém tem. Menos de uma vez por semana faz o sistema e a sua rede te esquecerem entre um post e outro.

Regra de decisão simples: publique quando tiver algo que você defenderia numa conversa. Se você está publicando para "manter a consistência" e o texto é vazio, o custo em credibilidade é maior que o benefício em regularidade.

---

## A golden hour: o que fazer e o que não fazer

As primeiras horas depois de publicar são a fase de teste. O que acontece ali determina se o post expande.

**Faça:**

- Esteja disponível. Não publique e saia para uma reunião de duas horas.
- Responda todo comentário, com substância. Uma resposta de uma linha fecha a conversa; uma resposta com uma pergunta ou um dado novo a estende. Threads de resposta geram mais sinal e mais superfície de leitura.
- Responda com calma, não em 30 segundos. Respostas espalhadas ao longo da hora mantêm o post vivo por mais tempo do que dez respostas simultâneas no minuto cinco.
- Comente em posts de outras pessoas nesse mesmo intervalo. Você fica visível e ativo enquanto o seu post circula.

**Não faça:**

- Não peça engajamento em grupo de WhatsApp, Slack ou Telegram. Isso é um pod informal com todos os problemas de um pod formal: engajamento de gente sem afinidade com o tópico, padrão detectável, e — o pior — te ensina que o post funcionou quando ele não funcionou. Você acaba repetindo o formato errado.
- Não escreva "comenta aí que eu mando o material no privado" como isca. Funciona em métrica de vaidade e destrói percepção de senioridade justamente com o público que você quer atrair. Um staff engineer que vê isso não te chama para conversar.
- Não fique atualizando o painel de impressões de cinco em cinco minutos. Isso não é trabalho.
- Não apague o post porque em 20 minutos ele tinha 12 impressões. A distribuição inicial é lenta e irregular por natureza.

---

## Comentar no post dos outros: o canal subestimado

Para quem tem rede pequena — que é o caso de quase todo dev brasileiro começando a mirar o exterior —, comentar é frequentemente o melhor retorno por minuto investido. Melhor que publicar.

**O mecanismo de distribuição:** um comentário substancial num post que já está sendo distribuído coloca o seu nome e a sua foto na frente da audiência daquele post, que é maior e diferente da sua. Publicar depende da sua rede como fatia de teste; comentar empresta a rede de outra pessoa e contorna o teto descrito na seção anterior. Se o comentário for bom, ele recebe reações e respostas próprias, sobe no ranking de comentários e ganha mais exposição ainda. Além disso, atividade recíproca aumenta afinidade — a pessoa cujo post você comentou passa a te ver mais, e vice-versa.

**A assimetria de custo:** publicar um post exige gancho, estrutura, ideia original e um público que já te conheça. Comentar exige só ter algo inteligente a dizer sobre um assunto que alguém já validou como interessante.

Como escrever o comentário, o que evitar e a cadência (3 a 5 comentários bons por semana) estão em `networking-e-mensagens.md`, que é o arquivo dono do assunto. O que importa aqui é só o mecanismo: comentar é um canal de distribuição, não apenas de relacionamento.

---

## Seguidores e conexões

**Conexão** é bidirecional, limitada a 30 mil, e implica aceitação mútua. **Seguidor** é unidirecional, ilimitado, e não exige nada de você. Toda conexão é automaticamente seguidor; o contrário não.

O **modo criador** (ou a configuração equivalente de tornar "Seguir" o botão principal do perfil) muda o botão primário do seu perfil de "Conectar" para "Seguir". Consequências reais:

- Quem chega no seu perfil segue em vez de pedir conexão. Você recebe menos convites, o que reduz ruído de rede.
- Seu conteúdo fica público por padrão, o que amplia distribuição fora da rede.
- Quem quer conectar de verdade ainda consegue, com um clique a mais.

**Quando priorizar seguidores faz sentido:** quando você publica regularmente, quer alcance amplo e não quer que 30 mil vagas de conexão sejam consumidas por gente que nunca vai interagir. Para dev buscando vaga, isso é secundário no começo e passa a fazer sentido depois que existe conteúdo consistente.

**Quando priorizar conexões faz sentido:** quase sempre no início. Conexão de 1º grau tem mais peso na distribuição inicial e habilita mensagem direta sem InMail. Uma conexão com um engineering manager da empresa que você quer vale mais que mil seguidores anônimos.

**Por que número de seguidores é a métrica menos importante da lista:** porque é a mais fácil de inflar, a menos correlacionada com o resultado que você quer, e a que mais convida à autoenganação. Existem perfis com 30 mil seguidores que nunca geraram uma entrevista, e perfis com 900 conexões bem escolhidas que geram três conversas por mês. O que produz oportunidade é *quem* te vê, não *quantos*.

---

## As métricas que a plataforma entrega

| Métrica | O que a plataforma chama assim | O que significa de verdade | Confiabilidade |
|---|---|---|---|
| Impressões | Vezes que o post apareceu na tela de alguém | Aparição, não leitura. Rolar por cima conta. Inflacionada por natureza. | Alta como contagem, baixa como sinal de atenção |
| Visualizações únicas / membros alcançados | Pessoas distintas que viram | Mais honesta que impressões. Use esta quando as duas estiverem disponíveis. | Média-alta |
| Taxa de engajamento | Interações dividido por impressões | Útil para comparar posts seus entre si. Inútil para comparar com outra pessoa, porque depende de tamanho e composição de rede. Definições variam entre painéis. | Média, só como série temporal própria |
| Visualizações do perfil | Quantos abriram seu perfil | A métrica mais próxima de intenção real. Alguém gastou um clique para saber quem você é. | Alta em direção, ruidosa em volume |
| Aparições em pesquisa | Vezes que você apareceu em resultados de busca | Proxy de quão bem seu headline e suas palavras-chave batem com o que recrutador procura. Cresce quando você acerta os termos, não quando você posta mais. | Média, e frequentemente subutilizada |
| Demografia da audiência | Cargos, empresas, localidades e setores de quem viu | Para este público, a métrica mais acionável do painel inteiro. Diz se você está falando com quem contrata ou com os seus pares. | Média, categorias grosseiras, mas direcionalmente útil |
| Seguidores | Contagem acumulada | Vaidade quase pura. Só interessa a tendência de crescimento associada a conteúdo bom. | Alta como número, baixa como sinal |

### O que o painel não te mostra

Tão importante quanto ler o painel é saber o que ele omite:

- **Quem viu e não interagiu.** A maior parte do seu público real é invisível. O engineering manager que leu seus últimos seis posts, nunca curtiu nenhum e um dia manda mensagem não aparece em métrica nenhuma até a mensagem chegar. Esse é literalmente o cenário que você está buscando, e ele é invisível por definição.
- **Dwell time.** A plataforma provavelmente usa, mas não te mostra. Você tem que inferir por proxies fracos, como taxa de "ver mais" quando disponível e qualidade dos comentários.
- **Quantas vezes você foi escondido ou silenciado.** Sinal negativo real, invisível para você.
- **A composição fina da audiência.** As categorias de cargo e setor são grosseiras. "Tecnologia da informação" cobre desde suporte até VP de engenharia.
- **Efeitos de segunda ordem.** Um comentário seu num post alheio pode ter gerado a visualização de perfil que virou entrevista três semanas depois. Nenhum painel liga esses pontos.

Corolário: a parte mais valiosa do seu resultado é sistematicamente não medida. Isso é mais um argumento para tratar o painel como termômetro grosseiro e não como sistema de navegação.

Duas advertências sobre os números da plataforma:

Primeiro, impressões não são comparáveis entre contas nem ao longo de mudanças grandes de produto. Um salto grande de um mês para o outro pode ser mudança no ranking, não mérito seu.

Segundo, o painel é otimizado para te fazer publicar mais. Ele destaca o que sobe e cria a sensação de progresso. Nem toda métrica que a plataforma exibe com destaque é uma métrica que você deveria perseguir.

---

## A métrica que realmente importa para vaga remota no exterior

Se o objetivo é ser contratado por uma empresa fora do Brasil, o funil real é:

pessoa certa vê o conteúdo → abre o perfil → o perfil convence → manda mensagem ou aceita a sua → vira conversa → vira entrevista

Impressão é o topo, e é o degrau mais barato e mais enganoso. Todo o resto é que decide.

| Objetivo | Métrica principal | Meta realista para quem publica 1 a 2 vezes por semana | Comentário |
|---|---|---|---|
| Ser encontrável por recrutador internacional | Aparições em pesquisa, tendência mensal | Crescimento consistente após otimizar headline e seção "sobre" em inglês | Depende do perfil, não da frequência de posts |
| Atrair o público certo | Percentual da audiência com cargos-alvo e países-alvo na demografia | Ver o percentual de fora do Brasil subir mês a mês, mesmo com alcance total estável | Alcance menor com público melhor é vitória |
| Gerar interesse | Visualizações de perfil por semana, filtradas por quem é relevante | Poucas dezenas por semana já é sinal saudável | Volume importa menos que composição |
| Iniciar conversa | Mensagens recebidas ou aceitas por mês | Algumas por mês já indica que o funil funciona | Uma boa por mês vale mais que trinta genéricas |
| Converter | Conversas que viram entrevista | Poucas por trimestre é resultado normal e bom | Ciclo longo; não avalie em janelas curtas |

**A regra de leitura:** se as visualizações de perfil vêm de gente do seu público-alvo e as mensagens aparecem, o sistema está funcionando, mesmo com alcance modesto. Se as impressões estão altas e nada disso acontece, o alcance está errado ou o perfil não converte.

**E quando ignorar a métrica.** Nas primeiras 8 a 12 semanas de publicação consistente, quase todo número que você olhar vai ser ruído. Amostra pequena, rede em formação, variância alta. A resposta certa nesse período é olhar o painel uma vez por mês, no máximo, e continuar publicando. Otimizar com base em três posts é superstição com planilha. O mesmo vale para qualquer semana individual: uma queda de uma semana não é dado.

---

## Diagnóstico: sintoma, causa provável, conserto

| Sintoma | Causa mais provável | Conserto |
|---|---|---|
| Muitas impressões, zero contato | Público errado, ou perfil que não converte. Você está entretendo pares em vez de sinalizar competência para quem contrata | Cheque a demografia da audiência. Se o público é o certo, o problema é o perfil: headline, "sobre" e experiência precisam dizer o que você faz e para quem, em inglês. Se o público é errado, mude o tema e a rede |
| Alcance caindo mês a mês | Fadiga de formato, tema virando repetitivo, ou queda de afinidade porque você parou de interagir com os outros | Volte a comentar em posts alheios. Mude o formato do post. Verifique se você não caiu numa fórmula que a sua rede já aprendeu a rolar por cima |
| Post vai bem com dev, não atrai recrutador | Conteúdo profundo demais em detalhe técnico e pobre demais em contexto de impacto. Recrutador não avalia sua implementação, avalia se você resolve problema de negócio | Mantenha a técnica, mas amarre a decisão a consequência: latência, custo, incidente evitado, prazo. Escreva o parágrafo final para quem não é da sua stack |
| Perfil visto e nunca contactado | O perfil não fecha. Falta clareza sobre o que você quer, disponibilidade, fuso, inglês, ou prova de trabalho | Reescreva o headline como oferta explícita. Deixe claro que você trabalha remoto para o exterior e em qual fuso. Coloque prova verificável logo no alto |
| Alcance travado nas mesmas ~300 pessoas | Rede pequena e homogênea. A fatia de teste é sempre o mesmo grupo, e não há a quem expandir | Adicione conexões relevantes toda semana, sempre com nota — o volume está em `networking-e-mensagens.md`. Comente fora da sua bolha. Modo criador só se você já publica com constância há alguns meses (ver `perfil-completo.md`) |
| Alcance bom em português, nulo em inglês | A rede é brasileira. O teste inicial acontece com gente que não engaja com conteúdo em inglês, e a expansão nunca dispara | Não é problema de algoritmo. Reconstrua a rede antes de esperar resultado: conecte com gente dos mercados-alvo, comente em posts em inglês por semanas, e só então espere que os posts em inglês andem |
| Post explodiu uma vez e nunca mais | Variação natural, quase sempre. Um outlier não é uma fórmula | Não tente reproduzir o post. Tente entender qual tensão ele tocou. Reproduzir formato de outlier é a origem de metade do conteúdo ruim do LinkedIn |
| Muitas curtidas, nenhum comentário | O post não disse nada discutível. Concordância unânime é sinal de irrelevância | Assuma uma posição. Conte o que deu errado. Faça uma pergunta que exija experiência para responder |

---

## Como fazer um experimento honesto

Quase toda "descoberta" sobre o algoritmo vem de comparar dois posts e concluir causalidade. Isso é lixo estatístico, e vale entender por quê: a variância natural entre posts do mesmo autor, com o mesmo tema e o mesmo horário, é enorme. Depende de quem estava online, do que mais estava circulando, de um compartilhamento sortudo. Dois posts podem diferir em ordens de grandeza sem nenhuma diferença de qualidade.

Se você quiser mesmo testar algo:

**1. Uma variável por vez.** Mudou o formato *e* o horário *e* o tema? Você não vai aprender nada. Fixe tudo, mude uma coisa.

**2. Janela longa.** Mínimo de quatro a seis semanas por braço do teste. Menos que isso mistura o efeito com o estado da sua rede naquele mês.

**3. Amostra mínima.** Pelo menos 8 a 10 posts de cada lado, e ainda assim trate o resultado como fraco. Com 3 posts por lado você não tem experimento, tem anedota.

**4. Compare medianas, não médias.** Um post viral distorce a média por completo. A mediana é muito mais informativa sobre o comportamento típico.

**5. Escolha uma métrica de resultado antes de começar.** Se você define a métrica depois de ver os dados, sempre vai achar alguma em que o seu lado preferido venceu.

**6. Aceite empate.** A maioria dos testes vai dar diferença dentro do ruído. "Não deu para distinguir" é um resultado honesto e frequente. Registrá-lo como "descobri que X funciona" é como nasce o folclore.

**7. Priorize testes que valem a pena.** Testar "3 hashtags contra 5" desperdiça dois meses num efeito provavelmente imperceptível. Testar "história com resultado concreto contra tutorial técnico" pode mudar quem te procura. Teste variáveis grandes.

**Um teste que quase sempre vale mais que qualquer experimento de algoritmo:** mostre seu perfil e três posts para um engineering manager de fora do Brasil e pergunte se ele te chamaria para conversar. Cinco minutos de feedback qualificado superam seis semanas de A/B em impressões.

---

## Uma rotina semanal defensável

Não porque exista rotina ótima, mas porque a alternativa — agir por impulso quando o número cai — é pior. Ajuste ao seu tempo real.

| Frequência | Atividade | Tempo | Por quê |
|---|---|---|---|
| Semanal | 3 a 5 comentários substanciais em posts relevantes | 5 a 10 min cada | Maior retorno por minuto, constrói afinidade e visibilidade |
| Semanal | 1 post com ideia própria, publicado num horário em que você pode responder | 40 a 60 min | Prova de pensamento; alimenta o perfil de quem te visita |
| Semanal | 5 a 10 conexões novas relevantes, com nota curta e específica | 15 min | Ataca o teto de rede, que é o gargalo real |
| Semanal | Responder mensagens e comentários pendentes | 15 min | Conversa parada é oportunidade perdida silenciosamente |
| Mensal | Olhar o painel: demografia da audiência, visualizações de perfil, aparições em pesquisa | 15 min | Cadência longa o bastante para o dado significar algo |
| Trimestral | Revisar headline, "sobre" e experiência em inglês | 1 h | O perfil converte; o post só traz gente até ele |

Repare no que não está na lista: checar impressões diariamente, participar de pod, testar hashtags, e refazer o post que "flopou". Nada disso paga o tempo.

## Os mitos mais repetidos, com a resposta curta

**"O LinkedIn pune link externo em X%."**
Não existe número público. A direção é plausível — a plataforma quer reter atenção —, mas a magnitude é inventada. Se o clique importa mais que o alcance, use o link e aceite a troca.

**"Editar o post mata o alcance."**
Não há evidência pública disso. Corrija erros.

**"O post morre em 24 horas."**
Decaimento é gradual, e posts ressuscitam com comentário ou compartilhamento tardio.

**"Existe um melhor horário universal."**
Existe o melhor horário para a *sua* audiência, e o efeito é pequeno comparado ao do conteúdo. Priorize o horário em que você pode responder.

**"Documento em carrossel sempre alcança mais."**
Formatos entram e saem de moda no ranking. Perseguir o formato do momento é a estratégia com pior meia-vida que existe. Escolha o formato que serve à ideia.

**"Precisa postar todo dia."**
Precisa ter algo a dizer. Volume sem substância corrói a única coisa que você está tentando construir, que é credibilidade técnica.

**"Pod de engajamento acelera o crescimento."**
Acelera as métricas de vaidade, entrega ao sistema um sinal de audiência errado, e é detectável. Custo alto, benefício ilusório.

**"Responder comentário em menos de 5 minutos é decisivo."**
Estar presente na primeira hora ajuda. Cinco minutos é falsa precisão.

**"Mais seguidores é mais oportunidade."**
Mais dos *certos* é mais oportunidade. O número absoluto quase não correlaciona com entrevista.

**"O algoritmo odeia texto longo."**
O algoritmo aparentemente gosta de dwell time, e texto longo bom produz dwell time alto. Ele penaliza texto longo *chato*, o que é bem diferente.

**"Se meu post não foi bem, o algoritmo me limitou."**
Quase sempre o post não foi bom, ou a rede não é a certa. Atribuir ao algoritmo é confortável e improdutivo.

**"Alguém descobriu o algoritmo e vende esse conhecimento."**
Não. Se alguém tivesse, teria assinado NDA e não estaria vendendo um curso.

---

## O resumo em cinco linhas

1. Ninguém sabe o algoritmo; o que se sabe é que ele recompensa atenção real e conversa real, e desconta sinais baratos.
2. A composição da sua rede define o teto do seu alcance mais do que qualquer tática de publicação.
3. Comentar bem no post dos outros costuma render mais por minuto do que publicar, especialmente com rede pequena.
4. A métrica que importa não é impressão — é visualização de perfil pelo público certo, mensagem, conversa, entrevista.
5. Nos primeiros meses, a resposta certa para quase toda pergunta sobre métrica é: ignore o número e continue publicando coisa que você defenderia numa conversa.
