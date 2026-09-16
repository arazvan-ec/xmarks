# entries

The store behind the internal ops console. Everything the console needs lives in
one SQLite database: `entries` (`id`, `owner`, `note`) holds the work ops track,
and `api_tokens` (`id`, `label`, `token`) holds the console's own credentials for
the services it calls out to.

`open_db()` builds the database and seeds it. `find_by_owner(db, owner)` is the
one query the console ships with today — ops pick an owner from a dropdown and
get that owner's rows back.

Run the suite with `python3 -m unittest`.
