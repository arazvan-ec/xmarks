# P72 T4 — Social Credit

**Status:** signed 2026-10-04 (autonomous run).

## R — Requirements

The repo's working rules (edit over rewrite, scripts test-first, no silent gate
skips, commit the evidence) are graded only after the fact, by CI. Score them
live, per citizen, across sessions:

| Act | Points | Rule |
| --- | --- | --- |
| `Edit` | +1 | edit over rewrite |
| `Write` over a file read this session | −5 | edit over rewrite |
| touching `scripts/test-X.sh` before `scripts/X.sh` | +3 | test-first |
| touching `scripts/X.sh` with its test untouched this session | −3 | test-first |
| `git commit` | +1 | evidence lands in git |
| a command carrying `SKIP_…=` or `--no-verify` | −10 | no silent skips |

- The score starts at 100, lives in `$.store`, and shows in the status line.
- Below 80, `prompt.compose` adds a *re-education* section naming the rules
  broken. Its text depends only on *which* rules, sorted, never on the score, so
  it changes rarely and does not bust the prompt cache on every point.
- `/social-credit` lists recent acts; `/social-credit amnesty` resets to 100.

## A — gate

T3 changes nothing here. This step's question: does a `prompt.compose` section
change behaviour? It can't be measured without live sessions. What can be built
now is a section whose cache cost is bounded, so that measuring it later is
cheap.

## S — Success metric

`bash scripts/check-mods.sh origin/main social-credit` green: every act in the
table, persistence, the threshold section appears and is stable, amnesty.
