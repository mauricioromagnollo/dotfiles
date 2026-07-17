# Frameworks de teste para shell

Este arquivo cobre o shunit2 em profundidade, os recursos do bats-core além do básico e as alternativas (ShellSpec, bash_unit e os projetos abandonados), fechando com um comparativo único. O básico do bats — instalação, `@test`, `run`, `$status`/`$output`/`$lines`, `setup`/`teardown`, `load`, `skip`, tmpdirs — está em `references/debug-testes-e-ambiente.md`, junto com o assert caseiro sem framework. Tudo o que está marcado como "validado"/"verificado" aqui foi reproduzido executando os frameworks, não lido em README.

## shunit2

Framework xUnit para shell, escrito em shell POSIX puro. A diferença central para o bats não é a API: é o alvo. O bats exige bash e define uma linguagem própria (`@test`) que precisa ser pré-processada. O shunit2 é um único arquivo `sh` que você faz `.` (source) a partir de um script de teste comum — e por isso roda em `sh`, `dash`, `ksh`, `mksh`, `zsh` e `bash`, incluindo o bash 3.2 que a Apple ainda entrega no macOS. Se o código sob teste é `#!/bin/sh` e precisa rodar em dash no Debian e ksh no AIX, testá-lo com um runner que só roda em bash testa o shell errado. Última release estável: **2.1.8** (o que `brew install shunit2` entrega); o `master` se identifica como `2.1.9pre`. Apache 2.0, ~1600 linhas, zero dependências.

### Instalação

```sh
curl -sLo tests/shunit2 https://raw.githubusercontent.com/kward/shunit2/master/shunit2  # vendorizar
git submodule add https://github.com/kward/shunit2 tests/shunit2                        # submodule
brew install shunit2      # macOS -> /opt/homebrew/bin/shunit2
apt-get install shunit2   # Debian/Ubuntu -> /usr/bin/shunit2
```

Com o pacote de distro o binário está no `PATH`, e como o builtin `.` procura no `PATH`, basta `. shunit2` sem caminho. Vendorizar é o padrão defensável: elimina a variável "qual versão o runner tem".

### `. shunit2` vai na última linha — e isso não é estilo

O shunit2 **não é uma biblioteca que você carrega e depois chama**: sourcear *é* executar a suíte. O bloco `Main` no fim do arquivo descobre os testes, roda tudo, imprime o relatório e termina com `return ${SHUNIT_FALSE}` se algo falhou. Duas consequências, ambas verificadas:

```sh
testA() { assertEquals 1 1; }
. ./shunit2
testB() { assertEquals 2 2; }   # definida DEPOIS do source
echo "esta linha roda?"
```

Saída: `./shunit2: line 1259: testB: command not found`, `FAILED (failures=0)` — e **`exit=0`**. `testB` foi *descoberta* (o grep a viu no texto) mas não *definida* no momento da execução; e o `echo` posterior sobrescreveu o `$?` que o `return` acabara de setar. Suíte vermelha, CI verde. Qualquer linha executável após o `. shunit2` pode destruir o exit code.

### Descoberta de testes: `grep`, não introspecção

Isto explica quase todas as surpresas do framework. Não há `declare -F` nem introspecção: o shunit2 roda `grep -E` **no arquivo-fonte do script pai**, com o regex `^\s*((function test[A-Za-z0-9_-]*)|(test[A-Za-z0-9_-]* *\(\)))`. Daí:

- funções geradas em runtime (via `eval`) nunca são encontradas — não existem como texto;
- o prefixo `test` é obrigatório. `checkAlgo() { assertEquals 1 2; }` **não roda**, não avisa, e a suíte fica verde. Renomear para `xtestFoo` é a forma idiomática (e silenciosa) de desabilitar um teste;
- o shunit2 precisa saber *qual* arquivo grepar, e usa `$0`. No zsh `$0` não sobrevive ao source — daí `SHUNIT_PARENT`;
- `SHUNIT_TEST_PREFIX` (2.1.8+) só muda o *display* no relatório, não a descoberta.

### Anatomia

O ciclo é `oneTimeSetUp` → para cada teste (`setUp` → `testXxx` → `tearDown`) → `oneTimeTearDown`. Todas as quatro são opcionais e sobrescrevíveis; `tearDown`/`oneTimeTearDown` rodam também no trap de `INT`/`TERM`. `setUp`/`tearDown` que retorna não-zero é **fatal** desde a 2.1.8, não um warning — cuidado com `tearDown() { rm -f "$f"; }` cujo último comando pode falhar; termine com `:` ou `|| true`.

Públicas: `SHUNIT_TRUE`(0), `SHUNIT_FALSE`(1), `SHUNIT_ERROR`(2), `SHUNIT_VERSION` e `SHUNIT_TMPDIR` — diretório temporário criado com `umask 077` e removido pelo trap de saída; use-o em vez de inventar `mktemp`. Definidas pelo usuário: `SHUNIT_PARENT`, `SHUNIT_COLOR` (`auto`|`always`|`never`|`none`; valor inválido é fatal), `SHUNIT_TEST_PREFIX`, `SHUNIT_CMD_TPUT`. O README ainda documenta `SHUNIT_CMD_EXPR`, que **não existe mais no fonte do master** — drift de documentação. `suite()` + `suite_addTest` dão ordem explícita, mas o próprio fonte os marca **DEPRECATED desde a 2.1.0**; para rodar um subconjunto, use a linha de comando.

### Assertions

Todas aceitam *message* opcional como **primeiro** argumento e retornam `SHUNIT_TRUE`/`FALSE`/`ERROR`.

| Função | Assinatura | Nota |
| --- | --- | --- |
| `assertEquals` / `assertNotEquals` | `[msg] expected actual` | comparação de string (`=`), sempre |
| `assertSame` / `assertNotSame` | `[msg] expected actual` | **deprecated**: aliases dos dois acima |
| `assertContains` / `assertNotContains` | `[msg] container content` | substring via `grep -F` |
| `assertNull` / `assertNotNull` | `[msg] value` | `test -z` / `test -n` |
| `assertTrue` / `assertFalse` | `[msg] condition` | inteiro **ou string com `eval`** |

Os `fail*` **não comparam nada** — só registram falha com mensagem formatada: `fail [msg]` → `ASSERT:msg`; `failNotEquals [msg] unexp act` e `failNotSame [msg] exp act` → `ASSERT:msg expected:<1> but was:<2>`; `failSame [msg] exp act` → `ASSERT:msg expected not same`; `failFound`/`failNotFound [msg] content` → `ASSERT:msg found:<x>` / `not found:<x>`. O README diz que os `fail*` "fail the test immediately". **É falso** — verificado: registram a falha e a função continua executando. Não há abort; para parar, dê `return` explícito.

Macros de line number (`${_ASSERT_EQUALS_}`, `${_ASSERT_TRUE_}`, …) prefixam a mensagem com `[linha]`. Exigem **aspas duplicadas** nos argumentos (são `eval`: `${_ASSERT_EQUALS_} '"msg"' 1 2`) e só funcionam onde `$LINENO` existe — bash>=3, ksh, mksh, zsh. Em dash devolvem `[0]`, silenciosamente inútil, em vez de erro.

### Skipping

`startSkipping` neutraliza os asserts seguintes (contam como skipped, não somem do total); `endSkipping` restaura; `isSkipping` consulta. O runner chama `endSkipping` no início de **cada** teste, então o escopo nunca vaza. Skips não deixam a suíte vermelha — o exit code segue 0. O idioma canônico é pular o que não se aplica ao shell atual: `[ -z "${BASH_VERSION:-}" ] && startSkipping` no topo do teste, que então reporta `OK (skipped=1)`.

### Runner, saída e CI

O relatório conta **asserts** em `failures=`, não testes (`Ran N tests` conta testes). Exit: 0 sucesso, 1 falhas, 2 (`SHUNIT_ERROR`) erro de framework. O modo *standalone* — `shunit2 ./meu_test.sh` — só funciona se o arquivo de teste **não** sourcear o shunit2: existe um guard `if test -n "${SHUNIT_VERSION:-}"; then exit 0; fi` no topo, e a segunda carga mata a suíte ("Ran 0 tests"). Escolha um modo e fique nele.

Opções exigem o separador `--`, e isso morde:

```sh
./meu_test.sh --suite-name=x        # FATAL unable to read from --suite-name=x  (exit 2)
./meu_test.sh -- --suite-name=x     # ok
./meu_test.sh -- testApenasEste     # roda só um teste
./meu_test.sh -- --output-junit-xml=results.xml
```

Sem `--`, o `$1` é lido como *nome do arquivo de testes* (modo standalone). As únicas opções aceitas são `--suite-name=` e `--output-junit-xml=`; qualquer outra `--*` é fatal. JUnit XML + `SHUNIT_COLOR=never` cobrem CI sem plugin nenhum.

### Armadilhas

**1. `set -e` não funciona — e falha aberto.** Documentado nas release notes ("shUnit2 does not work when the `-e` shell option is set") e pior do que parece: o runner invoca o teste como `if ! eval ${_shunit_test_}`, e POSIX manda ignorar `-e` dentro de contexto de condição. `set -e` fica **inteiramente neutralizado dentro dos testes**: com `set -e` no topo do arquivo, um `false` no meio de um `testXxx` não aborta nada — o teste segue e **passa**. Não conte com `set -e` para transformar setup quebrado em falha; asserte explicitamente.

**2. `assertTrue`/`assertFalse` fazem `eval` da string.** Se o argumento não parece inteiro, é `eval`ado — execução arbitrária:

```sh
evil="[ 1 -eq 2 ] || touch ./PWNED"
assertTrue "${evil}"   # cria o arquivo — e o teste PASSA (touch retorna 0)
```

Nunca interpole dado de teste na condição. E como o `eval` reparsa no diretório corrente, globs expandem no momento do assert — a **mesma** asserção muda de resultado conforme o conteúdo do diretório:

```sh
# com dois *.txt: expande p/ `[ -f a.txt b.txt ]` -> erro de sintaxe -> eval falha
assertFalse "[ -f *.txt ]"   # PASSA
assertTrue  "[ -f *.txt ]"   # FALHA
# com um único *.txt os dois resultados INVERTEM.
```

No fonte, `assertTrue` usa `eval "${cond}"` e `assertFalse` usa `eval ${cond}` (sem aspas, com `# shellcheck disable=SC2086`) — assimetria real. Prefira avaliar você mesmo e passar o exit code: `[ -f "${f}" ]; assertTrue $?`.

**3. A mensagem opcional engole argumentos.** `assertEquals` aceita 2 **ou** 3 argumentos e decide pelo `$#`. Valores não quotados com espaço mudam a contagem e o primeiro vira "mensagem":

```sh
a="a b"; b="cd"
assertEquals $a $b     # 3 args -> msg="a", expected="b", actual="cd"
# ASSERT:a expected:<b> but was:<cd>     <-- falha pelo motivo errado
assertEquals "$a" "$b" # 2 args -> correto
```

Com 4 args vira `shunit2:ERROR ... requires two or three arguments`. Quote sempre.

**4. `$?` é consumido pelo assert anterior.** Todo assert sobrescreve `$?`. Capture imediatamente: `meu_comando; rc=$?` e depois `assertEquals 0 "${rc}"`.

**5. zsh precisa de duas concessões.** `setopt shwordsplit` (senão é fatal — e a *própria* mensagem de fatal quebra com `command not found: echo -e`) e `SHUNIT_PARENT=$0`. Pior: por padrão (opção `FUNCTION_ARGZERO`) o zsh **reescreve `$0` para o arquivo sourceado**, quebrando o guard clássico de "script que também é biblioteca" — `sh`/`bash` dão `$0` = `sh`/`bash`, o zsh dá `./probe.sh`, o bloco main dispara e dá `exit` no meio do teste. Por isso o exemplo abaixo usa variável de guard em vez de `[ "${0##*/}" = 'slugify.sh' ]`.

### Exemplo completo

```sh
#! /bin/sh
# slugify.sh
slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//'
}
# Guard portável: o teste exporta SLUGIFY_LIB=1 antes de sourcear.
# NÃO use `[ "${0##*/}" = slugify.sh ]`: no zsh o $0 vira o arquivo sourceado.
if [ -z "${SLUGIFY_LIB:-}" ]; then
  [ $# -eq 1 ] || { echo "uso: slugify.sh <titulo>" >&2; exit 2; }
  slugify "$1"; echo
fi
```

```sh
#! /bin/sh
# slugify_test.sh
SHUNIT_PARENT="$0"; [ -n "${ZSH_VERSION:-}" ] && setopt shwordsplit
oneTimeSetUp() { SLUGIFY_LIB=1 . ./slugify.sh; }   # carrega a função 1x, sem rodar o main
setUp()    { workdir="${SHUNIT_TMPDIR}/work"; mkdir -p "${workdir}"; }
tearDown() { rm -rf "${workdir}"; }
testBasico()      { assertEquals 'hello-world' "$(slugify 'Hello World')"; }
testPontuacao()   { assertEquals 'a-b' "$(slugify 'a!!!b')"; }   # pontuação repetida colapsa
testAcentoVira()  { assertEquals 'c-o' "$(slugify 'cão')"; }  # UTF-8: 'ã' colapsa em UM '-'
testVazio()       { assertNull "$(slugify '')"; }
testIdempotente() {
  s="$(slugify 'Já Slugificado')"
  assertEquals "${s}" "$(slugify "${s}")"
}
testCliSemArgs() {
  ./slugify.sh >"${workdir}/out" 2>"${workdir}/err"
  assertEquals 'exit code' 2 $?        # $? capturado ANTES de qualquer outro assert
  assertContains "$(cat "${workdir}/err")" 'uso:'
}
. ./shunit2
```

```
$ for s in sh bash dash ksh zsh; do $s ./slugify_test.sh >/dev/null 2>&1; echo "$s exit=$?"; done
sh exit=0    bash exit=0    dash exit=0    ksh exit=0    zsh exit=0
```

`testAcentoVira` merece atenção: a expectativa ingênua era `ca-o`, e a suíte devolveu `c-o` — `ã` é multibyte em UTF-8 e o `sed` colapsa a sequência inteira de bytes não-alfanuméricos em um único `-`. O teste estava errado, não o script; é o tipo de premissa de encoding que só aparece executando. Note também `testCliSemArgs`: sem o helper `run` do bats, capturar saída e exit code do CLI é redirecionamento manual para arquivo — esse é o preço da portabilidade.

## bats além do básico

Referência: bats-core **1.13.0** (nov/2025); o básico está em `references/debug-testes-e-ambiente.md`. O bash 3.2.57 do macOS é oficialmente suportado — o problema não é rodar o bats, é a semântica do bash 3.2 dentro dos testes (ver `[[ ]]` adiante).

### `bats_require_minimum_version` e o sistema de warnings

Sem declarar a versão mínima, features novas **degradam em silêncio**: antes da 1.5.0 o `run` tratava qualquer argumento como parte do comando, então `run --separate-stderr foo` não ativava a flag — tentava *executar* `--separate-stderr`. O teste não quebrava, passava errado. Chame `bats_require_minimum_version 1.5.0` no topo do arquivo, em `setup()` ou `setup_file()`. Existe desde a 1.7.0 (antes, ela mesma falha; use `bats-backports` em migração). Além de travar a versão, informa o *floor* ao bats, que passa a dar warnings mais precisos — que saem no fim da execução e **não falham a suíte**: em CI viram ruído que ninguém lê. Trate-os como erro.

| Código | Significado | Correção |
| --- | --- | --- |
| `BW01` | comando do `run` saiu com 127 (command not found) | `run -127 cmd` se intencional; senão corrija o typo |
| `BW02` | feature exige versão maior | `bats_require_minimum_version <ver>` |
| `BW03` | `setup_suite` definido em `.bats` e nunca executado | mova para `setup_suite.bash`; ou `BATS_SETUP_SUITE_COMPLETED='suppress BW03'` |

`BW01` existe porque `run` sempre sucede: um typo vira status 127 e o teste passa. Validado: `run comndo-com-typo --flag` sem assert → **ok 1** + BW01.

### `run` avançado

```bats
run -1 foo arg     # assert de status embutido (0-255); falha se != 1   [1.5.0+]
run ! foo          # exige status não-zero (1-255); falha se suceder     [1.5.0+]
run -127 foo       # declara intenção e silencia BW01
```

Por padrão `$output` mistura stdout e stderr; `--separate-stderr` separa em `$output`/`$stderr` e `${lines[@]}`/`${stderr_lines[@]}` (validado com `run --separate-stderr bash -c 'echo O; echo E >&2'` → `$output=O`, `$stderr=E`). `--keep-empty-lines` preserva linhas vazias em `${lines[@]}` — por padrão somem (validado: `printf 'a\n\nb\n'` dá 2 linhas sem a flag, 3 com). `$BATS_RUN_COMMAND` guarda a string executada. Na CLI, `--verbose-run` faz todo `run` imprimir `$output`; `--errexit` liga `set -e` dentro do comando do `run`.

### `run` e pipes: `bats_pipe`

O bash parseia o pipe **fora** do `run`: `run echo foo | grep bar` é `(run echo foo) | grep bar`. O `run` roda no subshell do pipe, `$output` chega **vazio** no teste (validado), e o `grep` recebe a saída já capturada — nada. O teste vira decoração.

```bats
run bats_pipe foo \| bar       # \| escapado; bats_pipe sem \| sempre falha, de propósito
run bats_pipe -0 foo \| bar    # -0 / --returned-status N: força o status de um comando específico
```

Propaga status como `set -o pipefail` (último não-zero). Alternativas antigas: `run bash -c 'echo foo | grep bar'` ou embrulhar o pipe numa função.

### Armadilhas que fazem o teste passar errado

**`run` mascara falha.** É um wrapper que *sempre* retorna 0. Sem assert em `$status`, o teste passa. Validado: `run false` sozinho → **ok**.

```bats
run -0 cmd    # equivale a apenas 'cmd', porque o bats já roda com set -e
cmd           # prefira isto para "tem que dar certo"
run ! cmd     # mas para "tem que falhar", USE run
```

**Negação e `[[ ]]` não disparam `set -e`.** O bash deliberadamente não aborta em comandos negados: `! true` no meio do teste **não falha** (validado); só falharia como último comando, onde o status vira o retorno da função — use `run ! cmd` ou `! x || false`. E `[[ ]]`/`(( ))` não abortam no bash 3.2: o tratamento de `set -e` mudou no bash 4.1, e no macOS (3.2.57) `[[ 1 -eq 2 ]]` no meio do teste **passa** (validado). `[ ]` não sofre disso; ` || false` funciona sempre — `[[ "$x" == foo ]] || false` é portável e à prova de bash 3.2.

**`run` roda em subshell e variáveis não persistem entre `@test`s.** Função que devolve resultado por variável não funciona sob `run` — a mudança morre no subshell; teste essas funções **sem** `run`. Cada teste é um processo: validado, `MINHA_VAR` do t1 chega vazia no t2. Compartilhe com `export` em `setup_file` (visível a `setup`, teste, `teardown`, `teardown_file` — validado) ou grave em disco. **`cd` não vaza entre `@test`s** (validado), mas **vaza** do teste para o seu `teardown` e de `setup_file` para todos os testes do arquivo (ambos validados) — um `cd` em `setup_file` reposiciona o arquivo inteiro. E **`return 1` não é "true"**: convenção do bash é 0 = sucesso.

**Loop não registra testes.** `@test` é pré-processado em função; um `for` só redeclara a mesma função. Registre via `bats_test_function --description "$i ..." --tags t:$i -- test_body $i` dentro do loop, com o corpo numa função que recebe `$1` (não o `$i` do loop).

**Não dá para passar parâmetros** a arquivos ou testes (nem via shebang) — use variáveis de ambiente. **`load` não carrega `.sh`** (ele acrescenta `.bash`; para `.sh`, `source` — daí a convenção `.bats` para testes, `.bash` para helpers; o shellcheck entende `.bats` desde a 0.7), e `declare` no arquivo carregado não escapa do escopo do `load` (use `declare -g`). **Tarefas em background travam a suíte**: o filho herda o FD 3 e o bats espera esse FD fechar — feche com `cmd_longo 3>&-`.

### Bibliotecas: bats-assert, bats-file, bats-mock

**bats-assert** (exige bats-support carregado antes):

```bats
load '../libs/bats-support/load';  load '../libs/bats-assert/load'
assert_success                       # / assert_failure [17] — aceita o status esperado
assert_output 'exato';  assert_output --partial 'trecho';  assert_output --regexp '^linha um'
assert_output - <<< $'a\nb'          # '-' lê o esperado do stdin (multi-linha)
assert_line --index 1 'linha dois';  assert_line --index 0 --partial 'um'
assert_equal "$status" 0             # / assert_not_equal
assert [ -f "$f" ]                   # / refute — avalia expressão
refute_output --partial 'inexistente'
assert_stderr --partial 'problema'   # exige run --separate-stderr
```

`--` desliga o parsing de opções (`assert_output -- '-p'`). Há ainda `assert_regex`, `refute_line` e `assert_stderr_line`, com seus `refute_*`.

**bats-file** — os nomes reais são `_exists`, não `_exist`; todos têm par negativo (`assert_file_not_exists`, `assert_not_symlink_to`, ...):

```bats
assert_file_exists "$f";   assert_dir_exists "$d";   assert_exists "$path"
assert_file_permission 640 "$f";   assert_symlink_to "$alvo" "$link"   # alvo primeiro
assert_file_empty "$f";   assert_file_contains "$f" regex;   assert_files_equal a b
```

**bats-mock** — dois projetos incompatíveis. Use **jasonkarns/bats-mock** (ativo, API `stub`/`unstub`); grayhemp/bats-mock está parado desde 2023 e usa outra API (`mock_create`/`mock_get_call_args`).

```bats
load '../libs/bats-mock/stub'
setup()    { stub date "-r 222 : echo 'FAKE DATE'"; }  # plano: args esperados : comando a rodar
teardown() { unstub date; }
```

Cada linha do plano é uma invocação esperada, na ordem. O `stub` symlinka o `binstub` em `${BATS_MOCK_BINDIR}` (injetado no `PATH`) e grava as chamadas num *run file* em `${BATS_MOCK_TMPDIR}`. O `unstub` remove o stub **e verifica** que o plano foi cumprido — plano pendente faz o `unstub` retornar não-zero (validado); args divergentes fazem a invocação falhar. Ao stubar uma *função*, dê `unset` nela: a função sombreia o binstub no `PATH`.

### `setup_suite` e a ordem exata

Ordem validada com dois arquivos e um `setup_suite.bash`:

```text
setup_suite                            # só de setup_suite.bash, uma vez por execução
  setup_file                           # ao entrar no arquivo 1
    setup / test1 / teardown  ;  setup / test2 / teardown
  teardown_file
  setup_file / setup / test3 / teardown / teardown_file    # arquivo 2
teardown_suite
```

`setup_suite` **precisa** morar em `setup_suite.bash` (descoberto na pasta do primeiro `.bats`, ou via `--setup-suite-file`). Se o arquivo existir, deve definir `setup_suite`; `teardown_suite` é opcional. Definido num `.bats`, gera BW03 e não executa. `teardown` falha o teste se retornar não-zero — mas ERREXIT está **desligado** ali: um comando que falha no meio não interrompe o resto nem falha o teste; só o *último* comando (ou `return 1` explícito) decide.

Três tmpdirs com escopos distintos (validados como diretórios separados):

| Variável | Escopo | Uso |
| --- | --- | --- |
| `BATS_SUITE_TMPDIR` | toda a execução | fixtures caras compartilhadas entre arquivos |
| `BATS_FILE_TMPDIR` | um arquivo `.bats` | estado montado em `setup_file` |
| `BATS_TEST_TMPDIR` | um `@test` | tudo o mais — isolamento por teste, de graça |

### Execução: paralelismo, filtros, tags e formatters

```bash
bats --jobs 4 test/                 # exige GNU parallel (ou shenwei356/rush)
bats -f 'regex'                     # --filter por nome; --negative-filter inverte
bats --filter-tags slow,!flaky      # conjunção; repetir a flag = disjunção
bats -T                             # --timing: duração por teste;  -x = set -x nos comandos
bats -F tap13                       # --formatter: tap13|junit|pretty|/abs/path (pretty no TTY)
bats --report-formatter junit --output ./reports   # gera reports/report.xml para CI
```

`--jobs` sem GNU parallel **não roda nada**: sai com 1 e "Executed 0 instead of expected N tests" (validado no macOS sem parallel). Paralelismo quebra suítes com estado compartilhado, ordem entre testes ou escrita em local comum — a ordem não é garantida; ao ligar pela primeira vez, rode várias vezes para caçar dependências ocultas. Controles finos: `--no-parallelize-across-files`, `--no-parallelize-within-files`, ou `export BATS_NO_PARALLELIZE_WITHIN_FILE=true` em `setup_file`.

`# bats file_tags=integration` aplica a todos os testes **abaixo** da diretiva no arquivo; `# bats test_tags=slow, db:pg` aplica só ao **próximo** `@test` e depois é esquecida. Tags são case-sensitive, sem espaços, só alfanumérico + `_ - :`; o prefixo `bats:` é reservado. `bats:focus` filtra todos os outros testes — e o bats **força exit 1** mesmo em sucesso, para que um focus commitado por engano não deixe o CI verde rodando 3 testes (`BATS_NO_FAIL_FOCUS_RUN=1` desativa; nunca comite isso).

### Debug e o porquê do FD 3

O bats emite TAP na saída padrão. Para não corromper esse stream, ele separa o output do código sob teste do output do próprio bats: **o FD 3 escapa do formatter e vai direto ao terminal** — essa é a razão real, não convenção estética. `echo 'x'` (stdout/stderr) num teste é capturado e exibido **só quando o teste falha**; `echo '# x' >&3` é sempre visível e entra no stream TAP (prefixe com `#`, senão parsers de terceiros engasgam). Fora de funções, evite imprimir: o arquivo é avaliado *n+1* vezes e a mensagem se repete. Como o FD 3 é herdado por filhos, processo em background segura o pipe e **trava** o bats.

```bash
bats --print-output-on-failure       # imprime $output nos testes que falharam
bats --show-output-of-passing-tests  # ... e nos que passaram
```

Validado: sem a flag, o teste que falha mostra só a linha do assert; com ela sai também `# Last output:` com a pista real. Prefira isso a `echo` manual — ou bats-assert, que já imprime o output no diff da falha.

## ShellSpec e os outros

bats e shunit2 dominam o assunto, mas nenhum dos dois faz mocking nativo, teste parametrizado ou cobertura. Quem precisa disso tem opções — e a maioria delas está morta.

### ShellSpec

BDD de verdade para shell script, escrito em POSIX sh puro. Não é um runner de bash: é um **transpilador**. A DSL (`Describe`/`It`/`When`/`The`) não é sintaxe de shell válida — o ShellSpec traduz o specfile para shell script antes de executar. É por isso que consegue oferecer `Parameters` e `The line 2 of output` sem hack de `eval`.

A consequência prática: a **mesma suite roda em qualquer shell** via `--shell`. Verificado — os specs abaixo passam idênticos em bash 3.2, zsh, `/bin/sh` (dash-like) e ksh, sem uma linha alterada. Suporte declarado vai de `bash >= 2.03` a `busybox ash`, `mksh`, `yash`, `posh`.

O código sob teste (`lib/retry.sh`, POSIX puro):

```sh
retry() {
  max=$1; shift
  n=0
  while :; do
    n=$((n + 1))
    if "$@"; then return 0; fi
    if [ "$n" -ge "$max" ]; then
      echo "retry: falhou apos $n tentativas" >&2
      return 1
    fi
    sleep 1
  done
}
parse_port() {
  case $1 in
    *[!0-9]*|'') echo "porta invalida: $1" >&2; return 2 ;;
  esac
  [ "$1" -ge 1 ] && [ "$1" -le 65535 ] || { echo "fora de faixa: $1" >&2; return 2; }
  echo "$1"
}
```

O specfile (`spec/retry_spec.sh`):

```shellspec
Describe 'retry.sh'
  Include lib/retry.sh          # carrega o script no MESMO shell — funcoes ficam testaveis
  Describe 'parse_port()'
    # teste parametrizado nativo: 1 bloco It vira 5 examples distintos
    Parameters
      "8080"  0 "8080"
      "0"     2 ""
      "70000" 2 ""
      "abc"   2 ""
      ""      2 ""
    End
    It "valida a porta '$1'"
      When call parse_port "$1"       # 'call' = funcao no shell atual, sem subshell
      The status should eq "$2"
      The output should eq "$3"
      if [ "$2" -ne 0 ]; then
        The stderr should not eq ""   # erro vai pro stderr, nunca pro stdout
      fi
    End
  End
  Describe 'retry()'
    It 'nao repete quando o comando sucede de primeira'
      # Mock command-based: gera um script temporario e o poe no inicio do PATH
      Mock sleep
        echo "sleep NAO deveria ser chamado" >&2
      End
      When call retry 3 true
      The status should be success
      The stderr should eq ""
    End
    It 'desiste apos max tentativas'
      Mock sleep
        :                              # neutraliza o sleep: suite roda em ms, nao em segundos
      End
      When call retry 2 false
      The status should eq 1
      The stderr should include 'falhou apos 2 tentativas'
    End
  End
End
```

Resultado real: `7 examples, 0 failures` em 0.43s, e o mesmo número em zsh, sh e ksh. Os pontos que importam:

- **`When call` vs `When run`**: `call` executa a função no shell corrente (variáveis globais visíveis, cobertura medida); `run` executa em subshell. `When run script foo.sh` e `When run source foo.sh` ignoram o shebang e rodam no shell do spec — é assim que se testa um script inteiro multi-shell.
- **Mocking em duas camadas.** Function-based mock é só redefinir a função. `Mock`/`End` é command-based: gera um script externo em um diretório no início do `PATH`. Isso mocka `docker-compose` (hífen não é nome de função POSIX) e funciona quando o código sob teste chama o comando de dentro de um processo externo — coisa que o `fake` do bash_unit não alcança. O preço: não mocka builtin, e para ver variáveis externas elas precisam estar exportadas ou usar `%preserve`.
- **`Data`** injeta stdin sem heredoc indentado; **`%text`** faz o mesmo para strings esperadas. Ambos usam prefixo `#|`, então a indentação do bloco não vaza para o dado.
- **`Skip if 'motivo' funcao`** — atenção: o segundo argumento é **nome de função**, não um comando com argumentos. `Skip if 'x' [ ! -x /bin/foo ]` não funciona. `Pending` marca o inverso (deve falhar).
- **Aviso de output não verificado.** Se o `When` produz stdout e nenhum `The output` o assere, o ShellSpec marca `WARNED` e isso **afeta o status da suite**. Validado na prática: um `docker --version` sem assertion de output derrubou o run. É um default agressivo e correto — output não asserido é teste cego.
- **Saída e CI**: `--format tap`, `--format junit`, `--output junit` (gera `report/results_junit.xml`), `--jobs N` para paralelismo. Verificado TAP com `--jobs 4`: numeração consistente.
- **Cobertura via kcov** — e aqui vai o aviso honesto: **kcov é Linux-only na prática**. Com kcov instalado via Homebrew no macOS, `shellspec --kcov` aborta com `Failed to exchange stderr for pipe / Can't start/attach`. kcov depende de `ptrace`, que o Darwin não entrega. Cobertura de shell script é feature de CI Linux, não de laptop. Mesmo no Linux, só mede o que passa por `Include`, `When call` e `When run script`/`run source` — comando externo não é medido.

**Estado de vida:** vivo, porém estagnado. 1385 stars, não arquivado, mas a última release é a **0.28.1 de 11/01/2021** e o último commit no master é de **12/09/2024**. Cinco anos sem release; o README documenta features não lançadas. Não está morto — está parado, e a documentação anda à frente do binário que você baixa.

### bash_unit

O oposto do ShellSpec: sem DSL, sem transpilação. Funções `test_*` num arquivo bash, `source` no script sob teste, pronto. Repo migrou de `pgrange/bash_unit` para **`bash-unit/bash_unit`** (o path antigo redireciona, mas o `install.sh` correto é o da org nova).

```bash
source ./retry.sh
setup() { rm -f /tmp/bu_sleep_calls; }   # roda antes de CADA teste
test_parse_port_aceita_porta_valida() {
  assert_equals "8080" "$(parse_port 8080)"
}
test_parse_port_rejeita_nao_numerico() {
  assert_status_code 2 "parse_port abc"   # distingue codigo de erro, nao so "falhou"
}
test_parse_port_mensagem_de_erro() {
  assert_matches "porta invalida" "$(parse_port abc 2>&1)"
}
test_retry_nao_dorme_no_sucesso_imediato() {
  # 'fake' substitui o comando por codigo inline pelo resto do teste
  fake sleep 'echo x >> /tmp/bu_sleep_calls'
  assert "retry 3 true"
  assert_fail "test -e /tmp/bu_sleep_calls" "sleep nao deveria ser chamado"
}
test_retry_desiste_apos_max() {
  fake sleep true
  assert_status_code 1 "retry 2 false"
}
```

Resultado real: `6 tests, Overall result: SUCCESS` no bash 3.2.57 do macOS — sem exigir bash 4+, o que já é mais do que muitos scripts do ecossistema conseguem. Assertions: `assert`, `assert_fail`, `assert_equals`, `assert_not_equals`, `assert_matches`, `assert_not_matches`, `assert_status_code`, `assert_within_delta` (só inteiros), `assert_no_diff`, `fail`. Hooks: `setup`/`teardown` por teste, `setup_suite`/`teardown_suite` por arquivo. `todo_*` no lugar de `test_*` marca não-implementado sem quebrar a suite. `-p`/`-s` filtram e pulam por pattern, `-r` randomiza a ordem dentro do arquivo, `-f tap` dá TAP.

O `fake` é o diferencial e a armadilha. Ele define uma **função bash** sobrepondo o comando — logo: não sobrevive a `exec`, não vale para builtins (a doc lista explicitamente `exit`, `eval`, `export`, `trap`, `echo`, `[` como coisas que você não deve fakear), e a função auxiliar precisa de `export -f` para existir em subprocesso. Pior: **assertion dentro de um fake não funciona de forma confiável** — se o fake está num pipeline, o status dele se perde no `$?` do último comando. A doc é honesta sobre isso e ensina o caminho correto: o fake grava `${FAKE_PARAMS[@]}` num arquivo ou `coproc`, e o teste assere depois. Vale ler essa seção antes de confiar em spy.

Quando vale: você quer as assertions e o stack trace com arquivo:linha que o bats não te dá tão direto, e não quer aprender DSL nenhuma. Bash-only. **Estado de vida:** vivo e o mais ativo dos alternativos. 635 stars, release **v2.3.3 em 28/08/2025**, último push em **11/02/2026**. Tem hook de `pre-commit`, está no Homebrew, nixpkgs e AUR.

### assert.sh e shpec — abandonados

**assert.sh** (490 stars): interface mínima — `assert "echo test" "test"`, `assert_raises "false" 1`, `assert_end suite`. Sem mocking, sem hooks, sem parametrização. Ainda ostenta badge do Travis CI, que morreu para open source. Último push em **21/01/2022**. Não arquivado formalmente, mas parado há quatro anos. Não comece nada novo com ele.

**shpec** (386 stars): BDD com `describe`/`it`/`end` e `assert matcher args`. Sintaxe agradável, ideia certa — foi essencialmente superado pelo ShellSpec, que faz o mesmo com muito mais rigor. Último push em **19/12/2022**. Idem: morto na prática. Ambos são interessantes como leitura (`assert.sh` tem ~200 linhas e ensina bastante sobre como se implementa um harness), mas adotá-los hoje é escolher dívida técnica de graça.

## Qual usar

| | Shells | Mock nativo | Parametrizado | Cobertura | Paralelo | TAP / JUnit | Deps | Vivo? | Curva |
|---|---|---|---|---|---|---|---|---|---|
| **bats-core** | bash | não (bats-mock externo) | não | não | sim (`-j`) | TAP / JUnit | bash 3.2+ | **sim** (push 07/07/2026, 6.1k★) | baixa |
| **shunit2** | sh, bash, dash, ksh, zsh | não | não | não | não | JUnit (sem TAP) | nenhuma (1 arquivo) | **sim** (push 15/03/2026, 1.7k★) | baixa |
| **ShellSpec** | **todos POSIX** (bash 2.03+, dash, ksh, zsh, mksh, busybox…) | **sim** (function + command-based) | **sim** (`Parameters`, 4 estilos) | **sim** (kcov, Linux-only) | sim (`--jobs`) | TAP / JUnit | kcov só p/ cobertura | **parado** (release 01/2021, commit 09/2024, 1.4k★) | **alta** (DSL própria) |
| **bash_unit** | bash | `fake` (limitado) | não | não | não | TAP | bash 3.2+ | **sim** (v2.3.3 08/2025, push 02/2026, 635★) | baixa |
| **assert.sh** | bash | não | não | não | não | não | nenhuma | **não** (02/2022) | mínima |
| **shpec** | bash, zsh | não | não | não | não | não | nenhuma | **não** (12/2022) | baixa |

**bats-core é o default para bash, e ponto.** Maior ecossistema, bats-assert/bats-support/bats-file cobrem as assertions que faltam, todo mundo já viu, CI de qualquer lugar entende o TAP. Ele também não sofre os defeitos estruturais do shunit2: sem descoberta por `grep`, sem `eval` de condição. Não existe razão para começar em outra coisa se o alvo é bash e a suite é normal.

**shunit2 quando o alvo é `/bin/sh` de verdade ou o ambiente é restrito.** Dash no Debian, ash no Alpine/BusyBox, ksh em AIX/Solaris, bash 3.2 do macOS: teste *no shell de produção*. Um arquivo vendorizado, zero dependências, serve para container mínimo e CI sem bash. O trade-off é ergonomia: `eval` em condição, `set -e` inerte, descoberta textual, sem `run`, sem paralelismo, e assertion de output vai ser `assert_equals "$expected" "$(cmd)"` na mão.

**ShellSpec quando a suite é grande e você realmente precisa do que ele tem:** mock de comando externo, teste parametrizado sem copiar-colar, cobertura em CI Linux, e a mesma suite validando o script em cinco shells. É o único que entrega isso. O custo é real: DSL própria que não é shell (seu editor e seu shellcheck não entendem o specfile), curva de aprendizado maior que a dos outros somados, e um projeto sem release desde 2021. A 0.28.1 é estável e funciona — validada em quatro shells — mas não conte com correção rápida de bug.

**bash_unit quando você quer assertions decentes sem DSL** e a suite é bash-only e média. É a escolha de menor atrito depois do bats, e o mais bem mantido dos alternativos. Se o bats te irrita pelo `run` + `$status` + `$lines`, ele é o substituto direto.

**Nenhum framework quando o script tem 50 linhas.** Meia dúzia de `[ "$(cmd)" = "esperado" ] || { echo "FALHOU: cmd"; exit 1; }` resolve, não adiciona dependência, e qualquer um lê (o assert caseiro está em `references/debug-testes-e-ambiente.md`). Framework de teste para script pequeno é o mesmo erro que abstração prematura: você paga o setup, o CI, o onboarding e a instalação em troca de nada. Suba para bats quando a suite passar de ~10 casos ou quando precisar de setup/teardown de verdade — não antes.
