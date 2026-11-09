# A. Repo standards + lint/typecheck

## Mechanical checks
Run only what the repo already has configured (never install tools). Prefer the repo's own scripts (`package.json` → `lint`, `typecheck`, `type-check`; `composer.json` → `lint`, `phpstan`, `phpcs`):
- TypeScript: `npx tsc --noEmit -p .`
- ESLint: `npx eslint <changed js/ts files>`
- PHP: `php -l <changed php files>`; PHPStan / PHPCS if configured.

Record results in the report. Errors in **changed files** are Blockers; errors only in untouched files are not reported. A failing tool does not stop the review.

## Conventions (Should fix)
Compare with how the surrounding repo code does it — the repo's existing convention wins over personal taste:
- Naming of files, functions, components, variables, constants matches the repo.
- File placed in the folder the repo uses for that kind of code.
- Import style (aliases like `@/`, relative paths) matches the repo.
- Errors handled and logged the way the rest of the repo does.
- `any` / unsafe casts without a reason; `@ts-ignore` / `eslint-disable` without an explanatory comment.
- Leftover `console.log`, `debugger`, `var_dump`, `dd()`, `print_r`; commented-out code.
- Magic numbers/strings that should be named constants or enums.
