# 🧠 Claude Code Skills

A curated set of [Claude Code](https://docs.anthropic.com/en/docs/claude-code) **Agent Skills** I use every day.
Each skill is a focused knowledge pack that Claude loads automatically when the task matches — so the model reasons like a specialist (a DBA, an SRE, a backend engineer…) instead of a generalist.

> A **skill** is a folder with a `SKILL.md` (the entry point + trigger description) and optional `references/` files that Claude opens on demand. Nothing runs in the background — a skill only activates when its description matches what you're doing.

---

## 📦 What's inside

| Skill | Command | What it knows |
| :--- | :--- | :--- |
| **craft** | `/craft` | Clean Code, DRY/KISS/YAGNI, SOLID, cohesion & coupling, refactoring, and design patterns (GoF, DDD, Fowler/PoEAA) — **with a strong emphasis on when *not* to apply them**. |
| **nodejs** | `/nodejs` | Backend Node.js/TypeScript — Node 24 runtime, strict TypeScript, Fastify, Prisma, Zod and Vitest. Guards the four boundaries: input, core types, output, persistence. |
| **golang** | `/golang` | Idiomatic Go — package & API design, error handling, concurrency (goroutines, channels, `context`, `sync`), testing, modules and performance. |
| **dba** | `/dba` | Databases end-to-end — ER modeling, normalization, SQL, indexes, execution plans, transactions & concurrency, zero-downtime migrations and operational PostgreSQL. |
| **sre** | `/sre` | Reliability & DevOps — CI/CD (GitHub Actions & Azure Pipelines), Terraform/OpenTofu, Docker, Kubernetes and AWS. |
| **bash** | `/bash` | Robust Shell scripting — quoting & expansions, `set -euo pipefail` + traps, arrays, subshells, file descriptors, signals, `getopts`, and the Unix toolbelt (grep/sed/awk/find/xargs/jq). |
| **ui-ux** | `/ui-ux` | Interface & experience design — Norman, Krug, Gestalt, Nielsen's heuristics, Laws of UX, accessibility (WCAG) and modern UI patterns. |
| **conventional-commits** | `/conventional-commits` | Commit messages that follow Conventional Commits & commitlint (`@commitlint/config-conventional`), always in English. |
| **english-teacher** | `/english-teacher` | English for Brazilian learners — L1 interference & false friends, pronunciation, tenses & aspect, collocations, fluency & listening, corporate/tech English, error correction, study plans and exams (IELTS, TOEFL, Cambridge). |

Every skill defaults to being **conservative**: it explains the trade-offs and tells Claude when the right move is to do *nothing*.

---

## 🚀 Installation

Skills live in `~/.claude/skills/`. The `install.sh` script copies them there for you.

```bash
# from the repo root
cd claude

# install every skill
./install.sh

# or install only the ones you want
./install.sh craft dba nodejs
```

Then restart Claude Code (or run `/skills`) so it picks up the new skills.

### Options

| Command | Description |
| :--- | :--- |
| `./install.sh` | Install all skills (asks before overwriting an existing one) |
| `./install.sh --force` | Overwrite existing skills without asking |
| `./install.sh craft dba` | Install only the named skills |
| `./install.sh --list` | List the skills available in this repo |
| `./install.sh --help` | Show usage |

You can override the install target with the `CLAUDE_SKILLS_DIR` environment variable:

```bash
CLAUDE_SKILLS_DIR=/some/other/path ./install.sh
```

### Manual install

Prefer to do it by hand? Just copy the folders:

```bash
cp -R skills/craft ~/.claude/skills/
```

---

## 🛠️ Anatomy of a skill

```
skills/craft/
├── SKILL.md            # entry point: frontmatter (name + description) and the core guidance
└── references/         # deep-dive files Claude opens only when needed
    ├── solid.md
    ├── clean-code.md
    ├── ddd.md
    └── ...
```

The `description` in the frontmatter is what tells Claude *when* to load the skill — it's written to match natural requests ("refactor this", "why is this query slow?", "make a script for this"), not just keywords.

---

## ✍️ Creating your own

Want to build one? Ask Claude Code to use the **skill-creator** skill, or read the
[official Agent Skills docs](https://docs.anthropic.com/en/docs/claude-code/skills).
