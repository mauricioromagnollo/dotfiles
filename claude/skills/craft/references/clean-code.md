# Clean Code (Robert C. Martin) — síntese acionável

> Fonte: edição brasileira (Alta Books), "Código Limpo: Habilidades Práticas do Agile Software".
> Citações literais marcadas com `>`. Capítulos 2–7, 9–12, 17.

---

## 0. Premissa do livro

- **A única medida válida de qualidade de código: WTFs/minuto.** (cartum de Thom Holwerda, na Introdução)
- Lei de LeBlanc: **"Nunca é tarde"** (*Later equals never*) — o "limpo depois" não acontece.
- **Regra do Escoteiro**: deixe o código um pouco mais limpo do que você o encontrou.
- Uncle Bob é explícito de que isto é **ofício, não ciência**: > "Não tenho como justificar essa afirmação. Não tenho referências de pesquisas que mostrem que funções muito pequenas são melhores." (cap. 3, sobre tamanho de funções). Leia o livro como heurística de um praticante, não como lei.

---

## 1. Nomes (cap. 2) — regras concretas

| Regra | Detalhe |
|---|---|
| **Nome deve revelar propósito** | Deve responder: por que existe, o que faz, como é usado. **Se um nome precisa de comentário, ele não revela seu propósito.** |
| **Classes e objetos = substantivos** | `Cliente`, `PaginaWiki`, `Conta`, `AnaliseEndereco`. **Nunca um verbo.** Evite `Gerente`, `Processador`, `Dados`, `Info` no nome da classe. |
| **Métodos = verbos** | `postarPagamento`, `excluirPagina`, `salvar`. Acessores/modificadores/predicados com prefixo `get`/`set`/`is` (padrão JavaBean). |
| **Construtor sobrecarregado → factory estático nomeado** | `Complex.FromRealNumber(23.0)` é melhor que `new Complex(23.0)`. Torne o construtor privado para forçar o uso. |
| **Evite informação errada** | `accountList` só se for realmente uma `List`. Prefira `accountGroup`, `bunchOfAccounts`, `accounts`. |
| **Nunca use `l` minúsculo ou `O` maiúsculo** | Parecem `1` e `0`. |
| **Faça distinções significativas** | `a1, a2, ..., aN` é o oposto de nomes expressivos. `Product` vs `ProductInfo` vs `ProductData` não distinguem nada. `getActiveAccount()` / `getActiveAccounts()` / `getActiveAccountInfo()` = impossível saber qual chamar. |
| **Ruído é redundante** | Nome de variável nunca contém "variável"; nome de tabela nunca contém "tabela". `NameString` não é melhor que `Name`. |
| **Nomes pronunciáveis** | `genymdhms` → `generationTimestamp`. > "Se não puder pronunciá-lo, não terá como discutir sobre tal nome sem parecer um idiota." |
| **Nomes buscáveis** | Constantes com nome > número solto. `MAX_CLASSES_PER_STUDENT` é grepável; `7` não. **O tamanho de um nome deve ser proporcional ao tamanho do escopo.** Nome de uma letra só dentro de métodos pequenos. |
| **Evite codificações** | Sem Notação Húngara. Sem prefixo `m_` em membros. |
| **Interfaces sem `I`** | Prefira `ShapeFactory` (interface) + `ShapeFactoryImpl` (implementação) a `IShapeFactory`. > "Não quero que meus usuários saibam que estou lhes dando uma interface." |
| **Evite mapeamento mental** | `i`, `j`, `k` OK em loops de escopo mínimo (nunca `l`). Fora disso, não. > "Uma diferença entre um programador esperto e um programador profissional é que este entende que clareza é fundamental." |
| **Não dê uma de espertinho** | `HolyHandGrenade` → `DeleteItems`. Clareza > divertimento. Sem gírias/coloquialismos. |
| **Uma palavra por conceito** | Não misture `pegar`/`recuperar`/`obter` para a mesma ideia. Nem `controlador`/`gerenciador`/`driver` no mesmo código. |
| **Não faça trocadilhos** | O inverso da regra acima: não use `add` para "somar" e para "inserir em coleção". Semânticas diferentes → nomes diferentes (`insert`, `append`). |
| **Domínio da solução antes do domínio do problema** | Use termos técnicos (`AccountVisitor`, `JobQueue`) quando existirem; caia no domínio do problema só quando não houver termo "à la programador". |
| **Adicione contexto** | `firstName, lastName, street, state` → prefixe (`addrState`) ou, melhor, crie a classe `Address`. |

**Nuance**: Uncle Bob aceita prefixos `um`/`a` *se* fizerem distinção significativa (ex.: `um` para locais, `a` para parâmetros). O problema é `aZork` só porque `zork` já existe.

---

## 2. Funções (cap. 3) — regras concretas

### Tamanho
- **Regra 1: funções devem ser pequenas. Regra 2: devem ser menores ainda.**
- **Máximo ~20 linhas.** Ideal: 2 a 4 linhas (o Sparkle de Kent Beck).
- **Blocos dentro de `if`/`else`/`while` devem ter uma linha** — provavelmente uma chamada de função (que ganha um nome descritivo).
- **Nível de endentação máximo: 1 ou 2.**

### Uma coisa só
> **"AS FUNÇÕES DEVEM FAZER UMA COISA. DEVEM FAZÊ-LA BEM. DEVEM FAZER APENAS ELA."**

- **Teste operacional de "uma coisa"**: se você consegue extrair outra função dela com um nome que **não seja apenas uma reformulação da implementação**, ela faz mais de uma coisa (G34).
- **Seções dentro da função** (declarações / inicializações / seleção) = indício óbvio de fazer mais de uma coisa.
- **Um nível de abstração por função.** Misturar níveis confunde: o leitor não sabe o que é conceito essencial e o que é detalhe. > "como janelas quebradas, uma vez misturados os detalhes aos conceitos, mais e mais detalhes tendem a se agregar."
- **Regra Decrescente**: leia o código de cima para baixo como uma narrativa; cada função é seguida pelas do próximo nível de abstração (parágrafos "TO ...").

### Parâmetros
- **Ideal: 0 (nulo). Depois 1 (mônade), 2 (díade). 3 (tríade) deve ser evitado sempre que possível. Mais de 3 (políade) exige motivo muito especial — e mesmo assim não devem ser usados.**
- Heurística F1 (cap. 17) reafirma: **"Mais do que isso é questionável e deve-se evitar com preconceito."**
- **Formas mônades legítimas** (só três):
  1. Pergunta sobre o argumento: `boolean fileExists("MyFile")`
  2. Transformação do argumento, retornada: `InputStream fileOpen("MyFile")`
  3. Evento (entrada, sem saída, muda estado do sistema): `void passwordAttemptFailedNtimes(int attempts)` — use com cautela.
- **Se transforma o argumento, a transformação deve aparecer no valor de retorno.** `StringBuffer transform(StringBuffer in)` > `void transform(StringBuffer out)`.
- **Parâmetros booleanos (flag arguments) são feios.** > "Passar um booleano para uma função certamente é uma prática horrível, pois ele complica imediatamente a assinatura do método, mostrando explicitamente que a função faz mais de uma coisa." `render(true)` → divida em `renderForSuite()` e `renderForSingleTest()`.
- **Parâmetros de saída: evite.** Se a função precisa mudar estado, mude o estado do objeto dono. `report.appendFooter()` > `appendFooter(report)`.
- **Nuance sobre díades**: são aceitáveis quando os dois parâmetros são **componentes ordenados de um único valor** — `new Point(0,0)` é natural; `writeField(outputStream, name)` não. Mesmo `assertEquals(expected, actual)` é problemático (a ordem é convenção decorada). > "Díades não são ruins, e você certamente terá de usá-las."
- **Argumentos em excesso → objeto de argumento** ou embuta os nomes no nome da função (`assertExpectedEqualsActual(expected, actual)`).

### Efeitos colaterais
- **Efeitos colaterais são mentiras.** `checkPassword()` que chama `Session.initialize()` cria **acoplamento temporal** escondido.
- Se o acoplamento temporal é necessário, **deixe-o claro no nome** (`checkPasswordAndInitializeSession`) — > "embora isso certamente violaria o 'fazer apenas uma única coisa'". Uncle Bob prefere um nome honesto e feio a um nome bonito e mentiroso.

### Separação comando-consulta
- **Funções devem fazer *ou* responder algo, não ambos.** `if (set("username", "unclebob"))` é ambíguo: `set` é verbo ou adjetivo?
- Corrija separando: `if (attributeExists("username")) { setAttribute("username", "unclebob"); }`

### Outras
- **Não repita (DRY).** > "A duplicação pode ser a raiz de todo o mal no software."
- **Programação estruturada (Dijkstra: um `return`, sem `break`/`continue`/`goto`)**: Uncle Bob **dispensa a regra em funções pequenas**. > "se você mantiver suas funções pequenas, então as várias instruções return, break ou continue casuais não trarão problemas e poderão ser até mesmo mais expressivas". Só o `goto` continua proibido.
- **`switch`**: por definição faz N coisas. **Regra**: aceitável se aparecer **uma única vez**, para criar objetos polimórficos, e ficar **escondido atrás de uma herança/ABSTRACT FACTORY**. Nuance explícita: > "É claro que cada caso é um caso e haverá vezes que não respeitarei uma ou mais partes dessa regra."
- **Como escrever assim**: ninguém escreve limpo de primeira. Escreva feio, cubra com testes, **depois** refatore. Funções não nascem pequenas — ficam pequenas.

---

## 3. Comentários (cap. 4) — regras concretas

> "Não insira comentários num código ruim, reescreva-o." — Kernighan & Plauger

> **"Comentários são sempre fracassos."** — o uso adequado de comentários é **compensar nosso fracasso em nos expressar no código**.

- **Por que são ruins: eles mentem.** Não intencionalmente, mas o código muda e os comentários não o seguem. > "Só se pode encontrar a verdade em um lugar: no código."
- **Comentários imprecisos são muito piores do que nenhum.**
- **Explique-se no código**: `// Verifica se o funcionario tem direito a todos os beneficios` + `if ((employee.flags & HOURLY_FLAG) && (employee.age > 65))` → `if (employee.isEligibleForFullBenefits())`.

### Comentários **bons** (a lista completa que Uncle Bob aceita)
1. **Legais** — copyright, licença. Prefira referenciar a licença externa.
2. **Informativos** — mas o nome da função quase sempre é melhor (`responderBeingTested`).
3. **Explicação da intenção** — *por que* essa decisão. Talvez você discorde, mas sabe o que ele queria.
4. **Esclarecimento** — traduzir parâmetro/retorno obscuro **de biblioteca padrão ou código que você não pode alterar**. Risco: pode estar errado.
5. **Alerta sobre consequências** — `// SimpleDateFormat não é thread safe`.
6. **TODO** — legítimo, mas *não justifica deixar código ruim no sistema*; varra-os regularmente.
7. **Destaque** — realçar o que parece irrelevante (`// a função trim é muito importante`).
8. **Javadoc em API pública** — se você publica API, escreva bons javadocs. Mas eles podem mentir como qualquer outro comentário.

> Ressalva do próprio autor: **"o único comentário verdadeiramente bom é aquele em que você encontrou uma forma para não escrevê-lo."**

### Comentários **ruins**
Murmúrio; redundantes; enganosos; obrigatórios (javadoc em toda função); de diário/changelog; ruído; usar comentário onde caberia uma função ou variável; marcadores de posição; comentário de `}` de fechamento; atribuições/créditos (o VCS lembra); **código comentado** (abominação — exclua); comentário HTML; informação não-local; informação demais; conexão não óbvia; cabeçalhos de função (funções curtas e bem nomeadas não precisam).

### ⚠️ Crítica conhecida da comunidade
O capítulo é frequentemente levado ao extremo de **"não comente nada"**, o que o livro não diz — ele lista 8 categorias de comentários bons. A crítica legítima é que Uncle Bob subestima o comentário de **"por quê"** (contexto histórico, trade-off, workaround de bug de terceiro, referência a RFC/ticket): esse tipo de informação **não é expressável em nome de função** e é justamente o que mais se perde. A regra defensável hoje: *o código diz o **quê** e o **como**; o comentário diz o **porquê***.

---

## 4. Formatação (cap. 5) — regras concretas

- **Formatação é comunicação — e comunicação é a primeira regra do negócio de um desenvolvedor profissional.** > "Seu estilo e disciplina sobrevivem, mesmo que seu código não."
- **Time inteiro concorda com um único conjunto de regras.** Use ferramenta automatizada.

### Vertical
- **Arquivo: ~200 linhas típicas, limite de ~500.** (FitNesse: ~50k linhas com média de 65 linhas/arquivo; maior ≈ 400.) *Não é regra fixa, mas "deve-se considerá-la bastante".*
- **Metáfora do jornal**: nome/manchete no topo → sinopse de alto nível → detalhes descendo.
- **Espaçamento vertical entre conceitos**: linha em branco separa pensamentos completos.
- **Continuidade vertical**: linhas intimamente relacionadas ficam juntas (comentários inúteis quebram essa intimidade).
- **Distância vertical**: conceitos intimamente relacionados ficam verticalmente próximos.
  - **Variáveis locais**: declare o mais próximo possível do uso, no topo da função (funções são pequenas).
  - **Variáveis de controle de loop**: dentro da estrutura de iteração.
  - **Variáveis de instância**: em um **local bem conhecido** — no início da classe, por convenção Java. > "Não vejo motivo para seguir uma ou outra convenção. O importante é que ... todos devem saber onde buscar as declarações."
  - **Funções dependentes**: a que chama fica **acima** da chamada.
  - **Afinidade conceitual**: funções que variam a mesma tarefa ficam juntas mesmo sem se chamarem.
- **Ordenação vertical**: chamadas apontam **para baixo**, do alto nível ao baixo nível.

### Horizontal
- **~120 caracteres por linha** (o livro cita que dá para colocar 150, "não se deve ultrapassar esse limite").
- Espaçamento horizontal para associar/dissociar (operadores de precedência alta sem espaço).
- **Não alinhe declarações em colunas** — o alinhamento realça a coisa errada (o tipo, não o nome).
- **Endentação é obrigatória** — não colapse escopos em uma linha, mesmo em `if`/`while` curtos.
- **Regras da equipe > preferências pessoais.** > "Um bom sistema de software é composto por um conjunto de documentos que se lêem com clareza. Eles precisam ter um estilo consistente e agradável."

---

## 5. Objetos e Estruturas de Dados (cap. 6)

- **Objetos** escondem dados por trás de abstrações e expõem funções que operam neles.
- **Estruturas de dados** expõem dados e não têm funções significativas.
- **São opostos complementares.** Adicionar getter/setter em tudo **não** cria abstração:
  > "Ocultar a implementação não é só uma questão de colocar uma camada de funções entre as variáveis. É uma questão de **abstração**."
  - Concreto: `getFuelTankCapacityInGallons()` + `getGallonsOfGasoline()`
  - Abstrato: `getPercentFuelRemaining()` ← **preferível**
- **A pior opção é adicionar levianamente métodos de escrita e leitura.**

### A anti-simetria fundamental
> "O código procedimental (usado em estruturas de dados) facilita a adição de novas funções sem precisar alterar as estruturas de dados existentes. O código orientado a objeto (OO), por outro lado, facilita a adição de novas classes sem precisar alterar as funções existentes."
>
> E o inverso também é verdade.

**Nuance crítica** (muito ignorada por quem cita o livro): > **"Programadores experientes sabem que a ideia de que tudo é um objeto é um mito. Às vezes, você realmente deseja estruturas de dados simples com procedimentos operando nelas."** Escolha o paradigma pelo eixo de mudança esperado.

### Lei de Demeter
Um método `f` da classe `C` só deve chamar métodos de:
1. `C` mesma
2. um objeto **criado** por `f`
3. um objeto **passado como parâmetro** para `f`
4. um objeto em uma **variável de instância** de `C`

**Não** chame métodos em objetos retornados por essas funções. *"Fale apenas com conhecidos, não com estranhos."*

- **Train wrecks** (`ctxt.getOptions().getScratchDir().getAbsolutePath()`): quebre em linhas.
- **Nuance**: > "Se isso é uma violação da Lei de Demeter **depende se ctxt, Options e ScratchDir são ou não objetos ou estruturas de dados**." Se forem estruturas de dados, a lei **não se aplica** — elas naturalmente expõem suas entranhas. O problema é que getters/setters confundem a distinção.
- **Solução real**: pare de perguntar, mande fazer → `ctxt.createScratchFileStream(classFileName)`.

### Híbridos
Metade objeto, metade estrutura de dados (funções significativas + getters/setters públicos). **A pior coisa das duas condições** — dificultam adicionar funções *e* estruturas. Evite.

### DTO
A forma pura de estrutura de dados: **classe com variáveis públicas e nenhuma função**. Útil para banco, sockets, parsing. O formato "bean" (privadas + get/set) *"parece fazer alguns puristas da OO sentirem-se melhores, mas geralmente não oferece vantagem alguma"*.

---

## 6. Tratamento de Erro (cap. 7) — regras concretas

- **Use exceções, não códigos de retorno de erro.** Códigos de erro entopem o chamador e criam aninhamento; e é fácil esquecer de checar.
- **Escreva o `try-catch-finally` primeiro.** Blocos `try` são como **transações**: o `catch` deve deixar o programa em estado consistente. Comece pelo teste que força a exceção.
- **Use exceções não verificadas (unchecked).** > "A discussão acabou."
  - **Preço das checked exceptions: violação do Princípio Aberto-Fechado.** Um `throws` num nível baixo cascateia assinaturas até o topo. **Quebra o encapsulamento** — todas as funções no caminho precisam conhecer o detalhe de baixo nível.
  - **Ressalva**: > "As exceções verificadas podem às vezes ser úteis se você estiver criando uma **biblioteca crítica**: é preciso capturá-las. Mas no desenvolvimento geral de aplicativo, os custos da dependência superam as vantagens."
- **Forneça contexto com as exceções.** Mensagem informativa: **operação que falhou + tipo da falha**. Stack trace não diz a intenção.
- **Defina classes de exceção pela necessidade do chamador**, não pela origem/tipo do erro.
  - **Empacote (wrap) APIs de terceiros** — > "empacotar APIs de terceiros é a melhor prática que existe". Minimiza dependência, facilita trocar de biblioteca, facilita mockar em testes, e você define a API que preferir.
  - **Geralmente uma única classe de exceção basta para uma parte do código.** Use classes diferentes **só** quando quiser capturar uma e deixar a outra passar.
- **Defina o fluxo normal** — **Special Case Pattern** (Fowler): crie uma classe/objeto que trate o caso especial, para que o cliente não tenha `try/catch` na lógica de negócio. Ex.: `PerDiemMealExpenses` sempre retorna um total.
- **NÃO RETORNE `null`.** Cada `null` retornado é trabalho extra para o chamador e um `NullPointerException` esperando acontecer. Prefira **exceção** ou **objeto de caso especial** (`Collections.emptyList()`).
- **NÃO PASSE `null`.** Pior ainda. Não há bom jeito de tratar `null` passado por engano; proíba por política.

> Fechamento do capítulo: > "Podemos criar um código limpo e robusto se virmos o tratamento de erro como uma questão separada, algo que possa ser visto independente de nossa lógica principal."

---

## 7. Testes de Unidade (cap. 9)

### As Três Leis do TDD
1. **Não escreva código de produção até criar um teste de unidade que falhe.**
2. **Não escreva mais de um teste de unidade do que o necessário para falhar** — e *não compilar é falhar*.
3. **Não escreva mais código de produção do que o necessário para passar no teste atual.**

Ciclo ≈ 30 segundos.

### Manter os testes limpos
- > **"Os códigos de testes são tão importantes quanto o código de produção."** Não é cidadão de segunda classe.
- Teste sujo → difícil de mudar → vira o gargalo → o time descarta a suíte → o medo volta → o código de produção apodrece. Uncle Bob conta essa história como caso real que ele orientou.
- **Os testes habilitam as "-idades"** (flexibilidade, manutenibilidade, reusabilidade). > "Se você tiver testes, não terá medo de alterar o código!"
- **O que torna um teste limpo? "Três coisas: legibilidade, legibilidade e legibilidade."**
- Padrão **CONSTRUIR-OPERAR-VERIFICAR** (build-operate-check) / dado-quando-então.
- **Crie uma DSL de teste** — API específica do domínio de teste que torna os testes expressivos.
- **Padrão duplo**: código de teste pode ser ineficiente (ex.: concatenar String em vez de StringBuffer) onde o de produção não poderia. > "Há coisa que você talvez jamais faça num ambiente de produção que esteja perfeitamente bem em um ambiente de teste... **Mas nunca de clareza.**"

### Um assert por teste — a NUANCE
Uncle Bob **não endossa a regra dogmaticamente**. Ele mostra a divisão em `assertResponseIsXML()` / `assertResponseContains(...)`, mostra que dividir gera duplicação, e conclui:

> "**No final, prefiro as confirmações múltiplas na Listagem 9.2.**"
>
> "Acho que a regra da confirmação única é uma **boa orientação**. ... Mas **não tenho receio de colocar mais de uma confirmação em um teste**. Acho que a melhor coisa que podemos dizer é que se deve **minimizar o número de confirmações** em um teste."

### Um conceito por teste — a regra que ele realmente defende
> "Talvez a melhor regra seja que desejamos **um único conceito em cada função de teste**."

Regra final combinada: **minimize o número de asserts por conceito e teste apenas um conceito por função de teste.**

### F.I.R.S.T.
| | Regra | O que significa |
|---|---|---|
| **F** | **Fast** (Rapidez) | Testes lentos não são rodados; problemas não são achados cedo; você deixa de limpar o código. |
| **I** | **Independent** (Independência) | Um teste não configura condições para o próximo. Rode em qualquer ordem. Dependência → cascata de falhas que esconde defeitos. |
| **R** | **Repeatable** (Repetitividade) | Rode em produção, em QA, e no notebook no trem sem rede. Senão você sempre terá desculpa para falhas. |
| **S** | **Self-validating** (Autovalidação) | Saída booleana. Sem ler log, sem diff manual. Senão a falha vira subjetiva. |
| **T** | **Timely** (Pontualidade) | Escreva o teste **imediatamente antes** do código de produção. Depois, o código sai não-testável. |

---

## 8. Classes (cap. 10)

### Organização (convenção Java)
Ordem: constantes públicas estáticas → estáticas privadas → instâncias privadas → funções públicas (com as privadas usadas por elas logo abaixo). **Raramente há boa razão para variável pública.**

### Encapsulamento — nuance
> "Gostaríamos que nossas variáveis e funções fossem privadas, **mas não somos radicais**. Às vezes, precisamos tornar uma variável ou função protegida de modo que possa ser acessada para testes. **Para nós, o teste tem prioridade.** ... Perder o encapsulamento sempre é o último recurso."

### Tamanho
- **Regra 1: classes devem ser pequenas. Regra 2: devem ser menores ainda.**
- **Mede-se em RESPONSABILIDADES, não em linhas** (diferente de funções).
- **Teste do nome**: se você não consegue derivar um nome conciso, ela é grande demais. `Processador`, `Gerenciador`, `Super` = acúmulo de responsabilidades.
- **Teste das 25 palavras**: descreva a classe em ~25 palavras **sem usar "se", "e", "ou", "mas"**. Um "e" já denuncia responsabilidade demais.
- Uma classe com **5 métodos** ainda pode ser grande demais (o exemplo `SuperDashboard`).

### SRP
> "Uma classe ou módulo deve ter **um, e apenas um, motivo para mudar**."

> "O SRP é um dos conceitos mais importantes no desenvolvimento OO. É também um dos mais simples para se entender e aprender. Mesmo assim, estranhamente, **o SRP geralmente é o princípio mais ignorado** na criação de classes."

Por quê? > "Fazer um software funcionar e torná-lo limpo são duas coisas bem diferentes." Achamos que terminamos quando funciona.

**Contra-argumento respondido**: "muitas classes pequenas dificultam entender o todo?" → Não. > "você quer suas ferramentas organizadas em caixas de ferramentas com muitas gavetas pequenas, cada uma com objetos bem classificados e rotulados? Ou poucas gavetas nas quais você coloca tudo?" O ponto é entender **só** a complexidade que afeta o momento.

### Coesão
- **Classes devem ter um número pequeno de variáveis de instância.**
- **Cada método deve manipular uma ou mais dessas variáveis.** Quanto mais variáveis um método usa, mais coeso ele é para sua classe.
- **Classe maximamente coesa**: cada variável usada por cada método.
- **Nuance**: > "De modo geral, **não é aconselhável e nem possível** criar tais classes totalmente coesas; por outro lado, gostaríamos de obter uma alta coesão."
- **Mecânica da descoberta**: manter funções pequenas + listas de parâmetros curtas **prolifera variáveis de instância** → isso é o sinal de que **há outra classe tentando sair** da classe maior. Perder coesão ao dividir funções → divida a classe. *É assim que o design emerge.*

### Organizar para alterações
- **OCP**: classes devem ser abertas para extensão, fechadas para modificação. Adicionar recurso = **estender**, não modificar.
- **DIP**: dependa de abstrações, não de concretudes. Isso também é o que torna a classe testável (injetar um stub/mock).

---

## 9. Sistemas (cap. 11)

- **Separe a construção do sistema do seu uso.** `main` (e as fábricas) constrói o grafo de objetos; a aplicação apenas usa. Lazy init/`if (x == null) x = new ...` espalhado é uma violação de SRP + DIP + testabilidade.
- **Dependency Injection** — inversão de controle: o objeto não se responsabiliza por instanciar suas dependências.
- **Escale incrementalmente.** > "Sistemas de software são únicos comparados aos sistemas físicos": a arquitetura pode crescer de forma incremental **se** mantivermos a separação de interesses adequada. Não existe "acertar a arquitetura na primeira vez" — existe manter o custo de mudança baixo.
- **POJOs + aspectos** (AOP, proxies, EJB3/Spring) para separar interesses transversais (persistência, transação, segurança) de forma **não invasiva**.
- **Use padrões sabiamente, quando adicionarem valor demonstrável.** Crítica embutida do próprio livro: times adotaram EJB2 "porque era o padrão"; > "Já vi equipes ficarem obcecadas com diversos padrões muito populares e perderem o foco no quesito de implementação voltado para seus consumidores."
- **Sistemas precisam de DSLs** — minimizar a "distância de comunicação" entre o conceito do domínio e o código.
- **Adie decisões até o último momento responsável** — decida com informação máxima.
- Fechamento: > "Esteja você desenvolvendo sistemas ou módulos individuais, jamais se esqueça de usar **a coisa mais simples que funcione**."

---

## 10. Emergência (cap. 12) — As 4 Regras do Design Simples de Kent Beck

> "Essas regras estão **em ordem de relevância**."

### 1. Efetue todos os testes (o mais importante)
- Um sistema que não pode ser verificado **jamais deveria ser implementado**.
- **Mecanismo virtuoso**: querer testar → força classes pequenas e de propósito único (SRP) → testar força baixo acoplamento (DIP, injeção de dependência, interfaces).
- > "Criar testes leva a projetos melhores."

### 2. Sem duplicação
- > "A repetição de código é o inimigo principal para um sistema bem desenvolvido."
- Inclui **duplicação de implementação**, não só linhas idênticas: `isEmpty()` com booleano próprio + `size()` com contador → `isEmpty() { return 0 == size(); }`.
- **Elimine duplicação mesmo de 3 linhas** (extraia `replaceImage()`).
- **Por que**: extrair no nível baixíssimo **revela violações de SRP** e habilita "pequena reutilização" → reduz complexidade do sistema.
- Ferramenta de alto nível: **TEMPLATE METHOD** (e STRATEGY).

### 3. Expressividade (expressar o propósito do programador)
- **A maioria do custo de um software está na manutenção de longo prazo.**
- Como: bons nomes; classes e funções pequenas (que são fáceis de nomear); **nomenclatura padrão de padrões de projeto** (`...Command`, `...Visitor`); testes de unidade bem escritos **como documentação**.
- > "Mas a forma mais importante de ser expressivo é **tentar**. ... Lembre-se de que é muito mais provável que essa outra pessoa seja você."

### 4. Poucas classes e métodos (o de MENOR prioridade)
- Contrapeso explícito às regras 2 e 3: > "**Podem-se exagerar mesmo nos conceitos mais fundamentais**, como a eliminação de duplicação, expressividade do código e o SRP. Numa tentativa de tornar nossas classes e métodos pequenos, podemos vir a criar **estruturas minúsculas**."
- Alvos nomeados: **interface para cada classe**; separar sempre dados e comportamento em classes distintas.
- > "Deve-se **evitar tal dogmatismo** e adotar uma abordagem mais pragmática."
- Mas: > "embora seja importante manter baixa a quantidade de classes e funções, **é mais importante ter testes, eliminar a duplicação e se expressar**."

**Esta é a regra mais esquecida do livro** — é a válvula de escape explícita do próprio Uncle Bob contra o excesso das outras três.

---

## 11. Cap. 17 — Odores e Heurísticas (lista completa)

Origem: os "code smells" de Fowler (*Refactoring*) + os do próprio Martin, compilados ao refatorar os estudos de caso.

### Comentários (C)
| # | Nome | Uma linha |
|---|---|---|
| **C1** | Informações inapropriadas | Metadados (autor, data, changelog) pertencem ao VCS/issue tracker, não ao comentário. |
| **C2** | Comentário obsoleto | Velho, irrelevante, incorreto. Atualize ou delete já — vira "ilha flutuante de irrelevância". |
| **C3** | Comentários redundantes | `i++; // incrementa i`. Javadoc que só repete a assinatura. |
| **C4** | Comentário mal escrito | Se vale escrever, vale escrever bem: gramática, concisão, sem o óbvio. |
| **C5** | Código como comentário | > "Colocar códigos em comentários é uma abominação." Exclua — o VCS lembra. |

### Ambiente (E)
| # | Nome | Uma linha |
|---|---|---|
| **E1** | Construir requer mais de uma etapa | Um comando. `svn get mySystem; cd mySystem; ant all`. |
| **E2** | Testes requerem mais de uma etapa | Um botão na IDE, ou um comando na shell. |

### Funções (F)
| # | Nome | Uma linha |
|---|---|---|
| **F1** | Parâmetros em excesso | 0 > 1 > 2 > 3. Mais que isso é questionável e "deve-se evitar com preconceito". |
| **F2** | Parâmetros de saída | Inesperados. Mude o estado do objeto no qual a função é chamada. |
| **F3** | Parâmetros lógicos | Booleano declara que a função faz mais de uma coisa. Elimine. |
| **F4** | Função morta | Método nunca chamado. Delete sem medo. |

### Geral (G) — as 36
| # | Nome | Uma linha |
|---|---|---|
| **G1** | Múltiplas linguagens em um arquivo fonte | Ideal: uma linguagem por arquivo. Minimize as extras. |
| **G2** | Comportamento óbvio não implementado | Princípio da Menor Surpresa: implemente o que o outro programador esperaria. |
| **G3** | Comportamento incorreto nos limites | Não confie na intuição. Cada condição de limite merece um teste. |
| **G4** | Seguranças anuladas | Desligar warnings do compilador / testes que falham = Chernobyl. |
| **G5** | **Duplicação** | > "Uma das regras mais importantes neste livro." DRY / "Uma vez, e apenas uma". Toda duplicação é oportunidade perdida de abstração. |
| **G6** | Código no nível errado de abstração | `percentFull()` não pertence a `Stack` — pertence a `BoundedStack`. A separação deve ser **total**. |
| **G7** | Classes base dependem das derivadas | Base não deve saber nada das derivadas. **Exceção admitida**: nº fixo de derivadas (máquinas de estado finito) implementadas no mesmo jar. |
| **G8** | Informações excessivas | Interface pequena faz muito com pouco. Esconda dados, utilitários, constantes, temporárias. Menos métodos = melhor. |
| **G9** | Código morto | Não executado. Apodrece e passa a mentir sobre as convenções atuais. "Dê a ele um funeral decente." |
| **G10** | Separação vertical | Variáveis declaradas logo acima do primeiro uso; funções privadas logo abaixo. |
| **G11** | Inconsistência | Faça coisas similares da mesma forma. Princípio da menor surpresa. |
| **G12** | Entulho | Construtor vazio, variável não usada, função nunca chamada, comentário sem informação. Remova. |
| **G13** | Acoplamento artificial | Coisas que não dependem uma da outra não devem ser acopladas (enum genérico dentro de classe específica). |
| **G14** | Feature Envy | Método interessado nas variáveis de **outra** classe. (Smell de Fowler.) |
| **G15** | Parâmetros seletores | `false` pendurado no fim da chamada. Preguiça de dividir a função. |
| **G16** | Propósito obscuro | Expressões contínuas, notação húngara, números mágicos escondem a intenção. |
| **G17** | Responsabilidade mal posicionada | Onde colocar o código é uma das decisões mais importantes. Princípio da menor surpresa: onde o leitor esperaria. |
| **G18** | Modo estático inadequado | `Math.max(a,b)` OK. Se há chance de querer comportamento polimórfico, faça método de instância. |
| **G19** | Use variáveis descritivas | Quebre cálculos em valores intermediários com nomes. "Uma das formas mais poderosas de tornar um programa legível." |
| **G20** | Nomes de funções devem dizer o que fazem | `date.add(5)` — dias? semanas? muta ou retorna? Se precisa ler a implementação, o nome falhou. |
| **G21** | Entenda o algoritmo | Não faça funcionar jogando `if`s e flags. Entenda antes de declarar pronto. |
| **G22** | Torne dependências lógicas em físicas | Não presuma; **pergunte explicitamente** ao módulo do qual você depende. |
| **G23** | Prefira polimorfismo a `if/else`/`switch` | Regra prática: **uma vez** por tipo de switch, e só onde funções crescem mais que tipos. |
| **G24** | Siga as convenções padrões | Convenção do time > preferência pessoal. O código deve documentar a convenção. |
| **G25** | Substitua números mágicos por constantes nomeadas | `86400` → `SECONDS_PER_DAY`. **Nuance forte**: constantes auto-explicativas em fórmulas legíveis dispensam nome — `feetWalked/5280.0`, `hourlyRate * 8`, `radius * Math.PI * 2` (`TWO` seria "um absurdo"). Mas `PI` merece constante porque **a chance de erro de digitação é grande demais**. E "número mágico" vale para **qualquer token não auto-explicativo**, não só números (ex.: `assertEquals(7777, ...)` e a própria string `"John Doe"`). |
| **G26** | Seja preciso | Float para dinheiro é "quase criminoso". Não presuma que a primeira busca é única. Não ignore concorrência. |
| **G27** | Estrutura acima de convenção | `switch` + enum bem nomeado é inferior a classe base com métodos abstratos — **a estrutura força o cumprimento**. |
| **G28** | Encapsule as condicionais | `if (shouldBeDeleted(timer))` > `if (timer.hasExpired() && !timer.isRecurrent())`. |
| **G29** | Evite condicionais negativas | `if (buffer.shouldCompact())` > `if (!buffer.shouldNotCompact())`. |
| **G30** | Funções devem fazer uma coisa só | Função com "seções" → divida. |
| **G31** | Acoplamentos temporais ocultos | Se a ordem importa, **exponha-a**: faça cada função receber o resultado da anterior (passe o "bastão"). |
| **G32** | Não seja arbitrário | Tenha um motivo para a estrutura e comunique-o na estrutura. Estrutura arbitrária convida outros a alterá-la. |
| **G33** | Encapsule as condições de limites | Não espalhe `+1`/`-1`. `nextLevel = level + 1` uma vez. |
| **G34** | Funções devem descer apenas **um** nível de abstração | > "Isso pode ser o mais difícil dessas heurísticas para se interpretar e seguir." |
| **G35** | Mantenha dados configuráveis em níveis altos | Constante conhecida no alto nível não deve morar numa função de baixo nível — passe como parâmetro. |
| **G36** | Evite navegação transitiva | `a.getB().getC().doSomething()` — Lei de Demeter / "criar um amigo". |

### Java (J)
| # | Nome | Uma linha |
|---|---|---|
| **J1** | Evite longas listas de import usando wildcards | `import package.*;` é preferível a 80 imports. |
| **J2** | Não herde as constantes | Herdar interface só para pegar constantes é abuso; use `static import`. |
| **J3** | Constantes versus enum | Use `enum` — eles têm métodos e campos, são muito mais expressivos que `int` constantes. |

### Nomes (N)
| # | Nome | Uma linha |
|---|---|---|
| **N1** | Escolha nomes descritivos | > "Nomes em softwares são 90% responsáveis pela legibilidade." Reavalie frequentemente. |
| **N2** | Escolha nomes no nível apropriado de abstração | Não nomeie pela implementação. Nomeie pelo nível da classe/função. |
| **N3** | Use nomenclatura padrão onde for possível | `AutoHangupModemDecorator`. Padrões de projeto no nome comunicam design. |
| **N4** | Nomes não ambíguos | `doRename()` que na verdade renomeia o *módulo* → `renameModule()`. |
| **N5** | **Use nomes longos para escopos grandes** | O comprimento do nome ∝ tamanho do escopo. `i`/`j` OK em 5 linhas. |
| **N6** | Evite codificações | Sem `m_`/`f_`, sem prefixo de subsistema (`siv`). |
| **N7** | Nomes devem descrever os efeitos colaterais | `getOos()` que cria o oos se não existir → `createOrReturnOos()`. |

### Testes (T)
| # | Nome | Uma linha |
|---|---|---|
| **T1** | Testes insuficientes | "Parece que já está bom" não é medida. **Teste tudo que pode vir a falhar.** |
| **T2** | Use uma ferramenta de cobertura! | Ela mostra as lacunas — `if`/`catch` cujos corpos nunca rodaram. |
| **T3** | Não pule testes triviais | Baratos e o valor de documentação supera o custo. |
| **T4** | Um teste ignorado é uma questão sobre uma ambiguidade | `@Ignore` = pergunta pendente sobre um requisito não claro. |
| **T5** | Teste as condições de limites | Acertamos o miolo do algoritmo e erramos as bordas. |
| **T6** | Teste abundantemente bugs próximos | **Bugs se reúnem.** Achou um numa função? Teste-a exaustivamente. |
| **T7** | Padrões de falhas são reveladores | A *forma* como os testes falham diagnostica o problema. |
| **T8** | Padrões de cobertura podem ser reveladores | O que **não** foi executado explica por que os que falharam falham. |
| **T9** | Testes devem ser rápidos | > "Um teste lento é um que não será rodado." |

**Encerramento do próprio autor**: > "Mal poderíamos dizer que esta lista de heurísticas e odores esteja completa." Ele apresenta como **catálogo pessoal de um praticante**, não como norma.

---

## 12. Nuances e ressalvas de Uncle Bob (consolidado)

Onde o próprio livro relativiza suas regras:

1. **Tamanho de funções** — sem base empírica, admitido explicitamente ("Não tenho como justificar essa afirmação").
2. **`switch`** — a regra "uma vez, escondido atrás de factory" tem exceção declarada: "cada caso é um caso e haverá vezes que não respeitarei uma ou mais partes dessa regra."
3. **Programação estruturada** — as regras de Dijkstra (um `return`, sem `break`/`continue`) são **descartadas** em funções pequenas.
4. **Díades** — necessárias e legítimas quando os argumentos são componentes de um único valor (`new Point(0,0)`).
5. **Efeitos colaterais** — se o acoplamento temporal é inevitável, nome honesto e feio > "uma coisa só".
6. **Comentários** — 8 categorias explicitamente **boas**. O capítulo não diz "nunca comente".
7. **Lei de Demeter** — **não se aplica a estruturas de dados**, só a objetos.
8. **"Tudo é objeto" é um mito** — às vezes você quer estrutura de dados + procedimento. Escolha pelo eixo de mudança.
9. **Checked exceptions** — úteis em **bibliotecas críticas**; ruins em aplicação.
10. **Encapsulamento** — pode ser afrouxado (protected/package) **para testar**. "Para nós, o teste tem prioridade."
11. **Coesão total** — "não é aconselhável e nem possível". Busque *alta*, não *máxima*.
12. **Um assert por teste** — Uncle Bob **prefere múltiplos asserts** no exemplo real. A regra que ele defende é **um conceito por teste**.
13. **Design Simples regra 4** — antídoto explícito contra o dogmatismo das regras 1–3. "Deve-se evitar tal dogmatismo e adotar uma abordagem mais pragmática."
14. **Padrões de projeto** — usar "porque é padrão" (EJB2) é criticado pelo próprio livro.
15. **G7 (base ↔ derivada)** — exceção admitida para máquinas de estado finito.
16. **A lista do cap. 17** — declaradamente incompleta e pessoal.
17. **Cobertura** — no estudo de caso, ele aceita cair para **84.9%** porque "as linhas que não são cobertas são tão triviais que não vale a pena testá-las". O livro não prega 100%.
18. **Padrão duplo em testes** — ineficiência é aceitável em teste; falta de clareza nunca.

---

## 13. Críticas conhecidas da comunidade

Registradas honestamente — o livro é influente **e** contestado:

1. **Funções minúsculas demais.** "2 a 4 linhas" produz explosão de métodos privados de uma linha, forçando o leitor a saltar entre 15 funções para reconstruir um fluxo linear. A *localidade de raciocínio* piora mesmo com a legibilidade local melhorando. Muitos defendem hoje: pequeno o suficiente para caber na cabeça, não o menor possível.
2. **"Comentários são sempre fracassos" levado ao extremo.** Gera bases de código sem nenhum registro de **por quê** — o único tipo de informação que nome de função não carrega. Perde-se contexto de decisão, workaround, trade-off, referência externa.
3. **Exemplos Java-2008 datados.** Notação húngara, EJB2, checked exceptions, JavaBeans — muito do capítulo 2 e 11 endereça problemas que linguagens modernas resolveram. Nada disso se traduz direto para Go, Rust, TypeScript ou funcional.
4. **O código do próprio livro é criticado.** Análises do `SetupTeardownIncluder` (cap. 3) e do `PrimeGenerator` (cap. 15) apontam estado mutável em campos de instância criado só para permitir funções sem parâmetros — a regra "poucos parâmetros" empurrando complexidade para estado compartilhado. É a crítica mais séria e mais específica ao livro.
5. **DRY absolutizado.** "A duplicação pode ser a raiz de todo o mal" ignora o custo do **acoplamento** criado por abstrações prematuras. O contraponto moderno de Sandi Metz: *"duplication is far cheaper than the wrong abstraction"*. O livro só admite duplicação implicitamente (via regra 4 do design simples); não a trata como escolha legítima. **Duplicação aceitável**: quando dois trechos são coincidentemente iguais mas mudam por razões diferentes (violaria SRP unificá-los); em testes, onde explicitação > reuso.
6. **Métricas subjetivas.** "25 palavras sem 'e'", "uma coisa só", "um nível de abstração" — não são verificáveis nem automatizáveis, e viram munição para bikeshedding em code review.
7. **Cap. 13 (Concorrência) e o TDD dogmático** envelheceram mal; as três leis do TDD como *lei* são hoje minoria mesmo entre praticantes de TDD.

**Leitura recomendada**: trate o livro como um **catálogo de heurísticas com boa taxa de acerto**, não como norma. As partes mais duráveis: nomes (cap. 2), tratamento de erro (cap. 7), objetos vs. estruturas de dados (cap. 6), F.I.R.S.T. (cap. 9), e as 4 regras do Design Simples (cap. 12) — **especialmente a 4ª**.
