---
name: ship
description: Close out a unit of work — clean commit, push, pull request. Use at the very end of a cycle, after verify passes and compound is done.
disable-model-invocation: true
argument-hint: "[branch or PR title]"
allowed-tools: Read, Grep, Glob, Bash(git *), Bash(gh *), Bash(bash scripts/renumber.sh:*), Bash(bash "${CLAUDE_PLUGIN_ROOT}/scripts/renumber.sh":*)
---

# /flywheel:ship — close out the cycle

Finish and open a PR for: **$ARGUMENTS**

Pre-flight gates (stop if any fails):
- `/flywheel:verify` passed, and `/flywheel:review` has no unresolved Critical/High findings.
- You are on a feature branch, not the default branch. If on the default branch, create one first.

Then:
1. Review what the branch already carries (`git log --oneline <base>..HEAD`, then `git status --short` for the remainder — `review` already read the full diff a phase ago) — `/flywheel:work` and `/flywheel:debug` leave one atomic commit per task, and that history is the reviewable unit. **Never squash, rebase or amend it**; rewriting history is the user's call, and only on their explicit ask.
2. Commit what remains with a clear message — **what** changed and **why** (imperative subject; body for rationale/trade-offs). That is typically the `/flywheel:compound` ledger (`.claude/flywheel/LEARNINGS.md`), the spec/plan, and docs. Stage intentionally; do not sweep in unrelated files. Nothing left to commit is a normal outcome, not an error.
3. If the base moved, merge it in (`git merge origin/<base>`, never rebase). If that reddens the release gate — the base took your version or your P-number — follow `skills/ship/references/renumber.md` before going on.
4. Push the branch (`git push -u origin <branch>`).
5. Open a PR. Check for a PR template first (`.github/pull_request_template.md` and similar) and mirror its sections. Use whatever PR mechanism is available — the GitHub MCP `create_pull_request`, the `gh` CLI, or the web link git prints. Summarize the change and link the spec.
6. Report the PR URL.

Never push straight to the default branch. Never open a PR while a gate is red without an explicit waiver from the user.

Prefer single commands over `&&` chains — the loop's git pre-approval (P21) and permission rules match one plain command at a time, and a force-free push of the current feature branch is pre-approved while anything chained re-prompts.
