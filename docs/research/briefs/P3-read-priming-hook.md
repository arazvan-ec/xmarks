# Brief: P3 — learnings-aware read-priming hook

**One-liner:** an advisory `PreToolUse` hook that, before reading a file with
recorded learnings, injects those learnings as cheap context first — flywheel's
dependency-free analogue of claude-mem's File Read Gate.

**Prereqs:** **P2** (needs the typed `files=` metadata). **Branch:**
`claude/flywheel-p3-read-priming`. **Version:** next unreleased at merge.

**Read first (bounded context):** this brief + [`../git-native-memory-design.md`](../git-native-memory-design.md)
§6, and skim `hooks/hooks.json` + `scripts/session-start.sh` for the hook style.

## Goal & locked decisions

Surface prior learnings for a file *before* an expensive read. **Advisory, never
blocking** (the read still happens — lower risk than claude-mem's blocking gate).
Must be fast and fail-open (fires on every read).

## Files to change

- `hooks/hooks.json` — add a `PreToolUse` hook on `Read` → a new script.
- **New** `scripts/read-prime.sh` — parse the target path from the hook input,
  grep the ledger for entries whose `files=` contains it, and emit any matches as
  additional context. No match / not a git repo / any error → emit nothing, exit 0.
- `scripts/install-vendored.sh` — vendor the new hook script (it currently vendors
  only `session-start.sh` + `gate.sh`).
- `scripts/test-install-vendored.sh` — its assertions about vendored hook scripts
  must include `read-prime.sh`.
- `README.md` (mention under hooks/state) + `.claude-plugin/plugin.json` +
  `upgrades/v<version>.md`.

## Implementation notes

- Optional size threshold later (claude-mem uses 1,500 bytes); v1 can prime
  regardless of size since it never blocks.
- Keep it cheap: a single grep over the ledger; bail immediately if the ledger is
  absent.
- `requires-action`: **false** if the vendoring test/installer updates ship
  together; note that re-vendoring adds the new hook.

## Acceptance criteria

- Reading a file that has a matching learning surfaces it; reading one without a
  match produces no output and does not error.
- `test-install-vendored.sh` passes with the new hook vendored + executable.
- All three checks green.

## Starter prompt (paste into a fresh session)

> Implement flywheel proposal **P3 (read-priming hook)** on branch
> `claude/flywheel-p3-read-priming`. It depends on P2 being merged. Read only
> `docs/research/briefs/P3-read-priming-hook.md` and
> `docs/research/git-native-memory-design.md` (§6), then add an advisory
> `PreToolUse` hook + `scripts/read-prime.sh`, update the vendoring installer and
> its test to include the new hook, and follow the release checklist in
> `docs/research/briefs/README.md`. Commit and push. No PR unless asked.
