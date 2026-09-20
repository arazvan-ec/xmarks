# Spec: P50 — the meter names the read, not just the total

**Slug:** `p50-the-meter-names-the-read` · **Created:** 2026-09-17 · **Backlog:** P50
**Status:** shipped as v0.66.0 — metric PASS. 26 discovered `scripts/test-*.sh`
and 11 `check-*` gates green under an isolated `TMPDIR`; `check-release-bump.sh`
reports 0.63.0 → 0.66.0 against the real base. Decisive clause held with one
honest limit: the reader's window always ends **now**, so only T5 — the
transition whose window ended as the line was written — could carry `max_read`
and `by_tool`. The other five omit them rather than reconstruct them. First live
figures: `max_read=11,036` over 117 calls, `Bash` 198,191 of 206,266 bytes.

**Prime:** P40a/P40b (read volume measured, then the routing of reads **rejected
as unjustified, not disproven**), P44 (the meter), and the ledger entry *"keeping
the aggregate is not keeping the measurement"* — which named this exact gap and
could not close it.

## R — Requirements

Reads are the dominant cost in this loop and the ledger can only say so in
aggregate. Over the corpus: **1,475,873 bytes in against 372,942 out — 4.0×**.
P40b proposed routing the expensive ones behind an `extractor` agent and was
rejected for want of evidence; the ledger records exactly why it could not be
judged:

> the largest single read in 619 calls is bounded only to [4,898 ; 152,232]
> bytes, straddling P40b's 8 KB threshold by 18×

That bound is the whole problem. `read-meter.sh` **records** `tool` and `bytes`
per call in its state file and then throws both away at `--since`, summing to one
number. The measurement exists; only the aggregate survives.

In scope, three assertions:

1. **The largest single read is reported.** `--since` prints `max_read=<N>`, so
   "is there a fat read?" stops being a 18× interval and becomes a number.
2. **The total is attributed to the tools that caused it.** `--since` prints
   `by_tool=<Tool>:<bytes>/<calls>,…`, so a 150 KB transition can be read as one
   fat call or a hundred small ones — which is the difference between P40b's
   threshold being the right lever and the wrong one.
3. **A maximum is never summed.** `run-cost.sh` totals its fields; `max_read` is
   a maximum and must be carried as one, across a run and across the corpus.

Out of scope: acting on the answer. P40b stays the owner's decision; this cycle
supplies the evidence it was rejected for lacking, and says so rather than
reopening it.

## E — Entities

- **`max_read`** — the largest single `tool_response` recorded in the window. A
  floor like `bytes_in`: tool output only, never the conversation.
- **`by_tool`** — `{tool: {bytes, calls}}` over the window. A write tool appears
  with **0 bytes and a real call count**, exactly as P44 defined it: the call
  happened, the bytes never entered context.
- **window** — unchanged from P44: `--since <ts>` or `--since first`.

## A — Approach

Nothing new is measured. The state file already carries `{ts, tool, bytes}` per
call; the reader collapses it. This is a reporting change on data the meter has
been keeping since v0.56.0 — which is why it can ship without a single new hook.

`run-cost.sh` grows a second field kind. `FIELDS` are summed; `MAX_FIELDS` are
maxed, per run, per bucket and across the corpus, under the same per-FIELD
coverage rule: a transition that does not carry `max_read` leaves it UNMEASURED
rather than contributing a 0 that would drag no maximum but would fake coverage.

## S — Structure

- `scripts/read-meter.sh` + `scripts/test-read-meter.sh`
- `scripts/run-cost.sh` + `scripts/test-run-cost.sh`
- `skills/work/references/work-detail.md` — both fields in the line's shape.
- `.claude-plugin/plugin.json` → **0.66.0** · `upgrades/v0.66.0.md`
- `docs/research/improvement-proposals.md` — P50, and P40b's row gains the
  evidence it was waiting for.

## O — Operations

See the plan. T2 is the riskiest: the reader is a hook half and a reporting half
in one script, and breaking the hook half silences the meter everywhere.

## N — Norms

Test-first. Terse code. Atomic commits, pushed per task. Every plan task writes
its own transition line — P49's gate is now watching this cycle.

## S — Safeguards

- **The hook half must not change.** Its contract (silence, exit 0, never block a
  tool call) is what keeps a broken meter from breaking every session. The arms
  that cover it stay green untouched.
- **UNMEASURED survives the addition.** A window with no recorded call reports
  UNMEASURED for the new fields too — never `max_read=0`, which reads as "the
  largest read was nothing" instead of "nothing was measured".
- **A maximum is never summed.** Asserted directly: two runs of `max_read=100`
  roll up to 100, not 200.
- **A window that does not end now cannot be measured.** `--since` cuts at a
  timestamp and runs to the present, so a line written after the fact can
  difference `bytes_in`/`tool_calls` from two cumulative readings but cannot
  recover a maximum or a per-tool split. Those fields are then omitted, never
  reconstructed. A `--until` bound would close it and was deliberately left out
  of this cycle's assertions.
- **`by_tool` is not a numeric proxy.** `check-telemetry.sh` requires `cost` to
  carry at least one numeric value; a dict does not satisfy it, and the arm that
  proves a cost object of only `by_tool` still fails keeps that honest.

## Success metric

```
export TMPDIR="$(mktemp -d)"
for t in scripts/test-*.sh; do bash "$t" || echo "RED $t"; done
for g in scripts/check-*.sh; do bash "$g" || echo "RED $g"; done
bash scripts/read-meter.sh --since first
```

Decisive clause: this cycle's own transition lines carry `max_read` and
`by_tool`, and the number that P40b's rejection called unbounded — the largest
single read — is reported as a value on a real run rather than an interval.
