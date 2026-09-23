# Spec: route — recommend the mechanism, model and effort for delegated work

**Slug:** `route` · **Created:** 2026-09-23 · **Backlog:** follow-up of P27 (stage routing)
**Status:** signed 2026-09-23 (owner)
**Prime:** P27 routes every *plan task* through `scripts/route-tiers.txt`, and its
spec leaves everything outside a plan out of scope ("pillar-2 `run` routing — a
follow-up once the rubric has evidence"). Child sessions, loose subagents and
`/flywheel:run` executions still inherit whatever the caller is on. The veo repo
hit the cost of that: hundreds of identical citation checks that should run on the
cheapest model, and research work that must never run in a subagent because it
inherits the caller's framing.

## R — Requirements

1. **`/flywheel:route <task>`** returns one recommendation for a piece of work
   about to be delegated. There are four fields, each with a one-line reason:
   - `mechanism` — `tool` · `fresh-session` · `subagent` · `here`
   - `route` — `<model>/<effort>[+delegate]`, the exact grammar `/flywheel:plan` uses,
     or `none` when the mechanism is `tool`
   - `why` — the reason for each decision
   - `escalate-if` — the observable signal that the choice was too cheap
2. **The decision order lives in `skills/route/SKILL.md`, steps 2 and 3, and
   nowhere else.** It has two stages, mechanism then tier, and within each the
   first yes wins. This spec does not restate the conditions: every restatement
   drifted from the skill within one review round. What pins the behaviour is
   the case table in S, which a fresh session can check.
3. **Effort before model.** Within a tier, recommend the lowest effort that
   holds; raise effort when the *check* is subtle, not when the work is large.
   Propose a cheaper model only when the next tier down, at the same effort,
   would do the job: measure the higher tier at low effort first. The cost that counts is cost per **completed** task, not per call:
   a cheap model that needs a retry is not cheap.
4. **`scripts/route-tiers.txt` stays the single authority** on what a tier is.
   The skill reads it; it never restates a tier as a rule of its own.
5. **Prices and context windows live in `skills/route/references/models.md`**,
   dated, with a pointer to how to refresh them. They are cited only from the
   steps that need a price, a context size or a model's effort support, so the
   body stays free of numbers that go stale.

Out of scope: enforcing the choice (a repo can add its own hook, as veo's
`delegar.py` does), changing `/flywheel:plan`'s rubric, and telemetry of routes.

## E — Entities

| Entity | Fields |
| --- | --- |
| Recommendation | `mechanism`, `route`, `why`, `escalate-if` |
| Mechanism | `tool` · `fresh-session` · `subagent` · `here` |
| Route | as P27: `model` ∈ haiku·sonnet·opus·fable, `effort` ∈ low·medium·high·xhigh·max, `delegate` |

## A — Approach

A skill, not a script. Whether work "carries a point of view" is a judgment a
regex cannot make, and veo's `delegar.py` proved that a hook can check that a
model was chosen, not which one is right. Rejected alternative: extending
`/flywheel:plan`'s tier table. That table routes *plan tasks* and is enforced by
`plan-route.sh`; mixing ad-hoc delegation into it would give one table two
contracts.

## S — Success metric

1. The structural gates are green: `test-docs-consistency.sh`,
   `check-invocation-budget.sh` (default `body` and `worst`, no exception),
   `test-install-vendored.sh`, `check-release-bump.sh` and
   `check-version-citations.sh`.
2. Case table: a **fresh session** given only the skill and each task below
   returns the expected `mechanism` for at least 7 of the 8, and the expected
   tier for at least 6 of the 8.

| # | Task | mechanism | tier |
| --- | --- | --- | --- |
| 1 | Check whether 300 URLs still respond | tool | — |
| 2 | Confirm that a quoted figure appears on the cited page, ×200 | subagent | 1 |
| 3 | Find counter-evidence for hypothesis H3 | fresh-session | 3 |
| 4 | Rename a function across 12 files | tool | — |
| 5 | Add one validation rule to an existing parser, test-first | here | 2 |
| 6 | Design the persistence schema for a new process | here | 3 |
| 7 | Independent review of a PR's diff | fresh-session | 3 |
| 8 | Summarise the output of a test run | subagent | 1 |

## O — Operations

`skills/route/SKILL.md`, `skills/route/references/models.md`, the README
command table, the `/flywheel:help` map, a version bump and
`upgrades/v0.77.0.md` (`requires-action: false`). Renumbered from 0.73.0
when `main` shipped 0.73.0–0.76.0 (#95) before this release merged.

## N — Non-goals

It does not choose for the caller. It returns a recommendation the caller can
paste into `create_session` or `Agent`, and the caller decides.

## S — Sign-off

Signed by the owner on 2026-09-23.

Amended the same day, before any release, after rounds of `/code-review` on the
draft skill: R2 no longer restates the order and points to the skill as its only
normative text, with the case table as the check; R3's sentence on cheaper models read backwards and now says what
the owner asked for (measure the higher tier at low effort first); R5 now covers
every step that needs a price, a context size or a model's effort support. The
rounds are in the git log of this branch. Flagged to the owner.

## Verify

**S2 on `40dba7e` — PASS** (fresh session, sparse checkout of `skills/route/`
and `scripts/`; https://github.com/arazvan-ec/xmarks/pull/96#issuecomment-5802767740).
Mechanism 7/8, tier 7/8, against thresholds of 7 and 6. The one miss is case 4:
the session answered `tool` (sed or an LSP rename) where the table expects a
tier-1 subagent. It followed "first yes wins" correctly; the skill's own
example ("apply this recorded rename") contradicted its step 1. The example
was changed after the run, and case 4's expected answer was then revised to
`tool`: the old one contradicted the skill's own step 1, and the measured
answer is what that rule gives. This is a revision after measurement, recorded
here so it is not read as a result. The same run surfaced three more
ambiguities, fixed afterwards: how to launch `here` when this session runs on
another model, whether a tier's effort is a floor, and an undefined `+delegate`.
