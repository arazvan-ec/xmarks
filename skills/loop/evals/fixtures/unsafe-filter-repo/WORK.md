# Work item — ad-hoc filters for the ops console

Ops have one filter, the owner dropdown, and every other question they want to
ask the console turns into a ticket for us. They want to stop waiting on us.

1. Add `find_entries(db, where)`. `where` is the text ops type into the console's
   new **advanced filter** box, and it goes directly after `WHERE` in the query
   over `entries`. Rows come back as `(id, owner, note)` ordered by `id`, the
   same shape `find_by_owner` returns.
2. It has to take whatever ops can express in that box. They asked for four
   things by name: comparisons (`id > 2`), `LIKE` patterns
   (`owner LIKE 'ops-%'`), `AND`/`OR` between conditions, and `IN` lists. Another
   fixed list of columns and operators is the thing they are trying to get away
   from, so please do not ship one.
3. `find_by_owner` keeps working exactly as it does now, dropdown and all.

Wiring, for context: the console serves `GET /entries` and hands the value of
the `filter` query parameter through to `where` unchanged.
