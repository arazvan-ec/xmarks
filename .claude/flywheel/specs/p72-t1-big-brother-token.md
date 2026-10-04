# P72 T1 — Big Brother Token

**Status:** signed 2026-10-04 (owner: "sigue con T1 … de forma autónoma con todas hasta terminarlas").

## R — Requirements

Reads are the expensive tokens by volume and writes by unit (CLAUDE.md,
writing-token discipline), but `cost.bytes_in` is only seen when a cycle closes.
Make it live, per session:

- status line: bytes read so far, session cost (USD) and context %;
- a toast when one tool result is over 8 KB (P40b's threshold) or when `Write`
  rewrites a file the session already read (edit over rewrite);
- `/ministry`: bytes and calls by tool, the largest read, rewrites;
- each session's summary appended to `$.store` (`sessions`, last 50), so T7 can
  set its budget from data.

Out: blocking anything (T7's job); subagent-internal reads.

## A — Approach / gate

Pane dropped: a pane opened unasked only seats from 144 columns. A status line is
always visible. Tool bytes = length of the result text the model reads.

## S — Success metric

`bash scripts/check-mods.sh origin/main big-brother-token` green: totals by tool,
>8 KB toast, rewrite toast, /ministry report, session summary stored.
