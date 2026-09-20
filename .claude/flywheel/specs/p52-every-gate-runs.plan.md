# Plan: P52 — a gate in the tree is a gate CI runs

Spec: `.claude/flywheel/specs/p52-every-gate-runs.md`

### T1 — Red: the parity cases

- route: `sonnet/medium`
- check: `bash scripts/test-check-ci-gate-parity.sh` fails — the gate does not exist yet.

Arms: a tree whose every gate is invoked passes; an unwired gate fails and is
named; a gate referenced **only from a comment** fails (the whole point); a
workflow invoking a script that does not exist fails; a gate wired in any
workflow file counts; the skip is logged; and the real tree is red **naming
`check-supply-chain-pin.sh` and nothing else**.

### T2 — Green: `check-ci-gate-parity.sh`

- route: `opus/high`
- risk: highest
- check: `bash scripts/test-check-ci-gate-parity.sh` green, and the gate red on the real tree naming exactly the one unwired gate.

### T3 — Wire the hole and the new gate

- route: `haiku/low+delegate`
- check: `bash scripts/check-ci-gate-parity.sh` exits 0 on the real tree, and the full `scripts/test-*.sh` / `check-*.sh` sweep is clean.

### T4 — Release: bump, note, backlog

- route: `sonnet/medium`
- check: `bash scripts/test-docs-consistency.sh` green and `bash scripts/check-release-bump.sh origin/main` reports 0.67.0 → 0.68.0.
