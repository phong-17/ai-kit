#!/usr/bin/env bash
# Install the /ship and /preflight Claude Code skills into the current project.
#
# Usage (run from inside the project's git repo, in Git Bash / macOS / Linux):
#   curl -fsSL https://raw.githubusercontent.com/phong-17/ai-kit/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/phong-17/ai-kit/main/install.sh | bash -s -- --global
#
# Options:
#   --global   install into ~/.claude/skills (all projects) instead of <repo>/.claude/skills
#   --ref X    install from branch/tag X (default: main)
set -euo pipefail

REPO_URL="${AI_KIT_REPO:-https://github.com/phong-17/ai-kit.git}"
REF="main"
GLOBAL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --global) GLOBAL=1 ;;
    --ref) REF="$2"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

say()  { printf '\033[1;34m▶\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✔\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*"; }

# --- 1. Download -------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
say "Downloading skills from $REPO_URL ($REF)"
git clone --quiet --depth 1 --branch "$REF" "$REPO_URL" "$TMP/kit"
ok "Downloaded"

# --- 2. Global install -------------------------------------------------------
if [ "$GLOBAL" = 1 ]; then
  DEST="$HOME/.claude/skills"
  mkdir -p "$DEST"
  for s in "$TMP"/kit/skills/*/; do
    name="$(basename "$s")"
    rm -rf "${DEST:?}/$name"
    cp -R "$s" "$DEST/$name"
    ok "Installed /$name → $DEST/$name"
  done
  echo
  ok "Done. Restart Claude Code to load the skills."
  exit 0
fi

# --- 3. Project install ------------------------------------------------------
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Not inside a git repository. cd into your project first (or use --global)." >&2; exit 1; }
cd "$ROOT"
say "Installing into project: $ROOT"

mkdir -p .claude/skills
for s in "$TMP"/kit/skills/*/; do
  name="$(basename "$s")"
  rm -rf ".claude/skills/$name"
  cp -R "$s" ".claude/skills/$name"
  ok "Installed /$name → .claude/skills/$name"
done

# ai-kit.config.json (never overwrite an existing one)
if [ -f ai-kit.config.json ]; then
  ok "ai-kit.config.json already exists — kept"
else
  cp "$TMP/kit/templates/ai-kit.config.json" ai-kit.config.json
  ok "Created ai-kit.config.json (edit baseBranch / commonDirs)"
fi

# Token file: .claude/settings.json, unless the team already commits that file
TOKEN_FILE=".claude/settings.json"
if git ls-files --error-unmatch "$TOKEN_FILE" >/dev/null 2>&1; then
  warn "$TOKEN_FILE is tracked by git (shared with the team) → using .claude/settings.local.json for the token"
  TOKEN_FILE=".claude/settings.local.json"
fi

# .gitignore entries
touch .gitignore
[ -s .gitignore ] && [ -n "$(tail -c1 .gitignore)" ] && echo >> .gitignore
for entry in ".claude/settings.local.json" "$TOKEN_FILE"; do
  if ! grep -qxF "$entry" .gitignore; then
    printf '%s\n' "$entry" >> .gitignore
    ok "Added $entry to .gitignore"
  fi
done

# Token placeholder (GitHub or GitLab, based on the remote)
REMOTE="$(git remote get-url origin 2>/dev/null || true)"
if [ -f "$TOKEN_FILE" ]; then
  ok "$TOKEN_FILE already exists — kept (make sure it has the token)"
else
  case "$REMOTE" in
    *gitlab*) printf '{\n  "env": {\n    "GITLAB_TOKEN": "PASTE_YOUR_TOKEN_HERE"\n  }\n}\n' > "$TOKEN_FILE" ;;
    *)        printf '{\n  "env": {\n    "GH_TOKEN": "PASTE_YOUR_TOKEN_HERE"\n  }\n}\n' > "$TOKEN_FILE" ;;
  esac
  ok "Created $TOKEN_FILE with a token placeholder"
fi

# CLI check
case "$REMOTE" in
  *gitlab*) command -v glab >/dev/null || warn "glab not found → install: winget install GLab.GLab" ;;
  *)        command -v gh   >/dev/null || warn "gh not found → install: winget install GitHub.cli" ;;
esac

echo
ok "Done. Next steps:"
echo "  1. Paste your token into $TOKEN_FILE"
echo "  2. Review ai-kit.config.json"
echo "  3. Commit .claude/skills, ai-kit.config.json and .gitignore (the token file stays ignored)"
echo "  4. Restart Claude Code, then use /preflight and /ship"
