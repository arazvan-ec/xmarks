# Plan: P14 slice 2 — the maturation survives, and the list answers

Spec: `.claude/flywheel/specs/p14b-maturation-survives.md` (signed 2026-09-14).

## Routing table

| Tier | Route | Tasks |
| --- | --- | --- |
| T2 default | `sonnet/medium` | T2, T3, T4, T5, T6, T7 |
| T3 judgment | `opus/high` | T1 |

**The riskiest step is T1**, and it is not the code — it is designing a fixture
that makes a maturation *evidence-forced without scripting the answer*. Step 4
says refine "only on evidence from this run… never drift for its own sake", and
most runs correctly mature nothing. An eval that demands a refinement from a run
that had no reason to make one would be grading obedience, not judgment; one
that hints at the refinement would grade the hint. The fixture has to contain a
real contradiction the run cannot miss and must decide about on its own.

## The ordering constraint

The budget gate is **red between T3 and T5 by design**: the rules land before
the ceiling is set from the measured body, because setting it first would be
picking a number to fit a diff. Do not read that red as a regression — T5 is
what closes it, and if the body lands somewhere the ~500 B rule cannot justify,
the plan stops and reports.

### T1 — a fixture whose contract contradicts itself in one narrow, visible way
- route: `opus/high`
- risk: highest
- changes: `skills/run/evals/fixtures/maturing-repo/` (copy of `demo-repo`; its Output schema constrains `digit_sum` to `0–27` while Rule 3 computes the sum of four digits, which reaches 36)
- check: a plate of `9999 XXX` (digit_sum 36) is valid per Rule 2's regex and lands outside the schema's own range, so a run must notice; `bash scripts/check-fixture-leaks.sh` green and `diff -r` against `demo-repo` shows only the schema line and nothing that names the refinement
- test-first: no

### T2 — eval 5 and its grader, asserted against git rather than the tree
- route: `sonnet/medium`
- changes: `skills/run/evals/evals.json`, `skills/run/evals/check.sh`, `scripts/test-eval-graders.sh`
- check: red on today's skill — `git log` shows no commit touching `processes/plate-audit.md` even though the file is modified and staged; the grader is also red on an untouched fixture (P26), which the commit assertion gives for free
- test-first: yes

### T3 — step 4 commits the matured contract
- route: `sonnet/medium`
- changes: `skills/run/SKILL.md` step 4
- check: eval 5 green — a commit exists whose diff touches the contract file and **nothing else**; the run still reports the persisted result when the commit fails
- test-first: yes

### T4 — a bare `/flywheel:run` lists the contracts
- route: `sonnet/medium`
- changes: `skills/run/SKILL.md` step 1
- check: `grep -qi 'no slug' skills/run/SKILL.md`; the branch points at `/flywheel:process` only when `processes/` is empty
- test-first: no

### T5 — the ceiling, from the measured body
- route: `sonnet/medium`
- changes: `scripts/invocation-budget.txt`
- check: `bash scripts/check-invocation-budget.sh` green; the new `run body` equals the measured body plus ~500 B rounded up to the hundred, and its comment says why a body of nothing but rules outgrew 4,800
- test-first: no

### T6 — the eval gate (P22 phase 2)
- route: `sonnet/medium`
- changes: `skills/run/evals/benchmarks/<date>/benchmark.json`
- check: `run` eval 1 green (no regression), eval 4 green (step 1 changed again, so the probe must still refuse), eval 5 green — recorded with their counts before any bump
- test-first: no

### T7 — docs, bump, upgrade note
- route: `sonnet/medium`
- changes: `docs/research/improvement-proposals.md`, `.claude-plugin/plugin.json`, `upgrades/v0.50.0.md`
- check: the spec's success metric exits 0, 19/19 `scripts/test-*.sh`, every `check-*.sh`, `claude plugin validate . --strict`
- test-first: no

## Safeguards, re-checked against the spec

- *Pathspec, contract only* — T2's grader asserts the commit's diff touches `processes/<slug>.md` and nothing else, so a `git add -A` that sweeps in the datastore row fails the eval rather than passing quietly.
- *The result outranks the lesson* — T3's check includes the failure path: a commit that cannot be made is reported once and the persisted result is still reported.
- *No new permission surface* — the commit is plain and force-free, inside the existing P21 grant. If it would prompt, the grant is wrong and the fix is the grant.
- *What this gate cannot see* — a commit that is never pushed is still lost when the clone is reclaimed. Pushing is deliberately out of scope; the limitation is stated in the skill, not only here.
- *The hollow-grader trap, already paid for once* — eval 5's assertions are positive by construction (a commit must EXIST), so the P26 invariant is satisfied without a special case. That is the lesson from P14a's eval 4 applied rather than relearned.
