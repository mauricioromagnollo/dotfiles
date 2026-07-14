#!/bin/bash

# Uncomment the next line if running the script directly!
# chmod +x backup-project.sh

# =================================================================
# This script backs up a project based on a list of files and
# directories declared inside the project itself.
#
# - It reads a list file (default: .backup-project.list) placed in
#   the project root. Each non-empty, non-comment line is a path
#   (file or directory) relative to the project root, e.g.:
#       tmp/
#       .env
#       config/secrets.yml
# - The listed items are copied - preserving their relative
#   structure - into a staging folder named after the project.
# - That folder is compressed into <project-name>.zip and moved to
#   the destination directory.
# - Everything is staged in a temporary directory that is always
#   removed on exit (success or failure), so no trace is left inside
#   the project or the current directory.
#
# $ backup-project <source-dir> <destination-dir>
# $ backup-project . ~/backups
# =================================================================

set -euo pipefail

LIST_FILE_NAME=".backup-project.list"

# Staging dir kept at script scope so the EXIT trap can always see it.
stageDir=""
# Guarantee the staging dir is removed no matter how we exit (success
# or failure), so no trace is left behind.
trap '[[ -n "${stageDir:-}" ]] && rm -rf "$stageDir"' EXIT

function print-msg() {
  local colorName="$1"
  local msgToPrint="$2"
  local colorID=37

  case $colorName in
    "-red") colorID=31 ;;
    "-blue") colorID=34 ;;
    "-green") colorID=32 ;;
    "-white") colorID=37 ;;
  esac

  echo -e '\033['$colorID'm'"$msgToPrint"'\033[m'
}

function print-usage() {
  print-msg -blue "Usage: backup-project <source-dir> <destination-dir>"
  print-msg -white "  <source-dir>       Project directory (use . for the current one)"
  print-msg -white "  <destination-dir>  Where the resulting .zip will be placed"
  print-msg -white ""
  print-msg -white "The project must contain a '$LIST_FILE_NAME' file listing the"
  print-msg -white "files/directories to back up (one relative path per line)."
}

function backup-project() {
  local sourceArg="${1:-}"
  local destArg="${2:-}"

  # --- Validate arguments -----------------------------------------
  if [[ -z "$sourceArg" || -z "$destArg" ]]; then
    print-msg -red "[!] Missing arguments."
    print-usage
    return 1
  fi

  if [[ ! -d "$sourceArg" ]]; then
    print-msg -red "[!] Source directory not found: $sourceArg"
    return 1
  fi

  # Resolve absolute paths so we can safely cd around.
  local sourceDir
  sourceDir="$(cd "$sourceArg" && pwd)"
  local projectName
  projectName="$(basename -- "$sourceDir")"

  local listFile="$sourceDir/$LIST_FILE_NAME"
  if [[ ! -f "$listFile" ]]; then
    print-msg -red "[!] List file not found: $listFile"
    print-msg -white "    Create it with one relative path per line (tmp/, .env, ...)."
    return 1
  fi

  # Create the destination if it does not exist yet.
  mkdir -p "$destArg"
  local destDir
  destDir="$(cd "$destArg" && pwd)"

  # --- Prepare a temporary, self-cleaning staging area ------------
  stageDir="$(mktemp -d "${TMPDIR:-/tmp}/backup-project.XXXXXX")"

  local projectStage="$stageDir/$projectName"
  mkdir -p "$projectStage"

  # --- Copy each listed item, preserving relative structure -------
  local copiedCount=0
  local item
  while IFS= read -r item || [[ -n "$item" ]]; do
    # Skip blank lines and comments.
    item="${item#"${item%%[![:space:]]*}"}"   # trim leading whitespace
    item="${item%"${item##*[![:space:]]}"}"    # trim trailing whitespace
    item="${item%/}"                            # drop trailing slash
    [[ -z "$item" || "$item" == \#* ]] && continue

    # Reject anything that could escape the staging folder.
    if [[ "$item" == /* || "$item" == *..* ]]; then
      print-msg -red "[!] Skipping (unsafe path): $item"
      continue
    fi

    local sourceItem="$sourceDir/$item"
    if [[ ! -e "$sourceItem" ]]; then
      print-msg -red "[!] Skipping (not found): $item"
      continue
    fi

    # Recreate the parent path inside the staging folder, then copy.
    local parentDir
    parentDir="$(dirname -- "$item")"
    mkdir -p "$projectStage/$parentDir"
    cp -R "$sourceItem" "$projectStage/$parentDir/"
    print-msg -green "[+] Added: $item"
    copiedCount=$((copiedCount + 1))
  done < "$listFile"

  if [[ "$copiedCount" -eq 0 ]]; then
    print-msg -red "[!] Nothing to back up. Check your $LIST_FILE_NAME."
    return 1
  fi

  # --- Compress the staged folder and deliver it ------------------
  local zipName="$projectName.zip"
  (
    cd "$stageDir"
    zip -qr "$zipName" "$projectName"
  )
  mv "$stageDir/$zipName" "$destDir/$zipName"

  print-msg -blue "[*] Backup created: $destDir/$zipName"
}

backup-project "${1:-}" "${2:-}"
