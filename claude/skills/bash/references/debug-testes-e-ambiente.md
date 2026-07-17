# Debug, testes e ambiente

Três assuntos que se sustentam: descobrir por que o script faz o que faz (trace, stack trace, profiling), provar que ele continua fazendo (bats-core, design testável) e entender o shell como ambiente (startup files, prompt, história, `shopt`). Tudo assume Bash 4.4+; onde a versão importa, está dito.

## Debug

### `set -x` e o `PS4` que vale a pena

`set -x` (ou `set -o xtrace`) imprime cada comando simples, expandido, precedido pelo valor de `PS4`. O padrão `'+ '` é inútil em script de verdade: não diz arquivo, nem linha, nem função. O primeiro caractere de `PS4` é replicado para indicar nível de indireção (subshell, função), então mantenha `+` no início para ganhar essa profundidade de graça.

```bash
PS4='+ ${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:-main}: '   # o mínimo aceitável
set -x
```

`PS4` é expandido a cada linha traçada, portanto aceita expansão de parâmetro e até `$( )` — mas comando dentro de `PS4` é um fork por linha e polui o próprio trace. Prefira variáveis que o shell já mantém: `LINENO`, `BASH_SOURCE`, `FUNCNAME`, `EPOCHREALTIME`, `SECONDS`, `BASHPID`.

Trace global em script grande é ruído. Use cirurgicamente — `set -x` antes do trecho suspeito, `set +x` logo depois. Dentro de função, `local -` (Bash 4.4+) restaura no retorno todas as opções alteradas com `set`, o que é mais limpo que salvar `$-` na mão:

```bash
f() { local -; set -x; comando_suspeito; }   # xtrace morre no return
```

### `BASH_XTRACEFD`: trace fora do stderr

O maior problema do `set -x` é misturar trace com a saída de erro real do programa: você perde a mensagem no meio de 400 linhas de `+`. `BASH_XTRACEFD` aponta o trace para outro descritor.

```bash
exec {fd_trace}>/tmp/trace.$$        # fd dinâmico (Bash 4.1+)
BASH_XTRACEFD=$fd_trace
set -x
# stderr do script fica limpo; o trace vai para /tmp/trace.$$
```

Cuidado: atribuir vazio ou dar `unset` devolve o trace ao stderr, mas fechar o fd é o efeito colateral — setar `BASH_XTRACEFD=2` e depois dar `unset` **fecha o stderr**. Nunca aponte para 2 se pretende desfazer.

### Rodar o script sob suspeita

```bash
bash -n script.sh          # só parseia: erro de sintaxe sem executar nada (-fsyntax-only)
bash -v script.sh          # ecoa cada linha como lida (antes da expansão)
bash -x script.sh          # xtrace sem tocar no shebang do arquivo
bash -xv script.sh         # linha original + linha expandida, lado a lado
```

`bash -v` mostra o texto-fonte, `bash -x` mostra o resultado das expansões; a diferença entre os dois é onde mora a maioria dos bugs de quoting. `set -o functrace` (`set -T`) faz os traps `DEBUG` e `RETURN` serem herdados por funções, subshells e substituições de comando — sem ele, seu trap `DEBUG` some assim que entra numa função.

### `trap ERR`, `LINENO` e um stack trace de verdade

O trap `ERR` dispara sempre que um comando falha nas mesmas condições em que `set -e` abortaria. A versão de bolso é `trap 'echo "erro na linha $LINENO (status $?)" >&2' ERR`. A versão que serve em produção usa o trio `FUNCNAME` / `BASH_SOURCE` / `BASH_LINENO`, que descrevem a pilha: `${FUNCNAME[i]}` foi definida em `${BASH_SOURCE[i]}` e chamada de `${BASH_SOURCE[i+1]}` na linha `${BASH_LINENO[i]}`. O índice 0 é o frame atual.

```bash
set -Eeuo pipefail   # -E é obrigatório: sem ele o ERR não dispara dentro de função

stack_trace() {
  local status=$? i   # capture $? antes de qualquer outro comando
  echo "falhou com status $status" >&2
  # começa em 1: o frame 0 é a própria stack_trace
  for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
    printf '  em %s (%s:%s)\n' \
      "${FUNCNAME[i]}" "${BASH_SOURCE[i]}" "${BASH_LINENO[i-1]}" >&2
  done
}
trap stack_trace ERR
```

O deslocamento de um índice no `BASH_LINENO[i-1]` é o erro clássico aqui. O builtin `caller [expr]` faz a mesma leitura de forma declarativa — retorna `linha função arquivo` para o frame `expr` e falha quando o frame não existe, o que dá o loop mais curto:

```bash
stack_trace() { local frame=0; while caller $((frame++)); do :; done >&2; }
```

Para step-through, `trap ... DEBUG` roda antes de cada comando simples:

```bash
trap 'read -rsn1 -p "[${BASH_SOURCE##*/}:$LINENO] $BASH_COMMAND" </dev/tty' DEBUG
```

`BASH_COMMAND` guarda o comando prestes a executar. Combine com `set -T` para atravessar funções. Isso é debugger de pobre mas resolve 90% dos casos sem instalar `bashdb`.

### `declare -p` em vez de `echo`

`echo "$var"` mente: não distingue vazio de não-definido, some com espaços em branco significativos, e para array só mostra o elemento 0. `declare -p` imprime a representação real, com atributos e quoting reversível.

```bash
declare -p arr          # declare -a arr=([0]="a b" [1]="" [2]="c")
declare -p x || echo "x não existe"   # falha se não definida — o teste que echo não faz
declare -f nome         # corpo da função, normalizado pelo parser
```

`declare -f` mostra como o Bash realmente entendeu seu código — e revela se um mock sobrescreveu o que você achava.

### Método

Antes de qualquer coisa, `shellcheck script.sh`. Ele acha quoting quebrado, `[ ]` vs `[[ ]]`, `$?` testado tarde demais, glob acidental — a maior parte do que você ia caçar no trace. Depurar sem rodar shellcheck antes é desperdiçar tempo em bug que uma ferramenta apontaria de graça.

No que sobrar: **bissecte com `exit 0`** no meio do script — chega ao comando culpado em log₂(n) execuções. **Isole em subshell**: `( set -x; trecho )` roda com trace num escopo descartável, onde variável e `cd` não vazam e você repete sem sujar o estado. **Minimize o caso** extraindo o trecho para `/tmp/min.sh` com valores literais em vez de `$@` — quase sempre o bug some na minimização, e o que você removeu para fazê-lo sumir *é* o bug. **Reproduza o ambiente certo** com `env -i bash --noprofile --norc ./script.sh`, que mostra o que quebra sem o `.bashrc` do dev para salvar — exatamente o caso do cron e do CI.

### Performance: o problema é fork

Um script Bash lento quase nunca é lento por causa do Bash. É lento porque chama um processo externo dentro de um loop: 10 mil iterações × um `sed` = 10 mil `fork`+`exec`, e cada um custa ordens de grandeza mais que qualquer coisa que o interpretador faça. A regra prática de otimização é uma só: **tire o subprocesso de dentro do loop**, seja movendo o loop para dentro do processo (uma chamada de `awk` no arquivo todo) ou substituindo o processo por um builtin.

```bash
# ruim: 2 forks por iteração
for f in *.log; do
  base=$(basename "$f" .log)
  slug=$(echo "$base" | tr 'A-Z' 'a-z')
done

# bom: zero forks — tudo builtin/expansão
for f in *.log; do
  base=${f##*/}; base=${base%.log}   # basename
  slug=${base,,}                     # tr 'A-Z' 'a-z' (Bash 4+)
done
```

Substituições diretas que valem memorizar:
- `basename`/`dirname` → `${v##*/}` e `${v%/*}`
- `sed 's/a/b/'` → `${v/a/b}`; `sed 's/a/b/g'` → `${v//a/b}`
- `tr`, `cut -c` → `${v,,}`, `${v^^}`, `${v:0:3}`
- `grep -q pat` num string → `[[ $v == *pat* ]]` ou `[[ $v =~ regex ]]`
- `x=$(printf ...)` → `printf -v x ...` (evita o subshell da substituição de comando)
- `expr`/`bc` para inteiro → `$(( ))`
- `cat arquivo | while` → `while ... done < arquivo`

Medir antes de otimizar. `time` é palavra reservada e cronometra pipeline inteiro ou grupo; `TIMEFORMAT` controla o formato (`%R` real, `%U` user, `%S` sys). Para profiling linha a linha, `PS4` com `EPOCHREALTIME` (Bash 5+) dá timestamp de microssegundo por comando traçado, sem fork:

```bash
TIMEFORMAT='%3R real | %3U user | %3S sys'
time { processar_tudo; }

PS4='+ $EPOCHREALTIME ${BASH_SOURCE##*/}:${LINENO}: '
exec {fd}>/tmp/prof.$$; BASH_XTRACEFD=$fd; set -x
# depois: delta entre timestamps consecutivos mostra onde o tempo foi
awk '{ if (p) printf "%.4f %s\n", $2-p, l; p=$2; l=$0 }' /tmp/prof.$$ | sort -rn | head
```

## Testes

Esta seção cobre o essencial: bats básico e o assert caseiro. Para shunit2, o bats avançado, ShellSpec e a escolha de framework, a referência é `frameworks-de-teste.md`; para test doubles, design testável, cobertura com kcov e CI, `testabilidade-e-cobertura.md`.

### bats-core

`bats` é o framework de facto: arquivos `.bats` são Bash com açúcar (`@test` vira função), o runner produz TAP.

```bash
# instalação — como submódulo é o que sobrevive ao CI
git submodule add https://github.com/bats-core/bats-core.git test/bats
git submodule add https://github.com/bats-core/bats-support.git test/bats-support
git submodule add https://github.com/bats-core/bats-assert.git test/bats-assert
./test/bats/bin/bats test/     # roda; --tap, --jobs N para paralelismo
```

`run cmd` executa `cmd` sem deixar `set -e` abortar o teste, e preenche `$status`, `$output` (stdout+stderr juntos) e o array `$lines`. Sem `run`, um comando que falha derruba o teste — o que é o que você quer no *arrange*, não na *assertion*.

`load` resolve caminho relativo ao diretório do arquivo de teste — é o certo para a instalação por submódulo acima. Se as libs vierem do sistema (`npm`, `brew`), o caminho depende da instalação e `load` quebra: use `bats_load_library bats-assert` com `BATS_LIB_PATH` apontando para o diretório das libs.

```bash
#!/usr/bin/env bats
# test/deploy.bats

setup_file() {
  # roda UMA vez por arquivo: coisas caras (build, subir container)
  export PROJETO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

setup() {
  # roda antes de CADA teste
  load 'bats-support/load'
  load 'bats-assert/load'
  PATH="$PROJETO_ROOT:$PATH"
  # BATS_TEST_TMPDIR é limpo automaticamente entre testes
  cd "$BATS_TEST_TMPDIR"
  source "$PROJETO_ROOT/deploy.sh"   # o guard main impede execução
}

teardown() {
  rm -rf "$BATS_TEST_TMPDIR/artefatos"
}

@test "slugify normaliza maiúsculas e espaços" {
  run slugify "Minha App V2"
  assert_success
  assert_output "minha-app-v2"
}

@test "montar_comando_curl inclui o token e a URL alvo" {
  TOKEN=segredo run montar_comando_curl "https://api.exemplo/deploy"
  assert_success
  assert_line --partial "Authorization: Bearer segredo"
}

@test "deploy falha com mensagem clara quando o token não existe" {
  unset TOKEN
  run deploy staging
  assert_failure 2
  assert_output --partial "TOKEN não definido"
}

@test "deploy chama o curl injetado exatamente uma vez" {
  # mock por injeção de dependência
  chamadas=0
  fake_curl() { ((chamadas++)); echo '{"ok":true}'; }
  CURL=fake_curl TOKEN=x
  run deploy staging
  assert_success
  assert_output --partial '"ok":true'
}

@test "primeira linha do help é o usage" {
  run deploy --help
  assert_equal "${lines[0]}" "uso: deploy <ambiente>"
  assert_equal "${#lines[@]}" 4
}

@test "publica no registry real" {
  [[ -n ${CI:-} ]] || skip "só roda no CI (precisa de credencial)"
  run publicar
  assert_success
}
```

`load nome` faz `source` de `nome.bash` relativo ao diretório do teste — é como você compartilha helpers. `skip "motivo"` marca o teste como pulado sem falhar (use para dependência externa ausente, nunca para teste quebrado). Variáveis úteis: `BATS_TEST_TMPDIR` (por teste), `BATS_FILE_TMPDIR` (por arquivo), `BATS_TEST_DIRNAME`, `BATS_TEST_NAME`.

### Testar sem framework

Para um script pequeno, um `assert` caseiro com exit code agregado basta e não adiciona dependência:

```bash
#!/usr/bin/env bash
source ./lib.sh
falhas=0

assert_eq() {  # assert_eq <esperado> <obtido> <descrição>
  if [[ $1 == "$2" ]]; then printf 'ok - %s\n' "$3"
  else printf 'NOK - %s\n  esperado: %q\n  obtido: %q\n' "$3" "$1" "$2"; ((falhas++))
  fi
}

assert_eq "minha-app" "$(slugify 'Minha App')" "slugify básico"
assert_eq "2" "$(conta_erros fixtures/app.log)" "conta ERROR"
exit $(( falhas > 0 ))   # exit code agregado: qualquer falha derruba o build
```

### O que torna um script testável

O script típico é intestável porque faz tudo em top-level, chama `curl` direto e não tem função com fronteira. Quatro mudanças resolvem.

**Guard `main`**: permite `source` do script sem executá-lo — é o que faz o teste enxergar as funções. **Funções puras**: recebem argumento, escrevem em stdout, não tocam em global nem em I/O. **Injeção de dependência via variável**: `: "${CURL:=curl}"` define o default sem sobrescrever o ambiente, e o teste passa `CURL=fake_curl`. **Separar montar de executar**: uma função devolve o argv (testável com assert de string), outra executa (fina demais para ter bug).

```bash
: "${CURL:=curl}"        # default sem sobrescrever o ambiente
montar_comando_curl() {  # puro: imprime o argv, um item por linha
  printf '%s\n' -fsS -H "Authorization: Bearer $TOKEN" -X POST "$1"
}
executar() { mapfile -t argv; "$CURL" "${argv[@]}"; }
main() { executar < <(montar_comando_curl "$1"); }

# só executa quando rodado diretamente, não quando "sourced"
[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
```

### Mocks

Duas formas, nessa ordem. **Função sombreando o comando**: função tem precedência sobre executável no PATH, então `curl() { ...; }` intercepta as chamadas — mas só no mesmo shell (use `export -f curl` para subshell filho), e `command curl` fura o mock, que é justamente como você chama o real por dentro dele.

**PATH de fixtures**: quando o código chama o binário de um subprocesso que não herda funções (via `env`, `xargs`, `sudo`), escreva um stub executável num diretório e prefixe o PATH. É mais fiel e funciona em qualquer nível de aninhamento.

```bash
mkdir -p "$BATS_TEST_TMPDIR/bin"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >>"$MOCK_LOG"\necho "{}"\n' \
  >"$BATS_TEST_TMPDIR/bin/curl"
chmod +x "$BATS_TEST_TMPDIR/bin/curl"
PATH="$BATS_TEST_TMPDIR/bin:$PATH"
```

### CI

Três passos, todos falhando o build:

```yaml
- run: shellcheck -x -S style $(git ls-files '*.sh' '*.bash')
- run: shfmt -d -i 2 -ci .        # -d falha se a formatação diverge
- run: ./test/bats/bin/bats -r --jobs 4 test/
```

`shellcheck -x` segue os `source`; sem isso ele ignora o que vem de fora e perde contexto. `# shellcheck disable=SCxxxx` deve vir sempre com comentário do porquê — supressão sem justificativa é dívida silenciosa.

## Ambiente e shell interativo

### Startup files e a ordem

A pergunta "por que minha variável não aparece no terminal do editor" tem sempre a mesma resposta: você a definiu num arquivo que aquele shell não lê. O Bash escolhe os arquivos por **duas dimensões independentes** — login ou não, interativo ou não:

| Invocação | Lê |
| --- | --- |
| Login interativo (`--login`, `bash -l`, Terminal.app do macOS, `ssh host`) | `/etc/profile`, depois **o primeiro** que existir entre `~/.bash_profile`, `~/.bash_login`, `~/.profile`; ao sair, `~/.bash_logout` |
| Interativo não-login (`xterm`, `tmux`, `bash` dentro de um shell) | `~/.bashrc` |
| Não-interativo (`bash script.sh`, `bash -c`, cron, hook) | **nada** — exceto o arquivo apontado por `BASH_ENV`, se definido |
| Login não-interativo (`bash --login script.sh`) | arquivos de login, como na primeira linha |
| Invocado como `sh` | `/etc/profile` e `~/.profile` (login); `$ENV` (interativo); nada (não-interativo) |

Três consequências práticas. Primeira: **`~/.bash_profile`, `~/.bash_login` e `~/.profile` são mutuamente exclusivos** — o Bash lê só o primeiro que encontrar, então criar `~/.bash_profile` num sistema que usava `~/.profile` silencia o `~/.profile` inteiro. Segunda: no macOS o Terminal abre **login shell** por padrão, logo `~/.bashrc` não é lido; no Linux é o contrário — daí a linha canônica no `~/.bash_profile`: `[[ -f ~/.bashrc ]] && . ~/.bashrc`. Terceira: o terminal integrado do editor, o cron e o hook rodam shell não-interativo, que **não lê `.bashrc` nem `.profile`** — se a variável precisa existir lá, ela vem do ambiente do processo pai (o editor, o `PATH` do launchd/systemd), não de arquivo de startup. `BASH_ENV` existe para isso, mas é global demais e vira armadilha; prefira exportar do supervisor.

Divisão correta: `~/.bash_profile` recebe o que acontece uma vez por sessão e é herdado (`export PATH`, `export EDITOR`, agente ssh); `~/.bashrc` recebe o que só faz sentido em shell interativo e não é herdado (alias, prompt, `shopt`, funções, completions). `export PATH=...:$PATH` no `.bashrc` faz o PATH crescer a cada shell aninhado.

`$-` contém `i` quando interativo; guardar o `.bashrc` com isso evita quebrar `scp`/`rsync`, que engasgam com qualquer saída inesperada:

```bash
case $- in *i*) ;; *) return ;; esac   # aborta o rc se não-interativo
```

### Prompt

`PS1` é o prompt primário; `PS2` a continuação (`>`); `PS0` é expandido **depois** de ler o comando e antes de executar (bom para timestamp de início); `PROMPT_COMMAND` roda antes de imprimir `PS1` e, no Bash 5.1+, pode ser array — cada elemento é um comando, o que permite vários hooks sem concatenar strings. Escapes: `\u` usuário, `\h` host curto, `\w` cwd (com `PROMPT_DIRTRIM=3` para limitar componentes), `\$` vira `#` se root.

Cores: **todo escape não-imprimível precisa estar entre `\[` e `\]`**. Esses delimitadores dizem ao readline "isto ocupa zero colunas". Sem eles, o readline conta os bytes do escape ANSI como largura visível, erra o cálculo da linha, e o sintoma clássico aparece: a linha se sobrescreve ao editar comando longo, ou o histórico redesenha o prompt torto.

```bash
# certo
PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
# errado — sem \[ \], edição de linha longa embaralha
PS1='\e[32m\u@\h\e[0m:\w\$ '
```

### História

```bash
HISTSIZE=100000            # entradas em memória
HISTFILESIZE=200000        # linhas no arquivo (default: vira HISTSIZE após os rc)
HISTCONTROL=ignoreboth     # ignorespace + ignoredups
HISTIGNORE='ls:bg:fg:history:exit:clear'
shopt -s histappend        # anexa em vez de sobrescrever o histfile ao sair
shopt -s cmdhist           # comando multi-linha vira UMA entrada
HISTTIMEFORMAT='%F %T '    # grava timestamp; muda o formato do `history`
```

`histappend` é obrigatório com múltiplos terminais abertos: sem ele, o último shell a sair sobrescreve o arquivo com a *sua* sessão e o resto do dia evapora. `ignorespace` dá o truque de prefixar com espaço um comando com segredo para ele não ir ao histórico. `erasedups` remove duplicatas antigas, mas destrói a ordem cronológica.

Expansão de histórico (interativo, por padrão): `!!` último comando, `!$` último argumento do comando anterior, `!*` todos os argumentos, `!ls` último comando começando com `ls`, `^velho^novo` substitui no último comando. `sudo !!` paga por si só.

A pegadinha: `!` **é expandido dentro de aspas duplas**. `echo "erro!"` funciona (`!` seguido de espaço/fim não é evento), mas `git commit -m "fix!ls"` vira expansão ou `event not found`. Aspas simples protegem; `set +H` desliga a expansão de vez — num shell onde você escreve mais mensagens que `!!`, é boa troca.

### `shopt` que valem a linha no `.bashrc`

```bash
shopt -s checkwinsize   # atualiza LINES/COLUMNS após cada comando (redimensionar não quebra o wrap)
shopt -s cdspell        # corrige typo em argumento de cd (só interativo)
shopt -s autocd         # "/tmp" sozinho vira "cd /tmp"
shopt -s globstar       # ** casa recursivo: **/*.ts
shopt -s nocaseglob     # glob case-insensitive
shopt -s direxpand      # completion expande $VAR/~ no buffer em vez de preservar o digitado
```

`globstar` é o único aqui que também vale em script (e aí `shopt -s globstar` fica no script, não no rc — script não lê seu rc). `nocaseglob` e `autocd` mudam comportamento de forma que pode surpreender: mantenha-os no `.bashrc`, nunca em arquivo que scripts façam `source`.

### Alias vs função

Alias é substituição textual no início do comando: não aceita argumento posicional, não funciona em script não-interativo (precisa de `shopt -s expand_aliases`) e não compõe. Função aceita argumento, tem escopo e `local`, retorna status e pode ser exportada. **Use função, salvo quando o alias for literalmente um encurtamento sem parâmetro** (`alias ll='ls -lah'`); qualquer coisa que precise de `$1` vira função (`mkcd() { mkdir -p -- "$1" && cd -- "$1"; }`). O único poder real do alias que a função não tem: alias terminando em espaço faz a *próxima* palavra também ser expandida como alias — `alias sudo='sudo '` faz seus aliases funcionarem sob `sudo`.

### `CDPATH`, readline, `bind`, `complete`

`CDPATH` é o PATH do `cd`: `CDPATH=.:~/projetos` faz `cd api` funcionar de qualquer lugar. Comece **sempre** com `.`, senão `cd subdir` local pode pular para outro lugar. Nunca exporte `CDPATH` — script que faz `cd` relativo quebra de forma bizarra.

Readline lê `~/.inputrc` (e `/etc/inputrc`); `$if Bash` limita diretivas ao Bash. O essencial — e o binding de seta que sozinho justifica o arquivo:

```
set completion-ignore-case on
set show-all-if-ambiguous on      # lista já no primeiro TAB
"\e[A": history-search-backward   # ↑ busca no histórico pelo prefixo já digitado
"\e[B": history-search-forward
```

`bind` faz o mesmo em runtime a partir do `.bashrc` (`bind '"\e[A": history-search-backward'`); `bind -P` lista os bindings, `bind -q função` diz que tecla chama o quê. `complete` registra completion: `-W "start stop restart"` para palavras fixas, `-F _minha_func` para lógica (a função lê `COMP_WORDS`/`COMP_CWORD` e preenche `COMPREPLY`), `-o default` para cair no completion de arquivo sem match.
