# git-wiki

An [Agent Skill][spec] that implements [Andrej Karpathy's LLM-wiki pattern][gist]
on top of a personal GitHub repo, with on-device hybrid search via [qmd][qmd].

Instead of re-doing RAG on raw sources every query, the LLM maintains a
persistent, compounding markdown wiki: it ingests sources, writes summaries
and entity/concept pages, keeps indexes current, and answers questions from
the wiki itself. You curate sources; the LLM does the bookkeeping.

> **This repo hosts the skill, not a wiki.** Installing it gives your agent
> the `git-wiki` capability; running `scripts/setup.sh` creates your personal
> wiki as a separate GitHub repo (private by default).

## Architecture

Three layers, per the Karpathy pattern:

1. **Raw sources** (`sources/`) — immutable articles, papers, notes. The LLM
   reads these but never rewrites them.
2. **Wiki pages** (`pages/`, `people/`, `concepts/`, …) — LLM-generated
   markdown, fully owned by the LLM. This is where synthesis accumulates.
3. **Schema** (`CLAUDE.md` inside the wiki repo, plus this skill's `SKILL.md`) —
   the conventions, page formats, and workflows the LLM follows.

Two root-level navigation files:

- **`index.md`** — content-oriented catalog, grouped by category. Updated on
  every ingest. The LLM reads this first when answering queries.
- **`log.md`** — append-only chronological record. Every entry is prefixed
  with `## [YYYY-MM-DD] <op> | <title>` so it is grep-friendly.

## Pieces

| piece    | role                                                         |
|----------|--------------------------------------------------------------|
| `gh`     | create and clone the personal GitHub wiki repo, push updates |
| `git`    | local commits and branching                                  |
| `qmd`    | on-device BM25 + vector + LLM-rerank search over the wiki    |
| the skill| runs from any [Agent-Skills-compatible agent][home] and edits the files |

## Prerequisites

- [`gh`][gh] authenticated (`gh auth status`)
- `git` with `user.name` and `user.email` configured
- `node` + `npm` (for `qmd`)
- [`qmd`][qmd] (the setup script will install it globally if missing)
- An [Agent-Skills-compatible agent][home] (Claude Code, Cursor, Copilot, …)

## Install

**Primary path — Agent Skills CLI:**

```sh
npx skills add rarce/git-wiki
```

Your agent will discover the skill at its next launch. Then bootstrap your
personal wiki by running the bundled setup script from the installed skill's
directory (path varies by client — check `npx skills list` or your agent's
skills directory):

```sh
<path-to-installed-skill>/scripts/setup.sh
```

**Manual alternative** — clone this repo and run the script directly:

```sh
git clone https://github.com/rarce/git-wiki ~/devel/git-wiki
~/devel/git-wiki/skills/git-wiki/scripts/setup.sh
```

Then symlink `skills/git-wiki/SKILL.md` into whichever skills directory
your agent discovers.

### What `setup.sh` does

1. Check dependencies and `gh` auth.
2. Prompt for a wiki repo name, visibility (default: private), and local path.
3. Create the GitHub repo via `gh repo create` (skipped if it already exists).
4. Clone it locally.
5. Copy the scaffolding from `skills/git-wiki/assets/wiki-scaffold/` into the
   clone: `CLAUDE.md`, `index.md`, `log.md`, plus `pages/` `people/`
   `concepts/` `sources/`.
6. Register the wiki as a `qmd` collection and run an initial `qmd embed`.
7. Make the first commit and push it.

## Usage

From inside the wiki clone (or with `WIKI_DIR` set), invoke your agent and
use any of:

- **Ingest a source**: *"ingest this article: `<url|path>`"*
- **Query**: *"what do I know about `<topic>`?"*
- **Lint**: *"lint the wiki"* — checks for stale dates, orphans, broken
  links, index drift, and missing cross-references.

The skill takes care of file layout, index/log updates, `qmd` re-embedding,
and committing + pushing through `gh`.

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
