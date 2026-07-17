# SOLID — definições originais, sinais, custos e críticas

Fontes primárias (Uncle Bob, Meyer, Liskov) + as críticas (North, Copeland) + as contra-críticas. Os dois lados, porque a decisão de **não** aplicar precisa de argumento tanto quanto a de aplicar.

> ⚠️ **Ressalva de procedência:** o PDF original do DIP (*C++ Report*, 1996) não foi acessível na extração. A definição das duas partes vem de fontes secundárias convergentes — o texto está correto, mas não foi verificado contra o original.

Ver também: `modeling-uml.md` (o mesmo conteúdo em vocabulário de 2001) · `tradeoffs.md` (YAGNI, o custo de toda abstração).

---

**Origem:** compilados por Robert C. Martin desde ~1995 (`comp.object`), consolidados em *Design Principles and Design Patterns* (2000) e *Agile Software Development* (2002). O acrônimo é de **Michael Feathers**, não de Martin. LSP é o único que **não é dele** (Barbara Liskov, keynote 1987; formalizado com Jeannette Wing, 1994). OCP é de **Meyer** (1988).

## B.1 SRP — Single Responsibility Principle

**Definição atual ([cleancoder, 2014](https://blog.cleancoder.com/uncle-bob/2014/05/08/SingleReponsibilityPrinciple.html)):** *"Each software module should have one and only one reason to change."* → canônica: **"A module should be responsible to one, and only one, actor."**

O ponto que "faz uma coisa só" destrói — **SRP é sobre pessoas**:
> *"When you write a software module, you want to make sure that when changes are requested, those changes can only originate from a single person, or rather, a **single tightly coupled group of people representing a single narrowly defined business function**."*

**Exemplo canônico** — `Employee`: `calculatePay()` → CFO; `reportHours()` → COO; `save()` → CTO. A classe faz "uma coisa" (é um empregado!) e **viola SRP mesmo assim** — responde a **três atores**. O medo concreto: *"Nothing terrifies our customers and managers more than discovering a program malfunctioned in a way that was, from their point of view, **completely unrelated to the changes they requested**."* Formulação alternativa: **"Gather together the things that change for the same reasons. Separate those things that change for different reasons."**

**Sinal de violação:**
- Um arquivo aparece em PRs de **times/domínios diferentes** por motivos não relacionados. *(O sinal mais forte é git log, não leitura de código.)*
- Merge conflicts recorrentes entre pessoas em features não relacionadas.
- Regra de negócio + formatação/persistência mudando na mesma classe por stakeholders diferentes.
- Você não descreve a classe sem "e": *"faz X **e** Y"*. Teste precisa mockar camadas distintas.

**Custo cedo demais:**
- **Fragmentação especulativa**: adivinhou os atores errado → dividiu na fronteira errada, agora calcificada em arquivos. Pior que não dividir.
- Explosão de `XService`/`XManager`/`XHelper` anêmicos; a lógica some entre indireções.
- Uncle Bob **admite**: separar é bom mas *"often not feasible"* — e sugere Facade pra reagrupar.
- **North**: separar conteúdo de formato *"creates artificial seams"* — mudam **juntos** (adicionar campo mexe nos dois) e vira *"an administrative chore of chaining identical fields together"*.
- **Sem atores identificáveis, SRP não tem input — é indefinido**, não "faça uma coisa só".

## B.2 OCP — Open/Closed Principle

**Original (Meyer, 1988):** *"Software entities (classes, modules, functions) should be **open for extension, but closed for modification**."* Meyer resolvia via **herança**; Martin reformulou via **abstração/polimorfismo**: cliente depende de abstração estável, comportamento novo entra como nova implementação.

**Reformulação do próprio Martin ([Solid Relevance, 2020](https://blog.cleancoder.com/uncle-bob/2020/10/18/Solid-Relevance.html)):** OCP = *"isolating business rules from implementation details (GUI, databases, protocols)"*. Ele mesmo moveu OCP de "não edite classes" para **"regra de negócio não muda porque o banco mudou"**.

**Sinal de violação:** `switch`/`if-else` sobre **tipo/enum** que cresce a cada feature e **se repete em vários lugares** (shotgun surgery); adicionar um caso exige editar N arquivos testados; regra de negócio importando driver de banco/SDK HTTP.

**Custo cedo demais — a crítica mais forte das cinco.** [David Copeland](https://naildrivin5.com/blog/2019/11/14/open-closed-principle-is-confusing-and-well-wrong.html):
- *"Code that is more flexible is more difficult to build, test, and maintain."* Flexibilidade pra caso hipotético = desperdício + fardo.
- **Perda de rastreabilidade**: `Client` → `AbstractServer` obriga a caçar implementações pra entender o que roda. **Com uma única implementação, a abstração só confunde.**
- **O paradoxo**: "proibido modificar o fonte" torna correção de bug impossível; exigir camada abstrata cria indireção desnecessária.
- Veredito: *"Ignore the Open/Close Principle entirely. Write code to solve the problems you have."*

Objeções em **linguagens modernas**:
- **Git + testes mudaram a economia.** OCP nasceu quando recompilar/redistribuir binário era caro e não havia rede de segurança. Hoje **modificar é barato e seguro** — a premissa de custo evaporou.
- **Union types + pattern matching exaustivo** (TS discriminated unions, Rust enums, Scala sealed traits) **invertem a recomendação**: o compilador aponta todos os lugares a atualizar. É o *expression problem* — OCP otimiza pra "adicionar tipos"; unions pra "adicionar operações". Aqui o `switch` é **superior** ao polimorfismo.
- **HOFs/funções de primeira classe** dão extensão sem hierarquia. **Extension methods/traits** (C#, Kotlin, Rust) estendem *sem modificar e sem herdar* — a dicotomia nem se aplica.
- Regra prática: **Rule of Three > OCP.** Abstraia na 3ª variação, quando o eixo é *observado*, não *adivinhado*.

## B.3 LSP — Liskov Substitution Principle

**Original (Liskov 1987; Liskov & Wing 1994):** *"If q(x) is a property provable about objects x of type T, then q(y) should be provable for objects y of type S where S is a subtype of T."* **Martin:** *"Subtypes must be substitutable for their base types."*

O subtipo deve respeitar o **contrato**: pré-condições não podem ser **fortalecidas**; pós-condições não podem ser **enfraquecidas**; invariantes preservados; *history rule* (não introduza mutabilidade onde a base prometia imutabilidade); sem exceções novas.

**Square/Rectangle**: `Square extends Rectangle` compila e "é-um" em português, mas quebra `r.setWidth(5); r.setHeight(4); assert(r.area()==20)`. **"is-a" do português ≠ "is-a" do sistema de tipos** — o contrato é definido pelos *clientes*, não pela taxonomia do mundo real.

**Sinal de violação:**
- **`if (x instanceof Subtipo)`** no cliente — o mais claro. Cliente precisa saber o tipo concreto → substituição falhou.
- Override com `throw NotSupportedException` (ex. `ReadOnlyList extends List` com `add()` que explode), ou corpo vazio pra "desativar".
- Subclasse exige setup extra (pré-condição fortalecida). Doc do tipo "exceto quando for X".
- **Teste operacional: rode a suíte da base contra cada subtipo.** Não passa → violou.

**Custo cedo demais:** o **menor dos cinco** — LSP não manda *criar* nada; é restrição sobre hierarquias que você já decidiu ter (custo ≈ 0 sem herança). O custo real é **rigor performático**: perseguir substituibilidade perfeita gera hierarquias contorcidas (`Shape` imutável + `resize()` retornando nova instância) quando o problema real era **não usar herança ali**. Contratos formais em código que ninguém vai estender = burocracia. **Crítica de fundo**: quase toda violação de LSP se resolve **removendo a herança**, não consertando o subtipo — o que o valida como *detector* e o enfraquece como *guia de design*.

## B.4 ISP — Interface Segregation Principle

**Original (Martin, ~1996):** *"Clients should not be forced to depend upon interfaces that they do not use."*

**Origem real**: consultoria na **Xerox** (impressoras). God class `Job` da qual todo cliente dependia → qualquer mudança forçava recompilar/redeployar tudo. Solução: **camada de interfaces** (`StapleJob`, `PrintJob`), cada cliente vendo só o que usa. Martin também usa o exemplo do **ATM**.

**Reformulação em Solid Relevance (2020):** ISP = *"managing **compile-time dependencies** in statically-typed systems"*.

> ⚠️ **A concessão mais importante do próprio Uncle Bob**: ISP é sobre **dependência de tempo de compilação**. Em linguagens dinâmicas sem etapa de compilação/link, **o motivo original do ISP desaparece**.

**Sinal de violação:** métodos vazios / `NotImplemented` **só pra satisfazer a interface** (mesmo sinal do LSP — não é coincidência: fat interface e quebra de contrato são a mesma doença); você importa um tipo enorme e usa 2 de 30 métodos; mudar um método que você não usa te força a recompilar/atualizar mocks; **setup de teste desproporcional** (mockar 15 métodos pra exercitar 1); `Repository<T>` com 20 métodos onde cada consumidor usa 3.

**Custo cedo demais:**
- **Explosão de interfaces de um método** — cada uma com nome, arquivo, import. Navegar vira caça ao tesouro.
- Interfaces com **um único implementador** ("header file syndrome"): custo puro, zero benefício. `IUserService` com só `UserService` é ruído.
- Em **TypeScript, structural typing já resolve**: o parâmetro declara a forma que precisa (`function f(x: { id: string })`); nenhuma interface nomeada precisa existir *a priori*. Aplicar ISP como "crie interfaces pequenas" antes de ter clientes distintos é cargo-culting de Java.

## B.5 DIP — Dependency Inversion Principle

**Original (Martin, *C++ Report*, 1996)** — duas partes:
> **(a)** *"High-level modules should not depend on low-level modules. **Both should depend on abstractions**."*
> **(b)** *"Abstractions should not depend on details. **Details should depend on abstractions**."*

**(b) é a que mais se perde**: não basta ter interface — a **interface não pode vazar o detalhe**. `interface UserRepo { findByPostgresCursor(c: PgCursor) }` tem interface e viola DIP.

"Inversão" de quê: no design em camadas ingênuo `Policy → Mechanism → Utility`, o alto nível **depende** do baixo. DIP inverte a **direção da dependência de código** em relação à **direção do fluxo de controle**. O ponto de ownership: **a interface pertence ao cliente (alto nível), não ao implementador** — por isso `UserRepository` mora no domínio e `PostgresUserRepository` no infra. É o que torna Clean/Hexagonal possível; **DIP é o único dos 5 que é arquitetural**. Exemplo canônico: `Copy()` (teclado→impressora) depende de `Reader`/`Writer` abstratos. (DIP e OCP são quase o mesmo princípio de ângulos diferentes — Martin admite.) Em 2020: *"keeping high-level business logic separate from low-level technical details"*.

**Sinal de violação:** regra de negócio faz `import { PrismaClient }` / `import axios` / `new Date()` / `process.env`; não dá pra testar a lógica sem subir banco/rede; interface com nomes vazados (`saveToS3()`, `executeQuery()`); a abstração mora no pacote da implementação (`infra/IUserRepo`) em vez do pacote do consumidor; trocar provider exige mexer no domínio.

**Custo cedo demais:**
- **Indireção sem benefício**: interface + DI container + factory pra uma implementação que nunca muda. `Ctrl+click` leva à interface, não ao código.
- **Abstração prematura vaza mesmo assim**: abstraiu `Database` cedo com uma implementação → a interface fica moldada nesse banco; quando o segundo chega, não serve. **Não dá pra abstrair bem com um exemplo só.**
- DI frameworks: erros em runtime em vez de compile time, stack traces ilegíveis, startup lento.
- **Honestidade**: pra código in-process que nunca troca de implementação (a maioria), DIP é custo puro. Se paga onde há **fronteira real**: I/O, rede, tempo, aleatoriedade, terceiro, ou fronteira de time.

---

## B.6 As críticas — e quando SOLID NÃO se aplica

### Dan North: *"Why Every Element of SOLID is Wrong"* → CUPID

[North](https://dannorth.net/blog/cupid-for-joyful-coding/) ataca a **estrutura**, não caso-a-caso:
> **"Principles are like rules: you are either compliant or you are not."**

Isso cria **bounded sets** (dentro/fora, seguidores de regra) em vez de **centered sets** (pessoas se movendo na direção de valores compartilhados). Proposta: **propriedades** — *"qualities or characteristics of code rather than rules to follow"*. Propriedade define **direção de melhoria**, não compliance binária: você não "cumpre" composability, você é *mais ou menos* composable.

Sobre **SRP**: *"pointlessly vague principle"*. Separar conteúdo de formato *"creates artificial seams"*; separar render de lógica **impede que a separação natural emerja organicamente** conforme o código cresce. É **premature optimization**. Sua resposta: *"Write Simple Code"*.

**CUPID:** **C**omposable (*"plays well with others"*) · **U**nix philosophy (*"does one thing well"* — single **purpose**, não single *responsibility*) · **P**redictable (*"does what you expect"* — determinístico, observável) · **I**diomatic (*"feels natural"*) · **D**omain-based (*"the solution domain models the problem domain in language and structure"*).

Note: **Unix philosophy ≈ SRP** e **Domain-based ≈ DDD**. CUPID não é o oposto de SOLID — é um reframe com ênfase diferente. North insiste: *"everything is a trade-off so you should always consider your context."*

### A resposta do Uncle Bob: [*Solid Relevance* (2020)](https://blog.cleancoder.com/uncle-bob/2020/10/18/Solid-Relevance.html)
- Software *"hasn't changed all that much"* desde 1945: continua *"if statements, while loops, and assignment statements"* → os princípios **transcendem paradigma**, não são OO-only.
- Ele **redefine os cinco em termos não-OO** (ver acima) — a melhor defesa e a maior concessão ao mesmo tempo: se OCP é "isole regra de detalhe" e DIP é "separe alto de baixo nível", os princípios são **quase a mesma coisa dita 5 vezes**.
- Concede que *"write simple code"* é bom conselho, mas: **"simplicity requires disciplines guided by principles."** Descartar SOLID lhe dá *"dread for the future of our industry"*.

### A contra-crítica a North: [Jeroen De Dauw](https://www.entropywins.wtf/blog/2017/02/17/why-every-single-argument-of-dan-north-is-wrong/)
- North ataca **straw men**: pega a versão mais literal/ingênua (SRP = "faz uma coisa", OCP = "nunca edite arquivo") e refuta essa.
- As alternativas propostas (*"write simple code"*) são **não-contraditórias** com SOLID e vagas demais pra serem acionáveis — "simples" não é operacionalizável; "um ator" é.
- Ponto justo dos dois lados: **SOLID mal ensinado** (o que North ataca) é nocivo; **SOLID bem entendido** (atores, contratos, fronteiras) sobrevive.

### Onde SOLID NÃO se aplica

**Código funcional:** SRP → funções puras já têm "uma razão pra mudar"; sem estado mutável compartilhado, a força motriz enfraquece. OCP → HOFs e composição resolvem; e **pattern matching exaustivo em ADTs é deliberadamente "fechado"** — isso é *feature* (compilador garante totalidade). LSP → sem subtipos nominais; type classes têm **leis** (functor/monad) que são análogo *mais rigoroso*, mas é teoria de categorias, não LSP. ISP → sem interfaces nominais e sem compile-time linking, o problema da Xerox não existe. DIP → *inversão* vira **parametrização**: passar a função como argumento, Reader monad, effect systems — o objetivo (isolar efeitos) sobrevive, a *mecânica* (interfaces + DI container) não. **Veredito: os objetivos são universais; as prescrições de SOLID são artefatos de OO estático dos anos 90.**

**Componentes React:** componente **já é** função pura props→UI; a unidade de reuso é **composição**, não hierarquia (não há herança em React; a doc recomenda composição há uma década).
- **OCP**: `children`, render props, custom hooks já dão extensão sem modificação — **de graça, sem abstract class**. `<AbstractButton>` é anti-idiomático.
- **SRP**: vale no espírito, mas "um componente = uma coisa" leva a **prop drilling** e à fragmentação que North descreve. **Colocation** (JSX + estilo + lógica juntos) é uma **rejeição deliberada** da separação por camada técnica em favor de separação por **feature** — e a experiência mostra que estava certa.
- **LSP/ISP**: quase sem tração — sem subtipos, e `Props` já é a interface, do consumidor por construção.
- **DIP**: sobrevive parcialmente — Context/providers pra injetar cliente de API/tema é DIP de verdade e vale.
- Debate real: [hooks *violam* SOLID](https://medium.com/codex/can-we-all-just-admit-react-hooks-were-a-bad-idea-c48120c5188d) porque dependem do consumidor ser function component e não podem ser trocados em runtime. Resposta do ecossistema: **e daí** — a ergonomia venceu.

**Scripts / glue / one-offs:** SOLID otimiza pra **mudança ao longo do tempo por múltiplas pessoas**. Script de migração, build, notebook, cron de 40 linhas **não têm esse eixo**: todo custo é pago à vista, todo benefício é futuro e não vai chegar. **SOLID é dívida de flexibilidade paga adiantado** — se o código não vai ser lido de novo, não pague.

**Não-OO** (SQL, config, IaC, shell, CSS): SRP e DIP têm análogos vagos (coesão, indireção); OCP/LSP/ISP não têm referente.

---

## B.7 Síntese

| Princípio | Custo de aplicar cedo | Onde realmente se paga |
|---|---|---|
| **SRP** | Alto — fragmentação especulativa em fronteiras adivinhadas | Quando você **identifica atores reais**. Sem atores, é indefinido |
| **OCP** | **O mais alto** — abstração especulativa, perda de rastreabilidade | Eixo de variação **observado** (3ª variação), ou fronteira regra ↔ detalhe |
| **LSP** | ~Zero — é restrição, não prescrição | Onde houver herança. Bom **detector**: violou → provavelmente remova a herança |
| **ISP** | Médio — explosão de interfaces; ~nulo em dyn/structural typing | Compile-time deps em linguagem estática; fronteira entre times/pacotes publicados |
| **DIP** | Médio-alto — indireção, DI container, abstração vazada | Fronteiras reais: I/O, rede, tempo, terceiros. Único **arquitetural** dos cinco |

**Os dois lados concordam em:** (1) o **objetivo** (isolar mudança, contratos honestos, fronteiras claras) não está em disputa — só a **mecânica** e o **timing**; (2) SOLID **preventivo** é dano, SOLID como **diagnóstico de dor já sentida** é útil; (3) a versão popular ("SRP = faz uma coisa", "OCP = nunca edite arquivo") é indefensável — e é a que 90% aprendeu: é o que North ataca e o que Martin diz que não é; (4) ergonomia importa — "responsável perante um ator" é acionável, "faz uma coisa" não.

**Operacional:** trate SOLID como **vocabulário de code review**, não checklist de design. *"Isso responde a dois atores"* e *"isso força o cliente a conhecer o subtipo"* aceleram uma conversa. *"Isso viola SRP"* não.

**Ponte com `modeling-uml.md`:** o livro de 2001 já dizia tudo, em outra linguagem. *"Classe bem estruturada agrega um conjunto restrito e bem definido de responsabilidades"* (SRP, p.166). *"Interfaces capturam semelhanças sem forçar relações artificiais"* (ISP/LSP, p.179). *"Componente evolui transparentemente se suportar as interfaces anteriores"* (OCP, p.182). *"Não modelar o que não é necessário modelar"* (p.357) = a crítica de North, 20 anos antes. **A disciplina é velha; o que muda é o custo de cada mecânica em cada linguagem e época.**

---

## Referências

[Uncle Bob — SRP (2014)](https://blog.cleancoder.com/uncle-bob/2014/05/08/SingleReponsibilityPrinciple.html) · [Solid Relevance (2020)](https://blog.cleancoder.com/uncle-bob/2020/10/18/Solid-Relevance.html) · Martin, *Design Principles and Design Patterns* (2000), *The Dependency Inversion Principle* (C++ Report, 1996), *The Interface Segregation Principle* (~1996) · Liskov & Wing, *A Behavioral Notion of Subtyping* (TOPLAS, 1994) · Meyer, *Object-Oriented Software Construction* (1988) · [Dan North — CUPID](https://dannorth.net/blog/cupid-for-joyful-coding/) · [slides: Why Every Element of SOLID is Wrong](https://speakerdeck.com/tastapod/why-every-element-of-solid-is-wrong) · [Copeland — The Open/Close Principle is Confusing and, well, Wrong](https://naildrivin5.com/blog/2019/11/14/open-closed-principle-is-confusing-and-well-wrong.html) · [De Dauw — Why Every Single Argument of Dan North is Wrong](https://www.entropywins.wtf/blog/2017/02/17/why-every-single-argument-of-dan-north-is-wrong/) · [Lebedev — SOLID in React](https://konstantinlebedev.com/solid-in-react/)
