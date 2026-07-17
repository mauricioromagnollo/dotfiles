# Domain-Driven Design (Evans, 2003)

DDD não é um catálogo de classes — é uma tese sobre onde investir modelagem. A tese: em software com **complexidade de domínio real**, o gargalo não é técnico, é o entendimento compartilhado entre quem conhece o negócio e quem escreve o código. Os patterns existem para manter o modelo e a linguagem alinhados enquanto o código evolui.

**Antes de aplicar qualquer coisa daqui, faça a pergunta que Evans faria:** este subsistema tem regra de negócio que muda e é discutida por especialistas, ou é armazenamento com formulário na frente? Para o segundo, CRUD honesto é a resposta certa, e Entity/Value Object/Repository só produzem burocracia. Evans chama isso de distinguir o **core domain** do resto — a modelagem cara vai onde está a vantagem competitiva.

---

## Estratégico — vem primeiro

### Ubiquitous Language

Um vocabulário único, usado igual na conversa com o especialista, nos testes e nos identificadores do código. Se o negócio diz "apólice" e o código diz `InsuranceRecord`, cada leitura custa uma tradução, e traduções acumulam erro.

Na prática: quando o usuário descreve o domínio, use os termos dele nos nomes. Quando o termo do negócio for ambíguo, isso é um achado — traga à tona em vez de inventar um nome neutro.

### Bounded Context

Uma fronteira dentro da qual um modelo é consistente e um termo tem exatamente um significado. Contextos diferentes podem ter "Cliente" com significados diferentes — e **isso é normal**, não é duplicação a eliminar.

O sintoma que revela a fronteira: uma classe com campos que só metade do sistema usa. "Cliente" em Vendas (crédito, histórico de compra) e "Cliente" em Suporte (tickets, SLA) são duas classes em dois contextos, não uma classe com dez campos nullable.

Tentar um modelo canônico único para a empresa inteira é o erro que Bounded Context existe para evitar.

### Context Map

Como os contextos se relacionam. Os tipos que mais aparecem:

- **Shared Kernel** — código compartilhado; barato, mas acopla os times.
- **Customer/Supplier** — o upstream atende requisitos do downstream.
- **Conformist** — o downstream aceita o modelo do upstream como veio (sem poder de negociação).
- **Anticorruption Layer (ACL)** — o downstream traduz o modelo externo no seu próprio. É Adapter promovido a decisão de arquitetura, e é a defesa contra um modelo legado/terceiro contaminar o seu.
- **Open Host Service / Published Language** — o upstream publica um protocolo estável para vários consumidores.

---

## Tático

### Entity

Objeto com **identidade** que persiste através de mudanças de estado. Dois pedidos com os mesmos dados são pedidos diferentes se têm ids diferentes.

```ts
class Order {
  constructor(readonly id: OrderId, private items: OrderItem[]) {}
  equals(other: Order) { return this.id.equals(other.id); }   // identidade, não valor
}
```

### Value Object

Definido só pelos seus atributos, **sem identidade** e **imutável**. Dois `Money(10, 'BRL')` são intercambiáveis.

```ts
class Money {
  private constructor(readonly cents: number, readonly currency: Currency) {}
  static of(cents: number, currency: Currency) {
    if (!Number.isInteger(cents)) throw new Error('cents deve ser inteiro');
    return new Money(cents, currency);
  }
  add(other: Money): Money {
    if (other.currency !== this.currency) throw new Error('moedas diferentes');
    return new Money(this.cents + other.cents, this.currency);  // novo objeto
  }
}
```

Este é o pattern com melhor retorno do DDD tático e o mais subutilizado. `Money`, `Email`, `Cpf`, `DateRange` como VOs eliminam classes inteiras de bug (somar reais com dólares, CPF inválido circulando) e centralizam validação. Adote VOs mesmo em projetos onde o resto do DDD não se paga.

### Aggregate

Um cluster de objetos tratado como **uma unidade de consistência**, com uma Entity como **raiz**. Regras:

- Referências externas apontam **só para a raiz**.
- A raiz garante as **invariantes** de todo o cluster.
- Cada transação altera **um** aggregate; consistência entre aggregates é eventual.

```ts
class Order {                                  // raiz
  private items: OrderItem[] = [];             // interno — ninguém pega referência
  addItem(sku: Sku, qty: number) {
    if (this.status !== 'draft') throw new Error('pedido fechado');
    if (this.items.length >= 100) throw new Error('limite de itens');
    this.items.push(new OrderItem(sku, qty));  // invariante garantida aqui
  }
  get lines(): readonly OrderItem[] { return Object.freeze([...this.items]); }
}
```

**A pergunta que define a fronteira:** que dados precisam estar consistentes *no mesmo instante*? Só esses entram. Aggregates grandes causam contenção de lock e carga lenta; aggregates pequenos são quase sempre a escolha certa.

### Repository

Coleção de aggregates com interface de domínio, escondendo a persistência.

```ts
interface OrderRepository {          // no domínio — sem SQL, sem ORM
  findById(id: OrderId): Promise<Order | null>;
  save(order: Order): Promise<void>;
}
```

A implementação vive na infraestrutura. **Um repository por aggregate root** — repository para entidade interna quebra a fronteira do aggregate.

Não transforme o repository em query builder (`findByNameAndStatusOrderByDate…`): consultas de leitura complexas são sinal de CQRS (ver `beyond-gof.md`), não de mais métodos.

### Domain Service

Operação de domínio que não pertence naturalmente a nenhuma Entity ou VO — tipicamente porque envolve vários aggregates. É stateless e nomeada com verbo do negócio (`TransferFunds`, `PricingPolicy`).

Cuidado: Domain Service é a saída de emergência que vira desculpa. Se toda regra virou service e as entidades só têm getters, você tem **Anemic Domain Model** — objetos que são structs e "services" que são procedimentos. Isso é procedural com nomes de OO, e paga o custo do DDD sem receber o benefício. Antes de criar um service, tente de novo colocar a regra na entidade dona do dado. A distinção entre objeto e estrutura de dados — e a ressalva de que nem tudo precisa ser objeto — está em `clean-code.md`.

### Domain Event

Algo relevante que aconteceu no domínio, no passado (`OrderPlaced`, `PaymentFailed`). Permite consistência eventual entre aggregates e desacopla efeitos colaterais da transação principal.

```ts
type OrderPlaced = { type: 'OrderPlaced'; orderId: OrderId; at: Date };
```

Trade-off: você ganha desacoplamento e paga com fluxo invisível (é Observer em escala de arquitetura — ver os trade-offs em `gof-behavioral.md`). Entrega, ordenação e idempotência viram problema seu.

### Factory (no DDD)

Encapsula a criação de aggregates complexos garantindo que nasçam **válidos**. Complementa o Factory do GoF: lá o foco é qual classe instanciar, aqui é qual invariante garantir no nascimento.

---

## Ordem de adoção

Se o usuário quer "aplicar DDD", esta ordem entrega valor mais cedo e falha mais barato:

1. **Ubiquitous Language** — de graça, ajuda sempre.
2. **Value Objects** — retorno imediato, risco quase zero.
3. **Bounded Contexts** — quando o modelo único começa a rachar.
4. **Aggregates + Repositories** — quando invariantes cruzam objetos.
5. **Domain Events / CQRS** — só com necessidade concreta de escala ou integração.

Pular direto para 4 e 5 em um CRUD é o modo mais comum de DDD dar errado.
