# Verification — csv-tally

The unit suite is green, so I ran the metric's own command. The CLI prints
rows=2 while the spec metric requires rows=3 — the green tests never exercise
the `__main__` path where the count is decremented.

VERDICT: FAIL — the CLI prints rows=2 against the spec's required rows=3
