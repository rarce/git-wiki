# CLAUDE.md — wiki schema

This file is the schema that Claude follows when maintaining this wiki.
It is loaded automatically by Claude Code whenever you work from this
directory. Edit it to change conventions for your wiki; the `git-wiki`
skill defers to what is written here.

This wiki follows the [Karpathy LLM-wiki pattern][gist]:

1. **Raw sources** under `sources/` — immutable; never rewrite them.
2. **Wiki pages** under `pages/`, `people/`, `concepts/` — LLM-maintained
   synthesis. This is where knowledge compounds.
3. **Schema** (this file) — conventions the LLM follows.

## Layout

| path          | purpose                                                        |
|---------------|----------------------------------------------------------------|
| `index.md`    | content catalog, grouped by category. Update on every ingest.  |
| `log.md`      | append-only log. Prefix: `## [YYYY-MM-DD] <op> | <title>`.     |
| `pages/`      | general topic pages.                                           |
| `people/`     | one file per person, kebab-case (e.g. `ada-lovelace.md`).      |
| `concepts/`   | one file per concept.                                          |
| `sources/`    | raw source notes. Immutable. Only add files; do not rewrite.   |

## Page format

Every wiki page begins with YAML frontmatter:

```yaml
---
title: Human-readable title
tags: [tag1, tag2]
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources: [sources/<file>.md, ...]
---
```

The body is standard markdown. Link to other wiki pages with **relative
paths**, e.g. `[Ada Lovelace](../people/ada-lovelace.md)`. Every mention of
an entity with its own page should be linked.

## Log format

`log.md` is append-only. Every entry starts with a level-2 heading of the
form:

```
## [YYYY-MM-DD] <op> | <title>
```

where `<op>` is one of `setup`, `ingest`, `query`, `lint`, `refactor`. The
body is a one-paragraph note describing what changed and which files were
touched. This makes the log grep-friendly:

```sh
grep '^## \[2026-04' log.md        # everything from April 2026
grep 'ingest |' log.md              # every ingest
```

## Index format

`index.md` is organized by category. Each entry is a single line with a
link, a short description, and optional tags. Example:

```markdown
## Concepts
- [BM25 scoring](concepts/bm25-scoring.md) — ranking function behind lexical
  search. Tags: `search`, `information-retrieval`.
```

## Search

This wiki is indexed by [`qmd`][qmd]. Prefer `qmd` over raw grep when doing
a query:

```sh
qmd query   "full natural-language question"   # hybrid, best quality
qmd search  "keyword"                          # BM25, fast
qmd vsearch "phrase"                           # vector only
qmd get     "pages/foo.md"                     # retrieve a page
qmd embed                                      # re-embed after edits
```

After any write to the wiki, run `qmd embed` so new content is searchable.

## Operations

See the `git-wiki` skill for the full procedures. The short version:

- **ingest** — save raw source under `sources/`, create or update
  summary/entity/concept pages, update `index.md`, append to `log.md`,
  commit + push, `qmd embed`. A good ingest touches 10-15 files.
- **query** — read `index.md`, run `qmd query`, synthesize an answer citing
  wiki pages. Append a one-line entry to `log.md`. File novel findings back
  as new pages (this is the compounding step).
- **lint** — periodic health check: stale updated dates, orphan pages,
  broken relative links, index drift, missing cross-references,
  contradictions. Report before mutating.

[gist]: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
[qmd]: https://github.com/tobi/qmd
