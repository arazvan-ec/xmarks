---
name: work
description: Implement plan tasks with the iterate-until-green inner loop — failing test, minimal implementation, run, observe, fix — never done until the objective check is green. Use when executing tasks from an approved plan.
argument-hint: "[task or plan-slug]"
allowed-tools: Read, Edit, Write, Grep, Glob, Bash
---

# /flywheel:work — the inner loop

**Progress, live:** materialize each plan task as a visible task before starting and flip its state the moment its local check goes green — never in bulk afterwards. **Every run, in a cycle or standalone**, append **one JSON line per transition** to `.claude/flywheel/runs/<spec-slug>/<date>.jsonl`: **never secrets, never a `tokens` field**, and omit a field you cannot compute rather than estimating it. Do not render the HTML report here; the loop does it at gates and close. Fail-open: reporting never blocks the work. The line's exact shape: `skills/work/references/work-detail.md`.

**Prime from fixtures:** before building test data for an entity, `/flywheel:recall fixture <entity>` — use the ledger's recipe instead of re-deriving it.

Execute the plan's tasks one at a time. For **each** task, run this loop and do not exit it until the task's local check passes:

1. **Red** — write (or identify) the smallest failing test / check that captures the task. Run it; confirm it fails for the right reason.
2. **Green** — implement the minimum to make it pass. No extra scope.
3. **Check** — run the tests and the linter/formatter. When behavior is user-visible, also exercise the real thing (run the app / hit the endpoint / run the script).
4. **Observe** — read the actual output. If not green, diagnose from the evidence and fix, then go back to step 2.
5. **Commit** — a green check is one finished logical change: commit it alone per **Commit discipline**, then take the next task.

## Commit discipline

`git commit -m "<imperative subject>" -- <the paths this task touched>`, then `git push -u origin <branch>`. Both are plain and force-free, so neither prompts; take the sha from the commit's own output.

- **Pathspec only.** `git add -A`/`-u` is banned: it sweeps in whatever was already dirty.
- **Never amend, rebase, squash or force-push.** Rewriting history is the user's call.
- **No commit, no field.** Not committing, or nothing to commit → **omit `commit`** from the transition line. Never a placeholder, never prose explaining the absence.
- **Fails open, decided once.** Settle committability before the first task; then a task with nothing to commit, or a rejected push, is reported once and the loop carries on. It never blocks on git.

## Honor the plan's route

Each task carries `route: <model>/<effort>[+delegate]` from the approved plan. Execute it at that tier. Three cases need care:

- **`+delegate`** → hand it to the **`executor`** agent with the task's `changes` and `check` verbatim. It returns the check output, or `ESCALATE: <reason>`. Never argue with an escalation — take the task back one tier up.
- **A route above the session's current tier** → say so and switch, or ask once: `/model opus high`, or `--effort high` for the session.
- **A route you could not honor** (no permission, agent unavailable) → run at the tier you have and **say which route was not honored**. Never downgrade silently.

A mis-route you **observed** — a T1 that needed escalating, a T3 that finished cheap — is worth a `decision` learning at compound time.

**Escalate on the second red, don't grind.** A local check failing twice for the same reason means the tier is wrong, not the code: move one tier up `scripts/route-tiers.txt` (`haiku→sonnet→opus`, or raise effort), record `route_escalated_from`, and continue there.

**Standing rule:** "done" means the objective check is green *and you have seen it be green*. Never report a task complete on the basis of reasoning alone.

**Prefer single commands over `&&` chains**: grants match subcommand-by-subcommand, so a chain re-prompts where two plain commands sail through.

**Anti-rationalization — these are banned:**

| Excuse | Reality |
| --- | --- |
| "The test is probably fine, I won't run it." | Run it. Unrun tests don't count. |
| "I'll verify everything at the end." | Verify each task; end-only verification hides which change broke things. |
| "Linter warnings are just noise." | Fix them, or justify each one explicitly in the spec's Norms. |
| "It's a small change, no test needed." | Small changes break things too — add the smallest check. |
| "It works on my reasoning." | Reasoning is a hypothesis; the run is the evidence. |
| "I'll commit it all at the end." | Commit each green task; one blob at the end is unreviewable and loses verified work to a bad turn. |

## When to delegate

Hand work to a **fresh-context subagent** at these thresholds (advisory): 4+ files read to understand an area, 2+ non-trivial files about to be touched (review first), ~20 tool calls without converging, or real effort spent standing up a fixture. A fixture you saw **work** — valid instance built, check green — you *offer* as a `type=fixture` learning, naming the entity, the recipe and the fields easy to get wrong. Never an unverified one.

When all tasks are green, hand off to `/flywheel:verify` for the objective gate against the spec's success metric. Do not self-certify the whole feature here.
