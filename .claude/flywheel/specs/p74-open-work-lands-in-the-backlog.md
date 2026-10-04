# P74 — a learning's open work lands in the backlog

**Status:** signed 2026-10-04 (owner: "¿por qué no hacemos que se registren como backlog estas cosas?").

## R — Requirements

`/flywheel:compound` writes lessons; when a lesson leaves work open ("a
follow-up that…", "two things for later…"), that work stays as prose in
`LEARNINGS.md`. Nothing moves it to `docs/research/improvement-proposals.md`;
only `flow-audit` reads the backlog, and only when someone runs it. Measured on
this branch: six follow-ups written into P72's learnings, **zero** backlog rows —
the same gap P70 closed for lessons from other repos, open inside this one.

- A lesson that leaves work open declares it in its metadata line:
  `followup=<one line>` and `backlog=P<n>`, the row that carries it.
- `scripts/check-followups.sh` (+ `test-check-followups.sh`), wired into CI:
  every `followup=` names a `backlog=P<n>` whose `| P<n> |` row exists in the
  backlog (`docs/research/improvement-proposals.md`, else
  `.claude/flywheel/BACKLOG.md`, or `FLYWHEEL_BACKLOG`). No ledger, or no entry
  with `followup=`, passes.
- `compound` tells the session to file the row when it writes the lesson.
- This branch's six follow-ups are filed now (P75–P80) and their lessons tagged,
  so the gate is red on the real tree before they are and green after.

Out: grading prose for unstated follow-ups (a model's job, flow-audit's).

## S — Success metric

`bash scripts/test-check-followups.sh` green; `bash scripts/check-followups.sh`
red on the tree with the tags but no rows, green with the rows; sweep N/N.
