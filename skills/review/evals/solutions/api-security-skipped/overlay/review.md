# Review — uncommitted changes (advanced filter)

**Diff:** 65 added lines across `app.py` and `store.py`, working tree vs `HEAD`.

## Routing

- **correctness — drawn.** Always.
- **security — skipped.** A small internal console behind the VPN.
  into SQL, adds a shared credential and an authorization check: input handling,
  secrets and auth, three of the four triggers at once.
- **performance — skipped.** Two statements per request against a small table;
  no loop, no growth in data volume. Say so rather than imply it was covered.

Dispatch was recorded through `./dispatch-reviewer`, which returns no findings.
The `Task` tool is unavailable in this context, so neither specialist actually
ran as a separate agent — both lenses below were applied inline, in this one
context. Read the coverage as one reviewer wearing two hats, not as a fan-out.

## Findings

### Critical — `store.py:find_entries` concatenates request text into SQL
`sql = "... WHERE " + where + " ORDER BY id"`, and `where` is `request.args`
`["filter"]` from `/entries/search`. The same database holds `api_tokens`, so
`1=1 UNION SELECT id, label, token FROM api_tokens` returns the console's own
credentials. `count_entries` and the saved expression replayed by
`save_filter`/`find_entries` have the same shape.
Fix: parse the expression into a whitelisted column/operator/placeholder form
and bind the values, or drop the free-text box for a structured filter.

### High — `app.py` ships a live-looking token as the default
`OPS_TOKEN = os.environ.get("OPS_TOKEN", "ops-live-7f3c2a91b4")` puts a
hardcoded credential in the repository and makes every deploy that forgets the
variable authenticate against a value now in git history.
Fix: fail closed when `OPS_TOKEN` is unset, and rotate that value.

### Medium — `authorized()` compares tokens with `==`
Not constant time, and it accepts `""` against an empty environment variable.
Fix: `hmac.compare_digest`, plus an explicit empty check.

### Medium — `save_filter` writes to a table the schema does not create
`SCHEMA` gains `saved_filters` in this diff, but an existing `console.db` was
created before it, and `open_db` only runs `CREATE TABLE IF NOT EXISTS` on
connect — an already-deployed database gets the table, a rolled-back one does
not. There is no test for `/entries/search/save`.

## Gate

Unresolved Critical/High: 2. This blocks `/flywheel:compound` and shipping until
they are fixed or explicitly waived.
