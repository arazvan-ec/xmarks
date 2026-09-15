# Plan: P42 — the telemetry duty gets an owner that runs

**Spec:** `.claude/flywheel/specs/p42-telemetry-has-an-owner.md`

## Routing table

| Tier | Route | Tasks |
| --- | --- | --- |
| T3 judgment | `opus/high` | T4 |
| T2 default | `sonnet/medium` | T1, T2, T3, T6 |
| T1 mechanical | `haiku/low+delegate` | T5, T7 |

The riskiest step is **T4**, ungating the duty in `work`: it is the only task
that changes what a skill *does at runtime*, and `work` runs standalone inside
every eval fixture — an ungated write can leak into fixtures or move a grader.
The gate script (T2) is the safer half; it only reads.

T3 is routed a tier above mechanical on purpose. Last cycle's one escalation was
a task called mechanical whose real content was judgment; classifying which specs
are cycles and which are design notes is the same shape.

### T1 — Red: the gate's cases
- route: `sonnet/medium`
- changes: `scripts/test-check-telemetry.sh` — conforming telemetry passes; a
  line missing contract keys fails; a `tokens` key fails; a spec with neither
  telemetry nor a baseline entry fails and is named; a baselined spec passes; a
  baseline entry with no reason fails; `.plan.md` files are not treated as specs.
- check: `bash scripts/test-check-telemetry.sh` fails naming a case.
- test-first: yes

### T2 — Green: check-telemetry.sh
- route: `sonnet/medium`
- changes: `scripts/check-telemetry.sh` — conformance over every `runs/**.jsonl`,
  coverage over every spec slug not baselined, `SKIP_TELEMETRY_CHECK=1` logged.
- check: `bash scripts/test-check-telemetry.sh` prints ALL PASS.
- test-first: yes

### T3 — The baseline, every entry with its reason
- route: `sonnet/medium`
- changes: `scripts/telemetry-baseline.txt` — the ten cycles that shipped
  unmeasured, plus the specs that are design notes rather than cycles, each with
  the reason it is exempt. No file is invented for any of them.
- check: `bash scripts/check-telemetry.sh` green on the current tree, and its
  output states the size of the debt rather than hiding it.
- test-first: no

### T4 — Ungate the duty in `work`
- route: `opus/high`
- risk: highest
- changes: `skills/work/SKILL.md` — drop the `Inside a /flywheel:loop cycle`
  precondition so the transition line is appended whenever `work` runs. Fail-open
  wording stays; HTML stays with `loop`.
- check: the clause is gone; `bash scripts/check-invocation-budget.sh` and
  `bash scripts/check-fixture-leaks.sh` both green.
- test-first: no (prose), but its eval runs at T6 before the version moves

### T5 — CI, docs, release
- route: `haiku/low+delegate`
- changes: the gate wired into `.github/workflows/validate-plugins.yml`; README;
  `.claude-plugin/plugin.json` → `0.53.0`; `upgrades/v0.53.0.md`.
- check: `bash scripts/test-docs-consistency.sh` and
  `bash scripts/check-test-pairing.sh` green; upgrade frontmatter matches manifest.
- test-first: no

### T6 — Release gate: run `work`'s eval
- route: `sonnet/medium`
- changes: none — run and report. CLAUDE.md gates a `work` behavior change on its
  eval before the bump.
- check: `skills/work/evals/check.sh` results reported honestly, including any
  case the ungating moved.
- test-first: no

### T7 — Run the spec's success metric
- route: `haiku/low+delegate`
- changes: none — run and report, including the decisive probe (an uncovered
  slug must make the gate exit 1 and name it).
- check: the metric command exits 0 and the probe fails as designed.
- test-first: no

## Safeguards re-checked

| Spec safeguard | Where the plan addresses it |
| --- | --- |
| no fabricated telemetry | T3 records absence only; no task writes a `runs/` file |
| ungating must not leak into fixtures | T4's check gates on `check-fixture-leaks.sh`; T6 runs the eval |
| fail-open preserved in the skill | T4 keeps the wording; the gate lives in CI, not in the cycle |
| the baseline is a debt list | T1 fails an entry with no reason |
