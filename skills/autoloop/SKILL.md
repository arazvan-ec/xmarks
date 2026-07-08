---
name: autoloop
description: Autonomous iterate-until-metric loop — repeatedly change → measure → keep-if-better / discard-if-worse against a single machine-checkable metric, within a fixed budget of iterations, without pausing for human input between iterations. Use only for well-specified, objectively measurable goals (get the suite green, tune a scraper until it extracts all items, drive a lint-error count to zero).
disable-model-invocation: true
disallowed-tools: AskUserQuestion
argument-hint: "[goal] [max-iterations, default 10]"
---

# /flywheel:autoloop — autonomous metric-driven loop

Goal: **$ARGUMENTS**

This runs hands-off. Preconditions — refuse and point the user to `/flywheel:loop` if either is missing:
- a **single machine-checkable metric** (a command whose output is an objective score / pass count / error count), and
- a **budget** (max iterations; default 10).

Loop:
1. **Measure baseline** — run the metric command; record the score. If already at target, stop and report.
2. **Hypothesize + change** — make the smallest change you believe improves the metric. Record what you changed.
3. **Re-measure** — run the metric command again.
4. **Keep or discard** — if the score improved, keep the change; if it regressed or stalled, revert it (`git checkout` / `git stash`) and try a different change.
5. Repeat until the metric hits target or the budget is exhausted.

**Independent stop check.** Before declaring the target met (step 5) or discarding an ambiguous result (step 4), dispatch the `evaluator` agent with the metric command, the target, your claimed score, and the prior score. You self-report the number; the evaluator re-runs the command itself and returns `CONTINUE` or `STOP — <reason>` — this is the cross-check `/goal` gets for free from its Haiku evaluator, applied on top of (not instead of) your own metric-command check. On a `CONTINUE`, keep looping even if you believed you were done; log the evaluator's reason alongside the iteration.

Keep a running log of `iteration | change | score | evaluator verdict | kept?`. Never ask the human mid-loop (AskUserQuestion is disabled). When you stop, report the trajectory, the final score, whether the target was met, and — if not — the most promising next direction.

**Safety:** work on a branch; only revert changes *you* made this run; never discard pre-existing uncommitted work.

**Token discipline:** autoloop runs unattended for up to the full iteration budget, so treat token spend as a first-class constraint, not an afterthought:
- **Pilot before scaling.** For a new or loosely-specified metric, run a small budget (2–3 iterations) first to confirm the metric command is meaningful and the change strategy is converging, before committing to the full budget.
- **Match the check interval to the work.** Don't re-run an expensive metric command (a full test suite, a slow build) more often than a single iteration's change could plausibly move it.
- **Make the budget/stop criteria explicit up front** — target score, max iterations, and what "stalled" means (e.g. N iterations with no improvement) — so the loop can't silently run to the budget ceiling on a lost cause.
- **Check spend mid-run** with `/usage`; for the turn-based cousins of this loop, `/goal` (status line shows token spend) and `/workflows` (progress + spend per agent) give the same visibility.
