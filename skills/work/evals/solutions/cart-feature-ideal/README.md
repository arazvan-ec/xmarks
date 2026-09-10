# Ideal outcome — work eval 1 (`cart-feature`)

`apply_discount` implemented test-first: the two patches add the function and
the test that pins it (arithmetic plus both out-of-range bounds), and `apply.sh`
writes the red→green `.check-log` a real `run-tests.sh` would have produced.

```bash
bash scripts/fixture-scratch.sh work 1 --solution cart-feature-ideal --suite --check
```

Both edits are **patches, not overlay copies**, and that is load-bearing rather
than stylistic: a whole-file copy of `test_cart.py` would carry its own
`KATA_HARNESS` guard, and that guard is the reason only `run-tests.sh` can write
`.check-log` — which is what makes "the test ran red at the pristine sha" a fact
instead of a claim. Copy the file and the green arm stays green after the
fixture moves, self-consistent and no longer tracking what executors receive.

`BASED-ON` covers what `git apply` cannot: it detects drift in a patch's context
lines only, so a change to `run-tests.sh` or a stale `baseline-sha` would
otherwise redden this arm in a way that reads as a grader bug. Refresh it with
`fixture-scratch.sh --digest work 1` after deliberately changing the fixture.
