# Superseded by the P25 kata rewrite (2026-07-30)

`benchmark.json` / `benchmark.md` in this directory were produced against the
**previous** eval prompts, which named `./run-tests.sh` and forbade
`python3 -m unittest`. Both arms scored 8/8 there, and the iteration's own notes
name the reason: that instruction told the executor tests were the medium before
the skill said anything, so the eval measured the model, not the skill.

P25 rewrote both prompts to a plain feature request / bug report and moved the
runner requirement into the fixture (`test_cart.py` refuses to import without
`KATA_HARNESS=1`, which only `run-tests.sh` sets), so `.check-log` still exists
for grading without the prompt hinting the method.

**Consequences, stated plainly:**

- This benchmark is **no longer the regression baseline** — it does not
  correspond to the current `evals.json`. Do not compare a new iteration's
  numbers against it.
- **Answered on 2026-07-30: the rewrite did not discriminate.** Two further
  iterations tied at 100%. The first still leaked the grading rule through the
  fixture README; the second removed that leak entirely and the baseline still
  did strict red→green unaided. Per the fallback written above, the kata is now
  labelled regression-only in the README rather than having its 100% cited as
  skill value. See `../2026-07-30/benchmark.json`.
- It is kept rather than deleted because the v0.31.0 evidence is still a true
  record of what was measured then.
