---
name: conventional-commits
description: Write git commit messages following Conventional Commits and commitlint (@commitlint/config-conventional), always in English. Use this skill whenever a commit is being created, reworded, amended, squashed, or split — including when the user says "commit this", "commit isso", "salva isso", "faz o commit", asks for a commit message, writes a PR or release title, fixes a commitlint failure, or when finishing any code change that will end up in git history. Trigger it even if the user does not mention Conventional Commits, commitlint, or semantic versioning by name.
---

# Commit conventions

Commit history is a durable, public artifact. It gets read months later by
someone bisecting a regression, by release tooling deciding the next version,
and by anyone browsing the repo on GitHub. That audience is the reason for
every rule below — the goal is a log where each subject line explains a change
without opening the diff.

## Language: always English

Write every commit message in English — subject, body, and footers — even when
the conversation with the user is in Portuguese or any other language. The
history is read by tooling and by contributors who may not share the user's
language, and a log that mixes languages is hard to scan.

This applies to the message only. Don't translate identifiers, file paths,
CMS field names, or quoted output; those keep their original form.

## Format

```
<type>(<scope>)!: <subject>
<blank line>
<body>
<blank line>
<footer>
```

Scope and `!` are optional. Body and footer are optional but usually worth it —
see below.

### Type

Pick from the `config-conventional` enum. Choosing the right one matters
because release tooling reads it: `feat` bumps the minor version, `fix` the
patch, and `!`/`BREAKING CHANGE:` the major.

| Type | Use for |
|---|---|
| `feat` | a new capability visible to a user of the code |
| `fix` | a bug fix |
| `perf` | a change that improves performance without changing behavior |
| `refactor` | restructuring that neither fixes a bug nor adds a feature |
| `docs` | documentation only |
| `test` | adding or fixing tests only |
| `build` | build system, Dockerfile, dependencies, bundler config |
| `ci` | CI configuration and workflows |
| `chore` | maintenance that fits nothing above (config, tooling, cleanup) |
| `style` | formatting only, no code meaning changed |
| `revert` | reverting a previous commit |

When two types fit, ask what the change is *for*, not what it touched. Editing
a test file to cover a bug you just fixed is part of the `fix`; editing it
because the assertion was wrong is `test`.

### Scope

The scope names the area of the codebase affected. Before inventing one, look
at what the repo already uses, so the log stays greppable:

```bash
git log --pretty=format:'%s' -200 | sed -n 's/^[a-z]*(\([^)]*\)).*/\1/p' | sort | uniq -c | sort -rn
```

Reuse an existing scope when one fits. Keep it lowercase, one or two words,
and prefer a domain name (`resume`, `blog`, `a11y`, `design`) over a file path.
Omit the scope entirely when the change is repo-wide or the type alone says
enough — an empty scope is better than a vague one.

### Subject

The subject is the line everyone reads, so make it carry the change.

- Imperative mood, as if completing "this commit will…": `add`, `fix`,
  `remove` — never `added`, `fixes`, `removing`.
- Start lowercase, and don't end with a period. commitlint rejects
  sentence-case/upper-case subjects and a trailing full stop.
- Keep the whole header under ~72 characters. commitlint's limit is 100, but
  git tooling and GitHub truncate around 72, so treat that as the real budget.
- Say what changed and, if it fits, where it lands — `raise post body to 18px
  (~75ch)` beats `update styles`.

### Body

Add a body whenever the reason isn't obvious from the subject — which is most
non-trivial commits. Explain **why** the change was needed and what the
previous behavior was; the diff already shows what changed, and duplicating it
in prose wastes the reader's time.

Wrap at 72 columns. Git doesn't wrap for you, so an unwrapped paragraph reads
as one long line in `git log`. Multiple paragraphs are fine.

A useful shape: first paragraph states the problem, second states the approach
and any deliberate trade-off or thing intentionally left alone.

### Footer

- Link the issue it resolves: `Close #147` (also `Closes`, `Fixes`, `Refs #12`
  when it's related but not resolved).
- Breaking changes get `BREAKING CHANGE: <what breaks and how to migrate>` in
  the footer, and a `!` before the colon in the header.

## Atomic commits

One commit, one logical change. If the subject needs "and", or you're tempted
to write a bulleted body covering unrelated areas, it should be two commits —
that's what makes `git revert` and `git bisect` useful later.

When the working tree mixes concerns, stage by path (`git add <paths>`) and
commit in separate passes rather than bundling them.

## Workflow

1. Read the actual change — `git status` and `git diff` (plus `git diff
   --staged`) — before writing anything. The message must describe what the
   diff does, not what the user said they wanted.
2. Check recent history for tone and scope vocabulary:
   `git log --pretty=format:'%s' -20`.
3. Split into atomic commits if the diff covers unrelated concerns.
4. Write the message. Use a heredoc so the body keeps its line breaks:
   ```bash
   git commit -F - <<'EOF'
   fix(design): raise post body to 18px (~75ch)

   Apply text-lg and leading-relaxed on the PostBody wrapper, bringing the
   measure down from ~88ch into the ideal range. Remove the now-redundant
   leading-relaxed from ParagraphSlice.

   Close #147
   EOF
   ```
5. Run the checklist below before committing.

If the repo has commitlint wired into a hook, a rejected commit tells you which
rule failed — fix the message, don't bypass with `--no-verify`.

## Checklist

- [ ] Message is entirely in English
- [ ] Type is from the enum and reflects the change's purpose
- [ ] Scope is lowercase and reuses the repo's vocabulary (or is absent)
- [ ] Subject is imperative, lowercase, no trailing period, header < 72 chars
- [ ] Body explains *why* and is wrapped at 72 columns (when a body is needed)
- [ ] Issue footer (`Close #N`) present when the commit resolves one
- [ ] `!` + `BREAKING CHANGE:` present if the change breaks consumers
- [ ] The commit is one logical change

## Examples

**A styling fix with context worth recording:**

```
fix(a11y): lighten dark-theme primary to pass AA contrast

The dark primary (#78023b) gave 3.1:1 against the surface, under the
4.5:1 AA floor for body text. Raise it to #ec4d92 (5.04:1) instead of
darkening the surface, which would have broken the code blocks.

Close #191
```

**A feature, no body needed because the subject is self-contained:**

```
feat(seed): allow filtering seed-projects by papel via CLI arg
```

**A breaking change:**

```
refactor(api)!: return null instead of 0 for unparsed start dates

BREAKING CHANGE: getCurrentAge now returns null when the start date is
missing. Callers doing arithmetic on the result must handle null.
```

**Rejected subjects and why:**

| Bad | Problem |
|---|---|
| `Fixed the bug.` | past tense, capitalized, trailing period, says nothing |
| `feat: cria componente Container` | not in English |
| `update stuff` | no type, no information |
| `feat(Blog): Add Search` | scope not lowercase, subject in start-case |
| `fix: fix login and also refactor the header and bump next` | not atomic |
