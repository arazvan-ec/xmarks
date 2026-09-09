---
name: plan
description: Turn an approved spec into ordered tasks, each with its own pass/fail check and a model/effort route. Use after /flywheel:spec sign-off, before writing code.
argument-hint: "[spec-slug]"
allowed-tools: Read, Grep, Glob, Write, Bash(bash scripts/plan-route.sh:*), Bash(bash "${CLAUDE_PLUGIN_ROOT}/scripts/plan-route.sh":*), Bash(bash .claude/flywheel/bin/plan-route.sh:*)
---

# /flywheel:plan — sequenced plan with per-task gates

Read the approved spec at `.claude/flywheel/specs/$ARGUMENTS.md` (or the most recent spec if no slug is given). If there is no approved spec, STOP and tell the user to run `/flywheel:spec` first — do not plan from a vague request.

Produce a plan and save it to `.claude/flywheel/specs/<slug>.plan.md`:

1. Decompose the work into small, ordered tasks (aim for 2–15 min each), each as **exactly this block** — the format is pinned so the route is machine-checkable:

   ```
   ### T<n> — <task title>
   - route: `<model>/<effort>[+delegate]`
   - risk: highest            ← on exactly one task (skip in a one-task plan)
   - changes: <files/functions this task touches>
   - check: <the test/command/observation that proves this task is done>
   - test-first: yes|no       ← yes where the inner loop applies
   ```

2. Identify the files to create/modify, new dependencies, and the single riskiest step (the one that carries `risk: highest`).
3. Re-check against the spec's Safeguards — make sure the plan addresses each one.
4. Open the plan with a **Routing table** (tier → route → task ids) and one line naming why the riskiest step is where it is.

## Routing: pick the tier per task, not per session

A whole plan run at one model/effort is wrong in both directions — a rename pays the top price, and a migration can run at whatever effort the session was left on. Route each task by what the task actually demands:

| Tier | Route | The task is |
| --- | --- | --- |
| **T1 mechanical** | `haiku/low+delegate` | Fully specified, no design choice left: renames, moves, config/string edits, doc-table sync, building a fixture from a recorded recipe, running a script and reporting output. |
| **T2 default** | `sonnet/medium` | Ordinary test-first implementation of one behavior inside code that already exists. Most tasks. |
| **T3 judgment** | `opus/high` | Interface/architecture design, concurrency, auth/secrets/data-migration, ambiguous requirements, 3+ modules at once — and the `risk: highest` task, always. |

- `+delegate` means `work` hands the task to the `executor` agent (haiku, low effort) in its own context instead of spending this one.
- Raise **effort** within a tier when the *check* is subtle (a tricky invariant) rather than when the code is large; `max` is for a genuinely hard proof, not for reassurance.
- The riskiest task runs at the **top tier or above** — `scripts/plan-route.sh` fails the plan otherwise, and rejects `inherit` or an integer effort there because neither can be ranked against it.
- The tiers themselves live in `scripts/route-tiers.txt` (`<tier> <model> <effort> [delegate]`, cheapest first). That table is what the linter enforces and what the summary labels; retune tiers there, not in prose.
- Route from evidence when the ledger has it: `/flywheel:recall routing <area>` — a past cycle that had to escalate a task like this one is a reason to plan it a tier up.

**Lint the plan before the gate** (fail-open — skip silently if the script isn't there): `bash "${CLAUDE_PLUGIN_ROOT}/scripts/plan-route.sh" .claude/flywheel/specs/<slug>.plan.md` on a marketplace install, `bash .claude/flywheel/bin/plan-route.sh <same arg>` on a vendored one, or `bash scripts/plan-route.sh <same arg>` inside the flywheel repo itself. All three are pre-approved. It checks every task carries one legal route and a check, and prints the tier summary to show at the gate.

GATE: present the plan **with its routing table and tier summary** — approving the plan approves its routes, including any model switch `work` will ask for. No code is written until the plan is approved. Then hand off to `/flywheel:work`.
