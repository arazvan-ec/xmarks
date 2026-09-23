# Spec: gate determinism — the same tree gets the same verdict

**Slug:** `gate-determinism` · **Created:** 2026-09-23 · **Backlog:** findings 3–5 of
`docs/research/review-v0.63-v0.71.md`

**Status:** shipped as v0.72.0 — metric PASS. (1) with a forced 1.1 s gap the
arm was red, and it is green after the fix. (2) seeds 0–15 went from a mix of
exit 0 and exit 1 to one verdict. (3) four boundary arms, each red first for its
own reason. The sweep ran with nothing in parallel.

**Prime:** P48 and P49 (cutoffs, route gate), P53 (read-meter's exclusive cut),
v0.71.0 (one cutoff registry).

## R — Requirements

Three places where a verdict depends on something other than the tree:

1. **`test-read-meter.sh` depends on the wall clock.** The exclusive-cut arm
   assumes two fed calls land in the same second (`:308`). When the second ticks
   between them, the arm fails. It turned `main` red after #91
   (`1 of 27 failed: scripts/test-read-meter.sh`).
2. **`check-route-honored.sh` depends on the hash seed.** A merged transition
   (`T1-T2`) is compared against `max(mapped, key=tier)`, where `mapped` is a
   `set`. When two tasks tie on tier (`opus/high` vs `opus/high+delegate`),
   Python's hash-randomized iteration picks the winner, so one tree exits 0 or 1
   depending on `PYTHONHASHSEED`.
3. **Every cutoff is a string comparison.** `"…20:00:00.5Z" >= "…20:00:00Z"` is
   `False`, and a non-`Z` offset sorts by its local wall time, not its instant.
   The corpus already mixes `Z` (83 lines) and `+00:00` (9). A post-cutoff line
   can read as pre-cutoff and have a fatal finding downgraded to a notice. This
   applies to `check-telemetry.sh`, `check-route-honored.sh` (per line and the
   run's `newest`), and `check-task-closure.sh` (the plan's git author date).

## E — Entities

- `scripts/fw_cutoffs.py` — the one cutoff registry. It gains `instant(ts)` and
  `binds(ts, cut)`, so every caller compares instants through one parser.
- `scripts/check-route-honored.sh`, `check-telemetry.sh`, `check-task-closure.sh`
  — the callers.
- `scripts/test-read-meter.sh` — the fixture.

## A — Approach

1. After feeding the two calls, the fixture rewrites the meter file so both rows
   carry the first row's `ts`. The arm's claim (a call *at* the cut second is
   excluded) no longer needs the clock's cooperation. The script under test is
   unchanged.
2. The merged range's planned task is chosen by
   `(tier, not delegate, then task order)` over a sorted sequence, not a set. On
   a tier tie, the non-delegated task is the one the merge runs at, and the
   delegated one is reported as absorbed. That matches the existing merge rule:
   a notice, never fatal.
3. `binds(ts, cut)`: both sides are parsed to aware UTC instants (`Z`, offsets,
   any fractional precision; a naive timestamp is read as UTC).
   - An **empty** `ts` does not bind. A line without one is the telemetry gate's
     to fail, and baselined corpus lacks it.
   - A **non-empty unparsable** `ts` binds. A timestamp the gate cannot place
     must not buy the corpus's forgiveness.
   - An unparsable **cut** raises, exit 2, like an unknown name.

## S — Structure

No new files beyond this spec and its plan. Release v0.72.0 (`requires-action:
false`: no interface or state change).

## O — Operations

Test-first per task: each new arm is seen red on the current code before the fix.

## N — Norms

No arm deleted or weakened. No corpus line rewritten (P18).

## S — Safeguards

The gates' output on the real tree must not change class: same exit codes,
same pre-cutoff counts. That holds because every corpus timestamp is
whole-second `Z` or `+00:00`, and those order the same either way.

## Success metric

- **(1)** `test-read-meter.sh` passes with a forced one-second gap between the
  two feeds. Today that gap makes it fail deterministically.
- **(2)** The tied-merge arm gives the same verdict for `PYTHONHASHSEED` 0–15.
- **(3)** New arms: a fractional-second line at the cut binds in
  `check-telemetry.sh`, and an offset line whose instant is after the cut binds
  in `check-route-honored.sh`. Each is red before the fix and green after.
- The full `scripts/test-*.sh` sweep and every `check-*` gate are green, and the
  real-tree gate outputs match `main` in exit code and counts.
