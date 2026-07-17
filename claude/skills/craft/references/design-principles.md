# Design Principles (Head First Design Patterns)

Os patterns são consequência, não ponto de partida. Cada um do catálogo GoF é a aplicação de um ou mais destes princípios a um problema recorrente — e é por isso que quem entende os princípios consegue avaliar um pattern que nunca viu, adaptá-lo, ou decidir que uma solução mais simples serve.

A regra de uso, que o próprio livro coloca no capítulo final: **comece pelos princípios e escreva o código mais simples que resolve o problema; introduza o pattern quando a necessidade emergir**. Um princípio violado é evidência de problema real; um pattern ausente não é.

Índice: [Os nove princípios](#os-nove-princípios) · [1 Encapsular o que varia](#1-encapsule-o-que-varia) · [2 Programar para interface](#2-programe-para-uma-interface-não-para-uma-implementação) · [3 Composição sobre herança](#3-favoreça-composição-sobre-herança) · [4 Acoplamento fraco](#4-busque-acoplamento-fraco-entre-objetos-que-interagem) · [5 Open-Closed](#5-open-closed-aberto-para-extensão-fechado-para-modificação) · [6 Inversão de dependência](#6-dependa-de-abstrações-não-de-classes-concretas) · [7 Menor conhecimento](#7-princípio-do-menor-conhecimento-fale-só-com-seus-amigos-imediatos) · [8 Hollywood](#8-princípio-de-hollywood-não-nos-ligue-nós-ligamos-para-você) · [9 Responsabilidade única](#9-uma-classe-deve-ter-apenas-um-motivo-para-mudar) · [Diagnóstico](#diagnóstico-do-princípio-violado-ao-pattern)

---

## Os nove princípios

| # | Princípio | Patterns que o encarnam |
|---|---|---|
| 1 | Identifique o que varia e separe do que permanece igual | Strategy, State, Abstract Factory, Bridge |
| 2 | Programe para uma interface, não para uma implementação | quase todos |
| 3 | Favoreça composição sobre herança | Strategy, Decorator, Bridge, State |
| 4 | Busque acoplamento fraco entre objetos que interagem | Observer, Mediator |
| 5 | Classes abertas para extensão, fechadas para modificação | Decorator, Strategy, Observer |
| 6 | Dependa de abstrações, não de classes concretas | Factory Method, Abstract Factory, DI |
| 7 | Menor conhecimento: fale só com seus amigos imediatos | Facade, Mediator |
| 8 | Hollywood: não nos ligue, nós ligamos para você | Template Method, Observer, Factory Method |
| 9 | Uma classe deve ter apenas um motivo para mudar | Iterator, Command, Single Responsibility |

Os princípios 5, 6 e 9 são, respectivamente, o OCP, o DIP e o SRP do SOLID. Para as definições originais, as críticas (Dan North e o CUPID) e os contextos em que SOLID **não** se aplica, ver `solid.md`.

---

## 1. Encapsule o que varia

> *Identify the aspects of your application that vary and separate them from what stays the same.*

O princípio fundador — os outros oito são refinamentos dele. Se algo muda a cada requisito novo, esse algo é um comportamento que precisa sair do meio do que é estável.

```ts
// varia: como calcular o frete. Estável: que todo pedido tem frete.
type ShippingPolicy = (o: Order) => Cents;

class Checkout {
  constructor(private shipping: ShippingPolicy) {}
  total(o: Order) { return o.total + this.shipping(o); }
}
```

**Como aplicar:** peça ao usuário o histórico. O que mudou nos últimos três meses? O que o time já sabe que vai mudar? Esses são os eixos que merecem encapsulamento. O resto é especulação, e encapsular especulação é como o over-engineering começa (é o YAGNI e seus quatro custos — ver `tradeoffs.md`).

## 2. Programe para uma interface, não para uma implementação

> *Program to an interface, not an implementation.*

"Interface" aqui significa **supertipo**, não a palavra-chave `interface`. O ponto é que a variável declarada com o tipo geral permite trocar o concreto sem tocar no chamador.

```ts
const store: BlobStore = new S3Store();   // não: const store: S3Store = ...
```

**Nota TS:** a tipagem é estrutural — qualquer objeto com a forma certa satisfaz o supertipo, sem `implements`. Isso torna o princípio mais barato de seguir aqui do que em Java, e torna fakes de teste triviais.

## 3. Favoreça composição sobre herança

> *Favor composition over inheritance.*

Herança fixa o comportamento em tempo de compilação e acopla o filho a toda mudança do pai (o acoplamento mais forte que existe em OO). Composição permite trocar em runtime e testar as partes isoladamente.

O sintoma que o livro usa: a explosão de subclasses. Se `Duck` precisa de `FlyingQuackingDuck`, `NonFlyingQuackingDuck`, `FlyingMuteDuck`… os comportamentos deveriam ser objetos compostos, não posições numa hierarquia.

**"Favoreça" não é "nunca herde".** Herança serve quando há um IS-A verdadeiro e estável, e a subclasse não precisa negar nada do pai. Se você se pega sobrescrevendo um método para lançar `UnsupportedOperation`, o IS-A era mentira.

## 4. Busque acoplamento fraco entre objetos que interagem

> *Strive for loosely coupled designs between objects that interact.*

Objetos fracamente acoplados interagem sabendo muito pouco um do outro. No Observer, o subject sabe apenas que os observers implementam uma interface — pode adicionar, remover e trocar observers em runtime sem que subject e observers se conheçam.

**O custo, que o livro discute pouco:** desacoplar torna o fluxo invisível. Um sistema totalmente orientado a evento é difícil de depurar porque não existe "seguir a chamada". Desacople onde a mudança é real, não por princípio.

## 5. Open-Closed: aberto para extensão, fechado para modificação

> *Classes should be open for extension, but closed for modification.*

O objetivo é adicionar comportamento sem editar código testado. Decorator é o exemplo canônico: um condimento novo é uma classe nova, e `Beverage` não muda.

**Onde isso engana:** aplicar Open-Closed em tudo produz abstração em todo lugar e código difícil de ler. O livro é explícito de que o princípio é caro e deve ser focado nas áreas **com maior probabilidade de mudar**. Você não descobre quais são adivinhando — descobre pelo histórico do repositório. Uma interface com uma única implementação criada "por via das dúvidas" é o caso de YAGNI que `tradeoffs.md` detalha.

## 6. Dependa de abstrações, não de classes concretas

> *Depend upon abstractions. Do not depend upon concrete classes.*

O Dependency Inversion Principle. Parece igual ao princípio 2, mas é mais forte: ele diz que **os módulos de alto nível também** não devem depender de baixo nível — os dois dependem da abstração. A "inversão" é que a interface é definida pelo consumidor de alto nível, e o detalhe de infraestrutura a implementa.

```ts
// o domínio define a porta e a possui; o Postgres se adapta a ela
interface OrderRepository { save(o: Order): Promise<void>; }
```

É a base de Ports & Adapters e do Repository do DDD (ver `beyond-gof.md` e `ddd.md`). Também é a razão de existir do Factory: sem factory, todo `new Concrete()` é uma dependência concreta.

## 7. Princípio do Menor Conhecimento: fale só com seus amigos imediatos

> *Principle of Least Knowledge — talk only to your immediate friends.*

Também chamado Lei de Deméter. De qualquer método de um objeto, invoque apenas métodos de:

- **o próprio objeto**;
- **objetos passados como parâmetro** do método;
- **objetos que o método cria** ou instancia;
- **componentes do objeto** (o que está em campo de instância — relação HAS-A).

Ou seja: **não chame métodos em objetos devolvidos por outras chamadas.**

```ts
// viola: acopla a Station, Thermometer e ao fato de que Station tem um Thermometer
station.getThermometer().getTemperature();

// segue: peça à Station que faça o pedido por você
station.getTemperature();
```

**Custo declarado:** métodos de repasse ("wrapper") a mais, e alguma indireção. O ganho é que a mudança para de cascatear.

## 8. Princípio de Hollywood: não nos ligue, nós ligamos para você

> *Don't call us, we'll call you.*

Componentes de baixo nível se plugam no sistema, mas **quem decide quando chamá-los é o alto nível**. É a definição de inversão de controle e o que separa framework de biblioteca.

Template Method é o caso puro: a subclasse fornece os passos, mas nunca escolhe a ordem — o esqueleto na superclasse chama os hooks. Observer é a versão desacoplada: o observer não fica perguntando ("não ligue"), ele é notificado.

Isso explica por que "não fique fazendo polling" e "não chame o pai a partir do filho" são a mesma regra em roupas diferentes.

## 9. Uma classe deve ter apenas um motivo para mudar

> *A class should have only one reason to change.*

Coesão. Cada responsabilidade extra é uma probabilidade extra de a classe mudar — e cada mudança é uma chance de quebrar as outras responsabilidades.

Iterator existe por causa disso: gerenciar a coleção e iterar sobre ela são dois motivos para mudar, então a iteração sai para outro objeto.

**O trade-off explícito:** o livro admite que o Composite **troca deliberadamente a Responsabilidade Única por transparência** — colocar `add`/`remove` na interface comum viola o princípio, mas permite ao cliente tratar folha e nó igualmente. É o exemplo mais útil do livro: princípios são guias, e às vezes você viola um de propósito, sabendo o que está comprando.

---

## Diagnóstico: do princípio violado ao pattern

Use ao revisar código. O princípio violado é a evidência; o pattern é o remédio *candidato*, não a conclusão.

| Sintoma | Princípio violado | Candidatos |
|---|---|---|
| `switch`/`if` sobre tipo repetido em vários lugares | 1 (encapsular o que varia) | Strategy, State |
| Tipo concreto no meio da regra de negócio | 2, 6 | DI, Factory, porta |
| Subclasses em combinação N×M | 3 (composição) | Bridge, Strategy |
| Subclasse sobrescreve método para lançar "não suportado" | 3 (IS-A falso) | Composição |
| Editar classe testada a cada feature nova | 5 (open-closed) | Decorator, Strategy |
| Domínio importa driver de banco / SDK | 6 (inversão) | Repository, Adapter, Hexagonal |
| Encadeamento `a.getB().getC().do()` | 7 (menor conhecimento) | Facade, método de repasse |
| Componente fica em polling perguntando "mudou?" | 8 (Hollywood) | Observer |
| Classe que muda por três motivos diferentes | 9 (responsabilidade única) | Extrair colaborador |

---

## As três mentalidades

O livro descreve a maturidade com patterns em três estágios, e a distinção é útil para calibrar uma recomendação:

- **Iniciante** — usa patterns em todo lugar; acha que mais patterns significa design melhor.
- **Intermediário** — vê onde patterns cabem e onde não, mas ainda força pattern canônico em situação que pede adaptação.
- **Zen** — pensa em termos de princípios e trade-offs, procura a solução mais simples, e aplica o pattern quando a necessidade surge naturalmente — sabendo que provavelmente precisará adaptá-lo.

Recomende como a mente Zen: princípios primeiro, solução simples, pattern quando a necessidade emergir, adaptação assumida.

## Anti-pattern

O complemento do pattern: **uma solução que parece boa e se revela ruim quando aplicada**. Um anti-pattern bem documentado diz três coisas, e vale seguir essa estrutura ao alertar o usuário sobre um caminho ruim:

1. **Por que a solução é atraente** — ninguém escolhe algo ruim de propósito; se você não explica a sedução, o alerta não convence.
2. **Por que ela é ruim no longo prazo** — o efeito concreto lá na frente.
3. **Qual pattern ou princípio oferece a boa solução** no lugar.

Exemplos frequentes: Singleton como estado global (`gof-creational.md`), Anemic Domain Model (`ddd.md`), Service Locator (`beyond-gof.md`), Golden Hammer — o "se você só tem um martelo, tudo parece prego" que o refactoring.guru cita ao criticar o uso injustificado de patterns.
