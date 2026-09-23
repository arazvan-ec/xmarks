# Plan: P58 — templates for two steps that went wrong by hand

Spec: `.claude/flywheel/specs/p58-templates-for-repeated-steps.md`

### T1 — Red: fixture-scratch arms

- route: `opus/high`
- risk: highest
- check: `bash scripts/test-fixture-scratch.sh` fails on the new arms only.

### T2 — Green: refuse a doomed workdir, add --executor-prompt

- route: `opus/medium`
- check: `bash scripts/test-fixture-scratch.sh` green.

### T3 — Template: answering review findings on a PR

- route: `opus/medium`
- check: `bash scripts/check-invocation-budget.sh` + `bash scripts/test-docs-consistency.sh` green.

### T4 — Ledger: the template practice and its three conditions

- route: `opus/medium`
- check: `bash scripts/test-docs-consistency.sh` green.

### T5 — Release: bump, note, backlog, full sweep

- route: `opus/medium`
- check: `bash scripts/test-docs-consistency.sh` + `bash scripts/check-release-bump.sh origin/main` green.
