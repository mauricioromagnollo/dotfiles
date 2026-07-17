---
name: bash
description: Escrever, revisar e depurar Shell Script Bash — quoting e expansões, `set -euo pipefail` e trap, arrays, funções, redirecionamento e file descriptors, processos e sinais, CLI com getopts, e as ferramentas ao redor (grep/sed/awk/find/xargs/jq). Use ao criar ou alterar qualquer arquivo `.sh`, `.bash`, `.bashrc`, hook de git, entrypoint de container, script de CI, Makefile com recipe de shell ou one-liner não trivial; ao investigar script que quebra com espaço no nome, que ignora erro, que "funciona no meu Mac", que não morre no Ctrl-C ou cuja variável some depois do pipe. Dispare também em pedidos como "faz um script pra isso", "automatiza isso", "esse comando tá errado?", "por que isso não pegou o erro", "como faço um loop no shell", "isso é seguro?", "roda isso pra cada arquivo", "revisa esse script", "o shellcheck reclamou disso", "escreve teste pra esse script", "como mocko o curl", "bats ou shunit2?", mesmo que Bash, shell ou script não sejam citados por nome. Também para justificar NÃO usar Bash e escrever em Python.
---

# Shell Script Bash

Bash é a única linguagem que a maioria dos engenheiros escreve sem nunca ter aprendido. O resultado é previsível: o script funciona no caminho feliz, na máquina de quem escreveu, com os nomes de arquivo que existiam naquele dia — e falha em silêncio no resto. O que separa um script sólido de um frágil não é conhecer sintaxe exótica, são quatro coisas: **citar toda expansão**, **fazer o erro parar o script**, **saber o que roda em subshell** e **saber quando o problema não é do Bash**.

**Este arquivo é o mapa. Não leia todas as referências** — decida aqui e abra só a que a tarefa exige.

## Referências

| Referência | Quando abrir |
|---|---|
| `references/sintaxe-e-expansoes.md` | Quoting, a ordem das expansões, `${var#pat}` e toda a família `${}`, `$( )`, `$(( ))`, IFS e word splitting, globbing, `extglob` |
| `references/scripting-robusto.md` | O prólogo e o que `set -e` **não** pega, `trap` e cleanup, exit codes, `mktemp`, lock, `eval`, injeção, estrutura de script grande |
| `references/estruturas-e-dados.md` | Arrays indexados e associativos, `declare`/`local`/nameref, `[[ ]]` e `=~`, `case`, `while read` correto, funções e retorno de valor |
| `references/io-e-redirecionamento.md` | File descriptors e a ordem de `2>&1`, `exec 3>`, here-docs, `<(...)`, `read`, `printf` vs `echo`, buffering, logging |
| `references/processos-e-concorrencia.md` | Subshell vs grupo, `source` vs exec, background e `wait -n`, sinais e propagação, `timeout`, paralelismo, PID 1 em container |
| `references/cli-e-argumentos.md` | `"$@"` vs `"$*"`, `getopts`, opções longas, `usage()`, exit codes, stdout vs stderr, subcomandos, config e env |
| `references/ferramentas-unix.md` | grep, sed, awk, find, xargs, sort/uniq/cut/tr, jq, curl, date — e **quando parar de usar Bash** |
| `references/portabilidade-e-armadilhas.md` | Catálogo de armadilhas, `sh` ≠ `bash`, Bash 3.2 do macOS, GNU vs BSD, tabela de versão → feature, `shellcheck` |
| `references/debug-testes-e-ambiente.md` | `set -x` e `PS4`, stack trace, profiling e custo de fork, **bats-core básico**, assert caseiro, startup files, `PS1`, histórico |
| `references/frameworks-de-teste.md` | **shunit2** a fundo (xUnit multi-shell), bats além do básico (`run -N`, gotchas, bats-assert/file/mock), ShellSpec e bash_unit, qual framework usar |
| `references/testabilidade-e-cobertura.md` | Tornar script testável, test doubles (stub em PATH, spy, `export -f`), fixtures e golden files, cobertura com kcov e suas mentiras, CI com matrix de versão de bash |

Vizinhas: `craft` para princípios de design e quando abstrair, `nodejs` quando o script for substituído por código de aplicação, `conventional-commits` na hora de commitar.

## O fluxo

### 1. Antes de escrever, decida se deve ser Bash

Esta é a decisão mais valiosa da skill, e ela vem **antes** de qualquer sintaxe. Bash é excelente como cola: encadear processos, mexer em arquivo, orquestrar ferramentas. Ele é ruim em quase todo o resto, e a degradação é silenciosa — o script não fica impossível, fica insustentável.

Sinais de que a resposta é outra linguagem (quase sempre Python):

- Precisa de estrutura de dados aninhada, ou de mais de um array associativo conversando entre si.
- Precisa de ponto flutuante. Bash não tem — e `bc` num loop é o começo de um pesadelo.
- Precisa parsear JSON, XML ou CSV com campo citado. `jq` resolve JSON; o resto, não.
- Passou de ~200 linhas, ou já tem função que retorna "objeto" via string delimitada.
- Precisa de tratamento de erro com contexto, retry com backoff e telemetria.

Diga isso explicitamente em vez de escrever 300 linhas de Bash em silêncio. E vale o contrário: um `for f in *.log; do gzip "$f"; done` não precisa virar script Python porque alguém leu que "Bash não escala".

### 2. Descubra a convenção antes de impor a sua

Nenhuma regra desta skill vale mais que o que o repositório já faz. Antes de criar arquivo:

- **Shebang**: os scripts existentes usam `#!/bin/bash` ou `#!/usr/bin/env bash`? `#!/bin/sh`? Se é `sh`, o alvo pode ser `dash` e **nenhum bashismo é permitido** — veja `references/portabilidade-e-armadilhas.md` antes de escrever `[[ ]]`.
- **Alvo de execução**: roda em CI Linux? No Mac de alguém? Em `alpine` (que tem `busybox sh`, não Bash)? Em container como PID 1? Cada resposta muda o que é permitido.
- **Linter**: existe `.shellcheckrc`, `shfmt` no CI, hook de pre-commit? Rode `shellcheck` no que existe antes de assumir que o projeto liga para isso.
- **Estilo**: indentação, `function foo()` vs `foo()`, `local` sempre? Leia dois scripts irmãos. Copiar o vizinho é quase sempre a resposta certa.

### 3. O prólogo não é enfeite, e não é suficiente

Todo script novo começa assim, e cada linha tem motivo:

```bash
#!/usr/bin/env bash
set -euo pipefail    # falha em erro, em variável não definida, e em erro no meio do pipe
IFS=$'\n\t'          # tira o espaço do word splitting: nome de arquivo com espaço para de quebrar
```

Mas **saber onde `set -e` não dispara é mais importante do que usá-lo.** Ele não dispara em comando dentro de `if`, `while`, `&&`, `||` ou `!`; não dispara em `local x=$(cmd_que_falha)` (o status vira o do `local`); não é herdado por subshell de command substitution sem `shopt -s inherit_errexit`. Um script com `set -e` e um `local x=$(...)` no meio tem tratamento de erro decorativo. `references/scripting-robusto.md` cobre cada buraco — leia antes de confiar no prólogo.

E o par que fecha a conta: `trap` para cleanup. Todo arquivo temporário nasce de `mktemp` e morre num `trap ... EXIT`, não numa linha `rm` no fim que nunca roda quando o script morre no meio.

### 4. Cite tudo, e saiba por que

`"$var"` sem aspas não é preferência de estilo. Sem aspas, o Bash faz word splitting no conteúdo e depois tenta expandir glob no resultado — então uma variável com `relatório final.txt` vira dois argumentos, e uma com `*` vira a lista do diretório. É o bug número um da linguagem, e ele só aparece quando o dado fica interessante.

A regra prática: **toda expansão vai entre aspas, sempre** (`"$var"`, `"$(cmd)"`, `"${arr[@]}"`, `"$@"`), e você só tira as aspas quando souber dizer em voz alta por que quer splitting ali. As exceções reais são poucas e conhecidas: dentro de `[[ ]]` à esquerda, em `(( ))`, e do lado direito de `==` quando o glob é intencional.

### 5. Saiba o que roda em subshell

Metade dos bugs de "a variável sumiu" e "o erro não subiu" é a mesma coisa: um subshell. `cmd | while read ...` roda o loop num subshell, então tudo que ele atribuir morre no `done`. Command substitution, `( )`, background `&` e cada estágio de pipe são processos separados; eles herdam, não devolvem.

```bash
# Errado: total volta zero, sempre
find . -name '*.log' | while read -r f; do total=$((total + 1)); done

# Certo: o loop roda no shell atual
while IFS= read -r f; do total=$((total + 1)); done < <(find . -name '*.log')
```

`references/processos-e-concorrencia.md` tem o modelo completo; `references/io-e-redirecionamento.md` cobre a process substitution que resolve.

### 6. Rode o shellcheck antes de dizer que terminou

`shellcheck` pega, de graça, a maior parte do que esta skill descreve: variável sem aspas, `set -e` mascarado, `read` sem `-r`, subshell perdido, comparação errada. Não é opcional e não é sobre estilo — cada `SCxxxx` é um bug catalogado com explicação.

Se precisar silenciar, silencie a linha específica com `# shellcheck disable=SC2086` **e um comentário dizendo por quê**. Um `disable` no topo do arquivo sem justificativa é o mesmo que desligar o linter.

Depois do shellcheck: `bash -n` para sintaxe e, no que for não trivial, execute de verdade — com espaço no nome do arquivo, com variável vazia, com o comando falhando. Um script testado só no caminho feliz não foi testado.

## Quando parar

- Se você está escrevendo a terceira função que serializa dado estruturado em string delimitada, o Bash já acabou. Reescreva em Python — e diga isso, não continue.
- Um `eval` quase sempre significa que a resposta certa era um array (`"${cmd[@]}"`). As exceções legítimas são raras e você deve saber nomeá-la.
- `sed` ou `grep` dentro de um loop sobre linhas costuma ser um `awk` de uma linha. Fork por iteração é o motivo de scripts Bash serem lentos.
- Abstração prematura em Bash dói mais do que em linguagem com módulo: uma "biblioteca" de funções `source`-ada por cinco scripts vira acoplamento global sem interface. Duplique antes de generalizar.
- Se a mudança pede um "framework" de shell, o problema não é o framework que falta.
