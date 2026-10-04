# P72 T0b — the Resource Committee picks the model

**Status:** signed 2026-10-04 (owner: "quiero que todo proceso se ejecute con el modelo y esfuerzo más óptimo al inicio, por ejemplo Sonnet 5.5, pero que … suba o baje el modelo en base a lo que se pide" → "sí, mételo antes de T1").

## R — Requirements

Plans already route tasks to `haiku/low`, `sonnet/medium`, `opus/high`, but a
session cannot switch its own model: check-route-honored records the gap as
"session model; not switched" (p69 T3, p70 T2/T4/T5). Mods can close it:
`turn.step` lets a hook rewrite `model` and `effort` of each request.

- In: a mod `mods/resource-committee/` that starts every session at
  `sonnet/medium`, classifies each idle prompt with Haiku
  (`mechanical | routine | judgment`) and routes the turn's main-thread steps
  accordingly; a `/committee` command to show the decision or pin a tier;
  `models.md` refreshed to the 2026-09-25 model table.
- Out: plan-task routes (phase 2, once T1 can measure cost); rewriting
  subagent steps (they carry their own `model`); Fable (caller-named only, per
  `route-tiers.txt`).

## E — Entities

| Tier | Route | When |
| --- | --- | --- |
| mechanical | `sonnet/low` | rename, move, format, run-and-report |
| routine | `sonnet/medium` | default; everyday coding |
| judgment | `opus/high` | design, spec, hard debugging, security, ambiguity |

Haiku is not a main-thread tier: 200K context and no effort control (models.md),
and the API guidance is to try the stronger model at lower effort before a
cascade. It stays available by explicit pin.

## A — Approach

Decide once per idle prompt (`prompt.submit` without `turnId`), never mid-turn:
caches are model-scoped and a mid-conversation effort change also invalidates
the messages cache, so a switch per step would cost more than it saves. A
slash command keeps the current tier. Subagent steps (`e.agentId`) pass
untouched. A pin overrides classification until `/committee auto`.

## S — Success metric

`bash scripts/check-mods.sh origin/main resource-committee` green, with tests
proving: default sonnet/medium; judgment → opus/high on the next steps;
mechanical → sonnet/low; mid-turn prompt does not re-decide; subagent step
untouched; pin overrides; slash command keeps tier.

## O — Operations

New mod at 0.1.0, listed in marketplace.json; flywheel 0.85.0 for the
`skills/route/references/models.md` refresh.

## N — Notes

Model ids are first-party (`claude-sonnet-5-5`, `claude-opus-5-5`,
`claude-haiku-4-5`); on Bedrock/Vertex they differ — a known limit of 0.1.0.

## S — Safeguards

The classifier failing (undefined) keeps the current tier, never escalates.
