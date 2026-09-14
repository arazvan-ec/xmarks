# Spec: P40a — the loop measures what it reads

**Slug:** `p40a-read-volume-proxy` · **Created:** 2026-09-14 · **Backlog:** P40a
**Status:** shipped as v0.50.0 — metric PASS (19/19 run-cost cases, five docs
gates green, and the decisive clause: a pre-P40a run prints `bytes_in UNMEASURED`
rather than totalling it as 0). Built in the same session as P41 once delegation
became honorable, not a fresh one.
**Prime:** P23 (`.claude/flywheel/specs/p23-cycle-cost.md`) — this extends its
line schema and inherits its proxy-honesty rule verbatim; P18 (evidence-gated
compounding), which is why no token field may appear; the Spotify Portal article
(2026-09), which is the *reason* this measurement is wanted but supplies none of
its mechanism.

## R — Requirements

P23 made the cycle's **writing** measurable: `bytes_out`, `tool_calls`,
`elapsed_s`. It left the other half dark. A cycle that reads twelve files to
change one line and a cycle that reads one file look identical in the telemetry,
so the repo currently cannot answer the question P40b exists to answer — *is
read volume a real cost peak here?* — and CLAUDE.md's own convention names only
the expensive-per-token half (output), never the expensive-by-volume half.

In scope:

1. A fourth cost proxy, **`bytes_in`** — bytes of file/command content this
   transition pulled into context. Mechanically observable: the session can
   size what it read.
2. **Field-level coverage.** Every run written before this schema carries a
   `cost` object with three fields and no `bytes_in`. Those lines are *measured*
   for the three and **unmeasured for `bytes_in`** — never folded in as 0. P23
   solved this for a whole missing object; a missing *field* is the same trap one
   level down, and the one that bites first, because every existing baseline has it.
3. A delta whose `bytes_in` row is **refused, not printed, when either side has
   no coverage** for it. A `-100%` against a baseline that never recorded the
   field is a lie the tool must not be able to tell.
4. Per-route buckets carry `bytes_in` under the same coverage rule.
5. **No `tokens` field, ever** (P18) — the existing warning stands unchanged.
6. The schema's four documented sites and the README say `bytes_in` too, or the
   data and its contract disagree.
7. Developed test-first, red→green (CLAUDE.md dev-loop rule).

Out of scope — this spec buys the instrument, not the intervention:

- The `extractor` agent and the size threshold in `read-prime.sh` (that is P40b,
  and it is not approved to build until this instrument reports).
- Any token count, estimate or conversion.
- Any change to what `bytes_out` means.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| line schema | `cost: {bytes_out, bytes_in, tool_calls, elapsed_s}` | `skills/loop/SKILL.md`, `skills/work/references/work-detail.md`, `skills/run/references/ledger-and-extensions.md`, `skills/process/references/contract-template.md` |
| coverage | per-field count of lines that carry the field | `scripts/run-cost.sh` |
| comparison tool | totals, per-route buckets, two-run delta | `scripts/run-cost.sh` |
| paired test | the coverage cases, red first | `scripts/test-run-cost.sh` |
| docs | the fourth proxy and what it is not | `README.md`, `upgrades/v0.50.0.md` |

## A — Approach

Extend the existing `cost` object with a fourth key and make the script's
accounting **per-field instead of per-line**. Today `measured` is one counter for
the whole object; it becomes a count per field, and every report line states its
own coverage.

Rejected alternative: a separate `read` object (`{files, bytes}`). It carries
more detail but makes every existing consumer branch on two shapes, and the
detail is exactly what P40b would need — not what P40a must prove. One key on
the object the tooling already parses is the smaller diff and the honest floor.

Trade-off accepted: `bytes_in` undercounts. Content re-entering context (a file
read twice, a diff echoed back) is charged once per read, and nothing charges for
the conversation itself. It is a **floor on read volume**, and the script says so
in the same breath it prints it — the P23 rule that a proxy is labelled wherever
it surfaces.

## S — Structure

`scripts/run-cost.sh` is the only logic change: `FIELDS` gains `bytes_in`,
`load()` returns `coverage[field]` alongside `totals`, `report()` prints coverage
where it is partial, and the delta skips any field without coverage on both
sides. The four schema sites and the README are text-only. No new script, no new
hook, no widened permission surface.

## O — Operations

1. Red: coverage cases in `scripts/test-run-cost.sh` (totals, partial coverage,
   refused delta, route bucket, back-compat on a pre-P40 file).
2. Green: per-field accounting in `scripts/run-cost.sh`.
3. Schema text at the four sites + README, inside the invocation budget.
4. Bump to `0.50.0` + `upgrades/v0.50.0.md` (`requires-action: false`).
5. P40 entry (a and b) in `docs/research/improvement-proposals.md`.
6. CLAUDE.md: name the volume half of the token convention.

## N — Norms

Terse code, no ceremonial comments (CLAUDE.md). Match `run-cost.sh`'s existing
voice: comments state the constraint that made the code that shape. Test-first,
one paired test per script (`check-test-pairing.sh`). Every skill/script change
is a release with an upgrade note. Atomic commits, pushed per task (P28).

## S — Safeguards

- **The zero trap is the whole risk.** A pre-P40 baseline totalling `bytes_in: 0`
  would make every P40b comparison show a fabricated improvement — the exact
  failure mode P23's `unmeasured` rule exists to prevent, and the reason
  requirement 3 refuses the row rather than printing it.
- **No behavior change to the three existing fields.** Their totals, deltas and
  route buckets must read identically before and after; the existing tests stay
  green untouched.
- Fail-open unchanged: malformed lines skipped and counted, missing file exits 2.
- `bytes_in` never travels to any external service; it is a local integer.
- Invocation budget: the skill edits are word-scale; `check-invocation-budget.sh`
  is the gate, and `loop` has ~326 B of headroom under the 4800 default.

## Success metric

One command, green:

```
bash scripts/test-run-cost.sh \
  && bash scripts/check-test-pairing.sh \
  && bash scripts/check-invocation-budget.sh \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/test-install-vendored.sh \
  && for f in skills/loop/SKILL.md skills/work/references/work-detail.md \
              skills/run/references/ledger-and-extensions.md \
              skills/process/references/contract-template.md README.md; do \
       grep -q bytes_in "$f" || exit 1; done \
  && printf '%s\n' \
       '{"ts":"2026-07-30T10:00:00Z","task":"t1","state":"completed","cost":{"bytes_out":100,"tool_calls":2,"elapsed_s":5}}' \
       > /tmp/p40a-old.jsonl \
  && bash scripts/run-cost.sh /tmp/p40a-old.jsonl | grep -qi 'bytes_in.*unmeasured'
```

The last clause is the one that matters: a pre-P40 run must report `bytes_in` as
unmeasured, not as 0.
