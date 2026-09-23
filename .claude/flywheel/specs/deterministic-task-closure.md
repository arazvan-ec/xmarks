# Spec: deterministic task closure — the `check:` a plan already carries is executed

## R — Requirements

Every plan task is required to carry a `- check:` — `plan-route.sh:151` rejects a
plan without one ("a route without a pass/fail check is not a task"). That field
is linted **for presence and never executed**. So the verdict "T4 is done" is
produced by a model reading its own work, over a field that, in most of the 98
checks in this repo's plans, already begins with a runnable command.

In scope (phase 1): extract the runnable command from each task's `check:`, run
it, and report a per-task PASS/FAIL/UNRUNNABLE table where the count of rows
equals the count of tasks. Out of scope (phase 2, owner-decided): the same
verifier over ad-hoc lists handed in chat that never become a plan.

Not in scope: the Stop hook. The owner ruled it out — `gate.sh` already carries
the project command's trust model and this must not be folded into it.

## E — Entities

| Entity | Where | Key fields |
| --- | --- | --- |
| plan task | `.claude/flywheel/specs/<slug>.plan.md` | `id`, `title`, `route`, `check` |
| parse | `plan-route.sh --json` | `tasks[]` — today carries no `check`; this spec adds it |
| verdict | `check-task-closure.sh` stdout | per task: PASS / FAIL / UNRUNNABLE |

## A — Approach

Execute only commands matching a **repo-script allowlist** (`scripts/test-*.sh`,
`scripts/check-*.sh`, and the other repo-shipped runners), extracted from the
backticked spans of `check:`. Everything else is UNRUNNABLE — named and counted,
never read as green.

The rejected alternative is `bash -c` over any backticked span. It would cover
more checks and it would also mean `/flywheel:verify` executes arbitrary shell
out of a file a PR can write — the exact exposure `gate.sh`'s trust store exists
to close. The allowlist keeps the blast radius at "CI already runs this repo's
scripts", which is the baseline exposure, not a new one.

Parsing goes through `plan-route.sh --json` and nowhere else: "two readers of one
format is how the two drift" (`check-route-honored.sh`).

## S — Structure

- `scripts/plan-route.sh` — `--json` records gain `check` (the raw field text).
- `scripts/check-task-closure.sh` — new: parse → extract → allowlist → execute → table.
- `scripts/test-check-task-closure.sh` — its pair (CI enforces the pairing).
- `scripts/test-plan-route.sh` — an arm for the new `check` field.
- `.github/workflows/validate-plugins.yml` — the gate step (`check-ci-gate-parity.sh` enforces it).
- `skills/verify/SKILL.md` — the step that runs it in-loop.

## O — Operations

1. `plan-route.sh --json` carries `check`.
2. Red arms for extraction, the allowlist, the taxonomy, and the cutoff.
3. `check-task-closure.sh` green against those arms.
4. Wire CI + `verify`.
5. Release: bump, upgrade note, backlog entry.

## N — Norms

Gate shape copied from the existing `check-*.sh`: a header stating what fails and
why, `SKIP_TASK_CLOSURE=<reason>` taking the reason and never a `1`, exit `0` ok /
`1` a real failure / `2` unusable input. Terse code, no ceremonial comments.

## S — Safeguards

- **Execution is the risk.** The allowlist is the boundary; a check naming
  anything outside it is UNRUNNABLE, never executed and never green.
- **Timeout per check**, so one hanging command cannot wedge CI.
- **Cutoff, not backfill** (P18, P48): plans older than the cutoff are reported
  UNRUNNABLE and do not fail the gate. The 98 existing checks are corpus, and
  nothing may be rewritten to buy a green.
- A FAIL and an UNRUNNABLE are different verdicts and never collapse into one
  count — the mistake `check-route-honored.sh` names as reporting absence as
  honored.

## Success metric

`bash scripts/test-check-task-closure.sh` and `bash scripts/test-plan-route.sh`
green; `bash scripts/check-task-closure.sh` exits 0 on this tree, reports every
task of this cycle's own plan as PASS with the command it ran, and reports the
pre-cutoff corpus as UNRUNNABLE without failing; `bash scripts/check-ci-gate-parity.sh`
green (proving the gate is actually wired); every `scripts/test-*.sh` and every
`scripts/check-*.sh` green.
