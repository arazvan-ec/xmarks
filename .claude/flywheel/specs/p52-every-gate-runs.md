# Spec: P52 — a gate in the tree is a gate CI runs

**Slug:** `p52-every-gate-runs` · **Created:** 2026-09-20 · **Backlog:** P52
**Status:** shipped as v0.68.0 — metric PASS. 27 discovered `scripts/test-*.sh`
and 12 `check-*` gates green under an isolated `TMPDIR`; `check-release-bump.sh`
reports 0.63.0 → 0.68.0 against the real base. Decisive clause held: the gate
was **red on the tree as it stands**, naming `check-supply-chain-pin.sh` (and
itself, not yet wired), and **green once both were wired** — parity now reports
12 of 12 gates invoked across 3 workflow files. The defect was proven to exist
before it was fixed.

**Prime:** P38/P41 (`check-hook-parity.sh`, `check-agent-parity.sh` — the same
shape, one level over), and the two ledger entries this is about: *"a gate can be
green, correct, and never run"* and *"the gate list you were handed is not the
gate set CI runs"*.

## R — Requirements

CI runs two kinds of check in two different ways. `scripts/test-*.sh` is
**discovered** by a glob, with a comment above it explaining exactly why — *"so a
new one cannot sit in the tree never executed (which is what happened to
test-run-cost.sh for four releases)"*. The `check-*.sh` gates, six lines below
that comment, are a **hand-written list of steps**.

The failure the comment describes has already happened again, to the other half:

> `scripts/check-supply-chain-pin.sh` — whose own header calls it *"the only
> Critical in the pillar-2 threat model"* — **is invoked by no workflow.** It
> appears in `.github/workflows/` exactly twice, both times inside a comment.

It has a test, it passes, it has been green in every local sweep, and it has
never once run in CI. Nothing is wrong with the gate; nothing was ever wired.

In scope, two assertions:

1. **Every `scripts/check-*.sh` in the tree is invoked by a workflow.** A gate
   nobody runs fails this one.
2. **Every gate a workflow invokes exists in the tree.** A typo or a deleted
   script fails this one — the converse, so a green parity cannot be bought by
   renaming a step.

Out of scope, deliberately: **replacing the hand-written list with a loop.** Two
of the gates take the merge base as an argument (`check-test-pairing.sh`,
`check-release-bump.sh`) and a naive glob would call them without it, leaving
them green having compared nothing — which is this ledger's oldest mistake
wearing a different hat. Named steps also carry per-gate annotations in the CI
UI. The list is not the defect; the list being **unchecked** is.

Also out of scope: a per-gate exception list. Nothing in the tree needs one
today, and an escape hatch built before a case exists is the speculative block
CLAUDE.md bans. The env skip every other gate has is enough.

## E — Entities

- **invocation** — the gate's path appearing in a workflow **outside a comment**.
  A line whose first non-space character is `#` is a mention, not a call; both
  of `check-supply-chain-pin.sh`'s appearances are exactly that, which is why
  the naive grep says it is wired and the gate must not.
- **workflow** — any `.github/workflows/*.yml`. A gate wired in *any* of them
  counts: `flywheel-update.yml` is as real as `validate-plugins.yml`.

## A — Approach

The repo already has this shape twice — `check-hook-parity.sh` asserts what
`hooks.json` declares is registered, `check-agent-parity.sh` does it for agents.
This is the third: what the tree ships must be what CI runs.

The comment-stripping is the whole subtlety, and it is why the gate is written
rather than a grep in a workflow step: the only evidence that the defect exists
is that two mentions look like invocations to anything that does not strip them.

## S — Structure

- `scripts/check-ci-gate-parity.sh` + `scripts/test-check-ci-gate-parity.sh`
- `.github/workflows/validate-plugins.yml` — wire `check-supply-chain-pin.sh`
  (the live hole) and the new gate (so it covers itself).
- `.claude-plugin/plugin.json` → **0.68.0** · `upgrades/v0.68.0.md`
- `docs/research/improvement-proposals.md` — P52, and P49's second open question
  closed.

## O — Operations

See the plan.

## N — Norms

Test-first. Terse code. Atomic commits, pushed per task. Every plan task writes
its own transition line — P49's gate is watching.

## S — Safeguards

- **A mention is not an invocation.** Asserted directly with a fixture whose only
  reference to the gate is a comment line: the arm is red if the gate counts it.
- **Wiring an unwired gate must not break CI.** `check-supply-chain-pin.sh` is
  run standalone first and exits 0 on the tree as it stands; a gate that is red
  when finally wired would be a bigger problem than the one being fixed, and the
  order here is deliberate.
- **The converse or nothing.** Asserting only "every gate is wired" lets a
  workflow invoke `scripts/check-nonexistent.sh` and stay green. Both directions
  or the parity claim is half a claim.
- **The gate covers itself.** It is wired in the same change, so a future edit
  that unwires it fails on its own rule.

## Success metric

```
export TMPDIR="$(mktemp -d)"
for t in scripts/test-*.sh; do bash "$t" || echo "RED $t"; done
for g in scripts/check-*.sh; do bash "$g" || echo "RED $g"; done
```

Decisive clause, on the real tree rather than a fixture: the gate is **red on the
tree as it stands**, naming `check-supply-chain-pin.sh` and nothing else, and
**green once that gate is wired** — the defect proven to exist before it is
fixed, not asserted afterwards.
