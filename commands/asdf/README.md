<div align='justify'>

# **ASDF**

> Uma forma símples de gerenciar versões das suas ferramentas / linguagens, tornando possível alterar de forma muito fácil a versão global e setar versões locais para cada diretório.

#

- [Instalação](#instalação)
- [Exemplos](#exemplos)
  - [Instalando Uma Versão Global do NodeJS](#instalando-uma-versão-global-do-nodejs)
  - [Instalando Uma Versão Local do NodeJS](#instalando-uma-versão-local-do-nodejs)
- [ASDF CLI](#asdf-cli)
- [Referências](#referências)

#

## **Instalação**

**1. Instalando o `curl` e o `git`:**
```sh
# Ubuntu / Debian
$ sudo apt install curl git -y

# Fedora / CentOS
$ sudo dnf install curl git -y

# Arch / Manjaro 
$ sudo pacman -S curl git --noconfirm
```

**2. Após o git e o curl instalado, vamos fazer o clone do repositório [asdf](https://github.com/asdf-vm/asdf):**

```sh
$ git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.8.0
```

**3. Vamos adicionar agora no arquivo de configurações do bash o caminho para o executável do asdf:**

```sh
$ echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc
$ echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc

# Se você estiver utilizando o zsh, pode adicionar também:
$ echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.zshrc
$ echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.zshrc
```
> Verifique agora se ao rodar o comando `asdf` é retornado para você algumas informações, caso o comando não seja encontrado, reinicie o seu terminal ou abra um novo!

## **Exemplos**

Nos exemplos será utilizado o NodeJS, mas lembrando que é possível instalar diversas ferramentas. Você pode verificar isso no link *plugins-list* que foi listado nas [Referências](#referências).

### Instalando Uma Versão Global do NodeJS

Adicionando o plugin do NodeJS com o comando `plugin-add`:

```sh 
$ asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git
```

No caso do NodeJS, também é necessário esse comando:

```sh
$ bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring
```

Agora você consegue ver todas as versões do NodeJS utilizando o comando `asdf list-all nodejs`. Vamos instalar a versão desejada do NodeJS:

```sh
$ asdf install nodejs 14.17.0
```

Agora precisamos setar a versão desejada do NodeJS de forma global, como se fosse a instalação padrão, fazendo que todo o nosso sistema utilize essa versão:
```sh
$ asdf global nodejs 14.17.0
```

> Pronto! Agora você está utilizando o NodeJS na versão 14.17.0 e você pode confirmar utilizando o comando `node -v`.

Se você quiser alterar a versão do NodeJS de forma global na sua aplicação, agora é só você utilizar os comandos:

```sh
$ asdf install nodejs 16.1.0
$ asdf global nodejs 16.1.0

# Caso queira remover a versão antiga:
$ asdf uninstall nodejs 14.17.0
```

### Instalando Uma Versão Local do NodeJS

Além de instalar globalmente a versão desejada, podemos instalar localmente (para cada diretório que desejarmos) a versão da nossa ferramenta. Automaticamente, quando entrarmos nesse diretório, a versão será alterada:

Vamos instalar o NodeJS na versão 10.0.0, por exemplo, e definir essa versão que será utilizada quando estivermos trabalhando no projeto '`foo`':

```sh
$ cd ~/projects/foo
$ asdf install nodejs 10.0.0
$ asdf local nodejs 10.0.0
```

Pronto! Agora toda vez que entrarmos no diretório do projeto `foo`, o NodeJS estará na versão 10.0.0.

## **ASDF CLI**

Alguns comandos úteis para relembrar, utilizando como exemplo a ferramenta `foo`:

Instalar uma versão global:

```sh
$ asdf install foo x.x.x
```

Instalar uma versão local:

```sh
$ asdf local foo x.x.x
```

Listar todas as versões que já foram instaladas:
```sh
$ asdf list foo
```

Listar todas as versões disponíveis para serem instaladas:

```sh
$ asdf list-all foo
```

Listar os plugins que já foram adicionados:

```sh
$ asdf plugin list
```

Atualizar os plugins:

```sh
$ asdf plugin update --all
```

## Referências

- [asdf](https://github.com/asdf-vm/asdf)
- [asdf-get-started](https://asdf-vm.com/#/)
- [plugins-list](https://asdf-vm.com/#/plugins-all)
- [commands-list](https://asdf-vm.com/#/core-commands)

</div>