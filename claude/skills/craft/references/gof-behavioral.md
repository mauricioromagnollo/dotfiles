# Padrões Comportamentais (GoF)

Tratam de algoritmos e da atribuição de responsabilidades entre objetos. São os mais usados no dia a dia — e os que mais frequentemente já existem prontos na linguagem ou no framework.

Índice: [Strategy](#strategy) · [Observer](#observer) · [Command](#command) · [State](#state) · [Template Method](#template-method) · [Chain of Responsibility](#chain-of-responsibility) · [Iterator](#iterator) · [Mediator](#mediator) · [Memento](#memento) · [Visitor](#visitor) · [Interpreter](#interpreter) · [Strategy vs. State vs. Command](#strategy-vs-state-vs-command)

---

## Strategy

**Intenção (GoF).** Definir uma família de algoritmos, encapsular cada um, e torná-los intercambiáveis. Strategy permite que o algoritmo varie independentemente dos clientes que o usam.

**Use quando** o mesmo trabalho tem variantes e **o cliente escolhe** qual usar.

```ts
type ShippingPolicy = (order: Order) => Cents;

const freeOverThreshold: ShippingPolicy = o => (o.total > 20000 ? 0 : 1500);
const flatRate: ShippingPolicy = () => 1500;

class Checkout {
  constructor(private shipping: ShippingPolicy) {}       // injetada
  total(o: Order) { return o.total + this.shipping(o); }
}
```

Em TypeScript a forma idiomática é uma **função**, não uma hierarquia — é literalmente o exemplo que o refactoring.guru dá ao discutir a crítica de que patterns compensam ausências da linguagem. Use classes quando a strategy tem estado próprio, dependências para injetar, ou várias operações relacionadas.

**Trade-offs.** O cliente precisa conhecer as opções para escolher. Um `Record<Kind, ShippingPolicy>` centraliza isso sem `switch` espalhado. O smell que motiva a troca (e as duas exceções em que o `switch` fica) está em `refactoring-smells.md`.

---

## Observer

**Intenção (GoF).** Definir uma dependência um-para-muitos entre objetos, de modo que quando um objeto muda de estado, todos os seus dependentes são notificados e atualizados automaticamente.

**Use quando** uma mudança precisa alcançar um número aberto de interessados, sem que a origem os conheça.

```ts
class Emitter<T> {
  private subs = new Set<(v: T) => void>();
  subscribe(fn: (v: T) => void): () => void {
    this.subs.add(fn);
    return () => this.subs.delete(fn);   // devolver o unsubscribe evita leaks
  }
  emit(v: T) { for (const fn of this.subs) fn(v); }
}
```

**Trade-offs.** Os mais sérios do catálogo: fluxo de controle vira invisível (não dá para "seguir a chamada"); ordem de notificação é indefinida; observers que não desinscrevem vazam memória; cascatas de update podem reentrar e produzir loop. Depurar sistema orientado a evento custa caro — reserve para onde o desacoplamento vale isso.

**Já existe pronto.** `EventTarget`, `EventEmitter` do Node, signals, `addEventListener` do DOM, RxJS. Escrever o seu raramente se justifica.

---

## Command

**Intenção (GoF).** Encapsular uma requisição como um objeto, permitindo parametrizar clientes com diferentes requisições, enfileirar ou logar requisições, e suportar operações que podem ser desfeitas.

**Use quando** a ação precisa ser **tratada como dado**: fila, log, retry, undo, transação, replay. Sem nenhuma dessas necessidades, Command é uma função com passos extras.

```ts
interface Command { execute(): void; undo(): void; }

class RenameCommand implements Command {
  private previous?: string;
  constructor(private doc: Doc, private next: string) {}
  execute() { this.previous = this.doc.title; this.doc.title = this.next; }
  undo() { if (this.previous !== undefined) this.doc.title = this.previous; }
}

class History {
  private stack: Command[] = [];
  run(c: Command) { c.execute(); this.stack.push(c); }
  undo() { this.stack.pop()?.undo(); }
}
```

**Trade-offs.** Uma classe por ação. O undo obriga a guardar estado anterior — se o estado é grande, combine com **Memento**.

**Reconhecendo.** `useReducer`/Redux são Command: a action é o comando reificado, e é por isso que time-travel debugging é possível ali.

---

## State

**Intenção (GoF).** Permitir que um objeto altere seu comportamento quando seu estado interno muda. O objeto parecerá ter mudado de classe.

**Use quando** o comportamento depende do estado e as transições são regra de negócio.

```ts
interface OrderState {
  pay(o: Order): OrderState;
  cancel(o: Order): OrderState;
}

const Pending: OrderState = {
  pay: o => { o.chargeCard(); return Paid; },
  cancel: () => Cancelled,
};
const Paid: OrderState = {
  pay: () => { throw new Error('já pago'); },
  cancel: o => { o.refund(); return Refunded; },   // transição carrega efeito
};
```

**Trade-offs.** Espalha a máquina de estados por vários objetos — ver o diagrama inteiro exige ler todos. Uma tabela de transições explícita às vezes comunica melhor. Ganha do `switch` quando cada estado tem várias operações e as transições têm efeito colateral.

---

## Template Method

**Intenção (GoF).** Definir o esqueleto de um algoritmo em uma operação, adiando alguns passos para subclasses. Template Method permite que subclasses redefinam certos passos sem mudar a estrutura do algoritmo.

```ts
abstract class Importer {
  import(file: Buffer) {          // o esqueleto é fixo
    const rows = this.parse(file);
    const valid = rows.filter(r => this.validate(r));
    this.persist(valid);
  }
  protected abstract parse(file: Buffer): Row[];
  protected validate(_: Row) { return true; }   // hook opcional
  protected abstract persist(rows: Row[]): void;
}
```

**Trade-offs.** É "inversão de controle" via herança: a subclasse não escolhe quando roda. Frágil quando a superclasse muda o esqueleto, e o acoplamento pai-filho é o mais forte que existe em OO.

**Alternativa em TS.** Uma função de alta ordem recebendo os hooks dá o mesmo resultado sem herança:

```ts
const importFile = (file: Buffer, hooks: { parse: (b: Buffer) => Row[]; persist: (r: Row[]) => void }) => {};
```

Prefira Strategy (composição) a Template Method (herança) quando os dois servem.

---

## Chain of Responsibility

**Intenção (GoF).** Evitar acoplar o remetente de uma requisição ao seu receptor dando a mais de um objeto a chance de tratar a requisição. Encadear os objetos receptores e passar a requisição pela cadeia até que um a trate.

```ts
type Middleware = (req: Request, next: () => Response) => Response;

const auth: Middleware = (req, next) => (req.token ? next() : new Response(null, { status: 401 }));
const chain = (mws: Middleware[], final: () => Response) =>
  mws.reduceRight((next, mw) => () => mw(req, next), final);
```

**Trade-offs.** **Nada garante que alguém trate** — a requisição pode cair pelo fim da cadeia em silêncio, e este é o bug clássico do pattern. Sempre defina o terminal. Depurar exige percorrer a cadeia.

**Reconhecendo.** Middleware de Express/Koa, event bubbling do DOM, handlers de log.

---

## Iterator

**Intenção (GoF).** Prover uma maneira de acessar sequencialmente os elementos de um objeto agregado sem expor sua representação subjacente.

**Em TypeScript, o pattern é um recurso da linguagem** — implemente o protocolo, não uma classe `Iterator`:

```ts
class Tree<T> {
  constructor(private value: T, private children: Tree<T>[] = []) {}
  *[Symbol.iterator](): Generator<T> {
    yield this.value;
    for (const c of this.children) yield* c;   // percurso encapsulado
  }
}
for (const v of tree) console.log(v);
```

**Valor.** Esconder a estrutura (árvore, paginação de API, cursor de banco) atrás de `for...of`. Generators tornam lazy loading trivial.

---

## Mediator

**Intenção (GoF).** Definir um objeto que encapsula como um conjunto de objetos interage. Mediator promove acoplamento fraco ao evitar que os objetos se refiram uns aos outros explicitamente.

**Use quando** N objetos se conhecem em malha e a comunicação (não o comportamento deles) é que ficou complexa.

**Trade-offs.** Troca malha por hub: o mediator concentra a complexidade e tende a virar God object. Vale quando o *protocolo* entre os componentes é a coisa complicada, e ter esse protocolo em um lugar só é melhor que espalhá-lo.

**Mediator vs. Observer.** Observer distribui notificação sem coordenação; Mediator coordena ativamente quem faz o quê. Um mediator pode usar Observer para se comunicar.

---

## Memento

**Intenção (GoF).** Sem violar o encapsulamento, capturar e externalizar o estado interno de um objeto para que ele possa ser restaurado a esse estado depois.

```ts
class Editor {
  private text = '';
  save(): Snapshot { return Object.freeze({ text: this.text }); }  // opaco pro caller
  restore(s: Snapshot) { this.text = s.text; }
}
```

**O ponto todo é o encapsulamento**: o caretaker guarda o memento mas não pode inspecioná-lo — só o originador entende seu conteúdo. Sem isso, é serialização comum.

**Trade-offs.** Custo de memória proporcional a snapshots × tamanho do estado. Para estado grande, considere snapshots incrementais ou diffs (ou Command com undo).

---

## Visitor

**Intenção (GoF).** Representar uma operação a ser executada sobre os elementos de uma estrutura de objetos. Visitor permite definir uma nova operação sem mudar as classes dos elementos sobre os quais opera.

**Use quando** a hierarquia de tipos é **estável** e as **operações crescem** — AST, compiladores, análise de documento.

```ts
interface Visitor<R> { num(n: NumNode): R; add(n: AddNode): R; }

class NumNode { constructor(readonly v: number) {} accept<R>(vi: Visitor<R>) { return vi.num(this); } }
class AddNode { constructor(readonly l: Node, readonly r: Node) {} accept<R>(vi: Visitor<R>) { return vi.add(this); } }

const evaluate: Visitor<number> = {
  num: n => n.v,
  add: n => n.l.accept(evaluate) + n.r.accept(evaluate),
};
```

**Trade-offs.** O eixo é rígido: operação nova é barata, **tipo novo é caro** (quebra todos os visitors). Se seus tipos crescem mais que suas operações, Visitor é exatamente a escolha errada — use polimorfismo comum.

**Nota TS.** Uma união discriminada + `switch` com checagem de exaustividade dá o mesmo benefício com muito menos cerimônia, e o compilador aponta todo lugar a corrigir ao adicionar um tipo:

```ts
type Node = { kind: 'num'; v: number } | { kind: 'add'; l: Node; r: Node };
const evaluate = (n: Node): number =>
  n.kind === 'num' ? n.v : evaluate(n.l) + evaluate(n.r);
```

---

## Interpreter

**Intenção (GoF).** Dada uma linguagem, definir uma representação para sua gramática junto com um interpretador que usa a representação para interpretar sentenças na linguagem.

**Use quando** há uma gramática **simples e estável** que se repete: filtros de busca, regras de permissão, feature flags, validação declarativa.

**Trade-offs.** Uma classe por regra de gramática — inviável para gramáticas grandes (use um parser generator). É o pattern menos usado do catálogo, e o refactoring.guru sequer o cataloga. Antes de escrever uma linguagem, confirme que uma função de configuração não resolve.

---

## Strategy vs. State vs. Command

Estruturas parecidas, intenções distintas:

| | Quem decide | O que representa | Sinal |
|---|---|---|---|
| **Strategy** | O cliente, na injeção | Um algoritmo intercambiável | As variantes não se conhecem |
| **State** | O próprio objeto, transicionando | Uma situação do ciclo de vida | Os estados retornam o próximo estado |
| **Command** | Quem enfileira/executa depois | Uma requisição reificada | Existe `undo`, fila ou log |

Se as variantes não sabem umas das outras, é Strategy. Se elas decidem quem vem depois, é State. Se você guarda a ação para executar/desfazer mais tarde, é Command.
