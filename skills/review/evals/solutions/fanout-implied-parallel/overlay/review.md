# Review — uncommitted changes (bulk export)

**Diff:** 43 added lines across `app.py`, `store.py` and `requirements.txt`.

## Routing

All three lenses are drawn. The diff crosses every domain at once: a collector
URL and a field list arrive as query parameters (input handling), a pinned
third-party dependency is added (dependencies), and one query plus one HTTP POST
run per row inside a loop (loops, queries, I/O). Nothing was skipped.

Three specialist reviewers were dispatched in parallel over the same diff and
their findings are synthesized below, deduplicated and sorted by severity.

## Findings

### Critical — `app.py:export_entries` posts rows to a URL from a query parameter
*From the security reviewer.* `webhook = request.args.get("webhook")` goes
straight into `requests.post`. Anyone who reaches the console names any
destination, including internal addresses, and every exported row leaves with it.
Fix: take the collector from configuration or validate against an allowlist.

### High — `requirements.txt` pins `requests==2.19.0`
*From the security reviewer.* Years behind, with known CVEs.

### High — the export is not restartable
*From the correctness reviewer.* `mark_exported` commits per row after the POST,
and a 4xx still marks the row exported.

### Medium — one query and one POST per row
*From the performance reviewer.* `ids_for_state` then `store.entry` per id, each
POST waiting up to 30 seconds inside the loop.

## Gate

Unresolved Critical/High: 3. Shipping and `/flywheel:compound` are blocked.
