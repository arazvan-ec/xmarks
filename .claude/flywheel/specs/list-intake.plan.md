# Plan: list intake — a handed list becomes a plan without a REASONS spec

Spec: `.claude/flywheel/specs/list-intake.md`

The spec named a prerequisite before this plan could even be committed: the
closure gate had to stop grading a task that has not started. It shipped in
v0.70.0 as PENDING, and its sibling `check-route-honored.sh` learned the same
discriminator in the gate-coherence cycle. Neither is a task here.

| Tier | Route | Tasks |
| --- | --- | --- |
| **T2 default** | `sonnet/medium` | T1, T3 |
| **T3 judgment** | `opus/high` | T2 |

T2 is the riskiest step: the fork replaces a refusal that exists to protect the
spec. A guard that can be talked past removes a protection rather than a
friction, which is worse than the friction it removes.

### T1 — `plan-route.sh` knows which riskiest rule applies

- route: `sonnet/medium`
- check: `bash scripts/test-plan-route.sh` green — an all-T2 list-plan lints clean, and an ordinary plan whose riskiest task sits below the top tier still fails.

### T2 — The STOP becomes a fork, and the T3 refusal survives it

- route: `opus/high`
- risk: highest
- check: `bash scripts/test-plan-route.sh` green with a list carrying one T3-shaped item refused by name, and `bash scripts/check-invocation-budget.sh` green after the `plan` edit.

### T3 — Release: bump, note, docs

- route: `sonnet/medium`
- check: `bash scripts/test-docs-consistency.sh` green and the full sweep clean.
