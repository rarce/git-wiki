#!/usr/bin/env bash
# setup.sh — bootstrap a personal git-wiki on GitHub.
#
# Creates (or reuses) a personal GitHub repo, clones it locally, scaffolds
# the Karpathy LLM-wiki layout from ./templates, registers the wiki as a
# qmd collection, makes an initial commit, and pushes.
#
# Usage: ./setup.sh          (interactive prompts)
#        REPO=my-wiki VIS=private LOCAL_DIR=~/wiki ./setup.sh  (non-interactive)

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

prompt() {
  # prompt VAR "label" "default"
  local __var=$1 __label=$2 __default=${3-}
  local __cur=${!__var-}
  if [[ -n $__cur ]]; then return 0; fi  # already set via env
  local __reply
  if [[ -n $__default ]]; then
    read -r -p "$__label [$__default]: " __reply || true
    __reply="${__reply:-$__default}"
  else
    read -r -p "$__label: " __reply || true
  fi
  printf -v "$__var" '%s' "$__reply"
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$SKILL_DIR/assets/wiki-scaffold"
[[ -d $TEMPLATE_DIR ]] || die "wiki-scaffold assets not found: $TEMPLATE_DIR"

# --------------------------------------------------------------------------
# dependency checks
# --------------------------------------------------------------------------
say "checking dependencies"
require gh   "install from https://cli.github.com"
require git  "install git"
require node "install node (e.g. brew install node)"
require npm  "install npm (comes with node)"

if ! gh auth status >/dev/null 2>&1; then
  die "gh is not authenticated — run: gh auth login"
fi

if ! git config --get user.email >/dev/null 2>&1; then
  warn "git user.email is not set — the initial commit will fail."
  warn "run: git config --global user.email you@example.com"
fi

if ! command -v qmd >/dev/null 2>&1; then
  say "qmd not found — installing @tobilu/qmd globally via npm"
  npm install -g @tobilu/qmd \
    || die "npm install failed — try manually: npm i -g @tobilu/qmd"
fi

GH_USER="$(gh api user --jq .login)"
say "GitHub user: $GH_USER"

# --------------------------------------------------------------------------
# prompts (env vars override)
# --------------------------------------------------------------------------
prompt REPO       "wiki repo name"            "wiki"
prompt VIS        "visibility (private/public)" "private"
prompt LOCAL_DIR  "local clone path"          "$HOME/$REPO"

case "$VIS" in
  private|public) ;;
  *) die "visibility must be 'private' or 'public' (got: $VIS)" ;;
esac

# expand ~ in LOCAL_DIR
LOCAL_DIR="${LOCAL_DIR/#~/$HOME}"

say "repo:       $GH_USER/$REPO ($VIS)"
say "local dir:  $LOCAL_DIR"

# --------------------------------------------------------------------------
# create GitHub repo (skip if exists)
# --------------------------------------------------------------------------
if gh repo view "$GH_USER/$REPO" >/dev/null 2>&1; then
  warn "repo $GH_USER/$REPO already exists — skipping create"
else
  say "creating GitHub repo $GH_USER/$REPO"
  gh repo create "$GH_USER/$REPO" "--$VIS" \
    --description "Personal LLM-maintained wiki (Karpathy pattern)" \
    >/dev/null
fi

# --------------------------------------------------------------------------
# clone
# --------------------------------------------------------------------------
if [[ -d "$LOCAL_DIR/.git" ]]; then
  warn "$LOCAL_DIR already has a git repo — skipping clone"
else
  if [[ -e "$LOCAL_DIR" ]]; then
    die "$LOCAL_DIR exists and is not a git repo — move it aside"
  fi
  say "cloning into $LOCAL_DIR"
  gh repo clone "$GH_USER/$REPO" "$LOCAL_DIR"
fi

cd "$LOCAL_DIR"

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
  # Substitute {{DATE}} and {{REPO}} in-flight.
  sed \
    -e "s|{{DATE}}|$TODAY|g" \
    -e "s|{{REPO}}|$REPO|g" \
    "$src" > "$dst"
}

copy_tpl CLAUDE.md       CLAUDE.md
copy_tpl index.md        index.md
copy_tpl log.md          log.md
copy_tpl README.md       README.md
copy_tpl gitattributes   .gitattributes

# keep empty scaffold dirs visible to git
for d in pages people concepts sources; do
  [[ -f "$d/.gitkeep" ]] || : > "$d/.gitkeep"
done

# --------------------------------------------------------------------------
# qmd: register collection and embed
# --------------------------------------------------------------------------
say "registering qmd collection '$REPO'"
if qmd collection list 2>/dev/null | grep -qw "$REPO"; then
  warn "qmd collection '$REPO' already exists — skipping"
else
  qmd collection add "$LOCAL_DIR" --name "$REPO" \
    || warn "qmd collection add failed — you can run it later"
  qmd context add "qmd://$REPO" "Personal LLM wiki (Karpathy pattern)" \
    || true
fi

say "generating embeddings (first run downloads a model; may take a minute)"
qmd embed || warn "qmd embed failed — run it manually later"

# --------------------------------------------------------------------------
# initial commit + push
# --------------------------------------------------------------------------
if [[ -n "$(git status --porcelain)" ]]; then
  say "creating initial commit"
  git add -A
  if git commit -m "chore: scaffold wiki layout"; then
    # Normalize the branch name so a fresh empty repo lands on `main`
    # regardless of the local init.defaultBranch setting.
    git branch -M main
    say "pushing to origin/main"
    git push -u origin main || warn "push failed — push manually later"
  else
    warn "initial commit failed — check git user.name/user.email"
  fi
else
  warn "nothing to commit (wiki was already scaffolded)"
fi

# --------------------------------------------------------------------------
# done
# --------------------------------------------------------------------------
cat <<EOF

$(say "done")

  wiki repo:  https://github.com/$GH_USER/$REPO
  local dir:  $LOCAL_DIR

Next steps:
  1. cd $LOCAL_DIR
  2. Launch your agent (Claude Code, Cursor, Copilot, …) from $LOCAL_DIR.
     If you installed this skill via "npx skills add rarce/git-wiki", the
     agent already discovers it. Otherwise see the repo README for manual
     install options.
  3. Try:
       "ingest this article: <url>"
       "what do I know about <topic>?"
       "lint the wiki"

EOF
