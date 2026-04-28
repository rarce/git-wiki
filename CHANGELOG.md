# Changelog

All notable changes to this project are documented here.

## Unreleased

## 0.1.0 - 2026-04-28

### Added

- Added `WIKI_VIS=local` support for creating a local-only wiki repo without publishing to GitHub.
- Added `AGENTS.md` with repository contribution guidelines.
- Added explicit trust-boundary guidance for ingested sources in the skill instructions.

### Changed

- Moved GitHub publishing from a hard requirement to an optional remote-backed workflow.
- Updated README install docs to cover local-only and GitHub-backed setup paths.
- Changed `setup.sh` to require `qmd` instead of installing it globally.

### Security

- Removed remote installer, transitive skill-install, and npm package-install instructions from the packaged skill.
- Documented that ingested external content must be treated as untrusted data and cannot override agent instructions.
