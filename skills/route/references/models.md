# Model prices and limits, for comparing two close routes

Snapshot of 2026-06-24, Anthropic first-party API. Prices go stale: refresh them
from the Models API (`client.models.list()`) or the `claude-api` skill before
you quote a number to anyone.

| Alias (`model`) | Model | Input $/1M | Output $/1M | Context | Effort |
| --- | --- | --- | --- | --- | --- |
| `haiku` | Claude Haiku 4.5 | 1 | 5 | 200K | none |
| `sonnet` | Claude Sonnet 5 | 2 | 10 | 1M | low–max |
| `opus` | Claude Opus 5.5 | 4 | 20 | 1M | low–max (default `medium`) |
| `fable` | Claude Fable 5.1 | 10 | 50 | 1M | low–max, thinking always on |

What the numbers mean for a route:

- **Opus costs twice Sonnet, not five times.** At this gap, tier 3 at low effort
  is often cheaper per completed task than tier 2 run twice.
- **Haiku has a 200K context and no effort control.** The `low` in tier 1's
  route is nominal, so inside tier 1 the only lever is the model itself. A
  tier-1 task that must read more than 200K at once goes to tier 2, whatever
  its difficulty.
- **Fable is 2.5× Opus.** It is not a tier in `route-tiers.txt`. Use it only
  when the caller asks for it by name, or when tier 3 at `max` has already
  failed the same check.
- **Lower effort on a newer model often matches higher effort on an older one.**
  Measure the higher tier at low effort before you build a cheaper cascade.
