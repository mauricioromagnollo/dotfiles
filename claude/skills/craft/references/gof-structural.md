# Padrões Estruturais (GoF)

Tratam de como classes e objetos se compõem em estruturas maiores. Quatro deles — Adapter, Decorator, Proxy e Facade — têm estrutura quase idêntica (todos envolvem um objeto e delegam). O que os distingue é **intenção**, e é isso que você comunica ao escolher o nome.

Índice: [Adapter](#adapter) · [Bridge](#bridge) · [Composite](#composite) · [Decorator](#decorator) · [Facade](#facade) · [Flyweight](#flyweight) · [Proxy](#proxy) · [Distinguindo os wrappers](#distinguindo-os-wrappers)

---

## Adapter

**Intenção (GoF).** Converter a interface de uma classe em outra interface que os clientes esperam. Adapter permite que classes trabalhem juntas quando não poderiam por interfaces incompatíveis.

**Use quando** você quer usar uma classe existente cuja interface não bate com a que precisa — tipicamente na fronteira com biblioteca de terceiro ou código legado.

```ts
// o que o domínio precisa
interface PaymentGateway {
  charge(cents: number, token: string): Promise<Receipt>;
}

// o que a lib oferece
class StripeSdk {
  createCharge(params: { amount: number; currency: string; source: string }) { /*...*/ }
}

class StripeAdapter implements PaymentGateway {
  constructor(private sdk: StripeSdk) {}
  async charge(cents: number, token: string): Promise<Receipt> {
    const res = await this.sdk.createCharge({ amount: cents, currency: 'brl', source: token });
    return { id: res.id, paidAt: new Date(res.created * 1000) };
  }
}
```

**Trade-offs.** Uma camada de tradução a manter. Adapters vazam quando a interface alvo não cobre um recurso do adaptado, e a tentação é adicionar um método "escape hatch" que reintroduz o acoplamento inteiro.

**Valor real.** O adapter é a costura de teste: o domínio depende de `PaymentGateway`, então o teste passa um fake sem rede.

---

## Bridge

**Intenção (GoF).** Desacoplar uma abstração de sua implementação, de modo que as duas possam variar independentemente.

**Use quando** há **dois eixos de variação** e a herança te obrigaria a criar N×M subclasses (`PdfCircle`, `SvgCircle`, `PdfSquare`, `SvgSquare`…).

```ts
interface Renderer { drawCircle(x: number, y: number, r: number): void; } // implementação

abstract class Shape {                                                    // abstração
  constructor(protected renderer: Renderer) {}
  abstract draw(): void;
}

class Circle extends Shape {
  constructor(renderer: Renderer, private r: number) { super(renderer); }
  draw() { this.renderer.drawCircle(0, 0, this.r); }
}
// N formas + M renderers = N+M classes, não N×M
```

**Trade-offs.** Uma indireção em toda chamada e um nível a mais de conceito. Só vale com os dois eixos realmente vivos — com um eixo só, é Strategy com nome pomposo.

**Como reconhecer.** Se os nomes das suas classes são concatenações de dois adjetivos, você quer Bridge.

---

## Composite

**Intenção (GoF).** Compor objetos em estruturas de árvore para representar hierarquias parte-todo. Composite permite que clientes tratem objetos individuais e composições uniformemente.

**Use quando** o cliente não deve se importar se está lidando com uma folha ou um nó.

```ts
interface Node { size(): number; }

class FileNode implements Node {
  constructor(private bytes: number) {}
  size() { return this.bytes; }
}

class DirNode implements Node {
  constructor(private children: Node[]) {}
  size() { return this.children.reduce((t, c) => t + c.size(), 0); } // mesma chamada
}
```

**Trade-offs.** A interface uniforme força decidir onde ficam `add`/`remove`: na interface comum (folhas ganham métodos sem sentido, erro só em runtime) ou só no composite (o cliente perde a uniformidade que motivou o pattern). O GoF reconhece que não há saída limpa — escolha conscientemente.

Vale entender essa tensão pelo que ela é: o Composite **troca deliberadamente a Responsabilidade Única por transparência**. Colocar operações de gerência de filhos na interface comum viola o princípio, e é exatamente isso que permite ao cliente tratar folha e nó igualmente. É o melhor exemplo de que princípios são guias, não leis — às vezes você viola um de propósito, sabendo o que compra (ver `design-principles.md`; o SRP em profundidade, com suas críticas, está em `solid.md`).

Em TS, uma união discriminada resolve com checagem estática e sem a violação.

---

## Decorator

**Intenção (GoF).** Anexar responsabilidades adicionais a um objeto dinamicamente. Decorators provêm uma alternativa flexível a subclasses para estender funcionalidade.

**Use quando** você quer somar comportamentos **por instância e em runtime**, em combinações que a herança não cobre.

```ts
interface Handler { handle(req: Request): Promise<Response>; }

class LoggingHandler implements Handler {
  constructor(private inner: Handler) {}
  async handle(req: Request) {
    console.time(req.url);
    try { return await this.inner.handle(req); } finally { console.timeEnd(req.url); }
  }
}

const app = new LoggingHandler(new RetryHandler(new CoreHandler()));
```

**Trade-offs.** Muitos objetos pequenos e stacks de erro profundas. Identidade quebra: o decorado não é `instanceof` o decorador, e `===` falha. A ordem importa e não é óbvia (retry dentro ou fora do log muda o que você mede).

**Nota.** Isto **não** é o decorator `@` do TypeScript, que é outra coisa (metaprogramação de anotação). Streams do Node são Decorator de verdade. Middleware é Decorator em forma funcional.

---

## Facade

**Intenção (GoF).** Prover uma interface unificada para um conjunto de interfaces em um subsistema. Facade define uma interface de nível mais alto que torna o subsistema mais fácil de usar.

**Use quando** o caso comum exige orquestrar muitas peças, mas você não quer proibir o acesso direto às peças para os casos raros.

```ts
class CheckoutFacade {
  constructor(private cart: Cart, private tax: TaxService, private pay: PaymentGateway) {}
  async submit(userId: string, token: string): Promise<Order> {
    const items = await this.cart.items(userId);
    const total = await this.tax.applyTo(items);
    const receipt = await this.pay.charge(total.cents, token);
    return Order.from(items, receipt);
  }
}
```

**Trade-offs.** Facade tende a virar God object: cada caso novo adiciona um método, e em um ano ela é o sistema. Mantenha-a fina — ela orquestra, não decide regra de negócio. Quando ela engorda, o smell é Large Class e o tratamento está em `refactoring-smells.md`.

**Distinção.** Facade simplifica **muitos** objetos; Adapter converte **um**.

---

## Flyweight

**Intenção (GoF).** Usar compartilhamento para suportar grandes quantidades de objetos de granularidade fina eficientemente.

**Use quando** você tem *muitos* objetos e a maior parte do estado deles é repetida. Separe **estado intrínseco** (compartilhável, imutável) de **extrínseco** (passado pelo cliente).

```ts
class Glyph {                       // intrínseco: compartilhado
  constructor(readonly char: string, readonly font: Font) {}
  draw(x: number, y: number) {}     // extrínseco: vem do chamador
}

const pool = new Map<string, Glyph>();
const glyphFor = (char: string, font: Font) => {
  const key = `${char}:${font.id}`;
  return pool.get(key) ?? pool.set(key, new Glyph(char, font)).get(key)!;
};
```

**Trade-offs.** Este é o único pattern estrutural cuja justificativa é puramente **medida** — só aplique com um profile na mão mostrando o consumo. O custo é código bem mais difícil de ler e um pool que, se não tiver política de despejo, vira leak.

---

## Proxy

**Intenção (GoF).** Prover um substituto ou placeholder para outro objeto para controlar o acesso a ele.

**Variedades:** virtual (instancia caro sob demanda), remoto (representa objeto em outro processo), de proteção (checa permissão), de cache, de log.

```ts
class LazyImage implements Image {
  private real?: RealImage;
  constructor(private path: string) {}
  render() { (this.real ??= new RealImage(this.path)).render(); } // carrega no 1º uso
}
```

**Trade-offs.** Indireção invisível: o cliente acha que fala com o objeto real. Um proxy que faz I/O onde o cliente esperava chamada local produz latência surpreendente — o clássico problema dos proxies remotos.

**Nota TS.** `new Proxy()` nativo cobre interceptação genérica sem escrever a classe.

---

## Distinguindo os wrappers

Estrutura idêntica, intenções diferentes. Errar o nome desinforma o leitor mais do que não nomear:

| Pattern | Interface do wrapper | Por que existe |
|---|---|---|
| **Adapter** | **Diferente** da do envolvido | Compatibilizar contratos |
| **Decorator** | **Igual** à do envolvido | Somar comportamento |
| **Proxy** | **Igual** à do envolvido | Controlar acesso |
| **Facade** | **Nova**, mais simples | Esconder um subsistema inteiro |

Regra prática: mesma interface + soma comportamento = Decorator; mesma interface + controla acesso = Proxy; interface diferente = Adapter; muitos objetos atrás = Facade.
