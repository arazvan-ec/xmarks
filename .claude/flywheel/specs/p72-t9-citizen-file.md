# P72 T9 — Citizen File

**Status:** signed 2026-10-04 (autonomous run).

## R — Requirements

Every cycle appends one JSONL line per transition to
`.claude/flywheel/runs/<slug>/<date>.jsonl`; the HTML report is rendered from it
only at gates and close. Mid-cycle, the record is unread. The Citizen File opens
it live:

- `/expediente [slug]` opens a pane on a cycle's record — by default the run
  directory modified most recently; each transition as a row (task, phase,
  state, route, an escalation marked `↑ from <route>`), then totals: transitions,
  bytes in, escalations;
- `/expediente list` names the cycles, newest first;
- `/expediente status` gives the same file in text for narrow terminals.

Out: rendering HTML; writing to the record.

## A — gate

T3 proved the pane pattern. This step's question, does the pane replace the
gate-time HTML report, is answered by design: it reads the same JSONL, so there
is one source and two views. The HTML stays the artifact that is shared; the
pane is the live view while the cycle runs.

## S — Success metric

`bash scripts/check-mods.sh origin/main citizen-file` green: newest cycle
chosen, rows and totals, escalation marked, list ordering, named slug, bad lines
skipped, pane mounts on terminal and desktop.
