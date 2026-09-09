# Spec — atomic commits in the dev loop (P28)

Slug: `atomic-commits` · Date: 2026-09-09 · Pillar 1 (build the software)

## R — Requirements

The loop produces exactly one commit per cycle, at `/flywheel:ship`. Everything
between the spec gate and the PR lives as uncommitted working-tree state: a
green task is not durable, a bad turn can lose hours of verified work, and the
PR arrives as one opaque blob whose reviewable unit is "the whole feature". The
plugin already pre-approves `git add` / `git commit` / force-free `git push`
(P21) — the plumbing exists and no skill uses it.

In scope:
- `/flywheel:work` commits **each task** the moment its local check goes green,
  and pushes.
- `/flywheel:debug` commits the fix + its regression test as one change.
- `/flywheel:ship` stops being the only commit: it commits what remains and
  never squashes the per-task history.
- Telemetry carries the commit sha on the transition line.

Out of scope: history rewriting of any kind (squash, rebase, amend, force —
the user's call, never the loop's); a commit-message linter; conventional-commit
prefixes; committing on the default branch.

## E — Entities

| Entity | Fields |
| --- | --- |
| Task commit | one plan task's paths + its test, imperative subject, `commit` sha on the telemetry line |
| Staging rule | explicit pathspec (`git commit -m … -- <paths>`); `-A`/`-u` banned |
| Push | `git push -u origin <current-branch>`, force-free, non-default — the exact form P21 grants |
| Skip condition | no repo · no change · default branch with no feature branch · push rejected → report once, keep working |

## A — Approach

Commit at the **green edge of each task**, inside `work`, using an explicit
pathspec so the commit contains that task and nothing else. Rejected
alternative: a `scripts/commit-task.sh` wrapper. It would be testable, but the
P21 hook grants `git` as argv[0] only, so every call would hit a permission
prompt — the wrapper would need its own grant, widening the pre-approved
surface to get a worse ergonomic than the two plain commands the hook already
covers.

Pathspec over `git add` + bare `git commit`: a bare commit sweeps whatever the
index already holds (`spec` and `compound` stage their files deliberately), so
the "atomic" commit would silently absorb them. `git commit -- <paths>` leaves
the index alone, which is what makes the unit honest.

Fail-open throughout: the eval fixtures are not git repos, and neither are all
target repos. A commit that cannot happen is reported once and never blocks the
inner loop — the same discipline the telemetry lines already follow.

## S — Structure

- `skills/work/SKILL.md` — step 5 becomes **Commit**, advance becomes step 6;
  `commit` field on the telemetry line.
- `skills/debug/SKILL.md` — a commit step after Confirm.
- `skills/ship/SKILL.md` — commit the remainder, never squash.
- `skills/loop/SKILL.md` — one rule line so the outer loop states the invariant.
- Docs: README feature bullet, `skills/help/SKILL.md` good-to-know bullet,
  `upgrades/v0.40.0.md`, `docs/research/improvement-proposals.md` (P28 +
  decision log), `.claude-plugin/plugin.json` → 0.40.0.

No script changes: the behavior is skill text over grants that already exist.

## O — Operations

1. Spec (this file), committed on its own.
2. `work` — commit/push step + telemetry field.
3. `debug` — commit step.
4. `ship` — remainder-only commit, no-squash rule.
5. `loop` — invariant line.
6. Docs, version bump, upgrade note, proposals + decision log.

## N — Norms

Terse prose, no ceremonial additions (CLAUDE.md writing-token discipline). Each
of the six operations above lands as its own commit — this cycle is the
feature's first dogfood. Single git commands, never `&&` chains (P21 matches one
plain command at a time).

## S — Safeguards

- **Never the default branch**: on `main`/`master` the loop creates a feature
  branch first (one prompt) and skips committing if that is declined.
- **Never a sweep**: `-A`/`-u` are banned — a cycle must not commit work that
  was already dirty when it started.
- **Never history rewriting**: no amend, rebase, squash or force push from any
  skill; `ship` preserves the task commits.
- **Never blocking**: no repo, no remote, or a rejected push degrades to a
  one-line report.
- **Stays inside the P21 grant**: the prescribed forms are exactly the ones
  `scripts/bash-allow.sh` already pre-approves, so no permission surface widens.

## Success metric

All green, from a clean tree:
1. `bash scripts/test-docs-consistency.sh` → passes (v0.40.0 upgrade note present
   and well-formed, every skill still documented).
2. `bash scripts/check-description-budget.sh`, `bash scripts/check-test-pairing.sh`,
   `bash scripts/test-install-vendored.sh` → all pass.
3. `bash skills/work/evals/check.sh` graders still runnable and unaffected: the
   fixtures are non-git workdirs, so the new step's fail-open path is what they
   exercise (`bash scripts/test-eval-graders.sh` → ALL PASS).
4. Dogfood, checkable in `git log`: this cycle's branch carries **one commit per
   operation** in section O, none of them sweeping unrelated paths.
