#!/bin/bash

chmod +x pop-os.sh

function main() {
	sudo apt update -y && sudo apt upgrade -y

	sudo apt install -y build-essential gnome-tweaks ubuntu-restricted-extras
	
	flatpak install flathub io.dbeaver.DBeaverCommunity

	sudo apt install virtualbox

	# Install Fonts
	sudo apt install -y fonts-firacode

	sudo apt install nautilus-dropbox -y

	sudo apt install -y steam discord transmission vlc telegram-desktop obs-studio

	# Google Chrome
	wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
	sudo dpkg -i google-chrome-stable_current_amd64.deb
	rm google-chrome-stable_current_amd64.deb
	
	
	sudo ufw enable
}

function install-razer-settings-mannager() {
	sudo apt install software-properties-gtk -y
	sudo add-apt-repository ppa:openrazer/stable -y
	sudo apt update
	sudo apt install openrazer-meta -y
	sudo gpasswd -a $USER plugdev
	sudo add-apt-repository ppa:polychromatic/stable -y
	sudo apt update
	sudo apt install polychromatic -y
}

function setup-terminal-theme-and-shell() {
	sudo apt install -y zsh
	# Install Meslo LGS Nerd Font
	git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.powerlevel10k
echo 'source ~/.powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc
	  cd $HOME
  mkdir .zsh
  git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
  echo "source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" >> .zshrc


	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh
	echo "source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ~/.zshrc

  chsh -s /usr/bin/zsh
}


function setup-editors() {
	sudo apt install -y vim
}

function install-spotify-client() {
	curl -sS https://download.spotify.com/debian/pubkey_5E3C45D7B312C643.gpg | sudo apt-key add - 
	echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
	sudo apt update && sudo apt install spotify-client -y
}

function install-asdf-and-languages() {
	git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.10.0
	echo ". $HOME/.asdf/asdf.sh" >> ~/.bashrc
	echo ". $HOME/.asdf/asdf.sh" >> ~/.zshrc
}

function install-vscode() {
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
  sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
  sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
  rm -f packages.microsoft.gpg
  sudo apt install apt-transport-https -y
  sudo apt update
  sudo apt install code -y
  
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

function install-insomnia() {
	echo "deb [trusted=yes arch=amd64] https://download.konghq.com/insomnia-ubuntu/ default all" \
    | sudo tee -a /etc/apt/sources.list.d/insomnia.list

	# Refresh repository sources and install Insomnia
	sudo apt-get update
	sudo apt-get install insomnia
}

# ==============================================================================
# install-packages.sh
# ==============================================================================
function docker-and-docker-compose() {
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

	 curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

	echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

	sudo apt-get update
 	sudo apt-get install docker-ce docker-ce-cli containerd.io -y

	  sudo groupadd docker

		sudo usermod -aG docker $USER

		newgrp docker 
		docker run hello-world

	sudo systemctl enable docker.service
 	sudo systemctl enable containerd.service
}