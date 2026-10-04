# P72 T12 — General Strike

**Status:** signed 2026-10-04 (autonomous run).

## R — Requirements

`/flywheel:debug` exists because guessing at a red test burns cycles: edit, run,
still red, edit again. Nothing notices the loop. The General Strike does:

- a Bash command that looks like a check (`test`, `check`, `sweep`, `pytest`,
  `jest`, `vitest`, `go test`, `cargo test`, `npm/pnpm/yarn test`, `make test`)
  is tracked per normalised command; a failure (`isError`) counts, a pass resets;
- the **3rd consecutive failure** of the same check, with an edit since the
  previous failure, declares a strike: `Edit`, `Write` and `NotebookEdit` are
  denied with the reason, and the next prompt carries a note to switch to
  `/flywheel:debug` (reproduce, isolate, hypothesise) before editing again;
  `Read`, `Grep`, `Glob` and `Bash` keep running, because diagnosis needs them;
- the strike ends when that check passes, when a `Skill` call opens
  `flywheel:debug`, or by `/strike end` (the owner's escape, toasted).

## A — gate

The step's question set the threshold: red→green TDD fails a check once, then
edits, then passes; two reds can be an honest second attempt; three reds of the
*same* check with edits between and no green is guessing. Re-running without an
edit is not a new attempt, so it doesn't count.

## S — Success metric

`bash scripts/check-mods.sh origin/main general-strike` green: 2 failures no
strike, 3 with edits strike, re-runs without edits don't count, a pass resets,
a different check is separate, edits denied/reads allowed during strike,
debug skill and `/strike end` lift it, non-check commands ignored.
