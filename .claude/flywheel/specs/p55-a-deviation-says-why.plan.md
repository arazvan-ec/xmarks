# Plan: P55 — a route deviation says why

Spec: `.claude/flywheel/specs/p55-a-deviation-says-why.md`

### T1 — Red: the reason arms

- route: `opus/high`
- risk: highest
- check: `bash scripts/test-check-route-honored.sh` fails on the new arms only.

### T2 — Green: the gate requires and prints the reason

- route: `opus/medium`
- check: `bash scripts/test-check-route-honored.sh` and `bash scripts/test-fw_cutoffs.sh` green.

### T3 — Skill: work says to record `route_reason`

- route: `opus/medium`
- check: `bash scripts/check-invocation-budget.sh` green.

### T4 — Release: bump, note, backlog entry

- route: `opus/medium`
- check: `bash scripts/test-docs-consistency.sh` green and every `scripts/test-*.sh` green.
