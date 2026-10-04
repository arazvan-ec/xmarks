# P72 T7 plan

| Tier | Route | Tasks |
| --- | --- | --- |
| T3 judgment | `opus/high` | T1 |

Riskiest: T1 — the only task; it denies reads.

### T1 — ration-book mod, test-first
- route: `opus/high`
- risk: highest
- changes: mods/ration-book/, .claude-plugin/marketplace.json, README.md
- check: `bash scripts/check-mods.sh origin/main ration-book`
- test-first: yes
