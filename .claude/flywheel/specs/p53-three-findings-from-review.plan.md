# Plan: P53 — three findings from review, each reproduced first

Spec: `.claude/flywheel/specs/p53-three-findings-from-review.md`

### T1 — Red: the three findings, as arms

- route: `sonnet/medium`
- check: `bash scripts/test-check-route-honored.sh` and `bash scripts/test-read-meter.sh` each fail on the new arms only.

### T2 — Green: the delegation suffix participates

- route: `sonnet/medium`
- check: a planned `haiku/low+delegate` recorded as `haiku/low` exits 1 and is named; recorded with the suffix, green.

### T3 — Green: a plan with no run directory is named

- route: `sonnet/medium`
- check: the gate names the 7 uncompared plans on the real tree and still exits 0.

### T4 — Green: an explicit `--since` is exclusive

- route: `opus/high`
- risk: highest
- check: `bash scripts/test-read-meter.sh` green, including every untouched P44 arm, and `--since first` still reports its earliest call.

### T5 — Release: bump, note, backlog, and the three threads answered

- route: `sonnet/medium`
- check: `bash scripts/test-docs-consistency.sh` green and the full sweep clean.
