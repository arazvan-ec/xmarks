# Spec: P16 — Live run/cycle progress (task ledger + telemetry report)

**Slug:** `p16-live-progress` · **Created:** 2026-07-13 · **Backlog:** P16
**Status:** signed 2026-07-13 (owner) — full cycle approved, no intermediate gates

## R — Requirements

Whenever flywheel executes multi-step work, the owner follows progress live
without reading transcripts or asking. Two surfaces, both pillars:

1. **Task ledger** — at execution start, materialize the steps as visible tasks
   in the host task system (pillar 2: one task per contract Rule; pillar 1: one
   task per phase in `loop`, one per plan task in `work`). Update states
   (`pending → in_progress → completed`, `blocked` on gates/failures) at every
   transition, in real time.
2. **Telemetry report** — a per-execution, git-persisted HTML report
   (`.claude/flywheel/runs/<slug>/<YYYY-MM-DD>.html`, slug = process slug or
   spec slug) regenerated at each transition and republished to a **stable
   artifact URL**, so an open page always shows the latest state. Content:
   ledger + states/timings, gates and their outcomes, unit/agent telemetry
   (tokens, duration), output counts (findings/tasks), maturation or compound
   events, metric verdict.
3. **Signal, don't narrate** — chat is reserved for gates, blockers, and the
   final synthesis.

**In scope:** `skills/run`, `skills/process` (contract template),
`skills/loop`, `skills/work`, README + `skills/help` sync, `plugin.json`
0.15.0 → 0.16.0, `upgrades/v0.16.0.md`.
**Out of scope:** a static report-generator script (the runtime authors the
report — agent-native, no code backend); changes to `agents/` or `hooks/`;
P14's lifecycle features (discovery, bookkeeping); retroactive reports.

## E — Entities

| Entity | Key fields | Lives at |
| --- | --- | --- |
| Task ledger | step id, name, state, transition times | host task system (ephemeral, rendered live to the owner) |
| Telemetry report | ledger snapshot, gates, unit telemetry, outputs, verdict | `.claude/flywheel/runs/<slug>/<date>.html` (git) + stable artifact URL |
| Progress obligation | the fixed text each skill carries | `skills/run`, `skills/process` template, `skills/loop`, `skills/work` |

## A — Approach

Encode the obligation **in the skill prompts** — in flywheel, prompts *are* the
implementation (Claude is the runtime). Rejected alternative: a hook/script
progress tracker (e.g. a `PostToolUse` state writer). More "enforced", but adds
runtime surface and per-call latency exactly where the flow-audit flagged hook
cost (P9/P11), duplicates state the host task system already renders, and
contradicts the agent-native stance. Trade-off accepted: prompt obligations are
advisory-strength; mitigated by making them fixed sections/steps (contract law,
like GATEs) rather than tips.

## S — Structure

- `skills/run/SKILL.md` — new fixed **Progress** step (ledger at start, update
  per transition, regenerate + republish report, signal-don't-narrate).
- `skills/process/SKILL.md` — contract template gains the **Progress
  reporting** section (new contracts inherit it; `flow-audit` v3 is the pilot).
- `skills/loop/SKILL.md` — same obligation per phase: ledger of the six phases,
  cycle report per execution.
- `skills/work/SKILL.md` — one ledger task per plan task when invoked
  standalone; feeds the same cycle report.
- `README.md` + `skills/help/SKILL.md` — document the surface (state list
  gains `runs/`).
- `.claude-plugin/plugin.json` → 0.16.0 · `upgrades/v0.16.0.md`
  (`requires-action: false`).

Dependency: report conventions already declared in this repo's `DATA.md`
(runs/ location) and piloted by `flow-audit` v3 + run #001's report.

## O — Operations

1. `skills/run`: insert the Progress step (before step 1, spanning the run).
2. `skills/process`: add the Progress reporting section to the template in §3.
3. `skills/loop`: add the per-phase ledger + cycle-report obligation.
4. `skills/work`: add the per-task ledger line + report-update note.
5. Sync `README.md` + `skills/help` (state list + one feature line each).
6. Bump `plugin.json`; write `upgrades/v0.16.0.md`.
7. Run the three test scripts; fix anything red.

## N — Norms

Match existing SKILL.md voice: imperative, terse, GATEs in caps. Keep additions
short — the flow-audit flagged prompt weight (P12): each skill gains ≤ 10 lines.
Report HTML: self-contained (CSP: no CDNs), theme-committed console style as
piloted in run #001, es/EN microcopy per the pilot. Docs edits keep
`marketplace.json`/`plugin.json` descriptions untouched (surface unchanged).

## S — Safeguards

- **Token cost:** regenerate the report at *phase/task transitions only* (never
  per tool call); report stays lean (~≤15 KB, no transcript dumps). Do not
  reintroduce the waste P12 exists to remove.
- **No secrets:** reports are git-committed and artifact-published — never
  include connection strings, tokens, or env values (aligns with P13).
- **Fail-open:** if the task system or artifact publishing is unavailable
  (headless/CI), execution proceeds and the final summary says progress
  reporting was degraded — it must never block or fail a run/cycle.
- **Honesty:** the report states observed facts only — real states, real
  timings; a task is never `completed` without its local check.
- **Idempotency:** one report file per (slug, date); same-day re-executions
  regenerate the same file; the artifact URL stays stable per report.

## Success metric

One command, exit 0 = PASS:

```bash
bash scripts/test-docs-consistency.sh \
  && bash scripts/test-install-vendored.sh \
  && bash scripts/test-read-prime.sh \
  && grep -q 'Progress' skills/run/SKILL.md \
  && grep -q 'Progress' skills/process/SKILL.md \
  && grep -q 'Progress' skills/loop/SKILL.md \
  && grep -q 'Progress' skills/work/SKILL.md \
  && grep -q '"version": "0.16.0"' .claude-plugin/plugin.json \
  && test -f upgrades/v0.16.0.md
```
