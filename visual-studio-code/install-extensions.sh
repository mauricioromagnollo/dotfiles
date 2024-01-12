#!/bin/bash

chmod +x install-extensions.sh 

extensions=( "mads-hartmann.bash-ide-vscode" "steoates.autoimport" "ms-vscode.cpptools" 
"Compulim.vscode-clock" "formulahendry.code-runner" "naumovs.color-highlight" "mikestead.dotenv" 
"ms-azuretools.vscode-docker" "EditorConfig.EditorConfig" "DigitalBrainstem.javascript-ejs-support" 
"dbaeumer.vscode-eslint" "wix.vscode-import-cost" "ritwickdey.LiveServer" "DavidAnson.vscode-markdownlint" 
"PKief.material-icon-theme" "rocketseat.theme-omni" "2gua.rainbow-brackets" 
"ms-vscode.vscode-typescript-tslint-plugin" "jpoissonnier.vscode-styled-components" "eamodio.gitlens" 
"GraphQL.vscode-graphql" "abusaidm.html-snippets" "hediet.vscode-drawio" "adpyke.codesnap" "humao.rest-client" 
"formulahendry.auto-rename-tag" "mauricioromagnollo.devxonado-snippets" )

for extension in "${extensions[@]}"
do 
  code --install-extension $extension
done
