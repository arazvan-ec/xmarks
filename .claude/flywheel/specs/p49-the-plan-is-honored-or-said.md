# Spec: P49 — the plan's ladder is honored, or the record says otherwise

**Slug:** `p49-the-plan-is-honored-or-said` · **Created:** 2026-09-17 · **Backlog:** P49
**Status:** shipped as v0.65.0 — metric PASS. 26 discovered `scripts/test-*.sh`
and 11 `check-*` gates green under an isolated `TMPDIR`. Both decisive clauses
hold: the gate reports 8 unrecorded tasks across p13/p42/p43 (five of them
`haiku/low+delegate`), p43's `T1-T2` merge and p13's three unrankable routes **as
pre-cutoff notices**, leaving the tree green; and it is **green on this cycle's
own plan and telemetry, red the moment T5's line is removed**, naming it. T5 was
routed `haiku/low+delegate` and ran there — `delegation-record.sh` wrote
`{tool: Agent, model: haiku}`.

**Prime:** P27 (route tiers), P41 (flywheel can honor its own `+delegate`), P48
(the ledger is totalled by phase), and `work`'s rule *"a route you could not
honor → say which route was not honored. Never downgrade silently."*

## R — Requirements

The aggregate says the route ladder collapsed: of 46 routed transitions, **40
ran on opus**, sonnet 5, **haiku 0**, and `+delegate` appears once in 58 lines.
The obvious reading — the planner over-assigns, or `work` disobeys — is **wrong**,
and checking it is what this spec is for. Measured per task, where a plan exists
and a transition maps to one:

| cycle | planned | what the record shows |
| --- | --- | --- |
| p42 | T1-T3 sonnet, T4 opus, T5 haiku+delegate, T6 sonnet, T7 haiku+delegate | T1-T2, T3, T4 **honored**; **T5, T6, T7 have no line at all** |
| p43 | T1 sonnet, T2 opus, T3 sonnet, T4+T5 haiku+delegate | T3 honored; T1 **absorbed** into a `T1-T2` transition that ran opus/high; **T4, T5 have no line** |
| p13 | T1-T3 opus/high | ran `opus/xhigh` ×3 — an effort the tier ladder cannot rank |

Every 1:1 transition honored its route — 5 of 5. The ladder evaporates three
other ways, none of which any gate asks about:

1. **The cheap tail is never recorded.** Five planned tasks across two cycles,
   including **all four `haiku/low+delegate` tasks**, have no transition line.
   The ledger cannot distinguish *"ran and wrote nothing"* from *"never ran"* —
   and that is the finding, not a detail of it.
2. **A merge silently buys the higher tier.** One transition covering `T1-T2`
   runs at the max of the two, so the cheaper task's route is paid for and
   never used. Nothing records that it happened.
3. **A route can be unrankable.** 26 lines carry `opus/xhigh`; the ladder in
   `plan-route.sh` is `low|medium|high|max`. A route nothing can rank cannot be
   compared with the plan's, and today it passes as if it had been.

In scope, three assertions:

1. **Every plan task appears in the record.** A task with no transition line —
   directly or inside a range like `T1-T2` — fails the gate from the cutoff on.
2. **A transition above its plan's tier says so.** Running above the max planned
   tier of the tasks it covers requires `route_escalated_from`. Without it, red.
3. **What cannot be compared is reported, never assumed honored.** A merge, an
   unrankable route, a transition that maps to no plan task: counted notices.

Out of scope, deliberately: **deciding whether `xhigh` is a tier.** The ladder
says `low|medium|high|max` and 26 lines say otherwise; which is right is the
owner's call, not a gate's. Reported, and raised in the backlog.

Also out of scope: failing a plan whose tasks all sit at the top tier. That was
this cycle's opening hypothesis and the evidence refuted it — the plans in this
repo route across all three tiers.

## E — Entities

- **mapped transition** — one whose `task` resolves to plan task ids: `T4`, a
  bare `4` (work's executor writes `{"task": 4}`), or a range `T1-T2`. Anything
  else (`spec`, `plan`, a phase name) maps to nothing: those transitions precede
  the plan and have no route to honor.
- **planned tier of a transition** — the **max** over the tasks it covers. A
  merged transition running at the max is not drift; the cheaper task going
  unrun at its own tier is what gets reported.
- **cutoff** — `2026-09-17T20:00:00Z`, the P48 constant reused by name
  (`FLYWHEEL_ROUTE_CHECK_FROM`), for the same reason: the corpus predates the
  rule and nothing may be backfilled (P18).

## A — Approach

**One parser for the plan format.** `plan-route.sh` already parses task blocks,
loads the tier table and ranks routes. Re-implementing that in a second gate is
how two readers of one format drift — the ledger has the entry. So `plan-route.sh`
gains `--json`, emitting per-task routes and their tiers, and the new gate
consumes it.

**The rule fires on this cycle.** A gate whose only subjects predate its cutoff
is P46's defect. So this cycle carries its own **plan**, and its transitions are
the gate's first live subject: skip a task's line, or merge two tasks without
saying so, and it reddens on me.

## S — Structure

- `scripts/check-route-honored.sh` + `scripts/test-check-route-honored.sh`
- `scripts/plan-route.sh` + `scripts/test-plan-route.sh` — `--json`.
- `skills/work/SKILL.md` — the rule's missing half: the observed direction is
  *upward*, and through merges, and neither was named.
- `.github/workflows/validate-plugins.yml` — the gate runs in CI.
- `.claude-plugin/plugin.json` → **0.65.0** · `upgrades/v0.65.0.md`
- `docs/research/improvement-proposals.md` — P49, and the `xhigh` question.

## O — Operations

### T1 — Red: the gate's cases
- route: `sonnet/medium`
- check: `bash scripts/test-check-route-honored.sh` fails naming the missing gate.

### T2 — Green: `plan-route.sh --json`
- route: `sonnet/medium`
- check: `bash scripts/test-plan-route.sh` green, `--json` emits every task's route and tier.

### T3 — Green: `check-route-honored.sh`
- route: `opus/high`
- risk: highest
- check: `bash scripts/test-check-route-honored.sh` green; the gate is red on p42's plan with T5-T7 missing and green on this cycle's own plan.

### T4 — `work`'s rule gains the direction it lacked
- route: `sonnet/medium`
- check: `bash scripts/check-invocation-budget.sh` green after the edit.

### T5 — Wire CI and run every discovered gate
- route: `haiku/low+delegate`
- check: `bash scripts/check-hook-parity.sh` and the full `scripts/test-*.sh` sweep green.

### T6 — Release: bump, note, backlog
- route: `sonnet/medium`
- check: `bash scripts/test-docs-consistency.sh` and `bash scripts/check-release-bump.sh origin/main` green.

## N — Norms

Test-first. Terse code. Atomic commits, pushed per task. Every task writes its
own transition line — this cycle is the gate's first subject, so skipping one is
the defect the gate exists to catch.

## S — Safeguards

- **The evidence is checked before it is built on.** The opening hypothesis (a
  collapsed planner) was refuted by the per-task comparison, and the spec says
  so rather than quietly retargeting.
- **Absence is not attributed.** A plan task with no line is reported as
  *unrecorded*, never as "ran at the wrong tier": the ledger cannot tell whether
  it ran, and the gate must not claim to know.
- **A route the ladder cannot rank is never read as honored.** `opus/xhigh`
  reports as unrankable; the vocabulary question goes to the owner.
- **No backfill.** Pre-cutoff drift is a counted notice, exactly as in P48.
- **Fail-loud on unusable input.** No plan, no telemetry, or a plan the linter
  rejects → exit 2 for that pair, never a silent pass.

## Success metric

```
export TMPDIR="$(mktemp -d)"
for t in scripts/test-*.sh; do bash "$t" || echo "RED $t"; done
for g in scripts/check-*.sh; do bash "$g" || echo "RED $g"; done
```

Decisive clauses, on real history and on this cycle:

1. `check-route-honored.sh` reports p42's three unrecorded tasks and p43's two,
   and p43's `T1-T2` merge, **as pre-cutoff notices** — the tree stays green.
2. It is **green on this cycle's own plan and telemetry**, and **red on that
   same pair with one task's transition line removed**.
