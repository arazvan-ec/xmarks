---
name: loop
description: Run the full development cycle (spec → plan → work → verify → review → compound) for one unit of work, gating between phases; small clear tasks route through a collapsed micro-cycle. Use to start a new feature or task.
disable-model-invocation: true
argument-hint: "[feature or task description]"
---

# /flywheel:loop — the outer development loop

You are running the flywheel cycle for: **$ARGUMENTS**

The cycle has six phases, each with an entry gate. Do not enter a phase until the previous gate is green. If a gate fails, stop and report — do not paper over it.

**Route by size first** — and state the route you chose and why (a silent shortcut reads as a skipped gate; `/flywheel:review` sets the precedent). A task is **small** when ALL hold: the expected change is ~1 file / under ~20 lines, it adds no new entity, dependency, or migration, and its pass condition is an obvious machine-checkable command. Small → run the **micro-cycle**: one message carrying a mini-spec (goal + success metric, a paragraph — no REASONS doc, no separate plan file) plus the task list, **one** sign-off, then `work` → `verify` (review routes itself by diff size; `compound` only if a durable lesson emerged). Anything fuzzy, multi-file, or that grows mid-flight → the full cycle below; if a micro-cycle sprouts scope, stop and upgrade to the full cycle rather than stretching the shortcut. Verification is never routed away — the micro-cycle skips *documents*, not gates.

0. **Prime.** Work from the SessionStart-injected learnings subset and skim related specs in `.claude/flywheel/specs/`; pull specifics with `/flywheel:recall <topic>`. Never read the whole ledger — the budgeted injection exists to avoid exactly that cost.
1. **spec** → run `/flywheel:spec`. Produces a REASONS contract + a single machine-checkable success metric. GATE: the spec is signed off before planning.
2. **plan** → run `/flywheel:plan`. Ordered tasks, each with its own check. GATE: plan approved; no coding before this.
3. **work** → run `/flywheel:work`. Implement task by task using the inner iterate-until-green loop. GATE: every task's local check is green.
4. **verify** → run `/flywheel:verify`. Objective PASS/FAIL against the success metric, running the real app/tests. GATE: must be PASS to continue.
5. **review** → run `/flywheel:review`. Parallel multi-specialist review. GATE: no unresolved Critical/High findings.
6. **compound** → run `/flywheel:compound`. Append the cycle's decisions, gotchas, and reusable patterns to the ledger.

Rules:
- **Progress, live** — at cycle start, materialize the six phases as visible tasks in the host task system and update states at every gate transition. Telemetry is two-tier: append **one JSON line per transition** (phase/task, state, timing, outcome — never secrets) to `.claude/flywheel/runs/<spec-slug>/<date>.jsonl`, and render the HTML report `.claude/flywheel/runs/<spec-slug>/<date>.html` from that JSONL **only at phase gates and at close**, republishing to the same stable artifact URL. Never regenerate the HTML per task transition — output tokens are the expensive ones, and a page per transition is the most expensive way to say "state changed". Chat is for gates, blockers, and the closing summary. Fail-open: reporting never blocks the cycle.
- Announce each phase as you enter it and state whether the prior gate passed.
- Never skip verify or review to "save time" — they are what make the loop trustworthy.
- For larger work, loop steps 3–4 per task, then do a single review pass at the end.
- Close with a one-paragraph summary: what shipped, the metric result, and what got compounded.
