# P72 T3 — Ventanilla Única

**Status:** signed 2026-10-04 (autonomous run).

## R — Requirements

`bash scripts/sweep.sh` (P60) is the pre-push gate, now ~10 minutes and 51
steps, and its verdict lands as a wall of text at the end. Make it a counter
where each gate is a stamp:

- `/ventanilla [base]` opens a pane and runs the sweep in the background; every
  `PASS`/`FAIL`/`SKIPPED` line stamps a row as it arrives; at the end a toast
  gives the verdict ("Sellado 51/51" or the missing stamps, "vuelva usted
  mañana");
- a sweep the model runs itself through Bash is read the same way when its
  result comes back, so the counter reflects it too;
- `/ventanilla status` answers in text, for terminals too narrow for a pane.

Out: re-implementing any gate. The gate list is whatever sweep.sh prints.

## A — gate

T2 left no evidence against this. The step's own question, whether a mod can
observe the sweep without re-implementing it, is answered by parsing its output
lines (`PASS x`, `FAIL x`, `SKIPPED x`, `N/M passed`), the format sweep.sh's own
test pins.

## S — Success metric

`bash scripts/check-mods.sh origin/main ventanilla-unica` green: stamps parsed
from a spawned sweep, verdict toast for pass and fail, Bash-run sweep observed,
pane mounts on terminal and desktop.
