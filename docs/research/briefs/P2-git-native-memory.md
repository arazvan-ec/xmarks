# Brief: P2 — git-native memory (first release)

**One-liner:** replace the whole-file `LEARNINGS.md` reload with typed entries +
budgeted, relevance-based injection, and add `/flywheel:recall` for on-demand
lookup — pure markdown, no DB.

**Prereqs:** none. **Blocks:** P3. **Branch:** `claude/flywheel-p2-memory`.
**Version:** bump to the next unreleased (0.10.0 at time of writing).

**Read first (bounded context):** this brief + [`../git-native-memory-design.md`](../git-native-memory-design.md)
(the locked design). You do NOT need the chat history.

## Goal & locked decisions

Give claude-mem-style selectivity while staying markdown-only. Locked decisions:
grep-live (no `.tsv` index yet); **defer** semi-auto staging; **defer** interop;
relevance scoring by branch/files/recency for v1. This release ships **three
things only**: typed entry format, selective injection, and `/recall`.

## Files to change

- `skills/compound/SKILL.md` — emit each learning in the typed format (§1 of the
  design): an `## <type>: <title>` header + a greppable metadata comment
  `<!-- fw: type=…; date=…; files=…; spec=…; pr=…; branch=… -->` + the body.
- `scripts/session-start.sh` — replace the blind ~50-line dump with the relevance
  pass (§2): compute branch / changed files / active spec via `git`, score entries,
  inject the **top N=12 full** (env `FLYWHEEL_LEARNINGS_INJECT`) + a one-line
  pointer to the rest. Keep the hook contract: read-only, idempotent, exit 0,
  fail-open.
- **New** `skills/recall/SKILL.md` — `/flywheel:recall <query>`: grep titles +
  metadata (cheap list), expand a chosen entry on demand (§3).
- `README.md` command table **and** `skills/help/SKILL.md` map — add `/flywheel:recall`
  (docs-consistency requires both).
- `.claude-plugin/plugin.json` + `upgrades/v<version>.md`.

## Implementation notes

- Backward-compatible: old free-prose entries still load (treated as low-priority,
  always-eligible). Don't rewrite history.
- No new binary/dependency. `git` and `grep` only.
- `requires-action`: the ledger format is additive and the hook degrades
  gracefully on old entries → **false** (re-vendor picks it up).

## Acceptance criteria

- `/flywheel:compound` writes an entry in the typed format (verify by reading a
  produced entry).
- `session-start.sh`, run in a repo with a multi-entry ledger, injects only the
  relevant budgeted subset + the pointer line (not the whole file); still exits 0
  when there is no ledger / not a git repo.
- `/flywheel:recall <query>` lists matches cheaply and can expand one.
- All three checks green (see release checklist in the briefs README).

## Starter prompt (paste into a fresh session)

> Implement flywheel proposal **P2 (git-native memory)** on branch
> `claude/flywheel-p2-memory`. Read only `docs/research/briefs/P2-git-native-memory.md`
> and `docs/research/git-native-memory-design.md`, then implement it: typed entry
> format in `skills/compound/SKILL.md`, relevance-based budgeted injection in
> `scripts/session-start.sh`, and a new `/flywheel:recall` skill (added to the
> README table and `/flywheel:help`). Follow the release checklist in
> `docs/research/briefs/README.md` (version bump + `upgrades/` note + the three
> tests). Commit and push the branch. Do not open a PR unless asked.
