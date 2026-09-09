# Spec — stage routing: per-task model + effort in the plan (P27)

Slug: `stage-routing` · Date: 2026-09-09 · Pillar 1 (build the software)

## R — Requirements

A plan today is a flat list of tasks, all executed by whatever model and effort
the session happens to be on. That is the wrong default in both directions: a
file rename pays Opus prices, and a security-sensitive migration may run at low
effort because the session was left there.

In scope:
- `/flywheel:plan` assigns every task a **route** — `model/effort`, optionally
  `+delegate` — from a fixed 3-tier rubric, and pins the task block format so
  the route is machine-checkable.
- `/flywheel:work` **honors** the route (delegate, or raise/lower session
  effort), **escalates** one tier on a second red instead of grinding cheap, and
  records `route` in the cycle telemetry.
- A lint/summary script for a plan's routes, wired into CI.
- One new agent as the vehicle for tier-1 delegation; `effort:` set on the
  existing agents so role routing covers effort, not just model.

Out of scope: automatic model switching without the user's consent (the route is
a plan-level decision approved at the plan gate); any token-count claim; pillar-2
`run` routing (a follow-up once the rubric has evidence).

## E — Entities

| Entity | Fields |
| --- | --- |
| Route | `model` ∈ haiku·sonnet·opus·inherit, `effort` ∈ low·medium·high·max, `delegate` bool |
| Task block | `### T<n> — <title>` + `route:`, `changes:`, `check:`, `test-first:`, optional `risk: highest` |
| Tier | T1 mechanical (`haiku/low+delegate`), T2 default (`sonnet/medium`), T3 judgment (`opus/high`) |
| Escalation | a task's route raised one tier after a second red on the same check; telemetry `route_escalated_from` |

## A — Approach

Route **per plan task**, decided at plan time and approved at the plan gate —
not auto-switched mid-task. Rejected alternative: a runtime heuristic in `work`
that picks a model per task on its own. It would move a cost/quality decision
out of the gate the owner signs, and it cannot be reviewed before it spends.
Routing is data in the plan; `work` only executes it and reports deviations.

The knobs are real, not invented (verified against Claude Code 2.1.267): agent
frontmatter takes `model:` and `effort:` (`low|medium|high|max` or an integer,
validated by the CLI's agent loader), and a session takes `--effort`,
`/model <model> <effort>`, `effortLevel`, `CLAUDE_CODE_EFFORT_LEVEL`, plus
`CLAUDE_CODE_SUBAGENT_MODEL` for subagents.

Honesty constraint (P18/P23): the payoff is **not** claimed in tokens. The
success metric is structural (routes present, valid, lint-enforced) and the
observable payoff rides on the existing `cost` proxies.

## S — Structure

- `skills/plan/SKILL.md` — rubric + pinned task block + routing table at the gate.
- `skills/work/SKILL.md` — honor / escalate / record.
- `agents/executor.md` (new) — haiku, `effort: low`, tier-1 vehicle, with an
  `ESCALATE:` refusal path.
- `agents/{verifier,evaluator,reviewer-*}.md` — add `effort:`.
- `scripts/plan-route.sh` + `scripts/test-plan-route.sh` (new pair).
- `.github/workflows/validate-plugins.yml` — run the new test.
- Docs: README, `skills/help/SKILL.md`, `upgrades/v0.39.0.md`,
  `docs/research/improvement-proposals.md` (P27 + decision log),
  `.claude-plugin/plugin.json` → 0.39.0.

## O — Operations

1. `scripts/test-plan-route.sh` — written first, seen red.
2. `scripts/plan-route.sh` — parse task blocks, validate routes, enforce that
   the riskiest task is not on the cheapest tier, print a tier summary.
3. `skills/plan/SKILL.md` — rubric, pinned format, gate copy.
4. `skills/work/SKILL.md` — route honoring, escalation, telemetry field.
5. `agents/executor.md` + `effort:` on the four existing agents.
6. CI step, docs, version bump, upgrade note, proposals + decision log.

## N — Norms

Terse prose, no ceremonial comments (CLAUDE.md writing-token discipline). Bash
scripts follow the house style of `scripts/run-cost.sh`: `set -euo pipefail`,
`fail`/`pass` helpers, `mktemp -d` + `trap` in tests, `ALL PASS` last line.
Script/test pair moves together in the diff (P22). Atomic commits.

## S — Safeguards

- **A cheap tier must never silently do expensive damage**: `executor` executes
  one fully-specified mechanical task and returns `ESCALATE: <reason>` rather
  than inventing a design decision; `work` escalates on a second red.
- **The riskiest step can never be routed cheap** — lint failure, not advice.
- **No silent model switching**: honoring a T3 route asks once if the session
  cannot be raised; a route that could not be honored is reported, not ignored.
- **Fail-open**: routing lint and telemetry never block the work.
- **No token claims** anywhere in the output (`run-cost.sh` already warns on a
  `tokens` key; nothing here adds one).

## Success metric

All green, from a clean tree:
1. `bash scripts/test-plan-route.sh` → `ALL PASS`.
2. `bash scripts/plan-route.sh .claude/flywheel/specs/stage-routing.plan.md` →
   exit 0, every task routed, tier summary printed (dogfooded: this cycle's own
   plan is the first routed plan).
3. `bash scripts/test-docs-consistency.sh`, `bash scripts/check-description-budget.sh`,
   `bash scripts/check-test-pairing.sh`, `bash scripts/test-install-vendored.sh`
   → all pass.
4. `claude plugin validate . --strict` → passes with `effort:` present in agent
   frontmatter. **Evidence limit, stated rather than glossed:** that command
   validates the marketplace/plugin manifests, so it proves `effort:` is not
   rejected — not that the loader consumes it. The direct evidence is the
   shipped CLI itself (2.1.267): its agent-file schema carries
   `effort: union(enum(low|medium|high|max), int).optional()` and its loader
   emits `Agent file … has invalid effort …`. A headless `claude -p --debug`
   probe with a deliberately invalid `effort:` surfaced no diagnostic either
   way, so it is not counted as evidence. Because the field is optional, a CLI
   that does not read it ignores it and routing still works through `model:`
   plus session effort.
