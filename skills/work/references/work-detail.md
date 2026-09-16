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
  `bytes_in` (bytes of tool output that entered context; a floor, never the
  conversation), `tool_calls`, `elapsed_s`. A field you cannot compute is left
  out on its own — the tooling reports an absent field unmeasured, never as
  zero — so never estimate one and never drop the whole object over one.
- **Read `bytes_in` and `tool_calls`; do not recall them.** The meter records
  every call as it happens, so ask it rather than reconstructing afterwards:
  `bash "${CLAUDE_PLUGIN_ROOT}/scripts/read-meter.sh" --since <previous
  transition's ts>` (`bash .claude/flywheel/bin/read-meter.sh` on a vendored
  install). It prints `bytes_in=<N> tool_calls=<N>`, or says **UNMEASURED** when
  no meter ran — in which case omit both fields rather than writing a zero. The
  two fields went unrecorded across the repo's entire history because the rule
  asked for a running total nothing kept.
