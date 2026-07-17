---
name: craft
description: Princípios de desenvolvimento (Clean Code, DRY, KISS, YAGNI, SOLID, coesão/acoplamento, refatoração) e design patterns (GoF, DDD, Fowler/PoEAA, padrões distribuídos) aplicados ao escrever, revisar e refatorar código — com ênfase em quando NÃO aplicá-los. Use ao implementar uma feature, corrigir um bug, revisar código ou um PR, decidir se abstrai ou duplica, nomear coisas, quebrar uma função/classe, organizar classes, modelar domínio, tratar erro, escrever teste. Dispare também em pedidos como "deixe isso limpo", "bem estruturado", "código de qualidade", "isso está over-engineering?", "vale abstrair isso?", "isso tá acoplado demais", "refatore", "revise esse código", "melhore esse trecho", "qual pattern usar aqui", "explique o Strategy/Observer/Factory", "quero trocar a implementação sem mexer no resto", "aggregate/value object/repository" — mesmo que o usuário não cite nenhum princípio ou pattern pelo nome. Dispare também ao revisar código com if/switch crescendo, herança em excesso, God class, ou dependência direta de detalhe de infraestrutura. Também para justificar NÃO refatorar, NÃO aplicar um princípio e NÃO aplicar pattern algum.
---

# Craft

Princípios não são checklist. São **hipóteses sobre o custo futuro de mudar o código** — e cada um tem um preço cobrado à vista contra um benefício que só chega se a mudança que você previu acontecer. Aplicar um princípio sem a força que o justifica é pagar o preço e não receber nada.

O erro caro quase nunca é "faltou princípio". É **princípio aplicado cedo demais**: a abstração errada, a interface com uma implementação, o `switch` polimorfizado antes do segundo caso existir. Duplicação você conserta quando entende o padrão; a abstração errada se defende sozinha, porque já custou caro e ninguém quer admitir (sunk cost). Por isso o default desta skill é **conservador**: espere a evidência.

## A pergunta que vem antes de qualquer regra

**O que está variando, quem sofre quando muda, e isso já aconteceu — ou eu estou adivinhando?**

Se você não consegue apontar **dois casos reais que já existem no código**, você está adivinhando. Adivinhar custa: build, delay, carry, repair (`references/tradeoffs.md` §1).

## Como usar

Não leia tudo. Decida aqui, abra **uma** referência.

| Referência | Quando abrir |
|---|---|
| `references/clean-code.md` | Nomear, tamanho de função, parâmetros, comentários, tratamento de erro, testes (F.I.R.S.T.), as 4 regras do Design Simples, e o catálogo de 66 heurísticas do cap. 17 |
| `references/refactoring-smells.md` | Você sentiu um cheiro e quer o nome + o tratamento; o catálogo de ~58 técnicas; quando **ignorar** o smell |
| `references/tradeoffs.md` | A decisão é "abstrair ou duplicar?", "vale a pena limpar isso?", "isso é YAGNI?" — Fowler, Beck, Sandi Metz, dívida técnica |
| `references/solid.md` | SOLID: definição real, sinal de violação, custo de aplicar cedo, e onde cada um **não** se aplica (TS, React, funcional, scripts) |
| `references/engineering-quality.md` | Coesão/acoplamento (as escalas), ocultação de informação, revisão de código (limites medidos), custo de manutenção, quando o rigor não se paga |
| `references/modeling-uml.md` | Vai desenhar/comunicar estrutura; agregação vs. composição; quando herança é errada; quando o diagrama é desperdício |
| `references/design-principles.md` | Os 9 princípios de OO (encapsule o que varia, favoreça composição, Menor Conhecimento…), a tabela **princípio violado → pattern candidato**, e o conceito de anti-pattern |
| `references/gof-creational.md` | Criação de objetos: Abstract Factory, Builder, Factory Method, Prototype, Singleton |
| `references/gof-structural.md` | Composição/estrutura: Adapter, Bridge, Composite, Decorator, Facade, Flyweight, Proxy |
| `references/gof-behavioral.md` | Algoritmos e responsabilidades: Chain of Responsibility, Command, Interpreter, Iterator, Mediator, Memento, Observer, State, Strategy, Template Method, Visitor |
| `references/ddd.md` | Modelagem de domínio: Ubiquitous Language, Bounded Context, Entity, Value Object, Aggregate, Repository, Domain Service, Domain Event |
| `references/beyond-gof.md` | Pós-GoF: Repository/Unit of Work, DI, Null Object, Result, Hexagonal/Ports & Adapters, CQRS, Event Sourcing, Saga, Circuit Breaker, Registry, Object Pool |
| `references/typescript-notes.md` | Antes de implementar qualquer pattern em TS/JS — o que a linguagem já resolve sem classe extra |

Skill irmã: **conventional-commits** (a mensagem do commit).

---

## Regra dos três — o núcleo

> 1ª vez: **apenas faça**.
> 2ª vez: **faça careta e duplique mesmo assim**.
> 3ª vez: **refatore**.

Por que três: com dois exemplos você não distingue **regra** de **coincidência**. A abstração certa exige ver o padrão, e o padrão precisa de exemplos. Abstrair no segundo é apostar — e a aposta errada sai mais cara que a duplicação.

A regra dos três é, principalmente, uma **regra de não fazer**: na 1ª e na 2ª vez, *não abstraia*.

### DRY é sobre conhecimento, não sobre texto

Dois trechos idênticos que codificam **decisões diferentes** que coincidem *hoje* **não são duplicação** — são coincidência. Unificá-los acopla dois motivos de mudança independentes, e a próxima mudança em um vai quebrar ou parametrizar o outro.

**Teste:** *quando a regra A mudar, a regra B tem que mudar junto — sempre?*
Sim → duplicação real. Não/talvez → coincidência. **Deixe duplicado.**

### "Duplicação é mais barata que a abstração errada"

A frase citada pela metade vira desculpa. A tese inteira (Sandi Metz) tem **um gatilho** e **um remédio**:

**O gatilho — passo 6.** Você está prestes a **adicionar um parâmetro, flag ou booleano a uma função compartilhada para fazê-la servir um caso novo**. Pare. A pergunta não é "como faço caber?", é: *isso ainda é uma abstração, ou já são duas coisas costuradas com um `if`?*

Esse passo é detectável em diff. É o sinal mais acionável desta skill inteira.

**O remédio — quando a abstração já apodreceu:**
1. **Re-inline** o código em cada call site.
2. Em cada um, **delete** o que não se aplica àquele caso.
3. Remova a abstração **e os condicionais** junto.
4. Você tem duplicação honesta. Deixe o padrão real emergir.

> "The fastest way forward is back."

---

## YAGNI — e onde ele não se aplica

**Invoque YAGNI quando:** existe capacidade construída para uma **feature presumida** (sem usuário real hoje) **e** ela **adiciona complexidade**. As duas condições, juntas.

Os quatro custos (o 1º é o menor): **build** · **delay** (a feature real atrasou) · **carry** (todo o código fica mais difícil, para sempre) · **repair** (quando a feature chega, não é como você previu — paga para fazer *e* para desfazer).

**YAGNI NÃO se aplica a:** refatoração, testes, CI, boa modularidade, bons nomes.

> "Yagni only applies to capabilities built into the software to support a presumptive feature, it does not apply to effort to make the software easier to modify."

Se não aumenta complexidade, não invoque YAGNI. Escolher a estrutura de dados certa e nomear bem não é gold plating.

**Alvos típicos em revisão:** interface com **uma** implementação · parâmetro de configuração sem consumidor · hook/extension point "para depois" · Strategy com uma estratégia · camada de abstração sobre uma lib que nunca vai ser trocada.

---

## Quando NÃO aplicar

A parte que as outras fontes escondem. Cada item tem fonte.

**Não refatore quando:**
- **A de-duplicação está deixando o código mais feio.** Regra literal do refactoring.guru: *"dê um passo atrás, reverta todas as suas mudanças e acostume-se com aquele código."* Refatoração que não limpou não é refatoração — é churn.
- **Não há rede de testes.** Sem testes você não está refatorando, está torcendo. Adicione teste ao entrar, ou não entre.
- **O cruft está em código estável que ninguém toca.** Juros ≈ zero. Ignorar é a decisão certa; a vigilância vai para as áreas de alta atividade.
- **Antes da 3ª repetição.**
- **É reescrita, não refatoração.** Se a build fica quebrada por dois dias, o nome certo é *restructuring* — outra atividade, outro risco, outra conversa. Teste: *posso commitar e deployar agora?*

**Não aplique o princípio quando:**
- **Protótipo genuinamente descartável.** Sommerville autoriza baixa confiabilidade **desde que descartado**. O pecado não é o protótipo sujo — é promovê-lo a produção. Decida qual dos dois você está fazendo **antes da primeira linha**.
- **Script/glue/one-off.** SOLID otimiza para mudança ao longo do tempo por várias pessoas. Um cron de 40 linhas não tem esse eixo: todo custo é à vista, todo benefício é futuro e não vem.
- **Meia-vida curta.** *"There are no free lunches, all abstractions have a cost."* Se o código morre antes de a dependência mudar, DIP é custo puro.
- **A linguagem já resolve.** Ver a tabela abaixo.
- **Modularizar demais também é defeito.** Existe um mínimo de custo: *"devemos evitar modularizar a menos ou a mais"*. Separação de interesses *"pode ser levada longe demais"* — muitos problemas minúsculos, cada um fácil, e o conjunto impossível.

**Mas a janela de "sujar" é minúscula.** A design payoff line fica em *"usually weeks not months"*, e devs sentem a queda de velocidade *"within a few weeks"*. "Vamos limpar depois do lançamento" já é tarde. Qualidade **interna** não tem trade-off com custo — é mais barata. (Qualidade **externa** tem, e é negociável.)

---

## Antes de aplicar um princípio de OO, veja se o TS já resolve

Boa parte do catálogo existe porque C++/Java dos anos 90 não tinham funções de primeira classe, módulos ou tipos algébricos.

| Forma clássica | Em TypeScript, frequentemente |
|---|---|
| Strategy com hierarquia | Uma função como parâmetro, ou `Record<Kind, fn>` |
| Singleton | Um módulo com `export const` — o cache de módulos do ES já garante instância única |
| Factory Method p/ um produto | `createX()` |
| Template Method | Função de alta ordem com hooks |
| Command sem undo | Um closure `() => void` |
| Iterator | `Symbol.iterator` / generators |
| Observer local | `EventTarget`, ou callbacks |
| Decorator de dados | Spread/composição de funções |
| Interface p/ ISP | **Structural typing**: `function f(x: { id: string })` |
| OCP via polimorfismo | **Discriminated union + switch exaustivo** |

A versão com classes se paga quando há **estado por instância**, **múltiplas implementações vivas ao mesmo tempo**, ou **um contrato que precisa de nome e documentação**. Se nada disso vale, prefira a forma simples e diga por quê. Detalhes em `references/typescript-notes.md`.

**A inversão que importa:** com union types, o `switch` exaustivo é **superior** ao polimorfismo — o compilador aponta todo lugar a atualizar. OCP otimiza para "adicionar tipos"; unions, para "adicionar operações" (*expression problem*). Escolha pelo eixo que de fato varia.

**Regra prática: Rule of Three > OCP.** Abstraia na 3ª variação, quando o eixo é *observado*.

---

## Patterns: vocabulário, não catálogo a cumprir

Um pattern só vale quando **nomeia uma força que já existe no código**. Se a força não existe, o pattern é indireção pura. A pergunta certa quase nunca é "qual pattern eu uso?", é a mesma de sempre: *o que está variando, e a que custo?*

**Princípios vêm antes do catálogo.** Escreva o código mais simples que resolve o problema; introduza o pattern quando a necessidade emergir do código real. **Um princípio violado é evidência; um pattern ausente não é.** Ao revisar código existente, a rota mais convincente é diagnosticar pelo princípio violado (`references/design-principles.md`) — o princípio explica *por que* dói; o nome do pattern, sozinho, não explica nada.

### Do sintoma ao candidato

Vá do que dói para o pattern, nunca o contrário.

| Sintoma no código | Candidatos | Referência |
|---|---|---|
| `switch`/`if` sobre um tipo, repetido em vários lugares | Strategy, State, Polimorfismo simples | behavioral |
| `switch` sobre um tipo, mas as operações é que crescem | Visitor | behavioral |
| Subclasses explodindo em combinações (2 eixos: N×M) | Bridge | structural |
| Precisa somar comportamento por instância, em runtime | Decorator | structural |
| Objeto muda de comportamento conforme estado interno | State | behavioral |
| Construtor com muitos parâmetros opcionais | Builder, objeto de options | creational |
| Famílias de objetos que precisam combinar entre si | Abstract Factory | creational |
| Biblioteca externa com interface incompatível | Adapter | structural |
| Subsistema complexo com muitos passos de setup | Facade | structural |
| Estrutura árvore tratada uniformemente (folha vs. nó) | Composite | structural |
| Um objeto precisa reagir a mudanças de outro sem acoplar | Observer, Mediator | behavioral |
| Ação precisa de undo, fila, log ou retry | Command, Memento | behavioral |
| Vários handlers possíveis, um (ou nenhum) atende | Chain of Responsibility | behavioral |
| Controle de acesso/lazy/cache/remoto sobre um objeto | Proxy | structural |
| Muitos objetos idênticos consumindo memória | Flyweight | structural |
| Regra de negócio vazando para controller/componente | Entity, Value Object, Domain Service | ddd |
| Invariante quebrando entre objetos relacionados | Aggregate | ddd |
| Domínio conhece SQL/HTTP/ORM | Repository, Ports & Adapters | ddd, beyond-gof |
| Mesmo termo com dois significados no sistema | Bounded Context | ddd |
| `null` checado em todo lugar | Null Object, Result/Option | beyond-gof |
| Leitura e escrita com modelos conflitantes | CQRS | beyond-gof |
| Chamada externa instável derrubando o sistema | Circuit Breaker, Retry | beyond-gof |

Se dois candidatos servem, escolha o de **menor indireção**. Strategy e State têm a mesma estrutura e diferem só na intenção: Strategy o cliente escolhe, State o objeto transita sozinho. Essa distinção de intenção é o que o pattern comunica — a estrutura sozinha não comunica nada.

### Nomes do domínio, não do catálogo

Os nomes do catálogo são abstratos demais para produção. O próprio GoF manda incorporar o participante ao nome do domínio, não usá-lo cru: `PixPaymentStrategy`, nunca `ConcreteStrategyA`. `PricingPolicy` é melhor ainda se o time já fala "política de preço" — **o vocabulário do domínio ganha do vocabulário do catálogo quando os dois competem.** Sufixe com o pattern só quando isso ajuda a prever o contrato (`UserRepository`, `OrderBuilder`). Evite `ManagerFactoryProviderImpl`.

### Diga o custo, sempre

Todo pattern troca simplicidade local por flexibilidade **em um eixo específico**. Ao recomendar, declare o eixo e o preço: *"Bridge deixa você adicionar renderers sem tocar nas formas, ao custo de uma indireção a mais em toda chamada e de um arquivo extra por implementação."* Isso é o que separa recomendação de catálogo recitado — e é a informação que o usuário precisa para **discordar de você**.

### Ao explicar um pattern

Pedido didático ("explique o Observer") → use a estrutura do próprio GoF, reduzida: **Intenção** (uma frase) · **Problema** (o cenário concreto que dói sem ele; prefira o domínio do usuário) · **Solução** (TypeScript curto e executável) · **Trade-offs** (todo pattern piora algo) · **Quando não usar** (a alternativa mais simples e a condição que a torna insuficiente).

Nada de UML em ASCII sem pedirem. Não invente "conhecidos usos" — cite os reais: Node streams são Decorator + Observer; `useReducer` é Command; `addEventListener` é Observer.

### Armadilhas de pattern

- **Pattern preventivo.** Strategy porque "um dia pode ter outro algoritmo" cobra indireção hoje por uma opção que talvez nunca seja exercida. Vale a **regra dos três**. *Exceção:* quando a barreira é de arquitetura (Repository/porta) e trocar depois custaria reescrever o domínio inteiro.
- **Aplicar à risca.** O GoF documenta uma forma em C++/Smalltalk de 1994. Adaptar não é traição — é o uso correto. Uma Factory que é função exportada continua sendo Factory.
- **Mais patterns ≠ design melhor.** Patterns adicionam classes, camadas e indireção; onde não são necessários, isso é só complexidade.
- **Confundir estrutura com intenção.** Adapter, Decorator, Proxy e Facade têm estrutura quase idêntica. Adapter converte interface, Decorator soma comportamento, Proxy controla acesso, Facade simplifica um subsistema. **Nomear errado desinforma mais do que não nomear.**
- **DDD tático sem estratégico.** Entity, Value Object e Repository em um CRUD sem regra de negócio produzem burocracia. A modelagem só se paga onde há complexidade de domínio real — o resto pode ser CRUD honesto.
- **Singleton como estado global.** Geralmente é acoplamento global com nome respeitável (é acoplamento **comum**, o segundo pior da escala). Prefira injetar; se injetar parece caro, esse é o sinal do acoplamento que o Singleton escondia.

---

## Os dials: todo smell é a cura de outro levada longe demais

Refatorar bem é achar o ponto, não zerar o smell. Se você está corrigindo um, o smell oposto é o seu freio.

| Eixo | Extremo A | Extremo B | O meio |
|---|---|---|---|
| Granularidade | **Large Class** / Divergent Change | **Lazy Class** / Shotgun Surgery | Uma classe, um motivo para mudar |
| Delegação | **Message Chains** (nenhuma) | **Middle Man** (demais) | Hide Delegate até a cadeia sumir, não além |
| Dado × comportamento | **Data Class** | **Feature Envy** | Junte — exceto quando Strategy/Visitor separa de propósito |
| Abstração | **Speculative Generality** (cedo) | **Duplicate Code** (tarde) | **Regra dos três** |
| Parâmetros | **Long Parameter List** | Dependência indesejada | Passe o mínimo, e só dados |

Um smell **não é prova de problema** — é gatilho de investigação. Em review, escreva o smell **e a pergunta que ele levanta**. Se a resposta for "está ok", está ok.

---

## Coesão e acoplamento — o que de fato prediz custo

O nome mais barato de diagnosticar é o **nome**. Se precisa de "e", "Manager", "Utils" para nomear, a coesão está no fundo da escala.

**Acoplamento, do pior ao melhor:** conteúdo (mexe no interno do outro — viola encapsulamento) → **comum** (global mutável) → **controle** (`render(data, isPreview)` — *boolean parameter é este nível*) → carimbo (passa `User` inteiro para usar `user.id`) → dados.

**Ocultação de informação — o argumento real:** não previne o erro, **contém o raio de alcance** dele. Por isso o critério de decomposição não é "quais funções existem", é **"quais decisões vão mudar"**. Cada decisão volátil (provedor de CMS, shape de tabela, formato de payload) atrás de uma interface, sozinha.

**O dado que reordena tudo:** manutenção é 50–75% do orçamento — e dentro dela **65% é funcionalidade nova, só 17% é bug**. Otimizar para "menos bugs" ataca 17%. Coesão/acoplamento/ocultação servem aos 65%: são controles sobre o **custo da análise de impacto**.

---

## Ao revisar código

**Limite medido, não opinião:** Fagan mediu ~125 declarações/hora na preparação e 90–125 na reunião; o teto é 2h. ⇒ **um PR revisável tem ordem de 200 linhas.** Acima disso a taxa não sobe — **a detecção cai**.

**A economia:** corrigir custa 1,5 unidade no projeto e **67 depois da entrega (≈45×)**. E *"as revisões não gastam tempo, elas poupam"* — a data de entrega **com** revisão é anterior à data sem.

**Regras:** revise o **produto, não o produtor** · enuncie o problema, **não o resolva** na revisão · **tudo que o typechecker/linter já pega sai da checklist humana**.

**Vocabulário, não veredito.** *"Isso responde a dois atores"* e *"isso força o cliente a conhecer o subtipo"* aceleram a conversa. *"Isso viola SRP"* não.

---

## O fluxo

1. **Nomeie a força.** Uma frase: o que muda e quem sofre. Não conseguiu? Não há problema de design — há código que você não gostou de olhar. É diferente.
2. **Conte os casos.** Menos de três → duplique e siga.
3. **Ache o eixo real de mudança.** É o tipo que cresce, ou a operação? (union+switch vs. polimorfismo)
4. **Veja se a linguagem resolve.** Se resolve, resolva assim e **diga por quê**.
5. **Aplique a menor mudança que atende.** *"Use a coisa mais simples que funcione."* Se um pattern nomeia a força, escolha o de menor indireção — e **declare o eixo e o preço**.
6. **Cheque o dial oposto.** Curei Message Chains e criei Middle Man?
7. **Verifique:** ficou mais limpo? nenhuma feature entrou junto? testes passam **sem terem sido reescritos**? Se "não" no primeiro — **reverta**.

**Ao mudar código existente:** *"make the change easy (warning: this may be hard), then make the easy change"* — refatoração preparatória e a feature em **commits separados**. E dois chapéus, nunca ao mesmo tempo: ou você preserva comportamento, ou você adiciona.

---

## Recusar é uma resposta legítima

Dizer *"não abstraia isso ainda — só há dois casos, e eles podem ser coincidência"* com a justificativa é uma resposta melhor que aplicar o pattern. Princípios *"should be 'violated' sometimes"*; o objetivo é a **decisão informada de desconsiderar um princípio**, não a conformidade.

O que os dois lados do debate concordam: **princípio preventivo é dano; princípio como diagnóstico de dor já sentida é útil.** Vale igual para pattern.

---

## Fontes

Gamma/Helm/Johnson/Vlissides, *Design Patterns* (1994) · Freeman et al., *Head First Design Patterns* (os 9 princípios, a disciplina de deixar o pattern emergir) · Evans, *Domain-Driven Design* (2003) · Fowler, *PoEAA* e *Refactoring* · Martin, *Clean Code* · Beck, *Design Simples* · Sandi Metz, *The Wrong Abstraction* · refactoring.guru.
