# Repository Guidelines

## Project Structure & Module Organization

This repository distributes the `git-wiki` Agent Skill and its installer.
Root-level files are project documentation and entry points: `README.md`,
`install.sh`, `LICENSE`, and `assets/demo.gif`. The skill lives in
`skills/git-wiki/`: `SKILL.md` defines behavior and trigger rules,
`scripts/setup.sh` scaffolds a user's wiki repository, and
`assets/wiki-scaffold/` contains Markdown templates copied into that wiki
(`CLAUDE.md`, `index.md`, `log.md`, `README.md`, and `gitattributes`).

## Build, Test, and Development Commands

- `bash -n install.sh` checks installer shell syntax.
- `bash -n skills/git-wiki/scripts/setup.sh` checks the wiki scaffolder syntax.
- `shellcheck install.sh skills/git-wiki/scripts/setup.sh` runs shell linting
  when ShellCheck is available.
- `bash install.sh` runs the full interactive installer, creating or reusing a
  wiki repo. Use `WIKI_VIS=local` to avoid GitHub publishing; other modes
  exercise GitHub and `npx` side effects. `qmd` must already be installed.

## Coding Style & Naming Conventions

Shell scripts use Bash with `set -euo pipefail`, small helper functions
(`say`, `warn`, `die`, `require`), uppercase environment variables, and
lowercase local variables. Keep scripts POSIX-friendly where practical, but
preserve Bash when existing code depends on it. Markdown files use concise
headings, fenced `sh` examples, and relative links. Wiki page and scaffold file
names should be lowercase kebab-case where generated content needs names.

## Testing Guidelines

There is no automated test harness. For script changes, run both `bash -n`
commands and ShellCheck if installed. For scaffold changes, review the generated
paths expected by `setup.sh`, especially `skills/git-wiki/assets/wiki-scaffold/`.
For installer changes, prefer `WIKI_VIS=local` for smoke tests. Use a
disposable private GitHub repo and temporary `WIKI_DIR` only when validating
remote publishing, for example:
`WIKI_REPO=tmp-git-wiki WIKI_VIS=private WIKI_DIR=/tmp/tmp-git-wiki bash install.sh`.

## Commit & Pull Request Guidelines

Git history uses Conventional Commit-style subjects such as `docs: ...`,
`fix(install.sh): ...`, `feat: ...`, `refactor: ...`, and `chore: ...`.
Follow that pattern and name the affected component when useful. Pull requests
should explain the user-visible behavior change, list commands run, and note
any local repo, GitHub, npm, or `qmd` side effects. Include screenshots or GIF
updates only when changing README visuals or demo assets.

## Security & Configuration Tips

Do not commit personal wiki content, tokens, generated local clones, or machine
specific paths. `install.sh` calls `npm`, `npx`, `git`, `qmd`, and optionally
`gh`; `setup.sh` must not install external packages. Document new network or
authentication requirements clearly before adding them.
