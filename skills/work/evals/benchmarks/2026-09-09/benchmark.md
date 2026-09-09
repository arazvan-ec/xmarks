# `work` eval iteration — 2026-09-09 (release gate for P28 / v0.40.0)

**Verdict: the release gate passes. The suite has a defect, and it is not this
release's.**

## What was run

Six fresh-context subagent runs against clean fixture copies, graded only by
`skills/work/evals/check.sh`:

| # | Eval | Arm | Workdir | Grader |
| --- | --- | --- | --- | --- |
| 1 | 1 feature-test-first | with_skill (v0.40.0) | non-git | 7/7 ✅ |
| 2 | 2 bugfix-regression-test-first | with_skill (v0.40.0) | non-git | 5/6 ❌ |
| 3 | 2 | with_skill (v0.40.0) | non-git | 5/6 ❌ |
| 4 | 2 | with_skill (v0.40.0) | non-git | 5/6 ❌ |
| 5 | 2 | **control: pre-P28 text** (`origin/main`, v0.39.1) | non-git | 5/6 ❌ |
| 6 | 1 | with_skill, **out-of-suite** | `git init` + 1 commit | 7/7 ✅ |

## The red assertion, and why it does not block v0.40.0

Eval 2's first assertion — *"first `.check-log` entry is `RESULT=FAIL` with
`IMPL_SHA` equal to `baseline-sha`"* — failed in every eval-2 run. The cause is
the same each time: the executor ran `./run-tests.sh` once to confirm a green
baseline **before** writing the regression test, so entry 1 is `PASS@baseline`
and the red is entry 2.

```
RESULT=PASS IMPL_SHA=8b44f02e8e4f2e3b   ← baseline check, pristine impl
RESULT=FAIL IMPL_SHA=8b44f02e8e4f2e3b   ← the red, still pristine impl
RESULT=PASS IMPL_SHA=c47feecd5f88bd5d   ← green, impl changed
```

The property the expectation states in prose — *the regression test reproduced
the bug before `cart.py` changed* — holds in all four traces. The mechanization
of it does not.

Run 5 is what makes this actionable rather than arguable: given the **pre-P28**
skill text, a fresh executor produced the identical log shape and the identical
single failure. So the red is pre-existing drift between the grader and current
executor behaviour, not a regression introduced by atomic commits. Three
consecutive reproductions rule out n=1 noise in the other direction.

**Deliberately not fixed here.** Loosening an eval assertion inside the very
release that assertion is gating is the move `P26` exists to prevent. The
finding is recorded for the owner; the candidate fix — assert that a
`FAIL`-at-pristine-`IMPL_SHA` entry exists with no changed-sha entry before it,
which still fails an implement-first workflow and still fails on an untouched
fixture — is a separate decision, and a separate release.

## What the runs prove about P28 itself

- **Fail-open is real, not aspirational.** Five runs sat in non-git workdirs.
  Each reported the commit step failing open once and carried on; none treated
  it as a blocker, and none invented a commit it had not made.
- **The git-initialized observation run (6)** is the only direct evidence of the
  new step executing, since the committed fixtures are plain directories:
  - it was on the default branch, so it created `task3-apply-discount` first
    instead of committing to `main`;
  - it committed with the pathspec form, and the untracked `.check-log` and
    `__pycache__/` **stayed out of the commit** — the exact sweep the rule
    exists to prevent;
  - the push was impossible (no remote) and it said so once rather than
    stalling.

## Limits of this evidence

- The suite still does not exercise the cycle telemetry at all — `work` writes
  JSONL only inside a `/flywheel:loop` cycle, and every executor independently
  reported writing none. The new `"commit": "<sha>"` field is therefore
  **unverified by this suite**.
- No `without_skill` arm: the release gate needs the regression signal only, and
  2026-07-30 already established these katas do not discriminate.
- Run 6 is an observation, not part of the eval definition. It is reported as
  such and should not be counted as a suite result.

## Addendum — the suite defect, resolved as v0.40.1 (same day)

The owner's call on the finding above: fix the mechanization, in its own
release, not in the one it was gating.

`skills/work/evals/check.sh` now asserts **a `RESULT=FAIL` at the pristine
`IMPL_SHA` with no changed-sha entry before it**, which is what the expectation
always said in prose. Written test-first: two cases went into
`scripts/test-eval-graders.sh` and the leading-baseline one was red before the
grader changed.

Re-graded under the fixed grader, with no re-runs — the same six workdirs this
iteration produced:

| Workdir | Eval | Before | After |
| --- | --- | --- | --- |
| eval1 | 1 with_skill | 7/7 | 7/7 |
| eval2 | 2 with_skill | 5/6 | **6/6** |
| eval2b | 2 with_skill | 5/6 | **6/6** |
| eval2c | 2 with_skill | 5/6 | **6/6** |
| eval2d | 2 control (pre-P28) | 5/6 | **6/6** |
| obs-git | 1 observation | 7/7 | 7/7 |

The guards that make the grader worth having are unchanged and still fire: red
on an untouched fixture, red on test-after, red on a log that never went red.
