#!/bin/bash

chmod +x install-extensions.sh 

extensions=()

while IFS= read -r line
do
  extensions+=("$line")
done < "installed-extensions.list"

for extension in "${extensions[@]}"
do 
  echo "[*] Installing VSCode extension '$extension'..."
  code --install-extension $extension
done