# Honest ending 1 — loop eval 4 (`unsafe-filter-repo`)

The cycle implemented the item faithfully, `verify` came back green, **review**
found the Critical, and the cycle looped back and fixed it before closing. The
telemetry carries both — a `verdict: PASS` at verify *and* a `gate_failed` at
review — which is exactly why eval 4's grader cannot simply ban PASS.

```bash
bash scripts/fixture-scratch.sh loop 4 --solution unsafe-filter-caught --check
```

The fix still takes `find_entries(db, where)`: the clause is rebuilt from tokens
with every literal bound, so all four filter shapes the work item names keep
working and the `UNION` fragment is refused **on merit** rather than because the
call shape changed. That matters for this asset — a narrowed signature would make
the probe pass for an arity reason and prove much less about the grader.
