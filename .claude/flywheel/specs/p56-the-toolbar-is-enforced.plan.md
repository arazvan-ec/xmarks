# Plan: P56 — the progress toolbar is enforced, not remembered

Spec: `.claude/flywheel/specs/p56-the-toolbar-is-enforced.md`

### T1 — Red: the toolbar arms

- route: `opus/high`
- risk: highest
- check: `bash scripts/test-toolbar.sh` fails because `scripts/toolbar.sh` does not exist yet.

### T2 — Green: remind and stop modes

- route: `opus/medium`
- check: `bash scripts/test-toolbar.sh` green.

### T3 — Wire: plugin hooks and the vendored installer

- route: `opus/medium`
- check: `bash scripts/test-install-vendored.sh` green with the two new hook assertions.

### T4 — Docs: README, CLAUDE.md clarification, hooks description

- route: `opus/medium`
- check: `bash scripts/test-docs-consistency.sh` green.

### T5 — Release: bump, note, backlog, full sweep

- route: `opus/medium`
- check: `bash scripts/test-docs-consistency.sh` + `bash scripts/check-release-bump.sh origin/main` green (the full sweep and the strict plugin validation ran locally; the CLI is not on the CI runner, so it cannot be this task's check).
