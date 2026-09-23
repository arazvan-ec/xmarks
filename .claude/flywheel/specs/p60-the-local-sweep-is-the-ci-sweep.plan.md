# Plan: P60 — the local sweep is the CI sweep

Spec: `.claude/flywheel/specs/p60-the-local-sweep-is-the-ci-sweep.md`

### T1 — Red: test-sweep arms

- route: `opus/high`
- risk: highest
- check: `bash scripts/test-sweep.sh` fails on every arm, because `sweep.sh` does not exist yet.

### T2 — Green: sweep.sh reads the workflow and reads `$?`

- route: `opus/medium`
- check: `bash scripts/test-sweep.sh` green.

### T3 — Wire: allowlist entry, CLAUDE.md pre-push line

- route: `opus/medium`
- check: `bash scripts/check-task-closure.sh` + `bash scripts/test-docs-consistency.sh` green.

### T4 — Release: bump, note, backlog row, sweep on the real tree

- route: `opus/medium`
- check: `bash scripts/sweep.sh origin/main` green.
