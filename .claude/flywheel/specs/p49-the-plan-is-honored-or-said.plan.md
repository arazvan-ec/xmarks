# Plan: P49 — the plan's ladder is honored, or the record says otherwise

Spec: `.claude/flywheel/specs/p49-the-plan-is-honored-or-said.md`

This cycle is its own gate's first live subject: every task below writes a
transition line, and the gate reddens if one is missing or if a merge goes
unsaid.

### T1 — Red: the gate's cases

- route: `sonnet/medium`
- check: `bash scripts/test-check-route-honored.sh` fails — the gate does not exist yet.

Arms: a plan task with no transition line; a transition above its planned tier
with and without `route_escalated_from`; a merged range reported as a notice; an
unrankable route reported, never read as honored; pre-cutoff drift counted, not
fatal; unusable input exits 2.

### T2 — Green: `plan-route.sh --json`

- route: `sonnet/medium`
- check: `bash scripts/test-plan-route.sh` green, and `--json` emits each task's route, tier and rank.

One parser for the plan format. The linter already ranks routes against
`route-tiers.txt`; the gate consumes that rather than re-deriving it.

### T3 — Green: `check-route-honored.sh`

- route: `opus/high`
- risk: highest
- check: `bash scripts/test-check-route-honored.sh` green; red on p42's pair with T5-T7 missing and green on this cycle's own plan.

### T4 — `work`'s rule gains the direction it lacked

- route: `sonnet/medium`
- check: `bash scripts/check-invocation-budget.sh` green after the edit.

The body says *never downgrade silently*. The observed direction is upward, and
through merges. One clause, in the body.

### T5 — Wire CI and run every discovered gate

- route: `haiku/low+delegate`
- check: the new gate appears in `.github/workflows/validate-plugins.yml` and the full `scripts/test-*.sh` sweep is green.

### T6 — Release: bump, note, backlog

- route: `sonnet/medium`
- check: `bash scripts/test-docs-consistency.sh` green and `bash scripts/check-release-bump.sh origin/main` reports 0.64.0 → 0.65.0.
