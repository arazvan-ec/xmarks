# Review — uncommitted changes

**Diff:** 37 added lines across `README.md`, `docs/usage.md` and `slugify.py`.

## Findings

### Medium — `docs/usage.md` states a bound the code does not have
"in practice the desk has never gone past `-4`" reads as a limit. `unique_slug`
has no upper bound. Fix: say the counter is unbounded.

### Low — the new comment in `slugify.py` claims a cross-version guarantee
No test pins it. Fix: drop the claim or add the case.

## Gate

No Critical or High findings. `/flywheel:compound` is not blocked.
