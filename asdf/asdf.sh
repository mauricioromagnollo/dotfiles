#!/bin/bash

chmod +x asdf.sh

NODEJS_VERSION=$1

git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.8.0
echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc
echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc
echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.zshrc
echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.zshrc

# Install NodeJS
asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git
bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring
asdf install nodejs $NODEJS_VERSION
asdf global nodejs $NODEJS_VERSION

# Install Yarn
asdf plugin-add yarn
asdf install yarn latest