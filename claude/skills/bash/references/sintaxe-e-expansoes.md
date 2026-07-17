# Sintaxe e Expansões

Quoting e expansões são a base semântica do Bash: quase todo bug clássico de shell é uma expansão que aconteceu na hora errada ou um valor que passou por word splitting sem aspas. Este arquivo cobre os quatro mecanismos de quoting, a ordem das expansões e por que ela explica bugs reais, expansão de parâmetros completa, command substitution, aritmética, process substitution, IFS/word splitting e globbing.

## Quoting

Existem quatro mecanismos: backslash, aspas simples, aspas duplas e dollar-single-quotes.

**Backslash** (`\`) preserva o valor literal do próximo caractere. A exceção é `\newline`, que é continuação de linha — o par some do input.

**Aspas simples** (`'...'`) preservam tudo literalmente. Não existe escape dentro delas: uma aspa simples não pode aparecer entre aspas simples, nem precedida de backslash. Para embutir uma, feche e reabra: `'don'\''t'`.

**Aspas duplas** (`"..."`) preservam tudo **exceto** `$`, `` ` ``, `\` e, com history expansion ligada, `!`. O detalhe que morde: dentro de aspas duplas, o backslash só é especial quando seguido de `$`, `` ` ``, `"`, `\` ou newline. Nos demais casos ele fica literal.

```bash
echo "a\tb"    # a\tb   — backslash preservado, \t não vira tab
echo "a\$b"    # a$b    — backslash consumido, $ literal
echo $'a\tb'   # a<TAB>b
```

**`$'...'`** (ANSI-C quoting) expande escapes no padrão C: `\n \t \r \a \b \e \f \v \\ \' \" \?`, `\nnn` (octal), `\xHH` (hex), `\uHHHH` / `\UHHHHHHHH` (Unicode), `\cx` (control-x). O resultado é tratado como single-quoted. É a única forma sã de escrever um newline, tab ou delimitador de controle literal num valor.

**`$"..."`** faz tradução via gettext (`LC_MESSAGES`, `TEXTDOMAIN`, `TEXTDOMAINDIR`). Se o locale é C/POSIX ou não há tradução, o `$` é ignorado e a string vira double-quoted normal. Como é uma forma de double quoting, **a string traduzida continua sujeita a expansão** — o que é uma superfície de injeção se a tradução vier de arquivo externo. `shopt -s noexpand_translation` faz o resultado ser single-quoted. Fora de i18n de verdade, não use.

### Por que `"$var"` sem aspas é o bug nº 1

Uma expansão sem aspas passa por **word splitting** e depois por **pathname expansion**. As duas coisas são invisíveis até o dado ficar hostil:

```bash
f="my file.txt"
rm $f            # ERRADO: vira `rm my file.txt` — dois argumentos
rm "$f"          # certo

v="*"
echo $v          # ERRADO: glob expande para os arquivos do diretório
echo "$v"        # imprime *

n=$(wc -l < f)   # dígitos + espaços; sem aspas "funciona" por acidente
[ -n $n ]        # ERRADO: se n for vazio vira `[ -n ]`, que é verdadeiro
[ -n "$n" ]      # certo
```

Regra: **aspas duplas em toda expansão**, salvo quando você quer splitting/globbing deliberadamente. Os casos onde omitir é seguro (`$((...))`, lado direito de `=`, dentro de `[[ ]]`) são exceções que não valem o custo cognitivo de memorizar.

## A ordem das expansões

A ordem é fixa e explica quase todo comportamento surpreendente:

1. **Brace expansion**
2. **Tilde**, **parâmetro/variável**, **aritmética**, **command substitution**, **process substitution** — juntas, da esquerda para a direita
3. **Word splitting**
4. **Pathname expansion** (filename/globbing)
5. **Quote removal** (sempre por último)

Só brace expansion, word splitting e pathname expansion **aumentam o número de palavras**. As demais expandem uma palavra em uma palavra — as exceções sendo `"$@"`, `$*`, `"${arr[@]}"` e `${arr[*]}`.

Consequências práticas:

```bash
# Brace vem ANTES de parâmetro: variável em brace não funciona
n=3; echo {1..$n}          # imprime literalmente {1..3}
eval "echo {1..$n}"        # 1 2 3 — ou use seq/loop aritmético

# Brace vem antes de tilde e é puramente textual
echo {a,b}.txt             # a.txt b.txt (mesmo que não existam)

# Word splitting vem DEPOIS de command substitution:
# por isso a saída de um comando com espaços vira vários argumentos
files=$(ls); rm $files     # ERRADO por dois motivos (split + glob)

# Quote removal é o último passo, e remove apenas as aspas
# presentes na palavra ORIGINAL — não as que surgiram de outra expansão.
v="'quoted'"; echo $v      # 'quoted' — as aspas são dados, não sintaxe
```

Esse último ponto é o que derruba a tentativa de "montar um comando numa string e executar": aspas produzidas por expansão nunca são reinterpretadas como sintaxe. Use arrays (`cmd=(prog --flag "$arg"); "${cmd[@]}"`), não strings.

Glob acontece **depois** do split, então um valor com espaço *e* asterisco sofre as duas coisas em sequência.

## Brace expansion

Forma: preâmbulo + `{lista,separada,por,vírgula}` ou sequência `{x..y[..incr]}` + pós-escrito. É **estritamente textual** e roda antes de tudo; caracteres especiais para outras expansões são preservados no resultado. Não é ordenada — preserva a ordem da esquerda para a direita. Aceita aninhamento.

```bash
echo a{d,c,b}e             # ade ace abe  (NÃO ordena)
echo {1..10..3}            # 1 4 7 10
echo {01..03}              # 01 02 03  (zero-padding se x ou y começa com 0)
echo {a..e}                # a b c d e  (locale C)
cp file.conf{,.bak}        # cp file.conf file.conf.bak — idioma útil
mkdir -p proj/{src,test}/{a,b}
```

Uma brace malformada (sem vírgula ou sequência válida, ou sem chaves não-quotadas) fica **inalterada**, sem erro — `echo {abc}` imprime `{abc}`. `x` e `y` precisam ser do mesmo tipo (inteiro ou letra).

## Tilde expansion

`~` → `$HOME`; `~user` → home do usuário; `~+` → `$PWD`; `~-` → `$OLDPWD`. Só expande no **início de uma palavra** e sem aspas.

```bash
echo ~/tmp                 # /home/u/tmp
echo "~/tmp"               # ~/tmp — aspas matam a expansão
p=~/tmp                    # expande: tilde expande após = em assignment
p="~/tmp"                  # NÃO expande — armadilha comum
cd "$HOME/tmp"             # prefira $HOME quando precisar de aspas
```

## Expansão de parâmetros

`${var}` — as chaves são obrigatórias quando o nome é seguido de caractere que poderia fazer parte dele (`${x}_y`) ou para parâmetros posicionais acima de 9 (`${10}`).

| Operador | Efeito |
| --- | --- |
| `${var:-pad}` | usa `pad` se `var` unset **ou** vazio; não atribui |
| `${var-pad}` | idem, mas só se **unset** (vazio passa) |
| `${var:=pad}` | usa `pad` **e atribui** a `var` (falha em posicionais) |
| `${var:?msg}` | erro em stderr e sai se unset/vazio — guarda de contrato |
| `${var:+alt}` | usa `alt` **se** `var` tiver valor; senão vazio |
| `${#var}` | comprimento em caracteres; `${#arr[@]}` = nº de elementos |
| `${var:off:len}` | substring; `off`/`len` negativos contam do fim |
| `${var#pat}` | remove menor prefixo casando `pat` |
| `${var##pat}` | remove maior prefixo (idioma: basename) |
| `${var%pat}` | remove menor sufixo (idioma: tirar extensão) |
| `${var%%pat}` | remove maior sufixo |
| `${var/pat/rep}` | substitui **primeira** ocorrência |
| `${var//pat/rep}` | substitui **todas** |
| `${var/#pat/rep}` | só se casar no **início** |
| `${var/%pat/rep}` | só se casar no **fim** |
| `${var^pat}` / `${var^^pat}` | maiúscula: primeiro char / todos (bash 4+) |
| `${var,pat}` / `${var,,pat}` | minúscula: primeiro char / todos (bash 4+) |
| `${!prefix*}` / `${!prefix@}` | nomes de variáveis com o prefixo |
| `${!var}` | indireção: valor da variável **nomeada** por `var` |
| `${var@op}` | transformação (ver abaixo, bash 4.4+) |

O `:` distingue "unset" de "unset ou vazio" — em todos os quatro primeiros. É a diferença entre aceitar string vazia como valor legítimo ou não.

```bash
: "${CONFIG:?variável obrigatória não definida}"   # aborta cedo, mensagem clara
port=${PORT:-8080}                                  # default
${var:+--flag "$var"}                               # inclui a flag só se houver valor
```

Os padrões aqui são **globs**, não regex. `pat` casa contra a string inteira em `#`/`%` (ancorado na ponta) e em qualquer lugar em `/`.

```bash
p=/usr/local/bin/tool.tar.gz
echo "${p##*/}"      # tool.tar.gz  — basename
echo "${p%/*}"       # /usr/local/bin — dirname
echo "${p%.*}"       # ...tool.tar   — tira UMA extensão
echo "${p%%.*}"      # /usr/local/bin/tool — tira TODAS
echo "${p//\//-}"    # -usr-local-bin-... — barra precisa de escape
```

Offset negativo **precisa de espaço** depois do `:`, senão colide com `:-`:

```bash
s=abcdef
echo "${s: -3}"      # def
echo "${s:-3}"       # abcdef — isto é o operador de default!
```

Indireção e prefixos:

```bash
foo=bar; bar=baz
echo "${!foo}"       # baz — expande foo, depois usa "bar" como nome
echo "${!BASH_*}"    # lista nomes que começam com BASH_
```

### Transformações `${var@op}`

Operador é uma letra única: `U` (tudo maiúsculo), `u` (inicial maiúscula), `L` (tudo minúsculo), `Q` (valor quotado, reusável como input), `E` (expande escapes como `$'...'`), `P` (expande como prompt string), `A` (assignment/`declare` que recria a variável com atributos), `K` (chave-valor quotado, para arrays), `a` (flags dos atributos), `k` (como `K`, mas separa em palavras).

`@Q` é o jeito correto de gerar comando reutilizável — é a única forma segura de interpolar um valor em algo que será reavaliado (`eval`, `ssh`, `bash -c`):

```bash
arg="it's here; rm -rf /"
ssh host "ls ${arg@Q}"    # quotado corretamente na outra ponta
```

O resultado de `${var@op}` **sofre word splitting e pathname expansion** — continue usando aspas.

**Portabilidade:** `@op` exige bash 4.4+; `^^`/`,,` exigem bash 4.0+. O bash de sistema do macOS é **3.2.57** (licença GPLv3), então nada disso existe lá. Se o script tem shebang `#!/bin/bash` e roda em macOS, assuma 3.2 ou exija `#!/usr/bin/env bash` com um bash do Homebrew.

## Command substitution

`$(...)` executa em subshell e substitui pela stdout, **com os newlines finais removidos** (os embutidos ficam, mas podem sumir no word splitting depois). Sempre `$()`, nunca backticks:

- Em `` `...` ``, o backslash mantém sentido literal exceto antes de `$`, `` ` `` ou `\`; em `$()` **nada entre os parênteses é tratado especialmente**.
- Aninhar backticks exige escapar os internos (`` \` ``); `$()` aninha direto.

```bash
echo "$(dirname "$(readlink -f "$0")")"    # aspas aninham naturalmente
now=$(date +%s)
```

O strip de newlines finais é um recurso, não um bug — mas significa que `$(...)` **não preserva** trailing newlines de um arquivo. Para capturar bytes exatos, use `printf` com um sentinela ou leia num array.

`$(< file)` é equivalente a `$(cat file)` e mais rápido — o shell lê o arquivo direto, sem fork.

Se a substituição aparece **dentro de aspas duplas**, não há word splitting nem globbing no resultado. Fora delas, há os dois.

Bash 5.3 acrescenta `${ cmd; }` (funsub), que roda no **ambiente atual** — efeitos colaterais persistem, sem fork — e `${| cmd; }`, que expande para `REPLY`. Útil, mas assuma indisponível salvo se você controla a versão.

## Expansão aritmética

`$(( expr ))` avalia e substitui o resultado. `(( expr ))` avalia e descarta, retornando status 0 se o resultado for **não-zero** (invertido em relação à intuição de C). Os tokens sofrem expansão de parâmetro, command substitution e quote removal antes de avaliar — por isso `$` é opcional nos nomes.

```bash
i=5
echo $(( i * 2 ))    # 10 — sem $ em i
x=0; (( x++ )); echo $?   # 1 — pós-incremento devolve 0, status vira 1
y=5; (( y++ )); echo $?   # 0
```

Esse é um bug real: `(( x++ ))` avalia para o valor **pré**-incremento; quando `x` é 0 o status é 1, e sob `set -e` isso mata o script no primeiro item do contador. Use `(( x++ )) || true` ou `: $(( x++ ))`.

Bases: constantes com **`0` à esquerda são octais**, `0x` é hex, e `base#n` cobre bases de 2 a 64.

```bash
echo $(( 16#ff ))     # 255
echo $(( 2#1011 ))    # 11
echo $(( 08 ))        # ERRO: "value too great for base" — 08 é octal inválido
echo $(( 10#08 ))     # 8 — força base 10: essencial para datas/horas zero-padded
```

O `10#` é obrigatório ao fazer aritmética com saída de `date +%m` ou `%d`, que vem zero-padded.

Aritmética do Bash é **só inteiros**, com truncamento na divisão. Não há ponto flutuante:

```bash
echo $(( 7 / 2 ))                  # 3
echo "scale=4; 7/2" | bc           # 3.5000
awk 'BEGIN { printf "%.2f\n", 7/2 }'
```

Overflow é silencioso (wrap em 64 bits). Uma expressão inválida imprime erro em stderr, não substitui e **não executa o comando** associado.

## Process substitution

`<(list)` e `>(list)` expõem a saída/entrada de um processo como um nome de arquivo (via `/dev/fd` ou FIFO), rodando `list` assincronamente. **Nenhum espaço** entre `<`/`>` e o parêntese, senão vira redirecionamento.

```bash
diff <(sort a.txt) <(sort b.txt)      # sem arquivos temporários
while read -r l; do :; done < <(cmd)  # evita o subshell do pipe
```

O segundo é o idioma que importa: `cmd | while read` roda o loop num subshell, e variáveis atribuídas lá dentro se perdem. Com `< <(cmd)` o loop roda no shell atual. Detalhes de I/O ficam no arquivo de redirecionamentos.

## IFS e word splitting

O shell escaneia os resultados de **expansão de parâmetro, command substitution e aritmética que não ocorreram entre aspas duplas**. Palavras que não vieram de expansão **nunca são splitadas** — `echo a  b` já foi tokenizado antes.

Regras que importam:

- `IFS` **unset** se comporta como `<space><tab><newline>`. `IFS` **vazio** (`IFS=`) desliga o splitting.
- Espaço, tab e newline são sempre "IFS whitespace". Sequências deles no início e no fim são removidas antes do split, e qualquer sequência delimita **um** campo — campos nulos só surgem de quoting.
- Um caractere **não-whitespace** em `IFS` (ex.: `:`) delimita um campo sozinho, junto de qualquer whitespace adjacente. Dois deles adjacentes **produzem um campo nulo**. É por isso que `IFS=:` sobre `a::b` dá três campos, mas `IFS=' '` sobre `a  b` dá dois.
- Argumentos nulos explícitos (`""`, `''`) são preservados e passados como string vazia. Nulos implícitos (variável sem valor, sem aspas) são **removidos**.

```bash
IFS=: read -r user _ uid _ <<< "$line"    # IFS local ao read — não vaza

# Iterar linha a linha, preservando espaços:
old_IFS=$IFS
IFS=$'\n'
for line in $(cat f); do :; done
IFS=$old_IFS

# Melhor: nem mexa em IFS
while IFS= read -r line; do :; done < f   # IFS= preserva espaços das pontas
```

`IFS= read -r` é o idioma canônico: `IFS=` vazio impede o strip de whitespace nas pontas, `-r` impede o `read` de comer backslashes. Prefixar o `IFS=` no próprio comando o torna temporário — não precisa restaurar.

Para restaurar um IFS seguro do zero: `IFS=$' \t\n'` (sintaxe bash/ksh93, não portável para sh).

## Pathname expansion (globbing)

Após word splitting, e a menos que `set -f` esteja ativo, o Bash escaneia cada palavra por `*`, `?` e `[`. Se houver algum não-quotado, a palavra vira padrão e é substituída pela lista **ordenada** de arquivos que casam.

- `*` — qualquer string, inclusive vazia
- `?` — exatamente um caractere
- `[...]` — bracket expression, casa **um** caractere. `[!...]` ou `[^...]` nega. Para casar `-`, ponha primeiro ou por último; para `]`, primeiro. Ranges dependem de `LC_COLLATE` — `[a-z]` **não** é `[abc...z]` em locales não-C. Use classes POSIX (`[[:alpha:]]`, `[[:digit:]]`) ou `shopt -s globasciiranges`.

Ponto inicial (no começo do nome ou logo após `/`) precisa ser casado explicitamente, salvo com `dotglob`. Barra sempre casa só com barra literal.

**O comportamento default sem match é o mais perigoso:** a palavra fica **inalterada**, e o glob literal vira argumento.

```bash
for f in *.log; do        # se não há .log, f recebe a string "*.log"
  [ -e "$f" ] || continue # guarda obrigatória sem nullglob
done
```

| shopt | Efeito |
| --- | --- |
| `nullglob` | sem match → palavra **removida** (loop não itera) |
| `failglob` | sem match → **erro** e comando não executa |
| `dotglob` | inclui arquivos começando com `.` (nunca `.` e `..`) |
| `globskipdots` | `.` e `..` nunca casam, mesmo com padrão iniciado por `.` |
| `nocaseglob` | match sem distinguir maiúsculas |
| `globstar` | `**` recursivo |
| `extglob` | operadores de padrão estendido |

`nullglob` é o que você quer em loops; `failglob` é melhor em linha de comando. Cuidado: `nullglob` faz `cmd *.txt` virar `cmd` sem argumentos quando não há match, o que pode fazer o comando ler stdin.

`GLOBIGNORE` filtra matches — mas **setá-lo com valor não-nulo liga `dotglob` implicitamente**. Para manter o comportamento antigo, inclua `.*` entre os padrões.

Com `globstar`, `**` casa arquivos e zero ou mais diretórios recursivamente; `**/` casa só diretórios. Ele **segue symlinks de diretório**, o que pode gerar recursão explosiva.

```bash
shopt -s globstar
for f in **/*.ts; do :; done      # recursivo, sem find
```

### extglob

Com `shopt -s extglob`, onde `pattern-list` é um ou mais padrões separados por `|`:

| Forma | Casa |
| --- | --- |
| `?(lista)` | zero ou uma ocorrência |
| `*(lista)` | zero ou mais |
| `+(lista)` | uma ou mais |
| `@(lista)` | exatamente uma |
| `!(lista)` | qualquer coisa **exceto** |

```bash
shopt -s extglob
ls !(*.bak)                  # tudo menos backups
mv +([0-9]).log old/         # só nomes puramente numéricos
echo "${f%%+(.gz|.bz2)}"     # extglob vale em ${} também
```

**Armadilha de parsing:** `extglob` muda o **parser**, porque os parênteses normalmente são operadores sintáticos. Ele precisa estar ligado **antes** de o construto ser *parseado* — não antes de ser executado. Como uma função inteira é parseada de uma vez, um `shopt -s extglob` dentro dela não afeta os padrões da própria função. Ligue no topo do script, fora de qualquer função, ou isole com `eval`.

Fora de nomes de arquivo (`[[ ... == pat ]]`, `case`, `${var#pat}`), o `.` inicial e a `/` não têm tratamento especial. E `[[ $x == $pat ]]` faz **pattern match**, não comparação — quote o lado direito (`"$pat"`) se quiser igualdade literal.
