---
name: compound
description: Capture the reusable knowledge from this cycle — decisions, gotchas, and patterns — into the versioned learnings ledger so the next cycle starts smarter. Use at the end of a unit of work, after review.
allowed-tools: Read, Edit, Write, Bash(git *)
---

# /flywheel:compound — close the loop (learning capture)

This is what makes the loop *compound*: each cycle leaves knowledge that primes the next.

Append a terse entry to the **top** (newest-first) of `.claude/flywheel/LEARNINGS.md` (create the file if missing, with a `# flywheel learnings` header). Keep it tight — `session-start.sh` injects a relevance-scored, budgeted subset of this file every session, so bloat costs context every single time.

## Entry format

One entry per genuinely reusable fact this cycle produced (usually 1, sometimes a couple). Each entry is a title line, a metadata comment, and a short body:

```markdown
## <type>: <one-line title>
<!-- fw: type=<type>; date=<YYYY-MM-DD>; files=<comma-separated changed files>; spec=<spec slug, if any>; pr=<PR number, if known>; branch=<branch name> -->

<what/why/fix/guard, 2-5 lines of prose. Include the rejected alternative for
decisions, the trap + avoidance for gotchas, the snippet/command for patterns.>
```

- **Title:** `## <type>: <title>` where `type` is one of `decision`, `gotcha`,
  `pattern`, `bugfix`. Human-scannable, greppable by `/flywheel:recall`.
- **Metadata comment:** a single `<!-- fw: k=v; k=v; … -->` line right after the
  title. It's an HTML comment — invisible when rendered, but git-diffable and
  greppable, which is what lets `session-start.sh` and `/flywheel:recall` filter
  entries without parsing prose. `type` and `date` (get today's with `date +%F`)
  are required; fill `files`/`spec`/`pr`/`branch` from what you know about this
  cycle (git status/diff, the active spec, the PR if one exists) and omit any you
  don't know — don't guess.
- **Body:** the learning itself, as prose. Unchanged ethos: include only what a
  future cycle would genuinely benefit from, omit the obvious.

Multiple entries in one `/flywheel:compound` call are fine — one block per fact, newest at the top.

Then stage the ledger (`git add .claude/flywheel/LEARNINGS.md`) so it is committed with the work. Report a one-line summary of what you compounded.
