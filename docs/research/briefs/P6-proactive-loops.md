# Brief: P6 — time-based / proactive loop guidance

**One-liner:** a docs page teaching users to compose flywheel's discipline with
Claude Code's time-based and proactive loops (`/loop`, `/schedule` routines) —
docs-first, no runtime skill yet.

**Prereqs:** none. **Branch:** `claude/flywheel-p6-proactive`. **Version:** none if
docs-only (see below).

**Read first (bounded context):** this brief + [`../claude-code-loops.md`](../claude-code-loops.md)
(§2 `/loop`, §3 routines, §5 workflows).

## Goal & decision

flywheel covers only turn-based loops. Rather than build a runtime skill first,
**ship guidance**: how to run flywheel's `verify`/`review` on a schedule, babysit
a PR with `/loop`, and compose `/schedule` + `/goal` + verification for proactive
streams. Respect the real caps (routines: 1-hour min; `/loop`: 50 tasks / 7-day
expiry).

## Files to change

- **New** `docs/proactive-loops.md` — the guide. Cross-link from `README.md`.
- **Docs-only → no version bump, no `upgrades/` note** (a `docs/` file isn't
  vendored and isn't checked by docs-consistency). If you later add a runtime
  skill (e.g. `/flywheel:watch`), *that* becomes a normal release.

## Acceptance criteria

- `docs/proactive-loops.md` exists, is accurate against the caps in
  `claude-code-loops.md`, and is linked from the README.
- `bash scripts/test-docs-consistency.sh` green (it will be — no skill/agent/version
  change).

## Starter prompt (paste into a fresh session)

> Implement flywheel proposal **P6 (proactive loop guidance)** on branch
> `claude/flywheel-p6-proactive`. Read only `docs/research/briefs/P6-proactive-loops.md`
> and `docs/research/claude-code-loops.md`. Write `docs/proactive-loops.md` (a guide
> to composing flywheel with `/loop`, `/schedule` routines, `/goal`, and workflows,
> honoring the documented caps) and link it from the README. Docs-only: no version
> bump. Run `bash scripts/test-docs-consistency.sh`. Commit and push. No PR unless asked.
