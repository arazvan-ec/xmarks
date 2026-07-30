# Spec: P26 — committed graders for `verify` and `work`

**Slug:** `p26-pillar1-graders` · **Created:** 2026-07-30 · **Backlog:** P26
**Status:** shipped as v0.37.0 — metric PASS (all seven commands exit 0). No eval
gate was required: the diff touches no `skills/*/SKILL.md`, agent or hook, so
there is no skill behavior to regress. The measurement this release exists to
make trustworthy — the `verify` iteration on the cleaned fixtures — is
deliberately **not** part of the metric and is still unrun.
**Prime:** P26 section in `docs/research/improvement-proposals.md`; the
"Post-audit sequencing (2026-07-30)" note that makes this a dependency for every
later pillar-1 eval run; `skills/{process,run}/evals/check.sh` (the contract to
mirror); both `skills/{verify,work}/evals/README.md` (the leak post-mortems).

## R — Requirements

1. **`skills/verify/evals/check.sh <id> <workdir>`** and
   **`skills/work/evals/check.sh <id> <workdir>`** exist, with pillar 2's
   contract: one `PASS:`/`FAIL:` line per expectation, exit 0 only if all pass,
   exit 2 on an unknown eval id.
2. **Each grader mechanizes exactly the expectations already committed in its
   `evals.json`** — no assertion invented here, none dropped. P26 builds the
   instrument; it does not redefine what is measured.
3. **Every grader in the repo is proven able to fail** — red against an
   untouched fixture copy. This is the property that found the hollow `run`
   eval-2 assertion, and it must hold for all four graders, checked
   mechanically rather than remembered.
4. **The pillar-1 graders are proven able to pass** — green against a
   synthesized ideal workdir, so a grader that can never pass (the mirror
   defect: a typo'd regex that fails every real run) is caught too.
5. **The fixture-leak grep becomes a gate.** Both eval READMEs already carry it
   as a manual step "before any iteration"; three leaks in one week is the
   evidence that a manual step is not a gate. Any fixture file matching the
   assertion vocabulary fails CI unless allowlisted with a reason.
6. **The runbook stops describing pillar 1 as hand-derived.** README's "Skill
   evals" section and both eval READMEs point at the graders.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| verify grader | regexes over `report.md` / `transcript.md` | `skills/verify/evals/check.sh` |
| work grader | `.check-log` vs `baseline-sha`, plus behaviour probes | `skills/work/evals/check.sh` |
| grader self-test | red-on-untouched (×4 graders) + green-on-ideal (×2) | `scripts/test-eval-graders.sh` |
| leak gate | assertion vocabulary may not appear in a fixture | `scripts/check-fixture-leaks.sh` |
| leak allowlist | `path:pattern:reason`, one per legitimate hit | `scripts/fixture-leak-allow.txt` |
| leak gate test | its own paired test | `scripts/test-check-fixture-leaks.sh` |
| runbook | pillar 1 is graded by a committed script now | `README.md`, both `evals/README.md` |

## A — Approach

**The graders mirror pillar 2 line for line** — same `ok`/`fail`/`check`
helpers, same `case "$ID"`, same exit contract — so one runbook step
(`bash skills/<name>/evals/check.sh <id> "$W"`) covers all four skills.

**`work` is graded from artifacts, never from the transcript.** `.check-log` is
written only by `run-tests.sh`, so first-entry-`RESULT=FAIL`-with-`IMPL_SHA`-equal-
to-`baseline-sha` is a fact about what ran, not a claim. On top of the four
committed expectations the grader re-executes the suite directly
(`KATA_HARNESS=1 python3 -m unittest`, which does **not** append to
`.check-log`, so grading cannot corrupt the log it grades) and probes the
required behaviour — `apply_discount` arithmetic and bounds, `add_item`
rejecting `qty <= 0`. "The final suite is green" is a committed expectation;
running it is how you check it.

**`verify` is graded from the two artifacts the executor saves.** `report.md`
(verdict as last non-empty line) and `transcript.md` (commands + real output),
in the workdir root unless `FW_EVAL_REPORT` / `FW_EVAL_TRANSCRIPT` override.
A missing artifact is a `FAIL:` line naming the path, never a silent pass —
the failure mode that makes a grader worthless is passing on absence.

**Requirement 3 is the load-bearing one, and it is a test, not a habit.**
`scripts/test-eval-graders.sh` copies each fixture untouched and asserts every
grader exits non-zero for every eval id. For `verify` and `work` it then
synthesizes the ideal outcome (an exemplary `report.md`/`transcript.md`; a
correct red→green `.check-log` plus a real `apply_discount`/`add_item` fix) and
asserts exit 0. Pillar 2's green side is not synthesized — building a valid
process contract in bash would be a second implementation of the thing being
graded; its green evidence is the committed benchmarks, and the test says so out
loud rather than leaving the gap implied.

**The leak gate needs an allowlist, not a looser regex.** `run-tests.sh`
legitimately says `.check-log`, `RESULT=`, and `IMPL_SHA` because it writes
them. Allowlisting those three exact `path:pattern` pairs keeps the vocabulary
strict everywhere else, so the next README that explains the grading rule fails
CI. A bare regex loose enough to let the runner through would have let the
`work` README leak through too.

Rejected: putting the graders under `scripts/` to inherit the pairing gate —
they belong beside the evals they grade, as pillar 2's already do, and
`test-eval-graders.sh` is a stronger check than pairing (it runs them). Also
rejected: adding "the verifier did not modify `app.py`" to the `verify`
expectations — plausibly true, but it changes what the eval measures and P26 is
the instrument, not a redefinition.

## S — Structure

- `skills/verify/evals/check.sh` (new)
- `skills/work/evals/check.sh` (new)
- `scripts/test-eval-graders.sh` (new, wired into CI)
- `scripts/check-fixture-leaks.sh` + `scripts/fixture-leak-allow.txt` (new, CI)
- `scripts/test-check-fixture-leaks.sh` (new, its pair)
- `.github/workflows/validate-plugins.yml` — two steps
- `README.md`, `skills/verify/evals/README.md`, `skills/work/evals/README.md`
- `.claude-plugin/plugin.json` → **0.37.0** · `upgrades/v0.37.0.md`

## O — Operations

1. Write `scripts/test-eval-graders.sh` and `scripts/test-check-fixture-leaks.sh`
   first; run both, see them red for the right reason (graders absent, gate
   absent).
2. Implement `skills/{verify,work}/evals/check.sh`; watch red → green.
3. Implement `check-fixture-leaks.sh` + allowlist; confirm it is red on a
   planted leak and on an emptied allowlist, green on the committed fixtures.
4. Wire both into `validate-plugins.yml`.
5. Docs: README runbook, both eval READMEs.
6. Full check suite, then bump + upgrade note.

## N — Norms

Bash + stdlib Python only, POSIX-ish, no new dependency. Graders are pure
readers of the workdir — they never write into it (the suite re-run is
side-effect-free by construction: only `run-tests.sh` appends to `.check-log`).

## S — Safeguards

- **No release-gate change without its own test**: the graders ship with
  `test-eval-graders.sh` in CI, so a future edit that makes one vacuous fails
  the build.
- **The escape hatch is logged, never silent**: `SKIP_FIXTURE_LEAKS=1` prints
  that it skipped, matching the two existing gates.
- **No eval definitions change** — `evals.json` is untouched in this release, so
  the committed benchmarks stay comparable and the pending `verify` iteration
  measures the skill rather than a moved goalpost.
- **Skill text is untouched**, so P22 phase 2's "run the eval before bumping"
  gate does not apply to this release — and that is stated in the upgrade note
  rather than left as an inference.

## Success metric

One command, exit 0 = PASS. It deliberately does **not** assert that the
`verify` iteration passes — that is the measurement this release makes
trustworthy, not part of it:

```bash
bash scripts/test-eval-graders.sh \
  && bash scripts/test-check-fixture-leaks.sh \
  && bash scripts/check-fixture-leaks.sh \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/test-install-vendored.sh \
  && bash scripts/check-test-pairing.sh \
  && bash scripts/check-description-budget.sh
```
