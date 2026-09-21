# Plan: gate coherence — three rules that disagree with their siblings

Spec: `.claude/flywheel/specs/gate-coherence.md`

| Tier | Route | Tasks |
| --- | --- | --- |
| **T2 default** | `sonnet/medium` | T1, T2, T4, T5 |
| **T3 judgment** | `opus/high` | T3 |

T3 is the riskiest step: it edits three gates at once, and a cutoff that shifts
by accident forgives or fails a stretch of history permanently (P18). Its check
is a before/after equality on the served values, not a passing suite.

### T1 — The pairing gate sees every script, not only `.sh`

- route: `sonnet/medium`
- check: `bash scripts/test-check-test-pairing.sh` green, with an arm where a `.py` added without its test reddens the gate and one where the stem-keyed pair satisfies it.

### T2 — route-honored: a cycle with no line for any task has not started

- route: `sonnet/medium`
- check: `bash scripts/test-check-route-honored.sh` green, including the arm that keeps a PARTIALLY recorded cycle fatal — without it this change deletes P49.

### T3 — Three cutoffs, one declared place

- route: `opus/high`
- risk: highest
- check: `bash scripts/test-fw_cutoffs.sh` green and `bash scripts/test-check-telemetry.sh` green; the value each gate serves is unchanged from before the extraction.

### T4 — The list-intake plan lands, now that nothing reddens on it

- route: `sonnet/medium`
- check: `bash scripts/check-route-honored.sh` and `bash scripts/check-task-closure.sh` both exit 0 with the plan committed and its work not started.

### T5 — Release: bump, note, backlog rows

- route: `sonnet/medium`
- check: `bash scripts/test-docs-consistency.sh` green and the full sweep clean.
