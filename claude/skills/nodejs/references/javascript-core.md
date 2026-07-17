# JavaScript Core: a semântica por baixo do TypeScript

O que o TypeScript **não** protege: coerção em runtime, identidade de objetos, ordem de execução assíncrona, ponto flutuante, data e mutação. Abra quando um bug não fizer sentido pelo tipo declarado — o tipo é apagado na compilação e o que sobra é isto aqui. Contexto: Node 24, TS strict, backend financeiro.

---

## 1. Tipos e coerção

Sete primitivos; o resto é objeto. Primitivos são **imutáveis, comparados por valor**; objetos são **mutáveis, comparados por referência** — `{a:1} === {a:1}` é sempre `false`.

| | `==` | `===` | `Object.is` | SameValueZero |
|---|---|---|---|---|
| `NaN, NaN` | false | false | **true** | **true** |
| `+0, -0` | true | true | **false** | true |
| `null, undefined` | **true** | false | false | false |
| `"0", 0` | **true** | false | false | false |

`===` por padrão. A única exceção legítima de `==` é `x == null`, que captura `null` e `undefined` de uma vez (o TS entende como narrowing). `Object.is` só para meta-programação com `-0`. **SameValueZero** — algoritmo de `includes`, `Map` e `Set` — explica por que `[NaN].indexOf(NaN)` é `-1` mas `[NaN].includes(NaN)` é `true`.

### Falsy

Exatamente seis: `undefined`, `null`, `0`/`-0`, `NaN`, `""`, `false`. Todo o resto é truthy — inclusive `[]`, `{}`, `"0"`, `"false"`. O bug clássico numa API financeira:

```ts
const amount = input.amount || 100;  // ❌ amount === 0 cai no default
const amount = input.amount ?? 100;  // ✅ só null/undefined caem
```

Idem `if (!count)` quando `0` é válido. `??` não pode ser misturado com `&&`/`||` sem parênteses — SyntaxError deliberado contra precedência ambígua.

### `null` vs `undefined`

`undefined` = ausência de nível de sistema (não inicializado, propriedade inexistente, parâmetro omitido); `null` = ausência deliberada. JSON não tem `undefined`: `JSON.stringify({a: undefined})` dá `{}` — o campo some do response. Se o cliente precisa distinguir "não enviado" de "limpar o campo", `null` explícito é obrigatório.

### Ponto flutuante e dinheiro

IEEE-754 binário representa `1/2` e `1/8` exatamente, mas **não** `0.1` nem `1/100`:

```ts
0.3 - 0.2 === 0.1;  // false
0.1 + 0.2;          // 0.30000000000000004
```

O problema é binário, não JavaScript — mas numa API financeira é fatal: centavos em `float` divergem do extrato. **Nunca represente dinheiro como `number` decimal.** Use **inteiro em centavos** (a recomendação clássica, Flanagan §3.1.4; seguro até `Number.MAX_SAFE_INTEGER` = 2^53−1, ~90 trilhões de reais) ou **`BigInt`** para precisão arbitrária e colunas `BIGINT`/`NUMERIC` — lembrando que `BigInt` **não serializa em JSON** (`JSON.stringify(1n)` lança) e não mistura com `number` (`1n + 1` lança).

```ts
type Cents = number & { readonly __brand: 'Cents' };
const toCents = (brl: string): Cents => Math.round(parseFloat(brl) * 100) as Cents;
```

`Math.round` na conversão, nunca acumular float; `toFixed` arredonda para exibição e não corrige acúmulo. `NaN` é o único valor diferente de si mesmo — detecte com `Number.isNaN`, nunca com o global `isNaN`, que coage (`isNaN("abc") === true`).

---

## 2. Escopo, TDZ e closures

`let`/`const`/`class` são block-scoped e vivem em **TDZ** do início do bloco até a declaração — acesso antes lança `ReferenceError`, não `undefined`. Sintoma: `Cannot access 'x' before initialization` quase sempre é **dependência circular entre módulos ESM**, não erro de escopo local.

**Closure** = função + referência viva ao ambiente léxico; com `let`, cada iteração do loop tem seu próprio binding, e `for (let i…) fns.push(() => i)` produz `[0,1,2]`. **Custo de memória**: a closure retém o *ambiente inteiro*, não só a variável usada — um handler que captura um escopo contendo um `Buffer` de 50 MB impede a coleta do buffer enquanto existir, e cache global de closures é a causa favorita de vazamento. Métodos no construtor alocam uma função por instância; métodos de `class` vão para o prototype.

---

## 3. `this`, protótipos e `class`

`this` é **dinâmico**: definido por *como* a função é chamada. Arrow functions não têm `this` próprio — capturam lexicamente.

```ts
class Service {
  handle = () => {};   // campo: this sempre correto, uma função por instância
  handle2() {}         // método: this depende da chamada, fica no prototype
}
const { handle2 } = new Service();
handle2(); // TypeError: this is undefined (classes são strict mode)
```

Passar `obj.method` como callback perde o `this` — use arrow field, `.bind` ou `() => obj.method()`. `class` é açúcar sobre a cadeia de protótipos.

**Não confunda**: `prototype` é propriedade de funções; `[[Prototype]]` é o link interno de qualquer objeto. `Object.setPrototypeOf` em objeto já criado desotimiza o engine — nunca em hot path.

Campos `#` são **hard private**: invisíveis a `Object.keys`, `JSON.stringify`, spread e Proxy — diferente de `private` do TS, que é só compile-time (`obj['x']` funciona em runtime). `#field in obj` serve como brand check.

**Composição > herança.** Encapsulamento e polimorfismo *separam* código; herança *amarra* — para herdar você precisa saber mais sobre a classe do que para usá-la (Eloquent JS, cap. 6).

---

## 4. Objetos

**Property descriptors** (`value`, `writable`, `enumerable`, `configurable`): literais criam tudo `true`; `Object.defineProperty` cria tudo `false` por padrão — daí propriedades que "somem" de `Object.keys`/`JSON.stringify`.

**`Object.freeze` é raso**: `Object.freeze({ db: { host: 'x' } })` deixa `cfg.db.host = 'y'` passar; só `cfg.db = {}` lança (em strict mode — todo ESM e toda `class`).

**Spread vs `Object.assign`**: ambos rasos e copiam próprias e enumeráveis, mas spread *define* propriedades novas enquanto `Object.assign` **invoca setters** do alvo. Nenhum copia getters — são avaliados e viram valores estáticos.

**Ordem das chaves** (importa para hash de payload, idempotency key, snapshot): chaves inteiro-like vêm **primeiro, em ordem numérica**; depois strings por inserção; depois symbols. `{100:'a', 2:'b', foo:'c'}` → `['2','100','foo']`.

**Cópia profunda**: `structuredClone` (Node 17+) lida com ciclos, `Map`, `Set`, `Date`, `RegExp`; **não** lida com funções, symbols nem protótipos de classe (volta objeto simples) — lança `DataCloneError`. `JSON.parse(JSON.stringify(x))` perde `undefined`, transforma `Date` em string e lança com `BigInt` e com ciclos. **Igualdade estrutural não existe em JS**: não há operador, e `JSON.stringify(a) === JSON.stringify(b)` depende da ordem das chaves.

---

## 5. Async a fundo

### Event loop e microtasks

Thread único. Promises resolvem via **microtask queue**, drenada inteira após o código síncrono e **antes** de qualquer timer — `setTimeout(f, 0)` + `Promise.resolve().then(g)` + `console.log(s)` imprime `s → g → f`. Mesmo já resolvida, a promise agenda o handler; nunca executa síncrono. Bloqueio síncrono impede timers e I/O de rodar. Callbacks rodam com a **stack vazia**, por isso `try/catch` síncrono não pega erro de callback assíncrono — o throw derruba o processo.

### Combinators — escolha pela semântica de falha

| | Resolve quando | Rejeita quando | Vazio |
|---|---|---|---|
| `all` | todas cumprem | **a primeira** rejeitar (fail-fast) | `[]` |
| `allSettled` | todas assentam | **nunca** | `[]` |
| `race` | a primeira a assentar | se essa rejeitar | **nunca assenta** |
| `any` | a primeira a cumprir | **todas** rejeitarem → `AggregateError` | `AggregateError` |

`all` para **transação lógica** — mas ele **não cancela** as demais: elas continuam e, se rejeitarem depois, viram unhandled rejection. `allSettled` para **trabalho independente** com relatório completo (importar N transações), erro em `results[i].reason`. `any` para **fallback entre réplicas**; `race` para **timeout**.

**Sequencial vs paralelo**: `await` em sequência soma latências e só se justifica quando B depende de A; para independentes, `Promise.all([getUser(id), getTransactions(id)])` custa a maior, não a soma. `for (const x of xs) await f(x)` é sequencial — às vezes é o que você quer (rate limit, ordem, backpressure), mas explicite a intenção.

### Erros engolidos

`await` ausente é a falha mais cara: a função retorna antes do trabalho terminar e o erro vira unhandled rejection — que no Node 15+ **derruba o processo**. Ative `no-floating-promises` no ESLint.

```ts
saveAudit(event);                          // ❌ derruba o processo
void saveAudit(event).catch(logger.error); // ✅ fire-and-forget explícito
```

**A armadilha do gap** (Eloquent JS, cap. 11): entre o início do statement e o fim do `await`, outro código roda. Mutar binding externo dentro de `map(async …)` é bug — cada `+=` lê o valor de *antes* do await:

```ts
let list = '';
await Promise.all(names.map(async n => { list += await fetch(n); })); // ❌ só o último
const lines = await Promise.all(names.map(async n => `${n}: ${await fetch(n)}`)); // ✅
```

Computar valores novos é sempre menos sujeito a erro do que mutar existentes.

---

## 6. Iterators, generators e async iteration

**Iterator**: `next()` → `{value, done}`. **Iterable**: `[Symbol.iterator]()` devolve um iterator. `for...of`, spread, destructuring e `Array.from` consomem iteráveis — polimorfismo estrutural puro. Generators (`function*`) escrevem iterators sem estado manual; `yield*` delega; cada um só itera uma vez.

Async iterators (`[Symbol.asyncIterator]`, `for await...of`) são a base de **streams** — a forma correta de processar arquivos e cursores grandes sem carregar tudo na memória, com backpressure natural: `for await (const row of db.queryStream(sql)) await process(row)`. É sequencial por construção; para concorrência limitada, agrupe em lotes com `Promise.all`.

---

## 7. `Map`/`Set`/`WeakMap` vs objeto literal

**Objeto literal / `Record`**: shape fixo e conhecido, serializa em JSON. **`Map`**: chaves dinâmicas ou não-string, muitas inserções/remoções, precisa de `.size`. **`Set`**: unicidade e pertinência. **`WeakMap`/`WeakSet`**: metadados atrelados a objetos sem impedir GC.

Objeto literal como mapa é perigoso: herda de `Object.prototype`, então `"toString" in ages` é `true` sem ninguém ter inserido — use `Object.create(null)` ou, melhor, `Map`. `Map` compara chaves com SameValueZero, mas objetos **por referência**: `map.set({id:1}, x); map.get({id:1})` → `undefined`. `WeakMap` é a escolha certa para cache por request/conexão: some quando a chave é coletada, enquanto `Map` global indexado por objeto vaza.

---

## 8. Date, timezone e `Intl`

`Date` é um wrapper de um inteiro: ms desde o epoch UTC. Todo o resto é interpretação.

- **Meses são zero-based**, dias não: `new Date(2012, 0, 1)` é 1º de janeiro.
- **Componentes usam timezone local**; `Date.UTC(...)` usa UTC. O mesmo instante lido com `getDate()` em GMT+1 e GMT−1 dá **dias diferentes** — a data de nascimento vira o dia anterior. Se o valor é uma *data civil* (vencimento, competência), não use `Date`: guarde `"2026-03-15"`.
- **`===` entre `Date`s compara referência**, sempre `false`; mas `<`, `>`, `<=` funcionam (coagem para número) — inconsistência que passa em review. Compare com `.getTime()`.
- **Parsing não-ISO é implementation-dependent**; só `new Date("2012-01-01T00:00:00Z")` é confiável. **Overflow rola silencioso**: `new Date(2012, 12, 32)` vira fevereiro de 2013. `Invalid Date` tem `getTime()` `NaN`, que se propaga — valide com `Number.isNaN(d.getTime())`.

Regra: **armazene e transporte instantes em UTC**; converta na borda com `Intl.DateTimeFormat` e `timeZone` **explícito** — o default é o do processo, UTC no container e outro na máquina do dev. Calendário: lib ou `Temporal`. Exiba com `Intl.NumberFormat` + `style: 'currency'`.

---

## 9. Armadilhas com sintoma

| Armadilha | Sintoma em produção |
|---|---|
| `\|\|` como default com `0`/`""` válidos | valor zerado vira default silenciosamente |
| promise sem `await` | processo morre com unhandled rejection sem stack útil |
| mutar binding em `map(async …)` | resultado só do último a responder |
| closure retendo escopo grande em cache global | RSS cresce sem parar; snapshot aponta `Closure` |
| `Object.freeze` raso + strict | `TypeError: Cannot assign to read only property` |
| float para dinheiro | centavos divergindo no fechamento |
| `Date` com componentes locais | data off-by-one entre dev e container UTC |
| `d1 === d2` para datas | sempre falso; regra de negócio nunca dispara |
| método desacoplado do objeto | `Cannot read properties of undefined` |
| chaves numéricas em objeto | ordem numérica, não de inserção; hash instável |
| bloqueio síncrono no event loop | p99 explode, health check falha, CPU baixa |
| dependência circular ESM | `ReferenceError: Cannot access 'X' before initialization` |

**Fontes**: MDN (Equality comparisons, Closures, Prototype chain, Promise, Iterators, class, Operators) · *Eloquent JavaScript*, caps. 6 e 11 · Flanagan 6ed, cap. 3 (só fundamentos que não mudaram) · *Notes for Professionals*, caps. 8–10, 13.
