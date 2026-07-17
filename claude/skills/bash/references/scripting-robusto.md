# Scripting robusto em Bash

Como um script deixa de ser frágil. O foco aqui é o que o prólogo `set -euo pipefail` **não** faz, onde `set -e` silenciosamente não dispara, e os padrões de cleanup, exit code e segurança que sustentam um script em produção. Assume Bash 4+; diferenças relevantes de versão estão marcadas.

## O prólogo, linha por linha

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
```

**`#!/usr/bin/env bash` vs `#!/bin/bash`.** Em macOS, `/bin/bash` é 3.2 (licença GPLv3), sem `declare -A`, sem `${var^^}`, sem `mapfile` confiável, sem `inherit_errexit`. `env bash` resolve pelo `PATH` e pega o Homebrew bash 5. O custo: em script privilegiado, resolver pelo `PATH` é exatamente o que você não quer (veja "PATH explícito"). Regra prática: `env bash` para ferramentas de dev; `/bin/bash` com caminho absoluto para scripts rodados por root/cron/systemd. Shebang não aceita múltiplos argumentos de forma portável — `#!/usr/bin/env bash -e` é lixo em vários kernels; ponha `set -e` no corpo.

**`set -e` (errexit).** Sai se um pipeline retornar status não-zero. É a opção mais mal compreendida do Bash; a seção seguinte é dedicada só a ela.

**`set -u` (nounset).** Referenciar variável não definida vira erro fatal em vez de expandir para string vazia. Pega typo em nome de variável — o modo de falha mais comum e mais silencioso do shell.

**`set -o pipefail`.** Sem ele, o status de um pipeline é o do **último** comando. `curl ... | tar -x` retorna 0 mesmo se o `curl` morreu no meio.

**`IFS=$'\n\t'`.** Tira o espaço do separador de word splitting. Faz `for x in $var` não quebrar em espaços — mas isso é remendo. A solução real é **citar tudo** e usar arrays; com aspas corretas o `IFS` custom é irrelevante. Pior: `IFS` custom quebra código de terceiros que você faz `source`, e quebra `read` que espera espaço. Se você cita corretamente, prefira **não** mexer no `IFS` globalmente; ajuste-o localmente onde precisar (`IFS=, read -ra parts <<<"$csv"`).

## `set -e`: onde ele NÃO dispara

O manual é explícito: o shell **não** sai se o comando que falha for parte da lista imediatamente após `while`/`until`, parte do teste de um `if`, parte de qualquer comando em lista `&&`/`||` **exceto o último**, qualquer comando do pipeline exceto o último (sujeito a `pipefail`), ou se o status estiver sendo invertido com `!`.

```bash
set -e

if grep -q foo arquivo; then ...; fi   # grep falha -> NÃO sai (é o teste)
falha && echo ok                        # NÃO sai (não é o último da lista)
echo ok && falha                        # SAI (é o último)
! falha                                 # NÃO sai (status invertido)
falha | cat                             # sem pipefail: NÃO sai
while falha; do :; done                 # NÃO sai
```

**A armadilha do "contexto onde -e é ignorado" é herdada.** Se uma função é chamada em contexto de teste, `-e` fica desligado **dentro de todo o corpo dela**, mesmo que ela própria faça `set -e`:

```bash
deploy() {
  set -e                # não tem efeito nenhum aqui
  rm /nao/existe        # falha
  echo "DESTRUIU TUDO"  # e continua executando
}
if deploy; then echo "sucesso"; fi   # imprime as duas linhas
```

Isto vale para `deploy && x`, `! deploy`, `until deploy`, `deploy || fallback`. O `|| fallback` é o caso perigoso do dia a dia: `install_deps || die "falhou"` desliga o errexit **dentro** de `install_deps`, então ela roda até o fim e o `die` só dispara se o **último** comando dela falhar.

**Errexit não é herdado por substituição de comando.** Fora de modo posix, o Bash **limpa** `-e` em subshells de command substitution:

```bash
set -e
x=$(false; echo "ainda rodo")   # não sai; x="ainda rodo"
shopt -s inherit_errexit         # bash 4.4+: subshell de $( ) herda -e
```

**Atribuição mascara o status.** O status de `local x=$(cmd)` é o status do `local`, não do `cmd` — sempre 0:

```bash
# errado: falha silenciosa
local ver=$(comando_inexistente)   # $? == 0, ver vazio

# certo: declare e atribua separado
local ver
ver=$(comando_inexistente)         # agora $? é do comando; -e dispara
```

Vale para `local`, `declare`, `export`, `readonly`. É o bug mais comum em código que "usa strict mode".

**`set -E` (errtrace).** Sem ele, o trap `ERR` **não** é herdado por funções, substituições de comando e subshells. Com `set -euo pipefail` mas sem `-E`, seu `trap ... ERR` não roda dentro de nenhuma função. Se você usa trap `ERR`, use `set -Eeuo pipefail`. (`set -T`/functrace faz o mesmo para `DEBUG` e `RETURN`.)

**Conclusão operacional:** `set -e` é uma rede de segurança para o caso que você esqueceu, nunca o mecanismo de tratamento de erro. Comandos cujo erro importa devem ser checados explicitamente.

## `set -u` e o buraco do array vazio

Em Bash **< 4.4**, expandir array vazio com `-u` é erro fatal, mesmo citado:

```bash
set -u
args=()
cmd "${args[@]}"      # bash 4.3 e 3.2 (macOS): "args[@]: unbound variable"
cmd "${args[@]:-}"    # workaround, mas injeta um argumento vazio ""
```

O workaround correto para 3.2/4.3 é o guard explícito:

```bash
(( ${#args[@]} )) && cmd "${args[@]}" || cmd
```

Em 4.4+ `"${arr[@]}"` de array vazio expande para nada e não erra. `$@` vazio nunca foi erro em nenhuma versão.

O escape genérico para variável opcional é `${var:-}` (default vazio) — mas use com parcimônia: sair espalhando `${x:-}` desliga exatamente a proteção que você pediu. Prefira inicializar (`declare x=""`) ou testar com `${x+set}`:

```bash
if [[ -n ${DEBUG+set} ]]; then ...; fi   # "DEBUG foi definida?", sem violar -u
```

`-u` também não protege contra typo em **atribuição** (`retires=5` cria variável nova, feliz), nem dentro de `[[ -z $tipo ]]` quando `tipo` é array associativo mal indexado.

## `pipefail` e `PIPESTATUS`

`pipefail` faz o pipeline retornar o status do último comando **não-zero** (o mais à direita que falhou), ou 0 se todos passaram. Custo: combina mal com consumidores que fecham cedo — `cmd | head -1` faz `cmd` morrer com SIGPIPE (141) e o pipeline passa a falhar. Isso é ruído, não bug seu.

`PIPESTATUS` é um array com o status de cada estágio do pipeline mais recente. É **volátil**: qualquer comando seguinte o sobrescreve, inclusive o `echo` que você usaria para inspecioná-lo.

```bash
set -o pipefail
tar -cf - dir | gzip > out.tgz
rc=("${PIPESTATUS[@]}")     # capture na PRIMEIRA linha após o pipeline
(( rc[0] == 0 )) || die "tar falhou (${rc[0]})"
(( rc[1] == 0 )) || die "gzip falhou (${rc[1]})"
```

## Exit codes

- `0` sucesso; `1` erro genérico; `2` uso incorreto (convenção herdada de `getopt`/BSD).
- `126` comando encontrado mas não executável (permissão, ou é diretório).
- `127` comando não encontrado — o clássico `command not found` (e o típico erro de `PATH`).
- `128+N` terminado pelo sinal N: `130` = SIGINT (Ctrl-C), `137` = SIGKILL, `143` = SIGTERM, `141` = SIGPIPE.
- `> 128` também é o que `wait` e `read -t` retornam ao serem interrompidos por sinal.

Reserve 3–125 para seus erros de domínio e documente-os. Não retorne 0 em caminho de erro só para "não sujar" o CI. `$?` é o status do último comando concluído — leia-o **imediatamente**, ele é sobrescrito por tudo, inclusive por um `[[ ]]`.

## `trap`

```bash
trap 'ação' SIGSPEC...
```

- `EXIT` (ou `0`): roda quando o shell sai, por qualquer motivo — inclusive por `set -e` e por sinal tratado. É onde o cleanup vive.
- `ERR`: roda quando um pipeline retorna não-zero, **sob exatamente as mesmas exceções do `set -e`** (`if`, `while`, `&&`/`||`, `!`, não-último do pipe). Não é catch. Requer `set -E` para valer dentro de funções/subshells.
- `INT`/`TERM`: interrupção do usuário e pedido de término. Trate-os para propagar corretamente (veja abaixo).
- `DEBUG`: antes de **cada** comando simples, `for`, `case`, `select`, `((`, `[[`. Base de tracing/profiling caseiro.
- `RETURN`: ao fim de cada função ou `source`. Requer `set -T` para herdar.

Traps **não** são herdados por subshells: "trapped signals that are not being ignored are reset to their original values in a subshell". Sinais **ignorados** (`trap '' TERM`) *são* herdados como ignorados — inclusive por processos filhos externos, o que costuma ser surpresa.

### Temporário + cleanup idempotente

```bash
tmpdir=""
cleanup() {
  local rc=$?
  [[ -n $tmpdir && -d $tmpdir ]] && rm -rf -- "$tmpdir"
  tmpdir=""                 # idempotente: segunda chamada não faz nada
  return $rc                # preserva o exit code original
}
trap cleanup EXIT
tmpdir=$(mktemp -d)         # NUNCA /tmp/meu.$$ — $$ é previsível
```

O cleanup precisa ser idempotente porque `EXIT` pode rodar depois de `INT` que já rodou o seu handler. E precisa tolerar estado parcial: ele roda mesmo se o script morreu na linha 3, antes de metade das variáveis existirem — daí o `tmpdir=""` inicial (obrigatório sob `set -u`).

### Propagando sinal corretamente

```bash
on_int() {
  trap - INT          # restaura default
  cleanup
  kill -INT "$$"      # morre "de verdade" com 130; pais veem sinal, não exit 1
}
trap on_int INT
```

Sair com `exit 1` de um handler de `INT` mente para o processo pai sobre a causa da morte. Se o script roda em foreground sem job control, o Ctrl-C do terminal vai para **todo o process group** — seu filho já recebeu o SIGINT antes de você.

Se o Bash está esperando um comando terminar e chega um sinal com trap, **o trap só roda quando o comando termina**. `trap ... TERM` não interrompe um `sleep 300` em foreground. Padrão para responsividade: `cmd & wait $!` — `wait` é interrompível.

## Padrões de erro

```bash
readonly PROGNAME=${0##*/}

err()  { printf '%s: %s\n' "$PROGNAME" "$*" >&2; }
die()  { err "$*"; exit "${_rc:-1}"; }

need() { command -v "$1" >/dev/null 2>&1 || die "dependência ausente: $1"; }
```

Mensagem de erro em **stderr**, sempre — quem faz `x=$(seu_script)` não pode receber o erro no stdout. `printf` em vez de `echo`: `echo` não é portável para argumentos com `-n`/`-e` nem com barras invertidas.

`command -v` é o certo para checar dependência: builtin, portável POSIX, não depende de `/usr/bin/which` (que existe? retorna o quê? varia por distro). Retorna 127-ish se não achar.

Valide cedo, no topo do `main`, antes de qualquer efeito colateral:

```bash
main() {
  need jq; need curl
  (( $# == 2 )) || { usage >&2; exit 2; }
  local src=$1 dst=$2
  [[ -r $src ]] || die "não legível: $src"
  [[ -d ${dst%/*} ]] || die "diretório destino inexistente: ${dst%/*}"
  ...
}
```

## Idempotência, dry-run e checagem de sintaxe

Um script que pode rodar duas vezes sem estragar nada é um script que pode ser reexecutado depois de uma falha no meio. Use `mkdir -p`, `ln -sfn`, `rm -f`, `grep -q ... || echo >> file`; teste estado antes de mutar em vez de assumir estado inicial.

```bash
DRY_RUN=${DRY_RUN:-0}
run() {
  if (( DRY_RUN )); then
    printf '[dry-run]'; printf ' %q' "$@"; printf '\n'
    return 0
  fi
  "$@"
}
run rm -rf -- "$target"
```

O `%q` é o detalhe que importa: imprime a forma **citada e reexecutável**, então o que você lê no dry-run é o que rodaria de fato. Passe os comandos como array (`"$@"`), nunca como string a ser reavaliada.

`bash -n script.sh` (noexec) lê sem executar: pega erro de sintaxe, `fi`/`done` faltando, aspas não fechadas. É lint de sintaxe, não de lógica — `bash -n` não vê `rm -rf /$vazio`. Complemente com `shellcheck`. `bash -x` (xtrace) para debug; `PS4='+${BASH_SOURCE##*/}:${LINENO}: '` deixa o trace legível.

## Segurança prática

**Variável não citada é injeção.** Word splitting + glob acontecem *depois* da expansão:

```bash
f='meu arquivo.txt'
rm $f          # tenta remover "meu" e "arquivo.txt"
rm "$f"        # certo

grep $padrao *.log      # padrao='-r /' vira flag; * vira o que estiver no dir
grep -e "$padrao" -- *.log   # -e ancora o padrão, -- encerra as opções
```

Regra: **cite toda expansão**, use `--` antes de operandos que vêm de variável, e prefira `printf '%s'` a `echo`.

**Diretório vazio + `rm -rf`.** `rm -rf "$dir/"` com `dir=""` vira `rm -rf /`. As aspas não salvam — o problema é o valor.

```bash
[[ -n ${dir:?dir vazio} && $dir != "/" ]] || die "recusando"
rm -rf -- "$dir"
```

`${dir:?mensagem}` aborta com mensagem se vazia/indefinida — a defesa mais barata que existe.

**`eval`.** Quase sempre há alternativa: arrays para comandos dinâmicos, `declare -n` (nameref, 4.3+) ou `${!var}` para indireção, `case` para despacho. Use `eval` só quando o texto a executar é **construído por você** e não contém dado externo — reconstruir opções salvas com `set +o`, ou `eval "$(ssh-agent -s)"` de fonte confiável. `eval "$(curl ...)"` e `eval "cmd $entrada_do_usuario"` são RCE, não estilo. Se precisar, `printf %q` cada pedaço antes de concatenar.

**`PATH` explícito em script privilegiado.** Se o script roda via sudo/cron/systemd, `PATH` herdado é um vetor: um `grep` plantado em `~/bin` vira root.

```bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
```

Some com `IFS` herdado (`IFS=$' \t\n'` explícito), `CDPATH` (`unset CDPATH` — senão `cd foo` pode ir para outro lugar e imprimir no stdout), `BASH_ENV`, `ENV`, `GLOBIGNORE`. `set -p` (privileged mode) neutraliza vários desses automaticamente.

**Race de arquivo temporário.** `f=/tmp/x.$$; echo dados > $f` é TOCTOU clássico: `$$` é previsível, `/tmp` é world-writable, um atacante pré-cria `/tmp/x.1234` como symlink para `/etc/passwd`. `mktemp`/`mktemp -d` criam atomicamente com `O_EXCL` e modo 600/700. Sempre com template terminado em `XXXXXX` e sempre pareado com `trap ... EXIT`. Para escrita "atômica" de arquivo final: escreva no temp **no mesmo filesystem** e `mv` por cima (rename é atômico; `cp` não é).

**umask.** Sob `set -u` você não controla o umask herdado. Se o script gera arquivo com segredo, `umask 077` **antes** de criar. `chmod` depois deixa uma janela em que o arquivo está world-readable.

**Sanitizar entrada** significa validar contra allowlist, não escapar contra denylist:

```bash
[[ $nome =~ ^[A-Za-z0-9_-]+$ ]] || die "nome inválido: $nome"
```

Note que dentro de `[[ ]]` a variável à esquerda não sofre splitting (contexto seguro), mas o regex à direita **não pode ser citado** ou vira literal.

## Lock / singleton

```bash
# flock (util-linux): FD 9 aberto no lockfile; lock some quando o processo morre
exec 9>/var/lock/meujob.lock
flock -n 9 || die "já em execução"
# sem trap para remover: o kernel libera o lock ao fechar o FD
```

`flock -n` falha na hora; `flock -w 30` espera. Não remova o lockfile no cleanup — isso reintroduz race (outro processo já pode ter o lock no inode antigo). Basta o FD morrer.

Onde não há `flock` (macOS, BSD), o lock por diretório: `mkdir` é atômico e falha se já existe, ao contrário de `[[ -e ]] && touch`, que tem janela entre teste e criação.

```bash
lockdir=/tmp/meujob.lock
if mkdir "$lockdir" 2>/dev/null; then
  trap 'rmdir "$lockdir"' EXIT
  printf '%s\n' "$$" > "$lockdir/pid"
else
  # lock stale? valide o PID antes de assumir que o dono está vivo
  pid=$(<"$lockdir/pid") || pid=""
  [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null && die "rodando (pid $pid)"
  die "lock stale em $lockdir — remova manualmente"
fi
```

O lock por `mkdir` **não** é liberado se o processo for SIGKILLado — daí a checagem de PID stale, e daí `flock` ser superior onde existir.

## Estrutura de script grande

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true   # 4.4+; no-op em 3.2/4.3

readonly PROGNAME=${0##*/}
readonly VERSION=1.2.0
readonly SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
declare -r DEFAULT_TIMEOUT=30
declare -ri MAX_RETRIES=3

usage() { cat <<EOF
uso: $PROGNAME [-n] [-v] <src> <dst>
  -n  dry-run
  -v  verbose
EOF
}

parse_args() { ... }
main() {
  parse_args "$@"
  ...
}

main "$@"
```

**Por que `main "$@"` no final.** O Bash lê o script **incrementalmente**: se você editar o arquivo enquanto ele roda, ele continua lendo do offset de bytes anterior e executa lixo. Com todo o corpo em funções e uma única chamada na última linha, o parse já terminou antes da execução começar. É também o que torna o script `source`-ável para teste (`main` só roda se não for sourced — guarde com `[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"`).

**`readonly`/`declare -r`** para constantes: transforma reatribuição acidental em erro fatal. `declare -ri` para inteiro readonly; `declare -g` para tocar escopo global de dentro de função. Cuidado: variável `readonly` não pode ser `unset` nem redefinida nem no mesmo shell — o que quebra re-`source` em testes.

**Variáveis locais sempre.** `local` em toda variável de função — sem ele, tudo é global e uma função clobbera o `i` da outra. E `local` cria o buraco do `local x=$(...)` descrito acima: declare primeiro, atribua depois.

**`SCRIPT_DIR` com `cd ... && pwd -P`**, não `dirname $0` cru: resolve symlink e relativo, e sobrevive a `cd` posterior no script.
