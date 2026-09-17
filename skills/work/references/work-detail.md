# work — the transition line

Reference for `/flywheel:work`. The body carries every rule; this carries the one
shape a run must reproduce exactly.

## The transition line in full

One JSON line per task transition, appended to
`.claude/flywheel/runs/<spec-slug>/<date>.jsonl`:

```json
{"ts": "<ISO>", "task": …, "phase": "<spec|work|verify|review|compound|ship>", "state": …, "route": "<model>/<effort>", "commit": "<sha>", "cost": {"bytes_out": …, "bytes_in": …, "tool_calls": …, "elapsed_s": …}}
```

plus what the transition proved.

- `phase` — which step of the loop this transition belongs to, on **every** line.
  `task` says which transition it is; `phase` is what the ledger is summed by,
  and a line carrying only the first cannot be totalled with the rest (P48).
  Free text, so a pillar-2 run names its Rule phase instead.
- `route_escalated_from: "<model>/<effort>"` — carry it on a transition that had
  to move up a tier. That pair is the only honest record of a mis-route.
- `cost` — **observable proxies only**: `bytes_out` (bytes you wrote),
  `bytes_in` (bytes of tool output that entered context; a floor, never the
  conversation), `tool_calls`, `elapsed_s`. A field you cannot compute is left
  out on its own — the tooling reports an absent field unmeasured, never as
  zero — so never estimate one and never drop the whole object over one.
- **Read the measured fields; do not recall or reconstruct them.** The meter
  records every call as it happens, so ask it:
  `bash "${CLAUDE_PLUGIN_ROOT}/scripts/read-meter.sh" --since <previous
  transition's ts>` (`bash .claude/flywheel/bin/read-meter.sh` on a vendored
  install). It prints `bytes_in=<N> tool_calls=<N> elapsed_s=<N>`. On a cycle's
  **first** transition there is no previous ts — pass `--since first`, which cuts
  at the earliest call this session recorded, rather than leaving the line
  unmeasured. If the session did other work before this cycle, that cut predates
  it: pass the explicit ts where the cycle began instead, and never `first`. It says
  **UNMEASURED** when no meter ran; omit the fields then rather than writing a
  zero. `bytes_in` and `tool_calls` went unrecorded across the repo's entire
  history because the rule asked for a running total nothing kept, and every run
  missed `elapsed_s` on line 1 because a commit delta has no previous commit.
