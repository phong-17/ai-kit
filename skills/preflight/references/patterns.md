# D. Design patterns

Every suggestion must state **the concrete problem the pattern solves in this diff**. If the only reason is "looks nicer", drop it.

- `if/else` or `switch` on type/status repeated in **2+ places** → lookup map or Strategy.
- fetch + loading + error + state logic repeated across components → custom hook.
- Component taking many boolean props to change behavior → variants or composition.
- Object creation with many variants scattered around → Factory.
- `fetch` / DB calls made directly in many places → service / repository layer.
- Prop drilling deeper than 3 levels → context / provider (only when it actually hurts).

Severity: the pattern removes duplication or a real bug risk introduced in this diff → **Should fix**. Otherwise → **Suggestion**.
