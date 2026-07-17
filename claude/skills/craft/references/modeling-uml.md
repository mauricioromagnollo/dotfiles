# UML — modelagem acionável

Fonte: Silva, A. & Videira, C., *UML, Metodologias e Ferramentas CASE* (Centro Atlântico, 2001), 578pp; citações por página impressa. Complementado por Fowler, *UmlAsSketch*.

Só o que é acionável para **desenhar/comunicar estrutura de código** — agregação vs. composição, quando herança é errada, quando o diagrama é desperdício. CASE e metodologias datadas foram deliberadamente omitidos.

Ver também: `solid.md` (os princípios que este livro já enunciava em 2001, com outro vocabulário).

---

## A.1 Quando um diagrama vale a pena — e quando é desperdício

### Os 4 princípios de modelagem (§2.3.2, p.36-37, via Booch)

| # | Princípio (citação) | Tradução prática |
|---|---|---|
| **P1** | *"A escolha dos modelos a criar tem uma profunda influência no modo como o problema é encarado e consequentemente como a solução é obtida."* | O diagrama **enviesa a solução**. Modelar um fluxo como classes vs. sequência produz arquiteturas diferentes. Escolha pelo que quer responder. |
| **P2** | *"Cada modelo deve poder ser expresso em diferentes níveis de precisão/abstracção."* | Detalhe é função **do leitor**, não do sistema. Diagrama sem leitor definido é lixo. |
| **P3** | *"Os melhores modelos reflectem a realidade."* | O "calcanhar de Aquiles": separar "o que faz" de "como faz" deixa **a visão concebida e a implementada divergirem**. Diagrama que não bate com o código é pior que nenhum. |
| **P4** | *"Nenhum modelo é suficiente por si só. Qualquer sistema não-trivial é representado [...] através de pequeno número de modelos, razoavelmente independentes."* | "Pequeno número." "Razoavelmente independentes" = construíveis em paralelo, mas consistentes. |

Contrapeso datado (p.34): *"é preferível um mau modelo que nenhum modelo"*. P3 é a que envelheceu melhor.

### "Avisos do Processo ICONIX" (§11.3, p.356-357) — a parte ágil, e a mais útil do livro

ICONIX se posiciona *"algures entre a complexidade e abrangência do RUP e a simplicidade e o pragmatismo do XP"* (p.350). Ideia-chave (p.388):

> **"Fazer (i.e. modelar) o menos possível, no mais curto período de tempo, de forma a concretizar um bom sistema."**

Desperdícios explícitos — "evitar a perda de tempo com detalhes desnecessários":

- **Não perder demasiado tempo com a inspecção gramatical** (substantivos→classes tem retorno decrescente rápido).
- **Não endereçar o desenho da multiplicidade demasiado cedo.**
- **"Endereçar a agregação e composição apenas na fase do desenho detalhado."** ← decidir isso cedo é *especulação*.
- **Não passar semanas em modelos de casos de utilização elaborados a partir dos quais não é possível construir um adequado desenho de classes.** (diagrama bonito que não gera design = desperdício puro)
- **Não perder muito tempo em discussões sobre "include" vs "extend".** (debate de notação ≠ trabalho)
- **Não focar em métodos "get"/"set" em detrimento dos métodos reais.**
- **Não desenhar diagramas de estados para objectos com apenas dois estados.**
- **"Não modelar o que não é necessário modelar."**
- **"Não desenhar diagramas de estados só porque se consegue desenhá-los."** ← a regra geral.

Observação estrutural (p.351): *"a implementação apenas depende da versão detalhada do diagrama de classes final. (Parece óbvio, mas muitos pensam ainda que se poderiam usar diagramas de sequência para gerar código automaticamente!)"* → **o diagrama de classes é o único artefato no caminho crítico**; sequência/estado/componente são ferramentas de raciocínio descartáveis.

### Complemento moderno: Fowler, *UmlAsSketch*

- **Sketch** (o que se paga): comunicação **seletiva**, não completa. 10 min de whiteboard antes de horas de código (*forward*); desenhar a partir do código pra explicar ao time (*reverse*). Regra: **"comprehensiveness is the enemy of comprehensibility"**.
- **Blueprint**: rigor e completude; só se paga com geração/round-trip real. **Programming Language** (MDA): morto.

| Vale a pena | Desperdício |
|---|---|
| Sketch descartável antes de decisão estrutural cara | Diagrama "de documentação" que ninguém atualiza (viola P3) |
| Reverse sketch pra onboarding/explicar código | Notação exaustiva (include/extend, multiplicidade cedo) |
| Diagrama de classes que **vira código** | Objeto com 2 estados; diagrama porque "dá pra fazer" |
| Pequeno número de modelos complementares (P4) | Modelo elaborado que não gera design |
| Detalhe calibrado pro leitor (P2) | Diagrama sem leitor definido |

---

## A.2 Diagrama de classes: as relações

O livro (§6.3, p.169) reduz a **três** fundamentais: **dependência, generalização, associação**. Agregação/composição são *adornos* da associação; realização entra via interfaces (§6.4).

**Dependência** (p.169) — tracejada dirigida. *"Indica que a alteração na especificação de um elemento pode afectar outro elemento que a usa, mas não necessariamente o oposto."* Em código: outra classe como **argumento de operação** ou **tipo de atributo**. Nota prática: *"Por motivos de simplicidade e clareza não se explicita em geral este tipo de relações nos diagramas de classes, já que [...] encontra-se especificado implicitamente."* → **não desenhe dependências entre classes**; só se pagam entre **pacotes** e para **notas**.

**Generalização/Herança** (p.170) — linha cheia + triângulo branco. "is-a"/"is-a-kind-of". Dá: subclasse herda estado+comportamento, pode adicionar, pode redefinir. Restrições de semântica (p.171): `{disjoint}` (padrão, descendente pertence a **só uma** subclasse); `{overlapping}` (**produto cartesiano** das subclasses, ex. `CírculoComEtiqueta`); `{complete}`/`{incomplete}`.

**Associação** (p.171) — linha cheia. *"Relação estrutural que especifica que objectos de uma classe estão ligados a objectos de outra."* Adornos: **nome, papel, multiplicidade, tipo de agregação**; menos comuns: navegação, visibilidade, qualificação.
- **Navegação** (p.173): default **bidirecional**; unidirecional é decisão **de desenho**, não de análise → em código: quem tem a referência.
- **Classe-associação** (p.177): a associação **tem atributos próprios** (`Tarefa` entre `Pessoa` e `Empresa`). Sinal: a tabela de junção ganhou colunas → vira entidade.
- **N-árias** (p.177): *"pouco comuns"*; quase sempre decomponíveis em binárias via classe-associação.
- **Reflexivas** (p.176): mesma classe em papéis diferentes (condutor/passageiro).

### Agregação vs. Composição — a distinção prática

**Agregação simples** (p.174) — losango **vazio** no "todo": *"relação do tipo 'is-part-of' ou 'has-a' [...] traduz **apenas** o facto de uma classe ser composta por diferentes outras classes."*

**Composição** (p.174-175) — losango **cheio**. Adiciona **exatamente duas** semânticas: *"(1) forte pertença do 'todo' em relação à 'parte', e (2) tempo de vida delimitado (as 'partes' não podem existir sem o 'todo'). Adicionalmente [...] 'o todo' é responsável pela **criação e destruição** das suas 'partes'."*

**O teste decisivo — o motor (§6.7, Ex. 6.1, p.187):**
> *"A relação entre motor e veículo é de **agregação** [...] mas **não deve ser composição**, pois podem existir motores sem estarem directamente colocados nos veículos (estão algures em stock à espera [...] de substituírem um motor gripado!)."*

**A pergunta não é "é parte de?" — é: _a parte pode existir sozinha, com identidade própria, fora do todo?_** Motor em estoque existe → agregação. `Departamento` fora de `Empresa` não existe (p.175) → composição. Ou (p.97): composição = *"o corpo humano tem uma perna"*; agregação = *"uma empresa tem empregados"*.

| | Agregação | Composição |
|---|---|---|
| Ciclo de vida | Independente | **Todo cria e destrói a parte** |
| Construção | Parte injetada (recebida pronta) | Parte instanciada **dentro** do todo |
| Destruição do todo | Parte sobrevive | Parte morre junto (cascade) |
| Compartilhamento | Vários todos podem referenciar | Exclusiva de um todo |
| Sinal em código | `constructor(motor: Motor)` | `this.itens = []` no construtor |
| Sinal em dados | FK nullable / tabela separada | `ON DELETE CASCADE`, agregado DDD |

> ⚠️ Processo (ICONIX, p.356): **"Endereçar a agregação e composição apenas na fase do desenho detalhado."** Decidir isso no modelo de domínio é cedo demais.

### Quando herança é errado

O livro não tem seção "não use herança", mas os elementos são consistentes:

1. **A interface existe justamente para evitar herança falsa** (§6.4, p.179). Benefício nº1 declarado: *"Captura de semelhanças entre classes não relacionadas **sem forçar a criação de relações artificiais entre elas**."* → **Sinal de herança errada: superclasse criada só pra compartilhar código entre classes que não são a mesma coisa.** Isso é "relação artificial" — use interface + composição.
2. **Herança múltipla é rejeitada na prática** (p.179-180): Java não tem; uma classe implementa 0..N interfaces e um objeto *"pode providenciar vários tipos"*. Herança dá *um* eixo; realização dá *N*.
3. **Hierarquias `{overlapping}` são o cheiro** (p.171): `FiguraGeométrica` especializada por **duas dimensões ortogonais** (forma × etiqueta) gera `CírculoComEtiqueta` — explosão combinatória. **Duas dimensões de variação = herança errada** → Strategy/Bridge/composição.
4. **Herança é "ser"; associação é "ter"** (p.97). Se você narra com "tem"/"usa", não é herança.
5. **Checklist de "não deve ser classe"** (p.93, Coad & Yourdon): classes com **um só atributo**; com **um só objeto**; **sem serviços aplicáveis**; que **"de facto correspondem a atributos de outros objectos"**. Ótimo detector de hierarquia inventada.
6. **Erros usuais** (§6.7, Fig 6.25, p.189, marcado "Facto Real"): (a) *"classes de estruturas de dados do tipo contentores (listas, hashtables) ao nível da análise"* → implementação vazando no domínio; (b) *"especificar atributos de chaves estrangeiras entre classes. Esses atributos existem, mas de forma implícita nas associações"* → modelagem relacional disfarçada de OO.

### Realização (§6.4, p.180) — interface ⇄ classe/componente

> *"Uma interface é um **contrato** na forma de uma colecção de especificações de métodos que providencia um mecanismo para separação clara entre a vista externa e a vista interna."*

Benefícios (p.179): (1) captura semelhanças **sem relação artificial**; (2) declara métodos que classes se comprometem a implementar; (3) *"revelar a interface de programação de um objecto sem revelar a sua classe"* — visto por **tipos diferentes conforme a situação**. É ISP+DIP em 2001, antes do nome pegar. Versionamento (p.182): *"a alteração de um componente pode (e deve) ser realizada de forma transparente da perspectiva dos restantes componentes (seus clientes), o que é possível caso suporte todas as interfaces definidas em versões anteriores"* → OCP na prática.

### Quando usar diagrama de classes (§6.6, p.186)
Três situações, só três: **(1) modelar o vocabulário do sistema; (2) modelar colaborações simples; (3) modelar o desenho de um esquema de base de dados.**

Diagrama de **objetos** (p.186): fotografia num instante. *"Não pode (nem deve pretender) especificar completamente a estrutura de objectos"* — há infinitas combinações; serve só pra **expor um caso concreto**. Útil pra explicar um bug ou caso-limite; inútil como documentação.

---

## A.3 Diagrama de sequência: quando usa

Duas dimensões (§7.3.1, p.204): **horizontal = objetos** (a ordem horizontal **não tem significado**), **vertical = tempo**.

**Uso declarado** (§7.3, p.203): *"usados para especificar a realização de um caso de utilização bem como a realização de uma operação envolvendo diferentes objectos"*; *"particularmente úteis para **detalhar um cenário de um caso de utilização**, e mais adequados para especificar **situações complexas, bem como múltiplos e concorrentes fluxos de controlo**."*

**Sequência vs. Colaboração** (p.203): colaboração enfatiza **organização estrutural** → melhor para sistemas **não concorrentes** e *"para ilustrar relações entre objectos em padrões de desenho [Gamma94]"*. Semanticamente equivalentes (§7.3.3).

Mensagens (§7.2.4, p.202) mapeiam direto em código: **Call** (síncrono, mais comum), **Return**, **Send** (assíncrono), **Create**, **Destroy**. Detalhe fino (p.202): *"num fluxo de controlo procedimental, a seta de retorno pode (e deve) ser omitida"* — só explicite retorno em fluxo **não-procedimental**. Em concorrência: seta simples = passa o controle (bloqueante); assíncrona = não passa. Restrições: `{new}`, `{destroy}`, `{transient}`.

**Onde entra no processo** (p.388): sequência é onde se identifica *"o comportamento (i.e., as operações) dos objectos intervenientes. Essas operações são adicionadas numa versão detalhada e final dos diagramas de classes."* → **é uma ferramenta para descobrir quais métodos as classes precisam ter.** Meio, não fim; extraiu os métodos, jogue fora.

**Veredito:** vale quando o fluxo é **assíncrono, concorrente, ou atravessa muitos colaboradores** e você não segura na cabeça. Não vale pra fluxo linear de 3 chamadas.

## A.4 Diagrama de componentes: quando usa

Confissão útil (§8.1, p.238): *"Na nossa opinião os diagramas de implementação constituem a parte **mais limitada, mal explorada e compreendida do UML**."*

**Componente** (p.238-239): *"um conjunto de artefactos **físicos em formato digital**"* — código, binários, executáveis, docs. A diferença crucial: *"Um componente de software é uma **parte física**: existe de facto num determinado computador e **não apenas na mente do analista**, como acontece com o conceito de classe."* Três tipos: **instalação** (DLL, executáveis), **trabalho** (fonte, dados, docs), **execução** (processos, threads).

**Uso** (§8.3, p.243): *"ilustra as **dependências** entre vários componentes de software"*. Só **tipos**, nunca instâncias.

**A parte acionável** (p.240 + Fig 6.18, p.181): componentes se conectam **por interfaces**, não por acesso direto: *"os componentes de software implementam uma ou mais interfaces e é **através destas interfaces que providenciam as suas funcionalidades a outros componentes**"*; *"em função do acesso ao componente, assim são providenciadas diferentes funcionalidades."* Visibilidade depende do tipo (p.240): em fonte, controla acesso aos construtores internos; em executável, se outros podem invocar seu código.

**Veredito:** é o **grafo de dependências entre módulos/pacotes/serviços deployáveis** — hoje o import graph, o `package.json`, o docker-compose. Vale quando: (a) desenhar **fronteiras de deploy/build**; (b) mostrar que módulo A não pode importar B; (c) versionar contrato entre times. Em ICONIX é opcional, *"consoante as necessidades"* (p.355). Não vale como documentação de rotina.

---

## A.5 Princípios de modelagem que se traduzem em código

**Encapsulamento** (§3.5.2, p.89): *"o processo de 'esconder' todos os detalhes de um objecto que não contribuem para as suas características essenciais [...] a **localização de funcionalidades numa única abstracção auto-contida**, que esconde a respectiva implementação **e decisões de desenho**, através da disponibilização de uma interface pública."* Note "e decisões de desenho" — não é só `private`, é esconder *a escolha*. Objetos como **caixas negras** (p.94).

Os 4 "necessários e suficientes" para uma linguagem ser OO (p.90): **encapsulamento, herança, polimorfismo, abstração**. Sem herança/polimorfismo → *"baseadas em objectos"*. Complementares: modularidade, concorrência, persistência.

**Responsabilidade** — a definição de classe bem estruturada (§6.2, p.166) é SRP escrito em 2001:
> *"Uma classe bem estruturada é **simples e facilmente entendida**; providencia uma abstracção definida a partir do **vocabulário do domínio** do problema ou da solução; **agrega um conjunto restrito e bem definido de responsabilidades**; e providencia uma **separação clara entre a especificação abstracta e a sua implementação**."*

O ícone de classe tem **quarta seção opcional** (p.166) para *"a lista de responsabilidades que a classe assume"* — não cabe em uma linha? God class. Subsistema (Wirfs-Brock, p.97): *"conjunto de classes que colaboram entre si para realizar um conjunto de responsabilidades"* → responsabilidade é a unidade de agrupamento acima da classe.

Taxonomia de operações (p.94), útil pra revisar API: **Modificadores** (alteram estado), **Selectores** (acessam), **Iteradores**, **Construtor**, **Destrutor**. Classe onde tudo é modificador+seletor e nada é comportamento real = *anemic model* (o aviso p.357 sobre get/set é o mesmo ponto).

**Visibilidade** (§3.5.2, p.96): *"A interface é o conjunto de operações e atributos disponibilizados por uma classe, que consoante a visibilidade se pode dividir em três partes: **pública** (visível para todos os objectos do sistema); **protegida** (só visível pelas suas subclasses); **privada** (faz parte da interface mas não é visível para nenhuma outra classe, só está disponível na implementação da própria classe)."* Sintaxe (p.167), útil como checklist de assinatura:
```
visibility name [multiplicity] : type-expression = initial-value {property-string}
visibility name (parameter-list) : return-type-expression {property-string}
```
Multiplicidade default de atributo é `1..1`. Estereótipos agrupam operações por seção (p.168).

**Complexidade** (§2.4, p.37-39): é **essencial**, não acidental (Brooks). Atributos de sistema complexo (Courtois85, p.38), dois acionáveis:
- *"Num sistema complexo, as relações intra-componentes são mais fortes do que as inter-componentes."* ← alta coesão/baixo acoplamento como **observação empírica**, não regra.
- *"Um sistema complexo que funciona é invariavelmente uma evolução de um sistema simples que já funcionou; um sistema complexo concebido de raiz normalmente não funciona e dificilmente pode ser alterado de forma a que tal aconteça."* ← Lei de Gall — o argumento anti-BDUF dentro de um livro pró-modelagem.
- *"A selecção dos componentes elementares é arbitrária e depende de quem a efectua, pois não existem critérios universais."* ← honestidade sobre limites de fronteira.

Ferramentas: **decomposição hierárquica** (Dijkstra) + **abstração** (*"esquecer os detalhes menos importantes"*). Boas práticas (p.39-40): iterativo; rastreabilidade de requisitos; componentes reutilizáveis; verificação de qualidade **não apenas no final**; *"conceber sistemas de modo a facilitar a sua expansão e alteração"*.

---

## Referências

Silva, A. & Videira, C., *UML, Metodologias e Ferramentas CASE*, Centro Atlântico, 2001: §2.3.2 (p.36), §2.4 (p.37-40), §3.5.2 (p.88-97), §6.2-6.7 (p.166-192), §7.2-7.3 (p.198-213), §8.1-8.3 (p.237-246), §11.3 (p.356-357), §11.6 (p.387-389). · [Fowler — UmlAsSketch](https://martinfowler.com/bliki/UmlAsSketch.html)
