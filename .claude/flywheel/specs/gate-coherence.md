# Spec: gate coherence — three rules that disagree with their siblings

## R — Requirements

Three defects, all of the same shape: a rule that is right on its own and
inconsistent with the gate beside it.

1. **`check-route-honored.sh` fails a plan whose work has not started.** v0.70.0
   taught `check-task-closure.sh` that a task with no transition line is PENDING,
   because the loop commits a plan at its approval gate *before* the work. Its
   sibling still fails that task as UNRECORDED, so a plan-only commit is red
   anyway and the fix bought nothing.
2. **`check-test-pairing.sh` only guards `scripts/*.sh`.** v0.70.0 added
   `scripts/fw_tasks.py`, the repo's first `.py` under `scripts/`, which the gate
   cannot see. The ledger already carries this exact defect once
   ("a new branch in install-vendored.sh can land with zero coverage").
3. **The cutoff literal is copied once per gate (P54b).** The proposal named two;
   there are now three — `FLYWHEEL_ROUTE_CHECK_FROM`, `FLYWHEEL_PHASE_REQUIRED_FROM`
   (same date, must move together) and `FLYWHEEL_TASK_CLOSURE_FROM` (its own date).
   One can move without the others, and nothing states which share a date on purpose.

Out of scope: P54(a), which asks *what* route-honored should call fatal. That is
a policy decision for the owner, not a coherence bug.

## E — Entities

| Entity | Where | Note |
| --- | --- | --- |
| cutoff registry | `scripts/cutoffs.txt` (new) | `<name> <iso> <reason>`, the `route-tiers.txt` idiom |
| cutoff reader | `scripts/fw_cutoffs.py` (new) | env var wins, then the registry |
| started-ness | run telemetry | a cycle with no line for **any** of its tasks has not started |

## A — Approach

**One discriminator, already shipped, applied to the sibling.** A cycle with no
transition line for *any* of its plan tasks has not started: report, never fail.
A cycle with lines for *some* has started, so a missing one is genuinely
unrecorded and stays fatal — which is the case P49 built the gate for. The
rejected alternative, forgiving every unrecorded task, would delete P49.

**The registry states the coupling the copies could not.** Two cutoffs share a
date because they were placed by one decision (P48); the third is its own. A
file with a reason per row makes that legible and makes a move one edit. Env
vars keep overriding, so every existing escape hatch still works.

**Pairing keys on the stem, not the extension.** `scripts/<stem>.<ext>` pairs
with `scripts/test-<stem>.sh` — the test is a runner, not a translation. This
renames `test-fw-tasks.sh` to `test-fw_tasks.sh` to match its subject.

## S — Structure

- `scripts/check-test-pairing.sh` + its test — every script language, stem-keyed.
- `scripts/test-fw-tasks.sh` → `scripts/test-fw_tasks.sh` (rename).
- `scripts/check-route-honored.sh` + its test — NOT-STARTED beside UNRECORDED.
- `scripts/cutoffs.txt`, `scripts/fw_cutoffs.py` + `scripts/test-fw_cutoffs.sh`.
- The three gates read the registry.
- `install-vendored.sh` + its test — `fw_cutoffs.py` and `cutoffs.txt` travel with
  `check-task-closure.sh`, which reads them.

## O — Operations

1. Pairing gate covers every script; rename the mismatched test. (First, so it
   guards the two files the rest of this cycle adds.)
2. route-honored learns NOT-STARTED.
3. The registry, and the three gates read it.
4. Commit the list-intake plan, which step 2 unblocks.
5. Release: bump, note, backlog rows.

## N — Norms

Each gate keeps its own exit codes and skip lever. A new verdict is **named and
counted**, never folded into an existing one. Terse code.

## S — Safeguards

- **NOT-STARTED must not swallow UNRECORDED.** The arm that matters is the
  partial cycle: some tasks recorded, one missing, still fatal. Without it this
  change deletes P49 and the gate still exits 0.
- **A widened pairing gate must not redden the corpus.** `fw_tasks.py` already
  has a test; the rename makes it discoverable. Anything else uncovered is a
  finding to report, not to paper over.
- **The registry must not silently change a cutoff.** Extracting the literals is
  a refactor: the values it serves must equal the values the scripts used, proven
  against the live corpus, or the extraction forgives or fails a stretch of
  history by accident (P18).
- Vendored installs break if the new module is not vendored with its readers.

## Success metric

`bash scripts/test-check-test-pairing.sh`, `test-check-route-honored.sh`,
`test-fw_cutoffs.sh` and `test-install-vendored.sh` green; the pairing gate names
a `.py` added without its test and stays green on this tree; route-honored exits
0 on a tree holding a plan whose cycle has no task lines and **still exits 1**
when a cycle has some lines and is missing one; each gate's cutoff before and
after the extraction is byte-identical; `.claude/flywheel/specs/list-intake.plan.md`
is committed with every gate green; full sweep green.
