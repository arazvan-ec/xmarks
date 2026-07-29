# eval fixture: cart-bugfix (regression-test-first kata)

Baseline suite is green but doesn't cover the reported bug (BUG.md). The eval
asserts from `.check-log` that a regression test reproduced the bug (first
logged run `RESULT=FAIL` with `IMPL_SHA` equal to `baseline-sha`) before
`cart.py` changed, and that the last run is `RESULT=PASS`. Runs must work on
a copy, never on this template.
