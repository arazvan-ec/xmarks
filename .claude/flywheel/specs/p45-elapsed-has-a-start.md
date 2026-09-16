# Spec: P45 — the first transition has a start

**Slug:** `p45-elapsed-has-a-start` · **Created:** 2026-09-16 · **Backlog:** P45
**Status:** shipped as v0.57.0 — metric PASS. `run-cost.sh` over this cycle's
run reports all four cost fields at **full coverage, line 1 included**, with no
PARTIAL marker anywhere. No run in the repo's history had managed that.

**Prime:** P23 (`elapsed_s` as a proxy), P44 (the meter, and the probe that found
`duration_ms` in the hook payload), and the ledger entry *"a missing field is not
a zero"* — which is why this gap is visible as PARTIAL instead of being averaged
away.

## R — Requirements

`elapsed_s` is reconstructed from commit-time deltas. Counted across the repo:

| run | lines | line 1 has `elapsed_s` | coverage |
| --- | --- | --- | --- |
| p42-telemetry-has-an-owner | 5 | **no** | 4/5 |
| p43-hooks-run-on-flywheel | 4 | **no** | 3/4 |
| p44-read-volume-is-observed | 4 | **no** | 3/4 |

Not a coincidence and not sloppiness: a delta needs a previous commit, and the
first transition of a cycle has none. The method cannot ever measure line 1, so
every run in the repo is permanently PARTIAL by exactly one line. The same method
also fails outright where there is no repo — `work`'s own eval workdir is not a
git checkout, and its executor had to omit `commit` for that reason.

In scope:

1. `read-meter.sh --since <ts>` also prints `elapsed_s` — **`now - cut`**, the
   wall clock of the transition, exact rather than a floor when the line is
   written at the transition (which the P42 rule already requires).
2. `--since first` resolves the cut to the **earliest recorded call**, so the
   first transition of a cycle has a start at last. That start is a floor: a
   session may think before it calls a tool, and nothing observes that.
3. `work`'s cost rule cites both forms and stops naming commit deltas.

Out of scope: a busy-time proxy. `duration_ms` is in the payload and would give
tool-time, but it is a different quantity from wall clock and nothing reads it —
recording a field on speculation is what this repo's token discipline bans.

## E — Entities

- **cut** — either the previous transition's `ts`, or the earliest metered row
  when the caller passes `first`.
- **counter file** — unchanged; `ts` per row is already all this needs, so the
  row schema does not change and old counters stay readable.

## A — Approach

No new state. The meter already timestamps every call, and the reader already
takes a cut; `elapsed_s` is the arithmetic nobody had asked for. `first` is the
only new input, and it exists because the alternative — a cycle-start marker
written somewhere — is state that can go stale and drift from the run it labels.

**Honesty rules carried over unchanged.** No counter file → UNMEASURED for all
three fields, never a zero. The meter is the single source; a session that ran
unmetered says so rather than computing a number from a clock it did not observe.

## S — Structure

`scripts/read-meter.sh` (+ its test), one edit to
`skills/work/references/work-detail.md`, `upgrades/v0.57.0.md`, version bump.

## O — Operations

- T1 test-first: `elapsed_s` in the `--since` output; `--since first`; UNMEASURED
  still covers all three; an empty counter is not a zero-length run.
- T2 implement.
- T3 `work`'s cost rule.
- T4 release: eval before the bump, upgrade note, gates.

## N — Norms

Test-first. Terse code. Atomic commits, pushed per task. A `scripts/` change is a
release with an upgrade note. The `work` eval runs **before** the bump.

## S — Safeguards

- **Fail-open.** Unreadable or absent counter → UNMEASURED, exit 0, never a throw.
- **No schema change.** Existing counter files and existing telemetry stay valid.
- **`elapsed_s` keeps its meaning** — wall clock, not tool time. Nothing in the
  repo that already carries it needs reinterpreting.
- **No backfill.** The three runs missing line 1 stay missing it (P18).

## Success metric

```
bash scripts/test-read-meter.sh && bash scripts/check-telemetry.sh \
  && bash scripts/check-test-pairing.sh && bash scripts/test-docs-consistency.sh \
  && bash scripts/check-hook-parity.sh && bash scripts/check-invocation-budget.sh
```

Decisive clause, on this cycle's own data: `run-cost.sh` over this run reports
`elapsed_s` at **full coverage — every transition, line 1 included** — rather
than PARTIAL. No run in the repo's history has ever managed that.
