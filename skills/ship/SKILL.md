---
name: ship
description: Commit all changes, rebase onto the base branch (default dev), force push to a feature/... branch, and create (or update) a GitHub Pull Request / GitLab Merge Request with a full description of the task changes, ready for the user to click Merge. Runs /preflight first and stops if it fails. Stops immediately if the rebase hits a conflict.
argument-hint: "[PR title - leave empty to auto-generate]"
disable-model-invocation: true
allowed-tools: Bash(git *), Bash(gh *), Bash(glab *), Read, Grep, Glob, Skill
---

# /ship — commit, rebase, push and open a PR

PR title provided by the user: `$ARGUMENTS`
- If set → use it **verbatim** as the PR title.
- If empty → write a concise title (≤ 72 chars) based on the changes.

Base branch: read `ai-kit.config.json` at the repo root if it exists and use its `baseBranch` (same file `/preflight` reads); default **`dev`**. Below, `<baseBranch>` is that name and `<base>` is `origin/<baseBranch>`.

Language: write everything (commit messages, branch names, PR title, PR description, PR comments, progress log, final report) in **English**.

Run the steps below in order. If any step fails, **stop and report** — never "fix" things with destructive commands (`reset --hard`, `rebase --abort`, `checkout -- .`, deleting files, ...).

## Progress log (mandatory)

The user wants to follow along in the terminal. Command output is not reliably shown to the user, so **you must print the progress yourself as normal text**:

- **Before** each step, print one line: `▶ [n/9] <Step name>`.
- **Before** each git / gh / glab command, print the exact command in a code span, e.g. `` $ git add -A ``. Give every Bash call a clear `description` too.
- **After** each command, print one short result line: `✔ <result>` (e.g. `✔ 10 files staged`, `✔ commit a1b2c3d`, `✔ rebased onto origin/dev (3 new commits)`), or `✖ <error>` and stop.
- Never print token values or the contents of `.claude/settings.json` / `.claude/settings.local.json`.

Example:
```
▶ [5/9] Add & commit
$ git status --short
✔ 10 changed files (8 modified, 2 new)
$ git add -A
✔ staged
$ git commit -m "feat: add OTP login"
✔ commit a1b2c3d
```

## Step 1 — Pre-checks (always first, also when resuming after a conflict)

1. Run in parallel:
   - `git rev-parse --show-toplevel` → the **repo root**. Run every later git command from the repo root (use `git -C <repo root> ...` or `cd` there first).
   - `git branch --show-current`
   - `git status --porcelain`
   - `git remote get-url origin`
   - `git log --oneline -10` (to learn the repo's commit style)
2. Detect the platform from the remote URL: contains `github` → `gh` CLI; contains `gitlab` → `glab` CLI.
3. **Creating the PR is mandatory** — the goal is a PR the user only has to click Merge on. Verify before doing anything else:
   - Installed? (`gh --version` / `glab --version`). If not → tell the user to install it (`winget install GitHub.cli` / `winget install GLab.GLab`) and **stop**.
   - Token available? Authentication is **token-based, per project, never an interactive login**. `gh` reads `GH_TOKEN`; `glab` reads `GITLAB_TOKEN` (+ `GITLAB_HOST` for self-hosted GitLab). They live in the `env` block of the project's **`.claude/settings.json`** (or `.claude/settings.local.json`) — Claude Code loads these for this project only. Check with `gh auth status` / `glab auth status`.
     If it fails → **stop** and tell the user to add the token to `<repo root>/.claude/settings.json` with only the keys they need (no empty values), then restart Claude Code:
     ```json
     { "env": { "GH_TOKEN": "github_pat_..." } }
     ```
     (GitLab: `{ "env": { "GITLAB_TOKEN": "glpat-...", "GITLAB_HOST": "gitlab.example.com" } }` — omit `GITLAB_HOST` for gitlab.com.)
     Never suggest `gh auth login` / `glab auth login`.
   - **The token file must never be committed.** Find which of `.claude/settings.json` / `.claude/settings.local.json` contains a token key with `grep -lE '"(GH_TOKEN|GITLAB_TOKEN)"' <file>` (`-l` only — never print the values). For each such file:
     - `git check-ignore -q <file>` fails (not ignored) → **stop** and tell the user to add that file to `.gitignore` first (offer to add it).
     - `git ls-files <file>` shows it is already tracked → **stop** and warn that the token is in git history: revoke the token and remove the file from the index (`git rm --cached <file>`).
   - Do not commit, rebase or push until all of this passes.

## Step 2 — Resume an interrupted rebase (only if one is in progress)

If `.git/rebase-merge` or `.git/rebase-apply` exists (check with `git rev-parse --git-path rebase-merge` / `rebase-apply`):
- Conflicted files still present (`UU`, `AA`, `DU`, `UD`, ... in `git status`) → list them, tell the user to resolve them, `git add <file>`, `git rebase --continue`, then run `/ship` again. **Stop.**
- No conflicts left → run `GIT_EDITOR=true git rebase --continue`, then run **Step 4 (quality gate)** — conflict resolutions must be checked too — then jump to **Step 7 (push)**.

Otherwise print `✔ no rebase in progress` and continue.

## Step 3 — Understand the changes

- Run `git diff`, `git diff --staged`, and check untracked files from `git status`.
- Read related files if needed to understand the **purpose** of the change (which bug is fixed, which feature is added).
- Warn (and ask the user before continuing) if sensitive or unwanted files are about to be added: `.env`, files containing keys/tokens/passwords, large build artifacts/binaries, `node_modules`, `vendor`, ...
- If there are no changes and the current branch has no new commits compared to `<base>` → report "nothing to ship" and **stop**.

## Step 4 — Quality gate (/preflight) — MANDATORY

`/ship` must never commit or push code that has not passed `/preflight`. There is no flag to skip this.

1. Compute the fingerprint of the current state (same command as `/preflight`):
   ```bash
   BASE=$(git merge-base <base> HEAD 2>/dev/null || git rev-parse HEAD)
   FP=$({ git diff "$BASE" --binary; git ls-files --others --exclude-standard; git ls-files --others --exclude-standard -z | xargs -0 -r git hash-object --; } | git hash-object --stdin)
   echo "$FP"
   ```
2. Read the result file at `git rev-parse --git-path preflight.json`.
3. File exists, `status` is `PASS`, **and** `fingerprint` equals `FP` → print `✔ preflight PASS (cached)` and continue.
4. Otherwise (missing file, `FAIL`, or code changed since the last check) → print `$ /preflight`, run the `preflight` skill with the Skill tool (no `--fix`), then read the result file again:
   - `PASS` → print `✔ preflight PASS` and continue.
   - `FAIL` → print `✖ preflight FAIL` and **STOP. Do not commit, rebase, or push.** Show the Blocker and Should-fix items and tell the user to fix them (or run `/preflight --fix`), then run `/ship` again.
5. Do not modify any source files during the gate.

## Step 5 — Branch, add & commit

Branch:
- Current branch **already** matches `feature/<name>` → keep it.
- Current branch is `dev`, `main`, `master`, `develop`, `staging`, `production`, or anything not matching `feature/...`:
  - Generate `feature/<slug>`: lowercase, ASCII only, words joined by `-`, max ~50 chars, derived from the PR title (or the changes). If a task ID appears (e.g. `ABC-123`, `#123`), put it first: `feature/ABC-123-fix-login`.
  - `git checkout -b feature/<slug>` (carries the current changes). If the name exists → append `-2`, `-3`, ...

Add & commit (from the **repo root**, so files outside the current directory are included):

```bash
git add -A
git commit -m "<feature description>"
```

- Commit message: concise description of the feature/fix, following the style of recent commits (e.g. conventional commits `feat:`, `fix:` if the repo uses them).
- If the user provided a PR title → use it as the first line of the commit message (unless it clashes with the repo style).
- Use a heredoc for multi-line messages.
- Nothing to commit (already committed) → print `✔ nothing new to commit` and continue.
- Pre-commit hook fails → report the error and **stop**. Never use `--no-verify`.

## Step 6 — Fetch & rebase onto the base branch

```bash
git fetch origin
git rebase <base>
```

- `<base>` does not exist → tell the user and **stop** (ask which base branch to use).
- **Rebase conflict → STOP IMMEDIATELY.** Do not resolve conflicts yourself and do not run `rebase --abort`. Tell the user:
  - The conflicted files (`git diff --name-only --diff-filter=U`).
  - Next steps: resolve conflicts → `git add <file>` → `git rebase --continue` → run `/ship` again (it resumes from the push step).
  - (To cancel instead: `git rebase --abort`.)

## Step 7 — Push

```bash
git push -f -u origin <branch>
```

- **Never** force push to `<baseBranch>`, `dev`, `main`, or `master`. If the current branch is one of them → stop and report an error.
- Push rejected (protected branch, permissions, ...) → report the error and **stop**.

## Step 8 — Create or update the PR

1. Check whether an open PR already exists for the branch:
   - GitHub: `gh pr list --head <branch> --state open --json number,url,title`
   - GitLab: `glab mr list --source-branch <branch>`
2. Write a **complete PR description** from the full diff `git diff <base>...HEAD` and `git log <base>..HEAD`:

```markdown
## Summary
<What the task is: the problem / requirement and why this change is needed>

## Changes
- `<path/to/file>`: <what changed and why>
- ...

## Impact
<Affected modules / screens / APIs; DB, config, env or migration changes if any>

## How to test
- [ ] <test step 1>
- [ ] <test step 2>

## Notes
<Risks, follow-ups, hints for reviewers — omit this section if empty>
```

   If the repo has its own PR template (`.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE/*`, `.gitlab/merge_request_templates/*`) → fill that template instead.

3. **No PR yet** → create one (heredoc for the body), never as a draft, assigned to the current user:
   - GitHub:
     ```bash
     gh pr create --base <baseBranch> --head <branch> --assignee @me --title "<title>" --body "$(cat <<'EOF'
     <description>
     EOF
     )"
     ```
   - GitLab:
     ```bash
     glab mr create --target-branch <baseBranch> --source-branch <branch> --title "<title>" --description "$(cat <<'EOF'
     <description>
     EOF
     )" --yes
     ```
   - Do not add reviewers yourself; leave that to the repo's defaults (CODEOWNERS, etc.).
   - Do **not** enable auto-merge and never merge the PR yourself — the user clicks Merge.
4. **PR already exists** → do not create a new one:
   - Add a comment summarizing what changed in this ship: `gh pr comment <number> --body "..."` / `glab mr note <number> --message "..."`.
   - User provided a new title → update it (`gh pr edit <number> --title ...` / `glab mr update <number> --title ...`).
   - If it is a draft → mark it ready: `gh pr ready <number>` / `glab mr update <number> --ready`.
5. Check that it can be merged:
   - GitHub: `gh pr view <number> --json url,isDraft,mergeable,mergeStateStatus` and `gh pr checks <number>` (CI may still be running — report the current state, do not wait in a loop).
   - GitLab: `glab mr view <number>` (merge status, pipeline status).
   - Merge conflict with the base branch → tell the user to run `/ship` again (it rebases onto the latest base).

## Step 9 — Report

Short summary, with the PR link on its own line so it is easy to click:
- **PR/MR: <link>** (created or updated)
- Merge status: ready to merge / CI running / CI failed / conflict
- Branch: `feature/...`
- Commit: hash + message
- Rebase/push result
