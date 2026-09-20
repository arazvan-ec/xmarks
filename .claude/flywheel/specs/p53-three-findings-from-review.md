# Spec: P53 — three findings from review, each reproduced first

**Slug:** `p53-three-findings-from-review` · **Created:** 2026-09-20 · **Backlog:** P53
**Status:** in progress.

**Prime:** P49 (`check-route-honored.sh`), P50 (the meter's new fields), and the
ledger entry *"asserting a step is PRESENT says nothing about what it operates
on"* — which is what two of these three are.

## R — Requirements

Three P2 findings from Codex on PR #91, against code this session wrote. Each was
**reproduced on a fixture before anything was changed**; all three hold.

| # | finding | reproduced |
| --- | --- | --- |
| 1 | a plan with no run directory is never inspected | **7 of 19** plans in this repo are in exactly that state |
| 2 | the `+delegate` suffix does not participate in the comparison | plan buys `haiku/low+delegate`, record says `haiku/low` → gate **exits 0, "honored"** |
| 3 | the inclusive `>= since` boundary double-counts the boundary second | `--since 10:00:00Z` reports `max_read=50000` from a call that belonged to the *previous* transition |

Finding 2 is the worst of the three in this repo specifically: `+delegate` is the
thing P41 and P49 exist to track, and the gate was reporting a lost delegation as
honored. Finding 3 lands on the two fields P50 had just added, where a maximum
inherited from the previous transition is not a rounding error but a wrong
answer to *"how big was the biggest read?"*.

Three assertions:

1. **A plan with no run directory is reported**, never silently skipped.
2. **A recorded route that drops a planned `+delegate` is a finding**, not a
   match — fatal from the cutoff on, like any other unrecorded deviation.
3. **An explicit `--since <ts>` is exclusive.** `--since first` stays inclusive:
   it names the earliest recorded call, and excluding it would drop the one call
   a cycle's first transition exists to measure.

## E — Entities

- **unrecorded delegation** — the plan's route carries `+delegate` and the
  recorded route does not. Not "above" or "below" — a different axis, so it is
  reported in its own words rather than folded into the tier comparison.
- **extra delegation** — the converse: recorded `+delegate` the plan did not ask
  for. A notice. Paying for less than you were allowed is not a defect.
- **uncompared plan** — a plan whose slug has no run directory, or an empty one.

## A — Approach

**Finding 1 is a notice, deliberately, and the reason matters.** Codex proposed
treating it as unusable or failed input. The duty it names already has an owner:
`check-telemetry.sh` **fails** a spec with no telemetry, and the 7 plans in this
state are precisely the ones its baseline exempts *with a reason*. Failing here
too would contradict a decision already taken and redden seven cycles that
shipped before the duty existed. What was genuinely missing is that the route
gate said nothing at all about them — so it now names them and counts them, and
the fatal duty stays with the gate that owns it.

**Finding 2 is fatal**, post-cutoff, because nothing in the corpus trips it: the
three `+delegate` transitions this session recorded all carry the suffix, and the
pre-cutoff delegate-planned tasks have no lines to compare at all. A rule with no
grandfathering needed is a rule that can be strict.

**Finding 3 splits the two cuts.** `>` for a timestamp the caller supplies, `>=`
for the one `first` derives. One boolean, set where `since` is resolved, so the
two cannot drift.

## S — Structure

- `scripts/check-route-honored.sh` + `scripts/test-check-route-honored.sh`
- `scripts/read-meter.sh` + `scripts/test-read-meter.sh`
- `skills/work/references/work-detail.md` — the boundary is exclusive, so
  passing the previous transition's `ts` is now exactly right rather than
  approximately right.
- `.claude-plugin/plugin.json` → **0.69.0** · `upgrades/v0.69.0.md`
- `docs/research/improvement-proposals.md` — P53.

## O — Operations

See the plan.

## N — Norms

Test-first, and **reproduced before fixed**: each arm is written from the fixture
that demonstrated the finding, not from the finding's description. Terse code.
Atomic commits, pushed per task. Every plan task writes its own transition line.

## S — Safeguards

- **`--since first` must not lose its first call.** The arm that covers it
  predates this change and stays green untouched; the exclusive boundary applies
  only to a caller-supplied timestamp.
- **Finding 1 must not redden seven baselined cycles.** Checked against the real
  tree: 7 plans have no run directory and every one of their specs is exempt in
  `telemetry-baseline.txt` with a reason.
- **Finding 2 must not redden the corpus.** Checked: no pre-cutoff line pairs a
  `+delegate` plan task with a suffix-less record, because those tasks have no
  lines at all.
- **The hook half of the meter stays untouched.** Only the reader's cut changes.
- **Extra delegation is not a failure.** Only the absence of a delegation the
  plan bought is.

## Success metric

```
export TMPDIR="$(mktemp -d)"
for t in scripts/test-*.sh; do bash "$t" || echo "RED $t"; done
for g in scripts/check-*.sh; do bash "$g" || echo "RED $g"; done
```

Decisive clauses, each on the fixture that reproduced the finding:

1. The gate names the 7 uncompared plans on the real tree, and stays green.
2. `haiku/low` recorded against a planned `haiku/low+delegate` is **red**, and
   green once the record carries the suffix or says why it does not.
3. `--since <the previous transition's ts>` no longer reports that transition's
   50,000-byte call as this one's `max_read`.
