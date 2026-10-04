# P72 T10 — Telescreen

**Status:** signed 2026-10-04 (autonomous run).

## R — Requirements

`LEARNINGS.md` is surfaced at session start (truncated) and before a Read
(read-prime.sh, advisory, as context the person never sees). The person sees
none of it at the moment it applies. The Telescreen puts the relevant lesson in
a band above the prompt:

- entries parsed from `.claude/flywheel/LEARNINGS.md`: `## <type>: <title>` and
  the `files=` list of its `<!-- fw: … -->` line;
- when a `Read`, `Edit` or `Write` touches a path one of those entries names,
  the band shows the newest such entry, `📺 GOTCHA · <title> — <file>`, with a
  Hide button; a hidden slogan stays hidden until a different one applies;
- no match, no band: the screen stays quiet;
- `/telescreen` reports entries loaded and slogans shown this session (the
  measurement the gate question needs).

## A — gate

The step's question, does a lesson at use-time prevent a repeat or is it
noise, decided the trigger: relevance by file, never rotation. Noise is
designed out first; prevention needs live sessions, and the shown-count is the
start of that measure.

## S — Success metric

`bash scripts/check-mods.sh origin/main telescreen` green: entries parsed,
band shows on a matching touch (terminal + desktop), quiet without match,
newest entry wins, hide holds until a new slogan, report counts.
