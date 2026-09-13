# Why `/flywheel:work`'s rules are what they are

The argument behind the rules in `skills/work/SKILL.md`. Moved here by P39: a run
executing the loop needs the rule, not the case for it, and everything a skill
body or its `references/` carries is paid in full at every invocation (P36).
This file is **not cited by the skill** — deliberately, so it is neither charged
nor loaded. It is for the person deciding whether to change a rule.

Text below is moved verbatim from `skills/work/SKILL.md` and
`skills/work/references/work-detail.md` as of v0.47.0.

## Why the git pair is force-free

`git commit -m "<imperative subject>" -- <the paths this task touched>`, then `git push -u origin <branch>`. Both are plain and force-free — exactly what the P21 hook pre-approves, so neither prompts. Take the sha for the transition line from the commit's own output; don't spend a `rev-parse` on it.

## Commit discipline — the reasoning behind each rule

- **Pathspec only.** It commits this task and leaves the index alone (`spec` and `compound` stage their files for `ship`). `git add -A`/`-u` is banned: it sweeps in whatever was already dirty when the cycle started.
- **Never amend, rebase, squash or force-push.** Rewriting history is the user's call, not the loop's.
- **No commit, no field.** When the cycle is not committing (or this task produced nothing to commit), **omit `commit` from the transition line** — never a placeholder, never prose explaining the absence. Same rule as the `cost` object above: an absent field is data a reader can act on, a filled-in excuse is not.
- **Fails open, decided once.** Settle committability before the first task — no repo, no remote, or the **default branch** with a new feature branch declined (that one prompts) → skip the commits for the rest of the cycle and say so once, rather than paying a failing `git` pair per task. Per task, nothing to commit or a rejected push is reported once and the loop carries on; it never blocks on git.

## Escalation — why two reds and not three

**Escalate on the second red, don't grind.** If a task's local check fails twice for the same reason, the tier is wrong, not the code: move it one tier up the ladder in `scripts/route-tiers.txt` (`haiku→sonnet→opus`, or raise effort), record `route_escalated_from` on the transition, and continue there. Two reds is the signal; a third red at the same tier is just paying twice for the same wrong answer.

## Why each delegation threshold is where it is

Long solo runs bloat context and bury signal. Hand work off to a **fresh-context subagent** at these thresholds — advisory, not hard rules; use judgment:

- **Reading 4+ files** to understand an area → delegate the exploration to a subagent; it digs in its own context and returns just the summary you need, instead of loading everything into this one.
- **About to touch 2+ non-trivial files** → get a fresh-context review before advancing (`/flywheel:review`, or the `reviewer-*` agents) — a reviewer that didn't write the code catches more.
- **~20 tool calls or ~5 exploratory reads deep** in one task without converging → stop, re-plan, and re-scope; a bloated context is a signal the task needs splitting, not more grinding.
- **Standing up test data / a fixture** — ~2+ non-trivial stub files or ~5 tool calls spent constructing a valid instance of a domain entity or a test harness → once the fixture is **proven** (it built a valid instance and the check using it went green), *offer* to record it as a `type=fixture` learning at compound time. Only offer for a recipe you saw work — never an unverified one. Advisory: it captures the costliest thing the next cycle re-derives; it never forces or blocks.

These keep each turn high-signal, mirroring flywheel's existing use of fresh-context reviewers.

## Why a mis-route is worth a learning

A mis-route that cost real time — a T1 task that needed escalating, or a T3 task that turned out mechanical — is worth a `decision` learning at compound time, so the next plan routes that kind of task right. Only when you observed it (P18): the escalation happened, or the task finished cheap.

## Why the telemetry line carries no `tokens` field

The `cost` fields are **observable proxies** — bytes you wrote, tool calls you made, seconds since the previous line. Never a `tokens` field: you cannot observe your own usage, and a guess is unverifiable evidence (P18). If a field cannot be computed, omit the whole `cost` object rather than estimating.

Do **not** regenerate the HTML report inside `work` — the loop renders it from the JSONL at phase gates and at close; a transition costs one line, not a page.

## Why the route is executed rather than re-decided

Each task carries its `route` from the approved plan: the plan gate approved the
route along with the task, so re-litigating it inside the loop spends the
approval twice. Running a T3 task at low effort because switching was
inconvenient is the same failure as skipping its test; a silently downgraded
route is an unverifiable cost claim in the other direction.
