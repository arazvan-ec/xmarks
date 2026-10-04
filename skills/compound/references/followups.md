# Open work goes to the backlog (P74)

Prose like "a follow-up should…" or "two things for later" in `LEARNINGS.md` is
read by no one who schedules work: six such follow-ups in P72's lessons reached
the backlog zero times. When a lesson leaves work open:

1. Add a row to the backlog — `docs/research/improvement-proposals.md`, else
   `.claude/flywheel/BACKLOG.md` (create it with a `| P | Title | Status | Evidence |`
   header) — with the next free `P<n>`, a status (`🔵 proposed`, or
   `🔵 needs data` when it waits on a measurement) and the evidence.
2. In the entry's metadata line write `followup=<one line>; backlog=P<n>`
   (`backlog=P<n>,P<m>` when one lesson opens several).

`scripts/check-followups.sh` fails CI when a `followup=` names no row, or a row
that is not a `| P<n> |` line of the backlog. A P-number mentioned in prose does
not count.
