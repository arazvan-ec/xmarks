# verify evals — benchmark, iteration 1 (2026-07-29)

1 run per configuration. Assertion grading is programmatic (grade.py in the session workspace); see evals.json for the assertions.

| eval | config | pass | time (s) | tokens | tool calls |
| --- | --- | --- | --- | --- | --- |
| planted-bug-failing-tests | with_skill | 3/3 | 106.7 | 36685 | 11 |
| planted-bug-failing-tests | without_skill | 2/3 | 80.5 | 35508 | 8 |
| sneaky-runtime-bug-green-tests | with_skill | 5/5 | 87.9 | 36251 | 12 |
| sneaky-runtime-bug-green-tests | without_skill | 4/5 | 97.2 | 35763 | 11 |
| clean-control-must-pass | with_skill | 2/2 | 98.3 | 37184 | 14 |
| clean-control-must-pass | without_skill | 1/2 | 66.1 | 33232 | 8 |

**with_skill** pass rate: 1.00 · **without_skill**: 0.66 · delta: +0.34

## Analyst notes

- with_skill runs were executed against the v0.30.0 skill text (re-run after rebasing on main); baselines are skill-independent and kept from the same iteration.
- with_skill passes 10/10 assertions across the 3 evals (planted bug -> FAIL, sneaky runtime bug -> FAIL with the CLI actually run, clean control -> PASS).
- Baseline got the analysis right in all 3 evals but violated the verdict contract every time: the report's last line is prose, not 'VERDICT: ...' — the skill's measured value this iteration is the machine-parseable verdict line plus evidence discipline.
- The 'cites concrete evidence' assertions passed in both configurations — they don't discriminate skill vs baseline alone; they guard against a lazy verifier regression.
- clean-control-must-pass exists to catch an always-FAIL verifier; both configurations correctly passed it (verdict content), baseline only missed the exact last-line format.
