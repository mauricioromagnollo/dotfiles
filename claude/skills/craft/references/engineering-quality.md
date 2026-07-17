# Craft de Engenharia de Software — Síntese Sommerville + Pressman

**Fontes:** **[S]** Sommerville, 6ª ed. (594 pp.) · **[P]** Pressman, 7ª ed. (764 pp.). Ambos PDFs
**escaneados sem camada de texto** (`pdftotext` → 0 chars); extração por OCR (`pdftoppm -gray` →
`tesseract -l por`). Citações entre aspas são transcrições; erros óbvios de OCR corrigidos.

> ## ⚠️ Aviso sobre a Seção 2 — leia primeiro
> A escala clássica de **7 níveis de coesão** (funcional→coincidental) vem de Stevens/Myers/
> Constantine (1974) e do *structured design*. **Ela NÃO existe nestas duas edições.** Verifiquei por
> OCR direcionado em [P] cap. 8, [P] cap. 10, [P] cap. 23, [S] §10.3 e [S] cap. 28. Pressman **cita**
> [Ste74] em §8.3.7 como origem do conceito, mas **não reproduz a escala** — a 7ª ed. a substituiu
> pela taxonomia OO de Lethbridge & Laganière (só **3** níveis). A escala de **acoplamento**, ao
> contrário, **está** em [P] §10.2.4, com os 5 níveis clássicos (conteúdo→dados) na ordem certa.
> A Seção 2 entrega o que os livros dizem (§2b, §2d, com citação) e, **separada e marcada**, a escala
> clássica de coesão como contexto externo (§2c).

---

## 1. Conceitos fundamentais de projeto — [P] cap. 8 (§§8.3.1–8.3.12, pp. 206–221)

**8.3.1 Abstração.** No nível mais alto a solução é enunciada no **domínio do problema**; nos mais
baixos, de forma implementável. **Procedural** = sequência nomeada de função "específica e limitada" (ex. `abrir`, detalhes omitidos); **de dados** = coleção nomeada que descreve um objeto (`porta`). → *Na prática:* o nome é o contrato. Se você precisa ler o corpo pra saber o que faz, falhou. Mudar a implementação de `abrir` **não deve mudar** a abstração `abrir`.

**8.3.2 Arquitetura.** "Estrutura ou organização dos componentes (módulos), a maneira pela qual
interagem e a estrutura de dados que utilizam". Trata **propriedades estruturais**, **não funcionais** (desempenho, confiabilidade, segurança) e **famílias de sistemas**. → *Na prática:* decida fronteiras antes de detalhar componentes. Nota de margem: **arquitetura não acontece por acaso** — sem decisão explícita, você paga depois, refazendo.

**8.3.3 Padrões.** Resolve "uma categoria específica de problemas num contexto específico", com as
"forças" que o direcionam. Serve pra decidir (1) se **se aplica**, (2) se pode ser reutilizado, (3) se guia um padrão similar. → *Na prática:* as 3 perguntas são o filtro anti-over-engineering — e a primeira é "se aplica?".

**8.3.4 Separação por interesses.** [Dij82]. Argumento quantitativo: a complexidade percebida de dois
problemas **combinados** é normalmente **maior que a soma** das separadas → dividir-para-conquistar. É a raiz declarada de "modularidade, aspectos, independência funcional e refinamento". **Contrapeso literal:** "pode ser levado longe demais — com um número excessivo de problemas muito pequenos, resolver cada um será fácil, porém **juntos** o conjunto pode ser muito difícil".

**8.3.5 Modularidade.** "O **único atributo** de software que possibilita que um programa seja
**intelectualmente gerenciável**" [Mye78]. **A curva de custo (Fig. 8.2) — o ponto mais acionável do
capítulo:** custo **por módulo** cai com o nº de módulos; custo **de integração** sobe; a soma tem mínimo em **M**, e "**não temos a sofisticação suficiente para prever M com certeza**". Regra: "devemos modularizar, mas tomar cuidado para permanecer **nas vizinhanças de M**. Devemos **evitar modularizar a menos ou a mais**". → Sub- e super-modularizar são **ambos** defeitos.

**8.3.8 Refinamento.** Top-down [Wir71]. **Abstração e refinamento são complementares**: abstração
*suprime* detalhe pra quem está fora; refinamento *revela* conforme avança. **Aviso literal:** "há uma
tendência a avançar diretamente para os detalhes, **pulando as etapas de refinamento**. Isso induz a erros e omissões e torna o projeto **muito difícil de ser revisado**."

**8.3.9 Aspectos.** A intersecta B se foi escolhida uma decomposição em que "**B não pode ser
satisfeito sem levar em conta A**" [Ros04]. Ex. do livro: "usuário registrado deve ser validado" atravessa tudo. → Idealmente vira **módulo separado**, não fragmentos "**espalhados**" ou "**emaranhados**" [Ban06]. Auth, logging, i18n, telemetria espalhados = aspecto mal modularizado.

**8.3.10 Refatoração.** [Fow00]: "mudar um sistema de tal forma que **não altere o comportamento
externo** do código, embora **melhore sua estrutura interna**". **O que se examina (lista literal):** redundância, elementos não utilizados, algoritmos ineficientes/desnecessários, estruturas de dados mal construídas, "ou qualquer outra falha de projeto". **Exemplo do livro:** componente de baixa coesão (3 funções pouco relacionadas) → 3 componentes de alta coesão; "resultado será um software mais fácil de se integrar, testar e manter".

**8.3.6 Ocultação** e **8.3.7 Independência funcional** → Seção 3.
**8.3.12 Classes de projeto** [Amb01], 5 camadas: **interface do usuário** · **domínio de negócio** ·
**processos** · **persistentes** · **sistema**.

---

## 2. Coesão e acoplamento — as escalas

### 2a. Enquadramento — [P] §8.3.7
> "A independência é avaliada usando-se **dois critérios qualitativos: coesão e acoplamento**. A coesão
> indica a **robustez funcional relativa de um módulo**. O acoplamento indica a **interdependência
> relativa entre os módulos**."

- **Coesão** = "extensão natural do conceito de ocultação de informações". "Um módulo coeso deve
  (idealmente) **fazer apenas uma coisa**." **Exceção admitida:** "muitas vezes é necessário e recomendável fazer com que um componente realize várias funções" — o que se evita são componentes
  **"esquizofrênicos"** (muitas funções *não relacionadas*).
- **Acoplamento** depende de 3 coisas concretas: **(1) complexidade da interface, (2) o ponto onde é
  feito o acesso ao módulo, (3) os dados que passam pela interface.** Baixo acoplamento → "menos sujeito a **reação em cadeia**" [Ste74].

### 2b. COESÃO — a escala que [P] 7ª ed. realmente dá
**[P] §10.2.3**, taxonomia **Lethbridge & Laganière [Let01]**, "enumerados em **ordem de nível de
coesão**" (listados do **melhor → pior**; nota de rodapé 4: "quanto maior o nível, mais fácil
implementar, testar e manter").

| Nível | Definição do livro | Reconhecimento |
|---|---|---|
| **1. Funcional** (melhor) | "Apresentada basicamente por operações; ocorre quando um componente realiza **um cálculo planejado e depois retorna um resultado**." | Entra dado, sai resultado. Sem estado escondido, sem efeito colateral. `formatConjunctionList(items)`. **O alvo.** |
| **2. De camadas** | "**Uma camada mais alta acessa os serviços de uma mais baixa, porém as mais baixas não acessam as mais elevadas.**" | O teste é a **direção**. Se a de baixo importa da de cima, quebrou. Ex. do livro: acesso é do painel-de-controle **para baixo**. |
| **3. De comunicação** | "**Todas as operações que acessam os mesmos dados** são definidas em uma classe (...) enfocam exclusivamente os dados em questão, acessando-os e armazenando-os." | Repository/DAO: tudo que toca a mesma tabela mora junto. |

> Veredicto: os três são "relativamente fáceis de ser implementados, testados e mantidos. **Devemos nos
> esforçar ao máximo para atingir esses níveis sempre que possível.** É importante notar, entretanto,
> que questões pragmáticas às vezes "**nos forçam a optar por níveis de coesão mais baixos**" — **e o
> livro não nomeia quais são.** É exatamente a lacuna de §2c.

### 2c. COESÃO — a escala clássica de 7 níveis (⚠️ NÃO está nestes livros)
Origem **Stevens/Myers/Constantine (1974)** = o [Ste74] que [P] §8.3.7 cita ("trabalho posterior de
Stevens, Myers e Constantine **solidificaram o conceito**") sem reproduzir. Incluída por ter sido
pedida; **sem citação de capítulo, porque não há uma.** Do **melhor (7)** ao **pior (1)**:

| # | Nível | Critério de agrupamento | Reconhecimento no código |
|---|---|---|---|
| **7** | **Funcional** | **uma única tarefa** bem definida | `calculateTax(order)`. O nome descreve tudo **sem "e"**. |
| **6** | **Sequencial** | **saída de um é entrada do próximo** | `parse() → validate() → normalize()`. Bom; muitas vezes refatorável p/ funcional. |
| **5** | **Comunicacional** | operam sobre **os mesmos dados**, sem encadeamento | Lê *e* grava *e* audita o mesmo registro. (= "de comunicação" de §2b.) |
| **4** | **Procedural** | **ordem imposta**, sobre dados **diferentes** | `initApp()`: abre log, lê config, conecta DB. Ordem importa, dados não se relacionam. |
| **3** | **Temporal** | só **rodam no mesmo momento** | `setup.ts`, `teardown()`, `onStartup()`. O único elo é "quando". |
| **2** | **Lógica** | categoria similar, selecionada por **flag/switch** | `handle(type, payload)` com `switch(type)`. Sinal: **parâmetro de controle** → casa com acoplamento por controle. |
| **1** | **Coincidental** (pior) | **nenhuma relação** | `utils.ts`, `helpers.ts`, `misc.ts`. O nome não consegue descrever o conteúdo. |

**Ponto de virada:** 1–3 = dívida · 4 = tolerável · 5–7 = alvo. Sintoma mais barato: **o nome**. Se
precisa de "e"/"Manager"/"Utils" pra nomear, provavelmente está em 1–4.

### 2d. ACOPLAMENTO — [P] §10.2.4 (a escala clássica **está aqui**)
Categorias de **Lethbridge & Laganière [Let01]**, listadas **do pior → melhor**. Os **5 primeiros são
exatamente a escala clássica pedida**; depois vêm 4 categorias OO extras.

| # | Nível | Definição do livro | Reconhecimento |
|---|---|---|---|
| **1. Por conteúdo** (pior) | um componente "**modifica de forma sub-reptícia os dados internos de um outro**". "**Isso viola o encapsulamento — um conceito de projeto básico.**" | `a._internalCache.push(x)` de fora. Monkey-patching. Campo privado via reflexão. |
| **2. Comum** (global) | "**uma série de componentes faz uso de uma variável global**". Ressalva: "às vezes é necessário (ex. estabelecer valores-padrão)". | Singleton mutável, `globalThis.config`, store global escrito de todo lado. Risco nomeado: "**propagação de erros incontrolada e efeitos colaterais não previstos** quando forem feitas modificações". |
| **3. Por controle** | "`A()` chama `B()` e **passa um flag de controle**. O flag '**dirige**' a lógica de fluxo no interior de B." | `render(data, isPreview)` + `if (isPreview)`. Risco: "uma **mudança não relacionada em B** pode exigir **alterar o significado do flag** que A passa. Se isso for menosprezado, **acontecerá um erro**." **Boolean parameter = este nível.** |
| **4. "Carimbo"** (stamp) | "`ClasseB` é declarada como **tipo para um argumento** de uma operação da ClasseA. Como agora ClasseB **faz parte da definição** de ClasseA, modificar o sistema **torna-se mais complexo**." | `f(user: User)` quando `f` só usa `user.id`. Passa a estrutura inteira; herda a volatilidade dela. |
| **5. Por dados** (melhor dos clássicos) | "operações passam **longas strings** como argumentos. A '**largura de banda**' da comunicação aumenta e a complexidade da interface cresce. Os testes e a manutenção são mais difíceis." | ⚠️ **Divergência:** no structured design clássico "acoplamento de dados" é o **melhor** nível (só escalares necessários); aqui [P]/[Let01] o descreve como problema de *largura de banda*. Regra válida nos dois: **passe o mínimo necessário, e apenas dados**. |

**Extras OO (não existem na escala clássica):**

| Nível | Definição | Leitura |
|---|---|---|
| **Por chamadas de rotinas** | "uma operação chama outra. **Comum e quase sempre necessário.** Entretanto, realmente aumenta a conectividade." | Inevitável. **Não é defeito.** |
| **Por uso de tipos** | "A usa um tipo definido em B" — "toda vez que uma classe declarar uma variável (...) como tendo **outra classe para seu tipo**". "**Se a definição de tipo mudar, todo componente que a usa também tem de ser alterado.**" | O acoplamento cotidiano de TypeScript. Barato, mas propaga mudança de tipo. |
| **Por inclusão/importação** | "A importa ou inclui um pacote ou o conteúdo de B." | Todo `import`. O grafo de dependências. |
| **Externo** | comunica com **infraestrutura** (SO, BD, telecom). "Embora necessário, **deve se limitar a um pequeno número de componentes**." | Justificativa canônica de adapter/repository. |

> **Fecho literal (§10.2.4):** "Um software deve se comunicar interna e externamente. Consequentemente,
> **acoplamento é uma realidade a ser enfrentada.** Entretanto, o projetista deve se esforçar para
> reduzi-lo sempre que possível e **compreender as ramificações do acoplamento elevado quando não puder
> ser evitado**."

### 2e. Onde as métricas moram — [P] cap. 23
**§23.3.6 — os "três Cs"** do projeto em nível de componente: **coesão, acoplamento, complexidade**.
- **Dhama [Dha95]** — métrica de acoplamento cobrindo 4 tipos, com contadores: **dados e fluxo de
  controle** (`d_i` params de dados de entrada, `c_i` params **de controle** de entrada, `d_o`/`c_o` de
  saída), **global** (`g_d` globais-como-dados, `g_c` globais-**como-controle**), **ambiental**. Ela
  **conta separadamente controle e globais** — é a formalização do custo dos níveis 2 e 3 de §2d.
- **Bieman & Ott [Bie94]** — coesão via *data slices*/*data tokens*/*glue*/*superglue tokens*; derivam
  **coesão funcional forte (SFC)**, **fraca (WFC)** e **adesividade**.
- **CK:** **CBO** — "à medida que o CBO aumenta, **é possível que a reutilização de uma classe
  diminua**"; mantê-lo "o mais baixo possível". **LCOM** — alto = métodos acoplados via atributos,
  "aumenta a complexidade do projeto de classe"; ressalva registrada: "há casos em que um valor alto de
  LCOM seja justificável". **MOOD:** **CF** (*coupling factor*).
- **Princípios de empacotamento [Mar00], [P] §10.2.1:** **CCP** "classes que mudam juntas devem ficar
  juntas" · **CRP** "as que não são reutilizadas juntas não devem ser agrupadas" · **REP** "a
  granularidade da reutilização é a granularidade da versão" · **ISP** "melhor várias interfaces
  específicas de clientes do que uma única de propósito geral".

---

## 3. Ocultação de informação e independência funcional — a justificativa de engenharia

### 3a. Ocultação — [P] §8.3.6
**Parnas [Par72]**, literal: módulos "caracterizados por **decisões de projeto que ocultem (cada uma
delas) de todas as demais**". Operacionalmente: informações (algoritmos e dados) "**inacessíveis por
parte de outros módulos que não necessitam tais informações**". Encapsulamento "define e **impõe
restrições de acesso**" a detalhes procedurais e à estrutura de dados local [Ros75].

> **A frase que importa:** "O uso de encapsulamento como critério de projeto fornece seus **maiores
> benefícios quando são necessárias modificações durante os testes e, posteriormente, durante a
> manutenção**. Como a maioria dos detalhes são ocultos para outras partes do software, **erros
> introduzidos inadvertidamente durante a modificação em um módulo têm menor probabilidade de se
> propagar** para outros módulos."

**O argumento exato:** ocultar informação **não previne** o erro — **contém o raio de alcance** dele. O
ganho é medido no custo de mudança futura, não no custo de escrita hoje. Por isso o benefício é invisível no dia em que você paga por ele. → *Na prática:* o critério de decomposição não é "quais funções existem", é "**quais decisões vão mudar**". Cada decisão volátil (formato de payload, provedor de CMS, shape de tabela) atrás de uma interface, sozinha. Cf. **CCP**: "quando alguma característica dessa área tiver de mudar, é provável que **apenas aquelas classes contidas no pacote precisarão ser modificadas**".

### 3b. Independência funcional — [P] §8.3.7
Módulos com função **única** e "**aversão à interação excessiva**"; cada um atende "um subconjunto
específico de requisitos" com "**interface simples** quando vista de outras partes".

**[P] pergunta "por que devemos nos esforçar para criar módulos independentes?" e responde:**
1. **Desenvolvimento** — "a função pode ser compartimentalizada e as interfaces simplificadas (considere as consequências quando o desenvolvimento é conduzido **por uma equipe**)".
2. **Manutenção e teste** — "mais fáceis de ser mantidos (e testados), pois **efeitos colaterais provocados por modificação são limitados**".
3. **Propagação de erros é reduzida.**
4. **Reuso** — "módulos reutilizáveis são possíveis".

> "**A independência funcional é a chave para um bom projeto, e projeto é a chave para a qualidade de
> um software.**"

### 3c. A cadeia causal completa — o argumento econômico central desta síntese
```
separação por interesses → modularidade → ocultação de informação
                                        → independência funcional (= alta coesão + baixo acoplamento)
                                        → efeitos colaterais LIMITADOS a um módulo
                                        → custo de compreensão + análise de impacto + reteste CAI
                                        → custo de manutenção CAI   (≈50–75% do orçamento — §4c)
```
**O elo que fecha, [S] §27.2:** "É mais dispendioso acrescentar funcionalidade depois da entrega, **por
causa da necessidade de compreender o sistema existente e analisar o impacto das mudanças**. Portanto,
**qualquer trabalho feito durante o desenvolvimento para reduzir o custo dessa análise é útil para
reduzir custos de manutenção**." → Coesão e acoplamento são, literalmente, **controles sobre o custo da
análise de impacto**.

### 3d. Reforços de [S]
- **§10.3** — objetos "inadequadamente acoplados, com interfaces bem definidas"; quando assim, "**a implementação de objetos pode ser modificada**" sem arrastar o resto.
- **§14.3 (Projeto com reuso)** — a favor de reusar **projeto abstrato** em vez de componente executável: reutilizar prontos impõe "restrição às decisões do projeto detalhado tomadas pelos implementadores"; se conflitam com seus requisitos, "a reutilização será **impossível ou introduzirá significativas ineficiências**". Padrões são a saída: "reutilizar projetos mais abstratos, que **não incluam detalhes de implementação**".
- **§18.2.1 (exceções)** — argumento **estrutural**, não de estilo: sem mecanismo de exceção, usar `if` pra detectar e desviar exige "um **grande número de verificações explícitas** (...). Isso **aumenta o tamanho e a complexidade do programa e o torna mais difícil de compreender**. Há uma probabilidade maior de os programadores **cometerem erros** e de os leitores **não conseguirem localizá-los**". → O mecanismo de exceção existe para **manter a coesão do caminho feliz**, separando erro da lógica normal. Cf. a checklist de [S] Fig. 19.7, classe "gerenciamento de exceções": *"Todas as possíveis condições de erro foram levadas em conta?"*

---

## 4. Manutenibilidade e evolução — [S] cap. 27 e §24.4

### 4a. Leis de Lehman — [S] §27.1
Lehman & Belady (1985). Ressalva do próprio [S]: são "**leis (hipóteses, na verdade)**".

| # | Lei | Enunciado (tabela do livro) | Uso |
|---|---|---|---|
| 1 | **Mudança contínua** | "Um programa utilizado em um ambiente do mundo real **necessariamente tem de ser modificado ou se tornará progressivamente menos útil**." | Manutenção é **inevitável**, não falha de planejamento. |
| 2 | **Aumento da complexidade** | "À medida que um programa em evolução se modifica, sua estrutura **tende a se tornar mais complexa**. **Recursos extras precisam ser dedicados a preservar e simplificar a estrutura.**" | ⭐ **A mais acionável.** Degradação é o *default*. Comentário do livro: "a única maneira de evitar é **investir na manutenção preventiva**" — e isso "significa **custos adicionais**, além daqueles de implementação das mudanças requeridas". **Refatoração não é bônus: é a linha orçamentária que compra a Lei 2.** |
| 3 | **Evolução de programa grande** | "A evolução é um **processo auto-regulador**. Atributos como tamanho, tempo entre releases e nº de erros são **aproximadamente invariáveis** para cada release." | Sistema grande age como "**massa inerte**": o tamanho inibe mudanças maiores, porque elas introduzem defeitos que degradam a funcionalidade. |
| 4 | **Estabilidade organizacional** | "A **taxa de desenvolvimento é aproximadamente constante e independente dos recursos** dedicados." | "Estado saturado". Confirma que "**grandes equipes são improdutivas**, uma vez que as atividades indiretas de **comunicação dominam** o trabalho". |
| 5 | **Conservação da familiaridade** | "As **mudanças incrementais em cada release são aproximadamente constantes**." | "Acrescentar nova funcionalidade **inevitavelmente introduz novos defeitos. Quanto mais funcionalidade em cada release, mais defeitos.**" → release gordo **tem que** ser seguido de release de correção. "**Não se deve orçar grandes aumentos de funcionalidade em cada versão sem levar em conta a necessidade de reparo de defeitos.**" |

**Ressalva honesta do autor:** releases radicalmente diferentes (Word, de 256K a sistema gigante)
parecem violar as leis. Resposta: "suspeito que esses programas **não sejam realmente uma sequência de revisões** — o mesmo nome tem sido mantido por **razões de marketing**, mas o programa em si tem sido
**amplamente reescrito**". E: considerações de negócio podem exigir ignorá-las "em qualquer momento".

### 4b. Tipos de manutenção e onde o dinheiro vai — [S] §27.2
**Três tipos** ([S] nota que "não há distinção nítida" e que a nomenclatura é "incerta" — por isso ele
**evita** corretiva/adaptativa/evolutiva):
1. **Reparar defeitos** — hierarquia explícita: erros **de codificação** = "relativamente barato";
   **de projeto** = "mais dispendiosos, podem envolver a reprogramação de diversos componentes";
   **de requisitos** = "**os mais dispendiosos**, devido à extensiva atividade de reprojeto".
2. **Adaptar a ambiente diferente** (hardware, SO, plataforma).
3. **Acrescentar/modificar funcionalidade** — "a escala das mudanças é **muito maior**".

**Distribuição (Lientz & Swanson 1980; confirmada por Nosek & Palvia 1990 — Fig. 27.2):**

| Atividade | % do esforço |
|---|---|
| **Novos requisitos / funcionalidade** | **65%** |
| Adaptação a novo ambiente | 18% |
| **Reparo de defeitos** | **17%** |

> "**Reparar defeitos não é a atividade de manutenção mais dispendiosa.** Em vez disso, a **evolução do
> sistema** para atender a novos ambientes e requisitos **consome a maior parte do esforço**." → "A
> manutenção é uma **continuação do processo de desenvolvimento**", razão pela qual [S] defende o
> **modelo espiral** (Fig. 27.3) sobre o cascata, "em que a manutenção é representada como atividade
> separada".

**Isto reordena prioridades:** otimizar para "menos bugs" ataca **17%**. Otimizar para **facilidade de
acrescentar funcionalidade** ataca **65%**. Coesão/acoplamento/ocultação servem principalmente aos 65%.

### 4c. Custo de manutenção vs. desenvolvimento — [S] §27.2
- **% do orçamento:** Lientz & Swanson — "**pelo menos 50%**" do esforço de programação vai para
  evolução de sistemas existentes. McKee (1984) — "**cerca de 65 a 75%**". [S]: "esse número **pode não
  ter diminuído**".
- **Por domínio:** aplicações de negócio — manutenção "amplamente **comparável**" ao desenvolvimento
  (Guimarães 1983). Embutidos de tempo real — "**até quatro vezes maior**". Causa apontada: "os elevados
  requisitos de confiabilidade e desempenho podem exigir que módulos sejam **estreitamente vinculados**
  e, como consequência, **difíceis de ser modificados**" → **acoplamento comprado por desempenho,
  cobrado depois**.
- **O multiplicador (Fig. 27.4) — o ROI mais concreto dos dois livros:** "Para o **Sistema 1**, os custos
  extras de desenvolvimento equivalentes a **US$ 25 mil** são investidos para fazer o sistema ter
  manutenção mais fácil. Isso resulta em **economia de US$ 100 mil** em custos de manutenção durante o
  tempo de vida útil." → **≈4×**, um "**significativo efeito multiplicador**" vindo "da redução dos
  custos de **compreensão, análise e testes**".
- **Veredicto:** "**investir esforço ao projetar e implementar um sistema para reduzir os custos de
  manutenção é uma opção eficaz em termos de custos.**"

**Os 4 fatores que encarecem a manutenção** (os 3 primeiros são **organizacionais**, não técnicos):
1. **Estabilidade da equipe** — a nova equipe "não compreende o sistema ou o **background das decisões de projeto**". Esforço vai para *entender antes de mudar*.
2. **Responsabilidade contratual** — contratos separados → "**não há nenhum incentivo para uma equipe de desenvolvimento escrever o software de maneira que seja fácil de ser modificado**. Se uma equipe puder optar pela simplificação a fim de economizar esforço durante o desenvolvimento, **vale a pena que proceda dessa maneira, mesmo que isso signifique aumento dos custos de manutenção**." — o incentivo perverso enunciado sem eufemismo.
3. **Habilidade da equipe** — "a manutenção tem uma **imagem ruim** (...) vista como um processo que requer **menos habilidade** e geralmente é **designada para o pessoal mais novo**".
4. **Idade e estrutura** — "à medida que os programas envelhecem, suas estruturas tendem a se tornar mais difíceis de ser entendidas e modificadas" (= Lei 2). Sistemas antigos "nunca foram bem estruturados e eram frequentemente **otimizados com vistas à eficiência, e não à facilidade de compreensão**".

> **Tese de fundo:** "os primeiros três problemas surgem do fato de que muitas organizações ainda **fazem
> distinção entre o desenvolvimento e a manutenção**. A única solução no longo prazo é **aceitar que os
> sistemas raramente têm um tempo de vida útil definido**." → adotar **sistemas evolucionários**,
> "projetados para evoluírem". O 4º é "o **mais fácil de tratar**": reengenharia e **manutenção
> preventiva** ("essencialmente, a **reengenharia incremental**").

### 4d. Previsão de manutenibilidade — [S] §24.4
> "**Com frequência, é impossível medir os atributos da qualidade diretamente.** Atributos como
> **facilidade de manutenção, complexidade e facilidade de compreensão** são afetados por muitos fatores,
> e **não existem métricas diretas e simples** para eles. Em vez disso, devemos medir algum **atributo
> interno** (como seu tamanho) e **supor que exista uma relação** entre o que podemos medir e o que
> desejamos saber."

**As 3 condições de Kitchenham (1990a)** para uma métrica interna ser previsão útil de atributo externo
— **o teste de honestidade de qualquer métrica de código**:
1. "O atributo interno deve ser **medido precisamente**."
2. "Deve existir uma **relação** entre o que podemos medir e o atributo de comportamento externo."
3. "Essa relação é **compreendida, foi validada** e pode ser expressa em uma **fórmula ou modelo**."

→ *Uso prático:* aplique-as **antes** de adotar qualquer gate numérico (cobertura, LOC, ciclomática).
**Quase todo threshold popular falha na condição 3.** [S] é ainda mais duro: a formulação de modelo
"para ser confiável, **exige experiência significativa nas técnicas estatísticas. Um especialista em estatística deve estar envolvido**".

**Controle vs. preditivas:** **de controle** (≈ processo): "esforço e tempo médio para **reparar defeitos
relatados**". **Preditivas** (≈ produto): "**complexidade ciclomática**, comprimento médio de identificadores, nº de atributos e operações". **Ceticismo registrado:** "existe uma **relutância em introduzir a medição, porque os benefícios não são bem definidos** (...) **não há padrões para as métricas**".

---

## 5. Qualidade: atributos e revisões técnicas

### 5a. Atributos internos vs. externos — [S] §24.4 (Fig. 24.10)

| | **Externos** | **Internos** |
|---|---|---|
| **O que é** | o que se **quer saber**; comportamento observável | o que se **consegue medir** no artefato |
| **Exemplos [S]** | facilidade de **manutenção**, **confiabilidade**, **usabilidade**, portabilidade, eficiência, facilidade de compreensão | **linhas de código**, complexidade ciclomática, comprimento de identificadores, nº de atributos/operações, nº de mensagens de erro |
| **Medição** | ❌ "impossível medir diretamente" | ✅ mensurável precisamente |

O diagrama "sugere que **pode haver** uma relação entre externos e internos, **mas não diz qual relação é essa**". → *Na prática:* **todo número no seu CI é interno; todo objetivo que você tem é externo.** A ponte é uma
**hipótese**, e Kitchenham (§4d) é o teste dela. Antídoto contra métrica-como-teatro.
**Raiz do problema, [S] §24.1:** "facilidade de manutenção, portabilidade ou eficiência podem ser
**atributos de qualidade não especificados**" — não estão nos requisitos, ninguém cobra, degradam por
default (Lehman 2).

### 5b. Por que revisar — a economia — [P] §§15.1–15.3, §14.3.2
- **Objetivo:** "encontrar erros durante o processo, de modo a **não se tornarem defeitos depois da
  liberação**". [P] distingue **erro** (antes) × **defeito** (depois), mas registra honestamente que "a
  distinção temporal **não é um pensamento dominante**".
- **Números-chave:** atividades de **projeto introduzem 50–65% de todos os erros**; revisões são "**até
  75% eficazes** [Jon86] na descoberta de falhas de projeto".
- **Amplificação de defeitos (§15.2, Figs. 15.1–15.3)** — mesmas **10** falhas iniciais:

  | | **Sem revisões** | **Com revisões** |
  |---|---|---|
  | Erros ao iniciar os testes | **94** | **24** |
  | **Erros latentes entregues** | **20** | **3** |
  | **Custo total** | **2.177 unid.** | **783 unid.** |

  → "**aproximadamente três vezes mais caro**" sem revisão. Custos unitários: **1,5** (projeto) · **6,5** (antes do teste) · **15** (durante o teste) · **67** (**depois da entrega**). **A escala 1,5→67 (≈45×) é o argumento inteiro.**
- **Dados de campo (§15.3.2):** erro de requisitos corrigido **na revisão ≈ 6 h/homem**; **achado em teste
  ≈ 45 h/homem** → **30 h/homem poupadas por erro**; 22 erros ⇒ **≈660 h/homem**. **HP:** ROI **10:1**, entrega acelerada **1,8 mês**. **AT&T:** custo total de erros ÷ **10**, produtividade **+14%**.
- **A refutação do "não temos tempo" (Fig. 15.4):** "o esforço **aumenta no início**, mas esse
  investimento inicial **rende dividendos** (...). Igualmente importante, **a data de entrega com revisões é anterior àquela sem revisões**. **As revisões não gastam tempo, elas poupam!**"
- **Custo da qualidade (§14.3.2):** prevenção · avaliação · falha (interna/externa); custos crescem
  "drasticamente" nessa direção [Boe01b]/[Cig07]: defeito corrigido **na codificação ≈ US$ 977**; **no teste de sistema ≈ US$ 7.136** (**≈7,3×**).

### 5c. O que se checa
**[P] §15.6 — 5 objetivos da RTF:** (1) descobrir **erros na função, lógica ou implementação**; (2)
verificar se **atende aos requisitos**; (3) garantir conformidade com **padrões predefinidos**; (4)
software desenvolvido **de maneira uniforme**; (5) projetos **mais gerenciáveis**. Laterais: serve de
**treinamento** e promove **backup/continuidade**.

**[S] §19.2.1 — o foco, e a fronteira:** "A **diferença fundamental** entre as inspeções e outros tipos de
revisão é que a **principal meta das inspeções é detectar defeitos**, em vez de considerar questões mais amplas de projeto." Defeitos = "erros lógicos, anomalias no código (...) ou a **não-conformidade com padrões**".

**[S] Fig. 19.7 — checklist canônica, por classe de defeito** (o material mais reutilizável dos 2 livros):

| Classe | Checagens |
|---|---|
| **Dados** | Variáveis **iniciadas antes** do uso? Constantes **denominadas**? Limite superior de vetores = tamanho ou tamanho **−1**? Strings com **delimitador** explícito? Possibilidade de **overflow de buffer**? |
| **Controle** | Cada **condição está correta**? Cada **loop termina**? Declarações compostas corretamente **entre parênteses**? Em `case`, **todos os casos** cobertos? **`break`** incluído onde requerido? |
| **Entrada/saída** | Todas as variáveis de entrada **são usadas**? As de saída **têm valor antes de saírem**? **Entradas inesperadas** podem corromper dados? |
| **Interface** | **Nº correto de parâmetros**? **Tipos** formais e reais combinam? Parâmetros **na ordem certa**? Memória compartilhada com **mesmo modelo** de estrutura? |
| **Armazenamento** | Estrutura ligada modificada → **links redesignados**? Espaço **alocado corretamente**? **Explicitamente liberado** depois? |
| **Exceções** | **Todas as possíveis condições de erro foram levadas em conta?** |

> **Regra da checklist ([S] §19.2.1):** "o processo deve **sempre ser dirigido por uma checklist** de
> erros comuns", estabelecida "pela **discussão com o pessoal experiente**", "**regularmente
> atualizada**", e "**diferentes checklists para diferentes linguagens**" — porque o compilador já cobre
> parte (ex.: compilador Ada confere nº de parâmetros; **C não**). **Corolário para hoje: tudo que o
> typechecker/linter já pega SAI da checklist humana.** Gilb & Graham: cada organização deve desenvolver
> **a sua**, atualizada "quando são descobertos novos tipos de defeitos".

### 5d. As regras — [P] §15.6.3
> Abertura: "**Uma revisão não controlada muitas vezes pode ser pior do que não fazer nenhuma revisão.**"

1. **Revisar o produto, não o produtor.** "Uma RTF envolve **pessoas e egos**. (...) Conduzida de forma imprópria, **pode assumir a aura de uma inquisição**. Os erros devem ser apontados **gentilmente**; o clima deve ser **descontraído e construtivo**; o intuito **não deve ser causar embaraços ou menosprezo**." O líder deve "**interromper imediatamente uma revisão que começou a sair do controle**".
2. **Estabelecer uma agenda e mantê-la.** "Um dos principais males de reuniões é **desviar do foco**."
3. **Limitar debates e refutação.** "Em vez de perder tempo debatendo, o problema deve ser **registrado para posterior discussão, fora da reunião**."
4. **Enunciar áreas do problema, não resolvê-los.** "**Uma revisão não é uma sessão para resolução de problemas.** A resolução deve ser **adiada para depois**."
5. **Tomar notas** — visíveis, "de modo que os termos e as prioridades possam ser avaliados por outros".
6. **Limitar participantes e insistir na preparação.** "**Duas cabeças funcionam melhor do que uma, mas catorze cabeças não funcionam, necessariamente, melhor do que quatro.**"
7. **Uma checklist por tipo de artefato** (análise, projeto, código, e até os artefatos de teste).
8. **Alocar recursos e programar tempo** — inclusive para as "**inevitáveis modificações**" resultantes.
9. **Treinar todos os revisores** — "tanto questões de processo como o **lado psicológico**". Freedman & Weinberg: uma **curva de aprendizado a cada 20 pessoas**.
10. **Revisar as revisões.** "Os primeiros artefatos a ser revisados devem ser **as próprias diretrizes de revisão**."

### 5e. Os limites quantitativos — o núcleo mais acionável
**Restrições da reunião — [P] §15.6.1:**

| Parâmetro | Limite |
|---|---|
| **Participantes** | **3 a 5** (tipicamente) |
| **Preparação antecipada** | obrigatória, **≤ 2 h/pessoa** |
| **Duração da reunião** | **< 2 h** |

> Consequência tirada pelo próprio livro: "deve ser óbvio que uma RTF se concentre em uma parte
> **específica (e pequena)**. Por exemplo, **em vez de tentar revisar um projeto inteiro**, os
> walkthroughs são realizados **para cada componente ou pequeno grupo de componentes**. **Afunilando-se o
> foco, a RTF terá maior probabilidade de revelar erros.**"

**[S] §19.2.1:** "A inspeção deve ser **relativamente curta (não mais de duas horas)**" — os dois livros
convergem no mesmo teto.

**Taxas medidas por Fagan na IBM — [S] §19.2.1** (confirmadas pela AT&T, Barnard & Price 1994):

| Estágio | Taxa |
|---|---|
| Revisão geral (*overview*) | **≈ 500 declarações/hora** |
| **Preparação individual** | **≈ 125 declarações/hora** |
| **Reunião de inspeção** | **90–125 declarações/hora** |

> **Estes são os números que respondem "quanto código revisar de uma vez": ~100 linhas/hora × teto de 2 h
> ⇒ um PR revisável tem ordem de 200 linhas.** Acima disso a taxa não sobe — **a detecção cai**.

**Papéis — [S] §19.2.1:** **Fagan** original: **autor, leitor, testador, moderador** ("o leitor lê o código
em voz alta"). **HP** (Grady & Van Slack 1994): **autor/proprietário** (responsável por **corrigir**),
**inspetor**, **leitor**, **relator**, **presidente/moderador**, **moderador-chefe** (**melhoria do
processo** e **atualização das checklists**). Nota: "**nem sempre existe a necessidade do papel de um leitor**" — Gilb & Graham dispensam a leitura em voz alta e sugerem que "os **inspetores devem ser selecionados para refletir diferentes pontos de vista**: testes, usuário final, qualidade".
**[P] §15.6.1:** **produtor** · **líder de projeto** · **líder de revisão** · 2–3 **revisores** ·
**registrador**. Cada revisor gasta **1–2 h** de preparação.

**Pré-condições da inspeção — [S] §19.2.1** ("é essencial que"):
1. "Haja uma **especificação precisa** do código. **É impossível inspecionar um componente com o nível de detalhes necessário para detectar defeitos sem ter uma especificação completa.**"
2. Membros "**familiarizados com os padrões organizacionais**".
3. "Versão **atualizada e sintaticamente correta**. **Não há razão para inspecionar código que esteja 'quase completo'**, mesmo que um atraso provoque interrupção no cronograma."

**Desfechos da RTF — [P] §15.6.1:** (1) **aceitar** sem modificações; (2) **rejeitar** por erros graves
(**nova revisão**); (3) **aceitar provisoriamente** (erros secundários, **sem nova revisão**). Todos assinam. Em [S], o **moderador** decide no *follow-up* se há nova inspeção.

**Follow-up — [P] §15.6.2:** "Devemos estabelecer um procedimento de acompanhamento (...). **Caso isso não
seja feito, é possível que problemas levantados possam 'ficar para trás'.**" Responsável sugerido: o
**líder da revisão**. **Relatório sintetizado** (1 página) responde: **(1) O que foi revisado? (2) Quem o
revisou? (3) Quais foram as descobertas e conclusões?**

**Métricas — [P] §15.3:** `Ep` (preparação) · `Ea` (avaliação) · `Re` (reformulação) · `TPS` (tamanho) ·
`Errsec` · `Errgraves`. `E_total = Ep+Ea+Re`; **densidade de erros** = `Err_total/TPS`. Teste de sanidade embutido: se a média histórica prevê ~19–20 erros num doc de 32 pp. e **você achou 6**, "ou fizemos um trabalho extremamente bom **ou então a abordagem de revisão não foi suficientemente completa**".

### 5f. O espectro de formalidade — [P] §§15.4–15.5
Formalidade "apropriada para **o produto a ser construído, a cronologia do projeto e as pessoas**".
Aumenta com [Lai02]: (1) **papéis explícitos**; (2) **planejamento/preparação**; (3) **estrutura
distinta**; (4) **follow-up**.
- **Teste de mesa** — "não há planejamento, agenda nem follow-up, [logo] **a eficácia é
  consideravelmente menor** (...). **Mas um simples teste de mesa pode realmente revelar erros** que, de
  outra forma, se propagariam". **1–2 h**. Melhoria barata: **usar uma checklist**.
- **Programação em pares** — "**pode ser caracterizada como um teste de mesa contínuo**. (...) o
  benefício é a **descoberta imediata** de erros". [Wil00]: o par "realiza inspeções continuamente (...),
  levando à **forma mais precoce e eficiente possível de eliminação de defeitos**". Resposta ao argumento
  de desperdício: "**se a qualidade for significativamente melhor que o trabalho individual, as economias
  são plenamente capazes de justificar a 'redundância'**".
- **RTF** = classe que **inclui walkthroughs e inspeções**. Regras de §5d–5e.
- **Revisões por amostragem (§15.6.4)** — a saída quando não dá pra revisar tudo: "**no mundo real dos
  projetos de software, os recursos são limitados e o tempo é escasso.** Como consequência, **as revisões
  são muitas vezes esquecidas**." Thelin et al. [The01]: inspecionar **uma fração `a_i`** de cada
  artefato, registrar falhas `f_i`, **estimar** o total, e **direcionar RTF completa apenas aos artefatos
  mais suscetíveis a erro**. → **Amostrar para priorizar > revisar tudo mal, ou nada.**

---

## 6. Quando o rigor NÃO se paga

**6.1 Rigor ∝ criticidade — [S] §19.1.** "O processo de V&V **é dispendioso**. Para alguns sistemas
grandes, como os de tempo real (...), **metade do orçamento do desenvolvimento pode ser gasto em V&V**." Regra de dosagem: "**o esforço relativo devotado a inspeções e testes depende do tipo de sistema** (...).
**Quanto maior for a importância de um sistema, mais esforço deve ser dedicado**" — o inverso também vale.

**6.2 Formalidade ∝ produto/prazo/pessoas — [P] §15.4.** Ver §5f. Não existe "a" revisão: existe um
**espectro**. Para um protótipo de interface, [P] usa como exemplo o extremo informal ("decidem que
**não haverá nenhuma preparação prévia**").

**6.3 Protótipos descartáveis: rigor é desperdício por definição — [S] §8.1.** O objetivo da prototipação
descartável é "**validar ou derivar os requisitos** (...). Uma vez escrita a especificação, **o protótipo não tem mais utilidade e é descartado**".
> **Regra literal:** "**Por definição, os protótipos descartáveis têm duração muito curta.** Deve ser
> possível modificá-los muito rapidamente, mas **a facilidade de manutenção a longo prazo não é exigida.
> O baixo nível de desempenho e confiabilidade pode ser aceitável em um protótipo descartável**, desde
> que ele cumpra sua função de ajudar no entendimento dos requisitos."

**A condição inegociável:** o protótipo **é descartado** e "um sistema com **qualidade de produção** é
construído". **O pecado não é o protótipo sujo — é promovê-lo a produção.** Contraste: a **prototipação evolucionária** "tem por objetivo **fornecer um sistema funcional aos usuários finais**" e **não goza dessa isenção**. → **Decida qual dos dois você está fazendo antes da primeira linha**: a resposta define se manutenibilidade é requisito ou desperdício. As ordens de ataque são **opostas**: no descartável "começar com aqueles requisitos que **não são bem compreendidos** (...). **Os requisitos que são diretos podem nunca ser prototipados**"; no evolucionário, pelos "**mais bem compreendidos e de maior prioridade**".

**6.4 "Bom o suficiente" — [P] §14.3.1.** É aceitável? "**A resposta deve ser 'sim'**, pois atualmente as
principais empresas agem dessa forma. Elas criam software com **erros conhecidos** e os entregam (...) reconhecem que **o tempo de colocação no mercado é a melhor cartada de qualidade** desde que o produto seja 'bom o suficiente'." Definição: alta qualidade nas funções "**que os usuários desejam**", com erros conhecidos nas "**mais obscuras ou especializadas**", apostando que "a **grande maioria dos usuários ignore os erros**".

**As duas condições em que [P] diz que NÃO funciona** — a parte que importa:
1. **Empresa pequena.** "**Não confie nessa filosofia.** (...) você corre o risco de **arruinar permanentemente a reputação da empresa**. Talvez **jamais tenha a chance de entregar a versão 2.0** pois, devido à má propaganda, as vendas podem despencar e a empresa **falir**." (A estratégia depende de "**um grande orçamento para marketing**" — é **jogada de incumbente**.)
2. **Domínios críticos** (embarcado de tempo real, automotivo, telecom). "Entregar software com erros conhecidos pode ser **negligente e expõe sua empresa a litígios custosos**. Em alguns casos, **pode constituir crime**."

> Veredicto: "**proceda com cautela** caso acredite que 'bom o suficiente' seja um atalho (...). **Pode
> ser que funcione, mas apenas para poucos casos e em um conjunto limitado de domínios.**"

**6.5 Modularizar demais também é defeito — [P] §§8.3.4–8.3.5.** Ver §1: "evitar modularizar a menos **ou
a mais**" (Fig. 8.2, custo de integração); e a separação por interesses "**pode ser levada longe demais**".

**6.6 O contraponto — o rigor que os livros dizem que se paga sempre.** Nenhuma isenção acima toca no
núcleo:
- **Inspeção > teste, em custo E eficácia** — [S] §19.2, Basili & Selby (1987): "a **revisão estática de
  código era mais eficaz e menos dispendiosa que os testes de defeitos** para descobrir defeitos" (confirmado por Gilb & Graham 1993). Extremo registrado: "uma série de organizações **abandonou o teste de unidades em favor das inspeções**. Eles constataram que as inspeções são tão eficazes que **os custos do teste de unidade não são justificáveis**" (é o caminho do **Cleanroom**, [S] §19.4 / [P] §21.4).
- **Revisões encurtam o prazo** — [P] Fig. 15.4: "as revisões **não gastam tempo, elas poupam!**"
- **Manutenibilidade tem ROI ≈ 4×** — [S] Fig. 27.4 (§4c).

---

**Offsets para reabrir os PDFs:** **[S]** PDF = pág. impressa **+14**. **[P]** PDF = impressa **+23** (apêndices ficam **no início** do arquivo, pp. 1–35; sumário ~36–50; cap. 1 começa na p. 60). Capítulos usados — **[P]:** 8 (conceitos), 10 (coesão/acoplamento), 14 (qualidade), 15 (revisões), 23 (métricas). **[S]:** 8 (protótipos), 10 (arquitetura), 14 (reuso), 18 (exceções), 19 (V&V/inspeções), 24 (qualidade/métricas), 27 (Lehman/manutenção).
