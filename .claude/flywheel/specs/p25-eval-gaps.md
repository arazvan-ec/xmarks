# Spec: P25 — close the gaps the P22 eval iteration exposed

**Slug:** `p25-eval-gaps` · **Created:** 2026-07-30 · **Backlog:** P25
**Status:** shipped as v0.34.0 — metric PASS; eval gate run 2026-07-30: 3/3 process evals, 39/39 assertions, no grader changes needed. Also fixed a hollow `run` eval-2 grader found while preparing the gate. Originally held at the bump because this spec
changes `skills/process/SKILL.md`, and CLAUDE.md requires the skill's eval to
run *before* the version is bumped. That run needs fresh-context subagents
(~120k tokens for `process` alone) and explicit owner authorization, so the
implementation lands complete and unbumped; v0.34.0 is reserved for it.
**Prime:** P25 section in `docs/research/improvement-proposals.md`; the
v0.31.0/v0.32.0 decision-log entries (both name these follow-ups); `run`
SKILL.md §4, which already pins the Improvement-log format `process` §5 lacks.

## R — Requirements

The committed benchmarks are honest about their limits, and those limits are the
work:

1. **`work`'s kata must discriminate.** Both arms scored 8/8 because the prompt
   and `TASK.md` name `./run-tests.sh` and forbid `python3 -m unittest` — that
   tells the executor "tests are the medium here" before the skill says
   anything. Remove every runner/test hint from the prompt and the task
   framing.
2. **Grading must survive requirement 1.** All four assertions read
   `.check-log`, which only `run-tests.sh` writes. Drop the instruction and a
   model that runs `unittest` directly produces no log, so the eval would fail
   for lack of plumbing rather than lack of discipline. The runner must become
   the *only* working path — enforced by the fixture, not by the prompt.
3. **The stale benchmark must not read as current.** `benchmarks/2026-07-29/`
   was produced against the old prompt; after the rewrite it no longer
   corresponds to the eval definition and must be marked superseded rather than
   silently kept as the regression baseline.
4. **`process` §5 pins the Improvement-log entry format**, matching `run` §4
   verbatim, and `skills/process/evals/check.sh` re-tightens to require it —
   reversing the v0.32.0 grader loosening in the correct direction (fix the
   skill, not the grader).
5. **The missing baseline arm becomes a documented, runnable procedure** for
   `process`/`run` — recorded in the README with its cost, explicitly marked
   as not yet run, so "49/49 green" is never mistaken for skill value.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| de-hinted prompts | runner + test framing removed from both katas | `skills/work/evals/evals.json` |
| task framing | functional requirement only, no runner line | `skills/work/evals/fixtures/cart-{feature,bugfix}/{TASK,BUG}.md` |
| harness guard | suite refuses to run outside `run-tests.sh` | `.../fixtures/cart-*/test_cart.py`, `.../run-tests.sh` |
| superseded marker | the 2026-07-29 benchmark is no longer the baseline | `skills/work/evals/benchmarks/2026-07-29/SUPERSEDED.md` |
| format pin | Improvement-log template, identical to `run` §4 | `skills/process/SKILL.md` §5 |
| re-tightened grader | requires `### <YYYY-MM-DD> — …` again | `skills/process/evals/check.sh` |
| baseline procedure | how to run the value study, and that it is unrun | `README.md` |

## A — Approach

**Requirement 2 is the load-bearing one.** Rather than trusting the prompt to
route the executor to `run-tests.sh`, the fixture enforces it: `test_cart.py`
refuses to import unless `KATA_HARNESS=1` is set, which only `run-tests.sh`
sets, and the refusal message names the runner. So the audit log always exists
whichever arm runs, the discovery path is natural (`ls`, then a clear error if
you guess wrong), and the prompt can be a plain feature request. This mirrors
real repos where the suite needs a harness — it is not a trick.

The prompt keeps "execute plan task 3 (TASK.md)": that is `work`'s documented
trigger ("executing tasks from an approved plan"), not a TDD hint. What goes is
every mention of tests, runners, and ordering.

**Honesty about what this does and does not prove.** The rewrite is *designed*
to discriminate; whether it *does* is unverified, because verifying it means
running the eval and I am not authorized to spend subagents here. So the README
says the discrimination is untested and the old benchmark is superseded rather
than replaced. Requirement 5 is documentation on purpose — running the baseline
study is a separate, authorized act.

Rejected: keeping the runner mention and calling the eval regression-only (the
proposal's fallback — it forfeits the fix rather than attempting it); patching
`check.sh` to accept a dated bullet forever (v0.32.0 already chose that as the
temporary path and flagged fixing the skill as the follow-up).

## S — Structure

- `skills/work/evals/evals.json` — 2 prompts rewritten
- `skills/work/evals/fixtures/cart-feature/{TASK.md,test_cart.py,run-tests.sh,README.md}`
- `skills/work/evals/fixtures/cart-bugfix/{BUG.md,test_cart.py,run-tests.sh,README.md}`
- `skills/work/evals/benchmarks/2026-07-29/SUPERSEDED.md` (new)
- `skills/process/SKILL.md` — §5 gains the format block
- `skills/process/evals/check.sh` — dated-entry assertion re-tightened
- `README.md` — baseline-arm procedure + unrun status
- **No version bump** (see Status); `upgrades/` untouched

## O — Operations

1. Add the harness guard to both fixtures and set `KATA_HARNESS=1` in both
   runners; confirm `python3 -m unittest` now refuses and `./run-tests.sh`
   still writes `.check-log`.
2. Strip runner/test hints from `evals.json`, `TASK.md`, `BUG.md`; refresh the
   fixture READMEs.
3. Write `SUPERSEDED.md` next to the stale benchmark.
4. Pin the format in `process` §5; re-tighten `check.sh`; verify the grader is
   red on a dated *bullet* and green on a `### <date>` heading.
5. README: baseline procedure, cost, unrun status.
6. Run the repo check suite. Stop before the bump; record the pending gate.

## N — Norms

Fixture edits stay minimal and stdlib-only. `check.sh` is not under `scripts/`,
so the pairing gate does not apply — it is itself the test. The guard uses one
env var and one clear message; no new dependency.

## S — Safeguards

- **Grading can never silently stop working**: step 1 is verified by hand
  (`.check-log` written via the runner, refusal on direct `unittest`) before the
  prompts lose their hint, so the two changes are never in flight together
  untested.
- **The stale benchmark is marked, not deleted** — the evidence of the v0.31.0
  iteration stays readable, it just stops being the current baseline.
- **The grader is re-tightened only after the skill pins the format**, so the
  gate never demands something the skill does not instruct.
- **No bump without the eval gate** — the whole point of P22 phase 2.

## Success metric

One command, exit 0 = PASS (note what it deliberately cannot assert: that the
rewritten kata discriminates — that needs an authorized eval run):

```bash
python3 -c "import json;d=json.load(open('skills/work/evals/evals.json'));
import sys;t=' '.join(e['prompt'] for e in d['evals']).lower();
sys.exit(0 if not any(k in t for k in ['run-tests','unittest','test-first','test first']) else 1)" \
  && ! grep -q 'run-tests' skills/work/evals/fixtures/cart-feature/TASK.md \
  && ! grep -q 'run-tests' skills/work/evals/fixtures/cart-bugfix/BUG.md \
  && grep -q 'KATA_HARNESS' skills/work/evals/fixtures/cart-feature/run-tests.sh \
  && grep -q 'KATA_HARNESS' skills/work/evals/fixtures/cart-bugfix/run-tests.sh \
  && test -f skills/work/evals/benchmarks/2026-07-29/SUPERSEDED.md \
  && grep -q '### <YYYY-MM-DD>' skills/process/SKILL.md \
  && grep -q '\^### 20' skills/process/evals/check.sh \
  && grep -qi 'baseline arm' README.md \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/test-install-vendored.sh \
  && bash scripts/check-test-pairing.sh
```
