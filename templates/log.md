# Log

Chronological, append-only record of operations on this wiki. Every entry
starts with a level-2 heading of the form:

    ## [YYYY-MM-DD] <op> | <title>

where `<op>` is one of `setup`, `ingest`, `query`, `lint`, `refactor`.
See `CLAUDE.md` for details.

## [{{DATE}}] setup | wiki initialized
Created by `git-wiki` setup.sh. Scaffolded `index.md`, `log.md`,
`CLAUDE.md`, and the `pages/` `people/` `concepts/` `sources/` directories.
