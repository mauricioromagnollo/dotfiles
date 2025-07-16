#!/bin/bash

# Uncomment the next line if running the script directly!
chmod +x notes.sh

# =================================================================
# This script opens a file inside my Dropbox called NOTES.txt 
# that I use to temporarily annotate important stuff.
#
# If the file does not exist, it will be created.
#
# $ notes
# =================================================================

function main() {
  local FILE="NOTES.txt"
  local FILE_WITH_PATH=~/Dropbox/$FILE

  if [ -f $FILE_WITH_PATH ]; then
    open-file $FILE_WITH_PATH
  else
    create-file $FILE_WITH_PATH
    open-file $FILE_WITH_PATH
  fi
}

function create-file() {
  touch $FILE_WITH_PATH
}

function open-file() {
  xdg-open $FILE_WITH_PATH </dev/null >/dev/null 2>&1 & disown && exit
}

main