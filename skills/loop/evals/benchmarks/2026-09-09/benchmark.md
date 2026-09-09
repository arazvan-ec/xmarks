# `loop` eval iteration — 2026-09-09 (first run of the suite; gate for P29 / v0.41.0)

**Verdict: gate passes on the final state. The suite found one defect in the
skill and one in itself, on its first outing.**

| Run | Eval | Workdir | Grader |
| --- | --- | --- | --- |
| 1 | 1 cycle-telemetry-and-atomic-commits | git repo | 11/11 ✅ |
| 2 | 2 no-repo-fail-open | non-git | 7/8 ❌ |
| 3 | 1 (re-run, after the fix) | git repo | 11/11 ✅ |
| 4 | 2 (re-run, after the fix) | non-git | 8/8 ✅ |

## The hole this suite was built to close

Before P29, `work`'s cycle telemetry was written by one skill and read by no
test — the P28 gate said so explicitly rather than glossing it. Runs 1 and 3 are
the first time any of it has been checked:

- the JSONL exists, parses, and carries no `tokens` key;
- **four distinct `commit` shas per run, every one resolving to a real commit
  via `git cat-file`.** Run 3's were 7-character abbreviations, which is the form
  executors actually write, and they resolve too.

That last assertion is the whole point. Parsing proves a field is a 40-hex
string; a fabricated sha is also a 40-hex string. Only git separates them.

## Defect 1 — the skill's: prose in a data field

Run 2 wrote `"commit": "none (not a git repo; commits skipped for cycle)"`.

Nothing was fabricated — the value is honest, which is the degradation worth
being glad about. But it puts prose in a field a reader parses, and
`skills/work/SKILL.md` never said what to write when there is nothing to commit.
The convention already existed one paragraph above, for the `cost` object: omit
rather than fill. `commit` now says it too, and run 4 omitted the field on all
11 lines.

An underspecified contract, found by running it. The executor's guess was
reasonable; the text was not complete.

## Defect 2 — the grader's: source and state conflated

Run 3 went red on the sweep test while sweeping nothing. The cycle wrote its own
renderer to `.claude/flywheel/bin/render-run.py` and committed it with the
telemetry — a commit containing **no source at all** — but that file ends in
`.py` and lives under `.claude/`, so it matched both sides of the grader's AND.

Source now means `.py` outside `.claude/`. The regression case went into
`scripts/test-eval-graders.sh` first and was seen red before the fix; the
synthetic swept commit (real source plus flywheel state) is still graded red.

This is the same failure mode v0.40.1 fixed in the `work` grader one release
earlier: a property mechanized as one surface form that correct behaviour does
not always take. Two in two releases is a pattern worth naming, not a
coincidence.

## What else the runs showed

- Run 1's review caught a **High** the run's own tests missed: `restock`
  credited *every* duplicate line item with the same name (total 5 → 11, expected
  8). It looped back to `work`, fixed it, and pinned it with a regression test.
  The fixture is not a toy that only ever goes green.
- Run 3's executor volunteered that it had briefly written a placeholder sha and
  replaced it with the real one, citing the skill's ban — the rule added after
  run 2, being followed.

## Limits of this evidence

- **Both evals run a cycle that passes its gates.** A cycle whose `verify` comes
  back FAIL, or whose `review` finds a Critical, is untested: the telemetry of a
  *blocked* cycle is graded by nothing. That is the next gap, and it is stated
  here rather than left for someone to discover.
- The `Task` tool was unavailable to all four executors, so `review` ran inline
  every time. Parallel specialist dispatch is not exercised by this suite.
- No `without_skill` arm: a bare model given this fixture would not write
  flywheel telemetry at all, so the comparison would measure nothing.
