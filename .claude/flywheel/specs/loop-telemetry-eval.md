# Spec — a `loop` eval that grades cycle telemetry (P29)

Slug: `loop-telemetry-eval` · Date: 2026-09-09 · Pillar 1 (build the software)

## R — Requirements

The v0.40.0 gate ended with a stated hole: `work` writes its JSONL transition
lines **only inside a `/flywheel:loop` cycle**, and every eval suite runs a skill
standalone. All six executors independently reported writing no telemetry. So
the two-tier reporting (P16/P23/P30) and the new `"commit": "<sha>"` field are
verified by nothing — a regression there would ship silently, and a sha invented
rather than observed would ship *loudly wrong* with no check to catch it.

In scope:
- `skills/loop/evals/` — the first suite that runs a **whole cycle**: fixture,
  `evals.json`, a committed deterministic `check.sh`, a README runbook.
- Assertions that only a real cycle can satisfy: the JSONL exists and parses,
  every recorded `commit` **resolves to a real git object in the workdir**, no
  task commit sweeps `.claude/flywheel/` state in with the source, the feature
  actually works, and no `tokens` key anywhere (P18).
- A second eval on a **non-git** workdir: the cycle still completes and the
  telemetry carries **no** `commit` field — the fail-open path, and the guard
  against a fabricated sha.
- Wiring into `scripts/test-eval-graders.sh`: red on an untouched fixture, green
  on a synthesized ideal outcome.

Out of scope: grading the HTML report's contents (it is rendered from the JSONL
the grader already reads); asserting a route (micro-cycle vs full cycle is the
skill's judgment and both emit telemetry); any token claim.

## E — Entities

| Entity | Fields |
| --- | --- |
| Transition line | one JSON object per line in `.claude/flywheel/runs/<slug>/<date>.jsonl`: `ts`, `state`, task/phase, optional `commit`, optional `cost` |
| Recorded commit | a `commit` value that must resolve via `git cat-file -e <sha>^{commit}` |
| Sweep signature | a commit that contains both source and `.claude/flywheel/` paths — what `git add -A` produces and a pathspec commit cannot |
| Fail-open case | non-git workdir: cycle completes, work lands in the tree, **no** `commit` key exists |

## A — Approach

Grade **artifacts, never the transcript** — the house rule of every existing
grader. The decisive one is cross-checking the telemetry against git: a `commit`
field is the only place in flywheel where a skill writes down a claim about
something outside its own file, so it is the only field that can be *verified*
rather than merely parsed. `git cat-file` is that verification, and it fails
exactly on the failure mode worth fearing (a plausible-looking sha nobody ever
made).

Rejected alternative: assert "N commits for N tasks". It reads stricter and is
weaker — the plan's task count is the skill's judgment (a two-function ask may
legitimately be one task or two), so the assertion would fail correct runs, which
is precisely the defect v0.40.1 just fixed in the `work` grader. Asserting the
*properties* of whatever commits exist survives both routes.

The non-git eval exists because the absence of a field is not provable from a
passing run: only a workdir where committing is impossible can show that the
executor reports it rather than inventing it.

## S — Structure

- `skills/loop/evals/fixtures/inventory-repo/` — a small module, its suite, and a
  work item naming two additions. Scenario prose only (P26 leak gate).
- `skills/loop/evals/evals.json` — 2 evals, each with a `setup` that instantiates
  the workdir (eval 1 `git init` + seed commit; eval 2 deliberately not).
- `skills/loop/evals/check.sh` — the grader, same contract as the other four.
- `skills/loop/evals/README.md` — ground truth + runbook (never copied into a
  workdir).
- `scripts/test-eval-graders.sh` — `loop` in the red-on-untouched sweep, plus a
  synthesized ideal outcome for the green side.
- Docs: README "Skill evals", `upgrades/v0.41.0.md`, `.claude-plugin/plugin.json`
  → 0.41.0, `docs/research/improvement-proposals.md` (P29 + decision log).

## O — Operations

1. Spec (this file).
2. Fixture: module, suite, work item.
3. `evals.json` — prompts, setups, expectations.
4. `check.sh` — written against the expectations, then proven red on an
   untouched fixture before any real run.
5. `test-eval-graders.sh` — red-on-untouched + green-on-ideal for `loop`.
6. Run both evals with fresh-context executors; grade; commit
   `benchmarks/2026-09-09/`.
7. Docs, version bump, upgrade note, proposals + decision log.

## N — Norms

Grader style follows `skills/run/evals/check.sh`: `set -u`, `ok`/`fail`/`check`
helpers, one PASS/FAIL line per expectation, exit 0 only if all pass, exit 2 on
an unknown id. Fixture prose carries no assertion vocabulary. Terse comments that
state constraints, not narration. One commit per operation above.

## S — Safeguards

- **The grader must be able to fail**: `scripts/test-eval-graders.sh` runs it on
  an untouched fixture and requires red, and on a synthesized ideal outcome and
  requires green. A grader that cannot do both is the defect P26 exists to catch.
- **No assertion may be satisfiable by doing nothing**: the behaviour probe and
  the independent suite re-run make "wrote plausible telemetry, built nothing"
  fail.
- **No grading from the transcript** — artifacts only.
- **Grading must not mutate what it grades**: the grader reads the JSONL and runs
  git plumbing (`cat-file`, `show --name-only`), never a command that writes.
- **No token assertions**: the grader instead *fails* a line carrying a `tokens`
  key, matching `run-cost.sh`.

## Success metric

All green, from a clean tree:
1. `bash scripts/test-eval-graders.sh` → `ALL PASS`, including `loop` red on an
   untouched fixture and green on the synthesized ideal outcome.
2. `bash scripts/check-fixture-leaks.sh` → OK with no new allowlist entry.
3. Both evals executed by fresh-context subagents and graded by the committed
   `check.sh`; results committed under
   `skills/loop/evals/benchmarks/2026-09-09/`. Eval 1 must show at least one
   telemetry `commit` value resolving to a real git object — that is the
   assertion this whole cycle exists to make possible.
4. `bash scripts/test-docs-consistency.sh`, `check-description-budget.sh`,
   `check-test-pairing.sh`, `test-install-vendored.sh` → pass;
   `claude plugin validate . --strict` → passes.
