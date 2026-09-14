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
- `cost` — **observable proxies only**: bytes you wrote, tool calls you made,
  seconds since the previous line. A field you cannot compute means omitting the
  whole `cost` object, never estimating it.
