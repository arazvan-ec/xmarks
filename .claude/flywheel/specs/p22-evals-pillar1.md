# p22-evals-pillar1 — behavioral evals for `verify` and `work` (P22 phase 2, pillar 1)

Owner ask (2026-07-29): implement P22 phase 2 for pillar 1 — skill-creator-style
behavioral evals for `skills/verify` and `skills/work`, with planted-bug
mini-repo fixtures, at least one real benchmark iteration as evidence, and a
README runbook for running them manually before a release (never in CI).

## R — Requirements

Skills are prompts; structural checks can't catch a behavioral regression
(`verify` starting to rationalize a FAIL into a PASS, `work` skipping the red
step). In scope:

1. `skills/verify/evals/evals.json` — 2-3 realistic prompts + objective
   assertions. Core: on a planted-bug fixture the report's last line is
   `VERDICT: FAIL — <reason>` and the report never rationalizes the failure
   into a PASS; a clean control fixture must end `VERDICT: PASS` (guards
   against an always-FAIL verifier).
2. `skills/work/evals/evals.json` — 2-3 realistic prompts + objective
   assertions. Core: evidence that the test ran red BEFORE the implementation
   changed — enforced by a fixture-side `run-tests.sh` that appends
   `RESULT=... IMPL_SHA=...` to a log the executor can't reorder.
3. Fixtures (mini-repos with planted bugs) versioned under
   `skills/<name>/evals/fixtures/`, registered as `type=fixture` learnings.
4. One real benchmark iteration per skill (with-skill vs baseline), committed
   under `skills/<name>/evals/benchmarks/` as evidence.
5. README documents how to run an eval manually before a release touching
   these skills. Evals are NOT wired into CI (≈300-800k tokens/iteration).

Out of scope: pillar 2 (`process`/`run`) — parallel session; automation of the
release gate; eval viewer hosting.

## E — Entities

| Entity | Where | Role |
| --- | --- | --- |
| `evals.json` | `skills/{verify,work}/evals/` | skill-creator schema: prompts + `expectations` |
| fixtures | `skills/{verify,work}/evals/fixtures/<slug>/` | read-only templates; runs copy them to a scratch dir |
| `run-tests.sh` (work fixtures) | inside each work fixture | sole test entrypoint; appends `RESULT` + `IMPL_SHA` to `.check-log` |
| `benchmark.json`/`.md` | `skills/<name>/evals/benchmarks/<date>/` | committed evidence of a real iteration |
| fixture learnings | `.claude/flywheel/LEARNINGS.md` | `type=fixture` recipes for both fixture families |

## A — Approach

Adopt the skill-creator harness as-is (evals.json schema, with-skill vs
baseline subagent runs, grader → benchmark.json) rather than inventing one.
Objectivity comes from the fixtures, not the grader's taste: verify fixtures
plant a bug whose ground truth is known (tests fail; or tests pass but the
real run misses the spec metric — the rationalization trap); work fixtures
log every test run with a content hash of the implementation file, so
"red before green, with the impl untouched at red time" is mechanically
checkable from `.check-log`.

## S — Structure

- `skills/verify/evals/{evals.json, fixtures/{tally-fail,tally-sneaky,tally-pass}/}`
- `skills/work/evals/{evals.json, fixtures/{cart-feature,cart-bugfix}/}`
- `skills/{verify,work}/evals/benchmarks/2026-07-29/benchmark.{json,md}`
- README: "Skill evals (manual release gate)" section
- LEARNINGS.md: two `type=fixture` entries

## O — Operations

1. Build fixtures; sanity-check each planted state by running it.
2. Write evals.json (prompts + assertions).
3. Run iteration 1: for each eval, with-skill + baseline subagents in
   parallel; grade against assertions; aggregate benchmark; commit evidence.
4. Register fixture learnings; write README runbook.
5. Rebase on main, bump version, upgrade note, push.

## N — Norms

Fixtures use only python3 stdlib (`unittest`) — no installs. Fixture scripts
live outside `scripts/` so the test-pairing gate doesn't apply. Writing-token
discipline: never echo fixture code into chat.

## S — Safeguards

- A clean control fixture keeps the verify eval honest (always-FAIL fails it).
- `IMPL_SHA` in the work log defeats "write impl first, then test": the first
  logged FAIL must carry the pristine impl hash (committed as `baseline-sha`).
- Fixtures are templates; prompts direct the executor to work on a copy so
  runs never dirty the versioned fixture.

## Success metric

```
python3 - <<'EOF'
import json, os, re
for skill, n_min in (("verify", 2), ("work", 2)):
    d = json.load(open(f"skills/{skill}/evals/evals.json"))
    assert d["skill_name"] == skill and len(d["evals"]) >= n_min
    assert all(e["prompt"] and e["expectations"] for e in d["evals"])
    bdirs = [p for p in os.listdir(f"skills/{skill}/evals/benchmarks")]
    assert bdirs, f"no benchmark evidence for {skill}"
    b = json.load(open(f"skills/{skill}/evals/benchmarks/{sorted(bdirs)[-1]}/benchmark.json"))
    configs = {r["configuration"] for r in b["runs"]}
    assert {"with_skill", "without_skill"} <= configs
    assert b["run_summary"]["with_skill"]["pass_rate"]["mean"] >= 0.75
assert os.path.isdir("skills/verify/evals/fixtures/tally-fail")
assert os.path.isdir("skills/work/evals/fixtures/cart-feature")
readme = open("README.md").read()
assert "evals" in readme and "not in ci" in readme.lower()
learn = open(".claude/flywheel/LEARNINGS.md").read()
assert len(re.findall(r"type=fixture", learn)) >= 3
print("P22-pillar1 metric: PASS")
EOF
```

Exits 0 printing `P22-pillar1 metric: PASS`.
