---
name: recall
description: On-demand lookup into the flywheel learnings ledger — cheaply list matching entries by title/type/files/date, then expand one on request. Use when SessionStart's budgeted injection didn't surface a learning you need, or to search past decisions/gotchas by keyword.
argument-hint: "<query>"
allowed-tools: Read, Grep, Bash(git *)
---

# /flywheel:recall — on-demand ledger lookup

`session-start.sh` only injects a relevance-scored, budgeted subset of `.claude/flywheel/LEARNINGS.md`. This is the escape hatch for everything else: **cheap search first, full detail only for what you actually pick.**

Query: **$ARGUMENTS**

## Layer 1 — cheap search

Grep `.claude/flywheel/LEARNINGS.md` for `$ARGUMENTS` across entry titles (`^## `) and metadata comments (`<!-- fw: ... -->`) — do **not** load full entry bodies yet. Match case-insensitively against the type, title text, `files=`, `spec=`, `pr=`, and `branch=` values.

Print a numbered list, cheapest form, one line each:

```
1. gotcha: logout didn't clear the session cookie (2026-07-08, files: src/auth/login.ts,src/auth/session.ts)
2. decision: use zod for validation (2026-06-01, files: src/schema.ts)
```

For old free-prose entries with no metadata comment, match on the title/body text and print them with no `files:`/date suffix.

If nothing matches, say so plainly and suggest a broader query — don't guess at an answer.

## Layer 2 — expand on demand

If the user (or the calling agent) asks for one of the numbered results, or `$ARGUMENTS` is specific enough that exactly one entry matches, read and print that entry's **full body** (title through the next `## ` header or EOF). Don't dump every match's full body unprompted — that defeats the point of keeping SessionStart injection small.
