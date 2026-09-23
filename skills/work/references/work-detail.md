# work — the transition line

Reference for `/flywheel:work`. The body carries every rule; this carries the one
shape a run must reproduce exactly.

## The transition line in full

One JSON line per task transition, appended to
`.claude/flywheel/runs/<spec-slug>/<date>.jsonl`:

```json
{"ts": "<ISO>", "task": …, "phase": "<spec|work|verify|review|compound|ship>", "state": …, "route": "<model>/<effort>", "commit": "<sha>", "cost": {"bytes_out": …, "bytes_in": …, "tool_calls": …, "elapsed_s": …, "max_read": …, "by_tool": {…}}}
```

plus what the transition proved.

- `phase` — which step of the loop this transition belongs to, on **every** line.
  `task` says which transition it is; `phase` is what the ledger is summed by,
  and a line carrying only the first cannot be totalled with the rest (P48).
  Free text, so a pillar-2 run names its Rule phase instead.
- `route_escalated_from: "<model>/<effort>"` — carry it on a transition that had
  to move up a tier. That pair is the only honest record of a mis-route.
- `route_reason: "<why>"` — required with `route_escalated_from`, and on any
  line that drops a planned `+delegate`. One sentence naming the cause, not the
  outcome. `check-route-honored.sh` fails a deviation without it and lists every
  reason, so the ladder's declines can be studied instead of guessed (P55).
- `cost` — **observable proxies only**: `bytes_out` (bytes you wrote),
  `bytes_in` (bytes of tool output that entered context; a floor, never the
  conversation), `tool_calls`, `elapsed_s`, `max_read` (the largest single tool
  response in the window — a maximum, never summed) and `by_tool`
  (`{tool: {bytes, calls}}`; a write tool appears with 0 bytes and a real call
  count). A field you cannot compute is left
  out on its own — the tooling reports an absent field unmeasured, never as
  zero — so never estimate one and never drop the whole object over one.
- **Read the measured fields; do not recall or reconstruct them.** The meter
  records every call as it happens, so ask it:
  `bash "${CLAUDE_PLUGIN_ROOT}/scripts/read-meter.sh" --since <previous
  transition's ts>` (`bash .claude/flywheel/bin/read-meter.sh` on a vendored
  install). It prints `bytes_in=<N> tool_calls=<N> elapsed_s=<N> max_read=<N>
  by_tool=<Tool>:<bytes>/<calls>,…`. The cut is **exclusive**, so the previous
  transition's own timestamp is exactly the right argument: calls bearing it
  belong to the transition that already counted them. On a cycle's
  **first** transition there is no previous ts — pass `--since first`, which cuts
  at the earliest call this session recorded, rather than leaving the line
  unmeasured. If the session did other work before this cycle, that cut predates
  it: pass the explicit ts where the cycle began instead, and never `first`. It says
  **UNMEASURED** when no meter ran; omit the fields then rather than writing a
  zero. `bytes_in` and `tool_calls` went unrecorded across the repo's entire
  history because the rule asked for a running total nothing kept, and every run
  missed `elapsed_s` on line 1 because a commit delta has no previous commit.
