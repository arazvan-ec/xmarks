---
name: compound
description: Capture the reusable knowledge from this cycle — decisions, gotchas, and patterns — into the versioned learnings ledger so the next cycle starts smarter. Use at the end of a unit of work, after review.
allowed-tools: Read, Edit, Write, Bash(git *), Bash(date *)
---

# /flywheel:compound — close the loop (learning capture)

This is what makes the loop *compound*: each cycle leaves knowledge that primes the next.

Prepend one **typed entry per distinct learning** to the **top** (newest-first) of `.claude/flywheel/LEARNINGS.md` (create the file if missing, with a `# flywheel learnings` header). Keep it tight — the SessionStart hook injects only a relevance-scored, budgeted subset of this file, and `/flywheel:recall` greps the rest, but every entry still costs something the moment it's selected.

Include only what a future cycle would genuinely benefit from — omit the obvious. One cycle typically yields 0–3 entries, not one per bullet point you can think of. Before closing, ask explicitly: *did we discover how to build a stub, seed data, or stand up a harness that the next cycle shouldn't have to rediscover?* — if so, that's a `fixture` entry.

**Only compound what this cycle proved.** A learning is durable context that primes every future session, so a wrong one is worse than none — it misleads silently. Record a lesson only when it rests on **observed evidence** from this cycle (a test that went green, a run/PR, output you actually saw), the same bar `work`/`verify` hold for code. If you could not verify it — a hypothesis, a plausible-but-unrun recipe, a guess about why something happened — do **not** write it as a durable conclusion; leave it out, or note it explicitly as unverified.

## Entry format

Get today's date with `date +%F` and the current branch with `git branch --show-current`. For each distinct learning:

```
## <type>: <one-line title>
<!-- fw: type=<type>; date=<YYYY-MM-DD>; files=<comma-separated touched files>; spec=<spec-slug>; pr=<PR number>; branch=<branch>; evidence=<what proved it> -->

<what/why/fix, as 2-5 sentences of prose: the trap and the guard for a gotcha, the
choice and rejected alternative for a decision, the reusable snippet/command for a
pattern, the root cause and the regression test for a bugfix.>
```

- `type` is one of `decision`, `gotcha`, `pattern`, `bugfix`, `fixture`.
  A **`fixture`** entry captures *how to set up the world* — the recipe to build
  a valid stub/fixture for a domain entity, seed the datastore, or stand up a
  test harness, with the fields/relationships easy to get wrong (title names the
  entity, e.g. `fixture: editorial stub for homeTag`). This is the costliest
  thing a future cycle re-derives, so capture it whenever this cycle discovered
  one — but **only a recipe you observed work** (it built a valid instance and
  the check using it went green), never a plausible-but-unrun one. Record *how
  to build* test data, **never** real credentials or PII. Keep the recipe body
  prose + inline code — no lines starting with `## ` (the ledger parsers read
  those as a new entry boundary and would split the recipe).
- The metadata comment is a **single line**: `key=value` pairs separated by `; `.
  `type` and `date` are required; omit a key entirely when it doesn't apply (no
  `pr=` key at all, not `pr=;`).
- **`evidence=` — what proved this lesson.** A learning is durable context that
  primes every future session (see "Only compound what this cycle proved" below),
  so every new entry carries `evidence=` pointing at the proof: a test name, a
  `command → result`, a PR/run id, the green check. If a genuinely cross-cutting
  lesson can't point to one concrete proof, write `evidence=unverified`
  **explicitly** — never omit it to hide that the entry rests on reasoning.
  Absent `evidence=` means *legacy* (pre-this-convention), which is different
  from an explicit `unverified`; the SessionStart injection and `/flywheel:recall`
  flag `unverified` entries so a reader weighs them accordingly. Keep it a
  pointer — never a credential or a raw output dump.
- `files` should list the paths most relevant to *finding this entry again* — this
  is what `scripts/session-start.sh` matches against the current branch's changed
  files to decide relevance, so keep it to the handful that actually matter.

Old free-prose entries already in the ledger are untouched — this format only applies going forward; the SessionStart hook and `/flywheel:recall` both still load them (as always-eligible, low-priority entries).

Then stage the ledger (`git add .claude/flywheel/LEARNINGS.md`) so it is committed with the work. Report a one-line summary of what you compounded.
