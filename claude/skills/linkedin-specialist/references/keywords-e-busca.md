# Keywords e busca: como ser encontrado no LinkedIn

Este arquivo trata de uma coisa só: **por que o seu perfil aparece (ou não) quando um recrutador procura alguém como você**. Não é sobre escrever bonito, não é sobre conteúdo, não é sobre networking. É sobre indexação e recuperação de informação.

O público aqui é o dev brasileiro mid/sênior que quer uma vaga remota em empresa de fora. Esse cenário tem particularidades — vocabulário em inglês, filtro de localização, disponibilidade de fuso — que mudam bastante o cálculo em relação a quem procura vaga CLT em São Paulo.

---

## 1. O modelo mental correto

Pare de pensar no perfil como uma página de apresentação. Pense assim:

- **O seu perfil é um documento indexado.** O LinkedIn quebra o texto dele em campos, dá peso diferente para cada campo e guarda isso num índice invertido.
- **O recrutador é um usuário fazendo uma query.** Ele digita termos numa caixa de busca (normalmente no LinkedIn Recruiter, não na busca comum) e recebe uma lista ordenada.
- **Otimizar o perfil é fazer a query dele bater no seu documento.**

Essa é a coisa toda. Se ele busca `"backend engineer" AND Go` e você escreveu "Desenvolvedor de Software" na headline e "Golang" só uma vez no meio de um parágrafo, você tem chance ruim de aparecer — não porque você é pior, mas porque o seu documento não casa com a query.

Duas consequências práticas que quase ninguém internaliza:

**(a) Não existe "o melhor perfil".** Existe perfil que casa com certas queries. Um perfil otimizado para `Site Reliability Engineer` é diferente de um otimizado para `Backend Engineer`. Escolher é obrigatório. Perfil que tenta casar com tudo casa mal com tudo, porque dilui os termos que importam.

**(b) Isso não é truque, é vocabulário.** A diferença entre "escrever a palavra que o outro usa" e "enganar o algoritmo" é enorme. Escrever `Kubernetes` porque você trabalha com Kubernetes é comunicação. Escrever `Kubernetes` porque você viu num vídeo é fraude que quebra na primeira entrevista técnica. A regra que resolve 100% dos casos ambíguos: **você só otimiza a forma como diz o que é verdade; nunca o conteúdo.**

Quando o texto do seu perfil e a sua realidade divergem, você não ganhou uma vaga — você comprou uma entrevista que vai queimar você com um recrutador que anota isso no ATS dele.

---

## 2. Onde as palavras-chave pesam de fato

O LinkedIn não publica os pesos e muda o ranking com frequência. Mas o padrão observado de forma consistente ao longo dos anos, e que é coerente com como qualquer sistema de busca funciona, é este:

### Peso alto

| Campo | Por que pesa | Observação prática |
|---|---|---|
| **Headline** | Campo curto, altamente ponderado, e é o que aparece na lista de resultados | O ativo mais valioso do perfil inteiro. Campo curto — escreva para caber com folga |
| **Cargo da experiência atual** | Campo estruturado, usado tanto em ranking quanto em filtro de "current title" | O recrutador filtra por título atual com muita frequência |
| **Seção de Skills** | Campo estruturado, casado com o skills tagging de vagas | Termo aqui é entidade, não texto solto |
| **Cargos de experiências anteriores** | Alimenta filtro de "past title" | Recrutador buscando senioridade olha a trajetória |

### Peso médio

| Campo | Observação |
|---|---|
| **About (Sobre)** | Texto longo; contribui, mas cada termo vale menos por diluição |
| **Descrições de experiência** | Idem. É onde vão os termos de cauda longa (nomes de ferramenta específicos) |
| **Nome da empresa** | Recrutador filtra por empresa. Se você trabalha em empresa desconhecida fora do Brasil, isso trabalha contra você — nada a fazer além de descrever a empresa em uma linha |
| **Certificações e cursos** | Batem em queries por certificação (`AWS Certified`, `CKA`) |
| **Projetos, publicações, voluntariado** | Contribuem pouco, mas são o lugar honesto para termos que você não pode reivindicar como experiência profissional |

### Peso baixo ou nenhum

- **Recomendações (o texto)** — quase nada em keyword matching. Valem como sinal social, não como texto indexado.
- **Comentários e reações em posts** — não entram na busca de perfis.
- **Texto dentro de imagens** (banner, carrossel, PDF de portfólio) — não é lido.
- **Lista de "keywords" no fim do About** — o clássico `#java #python #aws #devops #cloud #agile` empilhado no rodapé. Isso pesa pouquíssimo, sinaliza desespero para qualquer humano que leia, e ocupa espaço que renderia mais com uma frase concreta. Não faça.
- **Nome com sufixo de cargo** — colocar "João Silva | Senior Backend Engineer" no campo de nome. O LinkedIn desencoraja, e o efeito prático costuma ser a remoção do texto extra. Além disso, quebra o match do seu nome com verificação de identidade e background check. Não vale o ganho marginal.

**Conclusão operacional:** se você tem uma hora para investir, gaste 40 minutos na headline + cargo atual + skills, e 20 no resto. A distribuição de retorno é assim mesmo.

---

## 3. Boolean search na prática

Recrutador de tech sério não usa a busca do LinkedIn como você usa. Ele usa o LinkedIn Recruiter, que aceita boolean. Entender a sintaxe é entender o inimigo — ou melhor, entender o cliente.

### Sintaxe

| Operador | Efeito | Exemplo |
|---|---|---|
| `AND` | Ambos os termos precisam existir | `Go AND Kubernetes` |
| `OR` | Qualquer um dos termos | `Go OR Golang` |
| `NOT` | Exclui perfis com o termo | `NOT recruiter` |
| `"aspas"` | Frase exata | `"software engineer"` |
| `(parênteses)` | Agrupamento; define precedência | `(Go OR Golang) AND Kubernetes` |
| `*` | Curinga (suporte irregular e variável entre superfícies de busca; nem sempre funciona) | `develop*` |

Precedência padrão, quando não há parênteses: aspas > parênteses > `NOT` > `AND` > `OR`. Recrutador experiente parenteiza tudo justamente para não depender disso.

**Detalhe que decide muita coisa:** `"software engineer"` entre aspas **não** casa com "Software Engineering" nem com "Engenheiro de Software". O casamento é bem mais literal do que as pessoas imaginam. Sinônimo automático existe em alguns campos estruturados (skills, títulos normalizados), mas você não deve contar com ele.

### 15 queries reais e o que cada uma exige do seu perfil

**1.**
```
("software engineer" OR "backend engineer" OR "backend developer") AND (Go OR Golang) AND Kubernetes NOT recruiter
```
O `NOT recruiter` está aí porque recrutadores técnicos poluem os resultados (têm "Golang" no perfil por recrutarem gente de Golang). Implicação para você: se o seu About diz "ajudo empresas a contratar devs Go", você acabou de ser excluído. Cuidado com texto que faz você parecer recrutador, consultor ou vendedor.

**2.**
```
("senior software engineer" OR "sr software engineer" OR "senior developer") AND (Python OR Django) AND (AWS OR GCP)
```
Note `"sr software engineer"`. Recrutador bom cobre abreviação. Recrutador mediano não. Você não controla isso — mas controla escrever a forma extensa (`Senior`), que é a mais buscada. Escreva `Senior`, não `Sr.`.

**3.**
```
(React OR ReactJS OR "React.js") AND (TypeScript OR TS) AND NOT (student OR intern OR trainee OR bootcamp)
```
O `NOT` de senioridade. Se você é sênior mas deixou "Bootcamp XPTO — 2019" na experiência (não na educação), você entra no filtro de exclusão. Curso vai em Educação/Certificações, nunca em Experiência.

**4.**
```
"machine learning" AND (PyTorch OR TensorFlow) AND (Python) AND ("MLOps" OR "model deployment" OR "production")
```
O terceiro bloco separa quem treina modelo em notebook de quem coloca em produção. Se você faz o segundo, a palavra `production` precisa estar escrita no seu perfil. Ela quase nunca está.

**5.**
```
("data engineer" OR "analytics engineer") AND (Spark OR Databricks OR dbt) AND (SQL) AND (Airflow OR Dagster OR Prefect)
```
Query por ferramenta de orquestração. Nome de ferramenta é cauda longa perfeita para descrição de experiência: pouca gente escreve, quem busca busca literal.

**6.**
```
("site reliability engineer" OR SRE OR "platform engineer" OR "infrastructure engineer") AND (Terraform OR Pulumi) AND (Kubernetes OR K8s)
```
`SRE` sem aspas casa com a sigla isolada. Se você só escreveu "Site Reliability Engineering" por extenso, você depende do OR do recrutador. Escreva as duas formas em algum lugar do perfil.

**7.**
```
("engineering manager" OR "tech lead" OR "team lead") AND ("hiring" OR "mentoring" OR "1:1") AND NOT (recruiter OR "talent acquisition")
```
Query de liderança. Note que ela busca **evidência de atividade**, não título. `mentoring`, `hiring`, `1:1` são o que separa tech lead de verdade de tech lead nominal. Escreva o verbo.

**8.**
```
("full stack" OR "fullstack" OR "full-stack") AND (Node OR "Node.js" OR NodeJS) AND (React OR Vue OR Angular)
```
Três grafias de "full stack" e três de Node. Isso mostra por que **listar as duas ou três formas do mesmo termo não é redundância, é cobertura**. Não em sequência ("Node/Node.js/NodeJS" fica ridículo), mas distribuídas: uma na headline, outra em skills, outra na descrição.

**9.**
```
("software engineer" OR developer) AND (Brazil OR Brasil OR "Latin America" OR LATAM OR "South America")
```
Query de sourcing regional. Muito comum em empresas dos EUA contratando via EOR. Isso é a favor do brasileiro — e depende de a palavra `Brazil` (em inglês) estar em algum lugar legível. Isso normalmente vem do campo de localização, mas escrever `Based in Brazil` no About cobre o caso.

**10.**
```
("software engineer" OR "backend engineer") AND (fintech OR payments OR "payment processing" OR PCI) AND (Java OR Kotlin)
```
Query por domínio. Você provavelmente escreveu o que fez tecnicamente e esqueceu de escrever o **domínio de negócio**. Domínio é diferenciador enorme para vaga sênior: "pagamentos", "healthcare", "logística", "e-commerce", "seguros". Escreva em inglês.

**11.**
```
(QA OR "quality assurance" OR SDET OR "test engineer") AND (Cypress OR Playwright OR Selenium) AND automation
```
Cinco jeitos de nomear a mesma função. Se você é SDET e escreveu só "Analista de Testes", você é invisível para toda essa query.

**12.**
```
("mobile engineer" OR "iOS engineer" OR "Android engineer") AND (Swift OR Kotlin OR "React Native" OR Flutter) AND NOT (Ionic OR Cordova)
```
`NOT` por tecnologia que o time considera legado. Você não controla, mas repare: mencionar tecnologia antiga sem contexto pode te excluir. Se você usa Cordova hoje, aparecer nessa busca não seria bom para você de qualquer forma.

**13.**
```
("staff engineer" OR "principal engineer" OR "senior staff") AND (distributed OR "distributed systems" OR scalability OR "high availability")
```
Nível staff+. Note que a segunda metade é conceito, não ferramenta. Perfil sênior/staff que só lista ferramenta não bate em query de staff. Escreva o problema que você resolve, não só a stack.

**14.**
```
("software engineer") AND ("open to work" OR "seeking" OR "available") AND (remote OR "remote-first")
```
Query oportunista, comum em agência. Explica por que `remote` escrito em texto tem valor real — o filtro estruturado de preferência remota nem sempre é o que ele usa.

**15.**
```
(engineer OR developer) AND (English OR "fluent English" OR "advanced English" OR bilingual) AND Brazil
```
Query específica de quem contrata na América Latina. Nível de inglês é o gargalo declarado do sourcing no Brasil. Se você tem inglês de trabalho, isso precisa estar escrito com essas palavras. Vale mais que meia dúzia de siglas de framework.

**16 (bônus, o mais brutal).**
```
"software engineer" AND Go AND Kubernetes AND AWS AND Terraform AND PostgreSQL AND "open source"
```
Sete `AND` encadeados. Muitos recrutadores júnior escrevem assim e depois reclamam que "não tem candidato no Brasil". Você não pode consertar a query dele. Você pode garantir que todos os termos que são verdade sobre você estejam escritos em algum lugar — porque **um termo verdadeiro que você não escreveu é o jeito mais barato de sumir de um `AND`**. O Recruiter relaxa consultas restritivas e sugere expansões, e campos estruturados aceitam algum sinônimo — mas nada disso é garantido, e depender dele é apostar. A lição prática continua a mesma: liste as variantes do termo.

Essa última é a justificativa mais forte para completude: o custo de omitir um termo verdadeiro não é "aparecer mais embaixo", é "não aparecer".

---

## 4. Vocabulário: o termo dele vs o termo seu

Esta é a maior fonte de perda para dev brasileiro buscando vaga fora. Você descreve sua carreira com o vocabulário do RH brasileiro; ele busca com o vocabulário do mercado americano. São dicionários diferentes.

### Títulos: brasileiro → internacional

| Título comum no Brasil | Equivalente internacional buscado |
|---|---|
| Desenvolvedor Júnior | Junior Software Engineer / Software Engineer I |
| Desenvolvedor Pleno | Mid-level Software Engineer / Software Engineer II |
| Desenvolvedor Sênior | Senior Software Engineer / Software Engineer III |
| Desenvolvedor Full Stack | Full Stack Engineer / Full Stack Developer |
| Analista de Sistemas | Software Engineer / Systems Analyst (raro fora) |
| Analista de Suporte | Support Engineer / Technical Support Engineer |
| Analista de Testes / QA | QA Engineer / SDET / Test Automation Engineer |
| Analista de Dados | Data Analyst |
| Engenheiro de Dados | Data Engineer |
| Arquiteto de Software | Software Architect / Principal Engineer |
| Coordenador de TI | Engineering Manager / Technical Lead |
| Gerente de Projetos | Project Manager / Delivery Manager |
| Especialista em Infraestrutura | Infrastructure Engineer / Platform Engineer |
| Desenvolvedor Mobile | Mobile Engineer / iOS Engineer / Android Engineer |
| DevOps | DevOps Engineer / Platform Engineer / SRE |
| Product Owner | Product Owner / Product Manager (não são a mesma coisa lá fora — cuidado) |

Observações que importam:

- **"Pleno" não existe em inglês.** Traduzir literalmente ("Full Developer") é errado. O equivalente funcional é `Mid-level` ou o numeral `II`. Na dúvida, muitos perfis simplesmente omitem o nível em pleno e usam `Software Engineer` puro — o que é uma escolha razoável, porque a senioridade fica evidente pelo tempo de carreira.
- **`Engineer` vs `Developer`.** No mercado americano de produto, `Engineer` é a palavra dominante. `Developer` é mais comum em consultoria e em alguns mercados europeus. Recrutador experiente busca as duas com `OR`. Se você precisa escolher uma, escolha `Engineer` para vaga de produto nos EUA.
- **`Senior`, não `Sênior`.** Perfil em inglês, título em inglês. Perfil bilíngue é possível (o LinkedIn permite versões do perfil por idioma), mas a versão principal, para quem quer vaga fora, deve ser a em inglês.

### Stack: sinônimos e siglas

| Termo | Variantes a cobrir | Comentário |
|---|---|---|
| Go | Go, Golang | `Go` sozinho é ambíguo em busca de texto livre; `Golang` é inequívoco. Cubra os dois |
| JavaScript | JavaScript, JS | Escreva `JavaScript` como forma principal |
| TypeScript | TypeScript, TS | Idem |
| Kubernetes | Kubernetes, K8s | `K8s` é usado por gente técnica; `Kubernetes` por recrutador. Ambos |
| React Native | React Native, RN | `RN` sozinho é ruim demais para valer o espaço; prefira o extenso |
| Machine Learning | Machine Learning, ML | Ambos são muito buscados |
| Node.js | Node.js, NodeJS, Node | Escreva `Node.js` como principal |
| PostgreSQL | PostgreSQL, Postgres | Ambos aparecem em queries |
| CI/CD | CI/CD, Continuous Integration, Continuous Delivery | O extenso aparece em job description; a sigla em query |
| Infrastructure as Code | IaC, Infrastructure as Code | Ambos |
| Amazon Web Services | AWS | Ninguém busca o extenso. `AWS` basta |
| .NET | .NET, dotnet, C# | Pontuação atrapalha match; `C#` costuma ser mais confiável |
| Objeto-relacional / ORM | ORM, e o nome do ORM (Prisma, Hibernate, SQLAlchemy) | Nome específico é cauda longa valiosa |

**Por que listar as duas formas.** Porque a busca casa strings, não conceitos, e você não sabe qual forma o recrutador vai digitar. O custo de escrever as duas é baixo se você distribui: uma na headline, a outra em skills ou na descrição. O custo fica alto — e vira ruído — se você as empilha lado a lado. `Golang / Go / GoLang / go-lang` numa mesma linha lê como spam para humano e não ganha nada em máquina depois da segunda ocorrência.

Regra prática: **cada termo importante deve aparecer 2 a 3 vezes no perfil inteiro, em campos diferentes.** Acima disso, o retorno é zero e o custo de legibilidade é real.

### Termos em português: manter ou não?

Se você **só** quer vaga fora, o perfil deve ser todo em inglês e os termos em português são desperdício de espaço. Se você quer manter a porta aberta para o mercado brasileiro (posição defensável — o mercado brasileiro também paga bem e é mais fácil de fechar), a solução não é misturar os dois idiomas no mesmo texto. É usar o recurso de perfil em múltiplos idiomas do LinkedIn: uma versão em inglês e uma em português. Misturar produz um texto que lê mal nos dois idiomas.

---

## 5. Cargo interno esquisito da empresa

Empresa brasileira adora título que não significa nada fora dela: "Analista de Sistemas Sênior III", "Especialista de Tecnologia II", "Consultor de TI Pleno", "Ninja de Código", "Rockstar Developer", "Analista de TI - Faixa 4".

Esses títulos causam três problemas simultâneos: não batem em nenhuma query, não comunicam senioridade e, nos casos "criativos", queimam você com recrutador sênior.

### Como resolver sem mentir

O campo de cargo do LinkedIn não é um documento jurídico e não precisa ser idêntico ao registro na carteira. Ele precisa ser **uma descrição honesta da função**. As opções, em ordem de preferência:

**Opção 1 — Título funcional puro.** Você era "Analista de Sistemas Sênior III" e fazia trabalho de backend engineer sênior. Escreva:
```
Senior Backend Engineer
```
Isso é honesto: descreve o trabalho. Ninguém no mundo vai te acusar de fraude por não ter reproduzido a nomenclatura interna de faixa salarial da empresa.

**Opção 2 — Híbrido, quando o título interno tem valor.** Se o título oficial é reconhecível ou se você quer preservar a rastreabilidade:
```
Senior Backend Engineer (Analista de Sistemas Sênior III)
```
Formato defensável, mas paga um preço: o parêntese ocupa espaço e polui o campo mais valioso depois da headline. Só compensa em empresa grande onde o título interno é conhecido (bancos, big techs brasileiras).

**Opção 3 — Título oficial no cargo, funcional na primeira linha da descrição.** Mais conservador, e a única opção se você trabalha em lugar onde o RH confere o título literalmente (setor público, alguns bancos):
```
Cargo: Analista de Sistemas Sênior III
Descrição: Senior Backend Engineer working on payment processing systems...
```
Perde peso de campo, ganha em segurança. Se você está no setor público brasileiro, use esta.

### Onde isso vira mentira

A fronteira é **senioridade e escopo**, não nomenclatura.

- Trocar "Analista de Sistemas Sênior" por "Senior Software Engineer": **traduzir**. Faça.
- Trocar "Desenvolvedor Pleno" por "Senior Software Engineer" porque você acha que merece: **mentir**. Não faça.
- Trocar "Desenvolvedor" por "Tech Lead" porque você às vezes revisa PR dos outros: **mentir**. Tech Lead tem escopo definido (direção técnica, decisões de arquitetura, responsabilidade sobre o time). Não faça.
- Trocar "Estagiário" por "Junior Engineer": **mentir**, e das que quebram fácil em verificação de emprego.

O argumento prático, não o moral: **empresa estrangeira que contrata brasileiro remoto faz verificação de emprego.** Contratação via EOR (Deel, Remote.com, Globalization Partners, Velocity Global) e via PJ com contrato internacional passa por background check em algum nível — às vezes leve, às vezes com confirmação direta com o RH anterior. O título inflado aparece na diferença entre o que você declarou e o que o RH anterior confirma. E o resultado disso não é uma conversa constrangedora; é rescisão de oferta, às vezes depois de você já ter pedido demissão do emprego atual.

O upside da mentira é uma entrevista a mais. O downside é ficar desempregado no meio de uma mudança de emprego. A matemática é péssima.

---

## 6. Filtros que você não controla pelo texto

Boolean é a metade visível. A outra metade são **filtros estruturados**, e eles são mais letais porque eliminam você silenciosamente — você nunca aparece na lista, não há "quase".

| Filtro | Como funciona | Impacto para você |
|---|---|---|
| **Localização** | Campo estruturado da sua região; o recrutador seleciona uma ou mais regiões | O mais letal. Detalhado abaixo |
| **Anos de experiência** | Estimado pelo LinkedIn a partir das datas das suas experiências | Lacunas e experiências sem data bagunçam a estimativa |
| **Empresa atual / anterior** | Entidade da empresa | Empresa não cadastrada como página do LinkedIn não entra no filtro. Se a sua empresa não tem página, você some desse filtro |
| **Idioma do perfil** | Idioma detectado/declarado | Perfil em português pode ser filtrado fora em sourcing internacional |
| **Nível de senioridade** | Derivado do título e do tempo | Título esquisito quebra a inferência (ver seção 5) |
| **Open to work** | Sinal explícito que você liga nas configurações | Recrutador com Recruiter vê isso e frequentemente filtra por ele |
| **Escola / formação** | Entidade da instituição | Pouco relevante para vaga remota internacional |
| **Skills declaradas** | Entidades de skill | Filtro direto; skill não declarada = não filtrável |

### O filtro de localização, em detalhe

Este é o ponto onde mais gente perde a vaga e não sabe.

Recrutador de empresa americana abrindo uma vaga "remote" frequentemente aplica o filtro `United States` — porque a vaga é "remote (US)", ou porque a empresa só contrata onde tem entidade legal, ou porque ele nem pensou no assunto e o filtro veio pré-preenchido pelo país da vaga. Você, morando no Brasil, simplesmente não existe nessa busca. Não é ranking baixo. É ausência.

O que dá para fazer, honestamente:

1. **Aceite que o filtro de localização é um filtro real de mercado, não um bug.** Boa parte das vagas "remote" dos EUA é genuinamente restrita aos EUA por razões fiscais e legais. Aparecer nelas não te contrataria; te daria uma rejeição no estágio 2.

2. **Foque nas empresas que contratam LATAM por design.** Elas existem em número crescente e buscam explicitamente por `Brazil`, `LATAM`, `Latin America`, `remote-first`. As queries 9 e 15 da seção 3 são exatamente essas. Otimize para elas: `Brazil` legível, inglês declarado, fuso declarado.

3. **Deixe a localização clara e correta.** Se você mora em Brasília, escolha Brasília ou "Distrito Federal, Brazil". Não deixe em branco e não deixe genérico demais.

4. **Cidade grande vs cidade pequena.** Aqui há uma decisão real. O LinkedIn resolve localização por área metropolitana. Se você mora em Ponta Grossa, você pode declarar "Ponta Grossa, Paraná, Brazil" ou a área metropolitana de Curitiba, se ela for oferecida como opção para a sua região. Para vaga internacional remota, isso **quase não importa** — o recrutador filtra por país, não por cidade. Para vaga híbrida ou presencial no Brasil, importa muito. Escolha a cidade real; se a sua cidade pequena estiver dentro de uma região metropolitana que o LinkedIn oferece, escolher a região metropolitana é legítimo e amplia o alcance.

5. **Marcar preferência por trabalho remoto nas configurações de vaga.** Isso é diferente do campo de localização e é onde você diz que aceita remoto. Faça isso.

### Onde isso vira mentira: declarar que mora em outro lugar

A tentação é óbvia: colocar "San Francisco Bay Area" ou "Lisbon, Portugal" na localização para passar pelo filtro. Não faça. Os motivos são práticos e não são pequenos:

- **Você passa no filtro e falha na primeira pergunta.** "Are you authorized to work in the US?" é a primeira ou segunda pergunta de qualquer screening. A conversa acaba em 90 segundos, e o recrutador marca você como *misrepresented location* no ATS dele. Alguns ATSs guardam isso por anos e são compartilhados dentro de grupos de agências.

- **O EOR pega imediatamente.** Contratação via Deel/Remote.com/Velocity exige comprovante de residência, documento fiscal do país e conta bancária local. O modelo inteiro depende do país onde você reside, porque é ele que define a entidade contratante, os impostos e o contrato. Não existe "vou resolver depois". A discrepância aparece no onboarding, antes do primeiro pagamento.

- **Background check em contratação internacional inclui verificação de endereço** com frequência crescente. É trivial de verificar e é exatamente o tipo de inconsistência que faz um compliance team cancelar uma oferta.

- **Você contamina o próprio funil.** O LinkedIn usa sua localização para te recomendar vagas. Declarando um país onde você não pode trabalhar, você passa a receber vagas para as quais é inelegível e para de receber as vagas LATAM que seriam suas.

O resumo é: essa mentira específica não é "arriscada", ela é **estruturalmente incompatível** com o mecanismo pelo qual você seria contratado. Não há caminho em que ela funcione até o fim.

**O que é honesto declarar:** que você mora no Brasil, que trabalha remoto, que tem sobreposição com fusos americanos e europeus, que já trabalhou com times distribuídos, e que está disponível para contratação via EOR ou como contractor. Tudo isso é verdade e tudo isso resolve as objeções reais do recrutador melhor do que a mentira resolveria.

---

## 7. Declarar disponibilidade remota e fuso

Três lugares, com funções diferentes:

**(a) Preferências de vaga nas configurações.** Existe uma seção de preferências onde você indica tipos de trabalho aceitos (incluindo remoto), cargos de interesse e disponibilidade. Ela alimenta filtros e recomendações. A localização exata dos controles e os rótulos mudam com frequência — procure por preferências de busca de emprego / "open to work" nas configurações do seu perfil. Preencha, e escolha a visibilidade (só recrutadores vs público) conscientemente: o badge público de "Open to Work" tem custo reputacional debatível e às vezes atrai spam; a visibilidade restrita a recrutadores não tem esse problema e é a escolha padrão sensata para quem está empregado.

**(b) Headline.** É um campo curto e cada caractere é caro. `Remote` cabe e vale, se o remoto é o seu ponto de venda. Exemplo:

```
Senior Backend Engineer | Go, Kubernetes, AWS | Remote from Brazil (UTC-3)
```

Isso responde, em uma linha, às três perguntas do recrutador de LATAM: o que você faz, com o quê, e se dá para o fuso dele. Não desperdice a headline com `Passionate about technology | Lifelong learner | Coffee lover`. Zero dessas palavras é buscada por alguém contratando.

**(c) About.** É onde cabem os detalhes que não cabem na headline. Uma frase, no primeiro ou segundo parágrafo:

```
Based in Brazil (UTC-3), with 6+ hours of daily overlap with US Eastern and
partial overlap with European timezones. Available for full-time remote roles
via EOR or as an independent contractor.
```

Isso é denso em keyword (`Brazil`, `remote`, `EOR`, `contractor`, `UTC-3`) e é literalmente verdade. É a diferença entre "otimizar" e "mentir" resumida em quatro linhas.

Sobre o inglês, se ele é bom, diga com as palavras que são buscadas:
```
Fluent English — daily work with distributed teams across the US and Europe.
```
Se não é bom ainda, não escreva `fluent`. Escreva o que é verdade (`professional working proficiency`) ou não escreva nada. Essa mentira específica morre nos primeiros 30 segundos da primeira call, que é o pior lugar possível para ela morrer.

---

## 8. Skills

A seção de skills é o campo estruturado mais subutilizado do LinkedIn. Ela alimenta filtro, alimenta ranking e alimenta o match entre você e as vagas.

**Quantas.** Bem menos que o limite: **15 a 25 skills reais**, todas defensáveis numa entrevista técnica. Encher até o limite dilui o sinal. Quantas e quais declarar é assunto de `perfil-completo.md`; aqui interessa só o efeito na busca.

**Quais, em função da busca.** Priorize nesta ordem:

1. **Linguagens** que você usaria em produção amanhã (Go, Python, TypeScript).
2. **Plataformas e infra** (Kubernetes, AWS, Terraform, Docker, PostgreSQL).
3. **Frameworks e ferramentas** relevantes ao alvo (React, Django, Kafka, dbt).
4. **Domínios técnicos** (Distributed Systems, Microservices, System Design, API Design, Observability).
5. **Domínio de negócio**, se for diferencial (Payments, Fintech, E-commerce).

**Como ordenar.** As primeiras skills têm destaque visual e servem de resumo. Coloque no topo as três que definem o seu alvo — não as que você tem mais endossos. Se o seu alvo é backend Go e a skill com mais endossos é "Microsoft Excel" de dez anos atrás, a ordem está trabalhando contra você. Reordene, e apague o Excel.

**Por que skill genérica desperdiça espaço.** `Comunicação`, `Trabalho em equipe`, `Liderança`, `Resolução de problemas`, `Microsoft Office`, `Metodologias Ágeis`:

- Ninguém busca por elas. Nenhum recrutador de tech escreve `AND "trabalho em equipe"` numa query. Elas não recuperam você em nenhuma busca real.
- Elas não diferenciam. 100% dos candidatos alegam ter. Uma afirmação que todo mundo faz carrega zero informação.
- Elas ocupam as posições visíveis e diluem o perfil de skills que alimenta o matching de vagas.

A exceção real: soft skill **específica e verificável** (`Technical Writing`, `Mentoring`, `Incident Response`, `Public Speaking`) tem substância e aparece em query de vaga de liderança. `Comunicação` não.

**Skills e match de vagas.** O LinkedIn compara as skills declaradas na vaga com as suas e mostra ao recrutador algo do tipo "candidato tem 7 de 9 skills". Isso é um dos sinais mais concretos que ele vê. Skill que você tem mas não declarou **conta como zero** nessa comparação — não há inferência a partir do texto livre. É o argumento mais forte para preencher a seção com cuidado: é o campo com maior razão entre impacto e esforço no LinkedIn inteiro.

**Endossos.** Valem pouco. Não peça e não organize campanha de troca — nem com desconhecidos, nem com colegas. Se acontecerem naturalmente nas skills certas, ótimo; é no máximo um desempate visual. O dono do assunto é `perfil-completo.md`.

---

## 9. Conexões e recomendações como sinal de ranking

O LinkedIn não publica os pesos de ranking, então isto é inferência forte, consistente com como qualquer busca funciona: **o grau de conexão afeta a ordenação dos resultados.**

Na prática, perfis de 1º e 2º grau tendem a subir nos resultados de um recrutador, e a busca comum do LinkedIn (não o Recruiter) é bastante enviesada para a sua rede. Isso tem uma implicação direta e pouco intuitiva:

> Dois devs com perfis textualmente idênticos aparecem em posições diferentes para o mesmo recrutador, dependendo de quem cada um conhece.

Consequência prática: **conectar-se com recrutadores da sua área muda o que você aparece.** Não é sobre eles verem seu perfil naquele momento. É sobre você entrar no 1º grau deles — e, por transitividade, no 2º grau de centenas de outros recrutadores da mesma rede. Um recrutador de tech que trabalha com LATAM está conectado a dezenas de outros recrutadores de tech que trabalham com LATAM. Entrar nessa vizinhança do grafo é barato e tem efeito composto.

Como fazer sem ser desagradável:

- Conecte-se com recrutadores técnicos que anunciam vagas do seu perfil. Aceitação é alta; é literalmente o trabalho deles.
- Conecte-se com engenheiros das empresas que você quer. Isso te coloca no 2º grau dos recrutadores internos delas.
- Não mande pitch junto do convite. Convite sem nota, ou com uma linha factual, tem taxa de aceitação melhor do que parágrafo de venda.
- Volume importa mais do que se admite: sair de 200 para 800 conexões relevantes muda materialmente a sua visibilidade em busca. Mas **conexões relevantes** — encher com qualquer um degrada a qualidade das recomendações que o LinkedIn te dá e não ajuda no ranking para quem importa.

**Recomendações.** O texto de uma recomendação pesa pouco em keyword matching — não escreva recomendação pensando em SEO. O que ela faz: aumenta a taxa de conversão de quem já abriu seu perfil, e serve de prova social num momento em que o recrutador está decidindo se manda mensagem. Três a cinco recomendações específicas (nome do projeto, resultado concreto) valem mais que quinze genéricas. Recomendação de gestor direto e de par técnico são as que contam.

---

## 10. SSI (Social Selling Index)

O SSI é uma pontuação de 0 a 100 que o LinkedIn calcula em quatro dimensões (estabelecer marca profissional, encontrar as pessoas certas, engajar com insights, construir relacionamentos). Historicamente acessível em uma página dedicada de "social selling index" da própria LinkedIn.

O que você precisa saber:

- **É uma métrica de vendas, não de carreira.** Foi criada para o Sales Navigator, para medir uso da ferramenta por vendedores.
- **Recrutador não vê o seu SSI.** Não existe filtro por SSI. Não existe boost documentado por SSI no ranking de busca de talentos.
- **Ele mede atividade, não competência.** Você aumenta o SSI postando mais e conectando mais. Isso pode ou não ter relação com conseguir vaga.

Portanto: olhe uma vez por curiosidade, e ignore. Perseguir SSI é o exemplo mais puro de otimizar a métrica errada — todo o esforço vai para uma pontuação que nenhum decisor observa. O tempo gasto subindo SSI rende dez vezes mais gasto reescrevendo a headline ou preenchendo skills.

---

## 11. Como auditar o próprio perfil

Otimização sem medição é chute. Há quatro checagens que valem a pena, em ordem de utilidade.

### (a) Rode as queries do recrutador em você mesmo

Pegue as queries da seção 3 que descrevem a sua vaga alvo e rode na busca de pessoas do LinkedIn, filtrando por localização Brasil. Você aparece? Em que página?

Isso é aproximado — a busca comum não é o Recruiter, e ela é enviesada pela sua própria rede, o que te faz parecer mais visível do que você é. Mas serve para o teste binário que importa: **se você não aparece nem na sua própria busca enviesada a seu favor, o problema é grave e é de vocabulário.**

Registre em uma tabela simples:

| Query | Apareci? | Posição aproximada |
|---|---|---|
| `"senior backend engineer" AND Golang` | Sim | ~página 2 |
| `"backend engineer" AND Go AND Kubernetes` | Não | — |

A linha "Não" é a que te diz o que fazer: falta `Kubernetes` em campo de peso.

### (b) Veja o perfil deslogado

Abra uma janela anônima e acesse a URL pública do seu perfil. Isso mostra o que uma pessoa fora da sua rede vê, e frequentemente revela seções ocultas por configuração de visibilidade. Se o seu About está cortado ou as experiências não aparecem, você tem um problema de configuração que nenhuma keyword resolve.

### (c) Aparições em pesquisa

O LinkedIn expõe, na área de analytics do perfil, quantas vezes você apareceu em resultados de busca em um período recente, e frequentemente os termos e cargos associados a quem te encontrou. É a métrica mais próxima do que este documento trata.

**O que ela diz:** se o número sobe depois de você mudar a headline, a mudança funcionou. Se os cargos de quem te achou são "Technical Recruiter" e "Talent Partner", você está indexado para o público certo. Se são "Estudante" e "Analista Comercial", você está indexado errado.

**O que ela não diz:** nada sobre qualidade. Aparecer 500 vezes em buscas irrelevantes é pior do que aparecer 40 vezes em buscas do seu alvo, porque o primeiro caso costuma indicar que seu perfil é genérico demais. Nunca otimize esse número em si.

**Cuidado com a linha de base:** aparições variam com sazonalidade de contratação e com a sua própria atividade. Compare períodos equivalentes e não conclua nada a partir de uma semana.

### (d) Visualizações de perfil e "quem viu seu perfil"

Menos útil, mas o corte por **cargo de quem visitou** é informativo pelo mesmo motivo que o item anterior. Se recrutador nenhum abre seu perfil, o problema está em busca ou em headline (o que aparece na lista de resultados), não no conteúdo do perfil — porque o conteúdo nem chegou a ser lido.

Um diagnóstico rápido a partir do funil:

| Sintoma | Onde está o problema |
|---|---|
| Não apareço nas buscas | Vocabulário / campos de peso alto / filtro de localização |
| Apareço mas ninguém abre | Headline e foto — é o único que se vê na lista de resultados |
| Abrem mas não mandam mensagem | About e descrições de experiência: falta evidência concreta |
| Mandam mensagem mas para vagas erradas | Perfil genérico demais; falta escolher um alvo |

---

## 12. Checklist de otimização, priorizado por retorno

Faça na ordem. Pare quando o retorno marginal virar ruído — a seção 13 explica quando.

**Retorno alto (faça hoje, 60–90 minutos)**

1. Headline reescrita: cargo alvo em inglês + 2 a 4 tecnologias centrais + sinal de remoto/localização. Sem "passionate", sem "lifelong learner".
2. Cargo da experiência atual traduzido para o título internacional equivalente e honesto.
3. Skills: apagar as genéricas e as obsoletas; adicionar as verdadeiras e relevantes até 15–25; reordenar com as três do alvo no topo.
4. Localização preenchida corretamente (cidade real ou região metropolitana real) e preferência de trabalho remoto ligada nas configurações.
5. Primeiro parágrafo do About: o que você faz, com qual stack, com que tipo de sistema, morando onde, com que overlap de fuso, com que nível de inglês.

**Retorno médio (esta semana, 2–3 horas)**

6. Títulos das experiências anteriores traduzidos com o mesmo critério.
7. Cada experiência com 3 a 5 linhas de descrição contendo: sistema/domínio, stack literal, escala, resultado. É onde entram os termos de cauda longa (Kafka, Airflow, gRPC, Datadog).
8. Verificar cobertura de sinônimos: cada termo central aparece 2–3 vezes, em campos diferentes, sem empilhamento.
9. Domínio de negócio escrito em inglês (payments, healthcare, logistics, e-commerce).
10. Perfil em inglês como versão principal; versão em português como secundária, se você quer manter o mercado local.
11. URL pública personalizada (`/in/nome-sobrenome`) e foto profissional decente.

**Retorno baixo mas real (este mês)**

12. Recomendações: opcional e de retorno baixo — não entram na triagem, pesam no desempate entre finalistas. Se surgirem naturalmente, ótimo; não organize campanha (ver `perfil-completo.md`, dono do assunto).
13. Conexões: 30 a 50 recrutadores técnicos da sua área/região alvo e engenheiros das empresas de interesse.
14. Certificações relevantes cadastradas como entidade (não como texto solto no About).
15. Auditoria: rodar as queries em você mesmo e registrar o resultado.

**Retorno perto de zero (não faça)**

- Bloco de hashtags/keywords no fim do About.
- Perseguir SSI.
- Encher skills até o limite.
- Repetir o mesmo termo cinco vezes.
- Colocar cargo no campo de nome.
- Postar diariamente só para "alimentar o algoritmo" — conteúdo tem outros méritos, mas não melhora indexação de perfil para busca de talentos.

---

## 13. Quando a resposta certa é NÃO otimizar mais

Isto importa tanto quanto o resto do documento, porque otimização de perfil é viciante e tem retorno decrescente violento.

**Pare quando o checklist alto e médio estiver feito.** Depois disso, a variância entre um perfil bom e um perfil excelente é menor que a variância entre recrutadores. Você está ajustando a terceira casa decimal.

**Sinais de que você já passou do ponto:**

- Você está reescrevendo a headline pela sexta vez na mesma semana.
- Você está considerando adicionar termos que são "meio verdade".
- Você está lendo sobre o algoritmo do LinkedIn em vez de aplicar para vagas.
- Você está medindo aparições em pesquisa diariamente.

**O que rende mais que continuar otimizando, quando o básico está feito:**

1. **Aplicar para vagas.** Busca inbound (recrutador te acha) é um canal; aplicação direta é outro, e para dev brasileiro buscando fora ele costuma ser o maior. Perfil bom melhora a conversão da aplicação também.
2. **Melhorar o inglês.** Se o seu inglês é o gargalo, nenhuma keyword compensa. Esse é o investimento com maior retorno na carreira internacional de dev brasileiro, e não é perto.
3. **Referência humana.** Um ex-colega que já trabalha na empresa alvo vale mais que qualquer otimização de perfil. Indicação pula a etapa inteira da busca.
4. **Evidência pública de trabalho.** Repositório com código real, texto técnico, contribuição a projeto usado. Não porque indexa — porque converte quem já te encontrou.

**E o caso em que otimizar mais é ativamente ruim:** quando você começa a esticar a verdade para cobrir mais queries. Um perfil que aparece em 30% menos buscas mas é 100% defensável é estritamente melhor que o inverso, porque o funil não termina na busca. Ele termina numa entrevista técnica com alguém que faz o trabalho que você disse que faz.

A frase que resume o documento: **escreva a verdade sobre você com as palavras que a outra pessoa usa.** Todo o resto são detalhes de implementação.
