# Plan: P43 — flywheel's hooks run on flywheel

**Spec:** `.claude/flywheel/specs/p43-hooks-run-on-flywheel.md`

## Routing table

| Tier | Route | Tasks |
| --- | --- | --- |
| T3 judgment | `opus/high` | T2 |
| T2 default | `sonnet/medium` | T1, T3 |
| T1 mechanical | `haiku/low+delegate` | T4, T5 |

The riskiest step is **T2**, the flag itself: it writes `.claude/settings.json`,
the one file whose corruption breaks every session in the repo at once, and it
shares the installer's merge path with the full install every consuming repo uses.

### T1 — Red: the cases
- route: `sonnet/medium`
- changes: `scripts/test-install-vendored.sh` — self-target writes settings.json
  and nothing else, pre-existing `permissions` survive, a foreign target is
  refused, a re-run is idempotent. `scripts/test-check-hook-parity.sh` — a
  registration missing from the repo's own settings.json fails and is named.
- check: both suites fail naming a new case, not a syntax error.
- test-first: yes

### T2 — Green: `--hooks-only`, self-target only
- route: `opus/high`
- risk: highest
- changes: `scripts/install-vendored.sh` — the flag, the `scripts/` path prefix,
  an early exit after the settings merge. `scripts/check-hook-parity.sh` — the
  third assertion against this repo's settings.json.
- check: both suites green, the full install's existing cases unedited.
- test-first: yes

### T3 — Wire this repo, and record the cycle
- route: `sonnet/medium`
- changes: `.claude/settings.json` (produced by the new mode, committed);
  `.claude/flywheel/runs/p43-hooks-run-on-flywheel/<date>.jsonl` — this cycle's
  own telemetry, which P42's gate now requires of it.
- check: `bash scripts/check-hook-parity.sh` and `bash scripts/check-telemetry.sh`
  both green; `git diff --quiet .claude/settings.json` after a re-run.
- test-first: no

### T4 — README + release
- route: `haiku/low+delegate`
- changes: README note on `--hooks-only`; `.claude-plugin/plugin.json` → `0.55.0`.
  The upgrade note is written by the caller, not delegated — a release summary is
  judgment, which is the lesson T6 of P40a paid for.
- check: `bash scripts/test-docs-consistency.sh` green.
- test-first: no

### T5 — Run the spec's metric
- route: `haiku/low+delegate`
- changes: none — run and report, including the decisive probe (remove a
  registration, assert the parity gate names it, restore).
- check: the metric command exits 0 and the probe fails as designed.
- test-first: no

## Safeguards re-checked

| Spec safeguard | Where the plan addresses it |
| --- | --- |
| full install unchanged | T2's check requires the existing cases green, unedited |
| the mode writes one file | asserted in T1, not merely intended |
| permissions survive | its own assertion in T1 |
| the Stop gate stays inert | no task creates a project `gate.sh` |
