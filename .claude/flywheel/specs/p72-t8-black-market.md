# P72 T8 — Black Market

**Status:** signed 2026-10-04 (autonomous run).

## R — Requirements

Escape hatches exist so a rule can bend with a reason (`SKIP_*=<reason>`,
`Release-Exception:`, allow/baseline files). Each is debt with a reason on it
(CLAUDE.md, invocation budget). Nothing totals that debt. The Black Market keeps
two ledgers:

- **contraband** (live): a Bash command carrying `SKIP_X=<reason>`, `--no-verify`,
  or a commit message with `Release-Exception:` is recorded with its reason in
  `$.store` (last 200); a reason of `1`, `true` or empty is *without papers* and
  raises a toast;
- **permits** (standing): `/black-market audit` counts the entries in the repo's
  standing exception files — `scripts/*allow*.txt`, `scripts/*baseline*.txt`,
  `scripts/invocation-budget.txt` minus its defaults — plus `Release-Exception`
  trailers in `git log`;
- `/black-market` shows both; the status line shows contraband count.

Out: blocking (Social Credit already scores skips; one rule, one enforcer).

## A — gate (reshaped by measurement)

Measured before building: this repo's history has **0** `Release-Exception`
trailers and **0** `SKIP_*=` commits, but **31** telemetry-baseline exemptions,
**6** fixture-leak allows and **4** budget exceptions. The debt is standing, not
one-off, so the audit of permit files became the main ledger and live
contraband the secondary one.

## S — Success metric

`bash scripts/check-mods.sh origin/main black-market` green: contraband with
reason recorded, papers-less flagged, trailer recorded, audit counts permit
files (comments/defaults excluded) and trailers, persistence.
