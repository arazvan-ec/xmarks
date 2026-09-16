# Spec: P44 — read volume is observed, not reconstructed

**Slug:** `p44-read-volume-is-observed` · **Created:** 2026-09-16 · **Backlog:** P44
**Status:** shipped as v0.56.0 — metric PASS. The decisive clause held on real
data: `run-cost.sh` over this cycle's own run reports `bytes_in` 50,786 and
`tool_calls` 56 as numbers rather than UNMEASURED, the first values either field
has carried in the repo's history, and marks both PARTIAL (2 of 4) because the
two transitions that built the meter could not be measured by it.

**Prime:** P23 (cost proxies), P40a (per-field coverage, `bytes_in` as a floor),
P42 (the duty that now runs every run), P43 (the hooks that now fire here), and
the ledger entry *"a missing field is not a zero"* — which is the only reason
this gap was visible instead of being totalled as a win.

## R — Requirements

P40a shipped `cost.bytes_in`. Counted today across every telemetry file in the
repo: **18 lines, zero carrying `bytes_in`, zero carrying `tool_calls`.** The
instrument has never received a data point.

The cause is structural, not negligence. The two conforming files were written
at the end of a cycle and derived from git, where `bytes_out` (content bytes of
added lines) and `elapsed_s` (commit time deltas) are recoverable and read
volume is not. By the time a transition line is written the reads have already
happened and their sizes are gone. `work`'s rule — *"sum what you actually
read"* — asks a session to have kept a running total it was never given a place
to keep, so every session honestly leaves the field out, and P40a's honesty
rules correctly report UNMEASURED forever.

An instrument nothing feeds is the same failure P42 fixed one level up: a rule
whose precondition can never be met.

In scope:

1. `scripts/read-meter.sh` — a `PostToolUse` hook that appends one line per
   read-ish tool call (`tool`, `bytes`, `ts`) to a per-session counter, and the
   same script with `--since <ts>` to total that counter for a transition line.
2. Registration in `hooks/hooks.json`, in `install-vendored.sh`, and in this
   repo's own `.claude/settings.json` — the three directions `check-hook-parity.sh`
   already asserts, so a half-wiring fails CI rather than going unnoticed.
3. `skills/work/SKILL.md`: the cost rule names the meter as where the two
   fields come from, replacing an instruction to recall something unrecorded.

Out of scope: changing what `bytes_in` *means* (still a floor, per P23/P40a) and
anything that routes on it — that is P40b, and it stays unapproved until this
produces numbers.

## E — Entities

- **counter file** — `<tmpdir>/flywheel-reads-<sha256(session_id)[:16]>.jsonl`,
  the `delegation-record.sh` derivation verbatim. System temp, never the project.
- **transition line** — unchanged schema; two fields stop being absent.
- **`CLAUDE_CODE_SESSION_ID`** — how the reader reaches the same file the hook
  wrote. **Proven equal to the payload's `session_id`** (T1, below).

## A — Approach

**T1 ran first, and it was a probe rather than a doc quote** — the reference
page confirms `PostToolUse` receives `tool_response` but leaves its type
unspecified, and the design collapses if it is opaque. A throwaway hook
registered in an untracked `settings.local.json` dumped three real firings
(evidence: `probe-payload.jsonl`, scratchpad, 2026-09-16). Results:

| question | answer |
| --- | --- |
| is `tool_response` delivered? | yes, on every firing |
| its type | **always a dict, shape per tool** — `Bash` → `{stdout, stderr, interrupted, …}`, `Read` → `{type, file:{filePath, content, …}}` |
| `session_id` vs `CLAUDE_CODE_SESSION_ID` | **identical** — the reader can derive the writer's path, no heuristic |
| does a hook added mid-session fire? | **yes, immediately** — no restart |
| also present, unasked | `duration_ms`, `scratchpad_dir`, `tool_use_id`, `prompt_id` |

Two consequences the spec did not anticipate. **The meter cannot assume a
string**: it sums the lengths of the string leaves of `tool_response`, which is
tool-agnostic and keeps working for tools that do not exist yet — a per-tool
extractor would silently return nothing the first time a new tool appears, and
silence is what P42 was about. And **`duration_ms` makes `elapsed_s` observable
too**, today reconstructed from commit timestamps; it is recorded here and left
out of scope, because widening a cycle on a bonus is how a spec stops being
checkable.

Then: test-first script, wire the three directions, cite it from `work`.

Delta by timestamp, not by reset: a transition's `bytes_in` is the sum over
lines with `ts >= the previous transition's ts`. The transition line already
carries `ts`, so no mutable checkpoint and no reset to get wrong.

## S — Structure

`scripts/read-meter.sh` (+ `scripts/test-read-meter.sh`), one entry in
`hooks/hooks.json`, one in `install-vendored.sh`'s hook table, one edit to
`skills/work/SKILL.md`, `upgrades/v<next>.md`, version bump.

## O — Operations

- T1 probe: payload keys + `tool_response` type + session-id equality. Recorded.
- T2 test-first: `test-read-meter.sh` red → `read-meter.sh` → green.
- T3 wire all three directions; `check-hook-parity.sh` green.
- T4 `work`'s cost rule cites the meter.
- T5 release: upgrade note, bump, docs consistency, budgets.

## N — Norms

Test-first for the script. Terse code. Atomic commits, pushed per task. A
`scripts/`+`hooks/` change is a release with an upgrade note. The eval for
`work` runs before the bump (the order P42 got wrong).

## S — Safeguards

- **Fail-open, always.** No python3, unwritable temp, malformed payload, missing
  `tool_response` → exit 0 silently. A meter must never cost a read.
- **Nothing under the project.** `git status` stays clean; asserted, not intended.
- **`bytes_in` stays a floor.** It counts tool responses only: not the
  conversation, not content re-entering context, not tools the matcher misses.
  Labelled wherever it surfaces, per P23.
- **No backfill.** The 18 existing lines keep their absent fields (P18).
- **The meter is not a gate.** It records; it never blocks or asks.

## Success metric

```
bash scripts/test-read-meter.sh \
  && bash scripts/test-check-hook-parity.sh && bash scripts/check-hook-parity.sh \
  && bash scripts/check-test-pairing.sh && bash scripts/check-telemetry.sh \
  && bash scripts/test-install-vendored.sh && bash scripts/test-docs-consistency.sh
```

Decisive clause, on real data rather than a fixture: after this cycle's own
reads, `run-cost.sh` over this spec's run reports **`bytes_in` and `tool_calls`
as measured numbers instead of UNMEASURED** — the first time either field has
carried a value in the repo's history. If it still prints UNMEASURED, the cycle
failed regardless of how many tests are green.
