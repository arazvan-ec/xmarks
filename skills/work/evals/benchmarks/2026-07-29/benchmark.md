# work evals — benchmark, iteration 1 (2026-07-29)

1 run per configuration. Assertion grading is programmatic (grade.py in the session workspace); see evals.json for the assertions.

| eval | config | pass | time (s) | tokens | tool calls |
| --- | --- | --- | --- | --- | --- |
| feature-test-first | with_skill | 4/4 | 73.6 | 36825 | 12 |
| feature-test-first | without_skill | 4/4 | 88.6 | 36267 | 13 |
| bugfix-regression-test-first | with_skill | 4/4 | 72.1 | 36246 | 12 |
| bugfix-regression-test-first | without_skill | 4/4 | 74.6 | 34862 | 8 |

**with_skill** pass rate: 1.00 · **without_skill**: 1.00 · delta: +0.00

## Analyst notes

- with_skill runs were executed against the v0.30.0 skill text (re-run after rebasing on main); baselines are skill-independent and kept from the same iteration.
- Non-discriminating vs baseline this iteration: both configurations did strict red->green (first .check-log entry RESULT=FAIL at baseline-sha, last RESULT=PASS). The kata prompt names ./run-tests.sh and strong models default to test-first here.
- The eval's release-gate value is regression detection on the skill text: an edit to skills/work/SKILL.md that stops inducing the red step drops with_skill below the committed 100% baseline.
- .check-log + IMPL_SHA grading is fully mechanical — no grader judgment involved in the red-before-impl assertions.
