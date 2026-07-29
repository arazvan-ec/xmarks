# p19-update-postprocess — persistent post-update state + refresh smoke check

Owner ask (2026-07-29): "¿sería bueno hacer algún postproceso después de
actualizar la versión del plugin en los repos donde está instalado?" → approved
to build in the same session ("llévalo adelante").

## R — Requirements

The auto-update flow's `requires-action` warning lives only in the PR body: if
the weekly refresh PR is merged without running `/flywheel:update`, the pending
upgrade strategies are lost silently — files updated, `VERSION` current, no
trace of unapplied steps. Also, nothing verifies after a refresh that the
vendored hook scripts still parse, so a broken refresh is only discovered when
the next session's hooks fail.

In scope:
1. Persist "strategies pending" as repo state written by the installer, nagged
   by SessionStart every session until `/flywheel:update` applies and clears it.
2. Post-refresh smoke check in the installer: `bash -n` every vendored hook
   script; abort the install (non-zero) on failure so a broken copy is never
   recorded as installed.

Out of scope: auto-applying strategies from CI (deferred until the nag proves
recurring debt); marketplace installs (no installer runs there).

## E — Entities

| Entity | Where | Role |
| --- | --- | --- |
| `PENDING-UPGRADES` | `.claude/flywheel/` in target repos | One note-version per line whose strategy is unapplied. Written/merged by the installer; cleared per-version by `/flywheel:update`; removed by `--uninstall`. State, **never** in the manifest (manifest pruning would erase the debt on the next refresh). |
| upgrade note | `upgrades/v*.md` in xmarks | Source of truth: `requires-action: true` in range `(old, new]` ⇒ pending. |
| `UPGRADES.md` | `.claude/flywheel/` in target repos | Existing applied-strategy log; unchanged, still the idempotency record. |

## A — Approach

The installer is the single writer of pending state: it is the only component
that has both the old version (target's pre-refresh `VERSION`) and the note
files (its own checkout) at the moment the debt is created — CI and manual
updates share it. SessionStart only reads local state (no network, works under
`FLYWHEEL_NO_UPDATE_CHECK`). Rejected alternative: SessionStart diffing
`UPGRADES.md` against remote notes — needs network in a hook, re-derives the
range every session, and breaks when notes are renamed.

## S — Structure

- `scripts/install-vendored.sh` — capture old version before overwriting
  `VERSION`; write/merge `PENDING-UPGRADES`; `bash -n` smoke check; uninstall
  removes the file.
- `scripts/session-start.sh` — nag block reading `PENDING-UPGRADES`.
- `skills/update/SKILL.md` — §2.4 clears applied versions from the file.
- `.github/workflows/flywheel-update.yml` — PR body mentions the persistent nag.
- `scripts/test-install-vendored.sh`, `scripts/test-session-start.sh` — new
  assertions.

## O — Operations

1. Installer: read `OLD_V` from the target's `VERSION` early (before any write).
2. After writing the new `VERSION`: if `OLD_V` set and ≠ new, scan
   `upgrades/v*.md` with `sort -V`, keep `OLD_V < v ≤ new` and
   `requires-action: true`, merge into `PENDING-UPGRADES` (dedup, sorted).
3. Smoke check right after vendoring `bin/`: `bash -n` each script, abort on
   failure (old manifest still intact — nothing recorded as installed).
4. SessionStart: if `PENDING-UPGRADES` is non-empty, print a ⚠️ listing the
   versions and pointing at `/flywheel:update`.
5. Update skill: after logging a strategy to `UPGRADES.md`, delete its version
   line from `PENDING-UPGRADES`; remove the file when empty.
6. Uninstall: remove `PENDING-UPGRADES` alongside `VERSION`/manifest.

## N — Norms

Hook stays READ-ONLY/exit-0; installer stays idempotent and BSD-sed-safe;
version comparisons via `sort -V` (house pattern from the update workflow);
state files never enter the manifest (LEARNINGS.md precedent).

## S — Safeguards

- Same-version re-install must not clear or grow the file (debt survives
  refreshes, no duplicate entries).
- Empty file ⇒ no nag (`[ -s ]`).
- Unknown old version (pre-0.5.0, no `VERSION`) ⇒ installer writes nothing;
  `/flywheel:update`'s existing diff fallback still covers that path.
- Smoke check runs before the manifest swap, so an aborted install leaves the
  previous manifest and `VERSION` untouched.

## Success metric

`bash scripts/test-install-vendored.sh && bash scripts/test-session-start.sh`
exits 0, and their outputs include the new assertions:
`grep -q 'pending strategies recorded'` and `grep -q 'pending-upgrade nag'`
over the respective outputs.
