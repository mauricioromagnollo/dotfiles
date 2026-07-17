# Refatoração e Code Smells — síntese do refactoring.guru

Fonte: https://refactoring.guru/refactoring (páginas: what-is-refactoring, technical-debt, when, how-to, smells + 22 páginas de smell, techniques + 6 subcatálogos).
Convenção deste doc: **negrito** = nome de refatoração do catálogo; citações entre aspas são tradução fiel do texto original.

---

## 1. O que é refatoração (e o que NÃO é)

> "O principal propósito da refatoração é combater a dívida técnica. Ela transforma uma bagunça em código limpo e design simples."

Refatoração = **série de pequenas transformações que preservam o comportamento**, cada uma deixando o código ligeiramente melhor e o programa **funcionando ao fim de cada passo**.

### O que NÃO é refatoração

| Não é | Por quê |
|---|---|
| **Reescrita (rewrite)** | Refatoração é incremental e reversível; o programa nunca quebra no meio. Reescrever é jogar fora e recomeçar — o site admite isso como opção legítima, mas *fora* do guarda-chuva "refatoração": "quando o código está muito ruim, considere jogá-lo fora por completo — mas só depois de escrever testes abrangentes e reservar tempo suficiente". |
| **Adicionar feature** | "Não crie novas funcionalidades durante a refatoração." Misturar as duas atividades confunde o propósito de cada mudança. Idealmente **separe até em commits distintos**. |
| **Mudar comportamento** | Todos os testes devem continuar passando *sem serem alterados*. Se um teste quebra, ou você errou, ou o teste é baixo nível demais (testando detalhes privados de implementação). |
| **Otimização de performance** | Otimizar frequentemente *piora* a legibilidade em troca de velocidade — é o vetor oposto. Nota do site sobre o medo de "muitos métodos custam performance": "na quase totalidade dos casos o impacto é tão desprezível que nem vale a preocupação." |
| **Um grande commit "de limpeza"** | "Misturar muitas mudanças em uma grande modificação frequentemente falha — os desenvolvedores perdem de vista as melhorias." |

### Código limpo — 5 características

1. **Óbvio para outros programadores.** Nomes ruins, estruturas inchadas e números mágicos matam a compreensão.
2. **Não contém duplicação.** Duplicar obriga a manter N cópias sincronizadas.
3. **Número mínimo de classes e peças móveis.** Menos código = menos carga mental e manutenção.
4. **Passa em todos os testes.** Cobertura esparsa é sintoma de código sujo.
5. **É mais fácil e barato de manter.**

### Dívida técnica — causas catalogadas

- **Pressão do negócio** — lançar antes de terminar.
- **Falta de entendimento das consequências** — gestão não vê que a dívida freia o desenvolvimento, e refatoração vira "custo sem valor".
- **Não combater o acoplamento forte entre componentes** — "o projeto parece um monolito e não o produto de módulos individuais: qualquer mudança em uma parte afeta as outras."
- **Falta de testes** — "a ausência de feedback imediato encoraja gambiarras rápidas, porém arriscadas."
- **Falta de documentação** — trava onboarding; se a pessoa-chave sai, o desenvolvimento para.
- **Falta de interação entre o time** — conhecimento não distribuído; pessoas trabalham com informação desatualizada.
- **Desenvolvimento longo e simultâneo em várias branches** — a dívida acumula e explode no merge.
- **Refatoração adiada** — requisitos mudam, o código velho apodrece e mais código passa a depender dele.
- **Falta de monitoramento de conformidade** — cada um escreve de um jeito.
- **Incompetência** — "o desenvolvedor simplesmente não sabe escrever código decente."

---

## 2. Quando refatorar

### A Regra dos Três (verbatim)

1. "Quando você está fazendo algo pela **primeira** vez, apenas faça."
2. "Quando está fazendo algo similar pela **segunda** vez, faça careta por ter que repetir — mas faça a mesma coisa mesmo assim."
3. "Quando está fazendo algo pela **terceira** vez, comece a refatorar."

### Ao adicionar uma feature
Refatorar primeiro torna o código compreensível, e aí a feature entra fácil. Bônus: quem vier depois herda algo melhor. "Código limpo é muito mais fácil de captar."

### Ao corrigir um bug
Bugs se escondem em código bagunçado. Limpando, "os erros se tornam evidentes por conta própria" — muitas vezes o bug aparece sozinho no meio da refatoração.

### Durante code review
"A última chance de melhorar o código antes que ele fique disponível ao público." Fazer o review **em par com o autor**: correções triviais saem na hora, e para as complexas dá para estimar o tempo de forma realista.

### Quando NÃO refatorar
> Nota de fidelidade: o site **não tem uma seção explícita "quando não refatorar"** na página `/when`. Os itens abaixo vêm de `/how-to` e das seções "Quando ignorar" dos smells — que é onde essa doutrina realmente mora.

- **Quando é mais barato reescrever do zero.** `/how-to`: "às vezes o código está tão ruim que é mais fácil jogá-lo fora — mas só depois de ter escrito testes e reservado tempo." Se você está refatorando e o esforço não converge, essa é a saída.
- **Quando falta cobertura de teste.** A rede de segurança é pré-requisito: sem testes você não está refatorando, está torcendo. "Falta de testes" está listada como *causa* de dívida técnica, e "todos os testes devem passar" é critério de refatoração correta.
- **Quando o resultado fica pior.** Regra explícita em *Parallel Inheritance Hierarchies*: "se suas tentativas de de-duplicar produzem código ainda mais feio, dê um passo atrás, **reverta todas as suas mudanças** e acostume-se com aquele código."
- **Perto de deadline.** Implícito na causa "pressão do negócio" — a dívida contraída sob prazo é uma decisão de negócio consciente, não um acidente. A refatoração vira uma dívida *registrada*, não ignorada.
- **Antes da 3ª repetição.** A Regra dos Três é também uma regra de *não* refatorar: na 1ª e na 2ª vez, não abstraia.

### Checklist de "refatorei direito?"
1. O código ficou **mais limpo**. (Se não ficou, foi tempo jogado fora.)
2. **Nenhuma nova funcionalidade** entrou junto.
3. **Todos os testes passam** — sem terem sido reescritos para acomodar você.

---

## 3. Code smells — catálogo completo (5 categorias)

Formato: **Nome** — *Sinal* → tratamentos. **Payoff** e **Quando ignorar** destacados.

### 3.1 Bloaters
> "Código, métodos e classes que cresceram a proporções tão gigantescas que ficaram difíceis de trabalhar."

#### Long Method ★
- **Sinal:** "Um método contém linhas demais. Em geral, **qualquer método com mais de dez linhas** deve fazer você começar a se perguntar coisas."
- **Causa:** código só cresce, nunca encolhe; é mais fácil escrever do que ler; existe uma barreira psicológica a criar um método novo.
- **Tratamento:** **Extract Method** (padrão). Se variáveis locais atrapalham a extração: **Replace Temp with Query**, **Introduce Parameter Object**, **Preserve Whole Object**. Se nada funciona: **Replace Method with Method Object**. Condicionais → **Decompose Conditional**. Loops → **Extract Method** no corpo.
- **Payoff:** "Entre todos os tipos de objetos, os de métodos curtos vivem mais." Métodos longos escondem código duplicado dentro de si.
- **Quando ignorar:** *não há seção*. O único contrapeso registrado é a nota de performance: o custo de mais chamadas "é desprezível, não vale a preocupação".

#### Large Class ★
- **Sinal:** "Uma classe contém muitos campos / métodos / linhas de código."
- **Causa:** "Classes geralmente começam pequenas. Mas com o tempo ficam inchadas conforme o programa cresce." É mentalmente mais fácil colar em uma classe existente do que criar outra.
- **Tratamento:** **Extract Class** (comportamento destacável), **Extract Subclass** (comportamento usado só em certos casos), **Extract Interface** (listar o que os clientes realmente usam), **Duplicate Observed Data** (dados de domínio presos numa classe de GUI).
- **Payoff:** "Poupa os desenvolvedores de terem que memorizar um monte de atributos." Quebrar quase sempre elimina duplicação de código e comportamento.
- **Quando ignorar:** *não há seção*.

#### Primitive Obsession ★
- **Sinal:** primitivos em vez de pequenos objetos para tarefas simples (moeda, intervalos, strings especiais como telefone); **constantes codificando informação** (`USER_ADMIN_ROLE = 1`); constantes string como nomes de campo em arrays de dados.
- **Causa:** um campo primitivo é barato; criar uma classe "parece" caro. Depois vem outro, e outro — a classe incha.
- **Tratamento:** **Replace Data Value with Object**; **Introduce Parameter Object** / **Preserve Whole Object**; **Replace Type Code with Class** / **with Subclasses** / **with State/Strategy**; **Replace Array with Object**.
- **Payoff:** "Código fica mais flexível graças ao uso de objetos"; melhor compreensão e organização; **facilita achar código duplicado**.
- **Quando ignorar:** *não há seção*.

#### Long Parameter List
- **Sinal:** "Mais de três ou quatro parâmetros em um método."
- **Causa:** fusão de vários algoritmos num método só; ou tentativa de reduzir dependências entre classes passando tudo por parâmetro.
- **Tratamento:** **Replace Parameter with Method Call**; **Preserve Whole Object**; **Introduce Parameter Object**.
- **Payoff:** código mais curto e legível; pode revelar duplicação escondida.
- **Quando ignorar:** ✅ **"Não remova parâmetros se isso criar uma dependência indesejada entre classes."** (Passar o objeto inteiro acopla os dois lados — às vezes a lista longa é o preço do desacoplamento.)

#### Data Clumps ★
- **Sinal:** "Diferentes partes do código contêm **grupos idênticos de variáveis** (ex.: parâmetros de conexão a banco)."
- **Teste diagnóstico:** *remova um dos valores*. Os que sobraram ainda fazem sentido sozinhos? Se não, é um clump legítimo pedindo uma classe.
- **Causa:** arquitetura pobre ou "copy-paste programming".
- **Tratamento:** **Extract Class** (campos numa classe); **Introduce Parameter Object** (parâmetros repetidos); **Preserve Whole Object**; depois, mova o código que opera nesses dados para a classe nova.
- **Payoff:** "Operações sobre um dado específico agora estão reunidas em um único lugar, em vez de espalhadas ao acaso." Reduz o tamanho do código.
- **Quando ignorar:** ✅ **"Passar um objeto inteiro nos parâmetros de um método, em vez de só seus valores (tipos primitivos), pode criar uma dependência indesejada entre as duas classes."**

### 3.2 Object-Orientation Abusers
> "Aplicação incompleta ou incorreta de princípios de OOP."

#### Switch Statements
- **Sinal:** "Um `switch` complexo ou uma sequência de `if`s." Pior: a mesma lógica de switch replicada em vários pontos.
- **Tratamento:** **Extract Method** + **Move Method** (isolar e levar para onde pertence); type code → **Replace Type Code with Subclasses** / **with State/Strategy**; depois **Replace Conditional with Polymorphism**; variação simples por parâmetro → **Replace Parameter with Explicit Methods**; caso `null` → **Introduce Null Object**.
- **Payoff:** organização de código.
- **Quando ignorar:** ✅ duas exceções explícitas — (a) **switch simples**, com pouca lógica, não vale refatorar; (b) **Factory Method e Abstract Factory usam switch de propósito** para escolher a classe a instanciar.

#### Temporary Field
- **Sinal:** "Campos que recebem valor (e portanto são necessários) só sob certas circunstâncias. Fora delas, estão vazios."
- **Causa:** o programador criou o campo para evitar uma lista longa de parâmetros num algoritmo.
- **Tratamento:** **Extract Class** com os campos temporários e o código que os usa (≈ **Replace Method with Method Object**); **Introduce Null Object** no lugar dos `if (campo != null)`.
- **Payoff:** clareza e organização.
- **Quando ignorar:** *não há seção*.

#### Refused Bequest
- **Sinal:** "A subclasse usa só alguns dos métodos e propriedades herdados. Os não necessários ficam sem uso ou são redefinidos lançando exceções."
- **Causa:** "Alguém criou a herança motivado **apenas pelo desejo de reusar código** da superclasse. Mas superclasse e subclasse são completamente diferentes."
- **Tratamento:** herança inadequada → **Replace Inheritance with Delegation**. Herança faz sentido conceitual → **Extract Superclass** com o que é comum, e cada subclasse herda só o relevante.
- **Payoff:** "Você não vai mais precisar se perguntar por que a classe `Dog` herda de `Chair` (mesmo que ambas tenham 4 pernas)."
- **Quando ignorar:** *não há seção*.

#### Alternative Classes with Different Interfaces
- **Sinal:** "Duas classes fazem funções idênticas, mas com nomes de métodos diferentes."
- **Causa:** quem escreveu a segunda não sabia que a primeira existia.
- **Tratamento:** **Rename Method** para igualar; **Move Method**, **Add Parameter**, **Parameterize Method** para igualar assinatura e implementação; se só parte é duplicada → **Extract Superclass**; ao fim, **delete a classe redundante**.
- **Payoff:** menos duplicação; legibilidade ("você não precisa mais adivinhar por que existe uma segunda classe fazendo exatamente o mesmo").
- **Quando ignorar:** ✅ **"Às vezes fundir classes é impossível ou tão difícil que não vale a pena. Um exemplo é quando as classes alternativas estão em bibliotecas diferentes, cada uma com sua própria versão da classe."**

### 3.3 Change Preventers
> "Se você precisa mudar algo em um lugar, tem que fazer muitas mudanças em outros lugares também."

#### Divergent Change ★
- **Sinal:** **"Você se vê tendo que alterar muitos métodos NÃO relacionados quando faz mudanças numa classe."** Ex.: ao adicionar um novo tipo de produto, você mexe nos métodos de busca, de exibição e de pedido.
- **Mnemônico:** *uma classe, muitas razões para mudar* (violação de SRP pelo lado da classe). É o **oposto simétrico** de Shotgun Surgery.
- **Causa:** "estrutura de programa ruim ou 'copypasta programming'."
- **Tratamento:** **Extract Class** para separar os comportamentos. Se as classes resultantes têm comportamento parecido: **Extract Superclass** / **Extract Subclass**.
- **Payoff:** organização; menos duplicação; suporte mais simples.
- **Quando ignorar:** *não há seção*.

#### Shotgun Surgery ★
- **Sinal:** **"Fazer qualquer modificação exige muitas pequenas mudanças em muitas classes diferentes."**
- **Mnemônico:** *uma razão de mudar, muitas classes*. Espelho de Divergent Change — e o site avisa: nasce frequentemente **de aplicar Divergent Change demais** (fragmentar sem critério).
- **Causa:** uma única responsabilidade foi espalhada por várias classes.
- **Tratamento:** **Move Method** e **Move Field** para juntar o comportamento numa classe só (criando uma nova se nenhuma servir); **Inline Class** nas classes que ficaram vazias.
- **Payoff:** organização; menos duplicação; manutenção simplificada.
- **Quando ignorar:** *não há seção*. Mas a tensão com Divergent Change é o guard-rail: corrigir um até o extremo produz o outro. O ponto ótimo fica no meio.

#### Parallel Inheritance Hierarchies
- **Sinal:** "Sempre que você cria uma subclasse de uma classe, se vê tendo que criar uma subclasse de outra classe."
- **Tratamento:** faça as instâncias de uma hierarquia referenciarem as da outra; depois remova a hierarquia redundante com **Move Method** e **Move Field**.
- **Payoff:** menos duplicação; possível melhoria de organização.
- **Quando ignorar:** ✅ **"Às vezes ter hierarquias paralelas é apenas o jeito de evitar uma bagunça ainda maior na arquitetura. Se você descobrir que suas tentativas de de-duplicar as hierarquias produzem código ainda mais feio, dê um passo atrás, reverta todas as suas mudanças e acostume-se com aquele código."** — é a formulação mais honesta do site inteiro sobre desistir de uma refatoração.

### 3.4 Dispensables
> "Algo inútil e desnecessário cuja ausência tornaria o código mais limpo, eficiente e fácil de entender."

#### Duplicate Code ★
- **Sinal:** "Dois fragmentos de código parecem quase idênticos." Também a duplicação **sutil**: trechos *diferentes* que fazem a *mesma coisa*.
- **Causa:** vários programadores trabalhando em partes diferentes ao mesmo tempo; pressa de deadline; falta de vontade de refatorar direito.
- **Tratamento:**
  - Mesma classe → **Extract Method** + chamar dos dois lados.
  - Subclasses de um mesmo pai → **Extract Method** nas duas + **Pull Up Field** / **Pull Up Constructor Body** / **Pull Up Method**; passos parecidos em ordem parecida → **Form Template Method**; algoritmos diferentes com mesmo resultado → escolha o melhor e **Substitute Algorithm**.
  - Classes não relacionadas → **Extract Superclass** ou **Extract Class**.
  - Condicionais que levam ao mesmo resultado → **Consolidate Conditional Expression**.
  - Código idêntico em todos os ramos de um `if` → **Consolidate Duplicate Conditional Fragments**.
- **Payoff:** "Fundir código duplicado simplifica a estrutura e encurta o código." Menos código para manter, mais barato de entender.
- **Quando ignorar:** ✅ **"Em casos muito raros, fundir dois fragmentos idênticos de código pode tornar o código menos intuitivo e óbvio."** (Nota: "muito raros" — o site é deliberadamente restritivo aqui.)

#### Speculative Generality ★
- **Sinal:** **"Existe uma classe, método, campo ou parâmetro NÃO utilizado."** Abstrações criadas "por via das dúvidas", para features que nunca chegaram.
- **Causa:** "criado para dar suporte a funcionalidade antecipada que nunca se materializou" — tornando o código mais difícil de entender e manter.
- **Tratamento:** **Collapse Hierarchy** (classe abstrata desnecessária); **Inline Class** (delegação inútil); **Inline Method** (métodos sem uso real); **Remove Parameter** (parâmetros não usados); campos sem uso: apague.
- **Payoff:** código mais enxuto; suporte mais fácil.
- **Quando ignorar:** ✅ duas exceções — (a) **"Se você está desenvolvendo um framework, é eminentemente razoável criar funcionalidade não usada pelo próprio framework, desde que os usuários dele precisem dessa funcionalidade."**; (b) **antes de apagar, verifique se o elemento não é usado pelos testes unitários** — testes frequentemente precisam acessar informação interna da classe ou executar ações específicas de teste.

#### Lazy Class ★
- **Sinal:** **"Entender e manter classes sempre custa tempo e dinheiro. Se uma classe não faz o suficiente para merecer sua atenção, ela deveria ser deletada."**
- **Causa:** a classe encolheu depois de uma refatoração; ou foi criada para um desenvolvimento planejado que nunca aconteceu.
- **Tratamento:** **Inline Class** para componentes quase inúteis; **Collapse Hierarchy** para subclasses com pouquíssima função.
- **Payoff:** menos código; manutenção mais fácil.
- **Quando ignorar:** ✅ **"Às vezes uma Lazy Class é criada para delinear intenções para desenvolvimento futuro. Nesse caso, tente manter um equilíbrio entre clareza e simplicidade no seu código."**

#### Data Class
- **Sinal:** "Classe que contém apenas campos e métodos crus para acessá-los (getters e setters)." Recipientes de dados manipulados por outras classes, sem função própria.
- **Causa:** classes novas nascem pequenas; mas "a força real da OO está em juntar comportamento com dado".
- **Tratamento:** **Encapsulate Field** (campos públicos); **Encapsulate Collection** (arrays/coleções); procure no código cliente as operações que pertencem à classe de dados e traga-as com **Move Method** / **Extract Method**; depois enxugue a interface com **Remove Setting Method** e **Hide Method**.
- **Payoff:** "Operações sobre um dado agora estão reunidas em um único lugar"; ajuda a achar duplicação no código cliente.
- **Quando ignorar:** *não há seção*. **Contraponto importante:** ver *Feature Envy → Quando ignorar* — separar comportamento de dado é legítimo em Strategy/Visitor. Data Class não é smell quando é o "dado" de um pattern que a separa de propósito, ou um DTO de fronteira.

#### Dead Code
- **Sinal:** "Uma variável, parâmetro, campo, método ou classe não é mais usada (geralmente porque ficou obsoleta)."
- **Causa:** requisitos mudaram, ninguém limpou; ou ramos condicionais tornaram-se inalcançáveis.
- **Tratamento:** use uma IDE decente para detectar. **Delete o código e os arquivos**; classes desnecessárias → **Inline Class** / **Collapse Hierarchy**; parâmetros → **Remove Parameter**.
- **Payoff:** menos código; suporte mais simples.
- **Quando ignorar:** *não há seção*. (Na prática, o controle de versão é o argumento: não comente, apague — o git guarda.)

#### Comments
- **Sinal:** "Um método está cheio de comentários explicativos."
- **Causa:** "Comentários geralmente são criados com a melhor das intenções, quando o autor percebe que seu código não é intuitivo ou óbvio." → **"O melhor comentário é um bom nome de método ou classe."**
- **Tratamento:** comentário explica uma expressão complexa → **Extract Variable**; explica um trecho → **Extract Method**; já é um método e ainda precisa de comentário → renomeie para um nome autoexplicativo (**Rename Method**); afirma um pré-requisito de estado → **Introduce Assertion**.
- **Payoff:** código mais intuitivo e óbvio.
- **Quando ignorar:** ✅ comentários **são úteis** em dois casos — (a) **"quando explicam POR QUE algo está implementado de determinada forma"**; (b) **"quando explicam algoritmos complexos — depois que todos os outros métodos de simplificar o algoritmo foram tentados e falharam."**

### 3.5 Couplers
> "Contribuem para acoplamento excessivo entre classes, ou mostram o que acontece quando o acoplamento é trocado por delegação excessiva."

#### Feature Envy ★
- **Sinal:** **"Um método acessa os dados de outro objeto mais do que os seus próprios."**
- **Causa:** frequentemente aparece **depois** de mover campos para uma data class — e esquecer de mover junto as operações sobre eles.
- **Regra-mãe:** **"se as coisas mudam ao mesmo tempo, mantenha-as no mesmo lugar."** Dados e as funções que os usam mudam juntos.
- **Tratamento:** método inteiro pertence a outro lugar → **Move Method**; só uma parte acessa o outro objeto → **Extract Method** dessa parte + mover; método usa dados de várias classes → **determine qual classe contém a maior parte dos dados** e coloque o método lá; ou **Extract Method** partindo o método em pedaços que vão para classes diferentes.
- **Payoff:** menos duplicação (código de manipulação de dado centralizado); melhor organização (métodos ao lado dos dados).
- **Quando ignorar:** ✅ **"Às vezes o comportamento é mantido separado da classe que guarda os dados PROPOSITALMENTE. A vantagem usual disso é a habilidade de mudar o comportamento dinamicamente (ver Strategy, Visitor e outros patterns)."**

#### Middle Man ★
- **Sinal:** **"Se uma classe executa apenas uma ação — delegar trabalho para outra classe — por que ela existe?"**
- **Causa:** consequência do zelo excessivo em eliminar **Message Chains** (Hide Delegate demais); ou o trabalho útil migrou aos poucos para fora da classe, deixando uma casca.
- **Tratamento:** **Remove Middle Man** quando a maioria dos métodos apenas delega.
- **Payoff:** menos código inchado.
- **Quando ignorar:** ✅ **"Não delete middle men que foram criados por um motivo:** (a) um middle man pode ter sido adicionado **para evitar dependências entre classes**; (b) **alguns design patterns criam middle men de propósito** (como Proxy ou Decorator)."

#### Message Chains
- **Sinal:** "Você vê uma série de chamadas parecida com `$a->b()->c()->d()`."
- **Causa:** o cliente passa a depender da **navegação pela estrutura de classes**; qualquer mudança nas relações intermediárias obriga a mudar o cliente.
- **Tratamento:** **Hide Delegate** em vários pontos da cadeia; ou verifique como o objeto final é usado e aplique **Extract Method** + **Move Method** para empurrar essa função para o início da cadeia.
- **Payoff:** reduz dependências entre as classes da cadeia; reduz volume de código.
- **Quando ignorar:** ✅ **"Esconder delegates de forma agressiva demais produz código no qual é difícil ver onde a funcionalidade realmente acontece. O que é outro jeito de dizer: evite também o smell Middle Man."** — o par Message Chains ↔ Middle Man é um dial, não um interruptor.

#### Inappropriate Intimacy
- **Sinal:** "Uma classe usa campos e métodos internos de outra classe." — **"Boas classes devem saber o mínimo possível umas sobre as outras."**
- **Tratamento:** **Move Method** / **Move Field** para levar o pedaço para onde ele é usado; **Extract Class** + **Hide Delegate** para formalizar a relação; dependência mútua → **Change Bidirectional Association to Unidirectional**; se é intimidade entre subclasse e superclasse → **Replace Delegation with Inheritance**.
- **Payoff:** organização; suporte e reuso simplificados.
- **Quando ignorar:** *não há seção*.

#### Incomplete Library Class
- **Sinal:** "Mais cedo ou mais tarde as bibliotecas deixam de atender às necessidades. A única solução — mudar a biblioteca — costuma ser impossível, já que ela é read-only."
- **Causa:** o autor da lib não previu (ou recusou) a feature.
- **Tratamento:** poucos métodos → **Introduce Foreign Method**; muitas mudanças → **Introduce Local Extension** (subclasse ou wrapper).
- **Payoff:** "Reduz duplicação (em vez de criar sua própria biblioteca do zero, você ainda pega carona numa existente)."
- **Quando ignorar:** ✅ **"Estender uma biblioteca pode gerar trabalho extra: se mudanças na biblioteca alterarem seu contrato, você terá que alterar o seu código também."**

---

## 4. Catálogo de técnicas (nome + quando aplicar)

### Composing Methods
| Técnica | Quando |
|---|---|
| Extract Method | Um fragmento de código pode ser agrupado. |
| Inline Method | O corpo do método é mais óbvio que o próprio método. |
| Extract Variable | Você tem uma expressão difícil de entender. |
| Inline Temp | Variável temporária que só recebe o resultado de uma expressão simples. |
| Replace Temp with Query | Você guarda o resultado de uma expressão numa local para usar depois. |
| Split Temporary Variable | Uma local armazena vários valores intermediários diferentes. |
| Remove Assignments to Parameters | Algum valor é atribuído a um parâmetro dentro do método. |
| Replace Method with Method Object | Método longo cujas locais estão tão entrelaçadas que Extract Method não passa. |
| Substitute Algorithm | Você quer trocar um algoritmo existente por um mais claro. |

### Moving Features Between Objects
| Técnica | Quando |
|---|---|
| Move Method | Um método é mais usado em outra classe do que na sua. |
| Move Field | Um campo é mais usado em outra classe do que na sua. |
| Extract Class | Uma classe faz o trabalho de duas. |
| Inline Class | Uma classe quase não faz nada e não há responsabilidades planejadas para ela. |
| Hide Delegate | O cliente pega B de A e depois chama método de B. |
| Remove Middle Man | Uma classe tem métodos demais que só delegam. |
| Introduce Foreign Method | Classe utilitária não tem o método que você precisa e você não pode editá-la. |
| Introduce Local Extension | Idem, mas você precisa de *vários* métodos novos. |

### Organizing Data
| Técnica | Quando |
|---|---|
| Self Encapsulate Field | Acesso direto a campos privados dentro da própria classe. |
| Replace Data Value with Object | Um campo de dado tem comportamento e dados associados próprios. |
| Change Value to Reference | Muitas instâncias idênticas que deveriam ser um único objeto. |
| Change Reference to Value | Objeto-referência pequeno demais e raramente mudado para justificar seu ciclo de vida. |
| Replace Array with Object | Um array contém dados de tipos variados. |
| Duplicate Observed Data | Dados de domínio armazenados em classes de GUI. |
| Change Unidirectional Association to Bidirectional | Duas classes precisam uma da outra, mas a associação é só de mão única. |
| Change Bidirectional Association to Unidirectional | Associação bidirecional onde um dos lados não usa o outro. |
| Replace Magic Number with Symbolic Constant | Um número com significado embutido no código. |
| Encapsulate Field | Você tem um campo público. |
| Encapsulate Collection | Classe com campo de coleção e getter/setter ingênuos. |
| Replace Type Code with Class | Campo que contém um type code. |
| Replace Type Code with Subclasses | Type code que afeta diretamente o comportamento. |
| Replace Type Code with State/Strategy | Type code que afeta comportamento mas não permite subclasses. |
| Replace Subclass with Fields | Subclasses que diferem apenas por métodos que retornam constantes. |

### Simplifying Conditional Expressions
| Técnica | Quando |
|---|---|
| Decompose Conditional | Condicional complexo (`if-then/else` ou `switch`). |
| Consolidate Conditional Expression | Múltiplos condicionais levam ao mesmo resultado. |
| Consolidate Duplicate Conditional Fragments | Código idêntico em todos os ramos do condicional. |
| Remove Control Flag | Booleana servindo de flag de controle. |
| Replace Nested Conditional with Guard Clauses | Condicionais aninhados escondem o fluxo normal. |
| Replace Conditional with Polymorphism | Condicional escolhe ação conforme tipo ou propriedade do objeto. |
| Introduce Null Object | Métodos retornam `null` e o código está cheio de checagens. |
| Introduce Assertion | Uma condição precisa ser verdadeira para o código funcionar. |

### Simplifying Method Calls
| Técnica | Quando |
|---|---|
| Rename Method | O nome não explica o que o método faz. |
| Add Parameter | O método não tem dados suficientes. |
| Remove Parameter | O parâmetro não é usado no corpo. |
| Separate Query from Modifier | Um método retorna valor E muda estado. |
| Parameterize Method | Métodos parecidos diferindo só por valores internos. |
| Replace Parameter with Explicit Methods | O método se divide em partes escolhidas pelo valor de um parâmetro. |
| Preserve Whole Object | Você extrai vários valores de um objeto e os passa como parâmetros. |
| Replace Parameter with Method Call | O argumento é só o resultado de uma query que o método poderia chamar. |
| Introduce Parameter Object | Um grupo de parâmetros se repete entre métodos. |
| Remove Setting Method | O campo só deveria ser setado na criação. |
| Hide Method | Método não usado por outras classes. |
| Replace Constructor with Factory Method | O construtor faz mais do que setar parâmetros. |
| Replace Error Code with Exception | O método retorna um valor especial indicando erro. |
| Replace Exception with Test | Você lança exceção onde um teste simples resolveria. |

### Dealing with Generalization
| Técnica | Quando |
|---|---|
| Pull Up Field | Duas classes têm o mesmo campo. |
| Pull Up Method | Subclasses têm métodos que fazem trabalho similar. |
| Pull Up Constructor Body | Construtores das subclasses são quase idênticos. |
| Push Down Method | Comportamento na superclasse usado só por uma/poucas subclasses. |
| Push Down Field | Campo usado só em poucas subclasses. |
| Extract Subclass | Classe com features usadas apenas em certos casos. |
| Extract Superclass | Duas classes com campos e métodos em comum. |
| Extract Interface | Vários clientes usam a mesma parte da interface de uma classe. |
| Collapse Hierarchy | Subclasse praticamente igual à superclasse. |
| Form Template Method | Subclasses implementam algoritmos com passos similares na mesma ordem. |
| Replace Inheritance with Delegation | Subclasse usa só uma parte dos métodos da superclasse. |
| Replace Delegation with Inheritance | Classe com muitos métodos simples que delegam a *todos* os métodos de outra. |

---

## 5. Tensões que o catálogo revela (leitura transversal)

Os smells não são independentes — vários são **o excesso da cura de outro**. Refatorar bem é achar o ponto no dial, não zerar o smell.

| Eixo | Extremo A | Extremo B | Onde fica o meio |
|---|---|---|---|
| Granularidade de classe | **Large Class** / **Divergent Change** | **Lazy Class** / **Shotgun Surgery** | Uma classe = uma razão para mudar |
| Delegação | **Message Chains** (nenhuma) | **Middle Man** (demais) | Hide Delegate até a cadeia sumir, não além |
| Dado vs. comportamento | **Data Class** (dado sem comportamento) | **Feature Envy** (comportamento longe do dado) | Junte — *exceto* quando um Strategy/Visitor separa de propósito |
| Parâmetros vs. acoplamento | **Long Parameter List** | Dependência indesejada (Preserve Whole Object) | O "quando ignorar" de Data Clumps é o árbitro |
| Abstração | **Speculative Generality** (cedo demais) | **Duplicate Code** (tarde demais) | A **Regra dos Três** |

**A regra transversal mais valiosa do site**, de *Parallel Inheritance Hierarchies*: se a de-duplicação está gerando código mais feio, **reverta tudo e conviva com o código**. Refatoração que não deixou o código mais limpo não é refatoração — é churn.
