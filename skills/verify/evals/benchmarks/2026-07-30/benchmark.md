# `verify` behavioral eval — iteration 2026-07-30

**First iteration against the clean fixtures** (the v0.36.0 answer-key removal) and
the first graded by a **committed grader** (`skills/verify/evals/check.sh`, P26 /
v0.37.0) instead of regexes re-derived by hand. This replaces
`../2026-07-29/` — see its `COMPROMISED.md` — as the regression baseline.

Skill version 0.37.0 · executor: inherited session model · 1 run per arm.

## Result

| Eval | with-skill | baseline | Failing assertion (baseline) |
| --- | --- | --- | --- |
| 1 planted-bug-failing-tests | **3/3** | 2/3 | verdict line |
| 2 sneaky-runtime-bug-green-tests | **5/5** | 4/5 | verdict line |
| 3 clean-control-must-pass | **3/3** | 2/3 | verdict line |
| **Total** | **11/11 (1.00)** | **8/11 (0.71)** | **+0.29** |

## The delta is one thing, and it is the same thing as last time

All three baseline runs failed **exactly one** assertion — the machine-parseable
last line — and passed every other assertion in every eval. The last lines:

| Run | Last non-empty line of `report.md` |
| --- | --- |
| with 1 | `VERDICT: FAIL — python3 -m unittest exits 1 (test_totals_amounts: 14.75 != 20.0) …` |
| with 2 | `VERDICT: FAIL — python3 app.py data.csv prints rows=2 total=20.00, not the required rows=3 …` |
| with 3 | `VERDICT: PASS` |
| base 1 | `finished.` |
| base 2 | `Do not ship on the strength of the unit tests — they do not cover the line that is broken.` |
| base 3 | `… "someone remembers to run the CLI" into something CI enforces on every change.` |

`COMPROMISED.md` argued the 2026-07-29 delta would survive the leak because the
leaked README stated the required verdict format verbatim and the baseline still
closed in prose. **That prediction held.** With the answer key gone the delta is
+3/11 against +3/10 before — the same finding, now measured on a clean fixture
with a grader anyone can re-run.

## The baseline is not bad at verifying — it is bad at reporting

This is the honest reading, and it matters for how the skill is described:

- **Eval 1** — found `rows[:-1]`, identified the dropped `carla,5.25` row as
  exactly the 5.25 shortfall, confirmed the fix out-of-tree.
- **Eval 2** — found the `n -= 1` double header subtraction, ran the real CLI,
  and explained unprompted *why* the green suite carries no information about a
  metric written in terms of CLI stdout. It also enumerated the off-by-one across
  input sizes (a header-only file printing `rows=-1` while exiting 0).
- **Eval 3** — ran **5-mutant mutation testing** to prove the suite non-vacuous,
  and noted that two output-format mutations pass `unittest` while breaking the
  spec.

None of that is weaker than the with-skill arm. What the skill supplies is the
contract: a verdict on the last line, in a fixed form, that a gate can read
without a human. That is a real and narrow claim, and it is what these numbers
support.

## What these assertions do and do not discriminate

Now trustworthy as a statement, because the leak that made both arms look alike
is gone: **"cites concrete evidence", "ran the real CLI" and "no rationalized
PASS" passed in both arms, in all three evals.** They do not measure the skill
against a strong model. They are regression guards — if a future edit to
`verify/SKILL.md` produces a verifier that stops running the real thing or starts
rationalizing a FAIL, the with-skill arm drops and that is a signal worth having.

`clean-control-must-pass` did its job: neither arm produced a false FAIL on the
clean repo, so the two FAIL verdicts above are not an always-FAIL artifact.

## Caveats

- **1 run per arm.** No variance estimate within an arm; the pass-rate stddevs in
  `benchmark.json` are across evals, not across repeats.
- **`time_seconds` is not a latency measure.** All six executors ran
  concurrently, so wall-clock is contended. `tokens` and `tool_calls` are exact
  per-subagent accounting (with-skill mean 47.1k, baseline 43.9k — the skill costs
  about 3.3k output tokens more per run).
- **Assertion units changed.** The grader emits 11 lines (3+5+3) mechanizing
  `evals.json`'s 9 committed expectations (3+4+2); 2026-07-29 hand-split the same
  expectations into 10. Compare **pass rates** across iterations, never raw counts.
- **A first attempt was voided before grading** — see `VOID-attempt-1.md`.
