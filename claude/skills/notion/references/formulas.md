# Fórmulas do Notion

Este arquivo cobre Notion Formulas 2.0 — a reescrita da linguagem que trouxe tipos de lista, variáveis, dot notation e formatação rica no resultado. Se você aprendeu fórmulas do Notion antes disso, boa parte do que você sabe ainda funciona, mas você provavelmente está escrevendo fórmulas três vezes mais longas do que precisa.

A tese: **fórmula boa é fórmula que outra pessoa consegue ler em seis meses.** A linguagem hoje tem `let`, quebras de linha e dot notation exatamente para isso. Uma fórmula de uma linha com sete `if()` aninhados não é impressionante, é dívida técnica.

Referências principais: <https://www.notion.com/help/formula-syntax> e <https://www.notion.com/help/formulas>

---

## 1. Tipos de dado

A linguagem é tipada, e a maior parte dos erros vem de misturar tipos.

| Tipo | Exemplo de valor | Vem de |
|---|---|---|
| **Text** (string) | `"Em andamento"` | Title, Text, Select, Status, URL, Email, Phone |
| **Number** | `42`, `3.14` | Number, ID, rollups numéricos |
| **Boolean** | `true`, `false` | Checkbox, comparações |
| **Date** | `now()`, `prop("Due date")` | Date, Created time, Last edited time |
| **Person** | um usuário | Person, Created by, Last edited by |
| **Page** (object) | uma página de database | Relation (elemento individual) |
| **List** | `[1, 2, 3]` | Multi-select, Relation, Person, `split()`, rollups |

Os tipos de lista que o Notion documenta explicitamente: **Person (list)**, **Page (list)** e **Text (list)**. Na prática você também produz listas de número e de data com `map()`.

**O que isso significa na prática:**

- `prop("Multi-select")` **não é texto**, é uma lista de texto. Comparar com `==` falha silenciosamente. Use `.includes("valor")`.
- `prop("Relation")` **não é uma página**, é uma lista de páginas. Para acessar propriedades, você precisa de `.first()`, `.at(0)` ou `.map()`.
- `prop("Person")` também é lista. `prop("Assignee") == "Maurício"` nunca vai ser verdadeiro.

Este é, de longe, o erro número um de quem migrou do Formulas 1.0.

---

## 2. Sintaxe moderna

### Acesso a propriedades

```
prop("Due date")
```

No editor, digitar o nome da propriedade sugere o autocomplete. `prop()` continua sendo a forma canônica escrita.

### Dot notation

Toda função pode ser chamada como método sobre o primeiro argumento. Estas duas linhas são idênticas:

```
length(prop("Name"))
prop("Name").length()
```

Encadear é onde o ganho aparece:

```
prop("Tasks")
  .filter(current.prop("Status") == "Done")
  .length()
```

Contra:

```
length(filter(prop("Tasks"), current.prop("Status") == "Done"))
```

**Use dot notation sempre que houver dois ou mais níveis.** Fórmula lida da esquerda para a direita é fórmula depurável.

### `let` e `lets`

`let(variável, valor, expressão)` — uma variável.

```
let(person, "Alan", "Hello, " + person + "!")
```
→ `"Hello, Alan!"`

`lets(v1, val1, v2, val2, ..., expressão)` — várias.

```
lets(a, "Hello", b, "world", a + " " + b)
```
→ `"Hello world"`

**Por que isso é a coisa mais importante desta seção:** sem `let`, expressões repetidas são recalculadas toda vez que aparecem. Uma fórmula que chama `dateBetween(prop("Due"), now(), "days")` cinco vezes calcula cinco vezes. Com `lets`, calcula uma.

Ganho de legibilidade + ganho de performance, ao mesmo tempo. Não há motivo para não usar.

```
lets(
  dias, dateBetween(prop("Due date"), now(), "days"),
  feito, prop("Status") == "Done",
  ifs(
    feito,      "✅ Concluído",
    dias < 0,   "🔴 Atrasado " + abs(dias) + "d",
    dias == 0,  "🟠 Hoje",
    dias <= 3,  "🟡 Em " + dias + "d",
                "🟢 " + dias + "d"
  )
)
```

### Quebras de linha e indentação

O editor de fórmulas é multi-linha. Use. Uma fórmula com `ifs()` de cinco ramos em uma linha só é ilegível; a mesma fórmula indentada é óbvia.

O editor também aponta, enquanto você digita, o que está faltando e que tipo ele espera — leia essa dica em vez de adivinhar.

### Comentários

O editor de Formulas 2.0 suporta comentários e tabulação em fórmulas multi-linha, conforme <https://www.notion.com/help/guides/new-formulas-whats-changed>. Use-os para explicar **por que**, não o que:

```
// Regra do comercial: SLA conta só dias úteis
```

Se a sua fórmula precisa de mais de duas linhas de comentário para ser entendida, ela provavelmente deveria ser duas propriedades.

### Operadores

| Operador | Uso |
|---|---|
| `+` `-` `*` `/` `%` | Aritmética. `+` também concatena texto |
| `==` `!=` | Igualdade. Também escritos `equal()` / `unequal()` |
| `>` `<` `>=` `<=` | Comparação |
| `and` `or` `not` | Lógica. Também aceitos como `&&`, `\|\|`, `!` |
| `X ? Y : Z` | Ternário — equivalente a `if(X, Y, Z)` |
| `^` | Potência (também `pow()`) |

---

## 3. Funções por categoria

Lista organizada por finalidade. A referência canônica é <https://www.notion.com/help/formula-syntax>.

### Lógica e condicionais

| Função | O que faz |
|---|---|
| `if(cond, a, b)` | Ternário |
| `ifs(c1, r1, c2, r2, ..., fallback)` | Cadeia de condições. **Substitui `if` aninhado** |
| `and` / `or` / `not` | Booleanos |
| `empty(x)` | `true` se vazio (texto vazio, número zero em alguns contextos, data nula, lista vazia) |
| `equal` / `unequal` | Igualdade explícita |

```
ifs(
  prop("Priority") == "P0", 3,
  prop("Priority") == "P1", 2,
  prop("Priority") == "P2", 1,
  0
)
```

**Regra:** a partir de dois níveis, `if` aninhado vira `ifs`. Não existe caso em que `if(a, x, if(b, y, if(c, z, w)))` seja preferível.

**Sobre `empty()`:** use sempre antes de operar em Date ou Person que podem estar vazios. Data vazia em operação aritmética não retorna zero, retorna um estado indefinido que trava automações.

### Texto

| Função | O que faz |
|---|---|
| `length(t)` | Número de caracteres (ou de itens, em lista) |
| `substring(t, início, fim)` | Fatia por índice (base 0) |
| `contains(t, sub)` | `true` se contém |
| `test(t, regex)` | Testa contra expressão regular |
| `match(t, regex)` | Retorna as correspondências |
| `replace(t, alvo, novo)` | Substitui a **primeira** ocorrência |
| `replaceAll(t, alvo, novo)` | Substitui **todas** |
| `lower(t)` / `upper(t)` | Caixa |
| `trim(t)` | Remove espaços nas pontas |
| `repeat(t, n)` | Repete n vezes |
| `split(t, separador)` | Texto → lista |
| `join(lista, separador)` | Lista → texto |
| `format(x)` | Converte qualquer coisa em texto |
| `style(t, ...)` | Aplica formatação (ver seção 5) |
| `unstyle(t)` | Remove formatação |
| `link(rótulo, url)` | Cria hyperlink |

**`format()` é obrigatório com mais frequência do que se imagina.** Concatenar número com texto às vezes funciona, às vezes não — `format()` remove a ambiguidade:

```
"Faltam " + format(prop("Dias")) + " dias"
```

**`replace` vs `replaceAll`:** `replace` só pega a primeira. Este é um bug clássico em limpeza de texto. Ambos aceitam regex no alvo.

### Números

| Função | O que faz |
|---|---|
| `round(n)` `floor(n)` `ceil(n)` | Arredondamento |
| `abs(n)` | Valor absoluto |
| `mod(a, b)` | Resto |
| `pow(a, b)` / `sqrt` / `cbrt` | Potência e raízes |
| `min(...)` / `max(...)` | Menor / maior |
| `sum(...)` / `mean(...)` / `median(...)` | Agregações (aceitam listas) |
| `exp` `ln` `log10` `log2` | Logaritmos e exponencial |
| `sign(n)` | -1, 0 ou 1 |
| `pi` / `e` | Constantes |
| `toNumber(t)` | Texto → número |

Arredondar para 2 casas (não há função nativa):

```
round(prop("Valor") * 100) / 100
```

**`min` e `max` servem de clamp**, e isso é subutilizado:

```
min(max(prop("Progresso"), 0), 1)   // garante entre 0 e 1
```

### Datas

| Função | O que faz |
|---|---|
| `now()` | Data e hora atuais |
| `today()` | Hoje à meia-noite |
| `dateAdd(d, n, unidade)` | Soma |
| `dateSubtract(d, n, unidade)` | Subtrai |
| `dateBetween(d1, d2, unidade)` | Diferença |
| `dateRange(início, fim)` | Cria um intervalo |
| `dateStart(r)` / `dateEnd(r)` | Extrai pontas de um intervalo |
| `formatDate(d, formato)` | Data → texto formatado |
| `parseDate(t)` | Texto ISO → data |
| `timestamp(d)` | Data → Unix timestamp |
| `fromTimestamp(n)` | Unix timestamp → data |
| `minute` `hour` `day` `date` `week` `month` `year` | Extraem componentes |

**Unidades aceitas** em `dateAdd` / `dateSubtract` / `dateBetween`: `"years"`, `"quarters"`, `"months"`, `"weeks"`, `"days"`, `"hours"`, `"minutes"`.

**Tokens de `formatDate`:** `"YYYY"` (ano), `"MM"` (mês), `"DD"` (dia), `"h"` (hora), `"mm"` (minuto).

```
formatDate(now(), "DD/MM/YYYY")
```

**Cuidado com `day()`:** retorna o dia da **semana** (0 = domingo, 6 = sábado). O dia do mês é `date()`. Essa confusão quebra metade das fórmulas de dias úteis que circulam por aí.

**`now()` vs `today()`:** `now()` inclui hora, então `dateBetween(prop("Due"), now(), "days")` pode retornar 0 para algo que vence amanhã de manhã. Para lógica de prazo em dias, use `today()`.

**Custo de `now()`:** ele muda constantemente, o que significa que toda fórmula que o usa é reavaliada com frequência. Numa database grande, isso pesa. Ver seção 8.

### Listas

| Função | O que faz |
|---|---|
| `at(l, i)` | Item por índice (base 0) |
| `first(l)` / `last(l)` | Primeiro / último |
| `slice(l, início, fim)` | Sublista |
| `length(l)` | Tamanho |
| `concat(l1, l2)` | Junta listas |
| `sort(l)` | Ordena |
| `reverse(l)` | Inverte |
| `unique(l)` | Remove duplicados |
| `includes(l, x)` | Contém? |
| `find(l, cond)` | Primeiro que satisfaz |
| `findIndex(l, cond)` | Índice do primeiro que satisfaz |
| `filter(l, cond)` | Sublista que satisfaz |
| `some(l, cond)` | Algum satisfaz? |
| `every(l, cond)` | Todos satisfazem? |
| `map(l, expr)` | Transforma cada item |
| `flat(l)` | Achata listas aninhadas |

Dentro de `map`, `filter`, `find`, `some` e `every`, a variável do item atual é **`current`**:

```
map([1, 2, 3], current + 1)     // → [2, 3, 4]
filter([1, 2, 3], current > 1)  // → [2, 3]
```

**`some` vs `every` resolvem perguntas de negócio inteiras numa linha:**

```
prop("Sub-item").every(current.prop("Status") == "Done")   // tudo pronto?
prop("Sub-item").some(current.prop("Blocked"))             // algo travado?
```

### Pessoas

| Função | O que faz |
|---|---|
| `name(p)` | Nome do usuário |
| `email(p)` | E-mail do usuário |

Como Person é lista:

```
prop("Assignee").first().name()
prop("Assignee").map(current.name()).join(", ")
```

### Utilitários

`id()` — retorna o ID da página. Útil para construir URLs.

---

## 4. Relations e rollups dentro de fórmulas

O recurso mais poderoso do Formulas 2.0 e o menos conhecido: **você pode ler propriedades das páginas relacionadas diretamente, sem criar um rollup.**

```
prop("Tasks").filter(current.prop("Status") != "Done")
```

Isso é o exemplo da própria documentação. `current` é uma **página**, e `.prop()` sobre ela acessa qualquer propriedade dela.

### Padrões essenciais

```
// Soma de estimativas das tarefas do projeto
prop("Tasks").map(current.prop("Estimate")).sum()

// Quantas subtarefas concluídas
prop("Sub-item").filter(current.prop("Status") == "Done").length()

// Nome do projeto pai (relation limitada a 1 página)
prop("Project").first().prop("Name")

// Data mais tardia entre as tarefas
prop("Tasks").map(current.prop("Due date")).sort().last()

// Lista de responsáveis únicos, como texto
prop("Tasks").map(current.prop("Assignee").first().name()).unique().join(", ")

// Herdar prioridade do projeto quando a tarefa não tem
if(
  empty(prop("Priority")),
  prop("Project").first().prop("Priority"),
  prop("Priority")
)
```

### Quando usar fórmula e quando usar rollup

| Situação | Escolha |
|---|---|
| Agregação simples (soma, contagem, max) sem condição | **Rollup**. Mais barato, mais legível, não conta para o limite de profundidade |
| Agregação **condicional** ("soma só das não canceladas") | **Fórmula** com `filter()` |
| Precisa de duas propriedades da página relacionada ao mesmo tempo | **Fórmula** |
| Precisa formatar o resultado (emoji, cor, texto) | **Fórmula** |
| Precisa navegar dois níveis (task → projeto → área) | **Fórmula**, mas cuidado com performance |

**Regra:** rollup por padrão, fórmula quando há condição ou formatação. A tentação de fazer tudo em fórmula porque "é mais poderoso" produz databases lentas.

### O erro que trava automações

Segundo <https://www.notion.com/help/common-formula-errors>: relations retornam listas, e acessar propriedades sem definir qual elemento causa pausa nas automações. Sempre use `.first()`, `.at(0)` ou `.map()`.

```
prop("Project").prop("Name")            // ❌ erro de tipo
prop("Project").first().prop("Name")    // ✅
```

---

## 5. Formatação rica no resultado

Fórmulas não retornam só valores — retornam valores **estilizados**. Isso é o que separa uma coluna de fórmula útil de uma coluna de números cinza.

### `style()`

```
style(texto, estilo1, estilo2, ..., cor)
```

**Estilos:** `"b"` (bold), `"u"` (underline), `"i"` (italic), `"c"` (code — renderiza como pill), `"s"` (strikethrough).

**Cores:** `"gray"`, `"brown"`, `"orange"`, `"yellow"`, `"green"`, `"blue"`, `"purple"`, `"pink"`, `"red"`. Adicionando o sufixo `_background` (ex.: `"red_background"`) você colore o fundo em vez do texto.

```
style("Notion", "b", "u")
```

**A combinação que vira pill colorida:**

```
style("Atrasado", "c", "red_background")
```

Isso renderiza como uma tag, visualmente idêntica a um Select — mas calculada. É como você faz "status automático" sem que ninguém precise atualizar nada.

### `link()`

```
link("Notion", "https://notion.so")
```

Rótulo + URL. Excelente para transformar um ID externo em link clicável:

```
link(prop("Ticket"), "https://jira.exemplo.com/browse/" + prop("Ticket"))
```

### Emojis como indicadores

Emoji é texto. Prefixar o resultado com um emoji é a forma mais barata de tornar uma coluna escaneável:

```
ifs(
  prop("Health") == "On track", "🟢 No prazo",
  prop("Health") == "At risk",  "🟡 Em risco",
  prop("Health") == "Off track","🔴 Fora do prazo",
  "⚪ Sem status"
)
```

**Cuidado:** não use `style()` com cor **e** emoji colorido ao mesmo tempo redundantemente. Escolha um vocabulário visual e mantenha ele consistente na database inteira.

---

## 6. Receitas prontas

Todas escritas com `lets` e indentação. Ajuste os nomes das propriedades.

### Barra de progresso

**Antes de escrever isto:** se a pergunta é só "quanto por cento está concluído", um rollup `Percent checked` (sobre um checkbox) ou `Percent not empty` (sobre `Completed on`) mais uma propriedade Number com `Show as: Bar` resolve sem fórmula nenhuma — ver `databases-e-propriedades.md`. A fórmula abaixo só se justifica quando você quer a barra em texto, controle do formato, ou lógica que o rollup não expressa.

```
lets(
  total, prop("Sub-item").length(),
  feitas, prop("Sub-item").filter(current.prop("Status") == "Done").length(),
  pct, if(total == 0, 0, feitas / total),
  cheias, floor(pct * 10),
  if(
    total == 0,
    "—",
    repeat("█", cheias) + repeat("░", 10 - cheias)
      + "  " + format(round(pct * 100)) + "%"
  )
)
```

Se você preferir a barra nativa: crie uma propriedade **Number** com o percentual e configure `Show as: Bar`. Mais bonito, menos flexível. Use a versão em texto quando quiser embutir o número junto ou colorir condicionalmente.

### Status por prazo (atrasado / hoje / próximo)

```
lets(
  d, prop("Due date"),
  feito, prop("Status") == "Done",
  dias, if(empty(d), 999, dateBetween(d, today(), "days")),
  ifs(
    feito,      style("✓ Concluído", "c", "green_background"),
    empty(d),   style("Sem prazo", "c", "gray_background"),
    dias < 0,   style("Atrasado " + format(abs(dias)) + "d", "c", "red_background"),
    dias == 0,  style("Hoje", "c", "orange_background"),
    dias <= 3,  style("Em " + format(dias) + "d", "c", "yellow_background"),
                style("Em " + format(dias) + "d", "c", "blue_background")
  )
)
```

Note o `if(empty(d), 999, ...)` — sentinela para evitar operação com data nula. Sem isso, itens sem prazo quebram a fórmula.

**Uso:** agrupe uma view por esta propriedade e você tem um triage automático.

### Dias úteis restantes

Não há função nativa. A aproximação correta (exclui sábados e domingos, ignora feriados):

```
lets(
  inicio, today(),
  fim, prop("Due date"),
  totalDias, dateBetween(fim, inicio, "days"),
  semanas, floor(totalDias / 7),
  resto, mod(totalDias, 7),
  diaSemana, day(inicio),
  extras, filter(
    map([0, 1, 2, 3, 4, 5, 6], current),
    current < resto and mod(diaSemana + current, 7) != 0
                     and mod(diaSemana + current, 7) != 6
  ).length(),
  if(empty(fim) or totalDias < 0, 0, semanas * 5 + extras)
)
```

**Honestidade sobre esta receita:** ela é cara e não conhece feriados. Se dias úteis são críticos para o seu negócio, a solução robusta é uma database `Calendar` com um item por dia útil e um rollup de contagem — mais trabalhoso de montar, muito mais barato de calcular e capaz de lidar com feriados brasileiros.

### Contagem de subtarefas concluídas

```
lets(
  subs, prop("Sub-item"),
  total, subs.length(),
  feitas, subs.filter(current.prop("Status") == "Done").length(),
  if(total == 0, "", format(feitas) + "/" + format(total))
)
```

Retornar `""` quando não há subtarefas é deliberado: uma coluna cheia de `0/0` é poluição visual.

### Checkbox condicional (booleano derivado)

```
prop("Status") == "Done"
  and not empty(prop("Completed on"))
  and prop("Sub-item").every(current.prop("Status") == "Done")
```

Fórmula que retorna boolean é renderizada como checkbox. **Isto é a forma certa de ter um "Done" confiável** — ele não pode divergir do Status porque é derivado dele.

Use como filtro em views: `Is really done is Unchecked`.

### Semáforo de saúde de projeto

```
lets(
  tarefas, prop("Tasks"),
  total, tarefas.length(),
  feitas, tarefas.filter(current.prop("Status") == "Done").length(),
  atrasadas, tarefas.filter(
    current.prop("Status") != "Done"
    and not empty(current.prop("Due date"))
    and dateBetween(current.prop("Due date"), today(), "days") < 0
  ).length(),
  pct, if(total == 0, 0, feitas / total),
  diasRestantes, if(empty(prop("Deadline")), 999,
                    dateBetween(prop("Deadline"), today(), "days")),
  ifs(
    total == 0,                     "⚪ Sem escopo",
    pct == 1,                       "✅ Concluído",
    atrasadas > 2 or diasRestantes < 0,  "🔴 Fora do prazo",
    atrasadas > 0 or diasRestantes < 7,  "🟡 Em risco",
                                    "🟢 No prazo"
  )
)
```

Esta é a fórmula que substitui a reunião de status. Os limiares (`> 2`, `< 7`) são o lugar onde você codifica a política do seu time — ajuste e documente em comentário.

### Formatação de moeda (BRL)

O formato nativo de Number com moeda resolve o caso simples. Use fórmula quando precisar embutir num texto:

```
lets(
  v, prop("Valor"),
  inteiro, floor(abs(v)),
  centavos, round((abs(v) - inteiro) * 100),
  sinal, if(v < 0, "-", ""),
  sinal + "R$ " + format(inteiro) + "," +
    if(centavos < 10, "0" + format(centavos), format(centavos))
)
```

Para separador de milhar, o caminho é `Number with commas` na propriedade nativa — replicar isso em fórmula exige manipulação de string que não compensa.

### Próximo aniversário / data recorrente anual

```
lets(
  original, prop("Data"),
  esteAno, dateAdd(original, year(today()) - year(original), "years"),
  proximo, if(dateBetween(esteAno, today(), "days") < 0,
              dateAdd(esteAno, 1, "years"),
              esteAno),
  dias, dateBetween(proximo, today(), "days"),
  formatDate(proximo, "DD/MM") + " · em " + format(dias) + "d"
)
```

Devolve sempre a próxima ocorrência, virando o ano automaticamente. Combine com um filtro `Dias até < 30` para uma view "aniversários do mês".

### Extração de domínio de URL

```
lets(
  u, prop("URL"),
  semProtocolo, replaceAll(u, "^https?://", ""),
  semWww, replaceAll(semProtocolo, "^www\\.", ""),
  if(empty(u), "", semWww.split("/").first())
)
```

Usa regex em `replaceAll`. Combine com `Group by` para ver de quais fontes seus links vêm.

### Idade do item (envelhecimento)

```
lets(
  dias, dateBetween(today(), prop("Created time"), "days"),
  ifs(
    prop("Status") == "Done", "",
    dias > 90, style(format(dias) + "d parado", "c", "red_background"),
    dias > 30, style(format(dias) + "d", "c", "yellow_background"),
               format(dias) + "d"
  )
)
```

A view de faxina do arquivo de views fica muito melhor com esta coluna.

### Score de priorização (valor ÷ esforço)

```
lets(
  valor, ifs(prop("Impact") == "High", 3,
             prop("Impact") == "Medium", 2,
             1),
  esforco, if(empty(prop("Estimate")) or prop("Estimate") == 0, 1, prop("Estimate")),
  urgencia, if(empty(prop("Due date")), 1,
               max(1, 30 / max(1, dateBetween(prop("Due date"), today(), "days")))),
  round(valor * urgencia / esforco * 10) / 10
)
```

Retorna número — ordenável. É a coluna `Score` usada no padrão "backlog priorizado".

---

## 7. Erros comuns e depuração

Fonte: <https://www.notion.com/help/common-formula-errors>

| Erro | Causa | Correção |
|---|---|---|
| **Permissões** | A fórmula referencia database à qual você não tem acesso | Garanta acesso a todas as páginas e databases citadas |
| **Wrong return type** | O tipo retornado não bate com o esperado (automações exigem tipo específico) | Use `.includes()` para multi-select em vez de `==`; troque `""` por `empty()` |
| **Formula depth limit reached** | Fórmulas só podem ter **15 camadas** de profundidade | Combine fórmulas e rollups em menos propriedades |
| **Variáveis referenciando variáveis** | Em automações, variáveis da mesma ação não se enxergam | Defina cada variável em uma ação separada |
| **Variáveis em filtros** | Variáveis não filtram páginas em ações de automação | Defina uma variável `Trigger page` e mire nela |
| **Relations e People** | São listas; acessar propriedade sem escolher o elemento pausa a automação | `.first()`, `.at(0)` ou `.map()` |
| **Undefined value** | Date ou Person vazios em operação | Cheque com `if()` / `empty()` antes |
| **Erros de sintaxe** | Parêntese faltando, operador errado, função inexistente | Leia a dica do editor; ele diz o que espera |

### Método de depuração

Fórmula não é código: você não tem breakpoint. O que funciona:

1. **Comece pelo pedaço menor.** Escreva só `prop("Tasks").length()` e confirme que retorna número. Depois adicione uma camada. Fórmula grande escrita de uma vez é impossível de diagnosticar.
2. **Use `format()` para inspecionar.** Troque temporariamente o retorno final por `format(variável)` para ver o que a variável realmente contém. Frequentemente você descobre que é uma lista quando achava que era texto.
3. **Leia a mensagem do editor.** Ele diz o tipo que está recebendo e o que esperava. Isso resolve 80% dos casos.
4. **Cheque vazios primeiro.** Se a fórmula funciona em algumas linhas e não em outras, o culpado quase sempre é uma propriedade vazia.
5. **Confirme os tipos das pontas.** Multi-select, Person e Relation são listas. Sempre. Mesmo com um item só.

### Erros de raciocínio que a documentação não lista

- **`day()` não é o dia do mês.** É o dia da semana (0 = domingo). Dia do mês é `date()`.
- **`now()` inclui hora**, então diferenças em dias podem sair com uma unidade a menos do que você espera. Use `today()` para lógica de prazo.
- **Comparar Status com texto funciona, mas quebra em renomeação.** Se você renomear a opção "Done" para "Concluído", toda fórmula que compara com `"Done"` para de funcionar silenciosamente. Isso é um argumento forte para não codificar nomes de opção em muitas fórmulas — centralize a lógica numa propriedade só e derive as outras dela.
- **Fórmula não pode referenciar ela mesma** e nem criar ciclos entre propriedades. O Notion detecta e recusa.

---

## 8. Performance

Fórmulas são recalculadas. Numa database de 200 itens, nada disso importa. Em 20.000, importa muito.

**O que custa caro, em ordem decrescente:**

1. **Fórmulas que atravessam relations.** `prop("Tasks").map(...)` num projeto com 300 tarefas lê 300 páginas. Se cada tarefa também tem uma fórmula que lê o projeto, você criou um leque quadrático.
2. **Cadeias de fórmula sobre fórmula sobre rollup.** O limite documentado é 15 camadas, mas a performance degrada muito antes disso. Duas ou três camadas é o teto saudável.
3. **`now()`.** Muda continuamente, então força reavaliação frequente. `today()` é mais barato porque muda uma vez por dia.
4. **`repeat()` e manipulação pesada de string** em muitas linhas (barras de progresso em texto, por exemplo).
5. **Cadeias rollup → fórmula → rollup.** Rollup de rollup não existe (o Notion não permite), então quem precisa atravessar duas relations acaba intercalando uma fórmula entre os dois rollups. Funciona, mas cada camada recalcula em cascata — materialize o valor intermediário com automação sempre que puder.

**O que fazer:**

- **Use `lets` para não recalcular.** Ganho real e gratuito.
- **Prefira rollup a fórmula** para agregações simples. Rollups são otimizados e não contam para a profundidade.
- **Não coloque fórmula pesada em view que carrega sempre.** Se a coluna de "saúde do projeto" só é olhada semanalmente, esconda-a nas views do dia a dia — ela ainda é calculada, mas você reduz o custo de render.
- **Arquive.** A maior otimização de fórmula é ter menos linhas. Uma database com 40.000 tarefas das quais 38.000 estão concluídas há dois anos deveria ter as antigas movidas para uma database de arquivo.
- **Materialize o que não muda.** Se um valor foi calculado uma vez e nunca mais mudará (esforço real de uma tarefa concluída), uma automação que grava num campo Number normal é infinitamente mais barata que uma fórmula recalculando para sempre.

**Sinal de que você exagerou:** a database demora visivelmente para abrir, ou os valores das fórmulas aparecem em branco por um segundo antes de preencher. Nesse ponto, corte camadas.

---

## 9. Regras de higiene

1. **Uma fórmula, uma responsabilidade.** Se ela calcula progresso *e* formata *e* decide cor, quebre em duas: uma numérica (usável em rollup, sort e chart) e uma de apresentação.
2. **Sempre retorne o tipo mais útil.** Número é ordenável e agregável; texto não é. Boolean é filtrável como checkbox. Prefira número/boolean quando a fórmula alimenta views.
3. **`lets` sempre que uma expressão aparece duas vezes.**
4. **`ifs` a partir de dois níveis.**
5. **Nomes de opção codificados em texto são acoplamento.** Minimize.
6. **Sempre trate vazio** em Date, Person e Relation.
7. **Comente o "por quê" das regras de negócio**, especialmente limiares numéricos arbitrários.
8. **Se você precisa de mais de ~25 linhas**, pergunte se aquilo não são duas propriedades ou se não deveria ser uma automação gravando um valor.

---

## Leituras oficiais

- Intro a fórmulas: <https://www.notion.com/help/formulas>
- Sintaxe e funções (referência canônica): <https://www.notion.com/help/formula-syntax>
- Formulas 2.0, o que mudou: <https://www.notion.com/help/guides/new-formulas-whats-changed>
- Escrevendo fórmulas que estendem databases: <https://www.notion.com/help/guides/write-formulas-that-extend-capabilities-of-databases>
- Erros comuns de fórmula: <https://www.notion.com/help/common-formula-errors>
- Categoria Fórmulas: <https://www.notion.com/help/category/formulas>
- Relations e rollups: <https://www.notion.com/help/relations-and-rollups>
- Automations de database: <https://www.notion.com/help/database-automations>
