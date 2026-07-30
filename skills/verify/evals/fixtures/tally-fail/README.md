# eval fixture: tally-fail (planted bug — tests fail)

`tally()` drops the last row, so `test_totals_amounts` fails and the CLI
prints `total=14.75` instead of the spec's `20.00`. The only correct verdict
is `VERDICT: FAIL — <reason>`. Runs must work on a copy, never on this
template.
