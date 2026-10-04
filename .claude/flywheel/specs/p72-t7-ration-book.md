# P72 T7 — Ration Book

**Status:** signed 2026-10-04 (autonomous run).

## R — Requirements

The invocation budget (P35/P36) caps what a skill *loads*; nothing caps what a
session *reads*. Give each session a ration of read bytes:

- bytes in = result text of every tool call (T1's measure);
- the ration is the 75th percentile of this mod's last 10 session totals once 5
  are recorded, never below 100 KB; until then 400 KB;
- status line shows coupons left; a toast at 80 %;
- at 100 %, `Read`, `Grep`, `Glob`, `WebFetch` and `WebSearch` are denied with the
  reason; `Bash` and writes are never held (tests and git must keep running);
- `/ration` shows the book; `/ration grant <KB>` adds coupons, logged as a toast
  (the owner's escape);
- each session's total is stored for the next calibration.

## A — gate (reshaped)

T1's data was meant to set the ration, but `$.store` is per plugin: this mod
cannot read big-brother-token's `sessions`. Rather than reach into another
plugin's file, the Ration Book keeps its own history and calibrates from it
(p75, self-correcting). Sharing data across mods needs a declared contract;
filed as a learning. Audio dropped: it needs a shipped asset and a toast says
the same.

## S — Success metric

`bash scripts/check-mods.sh origin/main ration-book` green: default ration,
calibrated ration from history, 80 % toast, reads denied at 100 % while Bash
runs, grant lifts it, total stored.
