#!/usr/bin/env bash
# install.sh — one-shot bootstrap for the git-wiki skill.
#
# Creates a GitHub repo for your personal wiki, clones it locally,
# installs the git-wiki skill into the clone, runs the bundled
# scaffolder, and pushes the initial commit.
#
# Usage:
#
#   bash <(curl -sL https://raw.githubusercontent.com/rarce/git-wiki/main/install.sh)
#
# Non-interactive (environment-variable overrides):
#
#   WIKI_REPO=my-wiki WIKI_VIS=private WIKI_DIR=~/wiki \
#     bash <(curl -sL https://raw.githubusercontent.com/rarce/git-wiki/main/install.sh)
#
# Paranoid option — inspect before running:
#
#   curl -sL https://raw.githubusercontent.com/rarce/git-wiki/main/install.sh -o install.sh
#   less install.sh
#   bash install.sh

set -euo pipefail

SKILL_REPO="rarce/git-wiki"

# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m xx\033[0m %s\n' "$*" >&2; exit 1; }

require() {
  command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1 — $2"
}

# Read a value from the user, honouring any pre-set environment variable.
# Usage: prompt VAR "label" "default"
# Reads from /dev/tty so the script still works under `bash <(curl ...)`.
prompt() {
  local __var=$1 __label=$2 __default=${3-}
  local __cur=${!__var-}
  if [[ -n $__cur ]]; then return 0; fi
  local __reply
  if [[ -n $__default ]]; then
    read -r -p "$__label [$__default]: " __reply </dev/tty || true
    __reply="${__reply:-$__default}"
  else
    read -r -p "$__label: " __reply </dev/tty || true
  fi
  printf -v "$__var" '%s' "$__reply"
}

# --------------------------------------------------------------------------
# dependency checks
# --------------------------------------------------------------------------
say "git-wiki one-shot installer"
say "checking dependencies"
require gh   "install from https://cli.github.com"
require git  "install git"
require node "install node (e.g. brew install node)"
require npm  "install npm (comes with node)"

if ! gh auth status >/dev/null 2>&1; then
  die "gh is not authenticated — run: gh auth login"
fi

if ! git config --get user.email >/dev/null 2>&1; then
  die "git user.email is not set — run: git config --global user.email you@example.com"
fi

GH_USER="$(gh api user --jq .login)"

# --------------------------------------------------------------------------
# prompts (env vars override)
# --------------------------------------------------------------------------
prompt WIKI_REPO "wiki repo name"                 "wiki"
prompt WIKI_VIS  "visibility (private/public)"    "private"
prompt WIKI_DIR  "local clone path"               "$HOME/$WIKI_REPO"

case "$WIKI_VIS" in
  private|public) ;;
  *) die "visibility must be 'private' or 'public' (got: $WIKI_VIS)" ;;
esac

# expand a leading ~ in WIKI_DIR
WIKI_DIR="${WIKI_DIR/#~/$HOME}"

say "GitHub:      $GH_USER/$WIKI_REPO ($WIKI_VIS)"
say "Local dir:   $WIKI_DIR"

# --------------------------------------------------------------------------
# create the wiki repo (skip if it already exists)
# --------------------------------------------------------------------------
if gh repo view "$GH_USER/$WIKI_REPO" >/dev/null 2>&1; then
  warn "repo $GH_USER/$WIKI_REPO already exists — reusing it"
else
  say "creating GitHub repo $GH_USER/$WIKI_REPO"
  gh repo create "$GH_USER/$WIKI_REPO" "--$WIKI_VIS" \
    --description "Personal LLM-maintained wiki (Karpathy pattern)" \
    >/dev/null
fi

# --------------------------------------------------------------------------
# clone (skip if already cloned)
# --------------------------------------------------------------------------
if [[ -d "$WIKI_DIR/.git" ]]; then
  warn "$WIKI_DIR already has a git repo — skipping clone"
else
  [[ -e "$WIKI_DIR" ]] && die "$WIKI_DIR exists and is not a git repo — move it aside"
  say "cloning into $WIKI_DIR"
  mkdir -p "$(dirname "$WIKI_DIR")"
  gh repo clone "$GH_USER/$WIKI_REPO" "$WIKI_DIR"
fi

cd "$WIKI_DIR"

# --------------------------------------------------------------------------
# install the skill into the wiki repo
# --------------------------------------------------------------------------
SCAFFOLDER=".agents/skills/git-wiki/scripts/setup.sh"

if [[ -f $SCAFFOLDER ]]; then
  warn "$SKILL_REPO already installed at .agents/skills/git-wiki/ — skipping"
else
  say "installing skill: npx -y skills add $SKILL_REPO"
  npx -y skills add "$SKILL_REPO" \
    || die "npx skills add failed — try manually: npx -y skills add $SKILL_REPO"
fi

[[ -f $SCAFFOLDER ]] \
  || die "scaffolder not found at $SCAFFOLDER after install — expected it at .agents/skills/git-wiki/scripts/setup.sh. Check where 'npx skills add' placed the skill."

# --------------------------------------------------------------------------
# run the bundled scaffolder
# --------------------------------------------------------------------------
say "running the bundled scaffolder"
WIKI_NAME="$WIKI_REPO" bash "$SCAFFOLDER"

# --------------------------------------------------------------------------
# done
# --------------------------------------------------------------------------
cat <<EOF

$(say "all done")

  wiki repo:   https://github.com/$GH_USER/$WIKI_REPO
  local dir:   $WIKI_DIR

  cd $WIKI_DIR

Then launch your agent (Claude Code, Cursor, Copilot, …) and try:

  "ingest this article: <url>"
  "what do I know about <topic>?"
  "lint the wiki"

EOF
