---
name: compound
description: Capture the reusable knowledge from this cycle — decisions, gotchas, and patterns — into the versioned learnings ledger so the next cycle starts smarter. Use at the end of a unit of work, after review.
allowed-tools: Read, Edit, Write, Bash(git *)
---

# /flywheel:compound — close the loop (learning capture)

This is what makes the loop *compound*: each cycle leaves knowledge that primes the next.

Prepend one entry **per learning** to the **top** (newest-first) of `.claude/flywheel/LEARNINGS.md` (create the file if missing, with a `# flywheel learnings` header). Keep each entry tight — the `SessionStart` hook injects a relevance-scored subset of these every session, so bloat costs context every single time.

Get today's date with `date +%F`. Entry format — an `## <type>: <title>` header, a single greppable metadata comment, then the body:

```
## gotcha: logout didn't clear the session cookie
<!-- fw: type=gotcha; date=2026-07-08; files=src/auth/login.ts,src/auth/session.ts; spec=user-login; pr=42; branch=feature/login -->

Session cookies survived logout because the redirect fired before `clearSession()`.
Fix: await `clearSession()` before `res.redirect`. Root cause: fire-and-forget in
the handler. Guard: added a test asserting no `Set-Cookie` on the logout response.
```

- **Title** (`## <type>: <one-line title>`): `type` is one of `decision`, `gotcha`, `pattern`, `bugfix`. Pick whichever fits the learning; write a separate entry per learning rather than bundling several types under one header.
- **Metadata comment** (`<!-- fw: k=v; k=v; … -->`, one line, right after the title): `type` and `date` are required; `files` (comma-separated, the files this cycle actually touched), `spec` (the spec slug), `pr`, and `branch` are optional but include them when known — they're what makes injection and `/flywheel:recall` relevant instead of blind. HTML comments are render-invisible but git-diffable and greppable, so this line costs nothing to read yet is fully machine-filterable.
- **Body**: the learning itself — what/why/fix/guard, as prose. Same ethos as before: include only what a future cycle would genuinely benefit from, omit the obvious.

Then stage the ledger (`git add .claude/flywheel/LEARNINGS.md`) so it is committed with the work. Report a one-line summary of what you compounded.
