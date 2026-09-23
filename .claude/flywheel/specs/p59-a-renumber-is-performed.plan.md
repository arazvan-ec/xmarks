# Plan: P59 — a renumber is performed, not remembered

Spec: `.claude/flywheel/specs/p59-a-renumber-is-performed.md`

### T1 — Red: test-renumber arms on a fixture repo, including the #81 replay

- route: `opus/high`
- risk: highest
- check: `bash scripts/test-renumber.sh` fails on every arm, because `renumber.sh` does not exist yet.

### T2 — Green: mechanics, then `--check` and the keep marker

- route: `opus/high`
- check: `bash scripts/test-renumber.sh` green.

### T3 — Template: `skills/ship/references/renumber.md`, cited from ship

- route: `opus/medium`
- check: `bash scripts/check-invocation-budget.sh` + `bash scripts/test-docs-consistency.sh` green.

### T4 — Release: bump, note, backlog row, sweep on the real tree

- route: `opus/medium`
- check: `bash scripts/sweep.sh origin/main` green.
