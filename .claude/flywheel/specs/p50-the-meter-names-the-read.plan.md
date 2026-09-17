# Plan: P50 — the meter names the read, not just the total

Spec: `.claude/flywheel/specs/p50-the-meter-names-the-read.md`

P49's gate watches this cycle: every task below writes its own transition line.

### T1 — Red: the reader's new cases

- route: `sonnet/medium`
- check: `bash scripts/test-read-meter.sh` fails on the new arms only, with every P44 arm still green.

Arms: `max_read` is the largest single call, not the last and not the total;
`by_tool` attributes bytes and calls per tool; a write tool appears with 0 bytes
and a real call count; an empty window reports UNMEASURED for the new fields too,
never `max_read=0`.

### T2 — Green: `max_read` and `by_tool` in `--since`

- route: `opus/high`
- risk: highest
- check: `bash scripts/test-read-meter.sh` green, including every untouched P44 arm — the hook half must keep its silence-and-exit-0 contract.

### T3 — Red then green: a maximum is never summed

- route: `sonnet/medium`
- check: `bash scripts/test-run-cost.sh` green, with two runs of `max_read=100` rolling up to 100.

### T4 — The line's shape carries both fields

- route: `haiku/low+delegate`
- check: `skills/work/references/work-detail.md` names `max_read` and `by_tool`, and `bash scripts/check-invocation-budget.sh` stays green.

### T5 — Release: bump, note, backlog, and P40b's evidence

- route: `sonnet/medium`
- check: `bash scripts/test-docs-consistency.sh` green and the full `scripts/test-*.sh` / `check-*.sh` sweep clean.
