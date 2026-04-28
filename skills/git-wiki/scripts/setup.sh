#!/usr/bin/env bash
# setup.sh — scaffold the Karpathy LLM-wiki layout into the current repo
# and register it with qmd for on-device hybrid search.
#
# Run this from inside an existing git repo for your wiki. This script
# does NOT create the repo or clone it — it assumes that has already
# happened (by install.sh, by `gh repo create --clone`, by `git init`, or
# by hand). See the repo README for the full install flow.
#
# Usage:
#   .agents/skills/git-wiki/scripts/setup.sh
#
# Optional override:
#   WIKI_NAME=mywiki .agents/skills/git-wiki/scripts/setup.sh
#     # (defaults to the basename of the git toplevel)

set -euo pipefail

# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m xx\033[0m %s\n' "$*" >&2; exit 1; }

require() {
  command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1 — $2"
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$SKILL_DIR/assets/wiki-scaffold"
[[ -d $TEMPLATE_DIR ]] || die "wiki-scaffold assets not found: $TEMPLATE_DIR"

# --------------------------------------------------------------------------
# resolve wiki directory — must already be a git repo
# --------------------------------------------------------------------------
WIKI_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z $WIKI_DIR ]]; then
  die "not inside a git repo — create one first, e.g.:
    gh repo create my-wiki --private --clone
    cd my-wiki
    npx -y skills add rarce/git-wiki
    .agents/skills/git-wiki/scripts/setup.sh

  Or use the one-shot installer:
    bash <(curl -sL https://raw.githubusercontent.com/rarce/git-wiki/main/install.sh)"
fi

# --------------------------------------------------------------------------
# dependency checks
# --------------------------------------------------------------------------
say "checking dependencies"
require git  "install git"
require node "install node (e.g. brew install node)"
require npm  "install npm (comes with node)"

if ! git config --get user.email >/dev/null 2>&1; then
  warn "git user.email is not set — the initial commit will fail."
  warn "run: git config --global user.email you@example.com"
fi

if ! command -v qmd >/dev/null 2>&1; then
  say "qmd not found — installing @tobilu/qmd globally via npm"
  npm install -g @tobilu/qmd \
    || die "npm install failed — try manually: npm i -g @tobilu/qmd"
fi

# gh is used by remote-backed wiki workflows, not by local-only setup.
if [[ ${GIT_WIKI_LOCAL:-0} != 1 ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    warn "gh CLI not found — install from https://cli.github.com so the skill can use it later"
  elif ! gh auth status >/dev/null 2>&1; then
    warn "gh is installed but not authenticated — run: gh auth login"
  fi
fi

# --------------------------------------------------------------------------
# collection name
# --------------------------------------------------------------------------
WIKI_NAME="${WIKI_NAME:-$(basename "$WIKI_DIR")}"

say "wiki dir:    $WIKI_DIR"
say "collection:  $WIKI_NAME"

cd "$WIKI_DIR"

# --------------------------------------------------------------------------
# scaffold from templates
# --------------------------------------------------------------------------
say "scaffolding wiki layout from templates"

mkdir -p pages people concepts sources

TODAY="$(date +%Y-%m-%d)"

copy_tpl() {
  # copy_tpl <src-in-templates> <dst-in-wiki>
  local src="$TEMPLATE_DIR/$1" dst="$2"
  if [[ -e $dst ]]; then
    warn "$dst already exists — leaving as-is"
    return 0
  fi
  sed \
    -e "s|{{DATE}}|$TODAY|g" \
    -e "s|{{REPO}}|$WIKI_NAME|g" \
    "$src" > "$dst"
}

copy_tpl CLAUDE.md       CLAUDE.md
copy_tpl index.md        index.md
copy_tpl log.md          log.md
copy_tpl README.md       README.md
copy_tpl gitattributes   .gitattributes

for d in pages people concepts sources; do
  [[ -f "$d/.gitkeep" ]] || : > "$d/.gitkeep"
done

# --------------------------------------------------------------------------
# qmd: register collection and embed
# --------------------------------------------------------------------------
say "registering qmd collection '$WIKI_NAME'"
if qmd collection list 2>/dev/null | grep -qw "$WIKI_NAME"; then
  warn "qmd collection '$WIKI_NAME' already exists — skipping"
else
  qmd collection add "$WIKI_DIR" --name "$WIKI_NAME" \
    || warn "qmd collection add failed — run it later"
  qmd context add "qmd://$WIKI_NAME" "Personal LLM wiki (Karpathy pattern)" \
    || true
fi

say "generating embeddings (first run downloads a model; may take a minute)"
qmd embed || warn "qmd embed failed — run it manually later"

# --------------------------------------------------------------------------
# commit + push (only if there are changes and origin is set)
# --------------------------------------------------------------------------
if [[ -n "$(git status --porcelain)" ]]; then
  say "creating commit"
  git add -A
  if git commit -m "chore: scaffold wiki layout via git-wiki setup"; then
    # Normalize branch name to main for fresh repos.
    git branch -M main 2>/dev/null || true
    if git remote get-url origin >/dev/null 2>&1; then
      say "pushing to origin/main"
      git push -u origin main || warn "push failed — push manually later"
    else
      warn "no 'origin' remote set — skipping push"
    fi
  else
    warn "commit failed — check git user.name/user.email"
  fi
else
  warn "nothing to commit (wiki was already scaffolded)"
fi

# --------------------------------------------------------------------------
# done
# --------------------------------------------------------------------------
cat <<EOF

$(say "done")

  wiki dir:    $WIKI_DIR
  collection:  $WIKI_NAME

Next steps:
  1. Launch your agent (Claude Code, Cursor, Copilot, …) from $WIKI_DIR.
     It should discover the git-wiki skill at .agents/skills/git-wiki/.
  2. Try:
       "ingest this article: <url>"
       "what do I know about <topic>?"
       "lint the wiki"

EOF
