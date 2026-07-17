<div align="center">

# 🛠️ dotfiles

### *My machine, my rules.*

A cozy home for the configs, scripts, aliases and Claude Code skills that turn a fresh laptop into **my** laptop. ✨

<br />

![macOS](https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Shell Script](https://img.shields.io/badge/Shell_Script-121011?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Claude](https://img.shields.io/badge/Claude_Code-D97757?style=for-the-badge&logo=anthropic&logoColor=white)

<br />

*"Dotfiles are like a toothbrush — everyone should have their own, and you should never use someone else's."* 🪥
*(…but you're very welcome to steal ideas.)*

</div>

---

## 📖 What is this?

**Dotfiles** are the little hidden config files (`.zshrc`, `.gitconfig`, and friends) that carry your personal setup between machines. This repo is where I keep mine — plus handy scripts, install helpers, and a growing set of **Claude Code skills** — so setting up a new machine is a coffee-length task instead of a lost afternoon. ☕

## 🗂️ What's inside

| Folder | What lives here |
| :--- | :--- |
| 🧠 **[`claude/`](./claude)** | My **Claude Code skills** (`craft`, `nodejs`, `golang`, `dba`, `sre`, `bash`, `ui-ux`, `conventional-commits`) plus a one-command installer. |
| 💻 **[`console/`](./console)** | Handy terminal commands & scripts — project backups, cleanup helpers, `node_modules` nukers, audio splitters and more. |
| 🎮 **[`cs2/`](./cs2)** | Counter-Strike 2 configs — `autoexec.cfg` and practice setup. |
| 🌱 **[`git/`](./git)** | My global `.gitconfig` and Git tweaks. |
| 🍎 **[`macos/`](./macos)** | macOS bootstrap script and system defaults. |
| 🐧 **[`ubuntu/`](./ubuntu)** | Ubuntu setup — Zsh, Powerlevel10k, asdf and cleanup scripts. |
| 🧩 **[`visual-studio-code/`](./visual-studio-code)** | VS Code `settings.json`, keybindings and an extensions installer. |

## 🚀 Quick start

```bash
# clone it wherever you like
git clone https://github.com/mauricioromagnollo/dotfiles.git
cd dotfiles
```

Each folder is self-contained — dive into the one you need:

```bash
# 🧠 install my Claude Code skills
cd claude && ./install.sh

# 🍎 bootstrap a macOS machine
bash macos/mac_os.sh

# 🐧 bootstrap an Ubuntu machine
bash ubuntu/ubuntu.sh

# 🧩 install my VS Code extensions
bash visual-studio-code/install-extensions.sh
```

> 💡 Most folders ship their own `README.md` with the details. When in doubt, read before you run — these are *my* preferences, not universal truths.

## 🧠 Highlight: Claude Code skills

The [`claude/`](./claude) folder exports the [Agent Skills](https://docs.anthropic.com/en/docs/claude-code/skills) I use to make Claude Code reason like a specialist — a DBA, an SRE, a backend engineer — instead of a generalist. One command installs them all:

```bash
cd claude && ./install.sh
```

Full list and docs live in **[`claude/README.md`](./claude/README.md)**.

## 🤝 Contributing

This is a personal setup, so it evolves with my taste. But if you spot a bug, have a cool script, or just want to say hi — issues and PRs are always welcome. 🎉

---

<div align="center">

Made with ☕ and a questionable amount of `set -euo pipefail` by **[@mauricioromagnollo](https://github.com/mauricioromagnollo)**

⭐ *If any of this saved you time, drop a star!*

</div>
