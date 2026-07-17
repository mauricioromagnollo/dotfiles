# Padrões além do GoF

O catálogo de 1994 cobre design de objetos em um processo. Estes patterns cobrem o que veio depois: arquitetura de aplicação (Fowler, *PoEAA*), fronteiras (Cockburn) e sistemas distribuídos (Nygard, Hohpe). São tão usados quanto o GoF no código moderno.

Índice: [Compound Patterns e MVC](#compound-patterns-e-mvc) · [Ports & Adapters](#ports--adapters-hexagonal) · [Dependency Injection](#dependency-injection) · [Repository & Unit of Work](#repository--unit-of-work) · [Null Object](#null-object) · [Result / Option](#result--option) · [CQRS](#cqrs) · [Event Sourcing](#event-sourcing) · [Saga](#saga) · [Circuit Breaker & Retry](#circuit-breaker--retry) · [Registry](#registry) · [Object Pool](#object-pool)

---

## Compound Patterns e MVC

Um **compound pattern** é um conjunto de patterns que trabalham juntos numa solução de propósito geral, aplicável a muitos problemas. Combinar patterns numa solução específica não basta — para ser compound, a combinação precisa ser reutilizável como um todo.

**MVC é o exemplo canônico**, e entendê-lo como composição de três patterns explica seu funcionamento melhor que qualquer diagrama:

- **Model → Observer.** O model notifica views e controllers sobre mudanças de estado, mantendo-se desacoplado deles. Ele não sabe quem observa.
- **View + Controller → Strategy.** O controller é a *estratégia* da view: a view delega a ele qualquer decisão sobre comportamento de interface e cuida só do visual. Trocar o controller muda o comportamento sem tocar na view.
- **View → Composite.** A interface é uma árvore de componentes aninhados tratados uniformemente.

**Por que isso importa na prática.** Os derivados modernos (MVVM, MVP, Redux, o modelo de componentes do React) recombinam essas mesmas peças, e nenhum deles é MVC clássico. No React, por exemplo, a view não é observer do model no sentido clássico — o estado flui por props e o re-render é disparado pelo runtime (Hollywood Principle, ver `design-principles.md`). Reconhecer quais patterns o framework já implementa evita reimplementar à mão o que ele te dá: escrever um Observer próprio dentro de um framework reativo é trabalho duplicado.

**Trade-off.** MVC só se paga com uma interface que tem estado e várias visões do mesmo dado. Para uma página que renderiza e não muda, é cerimônia.

---

## Ports & Adapters (Hexagonal)

**Ideia.** O domínio define **portas** (interfaces) no seu próprio vocabulário; a infraestrutura fornece **adapters** que as implementam. A dependência aponta sempre para dentro: o domínio não importa nada de fora. É o DIP aplicado a uma fronteira inteira (ver `solid.md`).

```
HTTP ──► [ adapter ] ──► ( porta ) ──► DOMÍNIO ──► ( porta ) ◄── [ adapter ] ──► Postgres
```

**Valor.** Trocar Postgres por outro banco, ou HTTP por CLI, sem tocar na regra de negócio; e testar o domínio inteiro sem I/O.

**Custo — e ele é real.** Uma interface e um adapter por fronteira, mesmo quando existe uma implementação só. Em um app pequeno isso é cerimônia pura. Aplique nas fronteiras que **você tem motivo para acreditar que vão mudar ou que precisam ser testadas sem I/O**, não em todas por simetria — a porta com um adapter só, criada por precaução, é exatamente o gatilho de YAGNI descrito em `tradeoffs.md`.

Clean Architecture e Onion Architecture são a mesma ideia com nomes e camadas diferentes.

---

## Dependency Injection

**Ideia.** Um objeto recebe suas dependências em vez de construí-las. Isso é o que torna Strategy, Adapter e portas testáveis — DI é a mecânica por trás de metade do catálogo.

```ts
class OrderService {
  constructor(private repo: OrderRepository, private clock: Clock) {}  // constructor injection
}
```

**Em TypeScript, prefira injeção por construtor pura.** Um container com decorators e metadata (InversifyJS, tsyringe) só se paga com um grafo grande e escopos por requisição; abaixo disso, o `new` na composition root é mais claro e não custa build magic.

**Injete o relógio.** `new Date()` dentro do domínio torna teste dependente de tempo real. `Clock` é a dependência que mais compensa injetar e a mais esquecida.

---

## Repository & Unit of Work

**Repository** (ver `ddd.md`) esconde a persistência atrás de uma coleção.

**Unit of Work** rastreia os objetos modificados numa operação de negócio e escreve tudo numa transação:

```ts
interface UnitOfWork {
  run<T>(work: (repos: { orders: OrderRepository }) => Promise<T>): Promise<T>;
}
// tudo dentro de run() commita junto ou aborta junto
```

**Quando pular.** Um ORM (Prisma, TypeORM) já implementa os dois. Envolvê-lo em outro Repository só se justifica se você quer o domínio independente do ORM — decida conscientemente, porque a camada extra não é grátis.

---

## Null Object

**Ideia.** Em vez de `null`, retorne um objeto com a mesma interface e comportamento neutro.

```ts
const nullLogger: Logger = { info() {}, error() {} };  // não checar nada no chamador
```

**Use quando** "ausente" tem comportamento padrão sensato (logger, cache, política vazia). **Não use quando** ausência é um erro que deve ser tratado — um Null Object silencioso engole bug. Para "pode não existir e o chamador precisa saber", use o tipo:

---

## Result / Option

**Ideia.** Tornar falha e ausência explícitas no tipo em vez de exceção ou `null`.

```ts
type Result<T, E> = { ok: true; value: T } | { ok: false; error: E };

const parseAge = (s: string): Result<number, 'nan' | 'negative'> => {
  const n = Number(s);
  if (Number.isNaN(n)) return { ok: false, error: 'nan' };
  if (n < 0) return { ok: false, error: 'negative' };
  return { ok: true, value: n };
};
```

**Valor em TS.** O compilador obriga a tratar o caso de erro, e os erros esperados ficam documentados na assinatura — coisa que `throw` não faz.

**Trade-off.** Propagar `Result` manualmente é verboso sem `?` (Rust) ou do-notation. Convenção que funciona: **Result para erros esperados** (validação, regra de negócio, 404), **exceção para bugs e o inesperado**. Misturar os dois sem critério é pior que qualquer um dos dois.

---

## CQRS

**Ideia.** Separar o modelo de **escrita** (comandos, invariantes, aggregates) do modelo de **leitura** (queries, projeções desnormalizadas). Não precisam do mesmo schema nem do mesmo banco.

**Use quando** leitura e escrita têm requisitos conflitantes — aggregates protegem invariantes mas são péssimos para uma tela que junta seis entidades; a query direta é péssima para garantir invariante.

**A versão barata, que resolve 90% dos casos:** mantenha os aggregates para escrita e faça as leituras com queries SQL diretas em DTOs, sem passar pelo domínio. Isso já é CQRS. **Não exige** bancos separados, event sourcing, nem bus de mensagem — e trazer tudo isso junto é o erro clássico com este pattern.

**Custo da versão completa.** Consistência eventual visível ao usuário ("salvei e não apareceu na lista") e sincronização de projeções.

---

## Event Sourcing

**Ideia.** Guardar a sequência de eventos como fonte da verdade; o estado atual é uma dobra sobre eles.

**Ganhos.** Auditoria perfeita, time-travel, projeções novas sobre histórico antigo.

**Custos — altos e permanentes.** Versionamento de evento é para sempre (você nunca deleta um evento antigo, então todo consumidor precisa entender formatos velhos); snapshots viram necessidade de performance; queries ad-hoc ficam difíceis; a curva de aprendizado do time é longa; corrigir dado errado exige evento compensatório.

Reserve para domínios onde o **histórico é o produto** — contabilidade, auditoria regulatória, versionamento. Não é um upgrade default de CQRS, apesar de aparecerem sempre juntos na literatura.

---

## Saga

**Ideia.** Transação de negócio distribuída como uma sequência de passos locais, cada um com uma **compensação** para desfazer logicamente o anterior quando algo falha (não há rollback distribuído).

```
reservar estoque → cobrar cartão → agendar entrega
   ↓ falhou?          ↓ falhou?
   —              liberar estoque (compensação)
```

**Custo.** Compensação nem sempre existe de verdade (e-mail enviado não volta). Idempotência vira obrigatória em todo passo. Estados intermediários ficam visíveis ao usuário.

**Antes de adotar:** se os passos cabem num banco só, uma transação ACID resolve com uma fração do custo. Saga é para quando a fronteira de serviço já existe.

---

## Circuit Breaker & Retry

**Circuit Breaker.** Depois de N falhas, pare de chamar o serviço por um tempo e falhe rápido; teste periodicamente se voltou (fechado → aberto → meio-aberto).

**Use quando** uma dependência instável pode esgotar seus recursos — sem breaker, requisições travadas acumulam e derrubam o chamador junto (falha em cascata).

**Retry.** Sempre com **backoff exponencial + jitter**, e **apenas em operações idempotentes**. Retry sem backoff transforma degradação em DDoS contra o próprio serviço; o jitter evita que todos os clientes retentem no mesmo instante.

Combine: breaker por fora, retry por dentro, timeout em tudo. Um retry sem timeout não protege de nada.

---

## Registry

**Ideia.** Um objeto bem conhecido onde outros encontram serviços/dados comuns.

**Aviso.** É Singleton com outro nome e carrega os mesmos problemas: estado global, dependências escondidas, testes acoplados. Service Locator é a variante mais comum e é considerada anti-pattern pela maioria hoje — ele esconde da assinatura o que DI deixa explícito. Prefira DI; use Registry só onde injetar é comprovadamente inviável.

---

## Object Pool

**Ideia.** Reutilizar instâncias caras em vez de criar/destruir (conexões, workers, buffers).

**Aplique com medição.** Pool prematuro adiciona bugs de estado sujo entre usos — um objeto devolvido ao pool sem reset carrega dados do cliente anterior, e isso é um bug de segurança, não só de correção.

Na prática, use o pool da sua lib (driver de banco, `undici`) em vez de escrever um. Em serverless com Fluid Compute, o pool vive por instância de função reutilizada — dimensione `max` contando as instâncias concorrentes, não só as conexões do banco.
