# C. Shared logic → common dirs

- A function/helper declared inside a component file that uses no props, state, hooks or closure → candidate to move into `commonDirs`. Give the name, target path and function signature.
- Logic, regex, constants, or formatting (dates, money, numbers) repeated in **2+ places**.
- Duplicated types / interfaces / schemas.
- Re-implementing something that already exists: Grep `commonDirs` and installed dependencies (lodash, date-fns, dayjs, zod, ...) before concluding it is new.
- Repeated UI structure (button, modal, form field) when a common component already exists → reuse it.
- Do **NOT** propose extraction if the code is used in only one place and there is no clear reason (avoid premature abstraction).

Severity: duplicated / generic logic not extracted, or an existing helper/component not reused → **Should fix**. Otherwise → **Suggestion**.
