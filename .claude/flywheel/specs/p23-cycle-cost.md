# Spec: P23 — cycle-cost telemetry (the loop measures its own cost)

**Slug:** `p23-cycle-cost` · **Created:** 2026-07-30 · **Backlog:** P23
**Status:** shipped as v0.35.0 — metric PASS; eval gate run 2026-07-30 across
`work`/`process`/`run`: 8/8 evals, 57/57 assertions, with the `cost` object
verified on real run telemetry (14/14, 14/14 and 15/16 transitions). The bump was
held until that gate ran, because this spec changes
`skills/{work,loop,run,process}/SKILL.md` and CLAUDE.md gates skill changes on
running their evals first.
**Prime:** P23 section in `docs/research/improvement-proposals.md`; the
2026-07-30 measurement-audit entry; P16 (telemetry ledger) and v0.30.0
(two-tier telemetry) — this extends their line format rather than inventing one;
P18 (evidence-gated compounding), which is *why* the token field is banned.

## R — Requirements

v0.30.0 shipped four changes whose entire justification is output-token cost and
only one of them — the description trim — can be checked afterwards. The
telemetry JSONL already records *what* happened at every transition and never
*what it cost*, so the next optimization release has no way to prove itself and
a regression that doubles output is invisible.

1. Every transition line carries a `cost` object with three
   **mechanically observable** fields: `bytes_out` (bytes this transition wrote
   to files), `tool_calls` (tool calls made during it), `elapsed_s` (whole
   seconds since the previous transition's `ts`).
2. **No `tokens` field, ever.** A session cannot observe its own token usage
   accurately; a guessed number is exactly the unverifiable evidence P18 exists
   to keep out of the ledger. The owner chose proxies over a token field
   deliberately, and the tooling enforces it: `run-cost.sh` warns loudly when a
   line carries `tokens`.
3. The fields are **labelled proxies wherever they surface** — the HTML report's
   cost block and the script's output both say so. A proxy silently presented as
   cost is the same failure as a fabricated token count.
4. `scripts/run-cost.sh <run.jsonl> [baseline.jsonl]` totals one run and, given
   two, prints the delta per field with sign and percentage — so "cheaper" is a
   number, not a claim.
5. Lines that predate the schema (no `cost` object) are counted as
   **unmeasured and reported as such**, never as zero. Silently treating a
   missing field as 0 would make any old run look free and flatter every
   comparison against it.
6. Developed test-first, red→green, per the CLAUDE.md dev-loop rule.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| line schema | `cost: {bytes_out, tool_calls, elapsed_s}` | `skills/{work,loop,run,process}/SKILL.md` |
| close-time summary | proxy-labelled cost block in the rendered report | `skills/{loop,run}/SKILL.md` |
| comparison tool | totals + two-run delta | `scripts/run-cost.sh` |
| paired test | 8 scenarios over synthetic JSONL | `scripts/test-run-cost.sh` |
| docs | what the proxies are and what they are not | `README.md` |

## A — Approach

Extend the existing line rather than adding a second file: the JSONL is already
appended once per transition, so the cost object rides along at no extra write.
`elapsed_s` is derivable from consecutive `ts` values, but writing it explicitly
keeps the script simple and survives out-of-order lines.

`run-cost.sh` parses with `python3` (already a repo dependency) rather than
`awk` — JSON with a nested object is not an awk job, and robustness against
malformed lines is a requirement, not a nicety.

Percentages are printed only when the baseline field is non-zero; a delta
against zero prints as absolute plus `n/a`, because "+∞%" is noise.

Rejected: a `tokens` field (requirement 2 — the owner's explicit choice);
counting characters of chat output as a proxy (unobservable from inside the
session); a separate cost file per run (doubles writes to save nothing); making
the script fail on unmeasured lines (they are legitimate history — v0.16.0
through v0.32.0 runs have no cost object; report, don't reject).

## S — Structure

- `skills/work/SKILL.md` — transition-line schema gains `cost`
- `skills/loop/SKILL.md` — schema + the close/gate render gains a cost block
- `skills/run/SKILL.md` — schema + final-report render gains a cost block
- `skills/process/SKILL.md` — the contract template's Progress-reporting section
  documents the cost fields for generated contracts
- `scripts/run-cost.sh` + `scripts/test-run-cost.sh` (new, executable)
- `README.md` — the "Live progress" paragraph gains the cost-proxy sentence and
  the script
- `.claude-plugin/plugin.json` → **0.35.0** · `upgrades/v0.35.0.md`
  (`requires-action: false`), added once the eval gate was green

## O — Operations

1. Write `test-run-cost.sh` first; run it, see it fail with the script absent.
2. Write `run-cost.sh`; green.
3. Add the `cost` object to the four skills' line schema; add the proxy-labelled
   cost block to the two renderers and the contract template.
4. README sentence + script mention.
5. Repo check suite. Stop before the bump; record the pending eval gate.

## N — Norms

The cost object is three integers — it must not grow into a place to stash prose.
Fail-open like the rest of telemetry: a transition that cannot compute a field
omits the whole `cost` object rather than guessing, and the script reports it as
unmeasured. Writing-token discipline applies to the schema itself: three keys,
no nesting beyond one level.

## S — Safeguards

- **The token ban is enforced, not just documented** (requirement 2): the script
  warns on a `tokens` key, so re-introducing one is visible in tool output.
- **Unmeasured ≠ free** (requirement 5): old runs are reported as unmeasured, so
  a comparison can never silently credit the new run with an improvement.
- **Proxy labelling is mandatory** (requirement 3) in both surfaces, so nobody
  reads `bytes_out` as a token count later.
- **No new dependency**: `python3` is already required by the test suite.
- **No bump without the eval gate** — `work`, `process` and `run` all have evals.

## Success metric

One command, exit 0 = PASS (what it cannot assert: that the proxies correlate
with real token spend — that needs two comparable real cycles, which is the
first thing to do once this is released):

```bash
bash scripts/test-run-cost.sh \
  && printf '%s\n' \
    '{"ts":"2026-07-30T10:00:00Z","task":"t1","state":"completed","cost":{"bytes_out":100,"tool_calls":2,"elapsed_s":5}}' \
    '{"ts":"2026-07-30T10:00:10Z","task":"t2","state":"completed","cost":{"bytes_out":50,"tool_calls":1,"elapsed_s":10}}' \
    > /tmp/p23-metric.jsonl \
  && bash scripts/run-cost.sh /tmp/p23-metric.jsonl | grep -q 150 \
  && bash scripts/run-cost.sh /tmp/p23-metric.jsonl | grep -qiE 'prox(y|ies)' \
  && for s in work loop run process; do grep -q 'bytes_out' "skills/$s/SKILL.md" || exit 1; done \
  && for s in work loop run process; do grep -q 'tool_calls' "skills/$s/SKILL.md" || exit 1; done \
  && ! grep -q '"tokens"' skills/loop/SKILL.md \
  && grep -q 'run-cost' README.md \
  && bash scripts/check-test-pairing.sh \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/test-install-vendored.sh
```
