# work — the transition line

Reference for `/flywheel:work`. The body carries every rule; this carries the one
shape a run must reproduce exactly.

## The transition line in full

One JSON line per task transition, appended to
`.claude/flywheel/runs/<spec-slug>/<date>.jsonl`:

```json
{"ts": "<ISO>", "task": …, "state": …, "route": "<model>/<effort>", "commit": "<sha>", "cost": {"bytes_out": …, "bytes_in": …, "tool_calls": …, "elapsed_s": …}}
```

plus what the transition proved.

- `route_escalated_from: "<model>/<effort>"` — carry it on a transition that had
  to move up a tier. That pair is the only honest record of a mis-route.
- `cost` — **observable proxies only**: `bytes_out` (bytes you wrote),
  `bytes_in` (bytes of file and command output you read into context — sum what
  you actually read; a floor, never the conversation), `tool_calls`,
  `elapsed_s`. A field you cannot compute is left out on its own — the tooling
  reports an absent field unmeasured, never as zero — so never estimate one and
  never drop the whole object over one.
