# Spec: P42 — the telemetry duty gets an owner that runs

**Slug:** `p42-telemetry-has-an-owner` · **Created:** 2026-09-15 · **Backlog:** P42
**Status:** shipped as v0.54.0 — metric PASS, probe confirmed (an uncovered slug
exits 1 and is named), and the `work` release gate green: eval 1 graded 7/7 with
the decisive observation alongside it — a STANDALONE invocation wrote four
transition lines, the behavior P29 recorded as absent on 2026-09-09. This cycle's
own telemetry is the repo's first conforming run.
**Prime:** P23 (`cost` proxies) and P40a (`bytes_in`) — the schema this makes real;
P29 / `.claude/flywheel/specs/loop-telemetry-eval.md`, where this exact failure was
observed on 2026-09-09 and filed as an eval-coverage problem; P41, for the habit
of proving a duty runs instead of assuming it.

## R — Requirements

The loop's per-cycle telemetry has **zero conforming instances in this repo's
entire history**. Not "it stopped" — it never started. Diagnosis, with dates:

1. `skills/work/SKILL.md:10` gates the duty: *"Inside a `/flywheel:loop` cycle,
   append one JSON line per transition…"*.
2. The only unconditional owner is `skills/loop/SKILL.md`, whose body loads only
   when `/flywheel:loop` is invoked.
3. CLAUDE.md has instructed every session since 2026-07-29 (`10a4e43`) to run
   `spec → work → verify`. **That sequence never names `loop`.** So the owner
   never loads, `work`'s clause self-disables on its own precondition, and
   nothing is written. No error, no trace.

Ten consecutive cycles shipped with no telemetry — P33, P35–P39, P14a, P14b,
P40a, P41 — including P23 itself, the cycle that added `cost` to the schema.
`run-cost.sh` has been a reader with nothing to read since v0.35.0; its tests
pass on synthetic JSONL, so it has always been green.

In scope:

1. **Ungate the duty.** `work` appends its transition line whenever it runs, not
   only inside a `/flywheel:loop` cycle. The duty moves to the skill that is
   actually invoked.
2. **A gate that notices.** `scripts/check-telemetry.sh`, wired into CI:
   - **Conformance** — every `.jsonl` under `.claude/flywheel/runs/` carries the
     contract's keys and never a `tokens` key.
   - **Coverage, as a ratchet** — every spec slug in `.claude/flywheel/specs/`
     must have conforming telemetry unless it is named in
     `scripts/telemetry-baseline.txt` with a reason. A new spec therefore demands
     telemetry by default; silencing one is a visible line in the diff.
3. The ten historical debts and the design-note specs go in the baseline, each
   with its reason. **No backfill**: inventing telemetry for a cycle nobody
   measured is precisely the fabricated evidence P18 exists to keep out.

Out of scope:

- Naming `/flywheel:loop` in CLAUDE.md (option B). Not taken: it depends on every
  session remembering, and the repo already carries an argument against invoking
  the chain (P35: six bodies, 24,529 B).
- Rendering the HTML tier from the JSONL. `loop` still owns that at gates.
- Any retroactive `runs/` file.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| the duty | one JSON line per transition, ungated | `skills/work/SKILL.md` |
| conformance + coverage | the gate | `scripts/check-telemetry.sh` (+ paired test) |
| the debts | slug → reason | `scripts/telemetry-baseline.txt` |
| CI | the gate runs on every push | `.github/workflows/validate-plugins.yml` |

## A — Approach

Move the duty to the skill that runs, and put a ratchet behind it. The baseline
is inverted on purpose: it lists what is **exempt**, so a new cycle is covered by
default. A list of what is *expected* would have the same failure mode as the
rule it replaces — it needs someone to remember.

Rejected: option B (CLAUDE.md names `loop`) for the reason above; and a gate that
requires telemetry with no baseline, which would fail red on ten historical
cycles and be silenced with `SKIP=`, turning a debt into a habit.

Trade-off accepted: a baseline with ~14 entries is a large opening debt. That is
the honest size of it — every entry is a cycle that shipped unmeasured.

## S — Structure

`skills/work/SKILL.md` loses six words (the gating clause) — a net reduction
against the invocation budget. `scripts/check-telemetry.sh` + its paired test are
new. `scripts/telemetry-baseline.txt` is data. One CI step. No new hook, no new
permission surface.

## O — Operations

1. Red: `scripts/test-check-telemetry.sh` — conformance failures, a `tokens` key,
   an uncovered spec, a baselined spec passing, a malformed baseline.
2. Green: `scripts/check-telemetry.sh`.
3. `scripts/telemetry-baseline.txt` with every current debt and its reason.
4. Ungate `work`; confirm the budget still holds.
5. CI wiring, README, bump + upgrade note.
6. **Release gate**: run `work`'s eval (CLAUDE.md requires it for a `work`
   behavior change) before the bump.

## N — Norms

Test-first for the script (CLAUDE.md). Terse code. Atomic commits, pushed per
task (P28). Every `skills/`/`scripts/` change is a release with an upgrade note.
A `work` behavior change is eval-gated before the version moves.

## S — Safeguards

- **No fabricated telemetry.** The baseline records absence; it never invents a
  file. A cycle that shipped unmeasured stays visibly unmeasured (P18).
- **Ungating must not leak into fixtures.** `work` runs standalone inside eval
  fixtures; if the ungated duty writes there, `check-fixture-leaks.sh` is the
  gate that must stay green, and the eval graders must still pass.
- **Fail-open is preserved in the skill, not in CI.** The skill still says
  reporting never blocks the work — a cycle must not die over a telemetry line.
  The gate is what makes the omission visible afterwards, which is the half that
  was missing.
- The baseline is a debt list, not a config: each entry carries its reason, and
  removing an entry is the only way to pay it.

## Success metric

```
bash scripts/test-check-telemetry.sh \
  && bash scripts/check-telemetry.sh \
  && bash scripts/check-test-pairing.sh \
  && bash scripts/check-invocation-budget.sh \
  && bash scripts/check-fixture-leaks.sh \
  && ! grep -q 'Inside a `/flywheel:loop` cycle' skills/work/SKILL.md
```

plus the decisive clause, run as a probe: a spec slug that is **neither**
baselined **nor** backed by conforming telemetry makes `check-telemetry.sh`
exit 1 and name the slug. Without that, the gate cannot notice the next silence.
