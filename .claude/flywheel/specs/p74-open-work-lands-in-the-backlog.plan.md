# P74 plan

| Tier | Route | Tasks |
| --- | --- | --- |
| T2 default | `sonnet/medium` | T2, T3 |
| T3 judgment | `opus/high` | T1 |

Riskiest: T1 — a gate that misreads the ledger blocks every PR.

### T1 — check-followups.sh, test-first
- route: `opus/high`
- risk: highest
- changes: scripts/check-followups.sh, scripts/test-check-followups.sh, .github/workflows/validate-plugins.yml
- check: `bash scripts/test-check-followups.sh`
- test-first: yes

### T2 — compound files the row
- route: `sonnet/medium`
- changes: skills/compound/SKILL.md
- check: `bash scripts/check-invocation-budget.sh`
- test-first: no

### T3 — file P75–P80, tag their lessons, release
- route: `sonnet/medium`
- changes: docs/research/improvement-proposals.md, .claude/flywheel/LEARNINGS.md, .claude-plugin/plugin.json, upgrades/v0.86.0.md
- check: `bash scripts/check-followups.sh`
- test-first: no
