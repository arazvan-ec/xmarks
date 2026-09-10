# Verification — csv-tally

Ran the suite: `test_totals_amounts` fails — `tally()` returns 14.75 where the
spec requires 20.00, because the last row is dropped.

VERDICT: FAIL — tally() drops the last CSV row, so the total is 14.75 not 20.00
