# Processos e Concorrência

Modelo mental de como o Bash resolve um nome de comando, cria processos e propaga sinais e exit status. Quase todo bug "misterioso" de shell — variável que não persiste, script que ignora Ctrl-C, container que demora 10s para morrer, `set -e` que não dispara — cai em um dos buracos abaixo.

## Ordem de busca de comando

A ordem real é: **alias → função → builtin → hash → PATH**. Se o nome contém uma barra (`/usr/bin/ls`, `./script.sh`), nada disso acontece: o Bash executa o caminho direto.

```bash
type -a python      # mostra TODAS as resoluções, na ordem: alias, função, builtin, arquivos no PATH
command -v python   # imprime só a que vai ser usada — é isto que você quer em script
builtin cd /tmp     # força o builtin, ignorando função chamada "cd"
command ls          # pula alias e função, mas ainda usa builtin/PATH
enable -n echo      # desliga o builtin echo; agora /bin/echo ganha
hash -r             # limpa o cache de caminhos
```

Aliases são expandidos **na leitura do comando**, não na execução. Por isso um alias definido dentro de uma função não vale para os comandos da mesma função — a função inteira já foi lida. E por isso aliases são inertes em scripts não interativos (`expand_aliases` está off). Não use alias em script; use função.

O **hash** é um cache de `nome → caminho absoluto`. Instalou uma versão nova em um diretório que precede o antigo no PATH e o shell continua chamando a velha? O hash está velho: `hash -r`. Em script de CI que instala uma ferramenta e a chama em seguida, isso evita um bug intermitente.

### Por que `which` é pior que `command -v`

`which` é um binário externo (ou, em alguns sistemas, um script csh) que **não sabe nada sobre o seu shell**: não vê funções, não vê builtins, não vê aliases, e pode ler um PATH diferente. `command -v` é builtin, conhece a ordem real de resolução e é POSIX.

```bash
# ERRADO: dá falso negativo para builtin/função, e o exit status varia entre sistemas
if which cd >/dev/null; then ...

# CERTO
if command -v rg >/dev/null 2>&1; then ...
```

## Fork, subshell e ambiente

Um **subshell** é uma cópia do shell via `fork()`, sem `exec`. Ele herda tudo (variáveis exportadas *e não exportadas*, funções, FDs abertos, diretório atual, traps — que são resetados para o default se não forem ignorados), mas **nada que ele muda volta para o pai**. Criam subshell:

- `( ... )` — agrupamento explícito
- cada estágio de um pipeline `a | b | c`
- `$( ... )` e crases — substituição de comando
- `cmd &` — comando assíncrono
- `<( ... )` / `>( ... )` — substituição de processo
- `coproc`

`BASH_SUBSHELL` é incrementado a cada nível de subshell — útil para diagnosticar onde você está.

```bash
echo $BASH_SUBSHELL          # 0
( echo $BASH_SUBSHELL )      # 1
( ( echo $BASH_SUBSHELL ) )  # 2
```

A armadilha clássica é o `while read` em pipeline: o loop roda no subshell do último estágio e o contador morre com ele.

```bash
# ERRADO: imprime 0 — o while roda em subshell
count=0
printf 'a\nb\nc\n' | while read -r linha; do ((count++)); done
echo "$count"

# CERTO: redirecionamento de processo, sem pipe, sem subshell
count=0
while read -r linha; do ((count++)); done < <(printf 'a\nb\nc\n')
echo "$count"   # 3

# CERTO (alternativa): lastpipe roda o último estágio no shell atual
shopt -s lastpipe     # exige job control desligado (padrão em script)
count=0
printf 'a\nb\nc\n' | while read -r linha; do ((count++)); done
echo "$count"   # 3
```

### Grupo `{ }` vs subshell `( )`

`{ ... ; }` agrupa **no shell atual** — sem fork, atribuições persistem, `cd` persiste, `exit` mata o script. `( ... )` isola. Use `( )` quando quiser um `cd` ou um `set -x` descartável.

```bash
( cd /tmp && rm -rf build ); pwd     # pwd inalterado — o cd morreu com o subshell
{ cd /tmp && rm -rf build; }; pwd    # pwd agora é /tmp
```

Sintaxe: `{` e `}` são **palavras reservadas**, precisam de espaço em volta e de `;` (ou newline) antes do `}`. `(` e `)` são operadores e não precisam de nada disso. Custo: `( )` paga um fork; em loop quente isso importa.

## Ambiente vs variável de shell

Toda variável nasce **variável de shell**: visível para o shell atual e para subshells (que são cópias), mas invisível para processos `exec`utados. `export` a promove ao **ambiente**, que é o `char **envp` passado no `execve` — é isso, e só isso, que um programa externo enxerga.

```bash
FOO=bar
bash -c 'echo "[$FOO]"'        # [] — bash -c é um exec, FOO não estava no ambiente
export FOO
bash -c 'echo "[$FOO]"'        # [bar]

FOO=baz cmd                    # atribuição por comando: FOO entra no ambiente SÓ de cmd
env -i PATH=/usr/bin cmd       # ambiente limpo — útil para reproduzir bug de CI
```

Cuidado: `VAR=x cmd` só exporta para o comando quando **há** um comando. Se `cmd` for uma função ou builtin especial, a atribuição pode vazar para o shell atual (comportamento POSIX). E `VAR=x` sozinho, sem comando, é atribuição normal e persiste.

Mudar `FOO` depois do `export` propaga (o export marca o nome), mas mudar `FOO` **dentro** de um filho nunca volta. Não existe "variável de saída" de processo — o único canal de retorno é stdout/FD ou o exit status.

## `source` vs executar

`./script.sh` faz fork+exec: novo processo, novo shell, ambiente isolado. `source script.sh` (ou `. script.sh`) lê o arquivo **no shell atual**: funções e variáveis persistem, `cd` persiste, e `exit` no script **mata o seu shell**.

Duas armadilhas: (1) um script sourced *muda as opções do shell que o chamou* — `source` de um arquivo com `set -e` deixa o seu shell com `errexit` ligado, e um comando que falha te desloga; dentro de função, `local -; set -e` restaura as opções na saída. (2) `return` só é válido em função ou em script sourced; em script executado, é erro.

Detectar se foi sourced (padrão para arquivos que servem como lib *e* como CLI):

```bash
# ${BASH_SOURCE[0]} é o arquivo sendo lido; $0 é o nome do processo shell.
# Se executado, são iguais. Se sourced, $0 é o shell do chamador (bash, -bash, ...).
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  echo "sourced — só define funções" >&2
else
  main "$@"     # executado — roda de verdade
fi
```

## `exec`

`exec cmd` **substitui** o processo do shell pelo comando: mesmo PID, sem fork, sem retorno. Se `cmd` falhar em executar, o shell morre (a menos que `execfail` esteja setado em shell interativo).

O uso canônico é entrypoint de container e scripts wrapper: sem `exec`, o Bash fica vivo como pai, o processo real vira filho, e **o Bash não repassa sinais para o filho**. Um `SIGTERM` do orquestrador mata o shell e deixa a app órfã, ou pior: o shell está bloqueado esperando o filho, o sinal fica pendente, e o Docker espera 10s e manda `SIGKILL`.

```bash
#!/usr/bin/env bash
set -euo pipefail
prepara_config
exec node server.js "$@"     # node vira PID 1 e recebe SIGTERM direto
```

`exec` sem comando só aplica redirecionamentos ao shell atual — `exec 3< arquivo`, `exec > log.txt`.

## Background, `wait` e jobs

`cmd &` roda assíncrono e devolve imediatamente; `$!` guarda o PID do último background. `wait $pid` bloqueia e **retorna o exit status daquele filho** — é o único jeito de colhê-lo.

```bash
demorado & pid=$!
outra_coisa
wait "$pid"; rc=$?          # rc é o exit status de demorado
```

Regras que mordem:

- `wait` sem argumentos espera todos e retorna **0**, engolindo falhas. Sempre `wait "$pid"` individualmente se você se importa com o status.
- `wait` num PID que não é filho seu retorna **127**. Você não pode esperar por neto.
- Só dá para colher o status **uma vez**; o segundo `wait` no mesmo PID dá 127.
- `wait -n` retorna assim que **qualquer** filho termina, com o status dele; `wait -n -p var` grava em `var` qual PID foi.
- Se `wait` é interrompido por um sinal com trap, ele retorna **> 128** imediatamente e o trap roda.

`jobs` lista os jobs do shell atual (só interativo tem job control por padrão); `fg %1` / `bg %1` movem entre foreground e background. `disown %1` remove o job da tabela, e o shell não manda `SIGHUP` nele ao sair; `disown -h` mantém na tabela mas marca para não receber `SIGHUP`. `nohup cmd &` ignora `SIGHUP` e joga a saída em `nohup.out`, mas o processo continua no mesmo grupo/sessão; `setsid cmd` cria **sessão nova** e desliga do terminal de verdade. Para daemon real, `setsid` > `nohup`.

## Paralelismo em script

Padrão de pool com `wait -n`: dispara até N filhos, e a cada término dispara o próximo.

```bash
#!/usr/bin/env bash
set -uo pipefail
MAX=4
falhas=0

for item in "${itens[@]}"; do
  # se já tem MAX rodando, espera um terminar e colhe o status
  while (( $(jobs -rp | wc -l) >= MAX )); do
    wait -n || (( falhas++ ))
  done
  processa "$item" &
done

# drena o resto
while wait -n; do :; done 2>/dev/null
wait          # garante que ninguém ficou
(( falhas == 0 )) || { echo "$falhas job(s) falharam" >&2; exit 1; }
```

Para saber **qual** item falhou, guarde um mapa `declare -A dono; processa "$item" & dono[$!]="$item"` e colha com `wait -n -p pid`, que grava em `pid` qual filho retornou.

Não faça isso à mão sem motivo. `xargs -P` resolve o caso comum com melhor controle de erro e sem contabilidade manual:

```bash
# -P4 paralelismo, -n1 um arg por invocação, -0 seguro para nomes com espaço.
# xargs sai com 123 se qualquer invocação falhar.
printf '%s\0' "${itens[@]}" | xargs -0 -P4 -n1 -I{} ./processa.sh {}
```

GNU `parallel` vale quando você precisa de saída **não intercalada** (`--line-buffer`, `--tag`), retry (`--retries`), ou `--halt now,fail=1`. `xargs -P` intercala stdout dos filhos e corrompe linhas longas; `parallel` serializa.

## Sinais

- **SIGINT (2)** — Ctrl-C; vai para todo o **process group** do terminal, não só para o comando.
- **SIGTERM (15)** — pedido educado de término, default do `kill`. Capturável.
- **SIGKILL (9)** — não capturável, não ignorável, sem cleanup. Último recurso.
- **SIGHUP (1)** — terminal fechou. Shell reenvia para os jobs antes de sair.
- **SIGPIPE (13)** — escreveu em pipe sem leitor. É por isso que `cmd | head -1` mata `cmd` (e por que `set -o pipefail` faz `yes | head` "falhar" com 141 = 128+13).
- **SIGCHLD (17)** — filho mudou de estado; é o que destrava o `wait`.

```bash
kill -TERM "$pid"       # sinal por nome (portável, prefira ao número)
kill -0 "$pid"          # NÃO manda sinal: só testa se o processo existe e é sinalizável
kill -- -"$pgid"        # PGID negativo = mata o GRUPO inteiro (o -- protege do parsing)
```

`kill -0` é o idioma para checar vida, mas tem race: o PID pode ter sido reciclado. Em pool de jobs, prefira `jobs -rp` / `wait`.

Matar o pai **não mata os filhos**. Quem morre é o pai; os filhos viram **órfãos** e são reparentados para o `init`/PID 1. Só o `SIGHUP` do terminal ou um sinal explícito ao grupo alcança a árvore. Por isso `kill -- -$pgid` (o script precisa ter criado o próprio grupo, ex. via `setsid`).

### Traps e o Ctrl-C que não mata

```bash
trap 'echo "limpando"; rm -f "$tmp"' EXIT
trap 'echo "interrompido" >&2; exit 130' INT TERM
```

Traps **não são herdados por filhos**: o filho recebe o handler default (com uma exceção — sinais que o pai marcou como *ignorados* com `trap '' SIG` **são** herdados como ignorados; isso é permanente e não dá para desfazer no filho).

O comportamento que confunde: **se o Bash está esperando um comando em foreground, o trap não roda até o comando terminar**. Você aperta Ctrl-C, o `sleep 300` morre, mas o script continua parado — o trap só dispara depois. Pior: se o filho ignora `SIGINT`, o script fica travado. A saída é rodar o filho em background e usar `wait`, que **é** interrompível:

```bash
# ERRADO: trap só roda quando o sleep acabar
trap 'echo bye; exit 130' INT
sleep 300

# CERTO: wait retorna >128 na hora do sinal e o trap dispara
trap 'echo bye; kill "$pid" 2>/dev/null; exit 130' INT
sleep 300 & pid=$!
wait "$pid"
```

Em `set -e` + funções, use `set -E` (`errtrace`) para que o trap `ERR` seja herdado por funções, subshells e substituições de comando — sem ele, o `trap ... ERR` é invisível lá dentro.

## Timeout

Use `timeout(1)`. O padrão manual só serve se você não tiver coreutils.

```bash
timeout 30 cmd                       # SIGTERM aos 30s; exit 124 se estourou
timeout -k 5 30 cmd                  # SIGTERM aos 30s, SIGKILL 5s depois se resistir
timeout -s INT 30 cmd                # escolhe o sinal
timeout --foreground 30 cmd          # necessário quando cmd precisa do terminal
```

`timeout` sai com **124** no estouro, **125** se ele mesmo falhou, **126/127** para não-executável/não-encontrado, e `128+sinal` se o comando morreu por sinal. Não confunda 124 com falha da aplicação.

Sem coreutils, o padrão manual é um watchdog em background — e não esqueça de cancelá-lo:

```bash
cmd & pid=$!
( sleep 30; kill -TERM "$pid" 2>/dev/null ) & watchdog=$!
wait "$pid"; rc=$?
kill "$watchdog" 2>/dev/null    # senão o sleep sobrevive e mata um PID reciclado
```

## `coproc` e FIFOs

`coproc` cria um processo assíncrono com pipes bidirecionais ligados a um array de FDs.

```bash
coproc CALC { bc -l; }              # forma recomendada: sempre use { } e um NAME
echo "2^10" >&"${CALC[1]}"          # [1] escreve para o coproc
read -r resultado <&"${CALC[0]}"    # [0] lê do coproc
echo "$resultado"                   # 1024
exec {CALC[1]}>&-                   # fecha a entrada para o coproc terminar
wait "$CALC_PID"
```

Armadilha: o coproc quase sempre bufferiza em bloco (não é tty), então um `read` pode travar para sempre esperando saída presa no buffer do outro lado. Use `stdbuf -oL` ou um protocolo com delimitador.

FIFO nomeado quando os dois lados são processos independentes:

```bash
fifo=$(mktemp -u); mkfifo "$fifo"
trap 'rm -f "$fifo"' EXIT
produtor > "$fifo" &
consumidor < "$fifo"
```

`open()` de FIFO **bloqueia até que exista o outro lado** — abrir só para leitura trava até alguém abrir para escrita. Truque para não travar: `exec 3<>"$fifo"` (abre RW, nunca bloqueia).

## Exit status: onde ele se perde

**Pipeline** devolve o status do **último** comando. `PIPESTATUS` tem todos.

```bash
false | true; echo $?             # 0 — a falha sumiu
false | true; echo "${PIPESTATUS[@]}"   # 1 0
set -o pipefail                   # pipeline falha se QUALQUER estágio falhar
```

Copie `PIPESTATUS` na hora — o array é sobrescrito pelo próximo comando, inclusive por um `echo`:

```bash
cmd_a | cmd_b
rc=("${PIPESTATUS[@]}")     # snapshot imediato
```

**`local x=$(...)` é a armadilha mais cara do Bash.** `local`/`declare`/`export` são comandos: o exit status é o *deles* (0, quase sempre), não o da substituição. Isso engana `set -e` silenciosamente.

```bash
# ERRADO: rc é sempre 0; set -e nunca dispara aqui
f() { local out=$(cmd_que_falha); echo "rc=$?"; }

# CERTO: declare e atribua em passos separados
f() {
  local out
  out=$(cmd_que_falha) || return $?
  ...
}
```

**Subshell**: `( exit 3 )` propaga 3 normalmente. Mas `set -e` dentro de `$( )` só vale se a opção estiver ativa naquele contexto — e um `$( )` cujo status você não testa desaparece.

**Sinal**: processo morto por sinal N sai com **128+N** (130 = Ctrl-C, 137 = SIGKILL, 143 = SIGTERM, 141 = SIGPIPE). `exit 256` vira 0 — o status é 8 bits.

## Zumbis, órfãos e PID 1

Um **zumbi** é um filho que terminou e cujo status ainda não foi colhido: o kernel mantém a entrada na tabela de processos até o pai chamar `wait()`. O Bash colhe automaticamente, então zumbi em script é raro — aparece quando o *seu* processo é PID 1 e não faz reaping.

Um **órfão** é um filho cujo pai morreu; é reparentado para PID 1, que deve colhê-lo.

Em container, **PID 1 é especial**: o kernel não aplica as ações default de sinal a ele. Um processo em PID 1 que não instala handler para `SIGTERM` simplesmente **não morre** — o `docker stop` espera o grace period e manda `SIGKILL`. E `bash script.sh` como PID 1 é o pior dos mundos: o Bash não repassa sinais para filhos, não faz reaping de órfãos, e fica bloqueado no `wait`.

```dockerfile
# ERRADO: shell form vira /bin/sh -c "node server.js" — sh é PID 1, node é filho,
# SIGTERM morre no sh e o node só sai no SIGKILL 10s depois
CMD node server.js

# CERTO: exec form — node é PID 1 direto
CMD ["node", "server.js"]

# CERTO: entrypoint que precisa de setup, terminando em exec
ENTRYPOINT ["/entrypoint.sh"]      # e o script termina com: exec "$@"

# CERTO: quando você realmente precisa de árvore de processos, use um init que faz reaping
ENTRYPOINT ["tini", "--", "/entrypoint.sh"]     # ou: docker run --init
```

Se você precisa mesmo de um supervisor em Bash como PID 1, tem que fazer o trabalho na mão: trap que repassa o sinal, e `wait` interrompível.

```bash
#!/usr/bin/env bash
term() { kill -TERM "$child" 2>/dev/null; }
trap term TERM INT
app & child=$!
wait "$child"          # primeiro wait retorna >128 quando o sinal chega
wait "$child"          # segundo colhe o status real do filho após o shutdown
```
