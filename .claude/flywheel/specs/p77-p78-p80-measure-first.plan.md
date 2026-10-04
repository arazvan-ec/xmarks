# P77/P78/P80 plan

| Tier | Route | Tasks |
| --- | --- | --- |
| T2 default | `sonnet/medium` | T1, T2 |
| T3 judgment | `opus/high` | T3 |

Riskiest: T3 — big-brother-token's session summary is the record P78 and P80 decide on.

### T1 — newspeak counts prose asks (P77)
- route: `sonnet/medium`
- changes: mods/newspeak/
- check: `bash scripts/check-mods.sh origin/main newspeak`
- test-first: yes

### T2 — committee keeps its tally (P78)
- route: `sonnet/medium`
- changes: mods/resource-committee/
- check: `bash scripts/check-mods.sh origin/main resource-committee`
- test-first: yes

### T3 — Bash by command and cost per session (P80, P78)
- route: `opus/high`
- risk: highest
- changes: mods/big-brother-token/
- check: `bash scripts/check-mods.sh origin/main big-brother-token`
- test-first: yes
