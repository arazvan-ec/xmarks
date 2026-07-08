# Getting started with loops

> **About this document.** This is a faithful *adaptation* — short factual lists
> and the summary table are quoted; the connecting prose is summarized in our own
> words — of the article **"Getting started with loops"** by
> **[@delba_oliveira](https://x.com/delba_oliveira)**, published on the
> **[@ClaudeDevs](https://x.com/ClaudeDevs)** X account (6 Jul 2026). It is not a
> verbatim copy; read the original for the full text. It lives here as reference
> material for evolving flywheel — see [How this maps to flywheel](#how-this-maps-to-flywheel).

There is a lot of talk about *"designing loops"* rather than just prompting a
coding agent. The Claude Code team defines a **loop** as an agent repeating
cycles of work until a stop condition is met, and categorizes loops by four
questions: how they are **triggered**, how they are **stopped**, which Claude
Code **primitive** drives them, and which **task** each fits best.

Not every task needs a complex loop — start with the simplest solution and reach
for these patterns selectively.

## The four loop types

### 1. Turn-based loops

- **Triggered by:** A user prompt.
- **Stop criteria:** Claude judges it has completed the task or needs additional context.
- **Best used for:** Shorter tasks that are not part of a regular process or schedule.
- **Managed usage by:** Write specific prompts and improve verification using skills to reduce the number of turns.

```
        ┌──────────────────── the agentic loop ────────────────────┐
        ▼                                                           │
   Your prompt → Gather context → Take action → Verify the work → Response
        └────────────────────────── repeat if needed ─────────────┘
   Exits when Claude judges the task complete — or the effort budget runs out.
```

Every prompt starts a manual loop with you directing each turn: Claude gathers
context, acts, checks its work, repeats if needed, and responds. You then check
the result and write the next prompt. You can push more of that verification
*into* the loop by encoding your manual review steps as a `SKILL.md`, so Claude
can check its own work end-to-end. The more quantitative and tool-backed the
checks (browser, console, performance traces), the easier it is for Claude to
self-verify. For example:

```markdown
---
name: verify-frontend-change
description: Verify any UI change end-to-end before declaring it done.
---

# Verifying frontend changes

Never report a UI change as complete based on a successful edit alone. Verify it
the way a human reviewer would:

1. Start the dev server and open the edited page in the browser.
2. Interact with the change directly. For a new control (button, input, toggle):
   click it, confirm the expected state change, and screenshot before/after.
3. Check the browser console: zero new errors or warnings.
4. Use the Chrome Devtools MCP, run a performance trace and audit Core Web Vitals.

If any step fails, fix the issue and rerun from step 1 — do not hand back
partially verified work.
```

### 2. Goal-based loop (`/goal`)

- **Triggered by:** A manual prompt in real-time.
- **Stop criteria:** Goal achieved OR maximum number of turns reached.
- **Best used for:** Tasks that have verifiable exit criteria.
- **Managed usage by:** Setting a specific completion criteria and explicit turn caps, "stop after 5 tries."

```
   /goal get the homepage Lighthouse score to 90 or above, stop after 5 tries

                          ┌──── tries to stop ────┐
                          ▼                        │
     Claude works ──▶ Evaluator model ──▶ Loop ends (goal met,
     on the task       checks your          or the turn limit
                       condition            is reached)
          ▲                 │
          └── condition not met — sent back to work ──┘
```

A single turn is often not enough for complex tasks; agents do better when they
can iterate. `/goal` extends how long Claude keeps going by defining what *done*
looks like. The key difference from a plain turn-based loop: Claude does not get
to decide "good enough" and stop early. Each time it tries to stop, a separate
**evaluator model** checks your condition and sends it back to work until the
goal is met or your turn cap is reached. This is why *deterministic* criteria —
tests passed, a score threshold cleared — work so well.

### 3. Time-based loop (`/loop` and `/schedule`)

- **Triggered by:** A specified time interval.
- **Stop criteria:** You cancel it, or the work completes (the PR merges, the queue is empty).
- **Best used for:** For recurring work, or interfacing with external environments / systems.
- **Managed usage by:** Set longer intervals or react based on events rather than time.

```
   ┌── every N minutes ──┐
   ▼                     │
   run the prompt ──▶ react to what changed ──▶ (cancel, or work completes)
   └──────────── on an interval ──────────────┘
```

Some work is recurring — the task stays the same and only the inputs change (e.g.
summarizing Slack messages each morning). Other work depends on external systems
you poll and react to (e.g. a PR that may get reviews or fail CI). `/loop`
re-runs a prompt on an interval:

```bash
/loop 5m check my PR, address review comments, and fix failing CI
```

`/loop` runs on your computer, so it stops when you turn the machine off. Move it
to the cloud by creating a routine with `/schedule`.

### 4. Proactive loops

- **Triggered by:** An event or schedule, with no human in real time.
- **Stop criteria:** Each task exits when its goal is met. The routine itself runs until you turn it off.
- **Best used for:** Recurring streams of well-defined work: bug reports, issue triage, migrations, dependency upgrades, etc.
- **Managed usage by:** Routing routines to smaller, faster models and using the most capable model for judgment calls.

```
   RUNS IN THE CLOUD — LAPTOP OPEN OR NOT

   TRIGGER               GOAL + CHECK              REVIEW
   /schedule    ──▶      Main agent        ──▶     Second agent   ──▶  Opens a PR
   watches Slack/        loops until the           reviews, then         │
   GitHub for            verification skill        notifies you          ▼
   bug reports           passes                                     You decide
        ▲                                                           what to merge
        └──────────────── runs until you turn it off ──────────────┘
```

The primitives above compose — together with **auto mode** and **dynamic
workflows** (research preview) — into a loop for long-running work with no human
in the moment. To handle incoming feedback you might combine: `/schedule` to
check for new reports, `/goal` + verification skills to define and check *done*,
dynamic workflows to triage/fix/review each report, and auto mode so the routine
runs without stopping for permission. A composed prompt could look like:

```bash
/schedule every hour: check the project-feedback channel for bug reports.
/goal: don't stop until every report found this run is triaged, actioned, and
responded to. When fixing a bug, use a workflow to explore three solutions in
parallel worktrees and have a judge adversarially review them.
```

## Best practices

**Maintaining code quality** — a loop's output is only as good as the system
around it:

- **Keep the codebase clean** — Claude follows the patterns and conventions already present.
- **Give Claude a way to verify its own work** — encode what "good" means with skills.
- **Make docs easy to reach** — up-to-date framework/library docs carry current best practices.
- **Use a second agent for code reviews** — a reviewer with fresh context is less biased than the main agent.

When a result misses the bar, don't just fix that one issue — encode the fix so
the *system* improves for every future iteration.

**Managing token usage** — give loops clear boundaries:

- **Choose the right primitive and model for the job** — smaller tasks don't need multiple agents; some can use cheaper, faster models.
- **Define clear success and stop criteria** — so Claude arrives at the solution sooner (but not too soon).
- **Pilot before a large run** — dynamic workflows can spawn hundreds of agents; gauge usage on a small slice first.
- **Use scripts for deterministic work** — running a script is cheaper than re-reasoning the steps each time.
- **Don't run routines more often than needed** — match the interval to how often the watched thing changes.
- **Review usage** — `/usage` breaks down recent usage by skills, subagents, and MCPs; `/goal` with no arguments shows turns and token usage; `/workflows` shows per-agent token usage and lets you stop an agent.

## Summary

| Loop | You hand off | Use it when | Reach for |
| --- | --- | --- | --- |
| Turn-based | The check | You're exploring or deciding | Custom verification skills |
| Goal-based | The stop condition | You know what done looks like | `/goal` |
| Time-based | The trigger | The work happens outside your project on a schedule | `/loop`, `/schedule` |
| Proactive | The prompt | The work is recurring and well-defined | All of the above, and dynamic workflows |

To get started, look at the work you already do, pick one task where you're the
bottleneck, and ask which piece you could hand off: can you write the
verification check? Is the goal clear enough? Does the work arrive on a schedule?
Then run the loop, observe where it stalls or over-reaches, and iterate.

For more, see the Claude Code docs:
[running agents in parallel](https://code.claude.com/docs/en/agents),
[`/goal`](https://code.claude.com/docs/en/goal),
[`/loop`](https://code.claude.com/docs/en/scheduled-tasks) (the article's "loop"
link mis-points to `/goal`; the real page is `scheduled-tasks`),
[`/schedule` routines](https://code.claude.com/docs/en/routines), and
[dynamic workflows](https://code.claude.com/docs/en/workflows).
Detailed notes distilled from these pages live in
[`research/claude-code-loops.md`](research/claude-code-loops.md).

*Source: "Getting started with loops" by [@delba_oliveira](https://x.com/delba_oliveira),
[@ClaudeDevs](https://x.com/ClaudeDevs) (6 Jul 2026).*

## How this maps to flywheel

flywheel is, in the article's terms, a **turn-based** system: the nested outer
loop (`spec → plan → work → verify → review → compound`) and the inner
iterate-until-green loop inside [`skills/work`](../skills/work/SKILL.md). Mapping
the four loop types onto what the plugin ships today:

| Article loop type | flywheel today |
| --- | --- |
| **Turn-based** | ✅ Fully covered — the two nested loops ([README](../README.md) "two nested loops"; `skills/work`, `skills/loop`). |
| **Goal-based** | 🟡 Partial — [`skills/autoloop`](../skills/autoloop/SKILL.md) has a machine-checkable metric plus a max-iterations budget, but the *same* agent measures and judges its own score. There is no separate **evaluator model** that intercepts a stop attempt and forces continuation, which is the defining mechanism of `/goal`. |
| **Time-based** | ❌ Absent — no interval/cron/schedule trigger in any skill. (`/flywheel:loop` is the dev cycle, not a time runner.) |
| **Proactive** | ❌ Absent — nothing is event- or schedule-triggered without a human; `/flywheel:help` even mandates explicit confirmation before launching `loop`/`autoloop`. |

Two article best-practices flywheel **already** honors: verification encoded as a
skill + fresh-context agent ([`skills/verify`](../skills/verify/SKILL.md) +
[`agents/verifier.md`](../agents/verifier.md)), and a second fresh-context
reviewer (the three parallel `reviewer-*` agents dispatched by
[`skills/review`](../skills/review/SKILL.md)).

**Opportunity — model routing / token usage.** The article prescribes routing
routine work to smaller/faster models and reserving the most capable model for
judgment calls. Today all four agents are pinned `model: sonnet`
(`agents/*.md`), with no distinction between the mechanical `verifier` (run
tests, report) and the judgment-heavy `reviewer-*` agents.

> These gaps and opportunities are recorded here as a **roadmap only** — none are
> implemented by this document. It is the starting point for a later change.
