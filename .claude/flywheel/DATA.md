# DATA.md — this repo's data-persistence strategy

Declared once per repo (see `skills/process/SKILL.md` §1); every `/flywheel:run`
writes through this. Detected 2026-07-13: no external datastore exists here — no
`DATABASE_URL`, no ORM config, no `supabase/`, no DB service in compose. This
repo's durable records are **git-native markdown documents**, so that is the
store processes persist to.

## Store

The git repository itself — markdown files, committed. Two record kinds:

- **Improvement proposals + decision log** — `docs/research/improvement-proposals.md`
  (the living backlog; the repo's system of record for "what should change and why").
- **Design journal** — `docs/research/journal.md` (dated narrative entries).

## Access

Direct file `Write`/`Edit`, then `git add` so the record is committed with the
work. No DB client, no MCP server. A write has "landed" when it is present in
the file **and staged** (`git status --short` shows it).

## Schema

`docs/research/improvement-proposals.md`:
- `## Status` table — one row per proposal: `| P<n> | title | status-emoji + text | next action |`.
- `## Priority overview` table — `| P<n> | title | Value | Effort | Risk | Version bump? |`.
- One `## P<n> — <title>` section per proposal: **Why / What / Files / Open questions**,
  plus **Decisions** once acted on.
- `## Decision log` — append-only, dated (`YYYY-MM-DD`), **newest at the bottom**.

`docs/research/journal.md`: dated `## YYYY-MM-DD — <thread>` sections, narrative prose.

`.claude/flywheel/runs/<slug>/<YYYY-MM-DD>.html`: machine-issued run telemetry
reports (task ledger + timings, gates, findings, maturation) — one per run,
regenerated at every task-state transition and republished as a private
artifact so the owner watches progress live (see each contract's Progress
reporting section).

## Conventions

- **Idempotency key** for a process run: `(run date, process slug, scope)` — a
  same-day rerun updates its own decision-log entry instead of appending a duplicate.
- Proposal numbers `P<n>` are sequential and **never reused or renumbered**.
- The decision log is **append-only**: never edit or delete prior entries.
- Docs-only writes (`docs/research/**`, `.claude/flywheel/**`) need **no** plugin
  version bump. Any change under `skills/`, `agents/`, `hooks/`, or `scripts/` is
  a **release** (version bump + `upgrades/v*.md`) and is out of bounds for a
  process run — a run may only *propose* it.
- Destructive operations (deleting proposals, rewriting log history, force-push)
  are banned without explicit human confirmation.
