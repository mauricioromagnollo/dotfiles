#!/usr/bin/env bash
#
# install.sh — Install the Claude Code skills from this repo into ~/.claude/skills
#
# Usage:
#   ./install.sh                 Install all skills (asks before overwriting)
#   ./install.sh --force         Overwrite existing skills without asking
#   ./install.sh craft dba       Install only the named skills
#   ./install.sh --list          List the skills available in this repo
#   ./install.sh --help          Show this help
#
set -euo pipefail

# Resolve the directory this script lives in, so it works from any cwd.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
SKILLS_SRC="${SCRIPT_DIR}/skills"
SKILLS_DEST="${CLAUDE_SKILLS_DIR:-${HOME}/.claude/skills}"

FORCE=0
LIST=0
declare -a REQUESTED=()

# --- pretty output -----------------------------------------------------------
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; GREEN=$'\033[32m'; BLUE=$'\033[34m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  BOLD=""; GREEN=""; BLUE=""; YELLOW=""; RESET=""
fi

info()  { printf '%s\n' "${BLUE}==>${RESET} $*"; }
ok()    { printf '%s\n' "${GREEN}  ✔${RESET} $*"; }
warn()  { printf '%s\n' "${YELLOW}  !${RESET} $*"; }

usage() {
  sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# --- parse arguments ---------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --force|-f) FORCE=1 ;;
    --list|-l)  LIST=1 ;;
    --help|-h)  usage; exit 0 ;;
    -*)         warn "unknown option: $arg"; usage; exit 1 ;;
    *)          REQUESTED+=("$arg") ;;
  esac
done

if [[ ! -d "$SKILLS_SRC" ]]; then
  warn "skills directory not found at ${SKILLS_SRC}"
  exit 1
fi

# Collect the skills present in this repo (a skill is a dir with a SKILL.md).
declare -a AVAILABLE=()
for dir in "$SKILLS_SRC"/*/; do
  [[ -f "${dir}SKILL.md" ]] || continue
  AVAILABLE+=("$(basename "$dir")")
done

if [[ "$LIST" -eq 1 ]]; then
  info "Skills available in this repo:"
  printf '  - %s\n' "${AVAILABLE[@]}"
  exit 0
fi

# Decide which skills to install.
declare -a TO_INSTALL=()
if [[ "${#REQUESTED[@]}" -gt 0 ]]; then
  for name in "${REQUESTED[@]}"; do
    if [[ -d "${SKILLS_SRC}/${name}" && -f "${SKILLS_SRC}/${name}/SKILL.md" ]]; then
      TO_INSTALL+=("$name")
    else
      warn "no such skill in this repo: ${name} (try --list)"
      exit 1
    fi
  done
else
  TO_INSTALL=("${AVAILABLE[@]}")
fi

info "Installing ${#TO_INSTALL[@]} skill(s) into ${BOLD}${SKILLS_DEST}${RESET}"
mkdir -p "$SKILLS_DEST"

for name in "${TO_INSTALL[@]}"; do
  src="${SKILLS_SRC}/${name}"
  dest="${SKILLS_DEST}/${name}"

  if [[ -e "$dest" ]]; then
    if [[ "$FORCE" -ne 1 ]]; then
      printf '%s' "${YELLOW}  ?${RESET} ${name} already exists — overwrite? [y/N] "
      read -r reply </dev/tty || reply=""
      if [[ ! "$reply" =~ ^[Yy]$ ]]; then
        warn "skipped ${name}"
        continue
      fi
    fi
    rm -rf "$dest"
  fi

  cp -R "$src" "$dest"
  ok "${name}"
done

info "Done. Restart Claude Code (or run /skills) to pick up the new skills."
