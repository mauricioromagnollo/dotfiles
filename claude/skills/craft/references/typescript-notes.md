# Patterns em TypeScript — o que a linguagem já resolve

Leia antes de implementar qualquer pattern do catálogo. O GoF documenta formas pensadas para C++ e Smalltalk de 1994, linguagens sem funções de primeira classe, módulos, generics estruturais ou uniões discriminadas. TypeScript tem tudo isso, e várias formas canônicas encolhem para quase nada.

Isso **não** invalida os patterns: a intenção e os trade-offs continuam valendo, e são eles que você comunica ao nomear. O que muda é a quantidade de código.

---

## Funções de primeira classe substituem várias hierarquias

```ts
// Strategy
type Discount = (o: Order) => Cents;

// Command sem undo
type Action = () => void;

// Template Method
const importFile = (b: Buffer, hooks: { parse(b: Buffer): Row[]; persist(r: Row[]): void }) =>
  hooks.persist(hooks.parse(b));

// Factory Method para um produto
const createExporter = (k: Kind): Exporter => (k === 'pdf' ? new PdfExporter() : new CsvExporter());
```

Use classe quando houver **estado por instância**, **várias operações no mesmo contrato**, ou **dependências para injetar**. Nos outros casos, a função é o pattern. A hierarquia montada antes de existir a segunda implementação é o caso clássico de YAGNI e de abstração prematura — ver `tradeoffs.md`.

## Módulos substituem Singleton

```ts
// db.ts
export const db = createPool({ max: 10 });
```

O cache de módulos do ES garante uma avaliação por processo. `getInstance()` com campo estático reimplementa isso à mão. Atenção: em serverless, "por processo" é por instância de função — não conte com unicidade global.

## Uniões discriminadas substituem Visitor (e às vezes State e Composite)

```ts
type Node =
  | { kind: 'num'; v: number }
  | { kind: 'add'; l: Node; r: Node };

const evaluate = (n: Node): number => {
  switch (n.kind) {
    case 'num': return n.v;
    case 'add': return evaluate(n.l) + evaluate(n.r);
    default: return assertNever(n);   // erro de compilação ao adicionar um tipo
  }
};

const assertNever = (x: never): never => { throw new Error(`caso não tratado: ${JSON.stringify(x)}`); };
```

`assertNever` te dá o benefício central do Visitor — o compilador aponta cada lugar a atualizar — sem `accept`/double dispatch. Prefira a união quando os tipos são dados; prefira Visitor quando os elementos têm comportamento próprio e vêm de uma lib que você não controla.

## Generators substituem Iterator

```ts
class Paginated<T> {
  async *[Symbol.asyncIterator]() {
    let cursor: string | undefined;
    do {
      const page = await fetchPage(cursor);
      yield* page.items;
      cursor = page.next;
    } while (cursor);
  }
}
for await (const item of paginated) {}   // paginação invisível ao consumidor
```

## `Proxy` nativo substitui Proxy escrito à mão

```ts
const logged = new Proxy(service, {
  get: (t, p, r) => (typeof t[p] === 'function' ? (...a) => (console.log(p), t[p](...a)) : Reflect.get(t, p, r)),
});
```

Bom para interceptação genérica (log, mock). Ruim quando o cliente precisa entender o que acontece — mágica invisível custa depuração.

## Composição de funções substitui Decorator/Chain para pipelines

```ts
type Middleware = (req: Request, next: () => Promise<Response>) => Promise<Response>;
const compose = (mws: Middleware[]) =>
  mws.reduceRight<(r: Request) => Promise<Response>>(
    (next, mw) => req => mw(req, () => next(req)),
    async () => new Response(null, { status: 404 }),   // terminal explícito
  );
```

---

## Armadilhas específicas de TS/JS

**`interface` vs `type`.** Para contratos de pattern, ambos servem. `interface` faz declaration merging (útil para extensão por terceiros, perigoso por acidente); `type` compõe melhor com uniões. Seja consistente com o resto do repositório.

**Tipagem estrutural.** TypeScript não exige `implements` — qualquer objeto com a forma certa serve. Isso torna Adapter e fakes de teste triviais, e torna `implements` uma checagem opcional (útil, mas não o que define compatibilidade).

**`this` perdido.** Passar um método como callback (`emitter.on('x', obj.handle)`) perde o `this`. Use arrow function ou `bind` — é o bug número um ao implementar Observer com classes.

**Decorators `@` não são o Decorator do GoF.** São metaprogramação por anotação (NestJS, TypeORM). Não confunda ao explicar.

**`readonly` é só compile-time.** Para imutabilidade real em Value Objects, use `Object.freeze` ou não exponha a referência interna:

```ts
get lines(): readonly OrderItem[] { return Object.freeze([...this.items]); }
```

**Classes cruzam mal a fronteira de serialização.** Um objeto vindo de `JSON.parse`, de um Server Component ou do `localStorage` não é instância da sua classe — métodos somem, `instanceof` falha. Em Next.js, dados que atravessam a fronteira server→client precisam ser serializáveis: mantenha o domínio com classes no servidor e passe DTOs planos para o cliente.

**Igualdade de Value Object.** `===` compara referência. VOs precisam de um `equals()` explícito — não existe sobrecarga de operador em JS.
