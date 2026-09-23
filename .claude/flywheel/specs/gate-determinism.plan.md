# Plan: gate determinism — the same tree gets the same verdict

Spec: `.claude/flywheel/specs/gate-determinism.md`

### T1 — The read-meter fixture stops depending on the wall clock

- route: `sonnet/medium`
- check: `bash scripts/test-read-meter.sh` green, and green with a forced one-second gap between the two feeds (red before the fix).

### T2 — A tied merge picks its planned task deterministically

- route: `opus/high`
- check: `bash scripts/test-check-route-honored.sh` green; the tied-merge arm agrees across `PYTHONHASHSEED` 0–15 (it disagreed before).

### T3 — Cutoffs compare instants, through one parser

- route: `opus/high`
- risk: highest
- check: `bash scripts/test-fw_cutoffs.sh`, `bash scripts/test-check-telemetry.sh`, `bash scripts/test-check-route-honored.sh` and `bash scripts/test-check-task-closure.sh` green, each boundary arm seen red first.

### T4 — Release v0.72.0

- route: `sonnet/medium`
- check: `bash scripts/test-docs-consistency.sh` green and the full `scripts/test-*.sh` / `check-*.sh` sweep clean.
