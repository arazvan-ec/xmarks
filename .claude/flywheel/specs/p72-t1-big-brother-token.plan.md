# P72 T1 plan

| Tier | Route | Tasks |
| --- | --- | --- |
| T3 judgment | `opus/high` | T1 |

Riskiest: T1 — the only task.

### T1 — big-brother-token mod, test-first
- route: `opus/high`
- risk: highest
- changes: mods/big-brother-token/, .claude-plugin/marketplace.json, README.md
- check: `bash scripts/check-mods.sh origin/main big-brother-token`
- test-first: yes
