# Spec: P49 — a session pays for its own length, and the loop has no way to stop

**Slug:** `p49-the-session-pays-for-its-length` · **Created:** 2026-09-17 · **Backlog:** P49
**Status:** shipped as v0.65.0 — metric **PASS** (35/35 `scripts/{test,check}-*.sh`
green under an isolated `TMPDIR`; `claude plugin validate . --strict` green; the
budget's six assertions and the env-cap assertion each watched red first).

**Prime:** `scripts/read-meter.sh` (P44 — the accumulator this reads);
`skills/debug/SKILL.md` steps 3–4; `docs/research/improvement-proposals.md` P40b
(*"stays unapproved until real runs say whether read volume is a peak here"* —
this is that run, and it says the peak is not volume but **position**).

## R — Requirements

1. **The meter says when to stop.** Past a byte budget of accumulated tool
   response, the `PostToolUse` hook emits an advisory to write a handoff and end
   the session. Once per multiple of the budget, never once per call.
2. **The advisory is a read, not a measurement.** It must not add a call or a
   byte to what `--since` reports.
3. **The budget is movable and disablable.** `FLYWHEEL_CONTEXT_BUDGET_BYTES`;
   `0` disables; a typo falls back to the default rather than disarming it.
4. **Debug suspends when the evidence is out of reach.** Step 3 names the move
   for a log that lives on a device, in production, or behind a person: commit
   the instrumentation as instrumentation, say what it will discriminate and
   what the suite structurally cannot, end the session.
5. **The two exits taken instead of it are banned by name** — a second
   instrumentation round with nothing learned between them, and raising effort
   or tier to compensate for a missing discriminator.
6. **A tool response larger than the env-var cap is counted.**

## E — Entities

The measured session: 2h40m, 21,404,993 cache-read tokens, 456,818 cache-write,
120,280 output, 4,938 input, $18.30. Context reached 279,203 tokens. Output: 10
commits over 3 merged PRs — 4 instrumentation, 3 documentation, 3 candidate
fixes, 0 verifications. The cost model that decomposes it reproduces that bill
and two other sessions' to within 0.3%.

## A — Approach

**The finding is that volume is the wrong axis.** P40b proposed routing large
reads through an extractor and was rejected as unjustified. This run says why it
would not have paid: 178 tokens re-read per token produced, and **58% of the
bill** is not any single read but the *re-reading* of everything already there.
The first call in that session re-read ~30K tokens and the last re-read 279,203
— same work, nine times the price, for nothing but its position in the
transcript. The identical call sequence split across three chained sessions
costs 9.9M cache-read tokens against 21.3M. No amount of reading less reaches
that; only ending the session does.

So the lever is the **handoff**, and all three findings are it: end at a budget
(cost), end when the evidence must come from outside (a device bug), end instead
of raising effort (no discriminator). The first is mechanical, the other two are
rules, because no hook can see whether a hypothesis has evidence behind it.

## S — Structure

- `scripts/read-meter.sh` — the advisory, in the script that already owns the
  accumulator. Its header states the reason two halves live in one file (a split
  would let the derivation drift); a third half that reads the same total is the
  same argument.
- `scripts/test-read-meter.sh` — 7 new assertions, 24 total.
- `skills/debug/SKILL.md` — step 3's suspend, two bans. Body 1,679 → 2,364 B,
  under the 4,800 default.

## O — Operations

Nothing to run. The budget is on by default in any repo whose vendored copy
carries `read-meter.sh` on `PostToolUse` — which is the shipped wiring — and
arrives with `/flywheel-update`.

## N — Norms

`bytes_in` stays a **floor** (P23/P40a): tool responses only. The advisory
therefore fires on a floor, and 600 KB is deliberately below the context it
proxies. Absent is not zero: no meter, no numbers.

## S — Safeguards

- **Once per multiple.** An advisory that fires on every call spends the context
  it is warning about; the mark is a sidecar, never a meter row (requirement 2
  is asserted against exactly this).
- **Unable to remember means silent.** If the mark cannot be written, the hook
  says nothing rather than repeating forever.
- **A typo does not disarm the guard.** An unparseable budget falls back to the
  default; only an explicit `0` disables.
- **The default is derived, not chosen.** 600 KB is where the marginal cost of
  one more call (context × the cache-read rate) passes the fixed cost of writing
  a handoff and re-priming a fresh session — ~150K tokens, at the ~4 B/token
  this floor counts. It is a break-even, and it is stated so it can be argued
  with rather than inherited.
- **The hole under the measurement.** The budget could not be built without
  fixing it: the payload reached python through an env var, capped at 128 KiB,
  failing whole and silently. Every run before v0.65.0 under-reports any
  transition that read a large file. Not backfilled (P18).

## Success metric

```
export TMPDIR="$(mktemp -d)"
for t in scripts/test-*.sh scripts/check-*.sh; do bash "$t" >/dev/null || echo "RED $t"; done
claude plugin validate . --strict
```

Green means: no `RED` line, and validation passes.
