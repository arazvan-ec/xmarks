# P72 T0b plan

| Tier | Route | Tasks |
| --- | --- | --- |
| T2 default | `sonnet/medium` | T2 |
| T3 judgment | `opus/high` | T1 |

Riskiest: T1 — it rewrites the model of every main-thread request.

### T1 — resource-committee mod, test-first
- route: `opus/high`
- risk: highest
- changes: mods/resource-committee/, .claude-plugin/marketplace.json
- check: `bash scripts/check-mods.sh origin/main resource-committee`
- test-first: yes

### T2 — models.md refresh + release
- route: `sonnet/medium`
- changes: skills/route/references/models.md, .claude-plugin/plugin.json, upgrades/v0.85.0.md, README.md
- check: `bash scripts/test-docs-consistency.sh`
- test-first: no
