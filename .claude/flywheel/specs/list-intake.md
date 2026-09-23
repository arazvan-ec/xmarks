# Spec: list intake — a handed list becomes a plan without a REASONS spec

## R — Requirements

`skills/plan/SKILL.md:9` hard-STOPs without an approved spec: *"If there is no
approved spec, STOP and tell the user to run `/flywheel:spec` first — do not plan
from a vague request."* That refusal is why a list handed in chat never becomes a
`.plan.md`, and therefore never reaches `check-task-closure.sh` (v0.70.0). The
friction is the cause of the gap, not the missing artifact — which is why this
spec adds **no new format and no new verifier**.

In scope: a guarded intake path that turns a handed list into an ordinary
`.plan.md`. Out of scope: a second artifact type, a second closure verifier, and
any change to what `check-task-closure.sh` grades.

## E — Entities

| Entity | Where | Note |
| --- | --- | --- |
| handed list | the owner's message | N items, numbered or not |
| list-plan | `.claude/flywheel/specs/<slug>.plan.md` | an ordinary plan, marked as intake |
| intake guard | `plan-route.sh` | decides whether the list may skip the spec |

## A — Approach

**The guard reuses the tier ladder instead of inventing a judgment call.** A list
may skip the REASONS spec **iff every item routes T1 or T2 and carries a runnable
check**. Anything that would route T3 — interface/architecture design,
concurrency, auth/secrets/data-migration, ambiguous requirements, 3+ modules — is
precisely what the spec exists to protect, so it STOPs exactly as today.

This makes the escape hatch self-limiting: it cannot be used for the work the
refusal was written to catch, and the criterion is machine-checkable against
`route-tiers.txt` rather than argued per case.

The rejected alternative is a new `/flywheel:intake` command. A second way to
produce a plan invites the shortcut the STOP exists to prevent, and costs a
README row, a help-map row and an invocation budget. The STOP becomes a **fork**
instead: same command, same contract, the guard living where the refusal already
lives.

**The rule inverts for a list-plan.** An ordinary plan must put its riskiest task
at the top tier. A list-plan asserts the opposite — *no task reaches the top
tier* — which is the intake criterion restated. `plan-route.sh` currently fails
any plan without a `risk: highest` task at top tier, so it must learn which of
the two rules applies.

## S — Structure

- `skills/plan/SKILL.md` — the STOP becomes a fork; the intake branch and its guard.
- `scripts/plan-route.sh` — recognize a list-plan; apply the inverted riskiest rule.
- `scripts/test-plan-route.sh` — arms for both rules and for the T3 refusal.
- `scripts/check-task-closure.sh` — **prerequisite, see Safeguards**: a task the
  ledger never recorded is PENDING, not FAIL.

## O — Operations

1. Closure gate learns PENDING (prerequisite — without it intake ships a red CI).
2. `plan-route.sh` recognizes a list-plan and inverts the riskiest rule.
3. `skills/plan/SKILL.md` forks instead of stopping, with the T3 refusal intact.
4. Telemetry: a list intake is a cycle and writes transition lines like any other.

## N — Norms

No new command, no new file format, no second verifier. The list-plan is an
ordinary `.plan.md` that `check-task-closure.sh` grades unchanged — that is the
entire payoff.

## S — Safeguards

- **A T3 item still STOPs.** The guard is the whole safety property; if it can be
  talked past, this spec has removed a protection rather than a friction.
- **PENDING is a prerequisite, not a nicety.** The loop commits a plan at
  approval, *before* the work. Every task's check then fails — a plan-only PR is
  red by construction. Intake makes that the common case rather than the rare
  one, so the closure gate must report a task with no transition line as PENDING
  and grade only tasks the ledger says ran. `check-route-honored.sh` already
  fails unrecorded tasks after its cutoff, so nothing is lost by not failing here.
- **An intake plan still carries checks.** A list whose items have no runnable
  check is not made deterministic by becoming a plan; it reports UNRUNNABLE, and
  the intake says so at the gate rather than implying coverage it lacks.
- Slug collision with an existing spec must refuse, not overwrite.

## Success metric

`bash scripts/test-plan-route.sh` green with arms for both riskiest rules and the
T3 refusal; `bash scripts/test-check-task-closure.sh` green with a PENDING arm; a
list-plan of all-T2 items lints clean while the same list with one T3 item is
refused by name; `bash scripts/check-task-closure.sh` exits 0 on a tree holding a
committed plan whose work has not started; full sweep green.
