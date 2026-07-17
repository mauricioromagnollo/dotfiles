# Padrões Criacionais (GoF)

Abstraem o processo de instanciação. Ficam relevantes quando o sistema deve depender de *como* objetos são criados o mínimo possível — tipicamente porque o tipo concreto varia, ou porque a montagem é complexa o bastante para merecer nome próprio.

Índice: [Factory Method](#factory-method) · [Abstract Factory](#abstract-factory) · [Builder](#builder) · [Prototype](#prototype) · [Singleton](#singleton)

---

## Factory Method

**Intenção (GoF).** Definir uma interface para criar um objeto, mas deixar as subclasses decidirem qual classe instanciar. Factory Method permite adiar a instanciação para subclasses.

**Use quando** uma classe não pode antecipar a classe dos objetos que deve criar, ou quer que suas subclasses especifiquem os objetos que cria.

```ts
abstract class ReportPage {
  protected abstract createExporter(): Exporter; // factory method

  render(data: Row[]): Buffer {
    return this.createExporter().export(data); // não sabe qual Exporter
  }
}

class InvoicePage extends ReportPage {
  protected createExporter(): Exporter {
    return new PdfExporter();
  }
}
```

**Trade-offs.** Cria uma hierarquia paralela de criadores só para variar o produto. Cada produto novo pode custar uma subclasse nova.

**Quando não usar.** Se há um único produto, ou se a escolha é um `switch` simples sobre um enum, uma função basta:

```ts
const createExporter = (kind: ExportKind): Exporter =>
  kind === 'pdf' ? new PdfExporter() : new CsvExporter();
```

Isso ainda é uma factory. A subclasse só se paga quando o criador já tem outra razão para existir como hierarquia.

---

## Abstract Factory

**Intenção (GoF).** Prover uma interface para criar famílias de objetos relacionados ou dependentes sem especificar suas classes concretas.

**Use quando** o sistema deve ser configurado com uma entre várias famílias de produtos, e produtos de famílias diferentes **não podem se misturar**. Essa restrição de coerência é o que distingue Abstract Factory de várias factories soltas — sem ela, você não precisa deste pattern.

```ts
interface StorageFactory {
  createBlobStore(): BlobStore;
  createQueue(): Queue;
}

class AwsFactory implements StorageFactory {
  createBlobStore() { return new S3Store(); }
  createQueue() { return new SqsQueue(); }
}

class VercelFactory implements StorageFactory {
  createBlobStore() { return new VercelBlobStore(); }
  createQueue() { return new VercelQueue(); }
}
// impossível combinar S3Store com VercelQueue por acidente
```

**Trade-offs.** Adicionar um **produto** novo à família muda a interface e todas as factories. Adicionar uma **família** nova é barato. Se seus produtos mudam mais que suas famílias, o pattern está no eixo errado.

---

## Builder

**Intenção (GoF).** Separar a construção de um objeto complexo de sua representação, de modo que o mesmo processo de construção possa criar representações diferentes.

**Use quando** a construção tem passos com ordem/validação, ou quando o mesmo processo produz representações distintas.

```ts
class QueryBuilder {
  private wheres: string[] = [];
  private limitValue?: number;

  where(clause: string): this { this.wheres.push(clause); return this; }
  limit(n: number): this { this.limitValue = n; return this; }

  build(): string {
    const where = this.wheres.length ? ` WHERE ${this.wheres.join(' AND ')}` : '';
    return `SELECT * FROM orders${where}${this.limitValue ? ` LIMIT ${this.limitValue}` : ''}`;
  }
}
```

**Trade-offs.** O objeto fica inválido entre `new` e `build()`. Um builder mal feito permite `build()` em estado incompleto — o tipo não protege.

**Quando não usar.** Para "muitos parâmetros opcionais", um objeto de options resolve com menos código e melhor checagem estática (é o "objeto de argumento" que `clean-code.md` recomenda ao tratar de listas longas de parâmetros):

```ts
function createServer(opts: { port: number; host?: string; tls?: TlsConfig }) {}
```

Builder ganha quando há **ordem**, **acúmulo** ou **múltiplas representações do mesmo processo**. Não ganha por chaining ser bonito.

---

## Prototype

**Intenção (GoF).** Especificar os tipos de objetos a criar usando uma instância protótipo, e criar novos objetos copiando esse protótipo.

**Use quando** instanciar do zero é caro, ou quando as variações de objeto são melhor descritas como "igual àquele, mas com X diferente" — editores gráficos, seeds de teste, configuração em camadas.

```ts
class ChartConfig {
  constructor(readonly theme: Theme, readonly axes: Axis[]) {}
  clone(overrides: Partial<ChartConfig> = {}): ChartConfig {
    return new ChartConfig(overrides.theme ?? this.theme, overrides.axes ?? [...this.axes]);
  }
}
```

**Trade-offs.** Cópia profunda vs. rasa é a armadilha inteira do pattern: um `clone` raso compartilha referências mutáveis e produz bugs de aliasing difíceis de rastrear.

**Nota TS.** `structuredClone()` e spread cobrem a maior parte dos casos. O pattern se paga quando o clone precisa de lógica (resetar id, não copiar cache, reatribuir owner).

---

## Singleton

**Intenção (GoF).** Garantir que uma classe tenha somente uma instância e prover um ponto global de acesso a ela.

**Use quando** a unicidade é uma **invariante do domínio** e não apenas uma conveniência — um pool de conexões que o processo inteiro deve compartilhar, por exemplo.

**Em TypeScript, a forma canônica é um módulo:**

```ts
// db.ts — o cache de módulos do ES já garante uma instância por processo
export const db = createPool({ max: 10 });
```

Escrever `getInstance()` com um campo estático reimplementa à mão o que o sistema de módulos já faz.

**Trade-offs — leia antes de usar.** Singleton é estado global com um nome respeitável. Ele acopla todo consumidor a um ponto fixo, torna testes dependentes de ordem (o estado vaza entre casos), e esconde dependências que deveriam aparecer na assinatura. Em serverless/Fluid Compute, "uma instância" significa uma por *instância de função*, não uma globalmente — assumir o contrário produz bugs de cache raros e caros.

**Prefira** injetar a dependência. Se injetar parece trabalhoso demais, isso normalmente mede o acoplamento que o Singleton estava escondendo, não um defeito da injeção.

---

## Escolhendo entre eles

Todos encapsulam qual classe concreta é instanciada; diferem em quando e como:

- **Factory Method** — a decisão vive na subclasse do criador. Herança.
- **Abstract Factory** — a decisão vive em um objeto passado. Composição. Escolha esta quando famílias precisam ser coerentes.
- **Builder** — foco no *processo* de montagem, não em qual classe.
- **Prototype** — evita a hierarquia de criadores copiando instâncias.

Abstract Factory é frequentemente implementada com Factory Methods, e pode ser implementada com Prototype. Builder e Abstract Factory podem coexistir: o builder monta, a factory decide as peças.
