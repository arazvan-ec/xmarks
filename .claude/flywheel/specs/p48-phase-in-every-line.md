# Spec: P48 — the ledger can be aggregated by phase, and read across runs

**Slug:** `p48-phase-in-every-line` · **Created:** 2026-09-17 · **Backlog:** P48
**Status:** in progress.

**Prime:** P42 (the telemetry duty got an owner that runs), P40a/P44 (`bytes_in`
with per-FIELD coverage), P23 (`run-cost.sh`), and the ledger entry *"keeping the
aggregate is not keeping the measurement"* — the same defect, one level up.

## R — Requirements

CLAUDE.md says `cost.bytes_in` *"is what makes the difference checkable"*. Asked
the plain question the convention implies — **which phase of the loop costs
most?** — the ledger cannot answer it, for two independent reasons measured on
the corpus as it stands (11 run files, 58 transitions):

| defect | measured |
| --- | --- |
| `phase` is optional, so most lines do not carry it | 36 of 58 lines have none; **6 of 11 cycles** have none on any line |
| there is no view across runs | `run-cost.sh` takes one run and one baseline; the cross-cycle roll-up had to be hand-written to ask the question at all |

`check-telemetry.sh` accepts `task` **or** `phase` — so the 36 lines are
conforming, and the gate is right that they identify a transition. What they
cannot do is be summed by phase. Identification and aggregation are different
duties, and only the first was ever specified.

In scope, two assertions, each seen red before its green:

1. **A line written from now on names its phase.** A line whose `ts` is at or
   after the cutoff and carries no non-empty `phase` fails the gate. Before the
   cutoff it is a **counted notice, never fatal** — the corpus predates the rule
   and nothing may be backfilled (P18).
2. **The corpus has a transversal view.** `run-cost.sh --all <runs-dir>` totals
   every run file and breaks the totals down **by phase** and by route, under
   the per-FIELD coverage discipline P40a already established: an absent field
   reports UNMEASURED, never 0.

Out of scope: retro-stamping a phase onto existing lines (fabricated evidence),
and requiring `task` — a pillar-2 run has phases and no plan tasks.

## E — Entities

- **phase** — where in the loop a transition happened: `spec`, `work`, `verify`,
  `review`, `compound`, `ship`, `loop`, or a pillar-2 Rule phase. Free text: the
  gate asserts it is *there*, never which vocabulary it uses.
- **cutoff** — `2026-09-17T20:00:00Z`, one constant in the gate, overridable via
  `FLYWHEEL_PHASE_REQUIRED_FROM` so the arms can place a fixture on either side.
  Chosen to sit **after the newest line in the corpus** (`19:40:54Z`) and
  **before this cycle's first transition**: the rule binds live work from the
  moment it ships, and this cycle is its first subject.

## A — Approach

**Why a cutoff and not a baseline entry.** The shape debt is per *line*, not per
slug — 36 lines across 10 slugs, six of which are otherwise fully covered.
Listing them in `telemetry-baseline.txt` would exempt those slugs from the
**coverage** check too, hiding a real gap to silence a shape one. A timestamp
splits exactly the set that can still be fixed (lines not yet written) from the
set that cannot, and needs no list.

**Why not a future date.** A cutoff of "tomorrow" would ship a rule that cannot
fire on any live run today — P46's defect, committed deliberately. Placed at
20:00Z it is live on the first line this cycle writes.

The roll-up reuses `load()` verbatim rather than re-deriving totals: two counters
for one corpus is how the aggregate and the measurement drift apart.

## S — Structure

- `scripts/check-telemetry.sh` + `scripts/test-check-telemetry.sh`
- `scripts/run-cost.sh` + `scripts/test-run-cost.sh`
- `skills/work/references/work-detail.md` — the line's shape carries `phase`.
- `skills/work/SKILL.md` — one clause, in the body, where the duty is stated.
- `.claude-plugin/plugin.json` → **0.64.0** · `upgrades/v0.64.0.md`
- `docs/research/improvement-proposals.md` — P48 with the measured evidence.

## O — Operations

- T1 test-first, assertion 1: post-cutoff line with `task` and no `phase` red;
  same line with `phase` green; pre-cutoff phase-less line green **and counted**;
  a baselined slug's post-cutoff line stays a notice.
- T2 implement the rule in `check-telemetry.sh`.
- T3 test-first, assertion 2: `--all` over a two-cycle fixture totals both and
  groups by phase; phase-less lines land in their own bucket, never attributed;
  a field absent everywhere reports UNMEASURED, not 0.
- T4 implement `--all`.
- T5 release: the two skill files, bump, upgrade note, backlog entry, gates.

## N — Norms

Test-first, each arm watched red before its green. Terse code. Atomic commits,
pushed per task. This diff touches `scripts/` and `skills/`, so it is a release
and `check-release-bump.sh` applies to it.

## S — Safeguards

- **The rule must not redden the tree it ships on.** The cutoff is verified
  against the real corpus, not assumed: the newest existing line is `19:40:54Z`
  and two of today's lines (p40b) carry no phase — a date-granular cutoff of
  "2026-09-17" would fail CI on history that cannot be fixed.
- **A notice is counted, not repeated.** 36 pre-cutoff lines print as one summary
  line naming the count, not 36 lines of noise that would bury a real finding.
- **`task` stays sufficient for identification.** Assertion 1 adds a duty; it
  does not remove the existing one, so a pillar-2 line with a phase and no task
  and a pillar-1 line with both are both conforming.
- **The roll-up never fabricates a zero.** Per-FIELD coverage is carried through
  the merge, so a phase whose lines predate `bytes_in` reports UNMEASURED for
  that field while still totalling the three it has.
- **Fail-loud on unusable input.** A `--all` path that is not a directory, or a
  directory with no run files, exits 2 — not a green "nothing to report".

## Success metric

```
export TMPDIR="$(mktemp -d)"
for t in scripts/test-*.sh; do bash "$t" || echo "RED $t"; done
for g in scripts/check-*.sh; do bash "$g" || echo "RED $g"; done
bash scripts/run-cost.sh --all .claude/flywheel/runs
```

Decisive clauses, on the real corpus rather than a fixture:

1. `check-telemetry.sh` is **green on the tree as it stands** (36 phase-less
   lines, all pre-cutoff, reported as one counted notice) and **red on that same
   tree with this cycle's own telemetry line stripped of its `phase`**.
2. `run-cost.sh --all` reports the 11 cycles and 58 transitions, and answers by
   phase the question that took a hand-written script this session.
