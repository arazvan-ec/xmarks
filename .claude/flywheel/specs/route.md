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
   - `route` — `<model>/<effort>[+delegate]`, the exact grammar `/flywheel:plan` uses
   - `why` — the reason for each decision
   - `escalate-if` — the observable signal that the choice was too cheap
2. **The decision order is fixed, and the first question that answers wins:**
   1. Does a deterministic tool or script already do it? → `tool`, no model.
   2. Does the work carry a point of view that must not inherit the caller's
      framing (research, adversarial review, grading, synthesis)? →
      `fresh-session`. It is never a subagent, and never a `fork`: a fork
      inherits the whole context and ignores `model`.
   3. Is it reads or edits with no judgment — many identical ones, or one that
      would flood the caller's context? → `subagent` at tier 1, in parallel.
      Breadth never raises the tier; only an item that does not fit tier 1's
      context (per R5's reference, with room for the brief and the answer) does.
   4. Is it ordinary work inside existing structure? → tier 2.
   5. Is it design, ambiguity, security or data risk, a change that needs
      design across 3+ modules, or the riskiest step? → tier 3.
3. **Effort before model.** Within a tier, recommend the lowest effort that
   holds; raise effort when the *check* is subtle, not when the work is large.
   Propose a cheaper model only when the next tier down, at the same effort,
   would do the job: measure the higher tier at low effort first. The cost that counts is cost per **completed** task, not per call:
   a cheap model that needs a retry is not cheap.
4. **`scripts/route-tiers.txt` stays the single authority** on what a tier is.
   The skill reads it; it never restates a tier as a rule of its own.
5. **Prices and context windows live in `skills/route/references/models.md`**,
   dated, with a pointer to how to refresh them. They are cited only from the
   step that compares cost, so the body stays free of numbers that go stale.

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
| 4 | Rename a function across 12 files | subagent | 1 |
| 5 | Add one validation rule to an existing parser, test-first | here | 2 |
| 6 | Design the persistence schema for a new process | here | 3 |
| 7 | Independent review of a PR's diff | fresh-session | 3 |
| 8 | Summarise the output of a test run | subagent | 1 |

## O — Operations

`skills/route/SKILL.md`, `skills/route/references/models.md`, the README
command table, the `/flywheel:help` map, a version bump and
`upgrades/v0.73.0.md` (`requires-action: false`).

## N — Non-goals

It does not choose for the caller. It returns a recommendation the caller can
paste into `create_session` or `Agent`, and the caller decides.

## S — Sign-off

Signed by the owner on 2026-09-23.

Amended the same day, before any release: R3's sentence on cheaper models read
backwards ("only when the higher tier at low effort is not enough"). It now says
what the skill does and the owner asked for: the higher tier at low effort is
measured first, and a cheaper model is offered only when the tier below would do
the job. R2.3 and R2.5 were aligned with the skill in the same pass: breadth
does not raise a mechanical subagent above tier 1 (only an item that does not
fit tier 1's context does, with the size kept in R5's reference so R4 and R5
hold), and "3+ modules" means a change that needs design across them. Found by
`/code-review`; flagged to the owner.
