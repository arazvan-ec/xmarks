# Spec: P10 — Portability + installer correctness

**Slug:** `p10-portability-installer` · **Created:** 2026-07-13 · **Backlog:** P10
**Status:** signed 2026-07-13 (owner) — full cycle approved
**Prime:** LEARNINGS.md read (3 entries; "route review by diff type" applies —
this is a shell diff → correctness lens mandatory). Backlog P10 section +
flow-audit run #1 findings are the source evidence.

## R — Requirements

Make the vendored installer correct and portable, and stop shipping stale
repo-specific context in the agents:

1. **BSD/macOS-safe installer** — remove the GNU-only `sed "0,/re/"` address
   (`install-vendored.sh:180`); the documented local install must not die under
   `set -euo pipefail` on macOS.
2. **Upgrade pruning** — re-install removes files the new version dropped:
   diff old→new manifest and `remove_or_restore` every disappeared path (today
   orphans become permanently un-uninstallable).
3. **Uninstall symmetry for skills** — pre-existing `flywheel-*` skills backed
   up as `*.pre-flywheel` are restored on uninstall (agents already are; skills
   are deleted).
4. **Genericize agent prompts** — `reviewer-security.md` / `reviewer-performance.md`
   drop the bookmarking-era parentheticals ("X/Twitter cookies", "per-bookmark
   DB writes") that misdirect reviews in every target repo.
5. **allowed-tools honesty** — `compound` declares `Bash(date *)` (its body
   requires `date +%F`); `ship` declares `Bash(gh *)` (its body offers the gh CLI).

**Out of scope:** `session-start.sh` fixes (P9), `gate.sh` (P11),
`read-prime.sh` (P9), any skill-body prose changes beyond frontmatter.

## E — Entities

| Entity | Fields that matter | Files |
| --- | --- | --- |
| Manifest | sorted list of vendored paths; old vs new on re-install | written by `install-vendored.sh` |
| Backups | `*.pre-flywheel` (agents AND skills) | target repo `.claude/` |
| Agent prompts | repo-agnostic focus bullets | `agents/reviewer-{security,performance}.md` |
| Skill frontmatter | `allowed-tools` matching body needs | `skills/{compound,ship}/SKILL.md` |

## A — Approach

Fix in bash, in place — the installer is house-style bash (`set -euo pipefail`)
and the fixes are local: `1,/re/` (equivalent here: the `name:` line is never
line 1) or awk for the sed; a manifest diff loop for pruning; a restore pass
before the blanket `rm -rf` for skills. Rejected: rewriting the installer in
python — heavier, breaks the zero-dependency install path (python3 is already
only a soft dependency elsewhere). Tests extend `test-install-vendored.sh`
(same `ok:` idiom): a pruning assertion (plant a manifest entry, re-install
without it, assert removed), a skill-restore assertion, and a static
portability assertion (no `0,/` in the script).

## S — Structure

- `scripts/install-vendored.sh` — the three fixes (sed, pruning, skill restore).
- `scripts/test-install-vendored.sh` — three new assertions.
- `agents/reviewer-security.md`, `agents/reviewer-performance.md` — generic bullets.
- `skills/compound/SKILL.md`, `skills/ship/SKILL.md` — frontmatter only.
- `.claude-plugin/plugin.json` → **0.17.0** · `upgrades/v0.17.0.md`
  (`requires-action: false` — fixes apply on next re-vendor/update).

## O — Operations

1. Replace the `0,/re/` sed with a portable equivalent.
2. Add manifest pruning (old→new diff, `remove_or_restore` disappeared paths).
3. Restore `*.pre-flywheel` skill backups before the uninstall `rm -rf`.
4. Genericize the two agent parentheticals.
5. Widen the two `allowed-tools` lines.
6. Extend `test-install-vendored.sh` (pruning, skill restore, no-GNU-sed).
7. Bump + `upgrades/v0.17.0.md`; run all tests.

## N — Norms

Installer stays idempotent (the test installs twice); `ok:`/`fail:` test idiom;
minimal diffs; no new dependencies; vendoring rewrite of `/flywheel:` refs
untouched.

## S — Safeguards

- **Never delete user files:** pruning removes only paths present in the OLD
  manifest and absent from the NEW one — never globs, never unlisted files.
- **Backups are restored, not deleted** — for agents and skills alike.
- **Idempotency preserved:** double-install and install-after-upgrade both green.
- **Fail loud:** pruning logs each removed path; uninstall keeps preserving
  project state (`LEARNINGS.md` etc. — already asserted by the test).

## Success metric

One command, exit 0 = PASS:

```bash
! grep -q '0,/' scripts/install-vendored.sh \
  && ! grep -qiE 'twitter|bookmark' agents/reviewer-security.md agents/reviewer-performance.md \
  && grep -q 'Bash(date \*)' skills/compound/SKILL.md \
  && grep -q 'Bash(gh \*)' skills/ship/SKILL.md \
  && grep -q '"version": "0.17.0"' .claude-plugin/plugin.json \
  && test -f upgrades/v0.17.0.md \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/test-install-vendored.sh \
  && bash scripts/test-read-prime.sh
```

(`test-install-vendored.sh` itself gains the pruning + skill-restore
assertions, so its green is strictly stronger than today's.)
