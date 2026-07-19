# Da candidatura à oferta: o processo seletivo internacional para o dev brasileiro

Este arquivo começa onde o perfil termina. O LinkedIn otimizado gera visibilidade; visibilidade gera conversas; conversas geram processos. Mas a maioria dos devs brasileiros que chega à primeira conversa morre em algum ponto específico do funil — quase sempre pelo mesmo punhado de razões, corrigíveis, que ninguém corrige porque ninguém diz onde estão.

Escopo: vaga remota, empresa fora do Brasil, contratação como contractor (PJ) ou via EOR (Deel, Remote.com, Oyster, Velocity Global). Não é sobre relocation nem visto. Se o objetivo for mudar de país, quase tudo abaixo continua válido, mas a seção de knockout questions muda de sinal completamente.

Ressalva para o documento inteiro: todos os números são **ordem de grandeza**, tirados de padrões observados, não de estudo controlado. Taxa de resposta varia brutalmente por stack, senioridade, ano e humor do mercado. Use como direção relativa ("A converte muito mais que B"), nunca como meta absoluta.

## 1. Os quatro caminhos de entrada, e o que cada um vale

Há quatro formas de chegar num processo, e elas não são equivalentes: a diferença de retorno entre a melhor e a pior é de uma ordem de magnitude, não de alguns pontos percentuais.

| Caminho | Taxa de retorno relativa | Custo de tempo por candidatura | Quando vale |
|---|---|---|---|
| Responder a um InMail de recrutador | Altíssima (você já está pré-qualificado) | 10 minutos | Sempre. Responda até quando não quer a vaga. |
| Indicação (referral) de alguém de dentro | Muito alta | 30 a 90 minutos (o custo é construir a relação) | Sempre que existir alguém plausível |
| Aplicar no site/ATS da própria empresa | Média | 20 a 40 minutos | Para vagas que você realmente quer |
| Easy Apply em massa no LinkedIn | Próxima de zero | 40 segundos | Casos específicos, ver abaixo |

### Por que o Easy Apply em massa quase não funciona

O Easy Apply reduz o custo de candidatura a quase zero, então o volume explode: uma vaga remota internacional recebe rotineiramente milhares de candidaturas nos primeiros dias. Nesse regime o recrutador não lê, filtra — e o filtro é grosseiro: localização, autorização de trabalho, palavra-chave, anos de experiência. Você não compete por atenção, compete para sobreviver a um `WHERE`.

Some a isso que boa parte das vagas "remotas" do LinkedIn é remota **dentro de um país** (remote US, remote EU), e o brasileiro cai no primeiro campo do formulário. Você não perdeu para outro candidato; nunca foi elegível.

Mandar 200 Easy Applies num fim de semana é a forma mais eficiente de se sentir produtivo sem produzir nada. É trabalho emocional disfarçado de trabalho.

### O uso legítimo do Easy Apply

1. **Sinalização de mercado.** Uma rajada única de 15 a 20 candidaturas numa semana, medindo retorno, é termômetro barato: retorno zero em 30 candidaturas bem direcionadas não é azar, é perfil, título ou elegibilidade declarada. Repare que isso é um **teste pontual de diagnóstico**, não a cadência de trabalho — a cadência sustentada é 5 a 8 candidaturas boas por semana. Não confunda o termômetro com o método.
2. **Nicho com pouca concorrência.** Easy Apply numa vaga de Elixir sênior global com 40 candidatos é outra coisa que numa de React com 3.000. O problema nunca foi o botão, foi a razão candidatos/vaga.

Regra: **Easy Apply só quando a vaga tem menos de ~100 candidatos e menciona contratação global/worldwide/anywhere.** Fora disso, aplique no ATS ou não aplique.

### O caminho que quase ninguém usa e deveria

Aplicar no ATS **e** mandar uma mensagem curta a alguém da empresa no LinkedIn — não pedindo emprego, avisando. Isso muda a natureza da candidatura: ela deixa de ser uma linha numa tabela e passa a ter um humano associado.

```
Hi Sarah — I just applied for the Senior Backend Engineer role on your
team. I've been running Go services at similar scale for the past four
years, and the part of the description about migrating off the monolith
is exactly what I spent 2024 doing.

Not asking you to push anything through — just wanted the application to
have a face attached. Happy to answer anything if it's useful.
```

Funciona porque não pede nada, é específico (cita um trecho real da vaga) e dá ao destinatário uma ação de custo zero — tende a responder muito melhor que "hi, could you refer me?", que transfere trabalho e risco para um estranho. Quando **não** aplicar, de propósito: quando a vaga diz "must be located in / authorized to work in [país]" sem menção a contractor (não é otimismo, é ruído no seu próprio funil); quando a senioridade está dois níveis acima da sua (você não será "descoberto", será marcado como quem não lê); quando exigem sobreposição total de fuso com um time na Ásia — não é preconceito geográfico, é aritmética.

## 2. O currículo para o mercado externo

O currículo brasileiro padrão é ativamente prejudicial lá fora. Não é gosto: ele contém informação que, em vários países, o recrutador é **treinado para não olhar** por risco jurídico de discriminação. Um CV com foto e data de nascimento chegando num ATS americano cria um problema para quem recebe.

### O que sai

| Item | Brasil | Exterior | Por quê |
|---|---|---|---|
| Foto | Comum | Nunca (EUA/UK/Canadá) | Risco de viés; algumas empresas descartam o CV por compliance |
| Data de nascimento / idade | Comum | Nunca | Discriminação etária |
| Estado civil, filhos | Comum | Nunca | Irrelevante e ilegal de perguntar |
| CPF, RG, CNH | Comum | Nunca | Dado sensível, sem uso |
| Endereço completo | Comum | Só cidade/país | "São Paulo, Brazil" basta |
| Nacionalidade | Às vezes | Só se ajudar (dupla cidadania UE) | |
| "Objetivo profissional" genérico | Comum | Substituído por resumo | |
| Nota do ENEM, CR da faculdade | Comum | Nunca | |

Fica: nome, cidade/país, e-mail, telefone com DDI, LinkedIn, GitHub (se tiver algo real).

### Tamanho e ordem das seções

**Até ~8 anos de experiência: uma página**, sem exceção que valha discutir. Acima disso, duas são aceitáveis se a segunda tiver conteúdo e não sobra; três só em contexto acadêmico. Ninguém lê a segunda página com o cuidado da primeira — tudo que decide contratação vai na metade de cima da página um.

Para dev mid/sênior a ordem é fixa e não há razão para criatividade: **Cabeçalho** (nome, título-alvo, contatos, uma linha) → **Summary** (2 a 4 linhas; não é objetivo, é posicionamento) → **Experience** (cronologia reversa, 80% do peso) → **Skills** (lista agrupada, sem barrinhas de proficiência) → **Education** (uma ou duas linhas, sem CR e sem TCC) → opcionais (open source, publicações, certificações, idiomas).

Estudante ou primeiro emprego inverte Experience e Skills e sobe Education. Dev com 10 anos de estrada não precisa detalhar estágio de 2013 — uma linha basta, ou nem isso.

### O summary do topo

O erro clássico é escrever um parágrafo que serve para qualquer pessoa. Compare:

Ruim:
```
Passionate and results-driven software engineer with strong problem-solving
skills, seeking new challenges in a dynamic environment where I can grow.
```

Bom:
```
Backend engineer, 7 years, Go and Python. I work on systems where latency
and correctness both matter — payments, ledgers, event pipelines. Last three
years leading backend for a fintech processing ~40k transactions/day.
Remote-first since 2020, based in Brazil, working US hours.
```

O segundo diz stack, anos, domínio, escala, prova de remoto, e resolve a dúvida de fuso antes de ela virar objeção. O primeiro diz que você respira. E o "based in Brazil, working US hours" é deliberado: você quer que a objeção de localização apareça na linha 3, com o recrutador ainda interessado, e não na décima linha do formulário depois que ele se animou.

### Formatação que o parser lê

ATSs modernos (Greenhouse, Lever, Ashby, Workday) leem PDF razoavelmente bem, mas quebram em coisas previsíveis. O parser não pontua nem rejeita nada sozinho — quem descarta é o recrutador; o que está em jogo aqui é o seu currículo chegar legível e aparecer nas buscas por palavra-chave dentro da base. Keyword stuffing em texto branco, aliás, não ajuda: o texto aparece em qualquer copiar-e-colar e o recrutador lê como tentativa de enganar.

- **Uma coluna.** Duas colunas é a causa mais frequente de currículo saindo embaralhado do parser.
- **Sem caixas de texto, sem tabelas, sem informação em cabeçalho/rodapé** — texto em header do Word frequentemente some. **Sem ícones** de e-mail/telefone: o parser lê o ícone como nada e o texto ao lado perde contexto.
- **Fontes padrão** (Inter, Arial, Calibri, Garamond). **Títulos canônicos em inglês**: Experience, Education, Skills. Não invente "My Journey".
- **Datas `Mon YYYY – Mon YYYY`** (Jan 2022 – Present). Só o ano faz o parser assumir janeiro e errar o cálculo de tempo.
- **PDF com texto selecionável.** PDF que é imagem é currículo em branco para o ATS. Arquivo: `Firstname-Lastname-Resume.pdf`, não `cv_final_v3_ATUALIZADO.pdf`.

### EUA vs Reino Unido/Europa vs Europass

| Aspecto | EUA (resume) | Reino Unido / Irlanda (CV) | Europa continental | Europass |
|---|---|---|---|---|
| Nome | Resume | CV | CV | CV |
| Tamanho | 1 página forte | 2 páginas aceitas | 2 páginas | 3+ |
| Foto | Nunca | Nunca | Alemanha/Áustria ainda comum, mas caindo | Campo existe |
| Idade/estado civil | Nunca | Nunca | Evite mesmo onde é tolerado | Campo existe |
| Tom | Resultado, número, impacto | Um pouco mais de contexto e narrativa | Mais formal | Formulário |
| Ortografia | American (optimize, analyze) | British (optimise, analyse) | British costuma passar | — |

**Sobre o Europass: evite.** É um formulário padronizado da UE, criado por uma razão administrativa boa — comparar qualificações entre países. Como candidatura para engenharia em empresa de tecnologia, é ruim: layout inflado, seções obrigatórias vazias, escalas de autoavaliação de idioma que ninguém no setor privado usa, e uma estética que sinaliza "setor público / recém-formado". Só use se a vaga pedir explicitamente (algumas posições em instituições europeias pedem).

Na prática, um único CV bem feito em inglês americano, uma página, uma coluna, cobre a grande maioria dos casos. Variante britânica só se você estiver mirando UK com volume. E escolha uma ortografia e seja consistente: misturar "organize" e "optimise" no mesmo documento é o tipo de detalhe que um recrutador nativo percebe sem saber que percebeu.

## 3. Bullets de currículo

Esta é a parte que decide. Recrutador escaneia os bullets; tudo o mais é moldura.

### A estrutura, e o erro que a mata

**Ação (verbo forte) + contexto (o quê / onde / com que restrição) + resultado (o que mudou).** Os três elementos aparecem em ordem inversa de frequência: quase todo mundo escreve a ação, muita gente escreve o contexto, quase ninguém escreve o resultado — que é justamente o único que responde à pergunta real do leitor, "o que acontece de bom se eu contratar essa pessoa".

O erro estrutural mais comum é descrever o **cargo** em vez do **trabalho**. "Responsible for maintaining the API" é a descrição da vaga que você ocupou, não do que você fez nela; qualquer pessoa naquele cargo escreveria a mesma frase, o que a torna informativamente vazia. Teste rápido: se o bullet continuaria verdadeiro caso você tivesse passado o ano inteiro sem entregar nada, ele não é um bullet, é um crachá.

Verbos bons: built, designed, led, migrated, reduced, cut, shipped, rewrote, automated, scaled, instrumented, debugged, owned, launched, consolidated, eliminated, mentored.

Fracos ou proibidos: responsible for, worked on, helped with, participated in, was involved in, assisted, handled, dealt with, tasked with. Evite também os inflados sem substância — spearheaded, orchestrated, leveraged, synergized, revolutionized — que soam a currículo comprado.

### Como quantificar quando não existe número

Ninguém tem métrica para tudo, mas quase sempre dá para dar magnitude por outra via: **escala do sistema** ("serving ~2M requests/day", "for a 30-person engineering org"); **tempo** ("cut deploy time from 40 min to 6"); **contagem discreta** ("replaced 3 legacy services with one", "removed ~8k lines"); **frequência** ("from monthly releases to daily"); **antes/depois qualitativo com evidência** ("eliminated the on-call page that accounted for most of the team's night alerts"); **consequência organizacional** ("unblocked the mobile team's Q3 launch").

Se realmente não há nada, seja concreto sobre a dificuldade técnica em vez de inventar percentual. Número inventado é pior que ausência de número, porque a entrevista vai perguntar como você mediu.

### 15 bullets reescritos

**1. Responsabilidade genérica**
- Ruim: `Responsible for the backend of the company's main product.`
- Bom: `Owned the backend of the checkout platform (Go, Postgres) handling ~R$40M/month in transaction volume across 3 payment providers.`
- *Comentário: "responsible for" vira "owned", e a frase ganha stack, domínio e escala. O leitor agora sabe se você serve.*

**2. Sem resultado**
- Ruim: `Worked on migrating the system to microservices.`
- Bom: `Split a Rails monolith into 6 services over 9 months, cutting the median deploy from 45 minutes to under 5 and letting teams release independently.`
- *Comentário: "worked on" não diz se deu certo. A versão boa dá duração (mostra que foi projeto real), resultado técnico e resultado organizacional.*

**3. Métrica sem base**
- Ruim: `Improved application performance by 200%.`
- Bom: `Cut p95 latency on the search endpoint from 1.8s to 320ms by replacing N+1 queries with a single materialized view.`
- *Comentário: "200% melhor" não significa nada e o entrevistador vai perceber. Percentil, valores absolutos e a causa técnica dão credibilidade — e viram uma boa conversa na entrevista.*

**4. Descrição de tarefa**
- Ruim: `Wrote unit tests for existing code.`
- Bom: `Raised coverage on the billing module from 20% to 85% and drove the flaky-test rate down to near zero, which let us turn on required CI checks for the whole repo.`
- *Comentário: o valor de escrever teste nunca é o teste; é o que ele destrava. Aqui o destravamento é o CI obrigatório.*

**5. Ferramenta como conquista**
- Ruim: `Used Docker and Kubernetes.`
- Bom: `Containerized 14 legacy services and moved them to EKS, replacing a hand-managed EC2 fleet and removing roughly 20 hours/month of manual ops work.`
- *Comentário: usar uma ferramenta não é feito. O feito é o que mudou no mundo — aqui, horas de operação manual eliminadas.*

**6. Ajuda vaga**
- Ruim: `Helped the team improve code quality.`
- Bom: `Introduced a PR review rotation and a lint/CI gate; median time-to-merge dropped from 4 days to under 1 without adding reviewers.`
- *Comentário: "helped" é o verbo mais fraco do currículo. Nomeie a intervenção e mostre o número. O "without adding reviewers" fecha a objeção óbvia.*

**7. Sem contexto de escala**
- Ruim: `Developed REST APIs.`
- Bom: `Designed and shipped 20+ REST endpoints for a B2B integrations product used by 60 enterprise customers, including auth, rate limiting and versioning.`
- *Comentário: "REST APIs" é o piso do mercado. O que diferencia é para quem, quantos, e quais problemas difíceis (versionamento, rate limiting) você resolveu.*

**8. Liderança sem prova**
- Ruim: `Team leader of 5 developers.`
- Bom: `Led a 5-engineer squad through the replatforming of the customer portal; delivered in 2 quarters with zero unplanned downtime and no attrition on the team.`
- *Comentário: cargo de líder é fácil de escrever. "Zero unplanned downtime" e "no attrition" são as duas métricas que um hiring manager de fato liga.*

**9. Bug fixing genérico**
- Ruim: `Fixed bugs reported by users.`
- Bom: `Traced and fixed a data-race in the order sync worker that had been silently dropping ~0.5% of orders for months; added invariant checks that caught two similar bugs later.`
- *Comentário: um bug bom vale mais que dez features. O detalhe "silently" e o follow-up com invariantes mostram maturidade, não só conserto.*

**10. Frontend sem impacto**
- Ruim: `Built screens in React.`
- Bom: `Rebuilt the onboarding flow in React/TypeScript, cutting first-render from 4.2s to 1.1s on 3G and lifting signup completion by 12% (A/B tested over 6 weeks).`
- *Comentário: mencionar A/B e duração do teste inocula contra a acusação de correlação. Um número com metodologia atrás é muito mais forte.*

**11. Dado sem "e daí"**
- Ruim: `Created dashboards in Grafana.`
- Bom: `Instrumented the payments service with structured logs and RED metrics; the resulting dashboards cut mean time-to-diagnosis on incidents from hours to ~15 minutes.`
- *Comentário: dashboard não é entregável, diagnóstico rápido é. Cite o vocabulário certo (RED, structured logs) para sinalizar profundidade.*

**12. Processo sem consequência**
- Ruim: `Participated in agile ceremonies.`
- Bom: `(remover o bullet inteiro)`
- *Comentário: às vezes a reescrita certa é a exclusão. Participar de daily não diferencia ninguém e ocupa espaço que outro bullet usaria melhor.*

**13. Migração sem risco explicitado**
- Ruim: `Migrated the database from MySQL to PostgreSQL.`
- Bom: `Migrated a 900GB MySQL database to Postgres with dual-write and a phased cutover; 40 minutes of read-only time total, no data loss, no rollback.`
- *Comentário: o tamanho e a estratégia (dual-write, faseado) provam que você já fez isso de verdade. "No rollback" é o detalhe que um sênior reconhece.*

**14. Trabalho de plataforma invisível**
- Ruim: `Maintained CI/CD pipelines.`
- Bom: `Rewrote the CI pipeline (GitHub Actions, cached layers, parallel test shards): build time went from 22 to 6 minutes across the 40 repos of a 30-engineer org.`
- *Comentário: trabalho de plataforma precisa ser traduzido para espera de engenheiro e alcance, senão o leitor não-técnico não enxerga. Note que a magnitude vem de números verificáveis (repos, tamanho do time), não de uma economia estimada.*

**15. Inglês fraco desperdiçando bom trabalho**
- Ruim: `Was responsible for make the integration with the payment gateway of the client and give support.`
- Bom: `Built and supported the payment-gateway integration for our largest client, processing ~15k daily transactions with a 99.95% success rate.`
- *Comentário: o trabalho era bom, a frase matou. Erro gramatical no currículo custa mais que na entrevista — no papel não há como compensar com simpatia.*

## 4. Alinhamento entre LinkedIn e currículo

O recrutador abre os dois lado a lado. Isso não é paranoia — é literalmente parte do fluxo do trabalho dele, e ferramentas de sourcing colocam os dois na mesma tela.

**O que nunca pode divergir:**

| Campo | Regra |
|---|---|
| Datas de início e fim | Idênticas, mês a mês. Divergência aqui é lida como omissão de gap ou de demissão. |
| Nome da empresa | Idêntico. Se foi aquisição, use `NewCo (formerly OldCo)` nos dois. |
| Título do cargo | O mesmo. Se o título interno era "Analista de Sistemas III" e você quer usar "Software Engineer", use "Software Engineer" nos dois. |
| Sobreposição de empregos | Se houve, deve aparecer nos dois com explicação idêntica. |
| Formação | Instituição, curso e ano iguais. Diploma não concluído se declara como "coursework" ou não se declara — nunca como concluído. |

**O que pode e deve divergir:** extensão (LinkedIn com 6 bullets por cargo, currículo com 3 — é esperado); ênfase (currículo focado em backend, LinkedIn mais amplo — o que não pode é o currículo dizer "led a team of 8" e o LinkedIn não mencionar liderança em lugar nenhum); tom (LinkedIn admite primeira pessoa e narrativa no About, currículo não); cargos antigos (o currículo pode omitir empregos de mais de 12 anos atrás, o LinkedIn pode mantê-los — o contrário chama atenção negativa).

Traduzir títulos é legítimo e recomendado: "Desenvolvedor Pleno" não significa nada fora do Brasil, "Mid-level Software Engineer" significa. O que não é legítimo é promover a si mesmo — virar "Staff Engineer" quando você era pleno cria problema real no background check e na entrevista técnica.

Caso brasileiro específico: PJ com empresa própria (`Fulano Tecnologia LTDA`) prestando serviço a um único cliente por 3 anos. Liste **o cliente** como empregador e explicite o formato: `Software Engineer — ClientCo (contract via own company)`. Listar a própria LTDA faz parecer freelancer disperso.

## 5. Cover letter

A resposta honesta: **na maioria dos casos, não importa.** Em empresa de tecnologia de porte médio para grande, com ATS e campo opcional, ele é ignorado. Escrever cinco parágrafos para uma vaga da Shopify é tempo que renderia mais numa mensagem a um engenheiro do time.

Quando importa de verdade:

1. **Startup pequena** (abaixo de ~50 pessoas), onde a candidatura é lida por um fundador ou pelo hiring manager. Aqui a carta pode decidir.
2. **Mudança de área** — de QA para dev, de backend para ML, de agência para produto. O currículo mostra o passado; a carta explica a direção. Sem ela o leitor preenche a lacuna com a hipótese pior.
3. **Candidatura fora do perfil óbvio** — stack adjacente e não idêntico, senioridade acima do rótulo da vaga, domínio novo.
4. **A vaga pede explicitamente**, sobretudo com uma pergunta específica ("tell us about something you built that you're proud of"). Aí não é carta, é pergunta de entrevista antecipada, e ignorar é descarte.
5. **Empresas com cultura de escrita** (algumas remote-first). Elas dizem isso na descrição.

Quando **não** escrever: Easy Apply, empresa grande, campo opcional, sem pergunta específica. E jamais uma carta genérica com o nome da empresa trocado — é pior que nenhuma, porque prova desatenção.

### Modelo curto que não é genérico

Três parágrafos. Menos de 200 palavras. A regra que importa: **cada frase deve ser impossível de reaproveitar para outra empresa.**

```
Hi Marta,

I'm applying for the Senior Backend Engineer role. The line in the
posting about "the ledger is the hardest part of the system and we
know it" is why I'm writing — I spent the last two years rebuilding
a double-entry ledger at Nubank-scale volume, and the failure modes
you're describing (reconciliation drift, retries that double-post)
are the exact ones that kept me up.

What I'd bring: seven years of Go and Postgres, a rewrite that took
our reconciliation mismatches from ~200/day to under 5, and a strong
bias for making correctness observable rather than assumed. I've been
fully remote since 2020, based in Brazil, and I overlap with US
Eastern hours by choice, not by compromise.

I'm not going to claim I know your domain better than you do. But I
know this class of problem, and I'd like to talk about it.

Best,
Rafael
```

Funciona porque cita uma frase real do anúncio (prova de leitura), traz um número concreto, aborda fuso e localização sem pedir desculpas, e o último parágrafo desarma a arrogância que o segundo poderia sugerir. É curta o bastante para ser lida inteira. Não faça o oposto: "I have always been passionate about your mission", "I believe I would be a great fit", "Your company is a leader in the industry" — nenhuma dessas frases sobrevive ao teste de reaproveitamento.

## 6. Knockout questions do formulário

São as perguntas do formulário que eliminam automaticamente. A maioria dos brasileiros perde vagas aqui por **má interpretação**, não por inelegibilidade real — é a perda mais estúpida do funil, porque é inteiramente evitável.

### "Are you legally authorized to work in the United States?"

A resposta é **No**, salvo cidadania, green card ou visto de trabalho válido. Em muitos casos isso é eliminatório, e deveria ser: a vaga era W-2 nos EUA.

O erro grave é responder **Yes** pensando "eu posso trabalhar legalmente como PJ prestando serviço para os EUA". Não é a mesma pergunta. "Authorized to work in the US" é termo jurídico sobre autorização de emprego em solo americano. Responder Yes e o assunto aparecer na terceira etapa custa a vaga e a reputação com aquele recrutador.

- Havendo campo de texto próximo: `No — I'm based in Brazil and work with US companies as an independent contractor / through an EOR. Not seeking sponsorship or relocation.`
- Sem campo, e vaga claramente US-only W-2: **não aplique.** Você não converte e queima tempo.
- Vaga "remote — worldwide" que ainda assim faz essa pergunta (comum, é template de ATS): responda No e deixe claro na primeira linha do resumo/carta que você é contractor. O filtro costuma ser manual e o recrutador entende.

### "Will you now or in the future require sponsorship?"

Se você não quer relocation, a resposta correta é **No** — você não vai trabalhar em solo americano. Responder Yes liga um alarme de custo e complexidade sem motivo. Havendo campo aberto: `No — I work remotely from Brazil as a contractor; no visa or sponsorship needed.` Se você **quer** relocation, é Yes, e o funil é outro: mercado menor, processo mais longo, prazos dobrados.

### Localização, salário, disponibilidade

**Endereço:** sua cidade real no Brasil. Cidade americana falsa para passar o filtro é fraude de baixo nível que aparece no background check, no fuso das reuniões e no contrato. Se o formulário só oferece uma lista fechada de países sem o Brasil, essa é a resposta: a vaga não contrata daqui.

**Faixa salarial** é o campo mais perigoso, porque uma resposta ruim elimina antes de qualquer conversa. Em ordem de preferência: deixe em branco se opcional; se for texto, `Open / negotiable — happy to discuss once I understand the scope and the contract structure.`; se for numérico obrigatório, dê um número **em USD anual, nunca em reais nem mensal**, calibrado pelo mercado da vaga e não pelo seu salário atual convertido; se for faixa, um intervalo de cerca de 20% com o valor desejado no terço inferior, porque o piso vira âncora. Derive os valores da tabela de faixas de `vagas-remotas-no-exterior.md`, cruzando stack e senioridade — nenhum número de remuneração deve ser tirado daqui.

Erros clássicos: converter o salário em reais e pedir isso (ancora muito abaixo e sinaliza desconhecimento do mercado); pedir valor mensal (parece contratação local); pedir um número absurdo para "negociar depois" (você é filtrado antes da conversa). Se perguntarem seu salário **atual** — ilegal em vários estados americanos, e mesmo onde não é você não precisa responder: `I'd rather anchor on the value of the role than on my current contract, which is in a different market and currency.`

**Disponibilidade:** honesta e específica — `30 days' notice with my current client` ou `Available immediately`. "Immediately" quando você tem 30 dias de aviso vira atrito na semana da assinatura.

**Fuso:** responda com números, não com boa vontade — `Based in UTC-3. I overlap with US Eastern from 9am to 6pm ET with no adjustment, and can cover 8am ET when needed.` Vale mais que "flexible with hours".

**Anos de experiência:** só experiência profissional remunerada relevante. Somar estágio de 6 meses em suporte para virar "5 years" não sobrevive à entrevista técnica.

## 7. As etapas do processo, uma a uma

Um processo típico tem 4 a 7 etapas e leva de 3 a 8 semanas. Empresa pequena faz 3; big tech faz 6 ou mais.

### 7.1 Recruiter screen (25 a 30 min)

**Avalia:** inglês falado, coerência entre currículo e realidade, expectativa salarial, elegibilidade/localização, e se você é agradável de conversar. **Não avalia** profundidade técnica — o recrutador não sabe avaliar isso e não é o trabalho dele.

Preparação: um pitch de 90 segundos ensaiado (não decorado) — onde você está, o que faz, um resultado, por que está olhando o mercado; o número salarial pronto, porque você vai ser perguntado e hesitar custa mais que responder; antecipe **você** o assunto de fuso e contrato na primeira metade da conversa, o que projeta que já fez isso antes; e duas ou três perguntas sobre o processo.

O maior risco para o brasileiro aqui é o inglês travado nos três primeiros minutos. É nervosismo, não competência, mas o recrutador não distingue. Fale inglês em voz alta 15 minutos antes da call; aquecimento importa mais do que parece.

### 7.2 Hiring manager screen (45 a 60 min)

**Avalia:** se você resolve os problemas que o time tem hoje, como você pensa, e se ele quer conversar com você toda semana. É a etapa mais determinante do processo e a mais subestimada.

Preparação: leia (e use, se der) o produto; saiba dizer em duas frases qual problema você acha que a vaga existe para resolver, e pergunte se acertou; tenha duas histórias profundas — um projeto de que se orgulha e uma coisa que deu errado por sua causa; e perguntas sobre o time (tamanho, como priorizam, como é o on-call, o que quebrou por último).

### 7.3 Live coding (45 a 75 min)

**Avalia:** se você produz código funcional sob observação e comunica enquanto pensa. Em empresa de produto raramente é LeetCode hard — costuma ser problema aplicado: parsear algo, modelar um domínio pequeno, estender código existente.

- Pratique **falando em voz alta em inglês enquanto codifica**. É essa a habilidade que falta, não o algoritmo. Codificar em silêncio é reprovação mesmo com a solução certa.
- Comece perguntando entradas, limites, casos de borda. Sair codificando na primeira frase é o erro mais comum de nível pleno.
- Diga qual abordagem vai tentar e por quê, antes de digitar. Se travar, verbalize o que está tentando: 90 segundos de silêncio são piores que uma tentativa errada explicada.
- Escreva ao menos um teste ou exemplo manual sem ser pedido.

Se a empresa fizer LeetCode puro (big tech e algumas fintechs fazem), é treino específico: 4 a 6 semanas consistentes por padrão (two pointers, sliding window, hash map, BFS/DFS, heap, DP básica). Não há atalho. Para take-home, system design e behavioral, ver as seções 9, 8 e 10.

### 7.4 Painel / onsite virtual

Várias etapas no mesmo dia, 3 a 5 horas. Cada entrevistador avalia um eixo e escreve relatório independente; a decisão sai de um comitê ou de uma debrief. Peça a agenda antes, com nome e cargo de cada entrevistador, e olhe cada um no LinkedIn. Tenha perguntas **diferentes** para cada um — repetir a mesma pergunta para quatro pessoas é notado na debrief. Coma entre as sessões: fadiga em inglês na quarta hora é real e derruba gente boa.

### 7.5 Referências

Geralmente 2 a 3 contatos, ex-gestores de preferência. Peça permissão antes e mande à pessoa um resumo da vaga e dos pontos que você gostaria que ela mencionasse — referência que precisa lembrar de você na hora da ligação é referência morna. Se seus ex-gestores não falam inglês, avise o recrutador: `Two of my references are Brazilian and more comfortable in Portuguese — is a written reference acceptable?` Normalmente é.

## 8. System design para quem nunca fez

O formato pega o brasileiro de surpresa porque é raro em processos nacionais. Não é prova de conhecimento: é uma conversa em que você conduz o desenho de um sistema em voz alta enquanto o entrevistador introduz restrições. O que se espera por nível:

| | Pleno (mid) | Sênior |
|---|---|---|
| Escopo | Um serviço, um fluxo | Sistema com vários componentes |
| Espera-se | API sensata, modelo de dados correto, escolha de banco justificada, noção de cache | Tudo isso + trade-offs explícitos, modos de falha, consistência, evolução |
| Requisitos | Ok pedir esclarecimento e seguir | Você deve **liderar** a definição de requisitos e escopo |
| Escala | Saber quando algo não escala | Estimar carga, dimensionar, apontar o gargalo antes de ele aparecer |
| Falha | Reconhecer que existe | Desenhar para ela: retry, idempotência, backpressure, degradação |
| Resultado aceitável | Desenho correto, ainda que simples | Desenho correto + defesa das escolhas + o que você faria diferente em 10x |

Um pleno que enumera trade-offs bem é lido como sênior; um sênior que só desenha caixas sem justificar é lido como pleno.

### O formato da conversa (45 min típicos)

1. **Requisitos e escopo (5–10 min).** Pergunte: funcionais e não-funcionais, quantos usuários, escrita vs leitura, latência aceitável, consistência forte ou eventual. É onde a maior parte da nota é ganha ou perdida.
2. **Estimativas grosseiras (3–5 min).** QPS, volume de dados por ano, em ordem de magnitude, dito como aproximação. Não precisa acertar; precisa mostrar que você raciocina sobre magnitude.
3. **Desenho de alto nível (10 min).** Componentes principais e o fluxo de uma requisição ponta a ponta.
4. **Aprofundar em uma ou duas partes (15 min).** O entrevistador escolhe, ou você propõe: "the interesting part here is the write path — want me to go deeper there?"
5. **Gargalos, falhas, evolução (5–10 min).** O que quebra primeiro em 10x, o que acontece se esse componente cair.

### Erros clássicos

- **Sair desenhando sem perguntar nada** — o erro mais comum de todos.
- **Citar tecnologia como resposta.** "I'd use Kafka" não é design; "I need durable ordered delivery with replay, so a log-based broker like Kafka, at the cost of operational overhead" é.
- **Overengineering.** Multi-region ativo-ativo para 1.000 usuários é sinal de imaturidade, não de senioridade. Comece simples e escale sob pressão do entrevistador.
- **Esquecer o modelo de dados.** Muita gente desenha caixas e nunca diz o que fica em qual tabela. Escreva o schema.
- **Não falar** — mesmo problema do live coding, amplificado.
- **Defender demais.** Quando o entrevistador aponta um problema ele geralmente tem razão, e mesmo quando não tem, a habilidade avaliada é integrar crítica: `Good point — that breaks if X. Two options then: A or B. I'd lean A because...`

Preparação mínima realista: load balancer, cache, réplica de leitura, sharding, fila, consistência eventual, idempotência — e ter desenhado 5 ou 6 sistemas clássicos em voz alta (encurtador de URL, feed, chat, rate limiter, upload de arquivo, notificações).

## 9. Take-home

**Antes de qualquer coisa:** código de processo seletivo nunca roda na máquina principal — sempre em container ou VM descartável, sem credenciais e sem acesso à sua rede. Isso vale para take-home legítimo também, não só para os suspeitos. O protocolo de isolamento e os sinais de repositório malicioso estão em `riscos-golpes-e-etica.md`.

### Quanto investir, e quando recusar

O tempo declarado pela empresa é sempre otimista: um take-home anunciado como "3 a 4 horas" costuma exigir 6 a 8 para sair bom. Regra prática: invista **até o dobro** do tempo anunciado e pare, entregando o que deu com um README honesto sobre o que faltou. Passar 20 horas num take-home de 4 não impressiona — frequentemente prejudica, porque cria expectativa errada e algumas empresas penalizam scope creep explicitamente.

Recuse, educadamente e sem ressentimento, quando: o take-home vem **antes** de qualquer conversa humana (trabalho não pago para quem ainda não investiu 30 minutos em você); é estimado em mais de ~8 horas; o escopo parece suspeitamente uma feature real e específica do produto deles; ou você já está em estágio avançado com outras empresas e o custo de oportunidade é claro.

```
Thanks for sending this over. Honestly, at 10+ hours this is more than
I can commit to alongside my current contract. I'd be glad to do a live
pairing session of 60–90 minutes instead, or walk you through a project
I've already built — whatever gives you the strongest signal. If the
take-home is a hard requirement I completely understand, and I'd rather
tell you now than deliver something rushed.
```

Parte das empresas oferece a alternativa. As que não oferecem também são informação sobre elas.

### Como entregar

O código é metade da avaliação; a outra metade é a comunicação em torno dele. **README obrigatório**, com: como rodar (um comando, idealmente `docker compose up` ou `make run` — se o avaliador não rodar em 5 minutos, você perdeu); o que está e o que não está implementado, explicitamente; **decisões e trade-offs** (por que esse banco, por que essa estrutura, o que faria diferente com mais tempo); suposições feitas sobre requisitos ambíguos; e como rodar os testes.

**Testes**: sempre, mesmo sem a instrução pedir. Não precisa de 100% de cobertura — precisa cobrir o núcleo do domínio e os casos de borda que você citou no README. Ausência total de teste está entre os motivos mais comuns de reprovação em take-home de vaga sênior. **Commits**: histórico limpo, incremental, mensagens em inglês; um único "initial commit" com tudo desperdiça a chance de mostrar como você trabalha.

**Não faça**: 8 dependências para um exercício de 200 linhas; abstração para requisitos inexistentes; entrega sem instruções de execução; entrega 2 semanas depois sem avisar. Um trecho de README que funciona bem:

```markdown
## Trade-offs

- **In-memory store instead of Postgres.** The spec doesn't require
  durability and adding a DB would have doubled setup time for the
  reviewer. The repository interface is isolated in `store/`, so
  swapping it is a single implementation.
- **No auth.** Out of scope per the brief; I left a note in `server.go`
  where the middleware would hook in.
- **What I'd do with more time:** idempotency keys on the write path
  (currently a duplicate POST creates two orders) and a proper retry
  policy on the outbound webhook.
```

Reconhecer o próprio bug antes que o avaliador o encontre não é fraqueza; é a coisa mais sênior que dá para fazer num take-home.

## 10. Behavioral em inglês

Etapa que devs brasileiros subestimam, e onde muito processo morre. A causa não é falta de história — é a resposta que se dissolve num monólogo de quatro minutos sem estrutura, agravado pelo esforço cognitivo do inglês.

### STAR, na prática

**Situation** (2 frases: onde, quando, qual o cenário) → **Task** (1 frase: sua responsabilidade específica) → **Action** (a maior parte; o que **você** fez, primeira pessoa do singular, decisões e não atividades) → **Result** (2 frases: o que mudou, com número se houver, e o que você aprendeu).

Duração-alvo: **90 segundos a 2 minutos e meio.** Menos parece raso; mais perde o entrevistador.

Dois erros brasileiros específicos: **"we" em vez de "I"** — somos treinados a creditar o time, mas "we" o tempo todo torna impossível avaliar sua contribuição; use "we" para contexto e "I" para as ações, e credite o time no final, em uma frase. E **minimizar o resultado** — "it went ok, I guess" destrói uma história boa. Não precisa ser arrogante, precisa ser factual: "the migration shipped on time and we didn't have a single rollback."

### As 12 perguntas que sempre caem

1. Tell me about yourself.
2. Tell me about a project you're most proud of.
3. Tell me about a time you disagreed with a teammate or a manager.
4. Tell me about a time you failed, or shipped a bug to production.
5. Tell me about a time you had to deliver under a tight deadline.
6. Tell me about a time you had to learn something new quickly.
7. How do you handle competing priorities / too much work?
8. Tell me about a time you gave or received difficult feedback.
9. Tell me about a technical decision you made that turned out wrong.
10. Tell me about a time you influenced a decision without authority.
11. Why are you looking to leave your current role? / Why us?
12. Tell me about working with people in a different time zone or culture.

Não prepare 12 respostas: prepare 6 a 8 histórias sólidas e aprenda a recortá-las conforme a pergunta. Elas cobrem as 12 com folga.

### Resposta-modelo 1 — "Tell me about a time you disagreed with a teammate"

```
Last year our tech lead wanted to move our main service to a
microservices setup, and I pushed back — which was uncomfortable,
because he'd already presented the plan to the CTO.

My concern wasn't the architecture, it was sequencing: we had four
engineers, no service mesh, no distributed tracing, and an on-call
rotation that was already painful. I thought we'd be debugging network
problems instead of shipping.

So rather than argue in the meeting, I asked for a week. I pulled the
last three months of incidents and mapped which ones would have been
harder to diagnose across service boundaries — it was about two thirds
of them. I brought that to him one-on-one, and I came with an
alternative: extract one service first, the payments module, and only
continue if our incident diagnosis time didn't get worse.

He agreed. We extracted payments, it went well, and we did two more
over the next six months — but with tracing in place first, which came
out of that conversation. The part I'd repeat is going to him privately
with data instead of debating it in front of the CTO. The part I'd do
differently is raising it earlier; I sat on the concern for two weeks
because I didn't want to look obstructive.
```

*Comentário: a situação é curta. A ação mostra iniciativa, dado e alternativa — discordar sem propor alternativa é reclamar. O resultado é concreto e ainda inclui uma autocrítica genuína, que é o que separa uma resposta boa de uma ensaiada. Note o uso de "I" nas decisões e "we" no contexto.*

### Resposta-modelo 2 — "Tell me about a time you failed"

```
I took down checkout for about forty minutes on a Friday afternoon.

We were adding a column to the orders table — around 40 million rows,
Postgres. I'd run the migration in staging and it took seconds, so I
scheduled it for production during low traffic. What I missed is that
staging had a tiny fraction of the data, and the migration took an
ACCESS EXCLUSIVE lock. Every write to orders queued behind it.

I noticed within about three minutes because our latency alert fired.
I killed the migration, which rolled back cleanly, and traffic
recovered. Then I wrote the postmortem — and the part that mattered
wasn't my mistake specifically, it was that we had no rule about
migrations on large tables and nothing in CI would have caught it.

So I added two things: a CI check that flags any migration touching a
table over a million rows and requires a second reviewer, and a short
internal doc on lock-safe migration patterns in Postgres. We ran
probably thirty migrations after that with no incident.

What I actually learned is narrower than "test better" — it's that
staging is only a valid rehearsal if the data shape is comparable, and
for anything involving locks, it usually isn't.
```

*Comentário: falha real, com consequência real. A resposta não terceiriza a culpa nem se afoga em desculpas. Mostra detecção rápida (o alerta), resposta correta, e — mais importante — corrige o sistema, não só o próprio comportamento. A última frase é uma lição específica, não um clichê. Nunca responda essa pergunta com uma falha falsa ("I work too hard"); isso é imediatamente reconhecido e caro.*

### Resposta-modelo 3 — "Tell me about working across time zones"

```
I've been working with US-based teams from Brazil for four years now,
so this is basically my normal mode rather than an exception.

The concrete thing: I'm in UTC-3, so I overlap with US Eastern for most
of the working day and with Pacific for the afternoon. That's actually
one of the reasons companies work with Brazil rather than with Eastern
Europe or Asia — the overlap is real, not a compromise.

But overlap alone doesn't fix anything. What made the difference on my
last team was writing more than I would have otherwise. I moved design
discussions into short written docs before meetings, so people in three
time zones could contribute asynchronously instead of the two people
who happened to be awake making the call. I also made a habit of ending
my day with a short written update in the team channel — not a status
report, just decisions made and things I was blocked on. It sounds
small, but it meant the person picking up at 9am Pacific never lost
half a day waiting for me.

The one thing I've learned to be firm about: I don't take meetings after
7pm my time regularly. I'll do it for an incident or a launch, but if
it becomes standing, it stops being sustainable and I'd rather negotiate
it up front than quietly burn out.
```

*Comentário: transforma a "objeção" de localização em argumento a favor. Traz um comportamento concreto (docs antes da reunião, update escrito ao fim do dia) em vez de adjetivos como "communicative". E o parágrafo final estabelece um limite de forma profissional — isso não elimina candidato bom, ao contrário: sinaliza que você já fez isso o suficiente para saber o que quebra.*

Sobre o inglês nessa etapa: você não precisa falar sem sotaque, precisa ser **claro e estruturado**. Fale mais devagar do que o instinto pede; se perder a palavra, pare e reformule em vez de improvisar uma frase mais complexa; se não entender a pergunta, peça repetição — `Sorry, could you rephrase that?` é normal e não penaliza, enquanto responder outra coisa penaliza muito.

## 11. O que perguntar para a empresa

Não ter pergunta é resposta ruim, e perguntar "qual a cultura da empresa?" é quase igual a não ter.

| Etapa | Boas perguntas |
|---|---|
| Recruiter | Quantas etapas e prazo total? Qual o formato do contrato (contractor, EOR, CLT-like)? A faixa está definida? Por que a vaga está aberta? |
| Hiring manager | Como é um dia típico do time? Como as prioridades são decididas? Qual o maior problema técnico do time hoje? O que faria alguém falhar nessa posição nos primeiros 6 meses? |
| Técnica | Como é o processo de code review? Quanto tempo do sprint vai para dívida técnica? Como é o on-call? Qual foi o último incidente relevante? |
| Behavioral/values | Como é dado feedback aqui? Como a empresa lida quando alguém não está indo bem? |
| Oferta | Ver abaixo |

A melhor pergunta única do processo: **"What would make you consider this hire a mistake in six months?"** Força uma resposta honesta e ensina mais que cinco perguntas sobre cultura.

### As perguntas específicas de quem vai ser contractor no Brasil

Esta é a parte que ninguém pergunta e vira problema quatro meses depois. Faça por escrito, antes de assinar. Formule como logística, nunca como desconfiança: `A few practical questions so I can plan on my end —`.

1. **Moeda e pagamento.** `Is the contract denominated in USD? Which platform — Deel, Remote, direct wire? Who covers the transfer and platform fees?` Taxas de transferência e de plataforma podem comer uma fatia relevante de cada pagamento sem que ninguém as tenha mencionado.
2. **Previsibilidade.** `What's the payment schedule, and what's the typical delay between invoice and funds landing?` Invoice no dia 1 e dinheiro no dia 12 muda seu fluxo de caixa.
3. **Reajuste.** `Is there an annual review of the contract rate? Is it tied to performance, inflation, market?` Contrato de contractor costuma não ter reajuste automático — cada ano de silêncio é perda real de poder de compra.
4. **PTO.** `How does time off work for contractors — paid, unpaid, or an agreed number of days?` Muitos contratos não pagam férias, e isso precisa entrar no cálculo do valor.
5. **Feriados.** `Do I follow Brazilian holidays, US holidays, or neither?` Parece detalhe e é fonte constante de atrito.
6. **Core hours.** `What are the core hours? How late do meetings typically run in Eastern time?` Peça exemplo concreto, não a política declarada.
7. **Equipamento.** `Is there a hardware budget or stipend?` Contractor geralmente compra o próprio.
8. **Equity.** `Are contractors eligible for equity? Options or RSUs, and how does that work for a non-US person?` Frequentemente não são elegíveis; às vezes há alternativa em dinheiro.
9. **Aviso prévio dos dois lados.** `What's the termination notice — for me and for the company?` 30 dias mútuos é razoável; 7 dias para a empresa e 30 para você é assimetria negociável.
10. **Mudança de política de remoto.** `If the company changes its remote policy, what happens to contractors outside the US?` Desconfortável e por isso valiosa — já custou emprego a muita gente que não perguntou.
11. **IP e não-competição.** Leia as cláusulas. Contratos americanos padrão às vezes reivindicam IP de tudo o que você produz, inclusive fora do horário. É negociável, e vale negociar se você tem projetos próprios.
12. **Conversão futura.** `Is there a path to converting to an employee/EOR arrangement later?` Não porque você precisa, mas porque a resposta revela como eles enxergam contractors.

## 12. Negociação de oferta

Regra de partida: **quase toda oferta tem alguma folga, e a maioria das pessoas aceita a primeira sem perguntar.** Perguntar não custa a oferta — em empresa séria, retirar oferta porque o candidato negociou educadamente é praticamente inexistente.

### O que é negociável num contrato de contractor

| Item | Negociável? | Observação |
|---|---|---|
| Valor / rate | Sim, sempre | O item principal |
| Data de início | Sim, facilmente | Boa moeda de troca |
| Dias de PTO acordados | Sim, frequentemente | Muitas vezes mais fácil que dinheiro |
| Quem paga taxas de plataforma | Sim | Poucos pedem e muitos conseguem |
| Reajuste anual em cláusula | Sim, e vale muito | Raramente pedido |
| Verba de equipamento / home office | Sim, geralmente | Valor pequeno, resistência baixa |
| Aviso prévio simétrico | Sim | |
| Título | Às vezes | Depende de níveis internos |
| Signing bonus | Raro em contractor | Existe, mas incomum |
| Equity | Geralmente não para contractor | Pergunte, não conte com isso |
| Benefícios de saúde | Normalmente não | Às vezes vira stipend |

### Como pedir sem risco

Padrão que funciona: **entusiasmo genuíno + número específico + justificativa de mercado + porta aberta.**

```
Thanks — I'm genuinely excited about this, and I want to say that
first: I want to work with this team.

On the rate: based on what I've seen for senior backend contractors
with this scope working US hours, and on where my other conversation
is landing, I was targeting $X. If you can get to that, I'm ready to
sign today.

If the rate is fixed, I'd be glad to look at other pieces — an agreed
PTO allowance, or a written six-month review of the rate would both
move this for me.
```

Substitua `$X` por um valor anual único em USD, derivado da tabela de faixas de `vagas-remotas-no-exterior.md` para a sua stack e senioridade, ajustado para cima quando o escopo da vaga for maior que o típico do nível.

Funciona porque "ready to sign today" converte incerteza em fechamento — é o que mais destrava orçamento — e a alternativa no final impede o impasse binário.

Regras: **negocie por escrito** quando possível (e-mail dá tempo de pensar e cria registro); **um número, não uma faixa** — a fase importa: na triagem, quando ninguém sabe ainda o escopo, faixa é a resposta certa; aqui, com uma oferta já emitida, dar faixa faz você receber o piso dela; **peça uma vez, com clareza** (três rodadas sucessivas desgastam); e **nunca ameace** — "I have another offer, so you need to..." é o único jeito de perder uma oferta negociando.

### Competing offer

A alavanca mais forte que existe, e só funciona se for verdadeira:

```
I want to be transparent: I'm at final stage with another company and
expect a decision from them this week. You're my first choice, and I'd
rather not run this as an auction — is there room on the rate? If there
is, I'll close with you and stop the other process.
```

Nunca invente oferta concorrente. Empresas às vezes pedem detalhes, o mercado de contratação remota é surpreendentemente pequeno, e a exposição custa muito mais do que o ganho em jogo.

### Quando a oferta vem abaixo do esperado

Entenda de onde vem o gap. **A empresa ancorou no seu salário brasileiro?** Acontece, e é ilegítimo — recentre: `I understand my current contract is a reference point, but it's priced for the Brazilian market. I'd like to anchor on the value of this role.` **Banda rígida e você no piso?** Pergunte: `What's the range for this level, and where does this offer sit in it?` — piso de banda com sua experiência é argumento. **Te avaliaram um nível abaixo?** Pergunte direto: `Was I evaluated at the mid level rather than senior? I'd like to understand the reasoning.` Às vezes é corrigível com um contexto que faltou na entrevista.

### Quando **não** negociar

Quando a oferta já veio acima da sua expectativa e do mercado — pegue; negociar por esporte tem custo relacional. Quando você já negociou e recebeu um "não" claro e o resto do pacote é bom: insistir depois de um não firme sinaliza dificuldade em ler contexto, e o hiring manager registra isso. Quando você não tem alternativa, está com urgência financeira real e a oferta é razoável — aceitar e renegociar em 12 meses de dentro é jogada legítima. E em startup muito pequena onde o orçamento é visivelmente o que é: aí negocie PTO, equipamento ou revisão futura, não o rate.

### Quando aceitar uma oferta abaixo do ideal

Aceite se é sua primeira vaga internacional (o primeiro contrato tem valor de sinalização enorme para o segundo), se empresa e time são claramente bons, se existe promessa crível de revisão, ou se o valor — mesmo abaixo do mercado americano — é muito acima da sua alternativa local. A segunda vaga internacional se negocia de uma posição completamente diferente da primeira.

## 13. Depois do "não"

Pedir feedback vale, com expectativa calibrada: empresas americanas frequentemente não dão feedback detalhado por política jurídica, mas o recrutador às vezes dá algo útil informalmente.

```
Thanks for letting me know — no hard feelings, and I appreciate you
keeping me posted through the process.

If there's anything specific you can share about where I fell short,
I'd genuinely use it. And if a closer fit opens up later, I'd like to
be in the conversation.
```

Curto, sem argumentar contra a decisão, e mantém a porta aberta. Discutir o mérito da rejeição é o único jeito de tornar o "não" permanente.

O cooldown de reaplicação costuma ser de 6 a 12 meses, e algumas empresas o registram formalmente no ATS — reaplicar em 3 semanas para outra vaga da mesma empresa quase sempre dá rejeição automática. Exceção: rejeição por fit de vaga (não por desempenho) com um "keep in touch" do recrutador permite voltar em 3 a 4 meses, desde que com um sinal novo — projeto entregue, certificação, mudança de escopo no trabalho.

Manter o relacionamento com o recrutador é a parte mais subestimada do processo inteiro. Recrutadores mudam de empresa constantemente, e quem gostou de você em 2025 pode te chamar para algo muito melhor em 2027, de outra empresa. O mínimo é conectar no LinkedIn depois do processo, inclusive depois do "não". O melhor é uma mensagem a cada 4 a 6 meses, curta, com um sinal real: `just shipped the ledger rewrite I mentioned in our interview — thought of you`. Não é networking performático; são cinco linhas duas vezes por ano com pessoas que literalmente contratam.

E quando um recrutador te procurar para uma vaga que não serve, **responda mesmo assim**. Um "not right now, but here's what would interest me" mantém você na cabeça dele; silêncio te apaga da lista.

## 14. Tabela de diagnóstico

Encontre onde você está morrendo; a causa mais provável costuma ser a primeira linha correspondente.

| Onde você morre | Causa mais provável | O que consertar |
|---|---|---|
| Nenhuma resposta a candidaturas (>30 enviadas) | Easy Apply em massa em vagas geo-restritas | Filtrar por "worldwide/global", aplicar no ATS, buscar referral |
| Nenhuma resposta, vagas corretas, perfil sólido | Título/headline desalinhado com o que o recrutador busca; keywords ausentes | Alinhar título ao termo de mercado; revisar skills e resumo |
| Nenhum InMail de recrutador nunca | Perfil invisível no search (headline, skills, open-to-work off) | Trabalhar o perfil — outro arquivo desta skill |
| Descartado no formulário | Knockout question mal respondida (autorização, sponsorship, salário) | Rever seção 6; nunca deixar salário absurdo; explicar contractor |
| Recruiter screen sempre é a última etapa | Inglês falado travado, ou pedido salarial fora da faixa | Aquecimento antes da call; pitch ensaiado; recalibrar número |
| Passa no recruiter, morre no hiring manager | Não pesquisou a empresa; não articula impacto; sem perguntas | Preparar 2 histórias profundas + 4 perguntas específicas do time |
| Reprova em live coding com solução correta | Não verbalizou o raciocínio; não perguntou requisitos | Praticar codificar falando em inglês, gravar e rever |
| Reprova em live coding sem terminar | Lacuna real de prática algorítmica | 4–6 semanas de prática estruturada por padrão |
| Reprova em system design | Pulou requisitos; citou tecnologia sem trade-off; overengineering | Roteiro fixo da seção 8; desenhar 6 sistemas em voz alta |
| Reprova em behavioral | Respostas longas e sem estrutura; "we" no lugar de "I" | 8 histórias em STAR, cronometradas em 2 min |
| Take-home reprovado | Sem testes, sem README, difícil de rodar | README com trade-offs; um comando para rodar; testes do core |
| Chega no final e não recebe oferta | Perde para candidato local/mais barato, ou dúvida sobre fuso | Antecipar fuso com números; reforçar histórico remoto comprovado |
| Recebe ofertas sempre abaixo do mercado | Ancorou no salário brasileiro; nunca negociou | Ancorar na banda da vaga; usar o script da seção 12 |
| Passa em processos mas desiste dos contratos | Não perguntou sobre taxas, PTO, reajuste antes de assinar | Checklist da seção 11 por escrito, antes da assinatura |
| Muitos processos, nenhum avança | Volume sem foco — 40 candidaturas rasas | 5 a 8 candidaturas bem feitas por semana rendem mais que 80 rasas |

## 15. Resumo operacional

1. Easy Apply em massa é trabalho emocional; referral e resposta a InMail são o funil real.
2. Tire foto, idade e CPF do currículo. Uma coluna, uma página, PDF com texto selecionável.
3. Todo bullet: ação + contexto + resultado. Se descreve o cargo e não o trabalho, reescreva ou apague.
4. Datas e títulos batem exatamente entre LinkedIn e currículo. O resto pode variar.
5. "Authorized to work in the US" é **No** para quem fica no Brasil — explique que é contractor, nunca minta aqui.
6. Tenha o número em USD anual pronto antes da primeira call. Você vai ser perguntado.
7. Em live coding e system design avalia-se o pensamento verbalizado, não o silêncio produtivo.
8. Behavioral: 8 histórias, STAR, 2 minutos, "I" nas ações.
9. Antes de assinar: moeda, taxas, PTO, reajuste, aviso prévio, política de remoto — por escrito.
10. Negocie uma vez, com um número, com entusiasmo e sem ameaça. E saiba quando não negociar.
11. Não se candidate quando a vaga é geo-restrita, está dois níveis acima ou o fuso é impossível. Não é desistência, é preservar o funil.
