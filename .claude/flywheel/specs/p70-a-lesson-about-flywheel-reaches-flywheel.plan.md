# P70 plan

| Tier | Route | Tasks |
| --- | --- | --- |
| T1 mechanical | `haiku/low+delegate` | T3 |
| T2 default | `sonnet/medium` | T2, T4, T5 |
| T3 judgment | `opus/high` | T1 |

Riskiest: T1 — it decides what text leaves a private repo.

### T1 — upstream-issue.sh, test-first
- route: `opus/high`
- risk: highest
- changes: scripts/upstream-issue.sh, scripts/test-upstream-issue.sh
- check: `bash scripts/test-upstream-issue.sh`
- test-first: yes

### T2 — vendor it
- route: `sonnet/medium`
- changes: scripts/install-vendored.sh, scripts/test-install-vendored.sh
- check: `bash scripts/test-install-vendored.sh`
- test-first: yes

### T3 — issue form + label workflow
- route: `haiku/low+delegate`
- changes: .github/ISSUE_TEMPLATE/flywheel-feedback.yml, .github/workflows/labels.yml
- check: `bash scripts/test-upstream-issue.sh`
- test-first: no

### T4 — compound offers the issue
- route: `sonnet/medium`
- changes: skills/compound/SKILL.md, skills/compound/references/upstream.md
- check: `bash scripts/check-invocation-budget.sh`
- test-first: no

### T5 — flow-audit reads the channel
- route: `sonnet/medium`
- changes: .claude/flywheel/processes/flow-audit.md, README.md
- check: `bash scripts/test-docs-consistency.sh`
- test-first: no
