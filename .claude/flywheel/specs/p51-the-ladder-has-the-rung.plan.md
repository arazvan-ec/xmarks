# Plan: P51 — the effort ladder has the rung the CLI has

Spec: `.claude/flywheel/specs/p51-the-ladder-has-the-rung.md`

### T1 — Red: `xhigh` is legal, and ranks between `high` and `max`

- route: `sonnet/medium`
- check: `bash scripts/test-plan-route.sh` fails on the new arms — a plan routed `opus/xhigh` is rejected today.

Arms: a plan routing `opus/xhigh` lints OK; `--json` ranks it above `opus/high`
and below `opus/max`; the riskiest step routed `opus/xhigh` satisfies the
top-tier rule; `ultracode` is still rejected, since it is a mode and not a rung.

### T2 — Green: the rung, in the one place both scripts read

- route: `opus/high`
- risk: highest
- check: `bash scripts/test-plan-route.sh` green, and `bash scripts/check-route-honored.sh` reports p13's three transitions as an unrecorded upgrade rather than as unrankable, still as pre-cutoff notices, with the tree green.

### T3 — Release: bump, note, and P49's open question closed

- route: `sonnet/medium`
- check: `bash scripts/test-docs-consistency.sh` green and the full `scripts/test-*.sh` / `check-*.sh` sweep clean.
