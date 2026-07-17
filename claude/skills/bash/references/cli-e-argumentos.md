# CLI e argumentos

Como transformar um script em uma ferramenta de linha de comando que se comporta como as outras ferramentas do sistema: parsing de argumentos, convenções de stdout/stderr/exit code, configuração em camadas e subcomandos. O foco está nas armadilhas — a maior parte dos bugs de CLI em shell vem de quoting errado em `"$@"`, de mensagens no stream errado e de `source` em arquivo de config.

## Parâmetros posicionais

`$0` é o nome com que o script foi invocado (caminho como digitado, não resolvido); `$1..$9` são os argumentos. A partir do décimo, **as chaves são obrigatórias**: `$10` expande como `$1` seguido do literal `0`, não como o décimo argumento. Sempre `${10}`.

```bash
$#            # quantidade de parâmetros posicionais
${0##*/}      # basename do programa, sem forkar um processo (prefira a basename $0)
${!#}         # último argumento (expansão indireta); ${@: -1} também serve
```

`$#` conta apenas os posicionais, não inclui `$0`.

### `"$@"` vs `"$*"` — a diferença exata

Sem aspas os dois são idênticos e igualmente quebrados (sofrem word splitting e globbing). Com aspas:

- `"$@"` expande para `"$1" "$2" ...` — **uma palavra por parâmetro**, preservando espaços internos.
- `"$*"` expande para `"$1c$2c..."` — **uma única palavra**, onde `c` é o primeiro caractere de `IFS` (espaço por padrão; se `IFS` for vazio, os parâmetros são concatenados sem separador).

```bash
set -- "arquivo com espaço.txt" "outro.txt"

for a in "$@"; do echo "[$a]"; done
# [arquivo com espaço.txt]
# [outro.txt]        -> 2 iterações

for a in "$*"; do echo "[$a]"; done
# [arquivo com espaço.txt outro.txt]   -> 1 iteração
```

Regra: **`"$@"` sempre**, exceto quando você quer deliberadamente uma string única para log/mensagem. `"$*"` é útil com `IFS` local para join:

```bash
join_by() { local IFS="$1"; shift; echo "$*"; }   # join_by , a b c -> a,b,c
```

Armadilha sutil: quando não há parâmetros, `"$@"` desaparece completamente (zero palavras), enquanto `"$*"` produz uma palavra vazia. Por isso `cmd "$@"` com argv vazio chama `cmd` sem argumentos, mas `cmd "$*"` chama `cmd ""`. Dentro de uma função, `"$@"` são os argumentos da função, não os do script — se precisar dos do script lá dentro, passe explicitamente.

### `shift` e `set --`

`shift [n]` descarta os `n` primeiros posicionais e renumera o resto. Sem argumento, `n=1`. Se `n > $#`, o shell **não altera nada** e retorna status não-zero — não confie em `shift` para detectar fim de lista sem checar `$#` antes; com `set -e` um `shift` a mais aborta o script.

`set -- a b c` reescreve argv inteiro. É o mecanismo canônico para normalizar argumentos antes de reprocessá-los, e `set --` sozinho limpa todos os posicionais. Cuidado: `set -- $var` sem aspas é sujeito a splitting/globbing — é justamente isso que se quer ao explodir uma string, e justamente o que arruína caminhos com espaço quando não se quer.

```bash
set -- "${@:2}"        # equivalente a shift, mas explícito
set -- "$@" "--extra"  # append no fim de argv
```

## `getopts` (builtin)

```
getopts optstring nome [arg ...]
```

`optstring` lista as letras aceitas; uma letra seguida de `:` exige argumento, que vai para `OPTARG`. `OPTIND` é o índice do próximo argumento a processar; começa em 1 e **o shell não reseta sozinho** — se você chamar `getopts` duas vezes na mesma invocação (ex.: numa função de subcomando), faça `local OPTIND=1` ou `OPTIND=1` antes, senão o segundo loop começa no meio.

Duas modalidades de erro. Sem `:` inicial no optstring, `getopts` imprime diagnósticos próprios em stderr (suprimíveis com `OPTERR=0`). Com **`:` como primeiro caractere** (silent mode), ele fica calado e:

- opção inválida → `nome=?` e `OPTARG` recebe a letra ofensora;
- argumento faltando → `nome=:` e `OPTARG` recebe a letra da opção.

Silent mode é o que você quer: sem ele, uma opção inválida também põe `?` em `nome` mas **apaga** `OPTARG`, e você perde a informação para a sua própria mensagem.

```bash
verbose=0 outfile=
while getopts ':vo:h' opt; do          # ':' inicial = silent
  case $opt in
    v) verbose=1 ;;
    o) outfile=$OPTARG ;;
    h) usage; exit 0 ;;
    :)  die 2 "opção -$OPTARG exige um argumento" ;;
    \?) die 2 "opção desconhecida: -$OPTARG" ;;
  esac
done
shift $((OPTIND - 1))                  # descarta as opções; sobram os operandos em "$@"
```

`getopts` já entende agrupamento (`-vo saida`), `-osaida` colado e `--` como fim das opções — de graça. O que ele **não faz é opção longa**: `--verbose` chega como um único argumento que ele não sabe decompor, e sem `:` inicial ele reclama de `-` como opção inválida. Não há workaround decente dentro do builtin (o truque de aceitar `-` e reparsear `OPTARG` é frágil e não trata `--key=value`).

## Loop manual para opções longas

Quando você precisa de `--long`, `--key=value` ou ambos, escreva o loop. É mais código, mas é portável e você controla tudo:

```bash
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)    usage; exit 0 ;;
    -V|--version) echo "${0##*/} $VERSION"; exit 0 ;;
    -v|--verbose) verbose=$((verbose + 1)); shift ;;
    -q|--quiet)   verbose=0; shift ;;
    -n|--dry-run) dry_run=1; shift ;;
    -o|--output)  [[ $# -ge 2 ]] || die 2 "$1 exige um argumento"
                  outfile=$2; shift 2 ;;
    --output=*)   outfile=${1#*=}; shift ;;      # forma --key=value
    --)           shift; break ;;                # tudo depois é operando
    -[!-]?*)      # agrupamento: -abc -> -a -b -c, reinjetado em argv
                  arg=$1; shift
                  set -- "${arg:0:2}" "-${arg:2}" "$@" ;;
    -*)           die 2 "opção desconhecida: $1" ;;
    *)            args+=("$1"); shift ;;         # operando intercalado
  esac
done
set -- "${args[@]}" "$@"                          # operandos antes + depois do --
```

Pontos que costumam ser esquecidos: `--` precisa terminar o parsing mesmo que venham coisas parecidas com opção depois; `--output=` (valor vazio) é válido e `${1#*=}` devolve string vazia, então valide; o caso de agrupamento acima só funciona para flags sem argumento — se `-o` puder ser agrupado, trate `-oVALOR` reinjetando `"${arg:2}"` como argumento separado. Se você não quiser suportar operandos intercalados, use `*) break ;;` e pare no primeiro não-opção (comportamento POSIX; GNU permuta).

## `getopt(1)` — quando e por quê não

O `getopt` **do util-linux** (GNU, `getopt --longoptions`) resolve opções longas de verdade, com permutação e normalização de argv:

```bash
parsed=$(getopt -o vo:h --long verbose,output:,help -n "${0##*/}" -- "$@") || exit 2
eval set -- "$parsed"     # o eval é necessário: getopt devolve a lista já com quoting
```

Problemas: (1) o `getopt` do macOS/BSD é a versão histórica, **sem `--long`, sem `-o`, e que quebra em argumentos com espaço** porque não faz quoting da saída — seu script funciona no CI Linux e falha no laptop do colega; (2) exige `eval`, que é uma superfície de erro a mais; (3) detectar a versão em runtime (`getopt -T; [[ $? -eq 4 ]]`) é possível mas você acaba mantendo dois caminhos de parsing.

Recomendação prática: `getopts` quando só há opções curtas; loop manual quando há longas. `getopt(1)` só em script que declaradamente roda apenas em Linux com util-linux garantido — e ainda assim o ganho sobre o loop manual é pequeno.

## Convenções Unix que fazem o script parecer profissional

- **stdout é dado, stderr é conversa.** Tudo que outro programa pode querer consumir vai em stdout; progresso, avisos, erros e prompts vão em stderr. Um script que imprime "Processando..." em stdout inutiliza o próprio pipe.
- **`--help`/`-h` pedido explicitamente** → texto em **stdout**, exit **0** (é o resultado que o usuário pediu). **Uso errado** (opção inválida, argumento faltando) → mensagem curta em **stderr** e exit **2**, sem despejar o help inteiro. Confundir os dois quebra `meuscript --help | less` e mascara erros em scripts.
- **`--version`** imprime `nome versão` em stdout, exit 0.
- **Exit codes com significado**: 0 sucesso; 1 falha genérica; 2 erro de uso; e faixas próprias (3..63) para condições que o chamador queira distinguir. Documente-as no `--help`. `126`/`127`/`128+N` são do shell, não invente em cima.
- **Cor só se for para um humano**: `[[ -t 1 ]]` (stdout é tty) **e** `[[ -z ${NO_COLOR:-} ]]`. `NO_COLOR` respeita presença, não valor — `NO_COLOR=0` também desliga. Ofereça `--color=auto|always|never`.
- **`-` como argumento significa stdin/stdout**, por convenção (`cat -`, `tar -f -`). Trate `[[ $file == - ]]` explicitamente; não abra um arquivo chamado `-`.
- **Não seja interativo sem tty**: antes de qualquer prompt, cheque `[[ -t 0 ]]`. Em CI, stdin não é terminal, e um `read` pendurado vira timeout de pipeline.
- **`--dry-run`** deve percorrer exatamente o mesmo caminho de código e só trocar a execução por um log. Se o dry-run é um `if` separado, ele mente.
- **`-v`/`--verbose` acumulativo** (`-vv`) e `-q` para silenciar. Verbosidade vai em stderr.

### `usage()` e mensagens de erro

```bash
usage() {
  cat <<EOF
Uso: ${0##*/} [-v] [-o ARQUIVO] ORIGEM...
  -o, --output ARQUIVO   escreve em ARQUIVO ('-' = stdout)
  -v, --verbose          mais detalhe (repetível)
  -h, --help             esta ajuda
EOF
}
die() { local code=$1; shift; printf '%s: %s\n' "${0##*/}" "$*" >&2; exit "$code"; }
```

Use here-doc **sem aspas** no delimitador se quiser interpolar (`$VERSION`), e **com aspas** (`<<'EOF'`) para texto literal — sem aspas, um `$` ou crase no texto de ajuda é expandido e você vira alvo de erro bobo. Prefixar a mensagem com `${0##*/}` é o que permite achar o culpado quando o script roda dentro de um pipeline de dez comandos.

## Confirmação interativa e `--yes`

```bash
confirm() {
  [[ $assume_yes -eq 1 ]] && return 0
  [[ -t 0 ]] || die 2 "operação destrutiva requer confirmação; use --yes em modo não interativo"
  local ans
  read -r -p "$1 [y/N] " ans < /dev/tty || return 1
  [[ $ans == [yY] ]]
}
```

`read -r` sempre (sem `-r`, a barra invertida na resposta é interpretada). Ler de `/dev/tty` em vez de stdin permite confirmar mesmo quando o script está no meio de um pipe. E o caso não-interativo deve **falhar**, não assumir "sim" — assumir "não" também é ruim se o script prosseguir fingindo sucesso.

## Precedência de configuração

A ordem consagrada, do mais forte para o mais fraco: **flag > variável de ambiente > arquivo de config > default embutido**. Implementa-se de baixo para cima, deixando o parsing de opções por último:

```bash
outfile=${OUTFILE:-/dev/stdout}          # default, depois env
[[ -r $conf ]] && load_conf "$conf"      # config só sobrescreve o que env não fixou
# ... loop de opções ...                 # flag vence tudo
```

O erro clássico é ler a config depois do parsing e sobrescrever a flag. Use `${VAR:-default}` para env e mantenha uma variável "foi setado por flag" quando a lógica ficar ambígua. Prefixe as env vars com o nome da ferramenta (`MEUAPP_TIMEOUT`), nunca use nomes genéricos como `DEBUG` ou `TMPDIR` para semântica própria.

## Ler arquivo `.conf` com segurança

`source config` executa o arquivo: qualquer linha vira comando com os privilégios do script. Um `rm -rf /` ou um `$(curl ...)` no arquivo de config — editável por outro usuário, ou vindo do repo — é execução de código, não configuração. `source` só é aceitável quando o arquivo é comprovadamente confiável e você aceita que é código.

A alternativa é parsear apenas `chave=valor`, validando as chaves contra uma allowlist:

```bash
load_conf() {
  local key val
  while IFS='=' read -r key val; do
    key=${key%%[[:space:]]*}; key=${key##[[:space:]]}
    [[ -z $key || $key == \#* ]] && continue
    val=${val%\"}; val=${val#\"}                 # tira aspas opcionais
    case $key in
      timeout|outfile|color) printf -v "CONF_$key" '%s' "$val" ;;
      *) printf '%s: chave ignorada em %s: %s\n' "${0##*/}" "$1" "$key" >&2 ;;
    esac
  done < "$1"
}
```

`printf -v` atribui sem `eval` e sem `declare` dinâmico com string do usuário. Nunca faça `eval "$key=$val"`.

## Subcomandos (estilo `git`)

Duas abordagens. Dispatch por `case` é explícito e fácil de auditar. Dispatch por convenção `cmd_<nome>` é menos código e extensível:

```bash
cmd=${1:-help}; shift || true
if declare -F "cmd_$cmd" > /dev/null; then
  "cmd_$cmd" "$@"                # opções do subcomando são parseadas dentro dele
else
  die 2 "subcomando desconhecido: $cmd (veja ${0##*/} --help)"
fi
```

`declare -F` valida a existência da função — sem isso, `"cmd_$cmd" "$@"` com `cmd` vindo do usuário é injeção de nome de função/comando. As opções globais (`-v`, `--config`) devem ser parseadas **antes** do subcomando; as específicas, dentro da função (com `local OPTIND=1` se usar `getopts`). Se `$1` puder faltar, o `${1:-help}` acima evita `shift` com argv vazio sob `set -e`.

## Esqueleto copiável

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
VERSION=1.0.0
PROG=${0##*/}

usage() { cat <<EOF
Uso: $PROG [OPÇÕES] ARQUIVO...
  -o, --output ARQ   saída ('-' = stdout)   [\$MEUAPP_OUTPUT]
  -n, --dry-run      não altera nada
  -v, --verbose      repetível     -q, --quiet
  -y, --yes          assume sim    -h, --help    -V, --version
EOF
}
die()  { local c=$1; shift; printf '%s: %s\n' "$PROG" "$*" >&2; exit "$c"; }
log()  { (( verbose )) && printf '%s: %s\n' "$PROG" "$*" >&2; return 0; }

outfile=${MEUAPP_OUTPUT:--}   # default < env
verbose=0 dry_run=0 assume_yes=0
declare -a args=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)    usage; exit 0 ;;                       # help pedido: stdout, 0
    -V|--version) echo "$PROG $VERSION"; exit 0 ;;
    -v|--verbose) verbose=$((verbose+1)); shift ;;
    -q|--quiet)   verbose=0; shift ;;
    -n|--dry-run) dry_run=1; shift ;;
    -y|--yes)     assume_yes=1; shift ;;
    -o|--output)  [[ $# -ge 2 ]] || die 2 "$1 exige argumento"
                  outfile=$2; shift 2 ;;
    --output=*)   outfile=${1#*=}; shift ;;
    --)           shift; break ;;
    -*)           die 2 "opção desconhecida: $1" ;;      # uso errado: stderr, 2
    *)            args+=("$1"); shift ;;
  esac
done
set -- "${args[@]}" "$@"
[[ $# -gt 0 ]] || { usage >&2; die 2 "nenhum arquivo informado"; }

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then RED=$'\e[31m'; RST=$'\e[0m'; else RED= RST=; fi

for f; do                                   # 'for f' sem 'in' itera sobre "$@"
  [[ $f == - ]] && f=/dev/stdin             # '-' significa stdin
  [[ -r $f ]] || die 1 "${RED}ilegível${RST}: $f"
  log "processando $f"
  (( dry_run )) && { log "dry-run: pularia $f"; continue; }
  cat -- "$f"                               # '--' protege nomes iniciados por '-'
done > >(if [[ $outfile == - ]]; then cat; else cat > "$outfile"; fi)
```

## Completion básica

Para o próprio script, num arquivo carregado pelo `.bashrc` (ou em `/usr/share/bash-completion/completions/<nome>`):

```bash
complete -W '--help --version --verbose --dry-run --output' meuscript   # lista fixa
```

`-W` só serve para listas estáticas e não é contextual. Para completar por posição (subcomando no primeiro argumento, arquivos depois), use uma função com `-F`, lendo `COMP_WORDS`/`COMP_CWORD` e preenchendo `COMPREPLY` via `compgen`:

```bash
_meuscript() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  if (( COMP_CWORD == 1 )); then
    COMPREPLY=($(compgen -W 'build clean deploy' -- "$cur"))
  else
    COMPREPLY=($(compgen -f -- "$cur"))
  fi
}
complete -F _meuscript meuscript
```

`compgen -- "$cur"` com o `--` é obrigatório: sem ele, um `cur` começando com `-` é lido como opção do `compgen`.
