#!/bin/bash

# Uncomment the next line if running the script directly!
# chmod +x backup-project.sh

# =================================================================
# This script backs up a project based on a fixed list of files and
# directories declared in the BACKUP_ITEMS array below.
#
# - Each entry is a path (file or directory) relative to the project
#   root, e.g.: tmp/, .env, config/secrets.yml
# - The listed items are copied - preserving their relative
#   structure - into a staging folder named after the project.
# - That folder is compressed into <project-name>.zip and moved to
#   the destination directory.
# - Everything is staged in a temporary directory that is always
#   removed on exit (success or failure), so no trace is left inside
#   the project or the current directory.
#
# The array lives inside the script so it can be installed to
# /usr/bin (or another PATH dir) and used as a global command.
#
# $ backup-project <source-dir> <destination-dir>
# $ backup-project . ~/backups
# =================================================================

set -euo pipefail

# Files and directories to back up (relative to the project root).
BACKUP_ITEMS=(
  "tmp/"
  ".env"
)

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
  print-msg -white "Edit the BACKUP_ITEMS array in this script to choose what"
  print-msg -white "gets backed up (paths relative to the project root)."
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

  if [[ "${#BACKUP_ITEMS[@]}" -eq 0 ]]; then
    print-msg -red "[!] BACKUP_ITEMS is empty. Add paths to back up."
    return 1
  fi

  # Resolve absolute paths so we can safely cd around.
  local sourceDir
  sourceDir="$(cd "$sourceArg" && pwd)"
  local projectName
  projectName="$(basename -- "$sourceDir")"

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
  for item in "${BACKUP_ITEMS[@]}"; do
    item="${item#"${item%%[![:space:]]*}"}"   # trim leading whitespace
    item="${item%"${item##*[![:space:]]}"}"    # trim trailing whitespace
    item="${item%/}"                            # drop trailing slash
    [[ -z "$item" ]] && continue

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
  done

  if [[ "$copiedCount" -eq 0 ]]; then
    print-msg -red "[!] Nothing to back up. Check the BACKUP_ITEMS array."
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
