# Plan: P57 — a delegated review says it started

Spec: `.claude/flywheel/specs/p57-a-delegated-review-says-it-started.md`

### T1 — Red: the REVIEW arms

- route: `opus/high`
- risk: highest
- check: `bash scripts/test-delegation-guard.sh` fails on the new arms only.

### T2 — Green: the template and the guard family

- route: `opus/medium`
- check: `bash scripts/test-delegation-guard.sh` green.

### T3 — Skill and docs: review cites the template, README names it

- route: `opus/medium`
- check: `bash scripts/check-invocation-budget.sh` + `bash scripts/test-docs-consistency.sh` green.

### T4 — Release: bump, note, backlog, full sweep

- route: `opus/medium`
- check: `bash scripts/test-docs-consistency.sh` + `bash scripts/check-release-bump.sh origin/main` green.
