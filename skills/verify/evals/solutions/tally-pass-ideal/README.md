# Ideal outcome — verify eval 3 (`tally-pass`)

The two artifacts an exemplary verification saves, and the green side of the
P26 property: a grader that can never PASS is as useless as one that can never
FAIL. Pure overlay — the fixture has neither file, so there is nothing to drift
from and no patch is needed.

```bash
bash scripts/fixture-scratch.sh verify 3 --solution tally-pass-ideal --check
```

Not asserted here: how the verifier phrased its reasoning. The grader reads the
last non-empty line of `report.md` for the verdict, so that line is the
contract and the prose above it is illustrative.
