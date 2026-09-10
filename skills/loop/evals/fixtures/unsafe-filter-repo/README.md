# entries

The ledger module behind the ops console. `connect` opens a database and seeds
it, `all_entries` lists everything in `id` order and `entries_for_owner` narrows
to one owner. Rows come back as plain dicts.

Run the suite with `python3 -m unittest`.
