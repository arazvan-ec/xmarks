# Plan: P40a — the loop measures what it reads

**Spec:** `.claude/flywheel/specs/p40a-read-volume-proxy.md` (signed 2026-09-14)

## Routing table

| Tier | Route | Tasks |
| --- | --- | --- |
| T3 judgment | `opus/high` | T2 |
| T2 default | `sonnet/medium` | T1, T5 |
| T1 mechanical | `haiku/low+delegate` | T3, T4, T6, T7 |

The riskiest step is **T2**, the per-field accounting rewrite in `run-cost.sh`:
it is the one task that can silently break the three fields P23 already ships
while adding the fourth, and the zero trap the spec exists to prevent lives
inside it. T1 precedes it because the trap must be red before it is closed.

**`+delegate` restored (2026-09-14).** The first draft of this plan dropped it
because the `executor` agent was not a registered subagent type here — which
turned out to be a plugin defect, not a property of the task. P41 (v0.49.0) fixed
it: the agents are committed at `.claude/agents/` and register at session start.
These four routes are therefore honorable **from the next session onward**; the
session that wrote them still cannot execute them, so `work` runs in a fresh one.

### T1 — Red: the bytes_in coverage cases
- route: `sonnet/medium`
- changes: `scripts/test-run-cost.sh` — new cases: bytes_in totals; a cost object
  without `bytes_in` reports unmeasured for that field and stays measured for the
  other three; the delta refuses the bytes_in row when either side lacks
  coverage; a route bucket carries bytes_in; the eight existing cases stay green.
- check: `bash scripts/test-run-cost.sh` fails, and the failure names a bytes_in
  case — not a syntax error.
- test-first: yes

### T2 — Green: per-field accounting in run-cost.sh
- route: `opus/high`
- risk: highest
- changes: `scripts/run-cost.sh` — `FIELDS` gains `bytes_in`; `load()` returns a
  per-field `coverage` counter beside `totals`; `report()` states coverage where
  it is partial; the delta skips a field without coverage on both sides and says
  why; route buckets follow the same rule.
- check: `bash scripts/test-run-cost.sh` prints ALL PASS, including the eight
  pre-existing cases unedited.
- test-first: yes

### T3 — The schema's four sites say bytes_in
- route: `haiku/low+delegate`
- changes: `skills/loop/SKILL.md`, `skills/work/references/work-detail.md`,
  `skills/run/references/ledger-and-extensions.md`,
  `skills/process/references/contract-template.md` — add the fourth field to the
  enumerated cost object, word-scale edits only.
- check: `bash scripts/check-invocation-budget.sh` green and `grep -l bytes_in`
  matches all four.
- test-first: no

### T4 — README: the fourth proxy, and what it is not
- route: `haiku/low+delegate`
- changes: `README.md` P23 paragraph — name `bytes_in`, state it is a floor on
  read volume, state that pre-P40 runs report it unmeasured.
- check: `bash scripts/test-docs-consistency.sh` green; `grep -q bytes_in README.md`.
- test-first: no

### T5 — P40 in the backlog, both halves
- route: `sonnet/medium`
- changes: `docs/research/improvement-proposals.md` — status row + section for
  P40a (this) and P40b (the extractor + read threshold, explicitly *not
  approved*, gated on what P40a reports); `CLAUDE.md` — the token convention
  names the by-volume half as well as the per-token half.
- check: the P40 row exists in the status table and the P40b entry states its
  gate; `bash scripts/check-invocation-budget.sh` still green.
- test-first: no

### T6 — Release: bump + upgrade note
- route: `haiku/low+delegate`
- changes: `.claude-plugin/plugin.json` version → `0.49.0`;
  `upgrades/v0.49.0.md` with `requires-action: false`, `## What changed`.
- check: `bash scripts/test-install-vendored.sh` green; the upgrade file's
  frontmatter version matches the manifest.
- test-first: no

### T7 — Run the spec's success metric
- route: `haiku/low+delegate`
- changes: none — run and report.
- check: the spec's metric command exits 0, last clause included.
- test-first: no

## Safeguards re-checked

| Spec safeguard | Where the plan addresses it |
| --- | --- |
| the zero trap | T1 makes it red before T2 can close it; T2 carries `risk: highest` |
| no behavior change to the three fields | T1 keeps the eight existing cases unedited; T2's check requires them green |
| fail-open unchanged | no change to the skip/exit-2 paths; existing cases cover them |
| no external egress | `bytes_in` is a local integer; no task adds a network call |
| invocation budget | T3 and T5 both gate on `check-invocation-budget.sh` |
