---
name: preflight
description: Pre-ship quality gate for every file changed on the current branch (vs the base branch, including uncommitted and untracked files). Runs the built-in /code-review and /security-review first, then the team checks (repo standards + lint/typecheck, stack-specific security, shared logic → common dirs, design patterns). Writes a PASS/FAIL result that /ship requires before it will run. Use when the user asks to check/verify/review their changes before pushing or shipping. Pass --fix to apply fixes automatically.
argument-hint: "[--fix]"
allowed-tools: Bash(git *), Bash(npx *), Bash(npm *), Bash(pnpm *), Bash(yarn *), Bash(composer *), Bash(php *), Read, Grep, Glob, Edit, Write, Skill, Agent
---

# /preflight — verify changed code before shipping

You are an **independent reviewer** who has never seen how this code was written. Judge only what is in the code.

Arguments: `$ARGUMENTS`
- No `--fix` → **report only**. Do not modify source files.
- `--fix` → report, apply fixes, then verify again (Step 6).

Write the report in **English**.

## 1. Config

Read `ai-kit.config.json` at the repo root if it exists:

```json
{
  "baseBranch": "dev",
  "commonDirs": ["src/common", "src/utils", "src/components/common"]
}
```

- `baseBranch` — default `dev`.
- `commonDirs` — if missing, detect existing ones (`src/common`, `src/shared`, `src/utils`, `src/helpers`, `src/lib`, `app/Helpers`, `components/common`, ...).

Below, `<base>` means `origin/<baseBranch>`.

## 2. Scope

```bash
git fetch origin <baseBranch> --quiet || true
BASE=$(git merge-base <base> HEAD 2>/dev/null || git rev-parse HEAD)
git diff "$BASE" --stat
git diff --name-only --diff-filter=ACMR "$BASE"      # committed + uncommitted changes
git ls-files --others --exclude-standard            # new untracked files
```

- Scope = union of both lists, **code files only** (`ts`, `tsx`, `js`, `jsx`, `php`, plus any other source language the repo uses). Skip lock files, generated files, snapshots, build output, minified and vendored code.
- Review **changed lines only**; read surrounding code for context. Do not propose refactoring old code outside the diff.
- Empty scope → write PASS (Step 7) and report "no code changes to review".
- More than ~15 files → split into groups and run the team checks in parallel with subagents (give each the reference files), then merge.

## 3. Built-in reviews (run first)

Invoke with the Skill tool, in order, and collect every finding tagged with its source:
1. **`code-review`** — args `medium` (or `medium --fix` in `--fix` mode). Owns: correctness, swallowed exceptions, edge cases (null, empty arrays, failed async), general efficiency.
2. **`security-review`** — report only. Owns: general security vulnerabilities.

If a built-in skill is unavailable, note it in the report and continue. If a built-in did not cover some files in scope (e.g. it only saw uncommitted changes), list those files in the report and review them for correctness yourself.

## 4. Team checks (after the built-ins)

Do **not** repeat what the built-ins already own. Read each reference file from this skill's `references/` directory before running that check:

| Check | Reference |
|---|---|
| A. Repo standards + lint/typecheck | `references/standards.md` |
| B. Stack-specific security (only what `/security-review` tends to miss) | `references/security.md` |
| C. Shared logic → common dirs | `references/reuse.md` |
| D. Design patterns | `references/patterns.md` |

## 5. Noise rules and severity

- Report only with concrete evidence (`file:line`). No vague "might", "consider" wording.
- No pure formatting/style comments (that is the formatter's job); repo conventions in `standards.md` are not "style".
- Reuse + pattern items (C + D): at most **5**, most important first. If more exist, say how many were omitted.
- Before proposing a new common function, Grep `commonDirs` (and installed dependencies) for an existing equivalent; if one exists, propose reusing it.
- Merge duplicates: same location + same problem → one item, list all sources.

Each item: **Severity | Source/Type | file:line | Problem (1 sentence) | Why it matters (1 sentence) | Fix (short code)**.

Severity:
- **Blocker** — clear security vulnerability; bug that certainly causes wrong results or a crash; lint/typecheck error in changed files.
- **Should fix** — repo-standard violation; duplicated/generic logic not moved to `commonDirs`; existing helper not reused; a pattern that solves a concrete problem in this diff.
- **Suggestion** — optional improvement.

**`/ship` is blocked by any Blocker or Should fix.** Suggestions never block.

## 6. Fix (only with `--fix`)

- `/code-review --fix` already applied its fixes in Step 3. Run the built-in **`simplify`** skill now.
- Fix all remaining Blockers and Should-fix items yourself: security, lint/typecheck, standards, move shared logic into `commonDirs` and update every call site, apply the patterns.
- Keep behavior unchanged except where fixing a bug or security issue. Do not touch files outside the scope except the common files and required call sites.
- Verify once more: rerun Step 2, `security-review`, and the team checks on the new state (skip `code-review` / `simplify`). Anything still failing keeps its severity.

## 7. Write the result for /ship

Compute the fingerprint (**exactly** this command — `/ship` uses the same one):

```bash
BASE=$(git merge-base <base> HEAD 2>/dev/null || git rev-parse HEAD)
FP=$({ git diff "$BASE" --binary; git ls-files --others --exclude-standard; git ls-files --others --exclude-standard -z | xargs -0 -r git hash-object --; } | git hash-object --stdin)
echo "$FP"
```

Write to the file at `git rev-parse --git-path preflight.json` (inside `.git`, never committed):

```json
{ "status": "PASS", "fingerprint": "<FP>", "checkedAt": "<ISO timestamp>", "blocker": 0, "shouldFix": 0, "suggestion": 3 }
```

`status` is `PASS` only if Blocker = 0 **and** Should fix = 0.

## 8. Report

1–2 line summary, then items grouped by severity, then the verdict:
- **Ready to ship** (PASS)
- **Fix before shipping — /ship is blocked** (only Should-fix items)
- **Do not ship — /ship is blocked** (any Blocker)

When blocked, suggest `/preflight --fix` or fixing manually and running `/preflight` again.
If nothing was found, state which checks were run (built-ins, lint/typecheck, A–D) so "clean" is verifiable.
