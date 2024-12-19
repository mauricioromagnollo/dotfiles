#!/bin/bash

chmod +x mac-clear.sh

# Limpar a lixeira
echo "[*] Cleaning up trash files..."
rm -rf ~/.Trash/* -y

# Deletar os arquivos temporários
echo "[*] Cleaning up temporary files..."
rm -rf /tmp/* -y

# Deletar os logs
echo "[*] Cleaning up logs..."
rm -rf ~/Library/Logs/* -y

# Deletar os caches
echo "[*] Cleaning up caches..."
rm -rf ~/Library/Caches/* -y

# Deletar os arquivos da pasta Downloads
echo "[*] Cleaning up Downloads..."
rm -rf ~/Downloads/* -y

# Deletar as pastas node_modules dos projetos
echo "[*] Cleaning up node_modules..."
find ~/Projects/ -type d -name "node_modules" -print | awk -F'/node_modules' '{print $1}' | sort -u | xargs rm -rf

# Deletar dist, build, tmp, coverage, etc dos projetos
# Deletar todos os arquivos de docker (imagens, volumes...)
