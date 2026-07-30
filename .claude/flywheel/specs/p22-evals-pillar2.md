# Spec: P22 phase 2 (pillar 2) — behavioral evals for `process` and `run`

**Slug:** `p22-evals-pillar2` · **Created:** 2026-07-29 · **Backlog:** P22 phase 2
**Status:** shipped as v0.31.0 — metric PASS; eval iteration 1: 6/6 evals green, 49/49 assertions (two grader fixes, no skill regression). Renumbered from v0.30.0 at rebase (the optimization release claimed it first).
**Prime:** P22 section in `docs/research/improvement-proposals.md`; the
`type=fixture` learning "how to build a hook-test fixture"; skill-creator
harness (`evals/evals.json` schema, grader, `benchmark.json`).

## R — Requirements

Skills are prompts — structural checks can't catch a behavioral regression in
the pillar-2 skills where Claude *is* the backend. Give `process` and `run`
release-gate evals per the skill-creator harness:

1. `skills/process/evals/evals.json` — 2-3 realistic prompts; objective
   assertions: the generated contract at
   `.claude/flywheel/processes/<slug>.md` has frontmatter, numbered **fixed
   Rules**, an **Improvement log** (maturation) section left empty at
   creation, and a **Progress reporting** section naming
   `.claude/flywheel/runs/`.
2. `skills/run/evals/evals.json` — over a simple fixture contract: the run
   **persists per DATA.md** (row lands in the datastore file and is staged),
   **respects the contract's fixed rules** (deterministic output fields are
   exactly right; guardrail path on invalid input; idempotent upsert), and
   **regenerates the telemetry report** in `.claude/flywheel/runs/<slug>/`.
3. The fixture contract is **versioned next to the evals** and registered as
   a `type=fixture` learning (with `evidence=` from a real run).
4. README documents how to run an eval manually **before a release that
   touches these skills** — never in CI (a 3-case × 2-config iteration costs
   ~300-800k tokens).
5. At least one real iteration of each suite executed; `benchmark.json`
   committed as evidence.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| eval suite ×2 | prompts + assertions (skill-creator schema) | `skills/{process,run}/evals/evals.json` |
| fixture repo | mini target repo: `DATA.md`, `plate-audit` contract v1, seeded datastore | `skills/run/evals/fixtures/demo-repo/`, mirrored at `skills/process/evals/fixtures/target-repo/` |
| grader script ×2 | deterministic assertion checker `check.sh <eval_id> <workdir>` | `skills/{process,run}/evals/check.sh` |
| benchmark evidence | one graded iteration per suite | `skills/{process,run}/evals/benchmarks/2026-07-29/benchmark.json` |
| fixture learning | recipe to stand the fixture up | `.claude/flywheel/LEARNINGS.md` (`type=fixture`) |
| release | bump + upgrade note | `.claude-plugin/plugin.json`, `upgrades/v0.31.0.md` |

## A — Approach

Adopt the skill-creator harness as-is (evals.json schema; executor subagent
with skill path + task; grader → grading.json → benchmark.json) instead of
inventing a runner. Fixture process `plate-audit` is deliberately trivial and
fully deterministic (parse a Spanish plate, digit-sum checksum, upsert a
markdown table row) so every assertion is a grep, not a judgment call.
Graders are committed `check.sh` scripts — objective, reusable across
iterations, and they double as the assertion source of truth. Executors run
with-skill only for the release gate (regression detection); the with/without
baseline comparison stays documented as the optional full procedure — halving
the per-iteration cost is worth more than re-proving the skill's value each
release. Rejected: CI wiring (cost), a new `scripts/run-eval.sh` runner
(the procedure is 4 commands; a script would need its paired test and adds
surface for no determinism gain).

## S — Structure

- `skills/process/evals/{evals.json,check.sh,fixtures/target-repo/**}`
- `skills/run/evals/{evals.json,check.sh,fixtures/demo-repo/**}`
- `skills/{process,run}/evals/benchmarks/2026-07-29/benchmark.json`
- `.claude/flywheel/LEARNINGS.md` — one `type=fixture` entry
- `README.md` — "Skill evals" section (manual, pre-release, cost note)
- `.claude-plugin/plugin.json` → **0.31.0** · `upgrades/v0.31.0.md`
  (`requires-action: false`)

## O — Operations

1. Fixture: write `demo-repo` (DATA.md, `plate-audit.md` v1, seeded
   `data/plate-audits.md`), mirror for process evals.
2. Evals + `check.sh` per skill (process: new-contract / DATA.md-bootstrap /
   mature-existing; run: happy-path / idempotent-upsert / invalid-input).
3. Execute one iteration: 6 executor subagents (fresh context, with skill),
   grade via `check.sh`, aggregate `benchmark.json` (skill-creator schema).
4. LEARNINGS fixture entry (`evidence=` the benchmark).
5. README section; rebase on `origin/main`; bump; verify; telemetry report.

## N — Norms

Eval files live under `skills/<name>/evals/` (skill-creator layout); the
installer vendors only `SKILL.md`, so they add no vendored weight. `check.sh`
is not under `scripts/`, so the pairing gate doesn't apply — it *is* the test.
No runtime skill text changes. Writing-token discipline: fixture and contract
kept minimal.

## S — Safeguards

- **Assertions must be objective**: every check.sh assertion greps a
  deterministic artifact (exact field values for a known input), never "looks
  good". A hallucinated-but-plausible contract fails on structure, not vibes.
- **Executor prompts declare eval mode** (gates pre-approved, task
  system/artifact publishing unavailable → the skills' own fail-open paths),
  so runs terminate without human input yet still exercise the contract law.
- **No CI hook-up**: docs say manual-only; nothing in
  `.github/workflows/` changes.
- **Fixture is inert**: `demo-repo` is data, not an installable skill; no
  executable code beyond `check.sh`.

## Success metric

One command, exit 0 = PASS:

```bash
python3 -c "import json;[json.load(open(p)) for p in ['skills/process/evals/evals.json','skills/run/evals/evals.json']]" \
  && test -f skills/run/evals/fixtures/demo-repo/.claude/flywheel/processes/plate-audit.md \
  && test -x skills/process/evals/check.sh && test -x skills/run/evals/check.sh \
  && python3 -c "import json,sys;b=[json.load(open(f'skills/{s}/evals/benchmarks/2026-07-29/benchmark.json')) for s in ['process','run']];sys.exit(0 if all(len(x['runs'])>=2 for x in b) else 1)" \
  && grep -q 'type=fixture' .claude/flywheel/LEARNINGS.md && grep -q 'plate-audit' .claude/flywheel/LEARNINGS.md \
  && grep -qi 'skill evals' README.md \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/test-install-vendored.sh \
  && bash scripts/check-test-pairing.sh \
  && grep -q '"version": "0.31.0"' .claude-plugin/plugin.json \
  && test -f upgrades/v0.31.0.md
```
