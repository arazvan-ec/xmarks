# P75 — the sweep stops re-running itself

**Status:** signed 2026-10-04 (owner: "sí, ataca P75").

## R — Requirements

`bash scripts/sweep.sh` is the pre-push gate and took 10–30 min on the P72
branch. Measured before changing anything: `check-task-closure.sh` alone
**556 s**, grading 127 tasks that cite only **48 distinct commands** (79 repeat
runs: `test-docs-consistency` ×26, `check-invocation-budget` ×23,
`test-check-route-honored` ×8…), and two of them (P59 T4, P60 T4) run
`bash scripts/sweep.sh origin/main` — a whole sweep inside the sweep.

- One run per distinct check per gate run; every citing task keeps its own row
  and verdict, red ones included.
- The sweep hands `FW_SWEEP_ACTIVE=1` to its check-task-closure step only; a
  sweep that sees it runs nothing, says `SKIPPED nested sweep`, exits 0 — the
  enclosing sweep is running every step and its verdict decides (the mirror of
  P60's `FW_TASK_CLOSURE_ACTIVE` skip).

Out: changing what any check proves; parallelism.

## S — Success metric

Both tests green with the new arms seen red first; task-closure verdicts
identical row by row before/after; task-closure standalone 556 s → measured;
full sweep wall time measured before push.
