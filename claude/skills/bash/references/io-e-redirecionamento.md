# I/O e Redirecionamento

File descriptors, redirecionamento, here-documents, process substitution, pipes e os builtins `read`/`printf`. O foco é o modelo mental de `dup2` — quase toda armadilha de I/O em shell vem de ignorar que redirecionamento é uma sequência de operações sobre uma tabela de descritores, não uma declaração.

## O modelo: FDs e dup2

Todo processo nasce com três descritores abertos: `0` (stdin), `1` (stdout), `2` (stderr). Um FD é um índice numa tabela por processo; cada entrada aponta para uma *open file description* (o objeto do kernel com offset e flags). Redirecionar é reapontar uma entrada da tabela.

- `> file` → abre `file` (`O_WRONLY|O_CREAT|O_TRUNC`) e faz `dup2(novo_fd, 1)`.
- `>> file` → mesma coisa com `O_APPEND`. Cada write reposiciona no fim atomicamente, por isso `>>` de dois processos no mesmo log não sobrescreve; `>` sim.
- `< file` → abre para leitura, `dup2(novo_fd, 0)`.
- `2>&1` → `dup2(1, 2)`: FD 2 passa a apontar para *o que quer que o FD 1 aponte naquele instante*.
- `<> file` → abre para leitura **e** escrita no mesmo FD, sem truncar, criando se não existir. Útil para sockets e para escrever em `/dev/tcp` sem fechar o lado de leitura.

Redirecionamentos são processados **da esquerda para a direita**, antes do comando executar. Essa é a origem da armadilha mais clássica do shell.

```bash
# Ambos os fluxos vão para o arquivo.
# 1) dup2(fd_de_f, 1)  -> 1 aponta para f
# 2) dup2(1, 2)        -> 2 copia o 1 ATUAL, que já é f
cmd > f 2>&1

# Só o stdout vai para o arquivo. stderr vai para o terminal.
# 1) dup2(1, 2)        -> 2 copia o 1 ATUAL, que ainda é o terminal
# 2) dup2(fd_de_f, 1)  -> 1 vira f, mas o 2 CONTINUA no terminal
cmd 2>&1 > f
```

`2>&1` não cria um alias permanente entre 2 e 1: copia o alvo naquele ponto. Depois disso os dois FDs são independentes. `cmd 2>&1 > f` não é um erro — é a forma idiomática de *separar* stderr do stdout redirecionado, por exemplo `cmd 2>&1 > /dev/null | grep erro` (filtra só o stderr).

Um efeito útil: FDs duplicados compartilham a *mesma* open file description, logo compartilham o offset. Por isso `cmd > f 2>&1` intercala os dois fluxos coerentemente, enquanto `cmd > f 2> f` (duas aberturas independentes, dois offsets) faz um sobrescrever o outro.

## Atalhos do bash

```bash
cmd &> file        # equivalente a: cmd > file 2>&1  (forma preferida)
cmd &>> file       # equivalente a: cmd >> file 2>&1
cmd |& grep erro   # equivalente a: cmd 2>&1 | grep erro
```

Todos são bashismos — não existem em POSIX `sh`. Em script com `#!/bin/sh` use a forma longa. Existe também `>&file`, mas é ambíguo: se `word` expandir para um número ou `-`, o bash o interpreta como duplicação de FD. Prefira sempre `&>` ou a forma explícita `> file 2>&1`.

## FDs customizados e exec

`exec` sem comando aplica os redirecionamentos ao **shell atual**, de forma persistente.

```bash
exec 3> /tmp/saida.log     # abre o FD 3 para escrita
echo "linha" >&3           # escreve nele
exec 3>&-                  # fecha o FD 3

exec 4< /etc/passwd        # FD 4 para leitura
read -r linha <&4
exec 4<&-
```

Salvar e restaurar stdout é o padrão para silenciar um trecho e voltar:

```bash
exec 3>&1              # 3 guarda uma cópia do stdout original
exec 1> /tmp/log       # stdout do script inteiro vai para o log
echo "vai para o log"
exec 1>&3 3>&-         # restaura stdout e fecha a cópia (move: >&3-)
echo "vai para o terminal"
```

`[n]>&digit-` **move** em vez de copiar: duplica e fecha a origem. `exec 1>&3-` é `exec 1>&3 3>&-` em um passo.

A partir do bash 4.1, `{var}` deixa o shell alocar um FD livre (≥10) e guardar o número na variável — evita colidir com FDs já em uso, o que é obrigatório em código de biblioteca:

```bash
exec {fd}< /etc/hosts      # bash escolhe o número
read -r primeira <&"$fd"
exec {fd}<&-               # fecha usando o valor da variável
```

FDs acima de 9 escolhidos à mão são arriscados: o shell usa alguns internamente. Com `{var}` isso deixa de ser problema. Note que `{var}` também funciona por comando (`cmd {fd}<file`) e, nesse caso, o FD **persiste** além do comando — controle o ciclo de vida você mesmo (ou veja `shopt varredir_close`).

## Arquivos especiais

| Caminho | Efeito |
|---|---|
| `/dev/null` | descarta escritas; leituras dão EOF imediato |
| `/dev/stdin`, `/dev/stdout`, `/dev/stderr` | duplica o FD 0/1/2 |
| `/dev/fd/N` | duplica o FD N |
| `/dev/tty` | o terminal de controle, **ignorando** redirecionamentos |
| `/dev/tcp/host/port`, `/dev/udp/host/port` | abre socket (bashismo, só via redirecionamento) |

`/dev/tty` é o jeito de fazer um prompt aparecer mesmo com o script redirecionado — é exatamente o que `read -p` não garante quando o stdin vem de pipe:

```bash
read -r -p "Confirma? " resposta < /dev/tty   # sempre fala com o usuário
```

`/dev/tcp` não é um arquivo do sistema: é emulado pelo bash e só funciona em redirecionamento (não em `cat /dev/tcp/...`).

```bash
exec 3<>/dev/tcp/example.com/80        # <> porque precisamos ler e escrever
printf 'GET / HTTP/1.0\r\n\r\n' >&3
cat <&3
exec 3>&-
```

## Here-documents e here-strings

```bash
cat <<EOF          # NÃO citado: expande $var, $(cmd), $((expr))
Usuário: $USER
EOF

cat <<'EOF'        # citado: literal, ZERO expansão
Custa $100 e usa $HOME literalmente
EOF
```

Armadilha clássica: gerar um script, um Dockerfile ou um bloco de AWS/jq com `<<EOF` sem aspas e ver `$1`, `$HOME` e `` `cmd` `` serem devorados pelo shell externo. **A regra: cite o delimitador (`<<'EOF'`) por padrão; só omita as aspas quando você quiser interpolação.** Qualquer parte citada serve (`<<'EOF'`, `<<"EOF"`, `<<\EOF`).

`<<-EOF` remove **apenas TABs** iniciais — de cada linha e da linha do delimitador. Espaços não são removidos. Editores configurados para expandir tab em espaço quebram isso silenciosamente, e o erro aparece como um here-doc "não terminado".

```bash
	cat <<-'EOF'    # os recuos abaixo precisam ser TAB de verdade
	texto recuado
	EOF
```

Com delimitador **não** citado, `\<newline>` vira continuação de linha e é removido antes da checagem do delimitador — duas linhas podem se juntar e formar o terminador acidentalmente.

Here-string (`<<<`) entrega uma única string, com newline anexado, no stdin. Sofre expansão de parâmetro/comando mas **não** globbing nem word splitting — ainda assim, cite: `<<< "$var"`.

```bash
grep -c foo <<< "$texto"
IFS=: read -r user pass rest <<< "$linha"   # parse de campos sem subshell
```

## Process substitution

`<(list)` e `>(list)` rodam `list` assincronamente e substituem a construção por um **nome de arquivo** (`/dev/fd/63` ou um FIFO). Não pode haver espaço entre `<` e `(`.

```bash
diff <(sort a.txt) <(sort b.txt)          # compara sem arquivos temporários
comm -13 <(cmd_a) <(cmd_b)
```

O uso mais valioso é escapar do subshell do pipe. Em `cmd | while read ...`, o `while` roda num subshell e **toda variável atribuída se perde** ao final:

```bash
# ERRADO: total sai 0 — o while roda em subshell
total=0
find . -name '*.log' | while read -r f; do (( total++ )); done
echo "$total"

# CERTO: o while roda no shell atual; só o find está no subprocesso
total=0
while read -r f; do (( total++ )); done < <(find . -name '*.log')
echo "$total"
```

Note o espaço em `< <(...)`: é o redirecionamento `<` seguido da process substitution.

`>(...)` é o caminho inverso — escrever num processo:

```bash
cmd | tee >(gzip > saida.gz) >(wc -l > contagem) > /dev/null
```

Armadilhas reais:

- **O exit status se perde.** `<(cmd)` expande para um nome de arquivo; o status de `cmd` não chega a lugar nenhum. `diff <(falha) <(ok)` reporta o status do `diff`, nunca o da `falha`. Se o status importa, use arquivo temporário ou capture o PID com `$!` logo após e faça `wait`.
- **Não há sincronização com `>(...)`.** O comando externo pode terminar antes do processo de dentro drenar sua entrada — `tee >(sort > out)` pode deixar `out` incompleto no instante seguinte.
- **Não é POSIX** e depende de `/dev/fd` ou FIFOs. Falha em `sh`, em alguns ambientes restritos e em containers minimalistas sem `/dev/fd`. Quando o fallback é FIFO, o "arquivo" não é seekável: ferramentas que fazem `lseek` (alguns parsers, `tail -r`) quebram.

## noclobber

`set -o noclobber` (ou `set -C`) faz `> arquivo` **falhar** se o arquivo existir e for regular. `>|` força a sobrescrita mesmo assim; `>>` não é afetado.

```bash
set -o noclobber
echo x > existente     # erro: cannot overwrite existing file
echo x >| existente    # força
```

Proteção interativa útil, mas não é trava de concorrência confiável nem substituto de lockfile.

## Pipes: buffering, SIGPIPE, PIPESTATUS

Um pipe é um buffer do kernel (tipicamente 64 KB) entre dois processos que rodam **em paralelo**. Duas consequências dominam a depuração:

**Buffering da libc.** Programas com stdio decidem o modo de buffer olhando se a saída é um TTY: TTY → line-buffered; pipe ou arquivo → block-buffered (~4–64 KB). Por isso `tail -f app.log | grep ERRO` parece "travar": o `grep` só emite quando enche o bloco. Não é o `grep` lendo devagar — é ele *escrevendo* em bloco.

```bash
tail -f app.log | grep --line-buffered ERRO      # flag nativa, quando existe
tail -f app.log | stdbuf -oL grep ERRO           # força line-buffered de fora
stdbuf -o0 cmd | outro                           # sem buffer nenhum
```

`stdbuf` funciona via `LD_PRELOAD` e só afeta quem usa stdio — não funciona com Go, ou com programas que fazem `setvbuf` explicitamente. Aí o recurso é `unbuffer`/`script` (pty falso) ou a flag da própria ferramenta (`python -u`, `grep --line-buffered`, `awk` com `fflush()`).

**SIGPIPE.** Quando o leitor fecha, o escritor recebe `SIGPIPE` e morre com status `141` (128+13). É o mecanismo que faz `yes | head -1` terminar. Com `set -o pipefail`, esse 141 legítimo vira falha do pipeline inteiro — origem comum de CI vermelho em `cmd | head`.

**PIPESTATUS.** `$?` de um pipeline é o status do **último** comando. Os demais ficam no array `PIPESTATUS`, válido apenas até o comando seguinte:

```bash
cmd_a | cmd_b | cmd_c
status=( "${PIPESTATUS[@]}" )     # copie IMEDIATAMENTE, senão se perde
echo "a=${status[0]} b=${status[1]} c=${status[2]}"
```

`set -o pipefail` faz o pipeline retornar o status do último comando que falhou — mais simples que inspecionar `PIPESTATUS`, e o default recomendado.

## read

Nunca use `read` sem `-r`: sem ele, `\` vira escape e some da entrada, corrompendo caminhos do Windows e qualquer dado com backslash. E prefixe `IFS=` para não perder espaços nas pontas.

```bash
while IFS= read -r linha; do        # preserva espaços e backslashes
  printf '%s\n' "$linha"
done < arquivo.txt
```

`IFS=` na frente do comando é uma atribuição temporária: vale só para esse `read`. Sem ela, `IFS` default (espaço/tab/newline) apara os extremos da linha.

Opções que importam:

- `-r` — não trate `\` como escape. **Sempre.**
- `-p prompt` — prompt sem newline; só se o stdin é terminal.
- `-s` — silencioso, não ecoa (senhas).
- `-t seg` — timeout; retorna >128. Só vale para terminal/pipe/special file, **não** para arquivo regular.
- `-n N` — lê até N caracteres, mas para antes se achar o delimitador.
- `-N N` — lê **exatamente** N caracteres, ignora delimitadores, não aplica IFS.
- `-a arr` — joga as palavras num array; outros nomes são ignorados.
- `-d delim` — usa o primeiro caractere de `delim` como terminador. `-d ''` termina em NUL.
- `-u fd` — lê do FD indicado em vez do stdin.

Sem nome de variável, o resultado vai para `REPLY` — sem remoção de espaços via IFS, útil para cópia fiel.

Split em campos, sem subshell e sem `cut`:

```bash
IFS=: read -r user pass uid gid gecos home shell <<< "$linha"
```

Se há mais campos que nomes, **o excesso vai todo para o último nome, com os delimitadores intactos** — por isso o padrão `read -r chave resto`. Se há menos, os nomes restantes ficam vazios.

Um `read` num loop consumindo o mesmo stdin do corpo é armadilha: `while read -r x; do ssh host cmd; done < lista` some com linhas porque o `ssh` drena o stdin. Use `ssh -n`, ou leia por outro FD:

```bash
while read -r host <&3; do ssh "$host" uptime; done 3< lista
```

## printf em vez de echo

`echo` não é portável: o tratamento de `-e`/`-n` varia entre bash builtin, `/bin/echo`, `sh` e a opção `xpg_echo`. Pior, `echo "$var"` com `$var` começando em `-n` ou `-e` faz a string virar flag e desaparecer. `printf` não tem nenhum desses problemas.

```bash
printf '%s\n' "$var"        # sempre correto, mesmo se var="-n" ou "-e"
echo "$var"                 # pode sumir ou virar flag
```

O primeiro argumento de `printf` é o formato: nunca coloque dado do usuário nele (`printf "$var"` interpreta `%s` e `\n` vindos do dado). Use `printf '%s' "$var"`.

O formato é **reutilizado** enquanto sobrarem argumentos — isso é uma ferramenta, não um acidente:

```bash
printf '%s\n' "${arr[@]}"        # um elemento por linha, qualquer tamanho
printf '%s=%s\n' k1 v1 k2 v2     # consome os args de dois em dois
```

`-v var` grava na variável em vez de imprimir, sem subshell (mais rápido que `var=$(printf ...)` e preserva newlines finais):

```bash
printf -v pad '%05d' 42          # pad=00042
printf -v ts '%(%Y-%m-%d)T' -1   # data sem chamar date(1)
```

`%q` emite a string em formato reusável como entrada do shell — a forma correta de gerar comando para `eval`, `ssh` ou log:

```bash
printf '%q\n' "arquivo com espaço e 'aspas'"
```

## Nomes de arquivo com espaço e newline

Newline é caractere válido em nome de arquivo no Unix; o único separador seguro é o NUL. Por isso qualquer pipeline `ls | while read` ou `for f in $(find ...)` está quebrado.

```bash
# ERRADO: quebra em espaço e newline
for f in $(find . -name '*.txt'); do rm "$f"; done

# CERTO: separador NUL ponta a ponta
find . -name '*.txt' -print0 | xargs -0 rm --

# CERTO: sem xargs, lendo NUL no shell atual
while IFS= read -r -d '' f; do
  printf 'processando: %s\n' "$f"
done < <(find . -name '*.txt' -print0)

# CERTO: sem pipe nenhum
find . -name '*.txt' -exec rm -- {} +
```

`read -d ''` é o par de `-print0`: termina em NUL. `-print0`/`-0` são extensões GNU/BSD, não POSIX; `-exec ... +` é portável.

## exec para logging do script inteiro

```bash
exec > >(tee -a /var/log/meu.log) 2>&1   # tudo daqui pra frente vai para tela e log
```

Redireciona o stdout do script para um `tee` rodando em process substitution, e manda o stderr junto (ordem importa: `>` primeiro, `2>&1` depois). Ressalva: o `tee` é assíncrono e o shell não espera por ele — na saída, as últimas linhas podem chegar ao arquivo *depois* do script terminar, embaralhando a saída no terminal do chamador. Se isso importa, guarde o PID e faça `wait`.

## cat inútil (UUOC)

`cat file | grep foo` gasta um processo e um pipe à toa, e — pior que o custo — coloca o `grep` num subshell e apaga o nome do arquivo da saída do `grep`.

```bash
cat file | grep foo        # UUOC        →  grep foo file
cat file | tr a-z A-Z      # UUOC        →  tr a-z A-Z < file
```

O caso que realmente machuca é o do subshell: `cat f | while read -r l; do (( n++ )); done` perde `n`. Use `< f` ou `< <(cmd)`. `cat` legítimo: concatenar múltiplos arquivos, ou usar flags dele (`cat -n`, `cat -A`).
