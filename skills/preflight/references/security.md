# B. Stack-specific security

`/security-review` owns general vulnerabilities (injection, XSS, auth, SSRF, ...). Check **only** the stack-specific items below, and skip anything it already reported.

- Secrets: hardcoded keys/tokens/passwords; `.env` or credential files about to be committed; secrets written to logs.
- PHP: `echo` / template output without `htmlspecialchars` (or the framework's escaping); SQL built by string concatenation instead of prepared statements; `unserialize` on untrusted data; file upload without type/size checks; `include`/`require` with a path from input.
- Next.js / React:
  - `NEXT_PUBLIC_*` variables holding secrets.
  - Server-only code (DB, secrets, `fs`) imported into a client component (`"use client"`).
  - Server actions / route handlers without an auth check, or with authorization done only on the client.
  - `href` taken from user input (`javascript:` URLs); `dangerouslySetInnerHTML` with unsanitized data.
- Cookies without `httpOnly` / `secure` / `sameSite`; CORS `*` on authenticated endpoints; open redirects.
- Mass assignment: passing request body straight into a model/ORM create/update.
- Internal errors or stack traces returned to the client.
- New dependencies: unfamiliar names or names close to popular packages (typosquatting); suggest running `npm audit` / `pnpm audit` / `composer audit`.

Every finding here is a **Blocker**.
