# Claude Code skills: `/ship` + `/preflight`

Two [Claude Code](https://claude.com/claude-code) skills for a commit → review → PR workflow.

| Skill | What it does |
|---|---|
| `/preflight [--fix]` | Quality gate for every changed file (vs the base branch, incl. uncommitted/untracked): runs the built-in `/code-review` and `/security-review`, then team checks — repo standards + lint/typecheck, stack-specific security (PHP / Next.js), shared logic → common dirs, design patterns. Writes PASS/FAIL to `.git/preflight.json`. |
| `/ship [PR title]` | Pre-checks → `/preflight` (must PASS) → `feature/...` branch → `git add -A` → commit → `git fetch` → `git rebase origin/<base>` (stops on conflict) → `git push -f` → creates a ready-to-merge PR/MR with a full description. Prints a step-by-step progress log. |

## Install into a project

Run from inside the project's git repo (Git Bash on Windows):

```bash
curl -fsSL https://raw.githubusercontent.com/phong-17/ai-kit/main/install.sh | bash
```

The installer:
1. Copies the skills into `<repo>/.claude/skills/`.
2. Creates `ai-kit.config.json` (if missing).
3. Creates the token file `.claude/settings.json` with a placeholder (or `.claude/settings.local.json` if `settings.json` is already shared in git), and adds it to `.gitignore`.
4. Warns if `gh` / `glab` is not installed.

Re-run the same command to update the skills (your config and token file are kept).

Install for all projects on this machine instead: `... | bash -s -- --global`

## Setup per project

1. **Token** — paste it into the token file the installer created. Only keep the keys you use (no empty values):
   ```json
   { "env": { "GH_TOKEN": "github_pat_..." } }
   ```
   GitLab: `{ "env": { "GITLAB_TOKEN": "glpat-...", "GITLAB_HOST": "gitlab.example.com" } }` (omit `GITLAB_HOST` for gitlab.com).
   GitHub fine-grained token permissions: **Pull requests: Read & write**, **Contents: Read**.
2. **CLI** — `winget install GitHub.cli` (or `winget install GLab.GLab`).
3. **Config** — edit `ai-kit.config.json`:
   ```json
   { "baseBranch": "dev", "commonDirs": ["src/common", "src/utils", "src/components/common"] }
   ```
4. Restart Claude Code.

> The token file must never be committed. `/ship` refuses to run if it is not in `.gitignore` or is already tracked.

## Layout

```
skills/
  ship/SKILL.md
  preflight/SKILL.md
  preflight/references/{standards,security,reuse,patterns}.md
templates/ai-kit.config.json
install.sh
```
