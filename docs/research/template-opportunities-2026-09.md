# Template opportunities — 2026-09-23

A sweep of past sessions for repeated steps that went wrong on the same forgotten
detail more than once, graded against the owner's three conditions for a template
(`LEARNINGS.md`, "a template for a repeated step earns its place…"):
**born from a failure**, **something checks it was used**, **pointed to, never pasted**.

Sources: `git log` (#42–#95, 312 commits), `.claude/flywheel/runs/*/*.jsonl` (33 dirs),
`LEARNINGS.md`, `journal.md`, `improvement-proposals.md`, `review-v0.63-v0.71.md`, specs/plans.

## Candidates, ranked by evidenced occurrences

| # | Repeated step | Occurrences | Covered today | Check it could have |
| --- | --- | --- | --- | --- |
| P59 | Renumber a release after `main` took the version | ~11 | Detected (`check-release-bump.sh`), never performed; prose only in `briefs/README.md:45-51` | Inside the tool: `scripts/renumber.sh <old> <new>` |
| P60 | Full local gate sweep before push | ~10, snippet pasted in 8 specs | `check-ci-gate-parity.sh` covers CI, nothing local | Inside the tool: `scripts/sweep.sh` |
| P61 | Close a cycle's records (Status, verify line, backlog row) | ~8 | Nothing reads them | Gate: arm of `check-task-closure.sh` or `check-spec-closure.sh` |
| P62 | Make a new gate fail on the real tree before trusting it | ~11 across 8 specs | Nothing | Marker: required `cannot see:` in Safeguards + `references/new-gate.md` |
| P63 | Vendor a new script/data file skills call | 3 | `check-hook-parity.sh` covers hooks only | Inside the tool: extend parity to every `.claude/flywheel/bin/X` cited in `skills/` |
| P64 | Check a delegated child's report against the artifact | 3–4 | `delegation-guard.sh` checks the prompt only | Marker: `verified:` field on `+delegate` transitions, read by `check-route-honored.sh` |

### P59 — renumber

Evidence: `journal.md:178-184` (P5 moved 0.10→0.11→0.12), `journal.md:213-224` (P4 moved 0.13→0.14, and it was
the second collision on the same PR), aebafb4, f13cb83, d55d5e6, 3d1dd19 (six files edited by hand), dcb77f8,
`LEARNINGS.md:406-410` ("twice in one session"), `improvement-proposals.md:199-202`. The 0.59→0.61 renumber in
#81 left three `0.59.0` pointers in `flywheel-update.yml`, one of them in the `::error::` remedy.
It collides on P-numbers as well: the backlog table **today** has two `P55` rows and two `P56` rows
(`improvement-proposals.md:78-83`).
Sites touched: `plugin.json`, the `upgrades/v*.md` name and its frontmatter, the spec Status line, the plan
title, the backlog row, `benchmarks/*-v<ver>`, and workflow and prose pointers.
`check-version-citations.sh` deliberately leaves a bare mention free, so a stale Status line or backlog cell
stays invisible.
Shape: `git mv` the note and the `*-v<old>` dirs, then rewrite the manifest and frontmatter. After that, fail
while any `<old>` token remains in the files this branch touched. Exempt the "Renumbered from" line and the
telemetry JSONL, which is immutable. Cite it from `ship` or `sync` at the step that merges `main`.

### P60 — sweep

Evidence: p31/#80 had nine gates green while CI failed on the tenth (`LEARNINGS.md:224-244`).
`test-run-cost.sh` went unrun for four releases. p12 was green locally and red on mawk. In
deterministic-task-closure T6, test-pairing failed on CI. In the review retro, a false red came from a
sweep run in parallel with reviewers.
The same `for t in scripts/test-*.sh` loop is pasted into 8 specs, which breaks condition 3. It also calls the
base-ref gates without the `origin/<base>` argument CI passes (`validate-plugins.yml:61`). About 8 plans say
"full sweep clean" as prose rather than as a command.
Shape: take the gate list and arguments from the same place the workflow does, force a private TMPDIR, run
sequentially, and print `N/N`. Plans then cite `bash scripts/sweep.sh`, and task closure executes it. Mind
`check-task-closure.sh`'s timeout warning for sweeps run inside a task.

### P61 — close-out

Evidence: `review-v0.63-v0.71.md:99-107` (findings 8 and 9). At HEAD, 9 specs have no Status line
(atomic-commits, blocked-cycle-eval, deterministic-task-closure, gate-coherence, list-intake,
loop-telemetry-eval, p19-update-postprocess, p22-evals-pillar1, stage-routing), and **29 of 33** run dirs have
no `phase: verify` line.
Rows went stale in 5c8470a, 2a96e4a, 474a432 and gate-coherence T5. P54's heading and row disagree. Only 15 of
46 headings carry a status.
Shape: a spec whose run has a `phase: ship` line must carry `**Status:**`, a `verify` line and a backlog row
whose emoji matches its heading. Put a cutoff on the corpus as P48 did, so the old debt reads as a notice.

### P62 — a new gate is seen red on the real tree

Evidence (`LEARNINGS.md`): P42 read `tail -1` instead of `$?` (:386-394). In P35, deleting the branch left the
suite green (:428-434). P13 asserted presence and not the operand, reddened on comments and missed
`--detach` (:68-149). In P47, "differs" was used where "ahead of" was needed (:29-45). In P52, comment lines
gave a false green (:951-954). deterministic-task-closure exited 2 on its own corpus, and its allowlist
matched nothing (:975-1011). P45 exited 0 with a traceback.
The forgotten detail differs each time, but the step is the same: break it on purpose and read the exit code.
Shape: a `references/new-gate.md` checklist, cited from the plan step that adds a `check-*.sh`. It asks to put
the defect back on the real tree, read `$?`, test the shipped commented form, run the error paths against
the corpus, confirm the CI trigger reaches the gate, and write in Safeguards what the gate cannot see. The
checkable marker is a `cannot see:` line required in any spec that adds a `check-*.sh`.

### P63 — vendoring

Evidence: in 05127cf, `plan-route.sh`, `run-cost.sh` and `route-tiers.txt` went unvendored for about 4
releases and failed open. 8e944ce (the v0.44.1 hotfix) shipped with delegation hooks unvendored. In e6b6efd,
`task-closure-allow.txt` and `fw_tasks.py` were added with no assertion that they arrive.
Not a template: an existing gate is missing one arm. It is listed because the step recurs.

### P64 — a delegated report is verified, not relayed

Evidence: in P40a T6, a false baseline claim was relayed (`LEARNINGS.md:396-402`). In P52 T3, a red was called
"pre-existing" when it was not. In the review retro, "Reproduced" was relayed for repros only the agents had
run. p49 T5 did the check by hand ("verified by reading the diff").

## Rejected

- **Already covered:** answering review (`answering-review.md`, citation only; if it slips, P58 already names
  the next step), executor dispatch (`fixture-scratch.sh --executor-prompt`), delegated-review start
  (`fw-review-start`), telemetry fields (`check-telemetry.sh` + `read-meter.sh`), invocation budget,
  README/help table, test pairing, CI wiring (`check-ci-gate-parity.sh`).
- **The detail differs each time, and a checklist would not have caught the next one:** grader/fixture
  assertions (~10, `test-eval-graders.sh` partial), numbers left stale after review fixes (4; hard to
  mechanize; at most a line in `answering-review.md`), gate exit status swallowed by a pipe (3; better
  absorbed by P60, which reads `$?` itself).
- **One occurrence:** upgrade-note prose delegated (its rule is pasted into two plans; watch it), the
  hook-test scaffold, running the signed metric verbatim, and hand counts versus script counts.
- **No failure observed:** `marketplace.json`/`plugin.json` description drift.

## Accumulation

P59, P60 and P63 are scripts. They do not load into any skill body, so they cost the invocation budget
nothing. P61 is a gate. Only P62 adds a `references/` file. If the six ship, the flow gets one more document
to read, not six.
