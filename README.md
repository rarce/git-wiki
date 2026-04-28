# git-wiki

[![License: MIT](https://img.shields.io/github/license/rarce/git-wiki)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/rarce/git-wiki?style=social)](https://github.com/rarce/git-wiki/stargazers)
[![Agent Skills compatible](https://img.shields.io/badge/Agent%20Skills-compatible-blue)](https://agentskills.io)

**A self-maintaining knowledge wiki that lives in your own git repo.** Your agent ingests sources, writes the pages, keeps cross-references current, and answers from the wiki. On-device hybrid search. No server, no SaaS, no DB — local commits by default, optional GitHub publishing.

```sh
bash <(curl -sL https://raw.githubusercontent.com/rarce/git-wiki/main/install.sh)
```

![git-wiki demo](assets/demo.gif)

## Features

- **Compounds over time** — every ingested source and answered query enriches the wiki.
- **Your repo is the store** — versioned, portable, shareable locally or via GitHub, diffs as a change log. Zero hidden state to corrupt.
- **On-device hybrid search** — BM25 + vector + LLM rerank via [`qmd`][qmd]. No external API, no embeddings uploaded anywhere.
- **No server, no SaaS** — the only runtime is `bash`, `git`, `qmd`, and optionally `gh` for GitHub sync.
- **Agent-Skills standard** — works with Claude Code, Cursor, Codex, Copilot, or any [Agent-Skills-compatible agent][home].
- **Lint for drift** — stale dates, orphans, broken links, index drift, missing cross-references, and contradictions.

## How it works

Three layers from the [Karpathy LLM-wiki pattern][gist]:

1. **Raw sources** (`sources/`) — articles, papers, notes. Immutable; the LLM reads but never rewrites them.
2. **Wiki pages** (`pages/`, `people/`, `concepts/`) — LLM-owned markdown; synthesis accumulates here.
3. **Schema** (`CLAUDE.md` + `SKILL.md`) — conventions and workflows the LLM follows.

Two navigation files:

- **`index.md`** — content catalog, grouped by category. Read first on every query.
- **`log.md`** — append-only chronological record, grep-friendly (`## [YYYY-MM-DD] <op> | <title>`).

```
ingest                                        query
  │                                             │
  ▼                                             ▼
sources/ ──► wiki pages ──► index.md ──► answer with citations
                 ▲                  │
                 └───── qmd search ─┘
```

## git-wiki vs classic RAG

|                    | Classic RAG            | git-wiki                       |
|--------------------|------------------------|--------------------------------|
| What's retrieved   | raw chunks             | curated wiki pages             |
| Quality over time  | flat                   | compounds with each ingest     |
| Storage            | vector DB              | markdown in git                |
| Contradictions     | silently coexist       | surfaced by `lint`             |
| Ownership          | vendor-specific DB     | a git repo you own             |
| Portability        | migrate DB, reindex    | `git clone` / local copy       |

## Who this is for

- You read a lot (papers, articles, docs) and wish your agent remembered it.
- You want your knowledge **portable, versioned, and yours** — not locked in a vendor DB.
- You already work in an Agent-Skills-compatible editor (Claude Code, Cursor, Codex, Copilot…).
- You prefer plain markdown + git over proprietary formats.

> **This repo hosts the skill, not a wiki.** Installing it gives your agent
> the `git-wiki` capability; running `scripts/setup.sh` creates your personal
> wiki as a separate repo. The installer creates a private GitHub repo by
> default, or a local-only repo with `WIKI_VIS=local`.

## Pieces

| piece    | role                                                         |
|----------|--------------------------------------------------------------|
| `gh`     | create, clone, and push GitHub-backed wiki repos (optional for local-only) |
| `git`    | local commits and branching                                  |
| `qmd`    | on-device BM25 + vector + LLM-rerank search over the wiki    |
| the skill| runs from any [Agent-Skills-compatible agent][home] and edits the files |

## Prerequisites

- [`gh`][gh] authenticated (`gh auth status`) for GitHub-backed installs
- `git` with `user.name` and `user.email` configured
- `node` + `npm` (for `qmd`)
- [`qmd`][qmd] (the setup script will install it globally if missing)
- An [Agent-Skills-compatible agent][home] (Claude Code, Cursor, Copilot, …)

## Install

### One-shot (recommended)

```sh
bash <(curl -sL https://raw.githubusercontent.com/rarce/git-wiki/main/install.sh)
```

The installer will:

1. Check dependencies (`git`, `node`, `npm`, and authenticated `gh` unless
   using local-only mode).
2. Prompt for a wiki repo name, visibility (`private`, `public`, or `local`),
   and local wiki path.
3. Create the wiki repo: `gh repo create --clone` for GitHub-backed installs,
   or `git init` for `WIKI_VIS=local`.
4. `npx -y skills add rarce/git-wiki` — drops the skill into
   `.agents/skills/git-wiki/` **inside the wiki repo**.
5. Runs the bundled scaffolder
   (`.agents/skills/git-wiki/scripts/setup.sh`), which lays out `CLAUDE.md`,
   `index.md`, `log.md`, `pages/`, `people/`, `concepts/`, `sources/`,
   registers the wiki with `qmd`, commits, and pushes only when an `origin`
   remote exists.

### Non-interactive (env vars)

All three prompts can be pre-set:

```sh
WIKI_REPO=my-wiki WIKI_VIS=private WIKI_DIR=~/wiki \
  bash <(curl -sL https://raw.githubusercontent.com/rarce/git-wiki/main/install.sh)
```

For a local-only wiki that is never published to GitHub:

```sh
WIKI_REPO=my-wiki WIKI_VIS=local WIKI_DIR=~/wiki \
  bash <(curl -sL https://raw.githubusercontent.com/rarce/git-wiki/main/install.sh)
```

### Inspect-then-run (paranoid option)

```sh
curl -sL https://raw.githubusercontent.com/rarce/git-wiki/main/install.sh -o install.sh
less install.sh
bash install.sh
```

### Manual install

If you prefer to run each step yourself — for example, to add the skill to
a wiki repo you already have:

```sh
# 1. Create (or cd into) the wiki repo
gh repo create my-wiki --private --clone
cd my-wiki

# 2. Install the skill into this repo
npx -y skills add rarce/git-wiki

# 3. Run the bundled scaffolder
.agents/skills/git-wiki/scripts/setup.sh
```

For manual local-only setup:

```sh
mkdir my-wiki
cd my-wiki
git init -b main
npx -y skills add rarce/git-wiki
GIT_WIKI_LOCAL=1 .agents/skills/git-wiki/scripts/setup.sh
```

The scaffolder expects to be run from inside a git repo; it will not create
or clone a repo for you.

## Usage

From inside the wiki repo (or with `WIKI_DIR` set), invoke your agent and
use any of:

- **Ingest a source**: *"ingest this article: `<url|path>`"*
- **Query**: *"what do I know about `<topic>`?"*
- **Lint**: *"lint the wiki"* — checks for stale dates, orphans, broken
  links, index drift, and missing cross-references.

The skill takes care of file layout, index/log updates, `qmd` re-embedding,
and local commits. GitHub-backed repos can also push to `origin`.

## Skill layout (this repo)

```
rarce/git-wiki/
├── README.md                      # this file
└── skills/
    └── git-wiki/                  # the Agent Skill itself
        ├── SKILL.md               # frontmatter + instructions
        ├── scripts/
        │   └── setup.sh           # bootstrap for the user's personal wiki
        └── assets/
            └── wiki-scaffold/     # files copied into the user's wiki on setup
                ├── CLAUDE.md      # wiki schema
                ├── README.md
                ├── index.md
                ├── log.md
                └── gitattributes
```

See [`skills/git-wiki/SKILL.md`](skills/git-wiki/SKILL.md) for the full
skill definition, triggering rules, and operation procedures.

## Layout of the wiki `setup.sh` creates

```
<wiki-repo>/
├── CLAUDE.md          # schema the LLM follows (loaded automatically)
├── README.md          # short intro for humans browsing on GitHub
├── index.md           # categorized content catalog
├── log.md             # append-only chronological log
├── pages/             # general topic pages
├── people/            # one file per person (kebab-case)
├── concepts/          # one file per concept
└── sources/           # raw source notes (immutable)
```

## References

- [Agent Skills — specification][spec] and [overview][home]
- [skills.sh][skills] — the `npx skills add` CLI used to install this skill
- [Karpathy's LLM-wiki gist][gist]
- [`qmd` — Query Markdown][qmd]
- [GitHub CLI][gh]

[home]: https://agentskills.io
[spec]: https://agentskills.io/specification
[skills]: https://skills.sh
[gist]: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
[qmd]: https://github.com/tobi/qmd
[gh]: https://cli.github.com
