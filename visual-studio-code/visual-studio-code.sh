#!/bin/bash

chmod +x visual-studio-code.sh 

function install-extensions() {
  local extensions=( $@ )

  for extension in "${extensions[@]}"
  do 
    code --install-extension $extension
  done
}

EXTENSIONS=( "mads-hartmann.bash-ide-vscode" "steoates.autoimport" "ms-vscode.cpptools" 
  "Compulim.vscode-clock" "formulahendry.code-runner" "naumovs.color-highlight" "mikestead.dotenv" 
  "ms-azuretools.vscode-docker" "EditorConfig.EditorConfig" "DigitalBrainstem.javascript-ejs-support" 
  "dbaeumer.vscode-eslint" "wix.vscode-import-cost" "ritwickdey.LiveServer" "DavidAnson.vscode-markdownlint" 
  "PKief.material-icon-theme" "rocketseat.theme-omni" "2gua.rainbow-brackets" 
  "ms-vscode.vscode-typescript-tslint-plugin" "jpoissonnier.vscode-styled-components" "eamodio.gitlens" 
  "GraphQL.vscode-graphql" "abusaidm.html-snippets" )

install-extensions "${EXTENSIONS[@]}"

unset EXTENSIONS
