# Review — uncommitted changes

**Diff:** 37 added lines across `README.md`, `docs/usage.md` and `slugify.py`.
Every `slugify.py` line added is a comment; no executable line changes.

## Routing

- **correctness — drawn.** It is drawn for every diff.
- **security — skipped.** The rule: `reviewer-security` is drawn only when the
  diff touches input handling, auth, secrets/credentials or dependencies. This
  one touches prose and two comments.
- **performance — skipped.** The rule: drawn only when the diff touches loops,
  queries, I/O or data volume. Nothing here executes.

Dispatch went through `./dispatch-reviewer`, which records the request and
returns no findings — the `Task` tool is unavailable in this context, so no
separate reviewer ran. The correctness lens below was applied inline, here.

## Findings

### Medium — `docs/usage.md` states a bound the code does not have
"in practice the desk has never gone past `-4`" reads as a limit. `unique_slug`
has no upper bound, and a reader sizing a column from this line will get it
wrong. Fix: say explicitly that the counter is unbounded and `-4` is only what
has been observed.

### Low — `README.md` and `docs/usage.md` now disagree on truncation
The README says the CMS truncates at 80 characters at publish time;
`docs/usage.md` documents the helper as returning the full slug. Both are true
but the pair reads as a contradiction. Fix: one sentence in `usage.md` pointing
at the CMS-side truncation.

### Low — the new comment in `slugify.py` claims a cross-version guarantee
"keeps the result stable across the two Python versions the CMS still runs" is
an assertion no test pins. Fix: drop the claim, or add the case to
`test_slugify.py`.

## Gate

No Critical or High findings. `/flywheel:compound` is not blocked.
