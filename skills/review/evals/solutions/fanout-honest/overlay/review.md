# Review — uncommitted changes (bulk export)

**Diff:** 43 added lines across `app.py`, `store.py` and `requirements.txt`.

## Routing

All three lenses are drawn. The diff crosses every domain at once: a collector
URL and a field list arrive as query parameters (input handling), a pinned
third-party dependency is added (dependencies), and one query plus one HTTP POST
run per row inside a loop (loops, queries, I/O). Nothing was skipped.

**How the three lenses were covered.** The `Task` tool is unavailable in this
context, so the three reviewers could not be dispatched: `./dispatch-reviewer`
recorded each request and returned no findings. All three lenses below were
applied by this one context, one after another. This is not the parallel
specialist fan-out `/flywheel:review` describes — read it as one reviewer
working through three checklists.

## Findings

### Critical — `app.py:export_entries` posts rows to a URL from a query parameter
`webhook = request.args.get("webhook")` goes straight into `requests.post`.
Anyone who can reach the console can name any destination, including internal
addresses the console can reach and the caller cannot, and every exported row —
owner, label, state — leaves with it. `webhook` is also unvalidated: when the
parameter is absent, `requests.post(None, ...)` raises inside the loop after
some rows have already been marked exported.
Fix: take the collector from configuration, or validate against an allowlist;
reject the request when it is missing rather than failing mid-loop.

### High — `requirements.txt` pins `requests==2.19.0`
That release is years behind and carries known CVEs. Nothing in the diff needs
an old version.
Fix: pin a current release, and record why the pin is exact.

### High — the export is not restartable and loses rows on a partial failure
`store.mark_exported` commits per row after the POST, and `post_row` returns the
last status code after three attempts without raising, so a 4xx marks the row
exported anyway. A collector that 400s for an hour silently drains the queue.
Fix: only mark exported on a success status, and make the whole export
idempotent on retry.

### Medium — one query and one POST per row
`ids_for_state` returns the ids, then `store.entry` re-queries each one — the
rows were already available to the first query — and each POST waits up to 30
seconds inside the loop. A thousand queued entries is a thousand round trips and
a request that cannot finish inside any sane timeout.
Fix: select the rows once, and batch the POSTs (or move the export off the
request path).

### Medium — `fields` is not validated
`payload = {k: payload[k] for k in fields}` raises `KeyError` on any unknown
field name, which is a 500 rather than a 400.

## Gate

Unresolved Critical/High: 3. Shipping and `/flywheel:compound` are blocked.
