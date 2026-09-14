# The progress ledger, extensions, and why the agent is the runtime

Reference for `/flywheel:run` steps 0 and 1. The body states the rules; this states
the mechanics.

## Why there is no static backend

There is no static backend here — **you are the execution**. You follow the contract's fixed rules the way a service would, apply judgment only where the contract permits, and land the result in the repo's real datastore.

## Step 0 — the progress ledger in full

At run start, materialize each contract Rule as a visible task in the host task system (one task per Rule, in order) and update states (`pending → in_progress → completed`, `blocked` on gates/failures) **at every transition**. Telemetry is two-tier: append **one JSON line per transition** to `.claude/flywheel/runs/<slug>/<date>.jsonl`, and render the HTML report `.claude/flywheel/runs/<slug>/<date>.html` from that JSONL only at gates/blockers and at the final report — declared repo extensions may adjust the filenames (e.g. a per-profile suffix) — (ledger + timings, gates, unit telemetry, outputs, verdict, and a **cost block labelled as proxies** — totals of the per-transition `cost` fields `bytes_out` / `tool_calls` / `elapsed_s`, never tokens — never secrets); republish the artifact to the same stable URL each time the HTML is rendered, never per Rule transition. Chat is for gates, blockers, and the final report only — routine progress lives in the ledger. If the task system or artifact publishing is unavailable, proceed anyway and say so in the final report (fail-open, never block the run).

## Step 1 — what a declared extension may add

If the contract's frontmatter declares `extensions:`, read each `.claude/flywheel/extensions/<name>.md` and honor it for the whole run — extensions may add inputs (parse their tokens, e.g. `profile=<id>`, with the extension's defaults), output namespacing, isolation rules, telemetry naming, or capability fallbacks. Extensions never override the contract's Rules, Output schema, or Guardrails.

## Step 4 — what qualifies as a refinement

- A rule was ambiguous and you had to make a call → tighten the rule so the next run is deterministic.
- A recurring input shape, edge case, or data-quality issue the Rules don't mention → note the guard.
- A judgment heuristic that measurably improved the output → promote it from ad-hoc to written latitude.

## Probing the write path (step 1)

Read-only, always: the probe proves the path is there, it never proves it by
using it. A probe that writes is a mutation the Guardrails did not approve.

| Store | Probe | Reached |
| --- | --- | --- |
| PostgreSQL / MySQL | `psql "$URL" -c '\d <table>'` (or `SELECT 1 FROM <table> LIMIT 0`) | connection opens **and** the target table exists |
| Supabase / MCP | the server's list-tables or a `LIMIT 0` select | the project answers and the table is listed |
| ORM / repo script | the script's own read path (`findFirst`, `SELECT … LIMIT 0`) | it returns without connecting errors |
| Git-native file | the file's directory exists, is writable, and is inside the repo | `test -w`, and the path does not escape the worktree |

The concrete tool is whatever DATA.md's **Access** names — the probe uses that
one, never a different client that might succeed where the run's own would fail.

On failure, the run appends one transition with a `blocked` state naming the
check that failed and the command that would confirm it, then stops. It does not
retry, and it does not choose another store.
