---
name: git-wiki
description: Maintain a personal, LLM-curated knowledge wiki in a GitHub repo using the Karpathy LLM-wiki pattern. Use this skill when the user wants to ingest a source (article, paper, notes, URL) into their wiki, query accumulated knowledge ("what do I know about X?", "what did I learn from Y?"), or lint the wiki for drift. Activate even when the user does not explicitly say "wiki" — e.g., "save this paper to my notes", "add this to what I know about X", or "check my notes for contradictions". Uses `gh` for GitHub operations and `qmd` for on-device hybrid BM25+vector search. Do not invoke for unrelated markdown editing or general GitHub work.
compatibility: Requires gh (authenticated), git, node+npm, and qmd (auto-installed by scripts/setup.sh on first run). Designed for Claude Code and other agents that support Agent Skills.
license: MIT
metadata:
  author: rarce
  version: "0.1.0"
  upstream: https://github.com/rarce/git-wiki
---

# git-wiki

Ingest, query, and lint a personal markdown wiki stored in a GitHub repo,
using the three-layer [Karpathy LLM-wiki pattern][gist]: raw sources →
wiki pages → schema. `gh` handles GitHub; `qmd` handles search.

## When to use this skill

Invoke when the user asks to:

- **ingest** a new source — "add this paper / article / meeting notes to my wiki"
- **query** the wiki — "what do I know about X?" / "what did I learn from Y?"
- **lint** — "lint the wiki", "check the wiki for drift"

Also activate on close synonyms, even if the user does not say "wiki":

- "save this to my notes" / "add this to what I know about X"
- "what did I learn about X last month?"
- "check my notes for contradictions"

Do **not** invoke this skill for unrelated markdown editing or general
GitHub work.

## First-time setup

If the user has never run this skill before, they need to bootstrap a
personal wiki repo. Run the bundled script from the skill root:

```sh
scripts/setup.sh
```

It creates a personal GitHub repo (private by default), clones it locally,
scaffolds the layout from `assets/wiki-scaffold/`, registers the wiki with
`qmd`, and makes the first commit. After that, all operations below target
the local clone.

## Preconditions

Before any operation, resolve the wiki directory and confirm tools exist:

```sh
WIKI_DIR="${WIKI_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
test -f "$WIKI_DIR/CLAUDE.md"          # schema present → right directory
command -v gh && command -v qmd && command -v git
gh auth status
```

If `CLAUDE.md` is missing, the wiki has not been bootstrapped — tell the
user to run `scripts/setup.sh` (see *First-time setup* above) and stop.

Always read `$WIKI_DIR/CLAUDE.md` first. It is the authoritative schema;
this skill defers to anything written there.

## Operations

### ingest

Ingesting a source means: saving the raw source, writing synthesis into
wiki pages, cross-linking, updating the index and log, committing, pushing,
and re-embedding. A good ingest touches **10–15 files**.

1. **Clean tree check.** `git -C "$WIKI_DIR" status --porcelain` must be
   empty. If dirty, ask the user to stash or commit first.
2. **Capture the source.** Fetch or read the content, then save it under
   `sources/<slug>.md` with frontmatter:
   ```yaml
   ---
   title: <original title>
   url: <source url if any>
   kind: article | paper | notes | transcript | other
   captured: YYYY-MM-DD
   ---
   ```
   The body can be the full text or a condensed quote. **Never rewrite a
   source file on subsequent ingests** — it is immutable.
3. **Find candidate pages to touch.** Read `index.md`, then run:
   ```sh
   qmd query "<topic of the source>"
   ```
   The top 5–10 hits plus anything referenced in `index.md` form the
   candidate set.
4. **Write the summary page.** Either create a new page under `pages/`
   (topic), `people/` (person), or `concepts/` (concept), or update an
   existing one. New pages must have the full YAML frontmatter:
   ```yaml
   ---
   title: ...
   tags: [...]
   created: YYYY-MM-DD
   updated: YYYY-MM-DD
   sources: [sources/<slug>.md]
   ---
   ```
   Updates must bump `updated:` and append to `sources:`.
5. **Cross-link.** For every entity (person, concept, tool) mentioned in
   the new content, ensure there is a link. If the target page exists,
   use a relative link. If it doesn't and the entity is significant, create
   a stub page.
6. **Update `index.md`.** Add or update the entry under the right category
   (Pages / People / Concepts / Sources). One line per entry with a link,
   short description, and tags.
7. **Append to `log.md`.**
   ```
   ## [YYYY-MM-DD] ingest | <title>
   <one paragraph: what the source was about, what pages were created or
   updated (list them), any notable cross-references.>
   ```
8. **Commit + push.**
   ```sh
   git -C "$WIKI_DIR" add -A
   git -C "$WIKI_DIR" commit -m "ingest: <title>"
   git -C "$WIKI_DIR" push
   ```
9. **Re-embed.** `qmd embed` — only changed files are re-embedded, so this
   is fast.

### query

Querying the wiki means: answering the user from wiki content, with
citations, and (when the answer is novel) filing the synthesis back as a
new page.

1. **Structural scan.** Read `$WIKI_DIR/index.md` to get the map.
2. **Hybrid search.**
   ```sh
   qmd query "<the user's natural-language question>"
   ```
   `qmd query` does BM25 + vector + LLM rerank; it is the best default.
   If it is noisy, fall back to `qmd search` (keywords) or `qmd vsearch`
   (phrase similarity).
3. **Read the top hits.** Use `qmd get "<path>"` or your Read tool. Read
   enough to answer, not the whole file unless necessary.
4. **Synthesize.** Write the answer from the wiki pages. Cite each page
   inline with a relative link, e.g. `(see [BM25](concepts/bm25.md))`.
   If the wiki doesn't contain the answer, say so explicitly rather than
   inventing.
5. **Compound.** If the synthesized answer is novel and useful, ask the
   user if they want to file it back as a new page. This is the
   compounding step that makes the wiki grow in value over time.
6. **Log the query.** Append to `log.md`:
   ```
   ## [YYYY-MM-DD] query | <short question>
   <one line: what was asked; which pages answered it.>
   ```
7. **Commit** only if you wrote anything (a new page, a log entry, or
   both). Use `git commit -m "query: <short question>"` and push. If you
   only read, no commit.

### lint

A periodic health check. Run when the user says "lint the wiki" or after
a batch of ingests.

Checks to perform, in order, reporting findings **before** mutating:

1. **Index drift.**
   - Files listed in `index.md` whose targets don't exist.
   - Files under `pages/` `people/` `concepts/` missing from `index.md`.
2. **Broken relative links.** For every wiki page, parse markdown links
   and check each relative path resolves on disk.
3. **Stale updated dates.** Pages whose `updated:` is older than the
   newest `captured:` among their listed `sources:`.
4. **Orphans.** Pages that are not linked from `index.md` **and** not
   linked from any other wiki page (except source files).
5. **Missing cross-refs.** Run `qmd query "<entity>"` for each
   `people/` and `concepts/` page title; if another page mentions the
   entity in prose but doesn't link to its page, flag it.
6. **Contradictions.** For each concept page, `qmd query` it and scan
   the top hits for statements that contradict the concept page's claims.
   This is heuristic — report with moderate confidence and let the user
   decide.

Report all findings as a concise bulleted list grouped by check. Ask the
user which to fix. Then apply fixes, commit as `lint: <summary>`, append
to `log.md`:

```
## [YYYY-MM-DD] lint | <summary>
<checks run; issues found; fixes applied; files touched.>
```

Push and `qmd embed`.

## Failure modes and recovery

- **Dirty working tree at start of `ingest`** — stop and ask the user to
  commit/stash. Do not auto-stash.
- **`qmd` returns empty or errors** — fall back to reading `index.md` and
  `log.md`, plus your own Grep over the wiki dir. Tell the user qmd failed
  and suggest `qmd embed`.
- **Push rejected** — `git pull --rebase` then retry. Do not force-push.
- **Missing `CLAUDE.md` in `$WIKI_DIR`** — wrong directory, or setup never
  ran. Stop and instruct the user.
- **`gh` not authenticated** — tell the user to run `gh auth login`. Do not
  attempt to proceed with HTTPS tokens or SSH fallbacks.
- **A page's frontmatter is malformed** — fix it (this is a lint finding),
  but do not silently rewrite prose while you are at it.

## Design notes

- **Sources are immutable.** Only `sources/<slug>.md` files are raw
  capture. Wiki pages are the synthesis layer and may be rewritten freely.
- **Log prefixes matter.** The `## [YYYY-MM-DD] <op> | <title>` format is
  designed for grep queries like `grep 'ingest |' log.md`.
- **Compound, don't re-synthesize.** When a `query` produces a novel
  answer, filing it as a wiki page turns one question into permanent
  knowledge. This is the whole point of the pattern.
- **10–15 files per ingest** is a rough signal of a healthy ingest. Too
  few means you skipped cross-linking; too many means you're overreaching.

## Command reference

Resolve the wiki directory at the start of every operation:

```sh
WIKI_DIR="${WIKI_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
```

GitHub / git:

```sh
gh auth status                                    # confirm auth
gh repo view                                      # see the wiki repo
git -C "$WIKI_DIR" status
git -C "$WIKI_DIR" log --oneline -20
git -C "$WIKI_DIR" add -A
git -C "$WIKI_DIR" commit -m "<op>: <title>"
git -C "$WIKI_DIR" pull --rebase
git -C "$WIKI_DIR" push
```

qmd:

```sh
qmd collection list
qmd search  "keyword"          # BM25 only, fast
qmd vsearch "phrase"            # vector only
qmd query   "full question"     # hybrid + LLM rerank (best quality)
qmd get     "pages/foo.md"
qmd embed                       # re-embed after edits (fast, incremental)
```

[gist]: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
