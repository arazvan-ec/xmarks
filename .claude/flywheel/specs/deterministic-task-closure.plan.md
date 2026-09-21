# Plan: deterministic task closure — the `check:` is executed

Spec: `.claude/flywheel/specs/deterministic-task-closure.md`

| Tier | Route | Tasks |
| --- | --- | --- |
| **T2 default** | `sonnet/medium` | T1, T2, T4, T5 |
| **T3 judgment** | `opus/high` | T3 |

T3 is the riskiest step and sits at the top tier: it is the code that **executes
strings out of a repo file**, and its allowlist is the whole security boundary
between "CI already runs these scripts" and "verify runs whatever a PR wrote".

### T1 — `--json` carries the check it already parsed

- route: `sonnet/medium`
- check: `bash scripts/test-plan-route.sh` green, including a new arm asserting a task's `check` text survives into the JSON record.

### T2 — Red: the taxonomy, before it exists

- route: `sonnet/medium`
- check: `bash scripts/test-check-task-closure.sh` fails naming the missing script, with arms for PASS, FAIL, UNRUNNABLE, the allowlist refusal and the cutoff.

### T3 — Green: extract, allowlist, execute, report

- route: `opus/high`
- risk: highest
- check: `bash scripts/test-check-task-closure.sh` green; a check naming a command outside the allowlist is reported UNRUNNABLE and provably never executed.

### T4 — Wire it where it bites: CI and `verify`

- route: `sonnet/medium`
- check: `bash scripts/check-ci-gate-parity.sh` green with the new gate invoked, and `bash scripts/check-invocation-budget.sh` green after the `verify` edit.

### T5 — Release: bump, note, backlog

- route: `sonnet/medium`
- check: `bash scripts/test-docs-consistency.sh` green and the full sweep clean.
