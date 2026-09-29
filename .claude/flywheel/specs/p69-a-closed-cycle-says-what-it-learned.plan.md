# P69 plan

| Tier | Route | Tasks |
| --- | --- | --- |
| T2 default | `sonnet/medium` | T3 |
| T3 judgment | `opus/high` | T1, T2 |

Riskiest: T1 — the scope rule decides whether the hook blocks unrelated
branches or never fires at all.

### T1 — compound-due.sh, test-first
- route: `opus/high`
- risk: highest
- changes: scripts/compound-due.sh, scripts/test-compound-due.sh
- check: `bash scripts/test-compound-due.sh`
- test-first: yes

### T2 — wire both delivery paths
- route: `opus/high`
- changes: hooks/hooks.json, scripts/install-vendored.sh, scripts/test-install-vendored.sh
- check: `bash scripts/check-hook-parity.sh`
- test-first: yes

### T3 — compound records its outcome line
- route: `sonnet/medium`
- changes: skills/compound/SKILL.md, skills/work/references/work-detail.md
- check: `bash scripts/check-invocation-budget.sh`
- test-first: no
