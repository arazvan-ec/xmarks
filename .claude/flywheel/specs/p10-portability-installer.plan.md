# Plan: p10-portability-installer → release v0.17.0

Spec signed 2026-07-13. **Riskiest step:** T2 (pruning) — must only remove
paths listed in the OLD manifest and absent from the NEW one; never user files.
Test-first where it applies: T6's three assertions are written to fail against
the unfixed installer.

| # | Task | Files | Local check |
| --- | --- | --- | --- |
| T1 | Replace GNU-only `0,/re/` sed with portable `1,/re/` (safe: `name:` is never line 1 — frontmatter `---` is) | `scripts/install-vendored.sh:180` | `! grep -q '0,/' scripts/install-vendored.sh` |
| T2 | Manifest pruning on re-install: old→new diff; restore backup or remove; log each pruned path; rmdir emptied parents | `scripts/install-vendored.sh` (before manifest write) | new test assertion (T6.2) green |
| T3 | Uninstall: restore `SKILL.md.pre-flywheel` backups per `flywheel-*` dir instead of blanket `rm -rf` | `scripts/install-vendored.sh:78` | new test assertion (T6.3) green |
| T4 | Genericize bookmarking-era parentheticals | `agents/reviewer-security.md`, `agents/reviewer-performance.md` | `! grep -qiE 'twitter\|bookmark' agents/reviewer-*.md` |
| T5 | `allowed-tools` honesty: compound +`Bash(date *)`, ship +`Bash(gh *)` | 2 frontmatters | greps from the spec metric |
| T6 | Three new test assertions: (1) static no-`0,/`; (2) stale-manifest-entry pruned on re-install; (3) pre-existing `flywheel-help` skill backed up + restored | `scripts/test-install-vendored.sh` | `bash scripts/test-install-vendored.sh` exit 0 |
| T7 | Bump 0.16.0 → 0.17.0 + upgrade note | `plugin.json`, `upgrades/v0.17.0.md` | spec metric greps |
| T8 | Report + ledger transitions (P16 law) | `runs/p10-portability-installer/…` | artifact republished per phase |
