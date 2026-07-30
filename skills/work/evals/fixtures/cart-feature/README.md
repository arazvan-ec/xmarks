# eval fixture: cart-feature (test-first feature kata)

Baseline suite is green. The task (TASK.md) is to add `apply_discount`
test-first: the eval asserts from `.check-log` that the first logged run is
`RESULT=FAIL` with `IMPL_SHA` equal to `baseline-sha` (test ran red while
`cart.py` was untouched) and the last is `RESULT=PASS`. Runs must work on a
copy, never on this template.

The suite is reachable **only** through `./run-tests.sh`: `test_cart.py` refuses
to import unless `KATA_HARNESS=1`, which only the runner sets, and the refusal
names the runner. That is deliberate — it means the prompt does not have to
mention tests or a runner (which was hinting the method and made both eval arms
score 8/8), while `.check-log` still always exists for grading. Discovery is the
natural one: `ls`, or a clear error if you guess `python3 -m unittest`.
