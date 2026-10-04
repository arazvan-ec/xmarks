# P77 · P78 · P80 — measure first

**Status:** signed 2026-10-04 (owner: "dale de forma autónoma con todo lo que sigue").

## R — Requirements

P77, P78 and P80 are `needs data`: building their fix now would be guessing.
Their first step is the instrument that collects the data, shipped in the mods
the owner will turn on first:

- **P77**: newspeak counts prose multi-item asks by kind (a count of items, a
  quantifier, a sequence), keeps the last 20 locally for a false-positive review,
  never nudges, and reports them in `/newspeak`. A list is never counted as prose.
- **P78**: resource-committee stores each session's tally of tiers chosen and
  switches; `/committee stats` sums them.
- **P80**: big-brother-token breaks Bash bytes down by command head (`git log`,
  `bash scripts/x.sh`, `cat`) in `/ministry` and each session summary, which also
  records the session's cost.

Each mod bumps to 0.2.0 (check-mods rule). Out: any nudge, hold or route change.

## A — gate

P76's lesson: check that a thing can be changed before filing it. Here, check
that a decision has data before building it. The data has to come from real
use, so these steps only build the meters and leave the decisions alone.

## S — Success metric

`bash scripts/check-mods.sh origin/main newspeak`, `… resource-committee`,
`… big-brother-token` green, with the new arms seen red first.
