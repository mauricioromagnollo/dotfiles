#!/bin/bash

chmod +x zsh.sh

sudo dnf install -y zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt"
ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma/zinit/master/doc/install.sh)"

# Make zsh default shell
echo 'exec zsh'$'\n'"$(cat $HOME/.bashrc)" > $HOME/.bashrc

# Move .zshrc file to home
cp .zshrc $HOME/.zshrc