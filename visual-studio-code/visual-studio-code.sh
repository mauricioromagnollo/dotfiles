#!/bin/bash

chmod +x visual-studio-code.sh 

function install-vscode() {
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
  sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
  sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
  rm -f packages.microsoft.gpg
  sudo apt install apt-transport-https -y
  sudo apt update
  sudo apt install code -y
}

function install-extensions() {
  local extensions=( "mads-hartmann.bash-ide-vscode" "steoates.autoimport" "ms-vscode.cpptools" 
  "Compulim.vscode-clock" "formulahendry.code-runner" "naumovs.color-highlight" "mikestead.dotenv" 
  "ms-azuretools.vscode-docker" "EditorConfig.EditorConfig" "DigitalBrainstem.javascript-ejs-support" 
  "dbaeumer.vscode-eslint" "wix.vscode-import-cost" "ritwickdey.LiveServer" "DavidAnson.vscode-markdownlint" 
  "PKief.material-icon-theme" "rocketseat.theme-omni" "2gua.rainbow-brackets" 
  "ms-vscode.vscode-typescript-tslint-plugin" "jpoissonnier.vscode-styled-components" "eamodio.gitlens" 
  "GraphQL.vscode-graphql" "abusaidm.html-snippets" "hediet.vscode-drawio" "adpyke.codesnap" "humao.rest-client" 
  "formulahendry.auto-rename-tag" )

  for extension in "${extensions[@]}"
  do 
    code --install-extension $extension
  done
}

# install-vscode
install-extensions
