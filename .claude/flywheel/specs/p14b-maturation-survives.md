# Spec: P14 slice 2 — the maturation survives the session, and the list answers

**Slug:** `p14b-maturation-survives` · **Created:** 2026-09-14 · **Backlog:** P14 (second of its 2–3 releases)
**Status:** shipped as **v0.50.0** — signed at the gate 2026-09-14. Metric
**PASS**. Eval gate green: `run` eval 1 (7/7, with the three new maturation
assertions) and eval 4 (7/7, no regression from the step-1 listing).

**Prime:** `skills/run/SKILL.md` step 4 ("Stage the contract if you changed it")
and step 1; the P14a plan's Revision 2 (why T5 was deferred and what it costs);
`scripts/invocation-budget.txt` (the ~500 B calibration finding);
`.claude/flywheel/LEARNINGS.md` → *"a ratchet that fires on ordinary work is
miscalibrated"* for the order to try when a ceiling blocks.

## R — Requirements

1. **A matured contract is committed, not left staged.** Step 4 today ends with
   *"Stage the contract if you changed it."* In an ephemeral session — the
   documented Claude Code web path, and every agent run — staged is **lost**,
   while the datastore row the run wrote survives. So the process keeps the
   result and forgets the lesson: the exact inversion of what a maturing runtime
   is for. Observed twice on 2026-09-14: both eval executors staged the contract
   and stopped there, correctly following the skill.
2. **A bare `/flywheel:run` lists the repo's contracts** — name + the first
   `## Purpose` sentence — instead of parsing an empty slug and telling the user
   to *define* a process. Only with no contracts at all does it point at
   `/flywheel:process`. Deferred from slice 1 for want of 140 B.
3. **`run`'s body ceiling is set by the measured rule, not by the diff.** The
   body is 4,746 B of nothing but rules, against 4,800. Requirements 1 and 2 add
   ~370 B and there is no argument or catalogue left to move — slice 1 took both.
   The ceiling moves to the post-slice body plus ~500 B (the measured cost of one
   feature), rounded up to the hundred, and the exception says *why* in the
   budget file.

**Out of scope, deliberately** — the rest of P14, which is its slice 3:
`flywheel_runs` bookkeeping, approval tiers by stakes×reversibility, process→
process composition, batch inputs, run→spec escalation, `sync` over contracts,
`spec`'s prior-art step reading DATA.md, the `process=<slug>` ledger key, the
`docs/proactive-loops.md` rewrite, and generalizing `agents/evaluator.md`.

**Rejected for this slice: `status: active|deprecated` + `superseded-by`.** It
pairs naturally with requirement 2 — a listing should not offer a superseded
contract — but nothing in this repo has ever deprecated one, so the rule would
be written for a case no one has met. That is the speculative block `CLAUDE.md`
bans. It earns its place the first time a contract is actually retired.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| maturation commit | the contract change, committed with its own message | `skills/run/SKILL.md` step 4 |
| contract listing | name + first Purpose sentence, read at print time | `skills/run/SKILL.md` step 1 |
| ceiling | `run body`, set by the ~500 B rule | `scripts/invocation-budget.txt` |

## A — Approach

**The commit is the run's, so the run makes it.** `work` already commits each
task at its green edge under the P21 grant (`git commit -m … -- <paths>`,
force-free), and step 4's change is exactly that shape: one file, one logical
change, a message the run can write from the Improvement log entry it just
appended. Nothing new is granted and nothing new is invented — the rule that
governs `work`'s commits is applied to the one commit `run` already has reason
to make.

**Pathspec, and only the contract.** The run has also written a datastore row
and telemetry; those belong to the repo's own conventions, not to this commit. A
`git add -A` here would sweep the datastore into a commit labelled "mature the
contract", which is the sweep `work`'s commit discipline bans for the same
reason.

**Fails open, like every other write in `run`.** No repo, no remote, the default
branch with a new feature branch declined — the run says so once and carries on.
A maturation that cannot be committed is still a maturation; losing it must never
cost the result that was already persisted.

**Rejected: committing the datastore row too.** Tempting, since the row is the
point of the run. But DATA.md decides how results are persisted — for the eval
fixture, "staged" *is* the declared proof of a landed write — and a skill that
committed it would override the repo's own strategy. The contract is the
plugin's artifact; the row is the repo's.

**The listing reads frontmatter at print time**, exactly as the banner does
since v0.49.0 — no generated index to go stale, and the persistence line is
never printed, since that is where a connection string lives.

## S — Structure

- `skills/run/SKILL.md` — step 4 commits; step 1 lists on an empty slug.
- `scripts/invocation-budget.txt` — `run body` by the rule, with its reason.
- `skills/run/evals/` — eval 5: a run whose maturation must survive, asserted on
  git rather than on the working tree.
- `scripts/test-eval-graders.sh` — eval 5 in the red-on-untouched list. (Its
  hand-maintained shape is a known defect, recorded in P38's commit; not fixed
  here.)
- `.claude-plugin/plugin.json` + `upgrades/v0.50.0.md`.

## O — Operations

1. Eval 5 and its grader **first**, seen red: today's skill stages and stops, so
   `git log` shows no commit touching the contract.
2. Step 4's commit rule; eval 5 green.
3. Step 1's listing branch.
4. Set the ceiling from the measured body. **The budget gate is red between
   steps 2 and 4 by design** — stated here so it is not mistaken for a
   regression.
5. Eval gate: `run` evals 1, 4 and 5 — 1 for no regression, 4 because step 1
   changes again, 5 for the new behaviour.
6. Full suite, every `check-*.sh`, then bump and upgrade note.

## N — Norms

Prose in one skill plus one budget line. The commit must be plain and
force-free so it stays inside the existing P21 grant — a maturation that
prompted for permission would block an unattended run, which is the runtime this
feature exists to serve.

## S — Safeguards

- **The commit is scoped by pathspec to the contract file.** Asserted in the
  eval: the commit's diff touches `processes/<slug>.md` and nothing else.
- **What this gate cannot see:** the eval proves a commit was made in a repo
  that has one. It cannot prove the maturation survives a container that dies
  mid-run, nor that anyone pushes it — a committed-but-unpushed improvement is
  still lost when the clone is reclaimed. Pushing is deliberately *not* added:
  it needs a branch decision the run has no business making alone.
- **The result outranks the lesson.** If the commit fails, the run reports it
  and still reports the persisted result. Losing a maturation is a cost; losing
  the row would be a regression.
- **No new permission surface.** If the commit would prompt, the grant is wrong
  and the fix is the grant, not a wider command.

## Success metric

One command, exit 0 = PASS:

```bash
bash scripts/check-invocation-budget.sh \
  && bash scripts/test-eval-graders.sh \
  && bash scripts/check-fixture-leaks.sh \
  && bash scripts/test-docs-consistency.sh \
  && grep -qi 'commit' skills/run/SKILL.md \
  && grep -qi 'no slug' skills/run/SKILL.md \
  && grep -qE '^run body=[0-9]+$' scripts/invocation-budget.txt
```

Plus the eval gate, which is the only thing that can see the behaviour: **`run`
evals 1 and 4 green** before the version bump.

The decisive assertions live in **eval 1** (see the Revision below for why not a
dedicated eval) and are stated against **git**, not the working tree: HEAD's copy
of the contract carries the dated Improvement log entry, nothing about it is left
staged, and the commit touching it carries one file. Asserting "the file changed"
would pass on the staged-and-lost behaviour, which is the whole defect.

## Revision (2026-09-14, during work) — the eval moved, and why

**Eval 5 is gone; its assertions live in eval 1.** The fixture built for it made
the run's own contract self-contradictory, and that **blocks** the run — while
step 4 matures only *"after a successful run"*. So no assertion could have made
eval 5 test the commit rule: the path it grades is one the skill never opens. The
plan named this as T1's risk and it landed anyway.

Eval 1 is where the rule is reachable, because its run succeeds, and two runs on
that fixture matured spontaneously (a `|` in a markdown cell; an undefined
insert position). Red→green is proven on real runs of the same skill: the pre-T3
run matured and staged (3 FAIL), the post-T3 run matured and committed (7/7).

**The finding that outlives this slice, recorded as a follow-up rather than
fixed:** two competent executors split on the blocked fixture. One proceeded with
the true value and matured the bound; the other refused to emit a
non-conforming output *and* refused to mature, holding that a schema change with
a version bump is not a blocked run's call. The second reading is the correct one
on the skill as written — but the skill says **nothing** about a run blocked by a
defect in its own contract, and that silence is a real gap. It is a new
requirement, so it belongs to slice 3, not here.