# P75 plan

| Tier | Route | Tasks |
| --- | --- | --- |
| T3 judgment | `opus/high` | T1 |

Riskiest: T1 — the only task; a memo that hid a real red would make the gate lie.

### T1 — memoize closure checks, skip the nested sweep
- route: `opus/high`
- risk: highest
- changes: scripts/check-task-closure.sh, scripts/test-check-task-closure.sh, scripts/sweep.sh, scripts/test-sweep.sh
- check: `bash scripts/test-check-task-closure.sh` and `bash scripts/test-sweep.sh`
- test-first: yes
