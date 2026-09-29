# P69 — a closed cycle says what it learned

**Status:** signed 2026-09-28 (owner: "arranca todo el trabajo propuesto de forma autónoma", after the B/A/C recommendation).

## R — Requirements

A cycle that reaches `ship` must leave an explicit compound outcome: either
`/flywheel:compound` ran, or the session recorded that there was nothing worth
compounding and why. Today neither is asked for, and the loss is invisible.

Measured on this repo, 2026-09-28: **14 of 16** run dirs with a `phase: ship`
line carry no `phase: compound` line; **22 of 56** specs are named by no ledger
entry (15 of them shipped). Compound legitimately yields 0 entries sometimes —
so the requirement is an explicit *outcome*, not an entry.

- In: a `Stop` hook, both delivery paths (plugin `hooks.json` + vendored
  installer), `compound` recording its own telemetry line, the escape line.
- Out: judging entry quality; runs no commit on this branch touched; blocking
  before `ship` (review sits between verify and compound, and nagging there
  every turn would be noise).

## E — Entities

| Entity | Where | Role |
| --- | --- | --- |
| run line | `.claude/flywheel/runs/<slug>/*.jsonl` | `phase` field is read |
| ship line | `phase: "ship"` | trigger |
| compound line | `phase: "compound"` (+ `entries: N`, `reason` when N is 0) | satisfies |

## A — Approach

A `Stop` hook, `scripts/compound-due.sh`, reusing `toolbar.sh`'s "branch-only
commits" scope: a slug is due when a `runs/<slug>/*.jsonl` this branch touches
(or leaves uncommitted) has a ship line and no compound line. Due → exit 2 with
the one-line fix. `stop_hook_active` never re-traps.

Rejected: an advisory (exit 0) note. A non-blocking Stop hook's output never
reaches the model, so it would be the same silence with extra cost. Rejected:
triggering on a verify PASS — it nags every turn of review.

## S — Structure

- `scripts/compound-due.sh` + `scripts/test-compound-due.sh` (new pair)
- `hooks/hooks.json` — third `Stop` group
- `scripts/install-vendored.sh` — copy, register, unregister
- `scripts/test-install-vendored.sh` — assert copied + registered once
- `skills/compound/SKILL.md` — append the compound line, `entries: N`
- `skills/work/references/work-detail.md` — `entries` / `reason` fields

## O — Operations

1. Test-first `compound-due.sh`: due blocks; compound line satisfies (with 0
   entries); untouched run ignored; no ship line ignored; stop_hook_active,
   non-git, malformed input → exit 0.
2. Wire both delivery paths; parity gate green.
3. `compound` writes its line; document fields.
4. Release + sweep.

## N — Norms

Mirror `toolbar.sh`: bash wrapper + python heredoc, fail-open, no deps beyond
python3/git. Terse comments. Message names the slug(s) and both fixes.

## S — Safeguards

- **Fail-open**: unreadable file, bad JSON, no git, no python → exit 0.
- **No re-trap**: `stop_hook_active` → exit 0; the escape is one line the
  session can write itself.
- **Scope**: only runs this branch touched — an old run on `main` never blocks.
- **Cost**: one git log + a handful of small files per stop, 5 s timeout.
- **cannot see:** a cycle that stops after verify and never ships.

## Success metric

`bash scripts/test-compound-due.sh` exits 0 with every arm above, **and**
`bash scripts/check-hook-parity.sh` exits 0, **and** `bash scripts/sweep.sh`
ends `N/N passed`.
