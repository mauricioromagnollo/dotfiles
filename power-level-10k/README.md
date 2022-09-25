# Oh My Zsh + Spaceship

## **Dependências**

```bash
# Arch / Manjaro
sudo pacman -S zsh curl git --noconfirm

# Debian / Ubuntu
sudo apt install zsh curl git -y

# Red Hat / Fedora
sudo dnf install zsh curl git -y
```

## **Instalando o Oh My Zsh**

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
```

## **Fira Code (Retina)**

```bash
# Arch/Manjaro
sudo pacman -S ttf-fira-code --noconfirm

# Ubuntu/Debian
sudo apt install fonts-firacode -y

# Red Hat/Fedora
sudo dnf install fira-code-fonts -y
```

> Após instalar a fonte, altere a fonte do seu terminal para **Fira Code Retina**.

## **Adicionando o Spaceship Prompt**

```bash
git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt"
```

```bash
ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
```

> Agora, abra o arquivo dentro do diretório /home chamado: ~/.zshrc e altere o valor da variável ZSH_THEME adicionando "spaceship":

```
ZSH_THEME="spaceship"
```

## **Mudando o Layout do Tema Spaceship**

```bash
SPACESHIP_PROMPT_ORDER=(
  user          # Username section
  dir           # Current directory section
  host          # Hostname section
  git           # Git section (git_branch + git_status)
  hg            # Mercurial section (hg_branch  + hg_status)
  exec_time     # Execution time
  line_sep      # Line break
  vi_mode       # Vi-mode indicator
  jobs          # Background jobs indicator
  exit_code     # Exit code section
  char          # Prompt character
)
SPACESHIP_USER_SHOW=always
SPACESHIP_PROMPT_ADD_NEWLINE=false
SPACESHIP_CHAR_SYMBOL="$"
SPACESHIP_CHAR_SUFFIX=" "
```

## **Oh My Zsh (Plugins)**

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/zdharma/zinit/master/doc/install.sh)"
```

Após a instalação, abra novamente o seu arquivo `~/.zshrc` e após a linha `### End of ZInit's installer chunk`, adicione:


```
zinit light zdharma/fast-syntax-highlighting
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-completions
```

## **Zsh Plugins**

Abra o seu arquivo `~/.zshrc` e procure pelos plugins, algo desse tipo:

```bash
plugins=(git)
```

Adicione no lugar essa lista de plugins:

```bash
plugins=(
	git
	archlinux
	asdf
	ruby
	aws
	composer
	docker-compose
	docker-machine
	docker
	dotenv
	github
	gitignore
	heroku
	node
	npm
	react-native
	redis-cli
	sudo
	vscode
	yarn
)
```

## **Fazendo o Terminal Abrir Direto no Zsh (Default Shell)**

Abra o arquivo ` ~/.bashrc`:

```bash
vim ~/.bashrc

# ou

code ~/.bashrc
```

Adicione essa linha no início do arquivo:

```bash
exec zsh
```

## **Visual Studio Code**

Para alterar o terminal do seu Visual Studio Code:

<kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>P</kbd> &rarr; **Open Settings (JSON)**

Adicione essa linha no JSON:

```json
{
  "terminal.integrated.shell.linux": "/bin/zsh",
}
```