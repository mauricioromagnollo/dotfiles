# Estruturas e Dados

Tipos de dado do Bash (arrays indexados, arrays associativos, atributos de variável) e controle de fluxo (testes, condicionais, loops, funções, aritmética). O foco é nas armadilhas de expansão e escopo que quebram scripts em produção — não na sintaxe básica.

## Arrays indexados

Qualquer variável pode virar array indexado; `name[subscript]=value` cria um automaticamente. `declare -a` torna a intenção explícita. Índices são expressões aritméticas, base zero, e **não precisam ser contíguos** — arrays em Bash são esparsos.

```bash
declare -a files                    # explícito
files=(a.txt "b c.txt" d.txt)       # atribuição composta
files[10]="longe.txt"               # buraco entre 3 e 10: array esparso
files+=(e.txt)                      # append vira índice 11, NÃO 4
echo "${files[-1]}"                 # índice negativo: último elemento
```

### `"${arr[@]}"` vs `"${arr[*]}"` vs sem aspas

Esta é a diferença que mais quebra scripts. `@` e `*` só divergem **dentro de aspas duplas**:

```bash
arr=("um dois" "tres")

for x in "${arr[@]}"; do echo "[$x]"; done   # [um dois] [tres]   ← 2 palavras, correto
for x in "${arr[*]}"; do echo "[$x]"; done   # [um dois tres]     ← 1 palavra, junta por ${IFS:0:1}
for x in ${arr[@]};  do echo "[$x]"; done    # [um] [dois] [tres] ← word splitting destrói os elementos
```

Regra: **`"${arr[@]}"` sempre**, com aspas, exceto quando você quer explicitamente uma string única (`"${arr[*]}"` com `IFS` ajustado). Sem aspas, cada elemento sofre word splitting e glob expansion — um elemento `*.txt` vira a lista de arquivos do diretório.

Com array vazio, `"${arr[@]}"` expande para **nada** (zero palavras), não para uma string vazia. Isso é o que torna `cmd "${args[@]}"` seguro com `args` vazio, enquanto `cmd "$args_str"` passaria um argumento vazio.

### Tamanho, índices e slice

```bash
echo "${#arr[@]}"       # número de elementos SET (não o maior índice + 1)
echo "${#arr[3]}"       # comprimento em caracteres do elemento 3
echo "${!arr[@]}"       # os ÍNDICES atribuídos — essencial em array esparso
echo "${arr[@]:1:2}"    # slice: 2 elementos a partir da posição 1
```

Armadilha do array esparso: iterar com `for ((i=0; i<${#arr[@]}; i++))` está **errado** se houver buracos — `${#arr[@]}` conta elementos, não abrange o maior índice. Use `for i in "${!arr[@]}"`.

```bash
arr=(a b c); unset 'arr[1]'         # aspas: senão a[1] sofre pathname expansion
echo "${#arr[@]}"                   # 2
echo "${!arr[@]}"                   # 0 2  ← índice 1 sumiu, o array não "compacta"
for i in "${!arr[@]}"; do echo "$i=${arr[i]}"; done   # correto
```

Para recompactar: `arr=("${arr[@]}")`.

### Passar array para função

Arrays não são passados por valor. Duas formas corretas:

```bash
# 1. Expandir como argumentos (o array vira "$@" dentro da função)
processa() { local -a itens=("$@"); echo "${#itens[@]}"; }
processa "${files[@]}"

# 2. Passar o NOME e usar nameref (bash 4.3+) — preserva buracos e permite escrita
processa_ref() { local -n ref=$1; ref+=("novo"); echo "${#ref[@]}"; }
processa_ref files                  # o nome, sem $ e sem []
```

A forma 1 perde a distinção entre "array com um elemento vazio" e "array vazio" só se você esquecer as aspas. A forma 2 é a única que permite mutação in-place.

### `mapfile` / `readarray`

Ler linhas para um array sem loop e sem word splitting (bash 4+; `readarray` é sinônimo):

```bash
mapfile -t linhas < arquivo.txt              # -t remove o \n de cada elemento
mapfile -d '' arquivos < <(find . -print0)   # NUL-delimitado: seguro com qualquer nome
mapfile -t -n 100 primeiras < grande.log     # só as 100 primeiras linhas
```

Sem `-t` cada elemento carrega o newline. `mapfile` limpa o array antes de atribuir, salvo com `-O origin`.

## Arrays associativos

Exigem `declare -A` **antes** do primeiro uso — sem isso, o Bash trata a variável como array indexado e o subscript string é avaliado como expressão aritmética, resolvendo para `0`. Silenciosamente, todas as chaves colidem no índice 0.

```bash
# ERRADO
unset map; map[foo]=1; map[bar]=2
echo "${map[foo]}"      # 2 — "foo" e "bar" viraram índice aritmético 0

# CERTO
declare -A map
map[foo]=1; map["chave com espaço"]=2
map=([a]=1 [b]=2)                   # atribuição composta
map=(a 1 b 2)                       # bash 5.1+: pares chave/valor alternados
```

Chaves são strings arbitrárias (mas nunca a string vazia). Iteração e existência:

```bash
for k in "${!map[@]}"; do printf '%s -> %s\n' "$k" "${map[$k]}"; done
echo "${#map[@]}"                   # número de pares

[[ -v map[foo] ]] && echo "existe"          # correto, distingue "unset" de "vazio"
[[ -n "${map[foo]}" ]] && echo "não vazio"  # falso-negativo se o valor for ""
[[ ${map[foo]+x} ]] && echo "existe"        # alternativa pré-4.2
```

`-v map[foo]` não leva aspas no subscript dentro de `[[ ]]`. A ordem de iteração de `${!map[@]}` é a ordem do hash interno — **não é** inserção nem ordenação. Se precisar de ordem, `printf '%s\n' "${!map[@]}" | sort`.

`declare -A` dentro de função cria o array **local**. Para um mapa global preenchido de dentro de uma função, use `declare -gA`.

## O padrão do array como argv

Este é o motivo principal de arrays existirem em scripts. Montar comando dinamicamente em string e depois executar exige `eval` — que reinterpreta metacaracteres e é uma porta de injeção. Montar em array e expandir com `"${cmd[@]}"` passa cada elemento como um argumento exato, sem reparsing:

```bash
# ERRADO — quebra com espaços, e eval reinterpreta $, ;, `, glob
cmd="rsync -a"
[[ $dry_run == 1 ]] && cmd="$cmd --dry-run"
cmd="$cmd '$src' '$dst'"
eval "$cmd"

# CERTO — sem eval, sem reparsing, espaços preservados
cmd=(rsync -a)
[[ $dry_run == 1 ]] && cmd+=(--dry-run)
[[ -n $exclude ]] && cmd+=(--exclude="$exclude")
cmd+=("$src" "$dst")
"${cmd[@]}"                         # cada elemento = 1 argv, literal
```

Vale igualmente para prefixos (`runner=(); [[ $sudo == 1 ]] && runner=(sudo)`, depois `"${runner[@]}" "${cmd[@]}"`) e para logar o que será executado (`printf '%q ' "${cmd[@]}"`).

## `declare` / `local` / `readonly`

Atributos aplicam-se à variável e, em arrays, a todos os elementos.

```bash
declare -i contador=0       # integer: atribuição sofre avaliação aritmética
contador="3+4"              # contador == 7 (não a string "3+4")

declare -r VERSION=1.2.0    # readonly: assign e unset falham depois
readonly -a CONSTS=(a b)

declare -n ref=alvo         # nameref (4.3+): toda operação recai sobre "alvo"
declare -g CACHE=x          # cria/modifica no escopo GLOBAL mesmo dentro de função
declare -p map              # imprime declaração reutilizável — o melhor debug de array
```

`declare -i` é mais armadilha do que ajuda: atribuir string não-numérica dá `0` silenciosamente. Prefira `(( ))` no ponto de uso. `declare` dentro de função implica `local`, exceto com `-g`. `declare -n` não se aplica a arrays (a nameref não pode *ser* array), mas pode *referenciar* um.

### Escopo dinâmico

Bash usa escopo **dinâmico**, não léxico: uma função enxerga as variáveis locais de quem a chamou, e as `local` da função corrente sombreiam as de escopos anteriores para todas as funções chamadas a partir dela.

```bash
outer() { local x=1; inner; echo "outer x=$x"; }
inner() { echo "inner vê x=$x"; x=2; }      # enxerga e ESCREVE no local de outer
outer                                        # inner vê x=1 / outer x=2
```

Consequência prática: **toda** variável de função deve ser `local`, inclusive contadores de loop e `i`. Sem isso, uma função vaza estado para o global ou, pior, colide com o local do chamador em recursão. Note também que `local x=$(cmd)` mascara o exit status de `cmd` (o status vira o do `local`, que é 0) — declare e atribua em linhas separadas quando o status importa:

```bash
local out; out=$(cmd) || return    # correto
local out=$(cmd) || return         # o || nunca dispara
```

`BASH_REMATCH` é definido no escopo global; declará-la `local` produz resultados inesperados.

## Testes: `[[ ]]` vs `[ ]` vs `test`

`[` e `test` são builtins comuns: seus argumentos passam por word splitting e pathname expansion antes de serem avaliados. `[[ ]]` é uma palavra reservada, parseada pelo shell — **nada** dentro dele sofre splitting ou globbing.

```bash
f="dois arquivos.txt"
[ -f $f ]     # ERRO: "[: dois: binary operator expected"
[ -z $vazia ] # com vazia="" vira [ -z ], que é sempre true
[[ -f $f ]]   # OK mesmo sem aspas — [[ ]] não faz splitting
```

Em Bash, use `[[ ]]` **sempre**. Ganhos: sem word splitting, `&&`/`||` internos (em vez de `-a`/`-o`, obsoletos e ambíguos), `=~` para regex, `==` com pattern matching, `<`/`>` sem escape. Só use `[ ]` quando o script precisa rodar em `sh` POSIX.

### Operadores de arquivo

| Operador | Verdadeiro se |
|---|---|
| `-e file` | existe (qualquer tipo) |
| `-f file` | existe e é arquivo regular |
| `-d file` | existe e é diretório |
| `-r` / `-w` / `-x` | existe e é legível / gravável / executável |
| `-s file` | existe e tem tamanho > 0 |
| `-L file` (ou `-h`) | existe e é symlink (não segue o link) |
| `-p` / `-S` | FIFO / socket |
| `-t fd` | fd está aberto e é um terminal |
| `f1 -nt f2` | f1 mais novo que f2, ou f1 existe e f2 não |
| `f1 -ot f2` | f1 mais velho que f2, ou f2 existe e f1 não |
| `f1 -ef f2` | mesmo device e inode (hardlink ou mesmo caminho) |

Todos, exceto `-L`/`-h`, **seguem symlinks** e testam o alvo. Um symlink quebrado falha em `-e` e passa em `-L`.

### Operadores de string e numéricos

| String | Numérico | Significado |
|---|---|---|
| `-z s` | — | comprimento zero |
| `-n s` (ou só `s`) | — | comprimento não-zero |
| `s1 = s2` / `s1 == s2` | `a -eq b` | igual (em `[[ ]]`, `==` faz pattern match) |
| `s1 != s2` | `a -ne b` | diferente |
| `s1 < s2` | `a -lt b` | menor (string: lexicográfico) |
| `s1 > s2` | `a -gt b` | maior |
| — | `a -le b` / `a -ge b` | menor-igual / maior-igual |

Outros úteis: `-v nome` (variável está set, funciona com subscript de array), `-R nome` (é nameref), `-o optname` (shell option ligada).

`<` e `>` em `[[ ]]` ordenam lexicograficamente **na locale corrente**; `test` usa ordenação ASCII. Isso significa que `[[ a < B ]]` pode dar resultados diferentes conforme `LC_COLLATE`. Para ordenação estável, `LC_ALL=C`.

Comparação numérica em `[[ ]]` é `-eq`/`-lt`/etc. — usar `<` compara **strings**. Prefira `(( ))`, que aceita os operadores naturais e não tem essa ambiguidade:

```bash
[[ $a -gt $b ]]      # funciona
(( a > b ))          # melhor: legível, sem $, aritmética completa
[[ 10 < 9 ]]         # true! comparação de string — bug clássico
(( 10 < 9 ))         # false, correto
```

## Pattern matching e regex

Em `[[ $x == pat ]]` o lado direito é um **pattern glob**, não uma string — e citar o lado direito desliga o matching:

```bash
f="relatorio.txt"
[[ $f == *.txt ]]     && echo match     # glob: casa
[[ $f == "*.txt" ]]   && echo match     # aspas: compara literalmente, NÃO casa
[[ $f == $padrao ]]                     # $padrao expande e é tratado como pattern
[[ $f == "$padrao" ]]                   # compara literal com o conteúdo de $padrao
```

O lado esquerdo pode ficar sem aspas dentro de `[[ ]]`. O lado direito: sem aspas se você quer pattern, com aspas se quer literal. Essa é a decisão, e ela é explícita.

Regex com `=~` tem a mesma armadilha, agravada: **citar o regex torna tudo literal**.

```bash
[[ $v =~ ^[0-9]+\.[0-9]+$ ]]        # regex de verdade
[[ $v =~ "^[0-9]+\.[0-9]+$" ]]      # ERRADO: casa a string literal com ^ e [ dentro

# Padrão recomendado: guardar o regex em variável SEM aspas na expansão
re='^([0-9]+)\.([0-9]+)\.([0-9]+)$'
if [[ $v =~ $re ]]; then
  major=${BASH_REMATCH[1]}; minor=${BASH_REMATCH[2]}; patch=${BASH_REMATCH[3]}
fi
```

`BASH_REMATCH[0]` é o match inteiro; índices 1..n são os grupos parentizados. É sobrescrito a cada `=~` bem-sucedido — copie os valores antes de outro teste. Como o Bash a define no escopo global, **nunca** declare `local BASH_REMATCH`.

Dentro de `[[ ]]` o regex passa por expansões do shell antes de chegar ao motor de regex: `[[ . =~ $pattern ]]` com `pattern='\.'` casa; `[[ . =~ "$pattern" ]]` não, porque o backslash chega escapado ao parser.

## Fluxo de controle

### `if` / `elif`

A condição é um **comando**, não uma expressão: `if grep -q foo f; then`. Exit status 0 é verdadeiro. Não escreva `if [[ $(cmd) == "ok" ]]` quando `if cmd; then` basta.

### `case`

Mais rápido e mais legível que cadeias de `[[ ]]` para despacho por padrão. Cada cláusula termina com `;;`, `;&` ou `;;&`:

```bash
case "$arg" in
  -h|--help)  uso; exit 0 ;;         # ;;  encerra o case
  --verbose)  v=1 ;;
  -*)         echo "flag desconhecida: $arg" >&2; exit 2 ;;
  *.tar.gz)   extrai_tar "$arg" ;;
  *)          arquivos+=("$arg") ;;  # '*' final = default
esac
```

- `;;` — encerra o `case` no primeiro match.
- `;&` — **cai** para a cláusula seguinte e executa seu corpo **sem testar** o pattern (fallthrough estilo C).
- `;;&` — continua **testando** as cláusulas seguintes e executa as que casarem (múltiplos matches).

O `word` do `case` sofre expansões antes do match; os patterns também. `shopt -s nocasematch` torna o match case-insensitive.

### `for`

```bash
for f in *.log; do ... done                  # glob; se nada casar, o literal "*.log" entra no loop
shopt -s nullglob                            # ...a menos que nullglob esteja ligado: 0 iterações

for x in "${arr[@]}"; do ... done            # array: sempre com aspas
for arg; do ... done                         # sem 'in': itera "$@" implicitamente
for ((i = 0; i < n; i++)); do ... done       # forma C, aritmética, sem $
```

`for f in $(ls)` é errado por dois motivos independentes: word splitting nos nomes com espaço e reinterpretação de globs. Use `for f in *` ou `mapfile -d '' < <(find ... -print0)`.

`break N` / `continue N` operam no N-ésimo loop **envolvente** (contando de dentro para fora), não no N-ésimo iterador.

### `while` / `until` / `select`

`while` roda enquanto o teste retorna 0; `until` enquanto retorna não-zero. `select` gera menu numerado em stderr, usa `PS3` como prompt, põe a linha lida em `REPLY` e só termina com `break` (ou EOF, retornando 1).

## `while read` corretamente

A forma canônica, e o porquê de cada parte:

```bash
while IFS= read -r line; do
  printf '%s\n' "$line"
done < arquivo.txt
```

- `IFS=` (vazio, só para este comando) impede que `read` remova espaços/tabs no início e fim da linha.
- `-r` impede que `read` interprete `\` como escape — sem ele, `C:\novo` perde a barra e `\` no fim junta linhas.
- Redirecionamento `< arquivo` em vez de pipe: mantém o loop no shell corrente.

### Última linha sem newline

`read` retorna status não-zero ao encontrar EOF sem delimitador — mas **já atribuiu** a variável. O loop acima descarta silenciosamente a última linha se o arquivo não terminar em `\n`:

```bash
while IFS= read -r line || [[ -n $line ]]; do   # processa o resto parcial
  ...
done < arquivo.txt
```

### O subshell do pipe

Cada comando de um pipeline multi-comando roda no seu próprio subshell. O loop à direita de um `|` é um processo separado: variáveis modificadas nele **não sobrevivem**.

```bash
# ERRADO — total sempre 0
total=0
cat nums.txt | while read -r n; do (( total += n )); done
echo "$total"        # 0: o loop rodou em subshell

# CERTO 1 — redirecionamento (também elimina o cat inútil)
total=0
while read -r n; do (( total += n )); done < nums.txt

# CERTO 2 — process substitution, quando a fonte é um comando
total=0
while read -r n; do (( total += n )); done < <(gerar_numeros)

# CERTO 3 — lastpipe: roda o ÚLTIMO comando do pipe no shell corrente
shopt -s lastpipe; set +m                # exige job control desligado (padrão em scripts)
gerar_numeros | while read -r n; do (( total += n )); done
```

`lastpipe` só tem efeito com job control inativo — em shell interativo não funciona sem `set +m`. Process substitution é a saída mais portátil e legível.

Armadilha adicional: comandos dentro do loop que consomem stdin (`ssh`, `ffmpeg`, `mysql`) engolem o resto do arquivo — passe `</dev/null` a eles, ou leia num FD alternativo: `while IFS= read -r line <&3; do ...; done 3< arquivo`.

## Funções

```bash
minha_func() {                # forma preferida; 'function nome' é bashismo dispensável
  local arg1=$1 arg2=${2:-padrao}
  local -a itens=()
  (( $# >= 1 )) || { echo "uso: minha_func ARG" >&2; return 2; }
  ...
  return 0
}
```

Funções rodam no shell corrente — sem fork. Variáveis são compartilhadas com o chamador a menos que sejam `local`. `return` sai da função; `exit` mata o shell inteiro — uma função de biblioteca **nunca** deve chamar `exit`. `return` sem argumento devolve o status do último comando; com argumento, um inteiro 0–255 (fora disso sofre módulo 256: `return 256` vira 0).

### Retornar valor

Três estratégias, com trade-offs:

```bash
# 1. stdout + command substitution — composável, mas custa um subshell e perde exit status
nome_upper() { printf '%s' "${1^^}"; }
v=$(nome_upper "abc")

# 2. variável global convencionada — sem subshell, mas acopla e polui
REPLY=""
nome_upper() { REPLY=${1^^}; }
nome_upper "abc"; echo "$REPLY"

# 3. nameref (4.3+) — o chamador escolhe o destino, sem subshell
nome_upper() { local -n _out=$1; _out=${2^^}; }
nome_upper resultado "abc"; echo "$resultado"
```

Armadilha do nameref: se o nome passado colidir com o do local do nameref, o Bash detecta referência circular e falha — prefixe os locais (`_out`, `__ref`). E `$(f)` remove **todos** os newlines finais; se a saída pode terminar em branco, use `v=$(f; printf x); v=${v%x}`.

### Argumentos

Dentro da função, `$1..$9` (e `${10}` em diante, com chaves obrigatórias) são os argumentos; `$0` **não** muda para o nome da função. `$#` é a contagem. `FUNCNAME` é um array: `${FUNCNAME[0]}` é a função corrente, `${FUNCNAME[1]}` o chamador — a pilha de chamadas.

`"$@"` expande cada posicional como palavra separada; `"$*"` junta tudo numa palavra usando o primeiro caractere de `IFS`. Repasse de argumentos é **sempre** `"$@"`:

```bash
wrapper() { comando_real --flag "$@"; }    # correto, preserva espaços e argumentos vazios
wrapper() { comando_real --flag $*; }      # quebra tudo com espaço
```

`shift [n]` descarta os n primeiros posicionais (padrão 1) e reindexa — a base do parser de flags:

```bash
while (( $# )); do
  case $1 in
    -o) saida=$2; shift 2 ;;
    -v) verbose=1; shift ;;
    --) shift; break ;;
    *)  break ;;
  esac
done
```

Recursão funciona, e é onde `local` deixa de ser estilo e vira correção — sem `local`, cada nível sobrescreve o estado do anterior. `FUNCNEST`, se > 0, limita a profundidade e aborta o comando ao estourar.

## Aritmética

`(( ))` avalia expressão aritmética C-like e devolve exit status **invertido**: resultado não-zero → status 0 (sucesso). Isso significa que `(( 0 ))` é falso e, sob `set -e`, `(( count++ ))` com `count=0` **aborta o script**:

```bash
(( count++ ))       # com count=0: retorna status 1 → set -e mata o script
(( ++count ))       # com count=0: avalia para 1 → status 0. Prefira pré-incremento
(( count++ )) || true   # ou neutralize explicitamente
```

Dentro de `(( ))` e `$(( ))`, variáveis são referenciadas **sem `$`** (o `$` é opcional e só atrapalha), e variável unset ou nula vale 0.

```bash
(( x = a * b + 1 ))               # atribuição; sem expansão de $
(( total += n ))
echo $(( (a + b) / 2 ))           # $(( )) expande para o VALOR
(( flag = x > 10 ? 1 : 0 ))       # ternário
echo $(( 2 ** 10 ))               # exponenciação: 1024
echo $(( 0x1f )) $(( 8#17 )) $(( 2#1011 ))   # hex, octal explícito, binário
```

Armadilha do zero à esquerda: constante com `0` inicial é **octal**. `$(( 08 ))` é erro de sintaxe — clássico ao fatiar datas (`mes=08`). Force base 10: `$(( 10#$mes ))`.

`let 'x = a + 1'` é equivalente mas exige quoting cuidadoso (`*`, `>` etc. seriam interpretados pelo shell). Não há razão para usar `let` em código novo.

Avaliação usa inteiros de largura fixa **sem checagem de overflow**; divisão por zero é erro. **Não existe ponto flutuante**: `$(( 7 / 2 ))` é 3, e `$(( 1.5 ))` é erro de sintaxe. Para float, delegue a `awk` ou `bc`:

```bash
media=$(awk -v s="$soma" -v n="$n" 'BEGIN{printf "%.2f", s/n}')
```

Para muitos casos, ponto fixo em inteiros basta e é mais confiável: trabalhe em centavos ou milissegundos e formate só na saída com `printf '%d.%03d'`.
