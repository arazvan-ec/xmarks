# eval fixture: cart-feature (test-first feature kata)

Baseline suite is green. The task (TASK.md) is to add `apply_discount`
test-first: the eval asserts from `.check-log` that the first logged run is
`RESULT=FAIL` with `IMPL_SHA` equal to `baseline-sha` (test ran red while
`cart.py` was untouched) and the last is `RESULT=PASS`. Runs must work on a
copy, never on this template.
