# eval fixture: cart-bugfix (regression-test-first kata)

Baseline suite is green but doesn't cover the reported bug (BUG.md). The eval
asserts from `.check-log` that a regression test reproduced the bug (first
logged run `RESULT=FAIL` with `IMPL_SHA` equal to `baseline-sha`) before
`cart.py` changed, and that the last run is `RESULT=PASS`. Runs must work on
a copy, never on this template.

The suite is reachable **only** through `./run-tests.sh`: `test_cart.py` refuses
to import unless `KATA_HARNESS=1`, which only the runner sets, and the refusal
names the runner. That is deliberate — it means the prompt does not have to
mention tests or a runner (which was hinting the method and made both eval arms
score 8/8), while `.check-log` still always exists for grading. Discovery is the
natural one: `ls`, or a clear error if you guess `python3 -m unittest`.
