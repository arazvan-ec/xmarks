# Plan — stage-routing (P27)

Spec: [`stage-routing.md`](stage-routing.md) · 8 tasks · pinned task format, so
`scripts/plan-route.sh` can lint this plan (and every future one).

## Routing

| Tier | Route | Tasks |
| --- | --- | --- |
| T1 mechanical | `haiku/low+delegate` | T6, T7 |
| T2 default | `sonnet/medium` | T1, T3, T4, T5, T8 |
| T3 judgment | `opus/high` | T2 |

Riskiest step: **T2** — the linter's grammar is the contract every future plan
is graded against; too strict and it fails honest plans, too loose and a route
means nothing.

### T1 — Failing test for the route linter
- route: `sonnet/medium`
- changes: `scripts/test-plan-route.sh` (new)
- check: `bash scripts/test-plan-route.sh` fails because `scripts/plan-route.sh` does not exist
- test-first: yes

### T2 — Route linter and tier summary
- route: `opus/high`
- risk: highest
- changes: `scripts/plan-route.sh` (new)
- check: `bash scripts/test-plan-route.sh` prints `ALL PASS`
- test-first: yes

### T3 — Rubric and pinned task format in plan
- route: `sonnet/medium`
- changes: `skills/plan/SKILL.md`
- check: `bash scripts/plan-route.sh .claude/flywheel/specs/stage-routing.plan.md` exits 0 on this plan, written to the format the skill pins
- test-first: no

### T4 — work honors, escalates, and records the route
- route: `sonnet/medium`
- changes: `skills/work/SKILL.md`
- check: the skill names the delegate path, the second-red escalation, and the `route` telemetry field; `bash scripts/check-description-budget.sh` still passes
- test-first: no

### T5 — executor agent plus effort on the existing agents
- route: `sonnet/medium`
- changes: `agents/executor.md` (new), `agents/{verifier,evaluator,reviewer-correctness,reviewer-security,reviewer-performance}.md`
- check: `claude plugin validate . --strict` passes with `effort:` in agent frontmatter
- test-first: no

### T6 — Wire the new test into CI
- route: `haiku/low+delegate`
- changes: `.github/workflows/validate-plugins.yml`
- check: the workflow runs `bash scripts/test-plan-route.sh`; `grep -q test-plan-route .github/workflows/validate-plugins.yml`
- test-first: no

### T7 — Docs: README table, help map, upgrade note, version bump
- route: `haiku/low+delegate`
- changes: `README.md`, `skills/help/SKILL.md`, `upgrades/v0.39.0.md`, `.claude-plugin/plugin.json`
- check: `bash scripts/test-docs-consistency.sh` passes with version 0.39.0
- test-first: no

### T8 — Proposals backlog and decision log
- route: `sonnet/medium`
- changes: `docs/research/improvement-proposals.md`
- check: P27 appears in both tables with a dated decision-log entry stating the evidence limit (structural metric, no token claim)
- test-first: no
