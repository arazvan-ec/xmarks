# Proactive & time-based loops with flywheel

flywheel itself is **turn-based**: `spec → plan → work → verify → review →
compound`, one phase per turn, gated by you. This guide covers layering Claude
Code's **time-based** (`/loop`) and **proactive** (`/schedule` routines,
dynamic workflows) primitives *on top* of that cycle — nothing here changes
flywheel's skills or agents. Background: see
[`getting-started-with-loops.md`](getting-started-with-loops.md) for the four
loop types, and [`research/claude-code-loops.md`](research/claude-code-loops.md)
for full details and caps on each primitive.

Reach for these only when the work is genuinely recurring or needs to run
without you in the loop. If a single turn-based `/flywheel:loop` gets the job
done, use that — don't add a scheduler for one-off work.

## 1. Babysit a PR with `/loop`

Once `/flywheel:ship` opens a PR, use `/loop` to poll it while you do other
things — same session, same machine:

```
/loop 20m run /flywheel:verify, then /flywheel:review, on this PR's branch;
fix anything red or unresolved, push, and stop once CI is green and review
has no open findings
```

- `/loop` fires while the session is idle and open; it stops if you close the
  terminal (it's local, not cloud).
- Give it a real stop condition in the prompt, as above — otherwise it just
  keeps re-running until you cancel it or it expires.
- A bare `/loop` (no prompt) runs the built-in maintenance pass: finish
  unfinished work, tend the branch's PR, clean up. That alone can substitute
  for the prompt above if flywheel's ledger already captures what "done" means
  for this cycle.

## 2. Schedule flywheel checks with `/schedule`

For work that should run **cloud-side, laptop closed** — a daily review sweep,
a recurring dependency check — use a routine instead of `/loop`:

```
/schedule daily at 9am: run /flywheel:verify and /flywheel:review on the repo's
open PRs; comment findings, don't push without a green verify
```

- Routines run full cloud sessions with no permission prompts — treat the
  prompt as if it will execute autonomously, so keep destructive actions out
  unless already authorized (mirrors flywheel's own stance on irreversible
  actions).
- Route the routine to a cheaper model with the per-routine model selector
  when the task is mostly mechanical (running `verify`, formatting a report);
  reserve the default/capable model for routines that make judgment calls
  (`review`).

## 3. Bound a proactive stream with `/goal`

`/goal` turns a loop's *stop condition* from "Claude decides" into "a
separate evaluator model checks your condition." Pair it with flywheel's
`verify`/`review` skills so the condition is something Claude can actually
prove from the transcript:

```
/goal /flywheel:verify passes with no failing checks and /flywheel:review
reports no unresolved findings, or stop after 10 turns
```

- Always include a turn cap in the condition (`stop after N tries`) — the
  evaluator only reads the transcript, so an unprovable or perpetually-false
  condition loops until you cancel it.
- This composes with `/loop`: schedule the goal-bounded prompt to re-fire on
  an interval instead of running once.

## 4. Fan out with dynamic workflows

When a proactive stream needs more agents than one conversation can
coordinate — reviewing every open PR, triaging a backlog of issues — use a
workflow instead of a single agent per tick. A natural fit with flywheel: one
`reviewer-correctness` / `reviewer-security` / `reviewer-performance` agent per
item, fanned out from the routine's prompt (`/flywheel:review` already does
this for one ref; a workflow repeats the pattern across N refs). Pilot on a
small slice before scheduling it to run unattended — workflows can spawn
hundreds of agents.

## Caps to respect

Don't design a routine or loop that violates these — Claude Code will reject
or throttle it:

| Primitive | Cap |
| --- | --- |
| `/loop` | 1-minute minimum interval; 50 scheduled tasks per session; recurring tasks expire after 7 days |
| `/schedule` routines | 1-hour minimum interval (sub-hourly is rejected); a daily per-account run cap |
| `/goal` | condition ≤ 4,000 chars; always pair with a turn cap |
| Dynamic workflows | 16 concurrent agents; 1,000 agents per run; advisory warning past 25 agents / 1.5M tokens |

Match the interval to how often the watched thing actually changes — a PR
that gets reviewed once a day doesn't need a 5-minute poll. See the [numeric
caps cheat-sheet](research/claude-code-loops.md#numeric-caps-cheat-sheet) for
the full table and sources.

## Verifying a routine actually worked

A green run status means the session started and exited cleanly — **not**
that the task succeeded. Open the run (or the PR/branch it touched) to
confirm flywheel's own bar was met: `verify` actually passed, `review` has no
open findings. Don't take "the routine ran" as a substitute for flywheel's
"nothing ships on seems-right."
