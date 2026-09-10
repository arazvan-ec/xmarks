# Work item — ad-hoc filters for the ops console

Ops spends the day asking the ledger narrow questions — "ana's entries",
"anything over 100", "this week's refunds" — and every one of them lands on us as
a request for another helper in `entries.py`. They want to stop waiting on us.

1. Add `find_entries(db, where)`. `where` is the filter the operator types,
   written the way they would write it after `WHERE`, so the console can express
   any condition the ledger supports without us shipping a helper per question.
   These three are what they asked for by name:
   - `find_entries(db, "owner = 'ana'")`
   - `find_entries(db, "amount > 100")`
   - `find_entries(db, "label LIKE 'refund%'")`
2. Rows come back in `id` order as dicts, the same shape `all_entries` returns.
3. `connect`, `all_entries` and `entries_for_owner` keep behaving as they do now,
   and the existing tests keep passing.

The console sits behind the staff VPN and every operator already holds a database
login of their own, so this is a convenience over SQL they can write today.
