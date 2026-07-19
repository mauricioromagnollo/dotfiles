# Escrita e formatos de post no LinkedIn

Este arquivo trata do ofício: como um post é construído, linha por linha, formato por formato. A decisão sobre *o que* postar e *por quê* está em outro lugar. Aqui a pergunta é mais estreita e mais difícil: você já tem algo pra dizer — como escrever de um jeito que alguém leia até o fim?

O público que importa para o dev brasileiro que quer vaga remota no exterior é pequeno e específico: recrutadores técnicos, hiring managers, engenheiros que podem te indicar. Esse público lê rápido, desconfia de superlativo e fecha o app no primeiro sinal de conteúdo motivacional. Quase toda a orientação genérica de "como viralizar no LinkedIn" foi escrita para vender curso de marketing e é ativamente prejudicial para você. O que segue assume o oposto: você quer ser respeitado por trinta pessoas certas, não aplaudido por três mil erradas.

---

## 1. A estrutura de um post

Todo post tem três partes, mesmo quando você não pensou nelas:

| Parte | Função | Tamanho típico |
|---|---|---|
| Hook | Fazer a pessoa clicar em "ver mais" | 1 a 3 linhas |
| Desenvolvimento | Entregar o que o hook prometeu | a maior parte do texto |
| Fechamento | Deixar um resíduo — ideia, pergunta, convite | 1 a 3 linhas |

### O corte do "ver mais"

O LinkedIn trunca o post. Onde exatamente o corte cai ninguém de fora sabe: varia entre desktop e mobile, com o tamanho da tela, e muda com testes que a plataforma roda sem avisar. A ordem de grandeza é **uma a duas linhas, algo na casa de uma centena e meia de caracteres no mobile** — que é onde a maioria lê. Quebras de linha contam. Um post que começa com três linhas curtas separadas por linha em branco gasta o orçamento visível mais rápido do que um parágrafo denso.

A consequência prática independe do número exato: escreva como se você tivesse **uma frase**. Se o seu hook só funciona com trezentos caracteres, ele não funciona.

Como testar sem publicar: escreva o rascunho, corte a primeira frase e leia isoladamente. Se essa fatia sozinha não dá vontade de continuar, o post está morto e nada no corpo vai salvá-lo. O outro teste, mais honesto: abra o editor de post do próprio LinkedIn, cole o texto, e olhe a pré-visualização no celular antes de publicar. Leva trinta segundos e evita o erro mais caro.

Um erro comum: gastar a primeira linha com contexto administrativo.

```
Ontem eu estava trabalhando em um projeto no trabalho e aconteceu uma coisa
interessante que eu queria compartilhar com vocês...
```

Todo o espaço visível consumido e nada foi dito. O leitor não sabe se é sobre Postgres ou sobre um churrasco. Compare:

```
Um índice que eu criei pra "melhorar performance" deixou a query 40x mais lenta.
```

Mesma história. A segunda versão já entregou a tensão.

### A regra da linha que ganha a próxima

Essa é a única regra estrutural que importa de verdade. **Cada linha existe para fazer a pessoa ler a próxima.** A primeira linha ganha a segunda; a segunda ganha a terceira. No momento em que uma linha não faz esse trabalho, o leitor sai — e ele sai silenciosamente, sem te avisar.

Isso tem uma consequência prática brutal: a maior parte da edição de um post é **deletar**. Não é reescrever bonito, é cortar a linha que só estava ali porque você a escreveu.

---

## 2. O hook: 15 padrões que funcionam

Cada padrão abaixo vem com um exemplo escrito de verdade, no contexto de conteúdo técnico.

| # | Padrão | Exemplo real |
|---|---|---|
| 1 | **Afirmação contraintuitiva** — contraria o senso comum e você consegue defender | Migramos de microserviços de volta pra um monólito. A latência p99 caiu 60%. |
| 2 | **Número específico** — redondo soa inventado, quebrado soa medido | Nosso build de CI levava 23 minutos. Hoje leva 4min12s. Não trocamos de máquina. |
| 3 | **Cena concreta** — coloca o leitor num lugar e num momento | 3h47 da manhã, PagerDuty tocando, e o gráfico de conexões do Postgres era uma linha reta no teto. |
| 4 | **Confissão de erro** — erro real, custo real; não "meu defeito é ser perfeccionista" | Eu derrubei a produção por 18 minutos com um `DELETE` sem `WHERE`. Em uma sexta-feira. |
| 5 | **Resultado antes da história** — conclusão primeiro, o "como" vira isca | Cortei 70% da conta de AWS do time em dois meses. Nenhuma das mudanças foi tecnicamente difícil. |
| 6 | **Tensão narrativa** — um conflito ainda não resolvido | O bug só acontecia em produção. Só às terças. Só depois das 14h. |
| 7 | **Pergunta genuína** — você não sabe a resposta e quer discutir | Alguém aqui conseguiu fazer code review assíncrono funcionar em time em 3 fusos? Porque eu não consegui. |
| 8 | **Correção de si mesmo** — revisão de crença é rara e valiosa | Há dois anos eu escrevi aqui que ORM era desnecessário. Eu estava errado, e sei exatamente onde. |
| 9 | **Comparação direta** — duas coisas, um critério | Go e Node resolvem o mesmo problema no meu time. A diferença que pesou não foi performance. |
| 10 | **O detalhe que ninguém nota** — especificidade que prova que você esteve lá | `SELECT count(*)` no Postgres não é O(1). Se isso te surpreende, temos o que conversar. |
| 11 | **A regra que você quebrou** — anti-dogma com contexto | A gente não escreve teste unitário pro service layer. É deliberado, e o time está melhor assim. |
| 12 | **Trecho de conversa** — diálogo curto | — Por que essa query tem um `ORDER BY` que ninguém usa? — Ela não funciona sem. Levei três dias pra entender que a resposta estava certa. |
| 13 | **Antes e depois em uma linha** — contraste comprimido | Deploy antes: 40 minutos, dois humanos, uma planilha. Deploy hoje: `git push`. |
| 14 | **A pergunta de entrevista que te pegou** — vulnerabilidade útil | Numa entrevista pra uma vaga em Berlim me perguntaram como eu debugaria um memory leak em produção sem acesso ao servidor. Eu travei. |
| 15 | **O custo real de uma decisão** — dinheiro, tempo ou pessoas | Manter aquele serviço legado custou 11 meses de trabalho de dois engenheiros. Foi a decisão certa. |

### Hooks queimados

Estes sinalizam, com precisão quase perfeita, um post que não vale a leitura. Público técnico já aprendeu a filtrá-los.

| Hook queimado | Por que morre |
|---|---|
| "Vou ser sincero:" | Implica que o resto do seu conteúdo não é. E o que vem depois nunca é sincero. |
| "Ninguém fala sobre isso." | Sempre falam. É verificável em dez segundos e você acabou de mentir. |
| "Isso mudou minha vida." | Linguagem de coach. Some qualquer credibilidade técnica. |
| "Você está fazendo X errado." | Presunção sobre alguém que você não conhece. Gera defensiva, não leitura. |
| "Bora falar sobre..." / "Vamos combinar que..." | Zero informação. Gasta o orçamento visível com aquecimento. |
| "Uma reflexão." | Anuncia que vem opinião vaga. |
| "Depois de 10 anos na área, aprendi que..." | Apelo à senioridade em vez de ao argumento. |
| Pergunta retórica vazia: "Você já parou pra pensar no impacto da cultura no seu time?" | Não é pergunta, é preâmbulo. Ninguém responde. |
| "🚨 ATENÇÃO 🚨" | Sinaliza spam. |
| "Recebi uma mensagem de um mentorado e resolvi compartilhar" | Formato de guru. Quase sempre a história é inventada ou remontada. |

O padrão comum entre eles: **prometem sem entregar nada na própria frase**. Um bom hook já contém informação. Um hook queimado só contém a promessa de informação.

### O tom de guru, e por que ele te custa a vaga

Existe um dialeto específico do LinkedIn brasileiro: frases curtas em linhas separadas, sabedoria genérica, história com moral no fim, o ponto final dramático. Algo como:

```
Ele não tinha o currículo.

Não tinha o inglês.

Não tinha o networking.

Mas tinha algo que ninguém tem.

Vontade.

E isso muda tudo.
```

Esse registro provavelmente performa bem em alcance bruto — é a inferência razoável, dado que ele explora tempo de permanência e reação emocional rápida (`algoritmo-e-metricas.md` trata o que se pode e o que não se pode afirmar sobre distribuição). Negar que funciona seria desonesto. O argumento contra ele não é que não funciona: é que **a assimetria é ruim**.

O upside é alcance junto a pessoas que não decidem sua contratação. O downside é desqualificação silenciosa junto às que decidem — staff engineers, tech leads, engineering managers, fundadores técnicos têm reação treinada e negativa a esse registro, não neutra. E essa classificação não vem com feedback: a pessoa simplesmente não te chama. O hiring manager de uma empresa europeia que abre o seu perfil e vê três posts assim fecha a aba. Você está competindo onde o sinal de qualidade é *precisão*, e o feed do seu perfil é o seu portfólio de pensamento.

A variante mais cara é o guru propriamente dito: o dev com quatro anos de carreira ensinando "como conquistar a vaga dos seus sonhos", tratando a própria trajetória como sistema replicável. Além de raso, denuncia falta de calibragem — exatamente a característica que mais assusta quem contrata sênior.

E o mal-entendido que trava muita gente: **personalidade não está no formato, está na especificidade e no julgamento.** Você pode ser engraçado, ácido, opinativo, informal, pessoal. Nada disso é cringe. Cringe é imitar um formato para colher reação quando a substância não sustenta. "E foi aí que eu entendi tudo" vira "levei duas semanas para entender e ainda não tenho certeza"; a frase de uma palavra solta vira frase curta mas completa; a abertura emocional vira o sintoma técnico na primeira linha; a humildade declarada ("humilde em compartilhar") vira humildade demonstrada, admitindo o que você não sabe.

---

## 3. Ritmo, formatação e o visual do texto

**Parágrafos de uma a três linhas**, com **linha em branco entre eles, sempre.** Bloco denso no mobile parece trabalho, e o leitor decide se lê pela *forma* antes de ler o conteúdo. A linha em branco é o único recurso de respiração que o LinkedIn te dá de graça.

**Listas ajudam quando os itens são paralelos e concretos.** Três causas de um incidente, quatro trade-offs de uma decisão, os passos de uma migration. Listas viram apresentação de slides sem conteúdo quando cada item é uma frase-de-efeito solta:

```
Consistência.
Disciplina.
Foco.
Resiliência.
```

Isso não é lista, é decoração. Teste simples: se os itens da lista pudessem ser embaralhados sem perda nenhuma de sentido, provavelmente eles não estão dizendo nada.

**Negrito e itálico via caracteres Unicode: não use.** O LinkedIn não tem formatação rica no post, e existem ferramentas que substituem letras normais por caracteres matemáticos Unicode (𝗕𝗼𝗹𝗱, 𝘐𝘵𝘢𝘭𝘪𝘤). Três problemas: leitores de tela leem letra por letra, pronunciam "mathematical bold capital B" ou simplesmente pulam, e você tornou seu texto inacessível por um efeito visual; a busca do LinkedIn não indexa esses caracteres, então escrever "𝗞𝘂𝗯𝗲𝗿𝗻𝗲𝘁𝗲𝘀" faz você desaparecer de quem busca Kubernetes; e sinaliza uso de ferramenta de automação, que é exatamente o sinal que você não quer emitir. Se precisa de ênfase, use estrutura — coloque a frase importante sozinha numa linha.

**Emoji: a posição defensável é não usar.** O argumento não é estético, é de sinal. No contexto de engenharia sênior internacional, emoji no corpo de um post técnico correlaciona com conteúdo raso — não porque emoji seja ruim, mas porque quem escreve conteúdo profundo raramente sente necessidade de decorar. Emoji como bullet (🔹 🚀 ✅) é o caso pior: reproduz a estética de post gerado por ferramenta, e leitores de tela anunciam cada um deles ("foguete", "marca de verificação") antes de cada item.

A exceção razoável: uma seta ou um emoji em uma vaga que você está divulgando, ou em post de celebração de time. Em post técnico, zero.

---

## 4. Tamanho: curto ou longo

O LinkedIn permite um post na casa de três mil caracteres — o número exato muda de tempos em tempos e não importa, porque não é uma meta.

| Tamanho | Caracteres | Quando funciona |
|---|---|---|
| Curto | 200 a 600 | Uma ideia só, afiada. Observação técnica, opinião, número interessante. Alto retorno por esforço. |
| Médio | 600 a 1.400 | O padrão útil. Uma história com começo, meio e fim, ou um argumento com duas ou três evidências. |
| Longo | ~1.400 até o limite | Post-mortem, decisão de arquitetura com contexto, história de carreira densa. Só sobrevive se cada linha ganhar a próxima. |

O post longo é a forma mais arriscada. Não porque as pessoas não leiam textos longos — leem — mas porque um post longo tem trinta oportunidades de perder o leitor em vez de cinco. A regra: **em post longo, você não tem direito a nenhuma linha de aquecimento**. Nenhum "antes de mais nada", nenhum "vale contextualizar que", nenhum parágrafo de transição. Se você não consegue defender a existência de cada linha, corte-a e o post fica médio — e melhor.

Post curto é subestimado. Uma observação técnica precisa de 400 caracteres frequentemente gera mais conversa qualificada do que um ensaio, porque é fácil de ler inteiro e fácil de responder.

---

## 5. Fechamento e CTA

O fechamento tem uma função: deixar o leitor com alguma coisa. Uma ideia reformulada, uma pergunta que ele vai carregar, um convite real de conversa.

**CTA que serve** — abre espaço genuíno, é específico, e você realmente quer a resposta: "Qual foi o pior incidente que você já causou? O meu ainda é esse." / "Se alguém aqui já rodou isso em escala maior, quero muito saber o que quebrou." / "Estou curioso se isso é consenso ou se é só o meu contexto." / "Se você fez a escolha oposta, me conta o que pesou."

**CTA mendigo** — pede engajamento pelo engajamento: "Comenta AQUI embaixo!" / "Compartilha se você concorda!" / "Marca aquele dev que precisa ler isso 👇" / "Curtiu? Me segue pra mais conteúdo assim." / "Deixa um 🔥 se você já passou por isso."

Por que sai pela culatra com público técnico especificamente: engenheiros leem CTA explícito como *manipulação de métrica*, porque é. O pedido revela que o objetivo do post era o número, não a ideia — e isso reclassifica retroativamente tudo que veio antes como marketing. Você perde exatamente o leitor que valia a pena, que é aquele com senso de bullshit calibrado.

Há também o custo de status. Pedir compartilhamento é pedir favor. Um sênior que você quer que te indique não é atraído por alguém pedindo favor a estranhos.

**Fechamento sem CTA nenhum é legítimo e frequentemente superior.** Terminar com a última linha do argumento, ponto final, funciona. O post não precisa de porteiro.

---

## 6. Os formatos, um a um

### 6.1 Post de texto puro

O formato padrão e o que deve responder pela grande maioria dos seus posts. Sem dependência de design, sem produção, e é o formato onde a escrita é julgada diretamente.

**Quando usar:** história, opinião, decisão técnica, observação, pergunta. Praticamente tudo.

**Como montar:** hook na primeira frase, antes do corte do "ver mais", desenvolvimento em parágrafos de 1 a 3 linhas, fechamento. Sem títulos, sem numeração de seção, sem markdown (o LinkedIn não renderiza).

**Exemplo completo — português:**

```
Passei três dias caçando um vazamento de memória que não existia.

O gráfico do heap do nosso serviço em Node subia até 1.8GB e o pod era morto
pelo OOMKiller. Todo dia, sempre entre 15h e 16h. Perfeito demais pra ser
coincidência.

Tentei o óbvio primeiro: heap snapshot, comparação entre dois pontos no tempo,
caça a closure segurando referência. Encontrei umas três coisas feias, corrigi
todas. O gráfico continuou igual.

No terceiro dia eu olhei o limite de memória do container. 2GB. E o
--max-old-space-size do Node? Não estava setado. Ou seja: o V8 estava usando o
default dele, calculado a partir da memória da máquina host, não do cgroup do
container. Ele achava que tinha muito mais RAM disponível do que o pod tinha
de fato.

Então o garbage collector não estava com pressa. Ele deixava o heap crescer
tranquilo até um limite que nunca ia chegar, porque o Kubernetes matava o pod
antes.

A correção foi uma linha no manifesto.

O que ficou pra mim não foi o detalhe do V8. Foi que eu passei dois dias
inteiros investigando o código da aplicação sem nunca perguntar se o problema
estava na fronteira entre a aplicação e o ambiente. Meu modelo mental parava
no package.json.

Hoje, quando algo "só acontece em produção", a primeira pergunta que eu faço é:
o que produção sabe que o meu laptop não sabe?
```

Isso tem hook (contraintuitivo: o vazamento não existia), desenvolvimento com detalhe técnico verificável, e um fechamento que generaliza sem virar sermão. Sem CTA, e não precisa.

**Exemplo completo — inglês:**

```
We deleted 40% of our test suite last quarter. Bug escape rate went down.

The suite had 3,100 tests and took 19 minutes. Most engineers stopped reading
the failures — they'd rerun the job and hope. A red build had stopped meaning
anything, which is the worst state a test suite can be in.

So we did an audit. Three questions per test:
- Has this test ever failed for a real bug?
- Does it fail for reasons unrelated to what it claims to test?
- If I delete it, what would I stop knowing?

About 1,200 tests failed all three. Most were unit tests over service classes
that only asserted that mocks were called with the arguments we had just
passed in. They tested the wiring, not the behavior. When we changed the
wiring, they broke; when we broke the behavior, they passed.

We deleted them and put the effort into 40 integration tests that hit a real
Postgres in a container.

Suite is now 6 minutes. People read the failures again. And in the two
quarters since, we've caught four bugs in CI that the old suite would have
waved through.

Test count is not a quality metric. It never was, and I'd been quietly
treating it as one for years.
```

Note o que o exemplo em inglês *não* faz: não usa "In today's fast-paced world", não abre com "I want to share", não termina com "Thoughts?". Vai direto.

### 6.2 Post com imagem única

**Quando usar:** quando a imagem carrega informação que o texto não carregaria bem — um gráfico de latência antes e depois, um diagrama de arquitetura, um trecho de código curto, uma captura de terminal.

**O que funciona visualmente:** gráfico com um eixo legível e um ponto óbvio — latência p99 com uma queda vertical marcada; se o leitor precisa estudar a imagem, ela falhou. Diagrama simples, no máximo seis caixas: Excalidraw ou algo com aparência de desenho bate diagrama corporativo, porque parece pensamento e não slide de venda. Screenshot de código (veja a seção 7). Foto real de contexto — whiteboard, tela do monitor às 4h, o post-it com a hipótese; autêntico bate produzido.

**O que não funciona:** stock photo de pessoas apertando as mãos, imagem gerada por IA de "engenharia de software", citação em cima de fundo gradiente, infográfico com dez blocos de texto.

**Como montar:** a imagem não substitui o texto. Escreva o post inteiro como se não houvesse imagem, e depois adicione a imagem como evidência. O erro comum é postar um gráfico com a legenda "olha isso 👀" e esperar que o gráfico se explique.

Formato: quadrado (1200x1200) ou retrato (1080x1350) ocupam mais área vertical no feed mobile do que paisagem.

### 6.3 Carrossel / documento PDF

Você sobe um PDF e o LinkedIn renderiza como carrossel deslizável. Tem fama de alcançar bem, e a explicação plausível é o tempo de permanência alto — mas isso é inferência, não mecanismo publicado; `algoritmo-e-metricas.md` é o dono do assunto. Escolha o formato pelo conteúdo, não pela expectativa de distribuição.

**Quando usar:** conteúdo que é genuinamente sequencial — passos de uma migração, evolução de uma arquitetura em quatro estágios, um checklist de code review, a anatomia de um post-mortem. Se o conteúdo não é sequencial, o carrossel é um post de texto quebrado em pedaços para explorar o algoritmo, e lê-se como tal.

**Estrutura slide a slide:**

| Slide | Conteúdo |
|---|---|
| 1 | O hook. Uma frase, fonte grande. É a capa e é o que aparece no feed. |
| 2 | O contexto/problema em 2 a 3 linhas. Sem introdução. |
| 3 a N-2 | Um ponto por slide. Um. |
| N-1 | A síntese ou o resultado. |
| N | Fechamento — sem "me siga", opcionalmente seu nome e onde falar com você. |

**Quantidade:** 7 a 12 slides. Abaixo de 6 o formato não se justifica; acima de 15 as pessoas abandonam no meio e você não ganha nada.

**Texto por slide:** 15 a 40 palavras. Um slide de carrossel não é um slide de apresentação com você falando por cima — ele precisa ser autossuficiente, mas curto. Fonte mínima 24pt equivalente; a maioria vai ler num retângulo de 5cm.

**Design:** fundo sólido, alto contraste, uma fonte, um acento de cor. Consistência entre slides importa mais que beleza.

**Acessibilidade:** PDF de imagem não tem texto selecionável e é opaco para leitor de tela. Coloque no texto do post uma síntese real do conteúdo — não "arrasta pro lado 👉", mas os três pontos principais em prosa. Isso também serve para quem não vai abrir.

**Exemplo de esqueleto preenchido** — carrossel "Como a gente migrou 400GB de Postgres com 90 segundos de downtime":

1. `Migramos 400GB de Postgres entre regiões. Downtime: 90 segundos.`
2. `Estávamos em us-east-1. O time e 80% dos usuários, na Europa. 120ms de latência em toda query.`
3. `Opção descartada: dump e restore. 400GB = ~6h de janela. Inaceitável.`
4. `O que usamos: replicação lógica. Publisher na origem, subscriber no destino, replicação contínua por 5 dias.`
5. `Armadilha 1: replicação lógica não replica sequences. Tivemos que sincronizar à mão no corte.`
6. `Armadilha 2: nem tabela sem primary key. Achamos 3. Duas viraram lixo, uma ganhou PK.`
7. `Armadilha 3: DDL não é replicado. Congelamos migrations por 5 dias. Foi a parte politicamente mais difícil.`
8. `O corte: read-only na aplicação → esperar lag zerar → sincronizar sequences → trocar a connection string → soltar.`
9. `90 segundos. 85 deles foram esperando o healthcheck do pool reconhecer o novo host.`
10. `O que eu faria diferente: ensaiar o corte 3 vezes com dados de produção, não 1. A gente descobriu o problema das sequences no ensaio único, por sorte.`

### 6.4 Vídeo curto

**Quando usar:** demonstração de algo em movimento (uma ferramenta, um fluxo de debug), ou quando o rosto e a voz adicionam algo — sotaque e naturalidade em inglês, por exemplo, o que é diretamente relevante para vaga internacional.

**Duração:** 30 a 90 segundos; quanto mais longo, mais gente abandona no meio. **Roteiro:** escreva. Vídeo improvisado tem 15 segundos de "então, é... eu queria falar sobre" e você perdeu todo mundo. Estrutura: **0 a 3s** a afirmação, sem "oi pessoal" ("esse comando resolveu um problema que eu debuguei por dois dias"); **3 a 15s** o contexto mínimo; **15 a 60s** o conteúdo, uma coisa só; **final** uma frase de fechamento, não "se inscreva".

**Legenda é obrigatória**, por três motivos em ordem de peso. Primeiro: a maioria assiste sem som, rolando o feed em contexto público — sem legenda, seu vídeo é uma pessoa mexendo a boca. Segundo: acessibilidade para surdos e pessoas com deficiência auditiva, o que não é opcional. Terceiro, e específico do seu caso: você é brasileiro falando inglês para público internacional, e legenda elimina inteiramente o atrito de sotaque, que é real mesmo com inglês excelente. Sem legenda, você está pedindo pro recrutador fazer esforço.

A legenda automática do LinkedIn erra bastante com termo técnico e sotaque. Revise o SRT — "Kubernetes" virando "cooper netties" na sua tela é ruim. Formato vertical ou quadrado, e grave com fone com microfone: áudio ruim mata mais vídeo do que imagem ruim.

### 6.5 Post com link externo

**O problema:** o LinkedIn quer manter as pessoas no LinkedIn, então é inferência razoável que post com link no corpo seja distribuído menos que post de texto puro. A direção é plausível; a magnitude é desconhecida, e qualquer porcentagem exata que alguém te der é inventada. `algoritmo-e-metricas.md` desenvolve isso.

**As alternativas:**

| Abordagem | Prós | Contras |
|---|---|---|
| Link no corpo do post | Honesto, um clique, preview visual | Alcance provavelmente menor |
| Link no primeiro comentário | Alcance do post preservado | Fricção extra; o comentário se perde quando outros comentários sobem; parece jogo de algoritmo (porque é) |
| Link no comentário + "link nos comentários" no post | Sinaliza claramente | Anuncia que você está driblando a plataforma |
| Sem link, conteúdo autossuficiente no post | Melhor experiência, melhor alcance | Você não leva tráfego pra lugar nenhum |

**A escolha defensável:** escreva o post de modo que ele tenha valor completo sozinho, e ponha o link no corpo se ele existir. Você perde alcance e ganha respeito. A tática do link no comentário é transparente para qualquer pessoa que use LinkedIn há mais de seis meses e economiza pouco.

Se o link é o ponto inteiro (você lançou uma lib, escreveu um artigo longo), então aceite o custo e ponha no post. Um post cujo valor depende de um clique não deveria fingir que não depende.

### 6.6 Artigo nativo e newsletter

**Artigo do LinkedIn:** editor com títulos, imagens e formatação; provavelmente distribuído bem menos que post — o artigo depende de dois cliques, e nada indica que o feed o trate como conteúdo nativo —, e fica indexado no seu perfil para sempre. **Newsletter:** artigos com assinatura, onde assinantes recebem notificação e e-mail — essa é uma vantagem real e a única razão forte para usar o formato.

**Por que quase sempre o post vence:** o post aparece no feed enquanto o artigo depende de alguém clicar duas vezes; um post de 2.000 caracteres bem escrito é lido inteiro por mais gente do que um artigo de 1.500 palavras; e você escreve mais rápido, publica mais e itera mais.

**Quando o artigo vale:** o conteúdo estoura o limite do post e não dá pra cortar (post-mortem técnico completo, com blocos de código); você quer algo permanentemente linkável do perfil, funcionando como amostra de escrita para candidatura; ou é newsletter com cadência real (quinzenal, mesmo dia) e recorte específico — "Postgres em produção", não "reflexões sobre tech".

Newsletter abandonada é pior que newsletter inexistente: a última edição de oito meses atrás fica visível no seu perfil. Se você não vai manter por doze meses, não comece.

Padrão que funciona: escreva o artigo, e publique um post de texto puro que conte a parte mais forte do artigo por inteiro, com o link no fim. O post entrega valor mesmo sem o clique.

### 6.7 Repost com comentário

Repost sem comentário é praticamente inútil — não diz nada sobre você, e não há razão para o feed tratá-lo como conteúdo seu.

**Como fazer render:** seu comentário precisa ser um post pequeno, autossuficiente, com opinião. O conteúdo original é o ponto de partida, não a substância.

Ruim:
```
Excelente conteúdo! Vale muito a leitura 👏
```

Bom:
```
Isso bate exatamente com o que a gente viu ano passado, com uma diferença
importante.

O texto argumenta que feature flags removem a necessidade de branch de longa
duração. Verdade. Mas o custo que ninguém menciona: seis meses depois a gente
tinha 40 flags ativas e nenhum processo pra removê-las. O código virou uma
árvore de decisão que ninguém conseguia ler.

Hoje toda flag nasce com data de morte no nome: `checkout_v2_expira_2026_03`.
Quem passa da data quebra o build.

Vale muito a leitura pelo resto do argumento, que eu acho correto.
```

O segundo comentário resolve algo: adiciona informação de campo, discorda parcialmente e propõe uma prática concreta. Isso é conteúdo próprio usando o post alheio como trampolim — e é legítimo, desde que você credite e não distorça.

Se você não tem nada a acrescentar, comente no post original em vez de repostar. Um bom comentário no post de alguém com audiência frequentemente te dá mais visibilidade qualificada que um post seu.

### 6.8 Enquete

**Uso legítimo:** você tem uma dúvida real sobre distribuição de práticas, e o resultado vai informar algo — seu, do seu time, de um post futuro.

```
Qual o seu ambiente de teste de integração?

○ Testcontainers
○ Banco compartilhado de dev
○ Docker Compose local
○ Mocks — sem banco real
```

Isso funciona: quatro opções mutuamente exclusivas, tópico de discussão real, os comentários provavelmente valem mais que os votos.

**O abuso:** enquete cuja resposta óbvia é uma só ("Documentação é importante? Sim / Muito"); enquete como isca disfarçada ("Você quer que eu escreva sobre X?"); enquete falsamente polêmica pra gerar briga ("Tabs ou spaces?"), que traz volume e nenhuma pessoa que importa; e enquete semanal como estratégia de presença, que vira ruído e sinaliza que você não tem o que dizer.

Limite razoável: uma enquete a cada dez ou quinze posts, e só quando você quer mesmo saber.

---

## 7. Post técnico sem virar tutorial chato

A diferença entre um post técnico que as pessoas leem e um que ninguém lê raramente é o assunto. É que o segundo tenta *ensinar* e o primeiro *conta o que aconteceu*.

Tutorial no LinkedIn compete com documentação, blog post e Stack Overflow — e perde em todos. O que o LinkedIn oferece que esses não oferecem é a **experiência de primeira mão de uma pessoa identificável**. Escreva isso.

| Em vez de | Escreva |
|---|---|
| "Como criar índices no Postgres" | "O índice que eu criei deixou a query 40x mais lenta. Aqui está por quê." |
| "5 boas práticas de code review" | "Mudei uma coisa no meu code review e o tempo até merge caiu pela metade." |
| "Introdução a Kubernetes probes" | "Nosso rolling deploy derrubava 2% das requests. Era o readiness probe." |

### Mostrar código no LinkedIn

Não cole código como texto. Sem fonte monoespaçada e sem preservação de indentação, ele fica ilegível e é truncado.

Screenshot, com regras:

- **Tema claro.** Contraintuitivo para quem programa no escuro, mas no feed do celular sob luz do dia o tema escuro perde muito contraste percebido, e a miniatura fica um retângulo preto.
- **Máximo 15 linhas.** Idealmente 6 a 10. O ponto é o *trecho*, não o arquivo.
- **Fonte grande.** Aumente para 18 a 20pt antes do print. O que parece exagerado na sua tela de 27" fica no limite do legível no celular.
- **Sem a IDE inteira.** Corte a barra lateral, o terminal, as abas. Só o código.
- **Destaque a linha que importa** — uma seta, um retângulo, ou um comentário `// aqui`.
- **Descreva o código no texto do post.** Screenshot é inacessível a leitor de tela. Uma frase resolve: "a linha crítica é o `SELECT ... FOR UPDATE SKIP LOCKED` no meio do loop".

Alternativa boa: em vez de código, mostre o *diff* ou o *antes e depois* em duas linhas de prosa. "Trocamos `findMany` seguido de um loop de `update` por um único `UPDATE ... WHERE id = ANY($1)`. 340 queries viraram 1." Muitas vezes isso comunica melhor que a imagem.

### Uma decisão de arquitetura em 200 palavras

Fórmula que funciona: **contexto → restrição → alternativas → escolha → custo aceito**.

```
A gente precisava processar webhooks de um parceiro que manda picos de 5 mil
eventos em 30 segundos, algumas vezes por dia, e nada no resto do tempo.

Restrição: o parceiro dá timeout de 3 segundos e não faz retry. Se a gente
demorar, o evento se perde e não volta.

Três opções na mesa:
- Processar síncrono e escalar a API. Caro e ainda arriscado no pico.
- Fila gerenciada (SQS). Resolve, mas é mais um serviço de infra e mais um
  ponto de configuração de IAM que ninguém do time domina.
- Gravar o payload cru no Postgres e processar com worker lendo com
  SKIP LOCKED.

Escolhemos a terceira. O endpoint faz um INSERT e devolve 200 em ~8ms. O
worker processa no ritmo dele.

O custo que aceitamos conscientemente: isso não escala infinitamente. Numa
ordem de grandeza acima do volume atual, a tabela de fila vira gargalo de
vacuum e a gente vai ter que migrar mesmo.

A gente escolheu a solução que o time inteiro consegue debugar às 3h da manhã,
em vez da que escala pra um volume que talvez nunca chegue.
```

Duzentas e poucas palavras, e um engenheiro sênior lendo isso aprende algo sobre você: você pensa em restrição real, considera alternativas, e nomeia o custo em vez de fingir que não existe. Isso é um sinal de contratação muito mais forte que uma lista de tecnologias.

### Transformar um bug em narrativa

Um bug já tem estrutura de história: sintoma → hipótese errada → descoberta → causa raiz → o que ficou.

Três erros comuns. **Contar em ordem cronológica completa:** você não precisa das dez horas, precisa da hipótese errada mais interessante e da descoberta. **Esconder o final até o fim:** suspense funciona em série de TV, não em feed — frequentemente é melhor entregar a causa raiz cedo e usar o corpo para explicar *como você chegou lá*. **Terminar no fix:** o fix é a parte menos interessante; o que interessa é o que o bug revelou sobre o modelo mental errado que você tinha.

---

## 8. Escrever em inglês sendo brasileiro

Os erros recorrentes do brasileiro escrevendo inglês profissional — formalidade excessiva herdada do português corporativo, falsos cognatos ("actually", "pretend"), imperativo que soa grosseiro, tradução literal de preposição — estão desenvolvidos em `networking-e-mensagens.md`, com as tabelas e os pares antes/depois. Valem igual aqui.

O que muda no post e não na mensagem direta: o registro é **público e permanente**, então o erro fica exposto a todo mundo que abrir seu perfil, não a um destinatário; o post tem **ritmo**, e frase curta com verbo forte é o que sustenta a regra da linha que ganha a próxima, enquanto a frase formal longa a quebra; e o post é **sua voz**, não um pedido — não tente soar americano, tente soar como você em inglês claro.

Duas regras específicas de post: expressão idiomática de que você não tem certeza, corte — o erro em idiom é muito mais visível para nativo do que uma preposição trocada. E ferramenta de correção gramatical, use; ferramenta que "melhora o tom" e reescreve, não — a textura de texto gerado é reconhecível justamente para o leitor que você quer impressionar.

---

## 9. Comentários

O que acontece nos comentários frequentemente vale mais que o post. É lá que a conversa fica de fato pública, é lá que um sênior te vê pensando em tempo real, e é o único lugar onde alguém pode discordar de você.

**Responda a todos.** Nas primeiras 24 horas, todos. Inclusive "muito bom!" — responda com algo além de "obrigado": pegue um pedaço do post e adicione uma linha. Isso mantém a conversa viva e é educado.

**O comentário como continuação.** Deixe deliberadamente algo de fora do post e coloque nos comentários. Não como isca, mas porque não cabia: o detalhe da configuração, o link para a issue no GitHub, a exceção do caso raro. Isso dá aos comentários uma razão de existir.

**Discordância técnica.** É a melhor coisa que pode acontecer com um post seu, e a maioria das pessoas administra mal.

- Se a pessoa tem razão: diga que ela tem razão, explicitamente, e edite o post ou adicione uma correção em comentário. "Você está certo, eu simplifiquei demais aí — `SKIP LOCKED` não resolve o caso de reentrega, e isso importa." Admitir erro em público é o comportamento mais raro e mais valorizado no LinkedIn técnico.
- Se a discordância é de contexto (funciona na escala dela, não na sua): nomeie o contexto em vez de brigar. "Faz total sentido no volume que você descreve. No nosso caso o gargalo apareceu porque..."
- Se você acha que a pessoa está errada: peça o dado. "Interessante — você mediu isso? Eu vi o oposto nesse benchmark aqui." Perguntar coloca a discussão em terreno técnico.

**Troll.** Discordância agressiva contém um argumento; troll contém só desprezo ("post de júnior", "isso é básico", "ninguém faz mais assim"). Regra: **uma resposta, curta e sem defensiva, ou nenhuma.** Nunca duas — se a réplica dele continuar sem argumento, pare, porque cada troca adicional sobe o post no feed e transforma sua timeline em briga. Uma resposta que funciona: "Pode ser básico pra você, e ainda assim eu quebrei a produção com isso. Se você tem uma abordagem melhor, escreve aí que eu leio." Ocultar comentário é ferramenta legítima para insulto puro — use sem culpa e sem anunciar.

**E o mais importante:** não terceirize comentário para IA. Um comentário genérico e simétrico é reconhecível, e a pessoa que recebeu percebe que você não leu. Isso destrói mais relacionamento do que o silêncio.

---

## 10. Vinte primeiras linhas fortes

**Português:**

1. `Um índice que eu criei pra "melhorar performance" deixou a query 40x mais lenta.`
2. `A gente rodou 8 meses sem testes de integração. Não recomendo, mas aprendi coisas.`
3. `O incidente durou 4 horas. A causa raiz tinha 2 caracteres.`
4. `Reprovei em uma entrevista por não saber explicar o que acontece quando você digita uma URL. Depois de 9 anos de carreira.`
5. `Nosso "microserviço" tinha 47 endpoints e um banco compartilhado com outros três serviços.`
6. `Passei três dias caçando um vazamento de memória que não existia.`
7. `Recusei uma proposta 40% maior. Ainda acho que foi certo, e agora sei por quê.`
8. `Kubernetes não era o problema. O problema era que a gente não sabia o que estava rodando.`
9. `Deletamos 1.200 testes. A taxa de bug em produção caiu.`
10. `O código mais importante que escrevi no ano passado tinha 6 linhas e apagou um serviço inteiro.`

**Inglês:**

11. `We deleted 40% of our test suite last quarter. Bug escape rate went down.`
12. `Our Postgres CPU sat at 95% for three weeks. The fix was one missing index — and finding it was not the hard part.`
13. `I've been running Kubernetes in production for a year and I still don't understand the scheduler.`
14. `The bug only happened in production. Only on Tuesdays. Only after 2pm.`
15. `I rewrote a Go service in Node. Latency got worse. We shipped it anyway, and it was the right call.`
16. `A four-hour outage taught me more about our system than six months of building it.`
17. `We moved from microservices back to a monolith. p99 latency dropped 60%.`
18. `Nobody on my team could explain what our retry logic actually did. Including the person who wrote it. Me.`
19. `The most expensive line of code I ever wrote was a SELECT * inside a loop.`
20. `I got rejected after the system design round. Here's the exact feedback they gave me, because I think it's useful.`

O que todas têm em comum: contêm informação, não anunciam informação. Nenhuma começa com "eu queria compartilhar".

---

## 11. Roteiro de revisão antes de publicar

Dez perguntas para o rascunho. Se três ou mais falharem, não publique — reescreva ou engavete.

1. **A primeira frase, sozinha, faria eu clicar em "ver mais"?** Leia isolado. Sem indulgência.
2. **Existe um número, um nome de tecnologia, ou um detalhe específico nas três primeiras linhas?** Abstração genérica não segura ninguém.
3. **Qual linha eu posso deletar sem perder nada?** Sempre existe pelo menos uma. Delete. Repita.
4. **Isso só eu poderia ter escrito?** Se qualquer pessoa com acesso ao Google escreveria igual, é conteúdo genérico e não constrói reputação.
5. **Eu aceitaria isso num code review de mim mesmo?** Ou seja: as afirmações técnicas são defensáveis? Se alguém pedir a fonte, eu tenho?
6. **Estou expondo alguém?** Empregador, ex-colega, cliente. Anonimize ou não publique. Post que fala mal de time anterior queima você, não eles.
7. **Tem tom de guru em algum lugar?** Sabedoria genérica, frase de efeito solta, moral no fim. Corte.
8. **O CTA é uma pergunta que eu realmente quero que respondam?** Se não é, corte o CTA inteiro.
9. **Eu leria isso de um estranho até o fim?** Honestamente. Não "é útil", mas "eu leria".
10. **Se essa for a única coisa que um hiring manager ler de mim, ela ajuda?** É o filtro final e o mais duro.

### Quando a resposta certa é não publicar

Não publique quando:

- **Você está com raiva.** Post escrito 40 minutos depois de uma reunião ruim vai parecer o que é. Escreva, salve, releia em dois dias. Na maioria das vezes você deleta.
- **O post é sobre uma empresa identificável de forma negativa.** O custo assimétrico é enorme: ganho de alcance temporário, risco de reputação permanente, e recrutador lê como "essa pessoa vai falar assim de nós".
- **Você não tem certeza da afirmação técnica.** Post técnico errado com muito alcance é a pior combinação possível. Verifique ou reformule como pergunta.
- **É só um humblebrag.** "Fiquei surpreso ao ser convidado para..." — todo mundo lê o que é. Se você quer anunciar uma conquista, anuncie diretamente e em uma linha; a falsa surpresa é o que irrita.
- **É a terceira vez na semana que você posta a mesma ideia com palavras diferentes.** Repetição é estratégia legítima em ciclos de meses, não de dias.
- **O post existe porque você "precisa manter consistência".** Consistência sem substância é ruído com cronograma. Semana sem post é melhor que post vazio — o feed do seu perfil é cumulativo, e cada post fraco dilui os fortes.
- **O conteúdo é uma opinião sobre algo que você nunca usou em produção.** Isso é detectável e caro.
- **Você usou IA para gerar o post inteiro e não reescreveu.** A textura é reconhecível: simetria excessiva, tríades, "não se trata apenas de X, mas de Y", zero detalhe específico. Usar IA para estruturar e criticar é útil; publicar a saída crua não.

---

## 12. Exercício de reescrita

### O rascunho ruim (completo)

```
🚀 A importância dos testes automatizados 🚀

Vou ser sincero: ninguém fala sobre isso, mas testes automatizados são
FUNDAMENTAIS para qualquer projeto de software de sucesso.

Ao longo da minha carreira, tive a oportunidade de trabalhar em diversos
projetos e com profissionais brilhantes, e aprendi que a qualidade não é
negociável.

Separei 5 motivos pelos quais você DEVE investir em testes:

✅ Confiança para refatorar
✅ Documentação viva do sistema
✅ Menos bugs em produção
✅ Deploy mais rápido
✅ Time mais tranquilo

No fim do dia, testar não é custo. É investimento. 💡

E você, já sofreu por não ter testes? Comenta AQUI embaixo! 👇

E se você concorda, compartilha com aquele dev que precisa ler isso!

#testes #qualidade #desenvolvimento #software #tecnologia #carreira #devs
#programacao #testesautomatizados #tdd
```

### A reescrita

```
A gente deletou 1.200 testes no trimestre passado. A taxa de bug em produção caiu.

A suíte tinha 3.100 testes e rodava em 19 minutos. Isso já era ruim. Mas o
problema real era outro: ninguém lia mais as falhas. Quando o build ficava
vermelho, a reação padrão era clicar em "rerun" e torcer. Build vermelho tinha
deixado de significar alguma coisa.

Fizemos uma auditoria. Três perguntas por teste:

- Esse teste já falhou por causa de um bug de verdade?
- Ele falha por motivos que não têm nada a ver com o que ele diz testar?
- Se eu deletar, o que eu deixo de saber?

Mil e duzentos testes responderam mal às três. A maioria era teste unitário de
service, com todos os colaboradores mockados, verificando que o mock foi
chamado com os argumentos que a gente tinha acabado de passar. Testavam a
fiação, não o comportamento. Quando a gente mexia na fiação, quebravam; quando
a gente quebrava o comportamento, passavam limpo.

Deletamos, e transformamos o esforço em 40 testes de integração subindo um
Postgres real em container.

A suíte hoje roda em 6 minutos. As pessoas voltaram a ler as falhas. E nos
dois trimestres desde então, o CI pegou quatro bugs que a suíte antiga teria
deixado passar.

Contagem de testes nunca foi métrica de qualidade. Eu tratava como se fosse, em
silêncio, há uns anos.

Se alguém aqui já fez essa faxina e deu errado, quero saber — a nossa deu certo
e eu ainda não sei quanto disso foi sorte.
```

### O que mudou, e por quê

| Mudança | Antes | Depois | Motivo |
|---|---|---|---|
| Hook | "A importância dos testes automatizados" + "Vou ser sincero: ninguém fala sobre isso" | "Deletamos 1.200 testes. A taxa de bug caiu." | O antes é um título de aula e dois hooks queimados empilhados. O depois é contraintuitivo, tem número específico e cabe no corte do "ver mais". |
| Especificidade | Zero números | 3.100 → 1.900 testes, 19min → 6min, 4 bugs | Números específicos são o principal sinal de que você esteve lá. Sem eles, o post é opinião de qualquer um. |
| Autoridade | "trabalhei com profissionais brilhantes" | O critério de auditoria em três perguntas | Autoridade emprestada (senioridade, colegas) vale menos que autoridade demonstrada (um método reproduzível). |
| Lista | 5 benefícios genéricos com ✅ | 3 perguntas operacionais da auditoria | A lista original é embaralhável sem perda — sinal de que não diz nada. A nova lista é uma ferramenta que o leitor pode usar amanhã. |
| Emoji | 🚀 💡 ✅ 👇 | nenhum | Ruído visual, prejudica leitor de tela, sinaliza conteúdo raso pro público-alvo. |
| Caixa alta | FUNDAMENTAIS, DEVE, AQUI | nenhuma | Grito. Substitui argumento por ênfase. |
| Fechamento | "testar não é custo, é investimento" | "contagem de testes nunca foi métrica de qualidade, e eu tratava como se fosse" | O antes é um chavão que ninguém discorda e por isso não informa. O depois é uma admissão de erro específica — memorável, e um sinal forte de senioridade. |
| CTA | "Comenta AQUI! Compartilha se concorda!" | "quero saber — a nossa deu certo e eu ainda não sei quanto disso foi sorte" | O antes pede favor e revela que a métrica era o objetivo. O depois é uma pergunta genuína, com uma admissão de incerteza que dá ao leitor algo real pra responder. |
| Hashtags | 10 genéricas | nenhuma (ou 2 no máximo) | Dez hashtags genéricas não trazem alcance relevante e sinalizam post de conteúdo. Se for usar, duas específicas. |
| Extensão | ~150 palavras de nada | ~280 palavras de história com evidência | O post ficou mais longo e mais rápido de ler, porque cada linha ganha a próxima. |

O ponto central da reescrita: o rascunho ruim tenta **convencer** de uma tese que ninguém contesta. A reescrita **conta o que aconteceu** e deixa a tese emergir. É a diferença entre alguém que fala sobre engenharia e alguém que faz engenharia — e é exatamente essa diferença que um hiring manager está tentando detectar quando abre seu perfil.
