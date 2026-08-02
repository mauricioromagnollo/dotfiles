#!/usr/bin/env bash
# Triagem de segurança de um repositório local.
#
# Roda só o que lê arquivo: varredura de segredo, dependências vulneráveis e SAST.
# Nenhum pacote sai para a rede em direção ao alvo — não há scan de host aqui, de
# propósito, porque isso exigiria autorização que este script não tem como verificar.
#
# A saída é uma lista de HIPÓTESES. Ferramenta encontra padrão; só a leitura do código
# confirma que existe caminho da entrada até o sink e que o impacto é real.
#
#   uso: triagem.sh [caminho-do-repo] [-o diretorio-de-saida]

set -uo pipefail   # sem -e: uma ferramenta ausente ou com achados não deve abortar a triagem

REPO="${1:-.}"
[[ "${REPO}" == -* ]] && REPO="."
OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--out) OUT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) shift ;;
  esac
done

if [[ ! -d "$REPO" ]]; then
  echo "erro: '$REPO' não é um diretório" >&2
  exit 2
fi
REPO="$(cd "$REPO" && pwd)"
OUT="${OUT:-${TMPDIR:-/tmp}/triagem-$(basename "$REPO")}"
mkdir -p "$OUT"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
dim()  { printf '\033[2m%s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# Executa um passo, salva a saída completa em arquivo e diz onde ela está.
# Se a ferramenta não existir, imprime como instalar e segue — triagem parcial
# vale mais que triagem que não roda.
passo() {
  local nome="$1" bin="$2" instalar="$3"; shift 3
  bold "▸ ${nome}"
  if ! have "$bin"; then
    dim "  ${bin} não encontrado — instale com: ${instalar}"
    return 1
  fi
  local log="${OUT}/${nome//[^a-zA-Z0-9]/-}.log"
  "$@" >"$log" 2>&1
  local rc=$?
  dim "  saída completa: ${log} (exit ${rc})"
  return 0
}

bold "Triagem de $REPO"
dim "resultados em $OUT"
echo

# ── 1. Segredos ───────────────────────────────────────────────────────────────
# O histórico importa tanto quanto a árvore de trabalho: um `git rm` não remove
# o blob, e uma chave commitada há um ano continua válida se ninguém a revogou.
if passo "segredos" gitleaks "brew install gitleaks" \
     gitleaks detect --source "$REPO" --redact --no-banner \
       --report-format json --report-path "${OUT}/gitleaks.json"; then
  n=$(grep -c '"RuleID"' "${OUT}/gitleaks.json" 2>/dev/null || echo 0)
  echo "  → ${n} candidato(s) a segredo"
  [[ "$n" -gt 0 ]] && dim "  ordem correta: revogar → rotacionar → investigar uso → só então limpar histórico"
fi
echo

# ── 2. Dependências ───────────────────────────────────────────────────────────
# osv-scanner cobre vários ecossistemas com uma invocação e usa a OSV, que é mais
# precisa em versão afetada que o `npm audit`.
if passo "dependencias" osv-scanner "brew install osv-scanner" \
     osv-scanner scan source --recursive "$REPO"; then
  grep -cE 'CVE-|GHSA-' "${OUT}/dependencias.log" 2>/dev/null \
    | xargs -I{} echo "  → {} linha(s) mencionando advisory"
  dim "  triagem: alcançabilidade > EPSS/KEV > CVSS. Ver references/supply-chain-e-cicd.md"
fi
echo

# ── 3. SAST ───────────────────────────────────────────────────────────────────
# --config auto escolhe as regras pela linguagem detectada. Em repositório grande
# isso demora; --config p/security-audit é o corte mais rápido.
if passo "sast" semgrep "brew install semgrep" \
     semgrep scan --config auto --error --quiet --json \
       --output "${OUT}/semgrep.json" "$REPO"; then
  n=$(grep -o '"check_id"' "${OUT}/semgrep.json" 2>/dev/null | wc -l | tr -d ' ')
  echo "  → ${n} achado(s) bruto(s)"
  dim "  espere ruído: cada um precisa das 4 perguntas de calibração do SKILL.md"
fi
echo

# ── 4. Sinais que ferramenta nenhuma procura ──────────────────────────────────
# Não são vulnerabilidades — são lugares onde elas se concentram, para orientar
# a leitura manual, que é o que de fato encontra falha de autorização e de lógica.
bold "▸ pontos de partida para leitura manual"
cd "$REPO" || exit 1
# -E é obrigatório no fallback: o grep sem ele usa regex básica, onde o `|` das
# alternâncias abaixo é caractere literal e todo padrão falha em silêncio.
GREP=$(have rg && echo "rg -n --no-heading -S" || echo "grep -rnIE")

conta() {
  local rotulo="$1" padrao="$2"
  local n
  n=$($GREP -e "$padrao" . 2>/dev/null \
        | grep -vE '(^|/)(node_modules|dist|build|vendor|\.git|coverage)/' \
        | wc -l | tr -d ' ')
  [[ "${n:-0}" -gt 0 ]] && printf '  %-34s %s\n' "$rotulo" "$n"
  return 0
}

conta "escape hatch de SQL cru"        'queryRawUnsafe|executeRawUnsafe|knex\.raw|sequelize\.query|\.Raw\('
conta "shell com string"               'child_process.*exec\(|exec\(.*\$\{|shell\s*[:=]\s*true|shell=True'
conta "HTML sem escape"                'dangerouslySetInnerHTML|innerHTML\s*=|v-html|bypassSecurityTrust'
conta "TLS desligado"                  'rejectUnauthorized\s*:\s*false|InsecureSkipVerify|verify\s*=\s*False'
conta "body inteiro em write"          'data:\s*(req|request|ctx)\.body|Object\.assign\(.*\.body|update\((req|request)\.body|\.\.\.(req|request)\.body'
conta "body cru em variável"           '(const|let|var)[[:space:]]+[a-zA-Z_]+[[:space:]]*=[[:space:]]*(req|request|ctx)\.body'
conta "id do cliente em query"         '(req|request|ctx)\.(params|query|body)\.[a-zA-Z]*([Ii]d|ID)\b'
conta "auth desligada / TODO"          'skipAuth|noAuth|TODO.*(auth|permiss|secur)|FIXME.*(auth|secur)'
conta "aleatoriedade fraca"            'Math\.random\(\)'
conta "workflow com alvo perigoso"     'pull_request_target|\$\{\{[[:space:]]*github\.event\.(issue|pull_request|comment)'

# Superfície mobile — o binário está na mão do atacante, então segredo embarcado
# e armazenamento local pesam mais aqui do que no backend.
conta "segredo embarcado"              '(sk_live|pk_live|AIza[0-9A-Za-z_-]{10}|xox[baprs]-|ghp_|AKIA[0-9A-Z]{10})'
conta "armazenamento local sem cifra"  'AsyncStorage\.(set|get)Item|UserDefaults\.standard\.set|SharedPreferences'
conta "WebView com JS"                 'javaScriptEnabled|addJavascriptInterface|setJavaScriptEnabled|allowUniversalAccess'
conta "manifest permissivo"            'allowBackup="true"|usesCleartextTraffic="true"|android:exported="true"'

echo
bold "Próximo passo"
cat <<'TXT'
  Nada acima é achado ainda. Para cada linha que interessar, feche o caminho:
  quem controla a entrada, por onde ela passa, que controle existe no meio, e o
  que um atacante consegue no fim. Só então classifique e escreva.

  A leitura manual que mais rende não está nesta lista: controle de acesso por
  objeto e lógica de negócio com dinheiro ou limite. Ver
  references/autorizacao-e-logica-de-negocio.md.
TXT
