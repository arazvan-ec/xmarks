# P72 T2 — Memory Hole

**Status:** signed 2026-10-04 (autonomous run, owner: "de forma autónoma con todas hasta terminarlas").

## R — Requirements

CLAUDE.md: "a list you were handed is a file, not a memory" — materialize it
numbered to a file before starting. Today nothing observes it. Make it a
mechanism:

- a prompt carrying a list (2+ numbered items, or 3+ bullets, outside code
  fences) opens a *hole*: the turn gets a context note telling the model to write
  the list to a file first;
- while the hole is open, `Edit`, `Write` and `NotebookEdit` to any other path are
  denied with the reason;
- writing a list file closes it: a path ending `.plan.md`, or under a
  `scratchpad/` directory, or named `tasks.md` / `todo.md`;
- `/memory-hole release` closes it by hand, logged as a toast (the owner's escape).

Out: checking the list *content* matches (that's closure, check-task-closure).

## A — gate

T1 left no evidence against this step; its own question is false positives,
which cost a blocked session, so the trigger is conservative (code fences
stripped, 2 numbered or 3 bullets) and the escape is one command.

## S — Success metric

`bash scripts/check-mods.sh origin/main memory-hole` green: list detected
(numbered, bullets), fenced list ignored, single item ignored, edit denied
while open, plan/scratchpad write allowed and closes, release closes.
