# Portabilidade e Armadilhas

Catálogo do que faz um script passar no seu laptop e explodir no CI, no container ou na máquina do colega. Duas frentes: **portabilidade** (o shell/coreutils do outro lado não é o seu) e **armadilhas** (a semântica do Bash não é a que você supôs). Para `set -e`, `pipefail`, `trap` e estrutura de script defensivo, veja `scripting-robusto.md`; aqui só aparecem os pontos onde esses mecanismos *falham silenciosamente*.

---

## Parte 1 — Portabilidade

### `sh` não é `bash`

`/bin/sh` é um contrato POSIX, não um caminho para o Bash. Em Debian/Ubuntu é `dash`; em Alpine é `busybox ash`; em macOS é `bash --posix` (3.2); em Solaris pode ser o Bourne de verdade. Um script com `#!/bin/sh` usando `[[ ]]`, arrays, `local`, `+=`, `${var/a/b}` ou `source` roda na sua máquina (onde `sh` é bash) e morre em produção com `Syntax error: "(" unexpected`. E, quando o Bash é invocado como `sh`, ele entra em modo POSIX depois de ler os startup files — mesmo *tendo* Bash, o comportamento muda.

Decisão binária, sem meio-termo:

- **Assuma Bash e declare**: `#!/usr/bin/env bash` (acha o Bash no `PATH`; em macOS, o do Homebrew antes do 3.2 do sistema). `#!/bin/bash` só se você controla a imagem — não existe `/bin/bash` em Alpine puro nem em FreeBSD.
- **Seja POSIX de verdade**: `#!/bin/sh`, e valide com `shellcheck -s sh` ou `dash -n`. Não basta "evitar `[[`".

Testar bashismos sem instalar dash: `checkbashisms script.sh` (pacote `devscripts`), ou `shellcheck -s sh`.

### macOS traz Bash 3.2

Por licença (Bash 4+ é GPLv3), a Apple congelou o `/bin/bash` em 3.2.57 (2007) e o shell padrão de login é o `zsh`. Se o script precisa rodar em macOS com o Bash do sistema, **nada abaixo existe**:

| Recurso | Versão mínima |
|---|---|
| `declare -A` (arrays associativos), `${x^^}`/`${x,,}`, `mapfile`/`readarray`, `&>>`, `\|&`, `coproc`, `case ... ;;&`, `globstar`/`**`, `$BASHPID` | 4.0 |
| `{fd}< file` (fd em variável), `BASH_XTRACEFD`, `printf -v arr[i]` | 4.1 |
| `declare -g`, `[[ -v var ]]` / `test -v`, `printf '%(%F)T'`, `lastpipe` | 4.2 |
| `declare -n` (nameref), `wait -n`, `[[ -v arr[i] ]]`, `BASH_COMPAT` | 4.3 |
| `${arr[@]}` vazio sem estourar `set -u`, `${var@Q}`/`@E`/`@P`/`@A`, `inherit_errexit` | 4.4 |
| `EPOCHSECONDS`, `EPOCHREALTIME`, `BASH_ARGV0`, `assoc_expand_once` | 5.0 |
| `SRANDOM`, `${var@K}`, `PROMPT_COMMAND` como array | 5.1 |
| `globskipdots`, `patsub_replacement`, `varredir_close` | 5.2 |

O Bash 5.x confirma isso pela via inversa: `BASH_COMPAT`/`shopt compatNN` só existem a partir do 4.0, e o próprio manual data mudanças como a colação locale-aware de `<`/`>` em `[[ ]]` (ASCII antes do 4.1, `strcoll(3)` depois) — o mesmo `[[ $a < $b ]]` ordena diferente em 3.2 e em 5.x.

**Falhe cedo, no topo do script**, em vez de quebrar no meio:

```bash
if (( BASH_VERSINFO[0] < 4 )); then
  printf 'requer bash >= 4 (atual: %s). Em macOS: brew install bash\n' "$BASH_VERSION" >&2
  exit 1
fi
```
`BASH_VERSINFO` é array: `[0]` major, `[1]` minor, `[2]` patch. Use `(( ))`; nunca compare `$BASH_VERSION` como string (`"5.2.15" < "4.4"` é verdadeiro lexicograficamente).

Para exigir 4.3+ (nameref, `wait -n`): `(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3) ))`. Alternativa ao `exit`: `[[ -x /opt/homebrew/bin/bash ]] && exec /opt/homebrew/bin/bash "$0" "$@"` — re-exec no Bash bom, se existir.

### GNU coreutils vs BSD (macOS)

O macOS traz utilitários BSD. Mesmos nomes, flags incompatíveis. Os reincidentes:

| Operação | GNU (Linux) | BSD (macOS) |
|---|---|---|
| edição in-place | `sed -i 's/a/b/' f` | `sed -i '' 's/a/b/' f` (o `''` é o sufixo de backup, obrigatório) |
| regex estendida | `sed -r` ou `-E` | só `-E` |
| data relativa | `date -d '3 days ago'` | `date -v-3d` |
| parse de data | `date -d "$s" +%s` | `date -j -f '%Y-%m-%d' "$s" +%s` |
| path canônico | `readlink -f p` | inexistente (use `greadlink -f` ou `python3 -c`) |
| metadados | `stat -c '%s %Y' f` | `stat -f '%z %m' f` |
| find com formato | `find . -printf '%p\n'` | inexistente (use `-exec` / `-print`) |
| PCRE | `grep -P '\d+'` | inexistente (use `grep -E '[0-9]+'`) |
| temp file | `mktemp -t pfx` (sufixo automático) | `mktemp -t pfx` (semântica diferente); portável: `mktemp "${TMPDIR:-/tmp}/pfx.XXXXXX"` |
| base64 linha única | `base64 -w0` | `base64` (já não quebra linha) |
| xargs vazio | `xargs -r cmd` (não roda se stdin vazio) | sem `-r`; roda uma vez com zero args |
| ordenação humana | `sort -h` | inexistente |
| `echo -e` | interpreta escapes | comportamento varia; **use `printf`** |

`sed -i` merece destaque: no macOS, `sed -i 's/a/b/' f` consome `s/a/b/` como sufixo de backup e falha pedindo expressão. E `sed -i '' -e 's/a/b/' f` quebra no GNU — o `''` vira um nome de arquivo. **Não existe invocação única.** Escolha uma estratégia:

1. **`gsed`/`gdate`/`gstat`** via `brew install coreutils gnu-sed`, e detecte:
   ```bash
   sed=sed; command -v gsed >/dev/null && sed=gsed
   "$sed" -i 's/a/b/' f
   ```
2. **Detectar em runtime** por capacidade, não por `uname`:
   ```bash
   if sed --version >/dev/null 2>&1; then       # GNU imprime versão; BSD erra
     sed_inplace() { sed -i "$@"; }
   else
     sed_inplace() { local e=$1; shift; sed -i '' "$e" "$@"; }
   fi
   ```
3. **Subconjunto comum**: temp + `mv`, e nunca precise de `-i`. Feio, roda em todo lugar, quase sempre a resposta certa.
   ```bash
   tmp=$(mktemp) && sed 's/a/b/' f > "$tmp" && mv "$tmp" f
   ```

`uname -s` como discriminante é frágil: Alpine é Linux mas tem BusyBox, não GNU — e ainda há WSL, Git Bash, containers. Detecte a *feature*, não o sistema.

### Modo POSIX

`set -o posix`, `bash --posix`, ou invocar o binário como `sh`. Não é "modo seguro" — é conformidade. O que muda e importa na prática:

- **Alias expansion sempre ligada**, inclusive em shell não-interativo.
- **Erro fatal mata o shell**: erro de sintaxe em expansão aritmética, erro de expansão de parâmetro, ou builtin especial POSIX (`:`, `.`, `eval`, `exec`, `exit`, `export`, `readonly`, `return`, `set`, `shift`, `trap`, `unset`) retornando erro → shell não-interativo **sai**. Fora do modo POSIX, apenas o comando falha.
- **Builtins especiais têm precedência sobre funções** na busca de comando (não dá mais para sobrescrever `exit` com uma função). Nomes de função não podem colidir com eles nem conter `/`.
- Redirecionamentos não fazem globbing nem word splitting no alvo; `~` no início de elementos do `PATH` não é expandido; substituições de comando não setam `$?`.
- `HISTFILE` vira `~/.sh_history`; `!` não faz history expansion dentro de aspas duplas.

Usar `set -o posix` para "testar portabilidade" é enganoso: o Bash em modo POSIX ainda tem arrays, `[[ ]]` e `local`. Só o `dash` te diz a verdade.

---

## Parte 2 — Catálogo de armadilhas

Formato: sintoma → errado/certo → causa em uma linha.

### Variável sem aspas

```bash
f="my file.txt"; rm $f          # errado: rm "my" "file.txt"
rm "$f"                         # certo
```
Word splitting por `IFS` + pathname expansion acontecem *depois* da expansão. Aspas duplas desligam ambos. Regra: **aspas sempre**, exceto quando você quer split ou glob de propósito.

### `[ $x = y ]` com `$x` vazio

```bash
x=""; [ $x = y ]                # errado: [ = y ] → "unary operator expected"
[ "$x" = y ]                    # certo (POSIX)
[[ $x == y ]]                   # certo (Bash: sem split/glob dentro de [[ )
```
`[` é um comando comum; a linha é montada por expansão antes de ele existir. `[[ ]]` é palavra reservada, parseada pelo shell.

### `$(cmd)` come newlines finais

```bash
v=$(printf 'a\n\n\n')           # v == "a"
v=$(cmd; printf x); v=${v%x}    # preserva os \n finais
```
Substituição de comando remove *todos* os newlines do fim. Importa em hashes, base64, conteúdo binário.

### `cmd | while read` — a variável some

```bash
count=0; find . -name '*.log' | while read -r f; do ((count++)); done
echo "$count"                                                    # 0
while read -r f; do ((count++)); done < <(find . -name '*.log')  # certo: process substitution
```
Cada lado do pipe roda em subshell; a atribuição morre com ela. Alternativa: `shopt -s lastpipe` (bash 4.2+, e só com job control desligado).

### `for f in $(ls)`

```bash
for f in $(ls); do rm "$f"; done              # errado: quebra em espaços/newlines
for f in ./*; do rm "$f"; done                # certo
find . -name '*.log' -print0 | xargs -0 rm    # certo, para árvores
```
Saída do `ls` não é um formato — é texto para humanos. Nome com espaço, newline ou `*` destrói tudo.

### `local x=$(falha)`

```bash
f() { local x=$(cmd_que_falha); echo "$?"; }   # 0 — status é do `local`
f() { local x; x=$(cmd_que_falha) || return; } # certo
```
`local`/`declare`/`export`/`readonly` são comandos: o exit status é deles, não da substituição. Isso também neutraliza `set -e`.

### `echo $var`

```bash
echo "$v"                       # se $v é "-n" ou "-e", vira flag; \t pode ser interpretado
printf '%s\n' "$v"              # certo, sempre
```
`echo` não é portável (BSD vs GNU vs builtin vs `xpg_echo`) e não tem `--` para encerrar flags. `printf` tem semântica definida.

### `rm -rf "$dir/$file"` com variável vazia

```bash
rm -rf "$dir/$file"             # dir e file vazios → rm -rf "/"
: "${dir:?dir não definido}"    # aborta com mensagem
rm -rf -- "${dir:?}/${file:?}"  # inline
```
`set -u` não pega variável *definida e vazia*. `${var:?msg}` pega.

### Aspas do lado direito de `==` desligam o glob

```bash
[[ $f == *.txt ]]               # glob: casa "a.txt"
[[ $f == "*.txt" ]]             # literal: casa só a string "*.txt"
pat='*.txt'; [[ $f == $pat ]]   # glob (variável não citada = padrão)
```
O inverso em `=~`: **cite** para tratar como literal.
```bash
[[ $s =~ $re ]]                 # $re como regex (correto)
[[ $s =~ "a.b" ]]               # "." literal — aspas anulam metacaracteres (bash 3.2+)
```
Sempre guarde a regex em variável e use `=~ $re` sem aspas.

### `$?` sobrescrito

```bash
cmd
echo "rodou"
if (( $? != 0 )); then ...      # errado: $? é do echo
```
```bash
cmd; rc=$?
echo "rodou"
if (( rc != 0 )); then ...
```
`$?` é do **último** comando executado — inclusive `echo`, `[`, `local`.

### Espaço na atribuição

```bash
x = 1                           # "x: command not found"
x=1                             # certo
x =1                            # roda `x` com argumento "=1"
```
Atribuição é reconhecida pelo parser só sem espaço em volta do `=`.

### `<` em `[[ ]]` é comparação de strings

```bash
[[ 10 < 9 ]] && echo sim        # imprime "sim" — ordem lexicográfica
(( 10 < 9 ))                    # falso, aritmético
[ 10 -lt 9 ]                    # falso, POSIX
```
Em `[[ ]]`, `<`/`>` comparam pela collation do locale (ASCII antes do bash 4.1). Para números: `-lt/-gt/-le/-ge` ou `(( ))`.

### `08` é octal

```bash
mes=08; (( mes + 1 ))           # "value too great for base"
(( 10#$mes + 1 ))               # 9
```
Em contexto aritmético, `0` inicial = octal, `0x` = hex. `10#` força base 10. Atinge meses, dias, horas, zero-padding em geral. `${mes#0}` também resolve, mas quebra em `"00"`.

### CRLF

```
$ ./script.sh
bad interpreter: /bin/bash^M: no such file or directory
```
O `\r` vira parte do path do interpretador. Com `#!/usr/bin/env bash`, o erro é o críptico `: No such file or directory`; com `#!/bin/bash -`, vira `: invalid option`. Pior: `\r` no meio do script quebra comparações sem erro óbvio. Diagnóstico: `file script.sh` → "with CRLF line terminators". Correção: `dos2unix` ou `sed -i 's/\r$//'`. Prevenção: `.gitattributes` com `*.sh text eol=lf`.

### `read` sem `-r`

```bash
read line                       # backslash vira escape: "C:\temp" → "C:temp"
IFS= read -r line               # certo: -r crua, IFS= preserva espaços nas bordas
```
Sem `-r`, `read` faz continuação de linha e remove `\`. Sem `IFS=`, corta espaço/tab do início e fim. **Sempre `IFS= read -r`.**

### `((i++))` retorna 1

```bash
set -e
i=0
((i++))                         # valor da expressão é 0 (pós-incremento) → status 1 → script morre
```
```bash
((i++)) || true                 # certo
i=$((i+1))                      # imune
```
`(( ))` retorna 0 se a expressão for **não-zero**, 1 se for zero. É aritmética C, não status Unix. Vale para `((flag = 0))`, `((count -= count))`, `let`, etc.

### `trap` que não roda

```bash
trap 'echo saindo' EXIT
trap 'cleanup' ERR              # ERR não é herdado por funções/subshells sem `set -E`
set -E                          # (errtrace) propaga ERR
set -T                          # (functrace) propaga DEBUG/RETURN
```
Outros modos de falha: `trap` definido **depois** do comando perigoso; `trap ... INT` não roda enquanto um comando externo em foreground segura o sinal; `kill -9` não é trapável. Dentro do handler de `EXIT`, um `exit 0` explícito **mascara a falha**:
```bash
cleanup() { rm -f "$tmp"; }         # certo: sem exit
cleanup() { rm -f "$tmp"; exit 0; } # errado: script sempre "passa"
```
Aspas: `trap "rm -f $tmp" EXIT` expande `$tmp` **agora**; `trap 'rm -f "$tmp"' EXIT` expande na hora do trap. Quase sempre você quer aspas simples.

### `sudo cmd > /root/f`

```bash
sudo echo texto > /root/f                  # "Permission denied" — o redirect é do SEU shell
echo texto | sudo tee /root/f > /dev/null  # certo
sudo sh -c 'echo texto > /root/f'          # certo
```
O shell abre os redirecionamentos antes de invocar `sudo`. `sudo` afeta o comando, não a plumbing.

### `cd` sem checar

```bash
cd "$d"; rm -rf ./*             # se cd falha, apaga o CWD atual
cd "$d" || { echo "falhou" >&2; exit 1; }     # certo
```
`cd` falho com `set -e` aborta — mas `cd "$d" && cmd`, ou `cd` dentro de `if`/`||`, não dispara `set -e`. Cheque explicitamente. Use `cd -- "$d"` se `$d` pode começar com `-`, e prefira subshell — `( cd "$d" && cmd )` não polui o CWD do resto.

### Alias em script

```bash
alias ll='ls -l'
ll                              # "ll: command not found"
shopt -s expand_aliases         # necessário em shell não-interativo
```
Aliases são expandidos no **parse**, não na execução: definir e usar um alias na mesma linha (ou na mesma função) não funciona nem com `expand_aliases`. Em script, use função.

### `[[ -n $x ]]` vs `[ -n $x ]`

```bash
x=""; [ -n $x ] && echo "não vazio"    # imprime! vira `[ -n ]`, teste de string "-n" → verdadeiro
[ -n "$x" ]                            # certo
[[ -n $x ]]                            # certo, aspas opcionais dentro de [[ ]]
```
`[[ ]]` não faz word splitting nem glob nas expansões, então variável sem aspas é segura — só ali.

### Glob sem match vira literal

```bash
for f in *.txt; do echo "$f"; done     # sem .txt algum → imprime "*.txt"
for f in *.txt; do [[ -e $f ]] || continue; echo "$f"; done   # guarda POSIX
shopt -s nullglob                      # padrão sem match → lista vazia (loop não roda)
shopt -s failglob                      # padrão sem match → erro de expansão
```
`nullglob` tem efeito colateral: `cmd *.txt` sem matches vira `cmd` sem argumentos (`ls *.foo` passa a listar o diretório inteiro). Ligue com escopo, não globalmente. Relacionado: `dotglob`, `globstar` (`**`, 4.0+), `nocaseglob`.

### Bônus recorrentes

- **`${arr[@]}` com `set -u` e array vazio** aborta em Bash < 4.4. Workaround: `"${arr[@]+"${arr[@]}"}"`.
- **`declare -A` em Bash 3.2** falha com `invalid option`. Se o script ignora esse erro (ou nunca declarou), `m[chave]=v` cria um array *indexado* e avalia `chave` como expressão aritmética: `m[foo]=v` e `m[bar]=w` gravam ambos em `m[0]` (nome não definido = 0). Silencioso e devastador.
- **`printf "$fmt"`** com `$fmt` vindo de fora = injeção de formato. Use `printf '%s' "$fmt"`.
- **`[ "$a" == "$b" ]`** funciona em Bash, mas `==` não é POSIX para `[` — em `dash`, erro. Use `=`.
- **`"$@"` vs `"$*"`**: o primeiro preserva argumentos; o segundo junta tudo numa string só, com o primeiro char de `IFS`.
- **`${#arr}`** é o tamanho de `arr[0]`, não do array. Use `${#arr[@]}`. E `function nome()` é bashismo; `nome() { ...; }` é POSIX.

---

## Parte 3 — Ferramentas

### `shellcheck`

Não é opcional. Rode em todo script, sempre, antes de commitar. Pega quase tudo da Parte 2 estaticamente.

```bash
shellcheck -s bash -S warning script.sh     # dialeto + severidade mínima
shellcheck -x script.sh                     # segue `source` de outros arquivos
shellcheck -f gcc script.sh                 # formato parseável para CI
```

Cada achado tem um código `SCxxxx` com página própria (`https://www.shellcheck.net/wiki/SC2086`). Os que você mais verá:

| Código | O quê |
|---|---|
| SC2086 | variável sem aspas (word splitting/glob) |
| SC2046 | `$(...)` sem aspas |
| SC2164 | `cd` sem `\|\| exit` |
| SC2155 | `local x=$(cmd)` mascara exit status |
| SC2181 | checou `$?` em vez de `if cmd; then` |
| SC2115 | `rm -rf "$a/$b"` com risco de vazio |
| SC2148 | falta shebang |
| SC2034 | variável atribuída e nunca usada |
| SC2154 | variável referenciada e nunca atribuída |
| SC1090/SC1091 | `source` de path dinâmico/não encontrado |
| SC2044 | `for` sobre `find` |
| SC2162 | `read` sem `-r` |

Silenciar exige justificativa **na linha acima**, com escopo mínimo (a diretiva vale para o próximo comando, ou para o arquivo se estiver antes do primeiro comando):

```bash
# shellcheck disable=SC2086  # $flags é intencionalmente splitado em argumentos
cmd $flags
```

`disable` no topo do arquivo desliga a regra no arquivo inteiro — quase nunca é o que você quer. Um `disable=SC2086` sem comentário explicando é dívida: para o próximo leitor, é indistinguível de "não entendi o aviso". Use `.shellcheckrc` na raiz do repo para dialeto e disables globais legítimos (`source-path=SCRIPTDIR`, `external-sources=true`).

Para portabilidade, o dialeto é o segredo: `shellcheck -s sh` (ou `# shellcheck shell=dash`) reclama de **todo** bashismo. É o teste barato de "isso é POSIX mesmo?".

### `shfmt`

Formatador. Elimina discussão de estilo e normaliza indentação — o que, na prática, expõe blocos mal aninhados. `shfmt -w -i 2 -ci -bn` no pre-commit; `shfmt -d .` (diff, falha se diferente) no CI. `shfmt -ln posix` valida o dialeto.

### `bash -n`

Checagem de sintaxe sem executar. Rápido, mas **fraco**: só pega erro de parse (`if` sem `fi`, aspas não fechadas), nada de semântica. Não substitui shellcheck.

```bash
bash -n script.sh
dash -n script.sh               # o teste de portabilidade que realmente conta
```
Cuidado: `bash -n` não detecta erros dentro de `eval` nem de strings, e um script sintaticamente válido pode ainda ser catastrófico. Pense nele como "compila" — não como "está correto".

Pipeline mínimo: `shfmt -d . && shellcheck -x ./**/*.sh`, mais um container com a versão **mínima** de Bash que você declara suportar. Se o README diz "Bash 4+", o CI precisa rodar em Bash 4 — senão a declaração é ficção.
