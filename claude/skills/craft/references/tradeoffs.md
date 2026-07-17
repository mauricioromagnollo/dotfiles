# Craft: Fowler, Beck, Metz — design, refatoração e princípios

Síntese acionável dos artigos-chave. Foco em **tese**, **trade-offs** e **quando o princípio NÃO se aplica**.

---

## 1. YAGNI — You Aren't Gonna Need It
`https://martinfowler.com/bliki/Yagni.html`

**Tese:** não construa capacidade para uma *presumed feature* (funcionalidade presumida, ainda não disponível para uso real). O erro não é só desperdiçar esforço — é que o custo se paga em quatro frentes, e as três últimas são as caras.

**Os quatro custos:**

| Custo | O que é |
|---|---|
| **Cost of build** | Analisar, programar e testar algo que não será usado. O custo óbvio e o *menor* deles. |
| **Cost of delay** | Custo de oportunidade: o tempo gasto na feature presumida atrasa a feature que gera receita agora. |
| **Cost of carry** | A complexidade extra torna **todo** o código mais difícil de entender e modificar — você paga juros em cada mudança futura, mesmo que a feature presumida nunca seja tocada. |
| **Cost of repair** | Quando a feature finalmente chega, quase nunca é como você previu. Você paga para construir *e* para desfazer/corrigir. |

**Onde YAGNI NÃO se aplica** (a parte mais ignorada):

> "Yagni only applies to capabilities built into the software to support a presumptive feature, it does not apply to effort to make the software easier to modify."

- Refatoração, testes automatizados, CI/CD, boa modularidade: **não são violações de YAGNI**. São as práticas *habilitadoras* que tornam o design evolutivo viável. Sem elas, YAGNI é irresponsável — você precisa conseguir adicionar a feature depois, barato.
- > "if you do something for a future need that doesn't actually increase the complexity of the software, then there's no reason to invoke yagni."
  Se não adiciona complexidade, não invoque YAGNI. Nomear bem, extrair uma função, escolher a estrutura de dados certa — isso não é "gold plating".

**Acionável na revisão:** ao ver um parâmetro de configuração, um hook, uma interface com uma única implementação, ou um `strategy` com uma estratégia — pergunte: *existe usuário real hoje?* Se não: cost of carry começa agora e nunca para.

---

## 2. As 4 regras do design simples (Beck)
`https://martinfowler.com/bliki/BeckDesignRules.html`

**Em ordem de prioridade:**

1. **Passes the tests** — funciona. Nada importa antes disso.
2. **Reveals intention** — o código é fácil de entender.
3. **No duplication** — "Once and only Once" (DRY / SPOT).
4. **Fewest elements** — remova tudo que não serve às três anteriores.

**Comentário de Fowler:**
- > "The rules are in priority order, so 'passes the tests' takes priority over 'reveals intention.'"
- Sobre a briga eterna entre #2 e #3: Fowler considera **a ordem entre elas irrelevante**, "since they feed off each other in refining the code" — eliminar duplicação revela intenção e vice-versa.
- Quando #2 e #3 conflitam de fato (Beck: praticamente só em testes): **"empathy wins over some strictly technical metric"** — otimize para quem vai ler, não para a métrica.
- A regra "no duplication" é "perhaps the most powerfully subtle of these rules": *"the exercise of eliminating duplication is a powerful way to drive out good designs"* — duplicação não é só feia, é um **sensor de design**.

**Trade-off:** a regra #4 (fewest elements) é o antídoto direto contra a #3 aplicada com fanatismo. Eliminar duplicação criando 5 camadas de abstração viola #4 e #2 juntas.

---

## 3. Technical Debt (metáfora de Ward Cunningham)
`https://martinfowler.com/bliki/TechnicalDebt.html`

**Tese:** a metáfora existe para tornar **conversável com não-técnicos** a decisão de quando limpar *cruft* e quando conviver com ele. É um argumento **econômico**, não moral.

- **Juros (interest):** o tempo extra por causa do cruft.
  > "If the module structure was clear, then it would take me four days to add the feature but with this cruft, it takes me six days. The two day difference is the interest on the debt."
- **Principal:** o custo de limpar o cruft.
- **Quando pagar o principal:** quando você vai voltar ali. > "if I have two more similar features coming up, then I'll end up faster by removing the cruft first."
- **Quando NÃO pagar:** cruft em código **estável, que ninguém toca**, tem juros ≈ zero. Ignorar é a decisão certa. A vigilância vai para as áreas de alta atividade.
- **Estratégia:** pagamento **gradual e incremental** durante o trabalho normal — não um "grande refactoring". A alocação de esforço naturalmente segue a atividade, que é onde os juros são maiores.
- **Aviso:** times que cortam qualidade para entregar rápido "end up maxing out all their credit cards, but still delivering later than they would have done had they put the effort into higher internal quality."

---

## 4. Technical Debt Quadrant
`https://martinfowler.com/bliki/TechnicalDebtQuadrant.html`

Duas dimensões: **deliberado × inadvertido** e **imprudente (reckless) × prudente**.

|  | **Reckless** | **Prudent** |
|---|---|---|
| **Deliberate** | "We don't have time for design" — sabe fazer melhor, escolhe não fazer, e subestima o custo. Quase sempre sai pela culatra: *"good design and clean code is to make you go faster."* | "We must ship now and deal with consequences" — decisão consciente de adotar um design insustentável a longo prazo por um ganho de curto prazo (ex.: fechar um release). **Legítimo**, desde que os juros sejam listados e pagos. |
| **Inadvertent** | "What's Layering?" — código bagunçado feito por quem ignora boas práticas. |  "Now we know how we should have done it" — **inevitável, mesmo para times excelentes**: > "it can take a year of programming on a project before you understand what the best design approach should have been." |

**Insight-chave:** o quadrante *inadvertent/prudent* é o mais importante — é dívida que **nenhuma quantidade de disciplina evita**. Aprender o design certo *é* o processo de construir. Isso destrói o argumento de "se tivéssemos projetado direito no começo".

**Acionável:** ao rotular dívida num PR/issue, diga *qual quadrante*. "Prudente/deliberada" merece um TODO com condição de pagamento; "imprudente/inadvertida" merece ensino, não ticket.

---

## 5. Design Stamina Hypothesis
`https://martinfowler.com/bliki/DesignStaminaHypothesis.html`

**Tese:** existe uma **design payoff line**. Antes dela, o projeto "sem design" entrega mais funcionalidade acumulada (pula a atividade de design). Depois dela, o projeto com bom design **ultrapassa e nunca mais é alcançado**, porque o sem-design degrada a velocidade continuamente.

- **Onde fica a linha?** > "usually weeks not months". Muito mais cedo do que as pessoas supõem.
- **Consequência:** a janela em que "sujar" é economicamente racional é **minúscula**. Praticamente só protótipos descartáveis e provas de conceito de fato descartadas.
- **Caveat honesto de Fowler:** > "it's a conjecture, there is no objective proof that this phenomenon actually occurs." Ele não consegue medir produtividade nem qualidade de design objetivamente. Trata como **axioma operacional**, baseado em observação de campo — e admite a fraqueza abertamente.

**Trade-off real:** se você *genuinamente* sabe que o código morre em dias (spike, demo única), você está abaixo da linha. Todo o resto — inclusive "esse serviço é pequeno" — já está acima.

---

## 6. Is High Quality Software Worth the Cost?
`https://martinfowler.com/articles/is-quality-worth-cost.html`

**Tese:** **software de alta qualidade interna é MAIS BARATO de produzir.** Isso inverte a intuição de qualidade-versus-custo de todo o resto da vida.

- **Qualidade externa** (UI, ausência de defeitos, confiabilidade): o cliente vê. Aqui o trade-off clássico **existe** — mais qualidade custa mais dinheiro, e é legítimo negociar.
- **Qualidade interna** (arquitetura, modularidade, clareza): o cliente **nunca vê**. Aqui **não há trade-off** — é um pseudo-trade-off. Investir *economiza* dinheiro.
- **O argumento:** cruft ⇒ curva de produtividade que começa rápida e degrada; devs gastam cada vez mais tempo entendendo antes de mudar, e injetam mais defeitos ao mudar.
- **Escala de tempo:** > "Developers find poor quality code significantly slows them down within a few weeks." Não meses, não anos. Não existe "vamos limpar depois do lançamento" — o depois já é tarde.
- Times de elite também produzem cruft; a diferença é que o gerenciam via testes automatizados, refatoração frequente e CI. Dados DORA: quem entrega várias vezes ao dia tem taxa de falha *menor*.

**Como usar em conversa com produto:** nunca peça "tempo para qualidade" como favor moral. Enquadre como: *"cortar aqui nos torna mais lentos em semanas, não em anos — o pedido é o caminho mais rápido para a data que você quer."*

---

## 7. Opportunistic Refactoring / Regra do Escoteiro
`https://martinfowler.com/bliki/OpportunisticRefactoring.html`

**Tese:** refatoração é **prática diária e contínua**, não uma fase agendada. Você refatora o código que você já está tocando por outro motivo.

- **Camp site rule (Bob Martin):** *"Always leave the code behind in a better state than you found it."* Não precisa ser grande — renomear uma variável, extrair um método.
- **Objeção "vou quebrar algo":** refatoração depende de rede de testes. Se a área é mal coberta, **adicione testes ao entrar**. Truque de Fowler: **injete um erro deliberado** e veja se a suíte pega — mede a qualidade real da rede.
- **Objeção "não é meu código / é outro módulo":** não adie melhorias entre módulos só porque a mudança é "lá". Adiar = nunca fazer.
- **Objeção "vamos agendar um sprint de refactoring":** times que refatoram bem *"hardly ever need to plan refactoring"*. Refactoring agendado é sintoma de que ele não está acontecendo.
- **Caveat — o "rabbit hole":** arrumar uma coisa revela outra, e outra. É risco real de consumir tempo imprevisto. Só o **julgamento** separa melhoria produtiva de garimpo infinito. Timebox e saiba abortar.
- **Obstáculos de processo:** **strong code ownership** e **feature branches longos** matam a refatoração oportunista (o custo de merge desencoraja mexer no que não é estritamente necessário).

---

## 8. Preparatory Refactoring
`https://martinfowler.com/articles/preparatory-refactoring-example.html`

**Tese (Kent Beck):**
> "for each desired change, make the change easy (warning: this may be hard), then make the easy change"

- **A metáfora da rodovia (Jessica Kerr):** *"It's like I want to go 100 miles east but instead of just traipsing through the woods, I'm going to drive 20 miles north to the highway and then I'm going to go 100 miles east at three times the speed."* Ir 20 milhas na direção *errada* é o caminho mais rápido.
- **Dois chapéus:** o **chapéu de refatoração** (preserva comportamento, testes verdes o tempo todo) e o **chapéu de feature** (adiciona comportamento). Preparatory refactoring **maximiza o tempo com o chapéu de refatoração** — o modo de menor estresse e menor risco, porque os testes nunca ficam vermelhos.
- **Diferença de opportunistic refactoring:** aqui a refatoração é *motivada pela feature que vem a seguir*. Não é limpeza genérica — é abrir a estrada exatamente onde você vai passar. Isso também a torna **justificável para o negócio**: não é "limpeza", é "parte de implementar a feature".

---

## 9. Code Smell
`https://martinfowler.com/bliki/CodeSmell.html`

**Tese:** > "A code smell is a surface indication that usually corresponds to a deeper problem in the system." (termo cunhado por **Kent Beck** enquanto ajudava Fowler no livro *Refactoring*.)

Duas propriedades definidoras:
1. **Rápido de identificar** — "quick to spot", superficial por definição. Método longo, classe grande, lista de parâmetros gigante. Se precisa de análise profunda, não é um *smell*.
2. **NÃO é prova de problema** — > "smells don't *always* indicate a problem." É um **gatilho de investigação**, não um veredito. Um método longo pode estar correto.

**Exemplo do mecanismo:** *Data Class* (dados sem comportamento) é um bom smell porque leva à pergunta certa: *o comportamento deveria morar aqui?* — às vezes sim (objeto anêmico virando objeto de verdade), às vezes não (DTO de fronteira é legítimo).

**Valor pedagógico:** smells permitem que um dev júnior **detecte** um problema sem ainda entender a teoria por trás. Fowler sugere o **"smell of the week"**: o time ataca um tipo de smell por vez, subindo a habilidade coletiva.

**Acionável em code review:** não escreva "isso é um code smell" como conclusão. Escreva o smell **e** a pergunta que ele levanta. Se a resposta for "está ok", está ok.

---

## 10. Refactoring Malapropism
`https://martinfowler.com/bliki/RefactoringMalapropism.html`

**Tese:** "refatorar" virou sinônimo de "mexer no código", e isso **destrói uma distinção útil**.

- **Restructuring** é o guarda-chuva: *"any rearrangement of parts of a whole"*.
- **Refactoring** é **uma técnica específica** dentro dele, com duas exigências não-negociáveis:
  1. **Preserva comportamento** — usa *"small behavior-preserving transformations"*.
  2. **Sistema quase sempre funcional** — *"your system should not be broken for more than a few minutes at a time"*.

**Por que importa (acionável):** se o seu "refactor" deixa a build quebrada por dois dias, você **não está refatorando** — está fazendo uma reescrita/reestruturação, que é uma atividade com risco, custo e comunicação **completamente diferentes**. Chamar de refactoring esconde o risco de todo mundo, inclusive de você. Outras técnicas de restructuring são legítimas — só precisam do nome certo e do plano certo.

**Teste prático:** *posso commitar e deployar agora mesmo?* Se a resposta é não, o chapéu que você está usando não é o de refatoração.

---

## 11. Duplication, Rule of Three e AHA
*(Fowler, `Refactoring` — atribuído a Don Roberts; e `https://kentcdodds.com/blog/aha-programming`)*

**Rule of Three ("three strikes and you refactor"), popularizada por Fowler no *Refactoring*:**

> "The first time you do something, you just do it. The second time you do something similar, you wince at the duplication, but you do the duplicate thing anyway. The third time you do something similar, you refactor." — Don Roberts

**Por que três e não dois:** duplicação é ruim para manutenção, **mas escolher a abstração certa exige exemplos suficientes para ver o padrão**. Com dois exemplos você não distingue coincidência de regra. Abstrair cedo demais é apostar na abstração errada — que sai *mais caro* que a duplicação (ver §12).

**AHA — Avoid Hasty Abstractions (Kent C. Dodds):**
- > "prefer duplication over the wrong abstraction" (Sandi Metz)
- > "optimize for change first" (Dodds) — a métrica não é "quantas linhas repetidas", é "quão fácil é mudar".
- Receita: (1) permita a duplicação no início; (2) espere o padrão emergir; (3) abstraia **quando você entende os casos de uso de verdade**; (4) não otimize cedo.

**Trade-off central: DRY é sobre CONHECIMENTO, não sobre TEXTO.**
Dois trechos idênticos que representam **decisões de negócio diferentes** que apenas *por acaso* coincidem hoje **não são duplicação** — são *coincidência*. Uni-los acopla dois motivos de mudança independentes, e a próxima mudança em um vai quebrar ou parametrizar o outro. Duplicação real é a mesma *regra* escrita duas vezes.

---

## 12. The Wrong Abstraction — Sandi Metz
`https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction`

**Tese:** > **"duplication is far cheaper than the wrong abstraction"** — e quando a abstração se prova errada, o remédio é **desfazê-la**, não parametrizá-la.

**A sequência exata do apodrecimento:**

1. Programador A identifica duplicação.
2. A extrai a duplicação para um método/classe com nome.
3. A substitui as ocorrências pela nova abstração.
4. Tempo passa. Os requisitos ficam parados.
5. **Surge um novo requisito que é *quase* — mas não exatamente — servido pela abstração.**
6. Programador B, "respeitando" a abstração existente, **adiciona um parâmetro e um condicional** para lidar com o caso novo. A abstração agora faz duas coisas. *A natureza dela mudou fundamentalmente.*
7. Repete-se o passo 6. Mais requisitos, mais parâmetros, mais condicionais. **Ciclo após ciclo, até o código ficar incompreensível.**
8. Alguém herda esse código. Nada faz sentido. Qualquer mudança é aterrorizante.

**A armadilha psicológica — sunk cost fallacy:** ninguém remove a abstração porque *já se investiu muito nela*. Quanto mais complicada, mais "valiosa" ela parece, e mais as pessoas se sentem obrigadas a preservá-la. **O esforço passado torna-se a razão para continuar sofrendo.**

**O remédio prescrito (a parte que quase todo mundo esquece):**
1. **Re-inline** o código da abstração de volta em **cada call site**.
2. Em cada local, **delete** as partes que não se aplicam àquele caso.
3. Remova a abstração **e todos os condicionais** junto com ela.
4. Você agora tem duplicação — mas duplicação **honesta e legível**. Deixe novos padrões emergirem *a partir do entendimento atual*.

> **"the fastest way forward is back."**

**Sinal de alarme mais útil deste artigo:** você está prestes a **adicionar um booleano/flag/parâmetro a uma função compartilhada para fazê-la servir um caso novo**. Esse é o passo 6. Pare. A pergunta certa não é "como faço isso caber?" — é "essa abstração ainda é uma abstração, ou já virou duas coisas costuradas com um `if`?".

---

## 13. Semantic Diffusion
`https://martinfowler.com/bliki/SemanticDiffusion.html`

**Tese:** termos técnicos perdem o significado ao se espalhar. É *"a succession of the telephone game"* (telefone sem fio): cada grupo que repassa o termo adiciona distorção, até o núcleo evaporar.

**Mecanismo:** cunhagem com definição clara → popularidade → o termo chega a quem não conhece as origens → cada hand-off adiciona interpretação → perda de significado.

**Fatores que aceleram:**
- **Popularidade** — ironicamente, o sucesso é o veneno: *"unpopular terms have less people to create the telephone chains"*.
- **Abstração** — conceitos amplos difundem mais rápido que ferramentas concretas. *Ruby on Rails* resiste (é tangível); *Agile* sofre (são valores e princípios).
- **Distância de comunicação** — aprender de fontes secundárias em vez dos originadores.

**Exemplos:** *Agile* ("não planejar nada"), *Web 2.0* (reduzido a "usar AJAX"), *Refactoring* (§10).

**Otimismo:** os termos historicamente se recuperam — *object-oriented* e *patterns* se estabilizaram.

**Acionável:** quando alguém disser "vamos refatorar", "isso é clean architecture", "somos ágeis" — **peça a definição operacional**. O termo, sozinho, já não carrega informação.

---

## 14. Two Hard Things
`https://martinfowler.com/bliki/TwoHardThings.html`

> **"There are only two hard things in Computer Science: cache invalidation and naming things."** — Phil Karlton
> (primeira fonte documentada: post do Tim Bray em 2005; Bray lembra de ouvir a frase por volta de 1996-97.)

Variantes que Fowler cataloga:
- **Leon Bambrick:** *"There are 2 hard problems in computer science: cache invalidation, naming things, and off-by-1 errors."*
- **Mathias Verraes:** adaptação para sistemas distribuídos — piada auto-referente sobre ordem de entrega de mensagens.
- **Phillip Scott Bowden:** *"there's two hard problems in computer science: we only have one joke and it's not funny."*
- **Nat Pryce:** a própria proliferação de variantes sugere que programação não é tão simples quanto se diz.

**O ponto sério:** *naming things* é difícil porque nomear é **design**. Um nome ruim é um sintoma de que você não entendeu o conceito. A regra #2 de Beck (reveals intention) e o passo 6 da Metz (a abstração que já não pode ser nomeada honestamente) são o mesmo problema visto de dois ângulos.

---

## 15. SOLID e quando princípios não se aplicam
`https://martinfowler.com/articles/dipInTheWild.html` (sidebar "Pragmatics on Principles")

**Tese de Fowler:** ele questiona o próprio termo "design principles". Vê SOLID como *"up front ideas that I often come back to due to familiarity"* — heurísticas familiares, não leis.

Citações-chave:
- > "I am not a fan of 'best practices', but I do like good ideas for a given context"
- Princípios de design **"Should be 'violated' sometimes"**.
- > **"There are no free lunches, all abstractions have a cost."**
- > "A colleague prefers to replace 'principle' with guideline. That fits for me as well."
- *"By calling something a principle, when I'm pragmatic I will probably violate a principle"* — o vocabulário de "princípio" cria culpa onde deveria haver julgamento.
- O objetivo a perseguir: **a capacidade de tomar uma decisão informada de desconsiderar um princípio de design**.

**Quando DIP especificamente NÃO compensa:**
> "If you happen to be working on something with a short software half-life, then the best thing for your context might be to be directly dependent on those dependencies."

- **Meia-vida curta do software:** inverter dependências custa indireção; se o código morre antes de a dependência mudar, você pagou por nada.
- **TDD estrito:** depender diretamente pode ser melhor que inverter por reflexo.
- Cada interface com uma única implementação, criada "por causa do D", é **cost of carry** (§1) travestido de princípio.

**Conexão com o resto:** SOLID aplicado dogmaticamente é uma máquina de produzir *hasty abstractions* (§11) — especialmente OCP e DIP, que empurram você a criar pontos de extensão para features presumidas. É YAGNI com sotaque de arquiteto.

---

## Síntese: as tensões que importam

| Força | Contra-força | Como decidir |
|---|---|---|
| DRY / no duplication (§2) | Wrong abstraction (§12), AHA (§11) | A duplicação é do mesmo **conhecimento** ou coincidência? Rule of three: espere o terceiro. |
| YAGNI (§1) | Habilitadores (testes, refactoring, modularidade) | Adiciona **complexidade** para uma **feature presumida**? Só aí invoque YAGNI. |
| Ship agora (dívida prudente/deliberada §4) | Design payoff line em **semanas** (§5, §6) | A janela abaixo da linha é minúscula. Só é honesta se os juros forem listados e pagos. |
| SOLID / princípios (§15) | "All abstractions have a cost" | Meia-vida do software. Violar conscientemente > seguir por reflexo. |
| Limpar tudo (§7) | Rabbit hole; cruft em código estável (§3) | Juros ≈ frequência de mudança. Refatore onde você **está passando**. |

**As três frases para levar:**
1. **"Make the change easy (this may be hard), then make the easy change."** (§8)
2. **"Duplication is far cheaper than the wrong abstraction... the fastest way forward is back."** (§12)
3. **"Yagni does not apply to effort to make the software easier to modify."** (§1)
