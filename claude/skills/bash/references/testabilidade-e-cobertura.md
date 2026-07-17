# Testabilidade e cobertura

Como projetar script Bash que pode ser testado sem disparar efeitos colaterais, quais test doubles usar em cada fronteira, o que a cobertura com kcov mede de verdade (medido, não presumido) e o CI que realmente paga em shell — a matriz de versões de Bash. O básico de bats e do assert caseiro está em `debug-testes-e-ambiente.md`; shellcheck a fundo e shfmt básico, em `portabilidade-e-armadilhas.md` — aqui eles aparecem só como passos de pipeline.

## Escrever script testável

O trabalho de tornar um script testável acontece **antes** do framework: é design. Se o script for testável, qualquer runner serve; se não for, nenhum salva.

### O problema central

Script feito para rodar não é feito para testar. O sintoma é sempre o mesmo — não existe forma de observar uma decisão sem provocar o efeito colateral dela:

```bash
#!/usr/bin/env bash
set -euo pipefail                                        # ANTES — nada testável isoladamente
REGION=$(curl -s http://169.254.169.254/.../region)      # rede no top-level
STAMP=$(date +%Y%m%d)                                    # relógio no top-level
[[ $EUID -eq 0 ]] || { echo "rode como root" >&2; exit 1; }   # exit no meio
cd /var/lib/app                                          # depende de cwd

deploy() {   # 200 linhas: decide o alvo, monta o comando, chama a rede e loga
  [[ $STAMP == *01 ]] && bucket="s3://backup-mensal" || bucket="s3://backup-diario"
  aws s3 cp "./dump-$STAMP.sql" "$bucket/$REGION/" --storage-class GLACIER
}
deploy "$@"
```

Sourcear esse arquivo num teste já dispara duas chamadas externas, aborta se você não for root e muda o cwd do runner. A regra `*01 → bucket mensal` — a única coisa que você realmente quer verificar — não é alcançável sem uma conta AWS. Quatro vícios distintos: **efeito no top-level**, **`exit` fora de `main`**, **dependência ambiental implícita** (rede, relógio, root, cwd) e **decisão fundida com efeito**.

### O guard `main`

A forma exata:

```bash
main() { ... }
# executa só quando o arquivo é o programa; fica inerte quando é sourceado
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then main "$@"; fi
```

`BASH_SOURCE[0]` é sempre o arquivo onde a linha está; `$0` é o programa invocado. Rodando `./deploy.sh`, os dois são `./deploy.sh` e `main` roda. Sob `source ./deploy.sh`, `$0` continua sendo o shell (`bash`, `zsh`, `-bash`), a igualdade falha e você fica só com as funções carregadas — que é exatamente o que um teste quer.

Três detalhes que só aparecem quando você executa:

**1. Prefira `if` a `&&`.** A forma curta `[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"` é idiomática e **quebra**: sendo a última linha, ela vira o status de saída do arquivo. Ao ser sourceada o teste dá falso, o `&&` devolve `1`, e um chamador com `set -e` morre no `source`:

```console
$ bash -c 'set -e; source ./deploy.sh; echo CHEGUEI'; echo $?
1                     # "CHEGUEI" nunca imprime — o guard matou o teste
```

Com a forma `if`, o bloco não executado devolve `0`. Se insistir no `&&`, feche com `|| true` ou `exit 0`/`return 0` explícito.

**2. Sob `set -u`, use `${BASH_SOURCE[0]:-}`.** Em Bash 3.2 (macOS), `BASH_SOURCE` pode estar vazio em contextos sem arquivo (`bash -c`), e `set -u` aborta com `BASH_SOURCE[0]: unbound variable`. A forma defensiva: `[[ ${BASH_SOURCE[0]:-} == "${0}" ]]`.

**3. Script que também é lib.** Quando o mesmo arquivo é biblioteca em produção e CLI, o guard é o mesmo, mas o `set -euo pipefail` **não pode** ficar no top-level: `source` importa as opções para o shell do chamador e contamina o teste inteiro — verificado: depois de `source ./deploy.sh`, `case $- in *u*)` no chamador acusa `set -u VAZOU`. Mova-as para dentro de `main`, onde só valem quando o arquivo roda como programa:

```bash
main() {
  set -euo pipefail   # só quando é programa, nunca quando é lib
  ...
}
if [[ ${BASH_SOURCE[0]:-} == "${0}" ]]; then main "$@"; fi
```

### Separar decisão de efeito

A ideia mais valiosa deste arquivo. Divida cada função em duas categorias:

- **Funções que calculam** — entrada por argumento, saída por stdout, status de saída como veredito. Sem rede, sem escrita, sem `date`, sem `$PWD`. São puras e testá-las é uma linha.
- **Funções que fazem** — I/O, rede, filesystem, processos. Não decidem nada; recebem pronto e executam.

Testar as puras é trivial. **Isolar as impuras é o trabalho** — e o objetivo é encolhê-las até serem burras demais para errar. Refatorando o `deploy` acima:

```bash
# DEPOIS — decisão pura: string entra, string sai
pick_bucket() {
  local stamp=$1 region=$2
  case $stamp in
    *01) printf '%s\n' "s3://backup-mensal/$region/" ;;
    *)   printf '%s\n' "s3://backup-diario/$region/" ;;
  esac
}
```

```console
$ source ./deploy.sh
$ [[ $(pick_bucket 20260101 sa-east-1) == "s3://backup-mensal/sa-east-1/" ]] && echo ok
ok
```

Sem AWS, sem rede, sem root, sem relógio. É `nvm` que leva isso ao extremo: `nvm_find_project_dir` não toca no filesystem real do runner — o teste passa `PWD` como variável e compara o stdout, um `[ "$ACTUAL" = "$EXPECTED" ] || die` por caso.

### Montar vs executar o comando

Corolário direto: uma função devolve o comando, outra o executa. A que monta é pura e assertável; a que executa é uma linha sem lógica.

```bash
build_upload_cmd() {   # pura: emite argv, uma palavra por linha
  local file=$1 url=$2
  printf '%s\n' "$CURL" --fail -sS -X POST -H "X-Ts: $NOW" --data-binary "@$file" "$url"
}

upload() {             # impura: só executa, nada a errar
  local cmd=()
  while IFS= read -r a; do cmd+=("$a"); done < <(build_upload_cmd "$@")
  "${cmd[@]}"
}
```

Uma palavra por linha (`printf '%s\n'`) é o formato mais seguro — sobrevive a espaços e a quoting sem `eval`. Para asserção legível numa linha só, `printf '%q '` produz uma forma re-parseável pelo shell. O que não fazer é devolver `"$*"`: colapsa argumentos e perde os limites entre eles.

### Injeção de dependência

Não precisa de framework. `: "${VAR:=default}"` atribui o default só se a variável estiver vazia — produção usa o padrão, teste sobrescreve pelo ambiente:

```bash
: "${CURL:=curl}"          # binário de rede
: "${DATE_CMD:=date}"      # relógio
: "${NOW:=$(date +%s)}"    # instante congelável — melhor que mockar 'date'
: "${STATE_DIR:=/var/lib/app}"   # caminho de dados, nunca hardcoded
```

Três variantes, em ordem de preferência: **congelar o valor** (`NOW`) é mais simples que **injetar o comando** (`DATE_CMD`), que é mais simples que **mockar o binário**. Passar o comando como parâmetro (`fetch() { local curl_bin=$1; ... }`) funciona e é o mais explícito, mas polui a assinatura — reserve para quando a dependência varia por chamada, não por ambiente.

Uma pegadinha na hora de sobrescrever: **o prefixo em `source` não persiste depois dele**.

```console
$ bash -c 'NOW=111 source ./lib.sh; echo "depois: ${NOW:-<vazio>}"'
depois: <vazio>        # sumiu — o prefixo vale só durante o source
$ bash -c 'NOW=111; source ./lib.sh; echo "depois: ${NOW:-<vazio>}"'
depois: 111            # atribua antes, sem prefixo
```

`basher` faz isso no `test_helper.bash`: todo caminho que o SUT consulta (`BASHER_PREFIX`, `BASHER_INSTALL_BIN`, `BASHER_PACKAGES_PATH`) é `export` para dentro de `$BATS_TMPDIR` antes de qualquer teste rodar. Nenhum caminho de produção é tocado porque nenhum está hardcoded.

## Test doubles

**1. Redefinir a função no escopo do teste.** Barato e instantâneo, roda no mesmo processo.

```bash
curl() { echo "MOCK"; }
```

Limite decisivo: pega chamada de função e mais nada — verificado: `command curl` passa direto no curl real e `bash -c 'curl ...'` não vê o mock. Use quando o SUT chama a dependência como função, no mesmo shell. É o default do ShellSpec pelo custo zero de processo.

**2. Shim/stub em PATH.** Um executável falso na frente do `PATH`. Pega **tudo**, inclusive subprocessos, `command foo`, `xargs foo` e `bash -c`.

```bash
# $FIXTURES/bin/curl — spy: grava o argv e devolve resposta canned
#!/usr/bin/env bash
printf '%s\n' "$#" >> "$SPY_LOG"     # aridade primeiro
printf '%s\n' "$@" >> "$SPY_LOG"     # uma palavra por linha: preserva espaços
echo "fake-response"
```

No teste: `PATH="$FIXTURES/bin:$PATH"; SPY_LOG="$TMPDIR/calls.log"; : > "$SPY_LOG"`. Asserção "chamou uma vez, com estes argumentos" — grave a aridade e leia o log como registros:

```bash
assert_called_once_with() {   # ex.: assert_called_once_with --fail -sS -X POST http://x/y
  local -a want=("$@") got=()
  local n; { read -r n; while IFS= read -r a; do got+=("$a"); done; } < "$SPY_LOG"
  [[ ${#got[@]} -eq $n ]] || { echo "esperava 1 chamada, veio mais" >&2; return 1; }
  [[ "${got[*]}" == "${want[*]}" ]] ||
    { printf 'esperado: %q\nrecebido: %q\n' "${want[*]}" "${got[*]}" >&2; return 1; }
}
```

Se o log tiver mais registros que a aridade declarada, houve mais de uma chamada — é assim que se distingue "chamou uma vez" de "chamou três". `basher` gera esses shims em runtime (`mock_command` escreve um `$cmd` que ecoa `"$command $@"` e faz `PATH=...:$PATH`); `nvm` mantém os dele versionados em `test/mocks/` — `uname_linux_x86_64`, `pkg_info_fail` (literalmente `exit 1`), um arquivo por cenário de plataforma. `bats-mock` é a versão industrializada: symlink para um `binstub` em `$BATS_MOCK_BINDIR`, um `${program}-stub-plan` com as invocações esperadas, um `${program}-stub-run` com as reais, e `unstub` compara os dois.

**3. `export -f` para atravessar subshell.** Meio-termo: mantém a definição em Bash puro, mas exporta para processos filhos — depois do `export -f curl`, `bash -c curl` passa a ver o mock. Só Bash, e não cobre `command curl` no mesmo shell. Útil quando o SUT invoca `bash -c` ou `xargs bash -c` e você não quer criar arquivo.

**4. Wrapper de comando.** `command_not_found_handle` só dispara quando o comando **não existe** — inútil para interceptar um `curl` instalado. `alias` não expande em script não-interativo sem `shopt -s expand_aliases` e não atravessa subprocesso. Ambos são frágeis demais para serem a estratégia principal; cite-os para saber por que não usá-los.

**Qual usar:** função redefinida por padrão; **PATH shim quando o SUT invoca um binário externo** ou quando você precisa espionar subprocessos; `export -f` quando há `bash -c` no meio e o shim não compensa. Se a resposta for "nenhum resolve", o problema é design, não mock.

### O que NÃO mockar

Não mocke coreutils. Não mocke o filesystem. Criar um `mktemp -d` de verdade e povoá-lo custa microssegundos e é infinitamente mais fiel que fingir `ls`. Se você sentiu vontade de mockar `ls`, `cat` ou `mkdir`, o sinal é de design: a função está fazendo I/O onde deveria estar decidindo. Mocke a fronteira do sistema — rede, relógio, `aws`, `docker`, `git push` — e nada abaixo dela. Note que `nvm` mocka `uname` e `pkg_info` (fronteira: identidade da plataforma) mas nunca `test` ou `dirname`.

### Fixtures e golden files

Um diretório versionado com os dados de entrada (`test/fixtures/`, como em `nvm`, `basher` e `bash-it`), e um diretório temporário descartável para tudo que o teste escreve — `BATS_TEST_TMPDIR` no bats, `$(mktemp -d)` fora dele, com `trap 'rm -rf "$tmp"' EXIT`.

Para saída estável, arquivo golden com `diff <(cmd) golden` — e um caminho de atualização, senão ninguém mantém o golden:

```bash
if [[ ${UPDATE_GOLDEN:-} == 1 ]]; then
  render_report "$FIXTURES/input.json" > "$FIXTURES/report.golden"
else
  diff -u <(render_report "$FIXTURES/input.json") "$FIXTURES/report.golden"
fi
```

`UPDATE_GOLDEN=1` regenera; o diff no PR é a revisão. O `diff` sai não-zero e imprime o contraste, que é exatamente o relatório de falha que você quer.

## Isolamento e casos difíceis

### Determinismo

Hermético por padrão: nenhum teste toca a rede, e um shim de `curl` que falha ruidosamente é melhor guarda que a confiança. O resto é fixar tudo que o ambiente pode variar:

```bash
export TZ=UTC LC_ALL=C LANG=C     # data e ordenação de 'sort' reprodutíveis
export NOW=1700000000             # relógio congelado
export SEED=42                    # aleatoriedade fixa
export HOME="$BATS_TEST_TMPDIR"   # nada escreve no $HOME real
```

`HOME` é o mais esquecido e o mais destrutivo — `git`, `ssh` e metade das CLIs leem config de lá. `bash-it` faz `readonly HOME="${BATS_SUITE_TMPDIR}"` e reconfigura `git config --global user.name` dentro dele; o `readonly` é o detalhe esperto, impede que qualquer coisa reatribua depois. Some a isso `unset "${!BASH_IT@}"` para limpar variáveis herdadas do shell de quem roda o teste.

Nenhum teste pode depender de ordem: se o teste B só passa depois do A, o estado vazou. `teardown() { rm -rf "$TEST_DIR"; }` e cada teste reconstrói o que precisa.

### Testar coisas difíceis

**Função que chama `exit`** — o `$( )` já é subshell; o `exit` morre lá dentro e o teste sobrevive:

```console
$ out=$( validate "" 2>&1 ); st=$?; echo "status=$st out=$out"
status=2 out=erro: vazio
```

**Função que lê stdin** — here-string, sem arquivo temporário: `run parse_config <<< "key=value"`. Para múltiplas linhas, here-doc.

**Função interativa** — `read` com stdin redirecionado: `confirm_delete <<< "yes"`. Se ela abre `/dev/tty` explicitamente, não há como alimentar por stdin — injete o descritor (`: "${PROMPT_FD:=/dev/tty}"`) e aponte para um arquivo no teste.

**Função que precisa de root** — `skip` quando `[[ $EUID -ne 0 ]]`, e rode a suíte completa num container no CI. Melhor ainda: extraia a decisão da ação e teste a decisão sem privilégio nenhum.

**`trap`/cleanup** — rode o SUT como subprocesso de verdade (`bash ./script.sh`) e verifique o efeito depois: `[[ ! -e $tmp ]]`. Trap só é observável quando o processo realmente termina. Para o caminho de sinal, `kill -TERM $pid` e depois confira o estado.

**Timeout** — `timeout 5 bash ./script.sh` no teste, e status `124` significa travou. Teste que pendura é pior que teste que falha.

## A pirâmide em shell

A base larga são **funções puras**: chamada direta, comparação de stdout e status, milissegundos, zero mock. É onde mora quase todo o valor, porque é onde mora quase toda a lógica — depois que você separou decisão de efeito. O meio é fino: um punhado de testes com shim em PATH para verificar que o comando montado é o comando certo, e que o wiring entre as puras funciona. O topo é **um punhado de testes end-to-end** do script real, invocado como processo, com fixtures em disco e a fronteira mockada. Poucos, lentos, e os únicos que provam que o programa é um programa.

Onde parar: testar cada `echo` é desperdício — o teste vira uma transcrição do código e quebra a cada mudança de texto sem pegar bug nenhum. Não teste `usage()`, não teste que o log logou. Teste o que **decide**, o que **quebra em produção** e o que você **teve medo de mudar**. Se uma função não tem ramo condicional e não tem efeito observável, ela não tem teste a escrever.

## Cobertura com kcov

Não existe instrumentação de fonte para shell. O `kcov` — a ferramenta de referência — não reescreve seu script: liga o rastreamento do próprio Bash e lê o que sai. Os dois métodos (`--bash-method=PS4`, default, e `--bash-method=DEBUG`) estão literalmente nos helpers que ele injeta em runtime via `BASH_ENV`:

```sh
# bash-helper.sh — método PS4 (default)
PS4='kcov@${BASH_SOURCE}@${LINENO}@'   # prefixo do xtrace vira registro estruturado
set -x                                  # cada comando executado emite uma linha
# bash-helper-debug-trap.sh — método DEBUG: set -o functrace + trap com o mesmo
# registro no DEBUG, escrito em $KCOV_BASH_XTRACEFD
```

Ou seja: a unidade de cobertura é **o comando que o Bash decidiu tracear**, não a linha de código-fonte. Essa diferença é a origem de todas as mentiras da métrica em shell. Demonstração empírica (kcov 43):

```bash
# lib.sh
saudacao() { echo "ola $1"; }      # 2 — one-liner
nunca_chamada() { echo "morta"; }  # 3 — NUNCA chamada por teste algum
soma() {                           # 4
  local a=$1 b=$2                  # 5
  echo $((a + b))                  # 6
}
```

Exercitando só `saudacao` e `soma`, o relatório diz `lib.sh: 100.00% (2/2)`. Duas linhas contadas — 5 e 6, o corpo multi-linha de `soma`. A linha 2 não existe para o relatório: o corpo de um one-liner colapsa no `LINENO` da definição e **nunca entra na contagem — nem quando executa** (medido: a linha de uma função one-liner efetivamente chamada também não é contada). Pelo mesmo motivo, a linha 3 — função morta one-liner — não aparece nem como não-coberta.

A nuance importa e foi medida nos dois sentidos: função morta com corpo **one-liner** (`f() { echo x; }`) → arquivo reporta `100.00% (1/1)`. A **mesma** função morta com corpo **multi-linha** → `33.33% (1/3)`, porque aí as linhas do corpo entram no denominador como não cobertas. A métrica é cega a one-liners nos dois sentidos — não soma quando executam, não denuncia quando estão mortos — e só enxerga função morta se o corpo tiver linhas próprias. Nenhuma linguagem compilada faz isso: lá o denominador vem do binário, aqui vem do que o trace viu.

Some os problemas estruturais: `[[ -n "$x" && -f "$y" ]]` numa linha conta como *uma* linha coberta, independente de quantos ramos você exercitou (não há branch coverage); heredoc conta pelas linhas do comando que o consome, não do conteúdo; e linha executada nunca significou comportamento verificado — `saudacao mundo >/dev/null` cobre 100% de `saudacao` sem afirmar nada.

Sem rodeio: **perseguir 100% em shell é desperdício**. O número é ruidoso demais para ser portão. Use cobertura como **detector de arquivo/função nunca tocada** — o sinal onde a ferramenta é honesta, desde que os corpos tenham linhas próprias — e um piso baixo e estável contra regressão grosseira (bats-core, um projeto de teste, roda com piso de **86.40%**). O esforço que sobra vai onde o CI de shell realmente paga: **matriz de versão de Bash e de OS**. Um bug de Bash 3.2 quebra usuário de macOS de verdade; uma linha não coberta raramente quebra alguém.

### kcov na prática

Invocação: `kcov [OPTIONS] <out-dir> <exec> [args]` — ex.: `kcov --include-path=. coverage/ ./test.sh`.

Instalação: no macOS ARM, `brew install kcov` **funciona** — validado (kcov 43, bottled, puxa `dwarfutils` + `openssl@3`) — e cobre script bash com o método default via `PS4`. O que falha no macOS é `--bash-method=DEBUG`: `Failed to exchange stderr for pipe: Bad file descriptor` / `kcov: error: Can't start/attach to ./test.sh`. Ferramentas que invocam o kcov por conta própria (ex.: `shellspec --kcov`) podem esbarrar nisso; trate cobertura no Mac como best-effort e colete o número oficial em CI/Linux (ou Docker). Em CI não compile; baixe o release, como faz o bats-core: `wget .../releases/download/v42/kcov-amd64.tar.gz && tar -xf kcov-amd64.tar.gz` produz `./usr/local/bin/kcov`. (`--bash-method` é *uncommon option*: só aparece em `kcov --uncommon-options`.)

Filtragem é obrigatória, não opcional. `--include-path`/`--exclude-path` fazem lookup de path real; `--include-pattern`/`--exclude-pattern` comparam string:

```bash
kcov --include-path=./src --exclude-path=/tmp,./vendor coverage/ ./test.sh
kcov --exclude-line='# kcov-ignore' --exclude-region='kcov-off:kcov-on' coverage/ ./test.sh
```

**Armadilha validada**: o kcov varre o diretório do script atrás de outros scripts (`--bash-dont-parse-binary-dir` desliga). Se o `out-dir` estiver *dentro* do `--include-path`, ele reprocessa o próprio HTML/JS recém-gerado como se fossem scripts e o total despenca — observado `0.02% (1/6333)`, com dezenas de entradas fantasma (`index.js`, `codecov.json`, `*.html`). **Mantenha o out-dir fora da árvore de fontes** — é por isso que o bats-core passa `--exclude-path=/tmp`. Com o out-dir fora, o mesmo comando volta a `TOTAL 100.00`.

Cada run gera HTML lcov-style (escrito continuamente durante a execução), `cobertura.xml`, `sonarqube.xml`, `cov.xml` e `coverage.json`. O JSON é o gancho de CI mais útil: `jq '.percent_covered' < coverage/bats/coverage.json`. `--merge` junta runs independentes (`kcov --merge /tmp/out /tmp/kcov-*`), o que importa quando a suíte roda em jobs separados. `--coveralls-id` sobe direto para Coveralls; para Codecov, aponte o uploader ao `cobertura.xml`.

Limitações reais:

- **Só bash/zsh/ksh** — precisa de trap `DEBUG`. `dash`/`sh` puro não tem cobertura; `--bash-handle-sh-invocation` tenta contornar `#!/bin/sh` via `LD_PRELOAD` de `execve` e o próprio manual admite que é bugado (default desligado).
- **Performance**: cada comando executado vira uma linha de trace num fd. Suíte grande fica visivelmente mais lenta.
- **macOS**: só o método `PS4` funciona (ver acima); tudo que depende de `LD_PRELOAD` (`--bash-tracefd-cloexec`, handling de `/bin/sh`) não existe no Mac.

### bashcov e ShellSpec

`gem install bashcov` faz sentido em exatamente um cenário: **o projeto já tem Ruby e SimpleCov** e você quer o relatório de shell no mesmo dashboard do resto. `bashcov --skip-uncovered -- ./test.sh --flags` rastreia todos os scripts executados, faz merge entre suítes (shUnit2, Bats, bash_unit, assert.sh) automaticamente e gera `./coverage/index.html` — configurável por um `.simplecov` na raiz. Fora do ecossistema Ruby, arrastar Ruby + gems para o CI só para medir cobertura de shell não se paga: use kcov.

Se você usa **ShellSpec**, cobertura é feature integrada:

```bash
shellspec --kcov                                # habilita (default: desabilitado)
shellspec --kcov --covdir coverage --kcov-options "--exclude-path=./vendor"
```

Requer kcov v38+ e `--shell bash` (ou zsh/ksh) — aborta com `Kcov v35 or later required` / `Require to use bash/zsh/ksh to run kcov`. Ele já aplica os excludes certos por você (`--exclude-pattern=/.shellspec,/spec/,/coverage/,/report/`), a parte que todo mundo erra na mão. Como ele invoca o kcov por conta própria, no macOS pode falhar mesmo com o kcov do brew funcionando — rode em Linux.

## CI

### GitHub Actions

Padrão extraído do workflow real do `bats-core` (`.github/workflows/tests.yml`). O núcleo do valor é o job 3 — a matriz de versão de Bash via container:

```yaml
name: Tests
on:
  pull_request: { branches: [main] }
  push: { branches: [main] }
permissions:
  contents: read   # menor privilégio; suba só onde precisar

jobs:
  # 1) Lint estático — rápido, falha cedo, roda sozinho.
  #    Flags, códigos e .shellcheckrc: ver portabilidade-e-armadilhas.md.
  lint:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v5
      - name: shellcheck
        run: |
          sudo apt-get update -y && sudo apt-get install -y shellcheck
          shellcheck -s sh scripts/*.sh   # -s sh: análise POSIX para os #!/bin/sh
          shellcheck src/*.bash
      - name: shfmt
        run: |
          curl -sSfL https://github.com/mvdan/sh/releases/download/v3.13.1/shfmt_v3.13.1_linux_amd64 -o shfmt && chmod a+x shfmt
          ./shfmt -i 2 -bn -ci -sr -d .   # -d = diff e exit != 0; não escreve nada

  # 2) Matriz de OS — pega diferença de coreutils (BSD vs GNU sed/date/readlink).
  test-os:
    strategy:
      fail-fast: false      # um OS quebrado não esconde os outros
      matrix:
        os: [ubuntu-22.04, ubuntu-24.04, macos-15]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v5
      - uses: bats-core/bats-action@4.0.0
        id: setup-bats
      - name: Rodar suíte
        # bats precisa de tty, senão tput quebra no runner; no macOS o
        # bats-core usa 'unbuffer bash {0}' (brew install expect).
        shell: 'script -q -e -c "bash {0}"'
        env: { TERM: linux, BATS_LIB_PATH: '${{ steps.setup-bats.outputs.lib-path }}' }
        run: |
          mkdir -p test-results/
          bats test/ --print-output-on-failure \
            --report-formatter junit --output test-results
      # JUnit no mesmo job (mesma suíte, não rode duas vezes): EnricoMi/
      # publish-unit-test-result-action@v2 com `if: always()`, um check_name
      # por OS para não colidir, e `checks: write` nas permissions.

  # 3) Matriz de versão de Bash — AQUI mora o valor real do CI em shell.
  #    3.2 é o Bash do macOS (preso por licença GPLv3): sem arrays associativos,
  #    sem ${x^^}, sem `declare -g`, sem `mapfile`. Suporta Mac? Teste 3.2.
  test-bash-version:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        version: ['3.2', '4.4', '5.2', '5.3']
    steps:
      - uses: actions/checkout@v5
      - name: Bash ${{ matrix.version }}
        run: docker run --rm -v "$PWD:/w" -w /w "bash:${{ matrix.version }}" ./test.sh

  # 4) Cobertura — job separado, Linux, sem bloquear o resto.
  coverage:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v5
      # actions/cache@v4 em ./usr/local/bin/kcov: o binário não muda, cacheie.
      - name: Instalar kcov (release pronto — não compile em CI)
        run: |
          test -x ./usr/local/bin/kcov && exit 0
          wget -q https://github.com/SimonKagstrom/kcov/releases/download/v42/kcov-amd64.tar.gz && tar -xf kcov-amd64.tar.gz
      - name: Coletar
        shell: 'script -q -e -c "bash {0}"'
        env: { TERM: linux }
        # --exclude-path=/tmp e out-dir fora da árvore (ver armadilha acima)
        run: ./usr/local/bin/kcov --exclude-path=/tmp "$PWD/coverage" \
               ./bin/bats --filter-tags '!no-kcov' test/
      - uses: actions/upload-artifact@v5
        with: { name: code-coverage-report, path: coverage/* }
      - name: Piso de cobertura
        env:
          minimum_coverage: '86.40'   # piso baixo e estável — não é meta de 100%
        run: |
          value=$(jq -r '.percent_covered' < coverage/bats/coverage.json)
          echo "Coverage: $value% (mínimo: $minimum_coverage%)" | tee "$GITHUB_STEP_SUMMARY"
          # comparação float sem depender de bc; awk sai 0 quando está ABAIXO do piso
          if awk -v v="$value" -v m="$minimum_coverage" 'BEGIN { exit !(v+0 < m+0) }'; then
            echo "abaixo do mínimo" | tee -a "$GITHUB_STEP_SUMMARY"; exit 1
          fi
```

Notas do padrão real: o bats-core usa `shell: 'script -q -e -c "bash {0}"'` + `TERM: linux` em praticamente **todo** job — sem tty emulado, `tput` quebra e a suíte falha por motivo errado. A matriz de Bash deles vai de `3.2` a `rc` (`3.2, 4.0…4.4, 5.0, 5.1, 5, rc`) sempre por container, nunca por brew — e eles ainda fixam todas as actions por SHA. Alternativas: `mig4/setup-bats` (mais simples, só o bats) e `ludeeus/action-shellcheck` (aceita `severity`, `ignore_paths`, `scandir`, `check_together`) no lugar do `apt-get install`.

### Bash antigo localmente

O truque mais útil para quem tem Mac, e a razão de o job de matriz acima ser barato de reproduzir localmente:

```bash
docker run --rm -v "$PWD:/w" -w /w bash:3.2 ./test.sh
```

Validado: a imagem roda em ARM (`GNU bash, version 3.2.57(1)-release (aarch64-unknown-linux-musl)`) — mesma versão exata do `/bin/bash` do macOS. As tags cobrem `3.0` a `5.3`, mais `devel` e `rc` (`bash:3.2`, `bash:3.2.57`, `bash:4.4`, `bash:5.2`, `bash:5.3-alpine3.24`, …); o entrypoint já é o `bash`. É Alpine/musl: se o script depende de coreutils GNU, instale-os — senão o teste falha por um motivo que não é a versão do Bash.

### Pre-commit

Hook manual, sem framework:

```bash
#!/usr/bin/env bash
# .git/hooks/pre-commit
set -euo pipefail
# Só os arquivos shell staged, NUL-safe contra espaço no nome.
# Sem `mapfile -d ''`: é Bash 4.4+ e o hook roda no Bash 3.2 do macOS.
files=()
while IFS= read -r -d '' f; do files+=("$f"); done < <(
  git diff --cached --name-only -z --diff-filter=ACM -- '*.sh' '*.bash'
)
[[ ${#files[@]} -eq 0 ]] && exit 0
shellcheck "${files[@]}"
shfmt -i 2 -bn -ci -sr -d "${files[@]}"
```

Com o framework `pre-commit` (`.pre-commit-config.yaml` real):

```yaml
repos:
  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: v0.11.0
    hooks:
      - id: shellcheck
        args: [--severity=warning]

  - repo: https://github.com/scop/pre-commit-shfmt
    rev: v3.13.1-1
    hooks:
      - id: shfmt          # binário upstream; variantes: shfmt-src, shfmt-docker
        args: [-i, '2', -bn, -ci, -sr, -w]
```

Os hooks do `pre-commit-shfmt` já filtram por `types: [shell]` com `exclude_types: [csh, tcsh]` — não precisa reinventar o seletor de arquivo.

### Ferramentas adjacentes

- **`shfmt`** — as flags do pipeline acima: `-i 2` indent, `-bn` quebra antes de `&&`/`||`, `-ci` indenta ramos de `case`, `-sr` espaço após redirecionamento, `-d` diff + exit != 0 (CI), `-w` escreve (hook local). `-ln posix|bash|mksh` trava o dialeto. Uso geral: ver `portabilidade-e-armadilhas.md`.
- **`checkbashisms`** (pacote `devscripts`) — complementa `shellcheck -s sh` varrendo script que se declara POSIX atrás de construção que só o Bash tem. Útil para quem publica `#!/bin/sh` para dash/BusyBox.
- **`shellharden`** — reescreve o script inserindo aspas onde faltam, corrigindo mecanicamente a classe de bug mais comum (word splitting/glob acidental). Agressivo: rode uma vez, revise o diff inteiro, nunca em hook automático.
