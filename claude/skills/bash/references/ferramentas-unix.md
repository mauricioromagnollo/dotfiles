# Ferramentas Unix

O Bash é cola, não linguagem de processamento. Quem faz o trabalho são `grep`, `sed`, `awk`, `find`, `jq` e companhia. Esta referência cobre o uso real dessas ferramentas em scripts e as armadilhas que quebram em produção — não a man page.

## Quando NÃO usar o Bash

A regra, sem meias palavras:

- **Precisa de estrutura de dados** (lista de listas, dict aninhado, objeto)? Python. Arrays associativos do Bash são planos e não aninham.
- **Precisa de float**? Python. `$(( ))` é inteiro. Chamar `bc` num loop é sintoma, não solução.
- **É JSON/XML/YAML**? `jq`/`yq` para extrair; Python se for transformar de verdade. **Nunca** parse JSON com grep/sed.
- **Passou de ~200 linhas** ou nasceram funções que retornam "objetos"? Python. O script vai crescer; ele sempre cresce.
- **Loop sobre milhões de linhas**? `awk`. Um `while read` em Bash faz fork/exec por linha e é 10–100x mais lento que o awk equivalente — e maior.
- **Precisa de tratamento de erro fino, retry com backoff, concorrência estruturada**? Python.

Bash é ótimo para: orquestrar processos, encadear pipes, glue de CI, wrappers curtos. Fora disso, é dívida.

## grep

```bash
grep -E 'erro|falha' app.log      # ERE: alternância, +, ?, {n,m} sem escape
grep -F 'a.b.c' lista.txt         # literal: nada de regex, e é o mais rápido
grep -P '(?<=id=)\d+' app.log     # PCRE: lookaround, \d. Só GNU grep.
```

Escolha `-F` sempre que o padrão for literal: além de rápido, evita que metacaracteres do dado virem regex.

```bash
grep -o 'user=[a-z]*' log      # imprime só o trecho casado, não a linha
grep -v '^#' conf              # inverte: descarta comentários (-i: ignora case)
grep -c ERROR log              # conta linhas casadas (não ocorrências)
grep -l ERROR *.log            # lista arquivos que casam (-L: os que NÃO casam)
grep -rn --include='*.ts' TODO src/   # recursivo + nº da linha, filtrando por glob
grep -A3 -B1 'panic' log       # 3 linhas depois, 1 antes (-C3 = ambos)
```

O exit status é a interface mais útil do grep em script — `0` casou, `1` não casou, `2` erro:

```bash
# -q sai no primeiro match e não imprime nada
if grep -q '^flag=true' "$conf"; then
  echo "habilitado"
fi
```

Variável no padrão: use `-F` e `--` para não interpretar como regex nem como flag.

```bash
grep -F -- "$termo" arquivo    # "-v" ou "a.b" vindos do usuário não te sabotam
```

`grep -c` conta **linhas**, não matches (para ocorrências: `grep -o pat | wc -l`). E `set -e` com `grep` sem match aborta o script — é a causa mais comum de "morreu sem erro".

## sed

Modelo: sed lê uma linha por vez para o *pattern space*, aplica os comandos cujo endereço casa, imprime o pattern space e recomeça. `-n` suprime a impressão automática — daí o par `-n` + `p`.

```bash
sed 's/foo/bar/' f          # troca a 1ª ocorrência de cada linha
sed 's/foo/bar/g' f         # todas
sed 's/foo/bar/2' f         # só a 2ª ocorrência da linha
sed 's/foo/bar/gI' f        # global, case-insensitive (GNU; BSD usa I também)
sed -E 's/(a|b)+/x/' f      # ERE, sem \( \)
```

**`-i` é a maior incompatibilidade GNU vs BSD (macOS):**

```bash
sed -i    's/a/b/' f    # GNU: edita in-place
sed -i '' 's/a/b/' f    # BSD/macOS: sufixo de backup vazio é obrigatório
sed -i.bak 's/a/b/' f   # funciona nos dois (deixa f.bak)
```

Em script portável, não use `-i`: escreva em temporário e mova — `tmp=$(mktemp) && sed 's/a/b/' f > "$tmp" && mv "$tmp" f`.

Endereços:

```bash
sed -n '5p' f              # só a linha 5 ($p = última)
sed -n '/BEGIN/,/END/p' f  # range por regex
sed '1d' f                 # apaga o header
sed '/^\s*#/d; /^$/d' f    # apaga comentários e linhas vazias
sed '10q' f                # imprime até a 10 e sai (rápido em arquivo enorme)
sed '/^user/s/0/1/' f      # substitui só nas linhas que casam o endereço
sed '/^host/c\host = prod' f    # c troca a linha inteira (a anexa, i insere antes)
```

Delimitador alternativo — obrigatório ao lidar com paths, senão vira cerca de barras. Grupos com `\1`:

```bash
sed 's|/usr/local|/opt|g' f     # em vez de s/\/usr\/local/\/opt/g
sed -E 's/^([^:]+):.*:([^:]+)$/\1 -> \2/' /etc/passwd
```

**Pare de usar sed quando**: precisar de estado entre linhas (hold space é escrita só-leitura para quem vem depois), contar/agregar, ou fazer mais de duas substituições encadeadas. Isso é awk. E sed não entende HTML/JSON/XML — não tente.

## awk

Modelo: `pattern { action }`. Para cada registro (linha, por padrão), se o pattern casa, executa a action. Sem pattern → toda linha. Sem action → `{ print }`.

```bash
awk '/erro/'                     # ~ grep
awk '{ print $2, $NF }'          # 2º campo e último
awk -F: '$3 >= 1000 { print $1 }' /etc/passwd   # -F define o separador
awk 'NR > 1'                     # pula header
awk 'NF'                         # descarta linhas vazias
```

Variáveis: `$0` linha inteira, `$1..$n` campos, `NF` número de campos, `NR` número do registro, `FNR` por arquivo, `FS`/`OFS` separador de entrada/saída, `RS`/`ORS` de registro.

```bash
# OFS só é aplicado quando $0 é reconstruído (daí o $1=$1)
awk -F, 'BEGIN{OFS="\t"} {$1=$1; print}' dados.csv
```

`BEGIN` roda antes da primeira linha, `END` depois da última — é onde vive a agregação.

```bash
awk '{ soma += $7 } END { print soma }' access.log        # soma uma coluna
awk '{ s += $2; n++ } END { if (n) printf "%.2f\n", s/n }' f   # média: float de graça
```

Array associativo é o que faz o awk substituir um script inteiro. `printf` tem semântica de C (`print` não formata):

```bash
# conta ocorrências por status HTTP
awk '{ c[$9]++ } END { for (k in c) print c[k], k }' access.log | sort -rn

# soma bytes por IP, formatado
awk '{ b[$1] += $10 } END { for (ip in b) printf "%-16s %8.1f MB\n", ip, b[ip]/1048576 }' access.log
```

Passar variável do shell — use `-v`, nunca interpole aspas:

```bash
limite=500
awk -v lim="$limite" '$3 > lim' f     # correto
# awk "\$3 > $limite" f               # frágil e injetável
```

Por que awk vence o `while read`:

```bash
while read -r a b; do echo "$((a+b))"; done < f   # ruim: 1 fork por linha, ~50x mais lento
awk '{ print $1 + $2 }' f                         # bom: um processo, uma linha
```

## find

```bash
find . -name '*.log'            # glob, case-sensitive (aspas! senão o shell expande)
find . -iname '*.LOG' -type f   # -iname ignora case; -type f/d/l
find . -maxdepth 2 -path '*/src/*'
find . -mtime -7                # modificado nos últimos 7 dias (-mmin -30 p/ minutos)
find . -size +100M -perm -u+x
find . -newer Makefile          # mais recente que o arquivo de referência
```

**Ordem dos predicados importa**: eles são avaliados da esquerda para a direita e curto-circuitam. `-name '*.log' -type f` é mais barato que `-type f -name '*.log'` quando o glob elimina mais. E `-maxdepth` precisa vir antes dos testes, senão o GNU find reclama.

`-prune` corretamente (cortar a árvore, não filtrar o resultado):

```bash
find . \( -name node_modules -o -name .git \) -prune -o -type f -name '*.ts' -print
```

O `-o -print` no fim é obrigatório: sem ele o `-print` implícito imprime também os diretórios podados.

`-exec` — a diferença de performance:

```bash
find . -name '*.tmp' -exec rm {} \;   # um processo rm POR arquivo
find . -name '*.tmp' -exec rm {} +    # agrupa argumentos: um rm para N arquivos
```

Use `+` sempre que o comando aceitar múltiplos argumentos. `\;` só quando precisar de exatamente um arquivo por invocação (ou de `{}` em mais de uma posição).

`find . -name '*.tmp' -delete` é mais rápido que `-exec rm` (sem fork); `find . -type f -print0 | xargs -0 ...` faz nomes com espaço/newline sobreviverem.

## xargs

O problema base: nome de arquivo pode conter espaço, aspas e até newline. `find | xargs` sem `-print0`/`-0` quebra nesses casos — e é assim que se apaga o arquivo errado.

```bash
find . -type f -name '*.bak' -print0 | xargs -0 rm -f
```

Flags:

```bash
xargs -0                   # entrada separada por NUL (par de -print0 / grep -lZ)
xargs -n1                  # um argumento por invocação
xargs -I{} mv {} /dest/    # posiciona o argumento; implica -n1 (mais lento)
xargs -r cmd               # --no-run-if-empty: GNU; sem isso, entrada vazia roda cmd sem args
find . -name '*.png' -print0 | xargs -0 -P"$(nproc)" -n1 optipng   # -P: paralelismo
```

`xargs -r` não existe no BSD (lá o comportamento já é não rodar).

## Cortar e juntar

```bash
cut -d: -f1,3 /etc/passwd     # por delimitador (1 char, literal)
cut -c1-10 f                  # por coluna de caractere
```

`cut` não colapsa delimitadores repetidos — para saída separada por espaços variáveis, use `awk '{print $2}'`.

```bash
paste -d, a.txt b.txt         # cola lado a lado
tr 'a-z' 'A-Z' < f            # traduz
tr -d '\r' < f                # apaga CR (arquivo do Windows)
tr -s ' '                     # squeeze: colapsa espaços repetidos
tr ' ' '\n'                   # quebra em uma palavra por linha
```

```bash
sort -u f                     # ordena e deduplica (-r: reverso)
sort -n f                     # numérico (senão "10" < "9"); -h: 1K/2M/3G; -V: versão
sort -t: -k3,3n /etc/passwd   # campo 3 como chave numérica
```

`-k3,3n` e não `-k3n`: sem o fim explícito, a chave vai do campo 3 até o fim da linha.

`uniq` só enxerga linhas **adjacentes** — sempre `sort` antes:

```bash
sort f | uniq -c | sort -rn    # o "top N" canônico
sort f | uniq -d               # só as duplicadas
sort f | uniq -u               # só as que aparecem uma vez
```

```bash
comm -23 <(sort a) <(sort b)   # linhas só em a (requer entradas ordenadas)
join -t: -1 1 -2 1 a b         # join relacional por campo
head -n5 f ; tail -n5 f
tail -n +2 f                   # da linha 2 até o fim (pula header)
tail -f app.log                # segue (-F sobrevive a rotação)
wc -l < f                      # sem "< " o wc imprime o nome do arquivo junto
rev ; tac ; nl                 # inverte chars / inverte linhas / numera
column -t                      # alinha colunas para leitura humana
```

## jq e yq

**Nunca parse JSON com grep/sed.** JSON não é orientado a linha, escapa aspas, aninha e reordena chaves. `grep '"id"'` funciona até o dia em que não funciona — e falha em silêncio, com o valor errado.

```bash
curl -fsS "$url" | jq -r '.token'    # -r: sem aspas na saída (use em pipe)
jq -e '.enabled' r.json              # -e: exit status reflete o valor (falsy -> 1)
jq -r '.users[] | select(.active) | "\(.id)\t\(.email)"' r.json
jq -n --arg n "$nome" '{name:$n}'    # CONSTRUIR json: --arg escapa por você
jq -s '.' *.json                     # slurp: junta em um array
jq -c '.[]'                          # compacto, uma linha por item (NDJSON)
```

`--arg` sempre passa string; use `--argjson` para número/bool/objeto. Para YAML: `yq` (o de Go, mikefarah) tem sintaxe jq-like — `yq '.spec.replicas' d.yaml`, `yq -o=json`. O `yq` em Python é wrapper de jq; confira qual está instalado antes de escrever o script.

## Arquivos

```bash
stat -c '%s %Y %n' f          # GNU: tamanho, mtime epoch, nome
stat -f '%z %m %N' f          # BSD/macOS: mesma coisa, sintaxe incompatível
```

`stat` é o exemplo canônico de portabilidade: rodando em Linux e macOS, prefira `find -printf` (GNU), escreva os dois caminhos, ou use `wc -c < f` para tamanho.

```bash
realpath f                    # caminho absoluto canônico (GNU; macOS moderno tem)
readlink -f link              # resolve symlink em cadeia (GNU)
dirname /a/b/c.txt ; basename /a/b/c.txt .txt   # -> /a/b  e  c
```

`dirname`/`basename` forkam. Em loop, use expansão de parâmetro — só lembre que `${path%/*}` devolve o próprio path se não houver `/`, enquanto `dirname` devolveria `.`.

```bash
dir=${path%/*} ; file=${path##*/} ; base=${file%.*}   # dirname / basename / sem extensão
```

```bash
tmpd=$(mktemp -d)                      # temporário seguro (mktemp p/ arquivo)
trap 'rm -rf "$tmpd"' EXIT             # limpeza sempre
```

Nunca use `/tmp/foo.$$` — é race condition e symlink attack.

```bash
install -m 0644 -D src/f /etc/app/f    # cria diretório, copia e seta modo num passo
rsync -a --delete src/ dst/            # idempotente, incremental, preserva metadados
cp -a src/ dst/                        # simples; sem delta, sem --delete
tar -czf b.tgz -C /src .               # -C entra no dir: sem prefixo no archive
tar -xzf b.tgz -C /dst
```

`rsync src/ dst/` (com barra) copia o *conteúdo*; sem barra copia o diretório. Essa barra já derrubou muita gente.

## Rede e misc

```bash
curl -fsS -L --retry 3 --retry-delay 2 -o out.json "$url"
```

- `-f`: **falha com exit != 0 em HTTP 4xx/5xx**. Sem isso, curl salva a página de erro e retorna `0` — o script segue feliz com lixo. Em script, `-f` não é opcional.
- `-s` silencia a barra de progresso; `-S` traz o erro de volta (`-sS` andam juntos).
- `-L` segue redirect; `--retry` cobre falha transitória; `--max-time` não pendura o CI.

```bash
date +%s                                 # epoch
date -u +%Y-%m-%dT%H:%M:%SZ              # ISO 8601 UTC — o único formato p/ log
date -d '2 days ago' +%F                 # GNU (-d @1700000000: epoch -> data)
date -v-2d +%F                           # BSD/macOS — incompatível com -d
```

```bash
seq 1 10 ; seq -w 1 100          # -w zera à esquerda
shuf -n5 f ; shuf -e a b c       # amostragem aleatória
shasum -a256 f                   # existe nos dois (Linux md5sum vs macOS md5) — prefira
getent hosts example.com         # resolve via NSS (respeita /etc/hosts, ao contrário de dig)
nc -z -w2 host 5432              # testa porta aberta (health check de dependência)
```

## Locale

O locale muda o resultado de `sort` e a velocidade de `grep`. Em UTF-8 o `sort` usa regras de collation complexas e `[a-z]` casa acentuados de forma surpreendente.

```bash
LC_ALL=C sort f                  # ordenação por byte: determinística e portável
LC_ALL=C grep -F pat huge.log    # frequentemente vários x mais rápido
```

Se o script compara saídas ordenadas, gera checksums ou faz diff entre máquinas, fixe `LC_ALL=C`. Só não fixe quando a ordem precisa ser apresentada a humanos com acento.
