# P72 T11 — The Supervisor

**Status:** signed 2026-10-04 (autonomous run).

## R — Requirements

CLAUDE.md: "close item by item, with evidence — a `file:line`, a command that
passes, or a commit; an item defensible only in prose is reported unverified."
check-task-closure grades that at plan level, after the fact. The Supervisor asks
for it during the work:

- every N idle prompts (default 5; `/supervisor every <n>`), the turn gets a
  context note: name what closed since the last check and its evidence, or say
  nothing closed;
- at `classic.Stop` of a supervised turn, a reply naming no evidence (no
  `path:line`, no backticked command, no 7+ hex commit) raises a toast; it does
  not block;
- `/supervisor` reports checks asked and how many replies named evidence.

## A — gate (reshaped)

The roadmap had a supervising subagent (`$.agent.register`). Cost analysis: a
subagent re-reads the conversation every check; the note is ~60 tokens and
rides a turn that happens anyway. flywheel already ships `verifier` and
`evaluator` agents for on-demand re-checks. So: a note plus a deterministic
evidence check, and the counter that answers "what does it catch".

## S — Success metric

`bash scripts/check-mods.sh origin/main supervisor` green: note on the Nth
prompt only, cadence configurable, evidence recognised in three forms, toast
on a bare reply, quiet on unsupervised turns, report counts.
