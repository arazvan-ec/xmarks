---
name: recall
description: On-demand, progressive-disclosure lookup over the flywheel learnings ledger — cheaply list matching entries by title/metadata, then expand one on request. Use when SessionStart's injected subset doesn't cover what you need, or to search past decisions/gotchas by keyword, file, or type.
argument-hint: "<query>"
allowed-tools: Read, Bash(grep *), Bash(git *)
---

# /flywheel:recall — progressive-disclosure ledger lookup

`SessionStart` only injects a relevance-budgeted subset of `.claude/flywheel/LEARNINGS.md` (see `scripts/session-start.sh`). This is the cheap escape hatch for everything else: **Layer 1** lists matches for almost no tokens; **Layer 2** expands exactly one entry, on request.

Query: **$ARGUMENTS**

## Layer 1 — cheap list

Grep `.claude/flywheel/LEARNINGS.md` (and `.claude/flywheel/learnings-archive/*.md` if that directory exists) case-insensitively for `$ARGUMENTS` across both the `## type: title` header lines and the `<!-- fw: … -->` metadata lines — so a query can match a title word, a `type=`, a file path in `files=`, a `spec=` slug, or a `branch=`. If `$ARGUMENTS` is empty, list every entry instead of searching.

For each match, print a numbered one-liner: `type — title (date, files)`, e.g.:

```
1. gotcha — logout didn't clear the session cookie (2026-07-08, src/auth/login.ts, src/auth/session.ts)
2. decision — chose git-native ledger over a DB (2026-07-08)
```

Old free-prose entries (no metadata line) don't have a clean `type`/`files` — list them as `note — <header text>` using whatever the `## …` header says.

If nothing matches, say so plainly and suggest a broader query rather than guessing at an expansion.

## Layer 2 — expand on demand

When the user (or you, mid-task) picks a number or otherwise identifies one entry from the Layer 1 list, print that entry's **full body** verbatim (header, metadata line, and prose) by reading it out of the ledger — don't summarize or paraphrase it away. Never expand more than one entry unless explicitly asked for more; that's what keeps this cheaper than just re-injecting the whole file.

## Notes

- Read-only: `/flywheel:recall` never edits the ledger. Use `/flywheel:compound` to add to it.
- This is the same list → expand pattern `scripts/session-start.sh` uses for its "N more learnings" pointer — `/flywheel:recall` is how you pull on that pointer.
