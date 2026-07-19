# Como recrutadores trabalham

Este arquivo descreve o outro lado da mesa. A maior parte do conteúdo sobre LinkedIn ensina a
otimizar para a plataforma: palavra-chave, algoritmo, hashtag, horário de postagem. Isso é a
camada mais rasa e a que menos decide. O que decide é uma pessoa — quase sempre sob pressão de
meta, com trinta abas abertas e pouco contexto técnico — olhando o seu perfil por alguns segundos
e tomando uma decisão binária.

O objetivo aqui é simples: parar de otimizar para o robô e passar a otimizar para essa pessoa.
Quando você entende o incentivo de quem lê, quase toda a "estratégia de LinkedIn" se resolve
sozinha.

Aviso sobre números: todas as taxas e volumes citados são ordens de grandeza típicas do mercado
de tecnologia, observadas de forma agregada. Variam muito por empresa, senioridade, stack,
região e momento de mercado. Use como bússola, nunca como estatística. Quando um número for
crítico para uma decisão sua, pergunte ao recrutador em vez de confiar na média.

---

## 1. Quem é quem: os sete interlocutores

"Recrutador" é um guarda-chuva para papéis com incentivos radicalmente diferentes. Falar com
todos do mesmo jeito é o erro mais comum e o mais caro.

| Papel | Trabalha para | É medido por | O que ele quer de você | Como falar com ele |
|---|---|---|---|---|
| **Sourcer** | A empresa (time interno) | Volume de candidatos qualificados entregues ao recrutador | Que você seja plausível e responda rápido | Objetividade. Responda em 48h mesmo que seja "não agora" |
| **Recrutador interno / TA** | A empresa | Contratações fechadas, tempo até contratar, qualidade da entrega | Que você passe pelo funil sem surpresas | Transparência sobre disponibilidade, visto, faixa salarial |
| **Agência / staffing** | Múltiplos clientes | Comissão por colocação (% do salário do primeiro ano) | Que você aceite rápido e aceite o que der | Cuidado. Pergunte qual empresa, qual vaga, se já submeteu seu nome |
| **Headhunter executivo** | Um cliente, poucas vagas | Contrato retido, reputação | Relacionamento de longo prazo | Vale responder mesmo sem interesse. Vira canal permanente |
| **Recrutador de plataforma** (Toptal, Turing, Deel-like, marketplaces) | A plataforma | Devs aprovados e alocados; margem por hora | Que você passe nos testes deles e fique disponível | Entenda a margem. Você é inventário deles, não cliente |
| **Hiring manager (HM)** | O próprio time | Entregar o roadmap sem afundar o time | Alguém que resolva a dor específica dele | Fale de escopo, autonomia, impacto, trade-offs |
| **Painel técnico** | O próprio calendário | Nada. Entrevistar é custo para eles | Não perder a tarde com alguém despreparado | Clareza de raciocínio, comunicação, humildade técnica |

### O que muda na prática

**Sourcer** não sabe a diferença entre Kafka e RabbitMQ e não precisa saber. Ele trabalha com uma
lista de requisitos que o HM escreveu e um booleano no LinkedIn Recruiter. Se seu perfil não
contém a palavra que está na busca dele, você não existe — não porque ele é preguiçoso, mas
porque ele nunca viu seu perfil. Isso justifica escrever o stack de forma explícita e redundante.

**Recrutador interno** carrega o processo inteiro e é quem mais sofre com surpresa tardia. Um
candidato que só menciona no quarto passo que precisa de patrocínio de visto, ou que trabalha em
UTC-3 e a vaga exige quatro horas de overlap com PST, queima o tempo dele. Ele nunca mais te
prioriza. Antecipar restrição é favor a ele, não fraqueza sua.

**Agência** é remunerada por colocação. O incentivo é te empurrar para qualquer vaga aberta,
inclusive submeter seu currículo sem avisar. Isso gera o pior cenário possível: a empresa recebe
seu nome por dois canais e o processo trava em disputa de comissão. Regra prática: nunca autorize
submissão sem saber o nome da empresa.

Mensagem padrão para agência:

> Happy to talk. Before you submit my profile anywhere, I need to know the company name and the
> role. I've had duplicate submissions cause problems before, so I approve submissions one
> company at a time.

Comentário: educado, mas fecha a porta para submissão às cegas. Ninguém sério se ofende.

**Plataforma** (Toptal, Turing e similares) é um intermediário que compra sua hora e revende com
margem. Não é golpe — é um modelo de negócio. Mas mude a expectativa: você não está sendo
contratado, está sendo aprovado para um catálogo. O processo é mais padronizado, o teto salarial
é menor e a relação com o cliente final é mediada. É excelente como porta de entrada e ruim como
destino permanente.

**Hiring manager** é o único que realmente decide. Recrutador filtra; HM contrata. Toda conversa
com HM deve mudar de registro: pare de listar tecnologias e comece a falar de problema, decisão e
consequência. "Migrei o serviço de pagamento para eventos" é fraco. "O checkout tinha acoplamento
síncrono com três serviços e caía junto com eles; propus fila e retry, ficamos com um incidente
por trimestre em vez de um por semana" é o registro certo.

---

## 2. Como o sourcing acontece de fato

O sourcer não navega no LinkedIn como você. Ele usa uma ferramenta paga de recrutamento — o
produto principal é o **LinkedIn Recruiter**, e existem camadas menores (Recruiter Lite, Talent
Hub, integrações com o ATS). Os nomes e recursos exatos mudam com frequência; o que importa é o
tipo de informação que a ferramenta expõe.

O que essa camada mostra e o seu perfil público não mostra:

- **Filtros muito mais finos**: anos de experiência calculados, empresa atual e anterior,
  senioridade inferida, escola, idioma declarado, localização com raio, e combinações booleanas
  sobre o texto inteiro do perfil.
- **Projetos e pipelines salvos**: você é adicionado a uma lista chamada "projeto" (equivalente à
  vaga). Você pode estar em vários projetos de várias empresas sem nunca ter sido contatado.
- **Notas e tags da equipe**: recrutadores da mesma empresa escrevem observações sobre você que
  ficam visíveis internamente e persistem por anos. "Falou que só aceita acima de X", "inglês
  travado na call", "recusou em 2023, revisitar" — tudo isso sobrevive.
- **Histórico de contato**: quem já te mandou InMail, quando, se você respondeu. Com esse histórico
  à vista, é inferência forte que um perfil que nunca responde acabe despriorizado.
- **Sinal de abertura visível só para recrutadores**: existe uma configuração de "aberto a
  oportunidades" que pode ser exposta apenas para recrutadores, sem selo público. Isso é
  materialmente diferente de não ter nada marcado — você aparece em filtros dedicados.
- **Destaques automáticos (spotlights)**: a plataforma sinaliza coisas como "mais propenso a
  responder", "interagiu com a marca empregadora", "candidatou-se recentemente", "veio por
  indicação", "ex-funcionário". Esses rótulos mudam de nome e de critério ao longo do tempo, mas
  a lógica é estável: quem já demonstrou algum sinal de interesse sobe na lista.

### Consequências práticas disso

1. **Marcar disponibilidade só para recrutadores é quase sempre vantajoso** e não tem custo de
   imagem, porque não aparece publicamente. Não confunda com o selo público na foto.
2. **Interagir com a página da empresa e com posts de gente de lá gera sinal rastreável.** Não é
   misticismo de algoritmo: a própria ferramenta expõe rótulos desse tipo ao recrutador.
3. **Responder InMail sempre, mesmo que para recusar, tende a proteger sua reputação na base.** Um
   "não, obrigado, mas me procure se surgir X" te mantém entre os que respondem — e isso é o que a
   ferramenta consegue enxergar de você.
4. **A busca é textual.** Se você escreve "trabalho com mensageria assíncrona" e nunca escreve
   "Kafka", você não aparece na busca por Kafka. Sinônimo humano não é sinônimo booleano.
5. **Localização é filtro duro.** Perfil marcado apenas como "São Paulo" pode ser cortado por
   filtros geográficos antes de qualquer leitura. Deixar explícito que você opera remoto e em qual
   janela de fuso resolve.

---

## 3. A economia de atenção: o processo é mais raso do que você imagina

Para uma vaga de engenharia de software mid/sênior com bom volume, é comum um sourcer varrer na
casa das centenas de perfis para montar uma lista curta de algumas dezenas. Cada perfil recebe
poucos segundos na primeira passada — a ordem de grandeza é de cinco a quinze segundos, e a
primeira triagem chega a ser mais rápida que isso.

Nessa passada, o olhar segue mais ou menos esta ordem:

| Ordem | Elemento | Pergunta silenciosa |
|---|---|---|
| 1 | Foto + nome + headline | "Isso é um engenheiro de verdade?" |
| 2 | Cargo atual + empresa atual | "Senioridade e contexto batem?" |
| 3 | Tempo no cargo atual | "Está disponível? Está estável?" |
| 4 | Localização | "Fuso e jurisdição funcionam?" |
| 5 | Cargo anterior e empresa anterior | "A trajetória faz sentido?" |
| 6 | Stack visível (headline, sobre, primeiras bullets) | "Bate com o requisito?" |
| 7 | Idioma do perfil | "Consigo colocar numa call em inglês?" |

Só depois disso — e só se sobreviveu — alguém lê o "Sobre" ou uma descrição de experiência.

### O que faz descartar em três segundos

- Headline genérica que não diz o que você faz ("Apaixonado por tecnologia", "Transformando ideias
  em realidade", "Buscando novos desafios").
- Cargo atual incoerente com a senioridade pretendida.
- Perfil inteiro em português quando a vaga é internacional.
- Foto que não passa como profissional em contexto corporativo estrangeiro (foto de festa, foto de
  grupo, avatar, selfie escura, sem foto).
- Última atualização evidentemente antiga: cargo que terminou em 2019 e nada depois.
- Nada de empresa nomeada — só "freelancer" ou "autônomo" por anos seguidos, sem descrição.

Isso é injusto e é verdade ao mesmo tempo. O ponto não é reclamar da superficialidade, é aceitar
que os primeiros segundos são um filtro de plausibilidade, não de mérito. Você não convence
ninguém em três segundos; você apenas evita ser eliminado.

---

## 4. O funil completo e onde cada perfil morre

Ordens de grandeza típicas para um processo internacional remoto, partindo de sourcing ativo:

| Etapa | Passagem (ordem de grandeza, **não é estatística**) | O que está sendo avaliado | Se você morre aqui, o diagnóstico é |
|---|---|---|---|
| Perfis varridos → InMail enviado | Uma pequena minoria, na casa de um em dez | Plausibilidade visual e textual | Headline, stack invisível, localização, perfil desatualizado |
| InMail → resposta | Uma minoria, na casa de um em cinco | Nada seu. É a mensagem dele e seu momento | Nenhum. Não responder é o seu problema, não o dele |
| Resposta → triagem do recrutador | A maior parte passa | Interesse real, faixa, disponibilidade, autorização | Desalinhamento de faixa ou restrição jurídica |
| Triagem → HM screen | Menos da metade | Coerência da história, inglês, escopo | Inglês travado, narrativa confusa, senioridade inflada |
| HM screen → técnica | Perto de metade | Profundidade real, fit com a dor do time | Você fala de ferramenta, não de problema |
| Técnica → system design | Menos da metade | Codificação, comunicação sob pressão | Falta de prática em live coding, silêncio no raciocínio |
| System design → comportamental | Perto de metade | Trade-offs, escala, maturidade arquitetural | Você constrói sem justificar; não pergunta requisito |
| Comportamental → painel final | A maior parte passa | Conflito, colaboração, autonomia remota | Histórias vagas, sem "eu fiz", sem resultado |
| Painel → referências | Menos da metade | Consenso do time | Um "não" forte de um entrevistador |
| Referências → oferta | Quase todos | Confirmação factual | Divergência entre o que você contou e o que a referência disse |

**Ressalva que acompanha esta tabela.** As passagens acima são ordens de grandeza, não taxas
medidas. Variam muito por empresa, senioridade, stack e momento de mercado. Servem para localizar
onde o seu funil quebra — nunca para prever o seu resultado nem para ser citadas como número.

Do topo ao fundo, é comum que de cada algumas centenas de perfis olhados saia **uma** contratação.
Isso significa que a rejeição é o estado normal do sistema, não um julgamento sobre você.

### Leitura diagnóstica por padrão de morte

- **Ninguém te procura, nunca**: problema de sourcing. Você não aparece nas buscas. É o problema
  mais fácil de resolver e o mais ignorado.
- **Recebe InMail mas nunca passa da triagem**: problema de alinhamento — faixa salarial, fuso,
  contratação (PJ/EOR/CLT), ou inglês.
- **Passa na triagem e morre no HM screen**: problema de narrativa. Sua história de carreira não
  se sustenta em cinco minutos de conversa.
- **Morre na técnica de forma consistente**: problema de prática, não de conhecimento. Devs
  sêniores que não entrevistam há anos performam abaixo do próprio nível.
- **Morre no system design**: problema de vocabulário e de método, não de experiência. Falta o
  ritual — coletar requisito, estimar, propor, criticar a própria proposta.
- **Chega no final e não recebe oferta**: geralmente comparação, não reprovação. Havia outro
  candidato. Peça para ficar no radar; é o momento de maior valor de rede.

---

## 5. ATS: o que é verdade e o que é lenda

ATS (Applicant Tracking System) é o banco de dados onde a empresa gerencia candidaturas. Os mais
comuns em tecnologia: **Greenhouse**, **Lever**, **Ashby**, **Workable**, **SmartRecruiters** e,
em corporações grandes, **Workday** e **SuccessFactors**.

### O que o ATS faz

- Armazena candidaturas, currículos, e-mails, notas de entrevista e scorecards.
- Faz **parsing** do currículo para preencher campos estruturados (nome, e-mail, empresas, datas).
- Aplica **knockout questions**: perguntas eliminatórias respondidas no formulário.
- Permite busca por palavra-chave dentro da base de candidatos.
- Gera relatórios de funil e de tempo por etapa.

### O que o ATS não faz

- **Não pontua e rejeita currículos automaticamente por conta própria.** A ideia de um "robô de
  ATS" que dá nota de 0 a 100 e descarta você por não ter uma palavra é, na esmagadora maioria
  das empresas de tecnologia, falsa. O que rejeita é uma pessoa clicando, ou uma knockout question
  que você mesmo respondeu.
- **Não penaliza fonte, cor ou uso moderado de tabela.**
- **Não lê a "densidade de palavras-chave" e te ranqueia por isso.** Keyword stuffing não te
  promove; te faz parecer artificial para quem lê depois.

### O que é verdade e importa

| Mito | Realidade |
|---|---|
| "O ATS rejeita PDF" | PDF é aceito por praticamente todos. O problema é PDF que é imagem escaneada |
| "Coluna dupla quebra o ATS" | Não quebra o sistema, mas embaralha o parsing. Custo real: campos preenchidos errado que você tem que corrigir na mão |
| "Preciso repetir a palavra-chave 8 vezes" | Precisa aparecer. Repetir não ajuda |
| "Se não usar o termo exato, sou eliminado" | Na busca do recrutador, sim, você não aparece. No ATS, é uma pessoa buscando |
| "Cabeçalho e rodapé são ignorados" | Frequentemente sim. Nunca coloque contato só no rodapé |
| "Gráficos de proficiência ajudam" | Não são lidos por máquina nem levados a sério por humano |

### Knockout questions: o filtro real e automático

Estas perguntas são de fato eliminatórias e automáticas, porque você responde num formulário:

- *"Are you legally authorized to work in [country]?"*
- *"Will you now or in the future require visa sponsorship?"*
- *"Are you located within [region/timezone]?"*
- *"What are your salary expectations?"* (campo numérico obrigatório)
- *"Do you have at least N years of experience with X?"*

Aqui vale rigor. Responder "sim" para autorização de trabalho num país onde você não tem direito
de trabalhar não é esperteza; é a forma mais rápida de ser eliminado no meio do processo e ficar
marcado no ATS. Para vagas globais que contratam via contratante ou EOR, a resposta honesta é
que você é contratado como contractor no Brasil e não precisa de patrocínio — isso é uma vantagem,
não uma desvantagem, e deve ser dito assim.

Formulação útil em inglês:

> I'm based in Brazil and work as an independent contractor / through an EOR. I don't need visa
> sponsorship for a remote role, and I can invoice internationally without any issues on my side.

Comentário: transforma uma pergunta que parece eliminatória numa afirmação de simplicidade
operacional para o empregador.

---

## 6. O que um recrutador de tech realmente avalia, em ordem

Ordem aproximada em que o julgamento se forma:

1. **Senioridade coerente.** Não o título, e sim a soma de anos, escopo descrito e tamanho das
   empresas. Um "Tech Lead" com três anos de carreira levanta suspeita, não admiração.
2. **Estabilidade.** Quanto tempo em cada casa. Dois anos ou mais é confortável. Uma sequência de
   passagens de oito meses precisa de explicação.
3. **Stack.** Bate com o requisito? A pergunta é binária e feita rápido.
4. **Escopo e impacto.** Você mantinha um CRUD ou desenhava o sistema? Liderou alguém? Tinha
   contato com produto? Media resultado?
5. **Tipo e tamanho de empresa.** Startup vs. corporação, produto vs. consultoria, B2B vs. B2C.
   Isso prediz ritmo, autonomia e tolerância a ambiguidade — e é usado como proxy grosseiro.
6. **Inglês.** Não o nível declarado. O nível inferido pelo texto do seu perfil.
7. **Fuso e disponibilidade de overlap.** Quantas horas você cobre da janela do time.
8. **Custo.** Sua faixa cabe no budget aprovado da vaga.

### O que ele não avalia, apesar do que a internet diz

- **Número de conexões e seguidores.** Irrelevante para sourcing.
- **Selos e badges de curso.** Ignorados quase sem exceção.
- **Certificações**, salvo em nichos específicos (cloud em consultoria, segurança, alguns setores
  regulados).
- **Quantidade de posts.** Conteúdo ajuda por inbound, não por ranking de candidato.
- **Nota de faculdade, faculdade em si** para mid/sênior. Peso alto só em júnior e em algumas
  empresas específicas.
- **Recomendações escritas no LinkedIn.** Não entram na triagem. Podem pesar no desempate entre
  dois finalistas, mas o que vale de fato são as referências no fim do funil.
- **Nome fantasia de cargo interno** ("Ninja", "Rockstar", "Engenheiro P3"). Traduza para o
  mercado.

---

## 7. Sinais que eliminam em silêncio

Ninguém vai te dizer que foi por isso. Cada item abaixo já foi motivo de descarte sem feedback.

| Sinal | Como o recrutador lê | Correção |
|---|---|---|
| Sênior no LinkedIn, Júnior no currículo | "Está inflando" | Um único título por período, coerente em todo lugar |
| Três empregos de 7 meses seguidos | "Vai sair em um ano" | Explique no perfil: contrato, projeto encerrado, aquisição, layoff |
| Gap de 18 meses sem menção | "O que aconteceu?" | Uma linha basta: sabático, saúde, estudo, cuidado familiar, empreitada própria |
| Perfil parado desde 2019 | "Não está no mercado / abandonou o perfil" | Atualizar, mesmo que sem trocar de emprego |
| Português impecável, inglês do perfil com erros | "Não sustenta uma call" | Perfil inteiro em inglês, revisado |
| Foto informal, banner com frase motivacional | "Não é o registro deste mercado" | Foto neutra, banner sóbrio ou nenhum |
| Conteúdo político agressivo no feed | "Risco" | Separe as contas. Não é censura, é canal |
| "Estou desempregado, preciso muito, qualquer vaga serve" | "Desespero, sem seletividade" | "Aberto a X, com foco em Y". Disponibilidade não é súplica |
| Headline com 12 tecnologias separadas por barras | "Não sei o que ele faz" | Função + domínio + 2 ou 3 tecnologias âncora |
| Descrições copiadas da descrição da vaga antiga | "Não sei o que ele fez de fato" | Verbo no passado, escopo, resultado |
| Vários "Founder" simultâneos sem produto | "História difusa" | Um projeto, com o que ele é |
| Todas as empresas anônimas ("empresa do setor financeiro") | "Não consigo calibrar" | Nomeie o que puder; NDA raramente cobre o nome do empregador |

Sobre job hopping: o problema não é trocar. É trocar sem contar por quê. Uma linha na descrição
— *"Contract role, closed when the client ended the program"* ou *"Left after acquisition; team
was dissolved"* — elimina a suspeita inteira. O recrutador não está procurando culpado, está
procurando previsibilidade.

---

## 8. Referral: o canal com maior conversão

Indicação interna tem, de longe, a melhor taxa de conversão de todas as fontes. É comum que uma
fração pequena das candidaturas venha por indicação e uma fração desproporcional das contratações
saia dela. A razão é econômica: no ATS, um candidato indicado aparece marcado, quase sempre entra
numa fila separada, e alguém dentro da empresa colocou reputação nisso. Além disso, muitas
empresas pagam bônus por indicação — quem te indica ganha se você for contratado. Pedir indicação
não é pedir favor; é oferecer um negócio.

### Como pedir a quem você conhece bem

Direto, com material pronto para a pessoa não trabalhar:

> Hey Ana — I'm applying for the Senior Backend Engineer role (req 4412) at Acme. Would you be
> comfortable referring me? No pressure at all if you'd rather not. To make it zero effort, here's
> my resume and three lines you can paste: [...]

Comentário: dá saída fácil ("no pressure"), identifica a vaga com número e entrega o texto pronto.

### Como pedir a quem você não conhece bem

Aqui a regra muda: não peça indicação. Peça **contexto**. A indicação, se vier, vem depois.

> Hi Marcus — I saw you work on the Payments team at Acme. I'm considering applying for the
> Senior Backend role there and I'd rather not apply blind. Would you be open to a 15-minute call,
> or even just answering one question here: how much of the work is greenfield vs. maintaining the
> legacy gateway? Happy either way, and thanks for reading.

Comentário: pergunta específica prova que você pesquisou, é barata de responder e abre a porta.
Muita gente responde a mensagem e oferece a indicação por conta própria. Se não oferecer, você
pode pedir depois da conversa, e aí já não é a um estranho.

### Regras que evitam constrangimento

- Nunca peça indicação a alguém que nunca viu seu trabalho para uma vaga que ele não conhece.
- Nunca peça a mais de uma pessoa da mesma empresa ao mesmo tempo sem avisar.
- Sempre dê saída elegante na própria mensagem.
- Se for indicado, avise a pessoa do desfecho. Isso é o que garante a segunda indicação.
- Ex-colegas são o melhor alvo. Eles têm dado real sobre você e o bônus é incentivo suficiente.

---

## 9. A triagem do recrutador: as perguntas e o que está por trás

A primeira call, de 20 a 30 minutos, quase nunca é técnica. É verificação de risco. Cada pergunta
tem uma pergunta escondida.

| A pergunta | O que ele está checando | Como responder |
|---|---|---|
| *"Tell me about yourself."* | Se você sabe se apresentar em 90 segundos e em inglês | Presente → trajetória → por que esta vaga. Nada de infância |
| *"Why are you looking to leave?"* | Se você é um risco de conflito | Motivo voltado para frente, nunca contra alguém |
| *"What are you looking for in your next role?"* | Se a vaga atende, para não perder tempo | Escopo, produto, time. Seja específico |
| *"What are your salary expectations?"* | Se você cabe no budget | Ver seção 10 |
| *"What's your notice period / availability?"* | Planejamento de start | Data concreta. Não invente urgência falsa |
| *"Are you authorized to work in X? Do you need sponsorship?"* | Viabilidade jurídica | Honestidade total. Contractor no Brasil é resposta boa |
| *"What's your timezone and overlap?"* | Se você cobre a janela do time | Horas exatas: *"I can reliably overlap 9am–2pm PT"* |
| *"Are you in other processes?"* | Urgência dele e sua concorrência | Verdade sem detalhe: *"Yes, two, both in early stages"* |
| *"How did you hear about us?"* | Atribuição de fonte | Se foi indicação, diga o nome |

Sobre motivo de saída, a diferença entre uma resposta que passa e uma que queima:

> Ruim: "My manager micromanages everything and the company is a mess."
> Boa: "I've been on the same maintenance-heavy scope for two years. I'm looking for a product
> team where I can own a system end to end — which is what drew me to this role."

Comentário: a segunda diz o mesmo sem transformar você num narrador de conflito. Recrutador ouve
crítica ao empregador atual como amostra do que você dirá dele depois.

Sobre inglês: a triagem **é** o teste de inglês. Não existe uma etapa separada na maioria dos
processos. Ele está avaliando se você entende pergunta feita rápido, se pede repetição sem
travar, e se consegue explicar algo técnico sem tradução literal. Pedir esclarecimento é neutro
ou positivo — *"Sorry, could you rephrase that?"* nunca custou vaga a ninguém. Silêncio longo
custa.

---

## 10. Salário: como não se sabotar com um recrutador estrangeiro

Esta é a conversa em que dev brasileiro mais perde dinheiro, por três motivos: converte para
reais e se assusta com o número, ancora na própria realidade local, e responde primeiro.

### Princípios

1. **Quem fala primeiro perde vantagem, mas travar também perde.** A saída é devolver a pergunta
   uma vez e, se insistirem, dar uma faixa em dólar já calibrada por mercado.
2. **Ancore na vaga, não na sua vida.** O que importa é o que a função vale para eles.
3. **Nunca minta sobre o salário atual.** Mas você não é obrigado a informá-lo — e em várias
   jurisdições nem podem perguntar.
4. **Nunca converta o seu salário atual para dólar como âncora.** É o erro mais caro do mercado
   brasileiro. Você não está pedindo um aumento sobre o que ganha; está sendo precificado numa
   outra economia.

### Devolvendo a pergunta

> Recruiter: "What are you currently making?"
> You: "I'd rather not anchor on my current comp — the markets aren't comparable. What's the
> approved range for this role? I'm confident we can align if it's in the right band."

Comentário: recusa educada, sem tom defensivo, e devolve com uma pergunta legítima. "Approved
range" é o vocabulário interno deles e sinaliza que você conhece o processo.

Se ele insistir uma segunda vez, dê faixa e cole a base ao mercado dele. Nesta fase — triagem — a
resposta é sempre uma faixa. Número único só na negociação de uma oferta já emitida; essa fase é
de `candidatura-e-processo-seletivo.md`.

> "Based on comparable remote senior backend roles in US-based companies, I'm targeting
> [FAIXA-ALVO EM USD/ANO] as a contractor. There's flexibility depending on scope, equity and
> benefits."

Derive `[FAIXA-ALVO EM USD/ANO]` da tabela de faixas de `vagas-remotas-no-exterior.md` — único
arquivo que enuncia remuneração — pelo seu nível e modelo de contratação.

Comentário: faixa ampla, moeda certa, referência ao mercado dele, e uma porta aberta ("depending
on scope").

### Quando ele pergunta o salário em reais

Acontece com agências e com plataformas. A resposta é firme e curta:

> "I price international contract work in USD, at market rate for the role. My local BRL salary
> isn't a useful reference for either of us."

Comentário: você não está sendo difícil, está recusando uma âncora que só serve para reduzir sua
oferta.

### Erros específicos a evitar

- Dizer um número anual pensando em mensal, ou vice-versa. Confirme sempre: *"annual, gross"*.
- Esquecer que como contractor você não tem férias remuneradas, 13º, FGTS, plano de saúde nem
  contribuição previdenciária — e que impostos e contabilidade são seus. O número bruto precisa
  cobrir isso.
- Aceitar "we'll discuss comp later" até o fim do processo. Peça a faixa cedo. Um processo de
  seis etapas que termina 40% abaixo é tempo perdido dos dois lados.
- Negociar apenas o salário. Bônus de assinatura, equipamento, orçamento de aprendizado, dias de
  folga contratados e revisão de seis meses são todos negociáveis, às vezes com menos atrito.

---

## 11. Rejeição, silêncio e reaplicação

| Situação | O que significa de fato | O que fazer |
|---|---|---|
| Rejeição automática em minutos | Knockout question ou filtro de localização | Reveja o que você respondeu no formulário |
| Rejeição depois da triagem | Faixa, fuso ou inglês | Pergunte, educadamente, qual foi o fator |
| Rejeição depois do técnico | Performance na etapa | Pratique o formato, não estude mais teoria |
| Rejeição no painel final | Quase sempre comparação | Peça para ficar no radar. Alta chance de retorno |
| Silêncio após candidatura espontânea | O normal. Muita gente aplica, ninguém lê tudo | Busque indicação ou contato direto com o HM |
| Silêncio após entrevista, mais de duas semanas | Vaga congelada, prioridade mudou, ou candidato preferido em negociação | Um follow-up. Depois, siga em frente |
| "We're moving forward with other candidates at this time" | Frase padrão, sem informação | Não leia significado que não existe |
| "We'd love to keep in touch" vindo do HM | Sinal genuíno em boa parte dos casos | Conecte-se com ele e mantenha contato leve |

Sobre follow-up: um, escrito, curto, depois do prazo que eles te deram. Nunca dois. Nunca no
domingo. Nunca cobrando.

> Hi Sarah — checking in on the Senior Backend role. You mentioned a decision this week, so I
> wanted to see if there's an update. Still very interested. Happy to wait if things have shifted.

Comentário: reconhece o prazo que ele mesmo deu, reafirma interesse, dá saída ("happy to wait").

Sobre reaplicar: a régua informal é de seis meses a um ano para a mesma empresa, e menos se você
tiver mudança material — nova stack, nova senioridade, novo escopo. Reaplicar para a mesma vaga
duas semanas depois é ruído. Reaplicar um ano depois, mencionando o processo anterior, é
positivo — sua nota antiga costuma seguir no ATS e um segundo contato deliberado lê como
maturidade.

> I interviewed for a similar role here about a year ago and made it to the final panel. Since
> then I've led the migration of our billing platform to event-driven processing, which is closer
> to what this role describes. Reapplying with that in mind.

Comentário: nomeia o histórico antes que o recrutador descubra, e explica o que mudou.

---

## 12. Traduzindo tudo isso em decisões de perfil

Amarrando as seções anteriores em regras práticas:

- **Escreva para busca booleana, leia como humano.** Cada tecnologia relevante precisa aparecer
  escrita, pelo menos uma vez, com o nome canônico. Sem listas de 30 itens.
- **Headline é uma frase de função, não um slogan.** Cargo + domínio + duas âncoras técnicas.
- **Perfil em inglês, sem exceção, para vaga internacional.** Português no perfil é o filtro mais
  silencioso de todos.
- **Localização explícita com fuso e status de contratação.** Uma linha no "Sobre" resolve três
  knockout questions antes que sejam feitas.
- **Cada experiência precisa responder três perguntas**: qual era o sistema, o que você fez nele,
  o que mudou depois. Nada de listar responsabilidades da vaga.
- **Marque disponibilidade no modo visível apenas para recrutadores.** Custo zero, ganho direto de
  visibilidade em filtros.
- **Responda todo InMail em até 48h**, mesmo com "não".
- **Trate cada interlocutor pelo incentivo dele**, não pelo cargo dele.

---

## 13. As dez perguntas para olhar o próprio perfil pelos olhos do recrutador

Passe por elas com honestidade. Cada "não" é um item de trabalho.

1. **Em cinco segundos, dá para dizer o que eu faço e em que nível?** Leia só a foto, o nome e a
   headline. Se precisa abrir a experiência para entender, está errado.
2. **Se um sourcer buscar exatamente a stack da minha vaga-alvo, eu apareço?** Faça a busca. Os
   termos exatos estão escritos no meu perfil, com o nome canônico?
3. **Minha senioridade declarada bate com o escopo que eu descrevo?** Um título de liderança sem
   nenhuma frase sobre decisão, arquitetura ou pessoas não se sustenta.
4. **Existe alguma incoerência entre LinkedIn, currículo e GitHub?** Datas, títulos, empresas. A
   menor divergência custa credibilidade no fim do funil.
5. **Todo gap e toda troca curta têm uma linha de explicação?** Se não têm, alguém vai preencher
   com a pior hipótese.
6. **Meu inglês escrito no perfil sustenta a expectativa de uma call em inglês?** Peça para alguém
   fluente ler. Erro no perfil é interpretado como erro de nível.
7. **Está claro, sem ele perguntar, que sou remoto, em que fuso e como sou contratado?** Se não
   estiver, você está delegando uma dúvida que costuma virar descarte.
8. **Cada experiência tem pelo menos um resultado, e não só uma lista de tarefas?** Um número, um
   antes-e-depois, um incidente evitado. Um por emprego basta.
9. **Meu perfil parece ativo?** Data da última atualização, atividade mínima, informação recente.
   Perfil congelado lê como pessoa fora do mercado.
10. **Se eu fosse o hiring manager desta vaga específica, eu me chamaria para a call?** Não "eu
    sou bom o suficiente" — e sim: dada esta dor concreta, este perfil é o que eu procuraria?

Se a resposta da décima for "não sei", o problema quase nunca é falta de competência. É que o
perfil está escrito para você, e não para quem lê.
