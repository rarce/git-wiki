#!/usr/bin/env bash
# install.sh — one-shot bootstrap for the git-wiki skill.
#
# Creates a personal wiki repo, installs the git-wiki skill into it,
# runs the bundled scaffolder, and commits the initial layout. By default
# the wiki is created on GitHub and cloned locally; use WIKI_VIS=local to
# create a local-only git repo without publishing it.
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
require git  "install git"
require node "install node (e.g. brew install node)"
require npm  "install npm (comes with node)"
require qmd  "install qmd before running install.sh; see the README prerequisites"

if ! git config --get user.email >/dev/null 2>&1; then
  die "git user.email is not set — run: git config --global user.email you@example.com"
fi

# --------------------------------------------------------------------------
# prompts (env vars override)
# --------------------------------------------------------------------------
prompt WIKI_REPO "wiki repo name"                 "wiki"
prompt WIKI_VIS  "visibility (private/public/local)" "private"
prompt WIKI_DIR  "local wiki path"                "$HOME/$WIKI_REPO"

case "$WIKI_VIS" in
  private|public|local) ;;
  *) die "visibility must be 'private', 'public', or 'local' (got: $WIKI_VIS)" ;;
esac

if [[ $WIKI_VIS != local ]]; then
  require gh "install from https://cli.github.com"
  if ! gh auth status >/dev/null 2>&1; then
    die "gh is not authenticated — run: gh auth login"
  fi
  GH_USER="$(gh api user --jq .login)"
fi

# expand a leading ~ in WIKI_DIR
WIKI_DIR="${WIKI_DIR/#~/$HOME}"

if [[ $WIKI_VIS == local ]]; then
  say "Mode:        local-only git repo"
else
  say "GitHub:      $GH_USER/$WIKI_REPO ($WIKI_VIS)"
fi
say "Local dir:   $WIKI_DIR"

# --------------------------------------------------------------------------
# create the wiki repo
#
# We use `gh repo create --clone` for fresh repos so the clone happens
# atomically inside gh (via `git clone` against a known URL) rather than
# via a follow-up `gh repo clone` — the latter queries GraphQL, which is
# eventually consistent and often lags a fresh REST create by a few
# seconds. For repos that already existed, we fall back to `gh repo clone`
# with a short retry loop in case we still hit the same lag.
# --------------------------------------------------------------------------
if [[ $WIKI_VIS == local ]]; then
  if [[ -d "$WIKI_DIR/.git" ]]; then
    warn "$WIKI_DIR already has a git repo — reusing it"
  else
    [[ -e "$WIKI_DIR" ]] && die "$WIKI_DIR exists and is not a git repo — move it aside"
    say "creating local git repo at $WIKI_DIR"
    mkdir -p "$WIKI_DIR"
    (
      cd "$WIKI_DIR"
      git init -b main >/dev/null 2>&1 || {
        git init >/dev/null
        git branch -M main 2>/dev/null || true
      }
    )
  fi
else
  REPO_EXISTED=0
  if gh repo view "$GH_USER/$WIKI_REPO" >/dev/null 2>&1; then
    warn "repo $GH_USER/$WIKI_REPO already exists — reusing it"
    REPO_EXISTED=1
  fi

  if [[ -d "$WIKI_DIR/.git" ]]; then
    warn "$WIKI_DIR already has a git repo — skipping clone"
  else
    [[ -e "$WIKI_DIR" ]] && die "$WIKI_DIR exists and is not a git repo — move it aside"

    WIKI_PARENT="$(dirname "$WIKI_DIR")"
    WIKI_BASENAME="$(basename "$WIKI_DIR")"
    mkdir -p "$WIKI_PARENT"

    if [[ $REPO_EXISTED -eq 0 ]]; then
      # `gh repo create --clone` clones into ./$WIKI_REPO relative to CWD.
      # If WIKI_DIR's basename differs from the repo name, we rename after.
      if [[ "$WIKI_REPO" != "$WIKI_BASENAME" && -e "$WIKI_PARENT/$WIKI_REPO" ]]; then
        die "$WIKI_PARENT/$WIKI_REPO exists and gh would clone into it — move it aside"
      fi
      say "creating + cloning $GH_USER/$WIKI_REPO"
      (
        cd "$WIKI_PARENT"
        gh repo create "$GH_USER/$WIKI_REPO" "--$WIKI_VIS" \
          --description "Personal LLM-maintained wiki (Karpathy pattern)" \
          --clone >/dev/null
        if [[ "$WIKI_REPO" != "$WIKI_BASENAME" ]]; then
          mv "$WIKI_REPO" "$WIKI_BASENAME"
        fi
      )
    else
      say "cloning existing $GH_USER/$WIKI_REPO into $WIKI_DIR"
      # Retry on the same eventual-consistency lag in case the existing
      # repo was created moments ago (e.g. a previous install.sh run failed
      # right after `gh repo create`).
      n=0
      until gh repo clone "$GH_USER/$WIKI_REPO" "$WIKI_DIR" 2>/dev/null; do
        n=$((n+1))
        if [[ $n -ge 5 ]]; then
          die "gh repo clone failed after 5 attempts — try: gh repo clone $GH_USER/$WIKI_REPO $WIKI_DIR"
        fi
        warn "clone attempt $n/5 failed, retrying in 2s…"
        sleep 2
      done
    fi
  fi
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
GIT_WIKI_LOCAL="$([[ $WIKI_VIS == local ]] && printf 1 || printf 0)" \
  WIKI_NAME="$WIKI_REPO" bash "$SCAFFOLDER"

# --------------------------------------------------------------------------
# done
# --------------------------------------------------------------------------
cat <<EOF

$(say "all done")

  local dir:   $WIKI_DIR
EOF

if [[ $WIKI_VIS == local ]]; then
  cat <<EOF
  mode:        local-only
EOF
else
  cat <<EOF
  wiki repo:   https://github.com/$GH_USER/$WIKI_REPO
EOF
fi

cat <<EOF

  cd $WIKI_DIR

Then launch your agent (Claude Code, Cursor, Copilot, …) and try:

  "ingest this article: <url>"
  "what do I know about <topic>?"
  "lint the wiki"

EOF
