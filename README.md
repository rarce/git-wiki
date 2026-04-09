# git-wiki

A Claude Code skill that implements [Andrej Karpathy's LLM-wiki pattern][gist]
on top of a personal GitHub repo, with on-device hybrid search via [qmd][qmd].

Instead of re-doing RAG on raw sources every query, the LLM maintains a
persistent, compounding markdown wiki: it ingests sources, writes summaries
and entity/concept pages, keeps indexes current, and answers questions from
the wiki itself. You curate sources; the LLM does the bookkeeping.

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

| piece         | role                                                         |
|---------------|--------------------------------------------------------------|
| `gh`          | create and clone the personal GitHub wiki repo, push updates |
| `git`         | local commits and branching                                  |
| `qmd`         | on-device BM25 + vector + LLM-rerank search over the wiki    |
| Claude Code   | runs the `git-wiki` skill and edits the files                |

## Prerequisites

- [`gh`][gh] authenticated (`gh auth status`)
- `git` with `user.name` and `user.email` configured
- `node` + `npm` (for `qmd`)
- [`qmd`][qmd] (the setup script will install it globally if missing)
- Claude Code

## Install

```sh
git clone https://github.com/rarce/git-wiki ~/devel/git-wiki
cd ~/devel/git-wiki
./setup.sh
```

> This repo hosts the **skill** (templates, `setup.sh`, `SKILL.md`). It is
> *not* a wiki itself — running `setup.sh` creates your personal wiki as a
> separate GitHub repo (private by default).

`setup.sh` will:

1. Check dependencies and `gh` auth.
2. Prompt for a wiki repo name, visibility (default: private), and local path.
3. Create the GitHub repo via `gh repo create` (skipped if it already exists).
4. Clone it locally.
5. Copy the scaffolding from `templates/` into the clone: `CLAUDE.md`,
   `index.md`, `log.md`, plus the `pages/` `people/` `concepts/` `sources/`
   directories.
6. Register the wiki as a `qmd` collection and run an initial `qmd embed`.
7. Make the first commit and push it.

## Usage

From inside the wiki clone (or with `WIKI_DIR` set), invoke Claude Code and
use any of:

- **Ingest a source**: *"ingest this article: `<url|path>`"*
- **Query**: *"what do I know about `<topic>`?"*
- **Lint**: *"lint the wiki"* — checks for stale dates, orphans, broken
  links, index drift, and missing cross-references.

The skill takes care of file layout, index/log updates, `qmd` re-embedding,
and committing + pushing through `gh`.

## Layout of a wiki repo

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

- [Karpathy's LLM-wiki gist][gist]
- [`qmd` — Query Markdown][qmd]
- [skills.sh][skills]
- [GitHub CLI][gh]

[gist]: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
[qmd]: https://github.com/tobi/qmd
[skills]: https://skills.sh
[gh]: https://cli.github.com
