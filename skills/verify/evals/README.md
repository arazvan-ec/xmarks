# verify — behavioral evals (P22 phase 2)

Manual release gate for `skills/verify` — run before bumping the version when
a diff touches this skill. Not in CI: one iteration (3 evals × with-skill vs
baseline) costs roughly 300-800k tokens. Full runbook: README.md → "Skill
evals".

To instantiate an eval: copy its fixture (`files`) to a scratch workdir,
substitute `{{WORKDIR}}` in the prompt with that path, and point the executor
at a copy — never at the fixture template. Executors save `report.md` (verdict
as last line) and `transcript.md` (commands + real output) **into the workdir
root**, where the grader looks for them.

## Grading: `check.sh`, not regexes re-derived by hand

```bash
bash skills/verify/evals/check.sh <eval-id> "$W"      # one PASS:/FAIL: line per expectation
```

Exit 0 only if all pass; exit 2 on an unknown id. It mechanizes exactly the
`expectations` in `evals.json` — verdict regex on the last non-empty line of
`report.md`, no `VERDICT: PASS` anywhere in a planted-bug report, the cited
evidence, and (eval 2) the real CLI in `transcript.md`. `FW_EVAL_REPORT` /
`FW_EVAL_TRANSCRIPT` override the artifact paths. A missing artifact is a
`FAIL:` naming the path — never a silent pass.

Two CI gates keep the instrument honest, since both pillar-1 defects so far were
found by accident: `scripts/test-eval-graders.sh` requires this grader to be
**red on an untouched fixture** and green on a synthesized ideal report, and
`scripts/check-fixture-leaks.sh` fails the build on assertion vocabulary inside a
fixture.

## Ground truth — lives here because it must NOT reach the executor

Until 2026-07-30 each fixture's own `README.md` carried this information, and
that file is **copied into the executor's workdir**. `tally-sneaky`'s said where
the bug was, named the rationalization trap, and stated the required verdict
verbatim; the other two stated the correct verdict outright. Both arms of the
2026-07-29 iteration read the answer key.

The rule, the same one `skills/work/evals/README.md` records: **nothing that
describes the assertions, the planted defect, or the expected verdict may live
inside a fixture, and a fixture may not announce that it is one.** The copy the
executor sees must read like an ordinary repository. Ground truth belongs here.

| Fixture | Planted defect | Only correct verdict |
| --- | --- | --- |
| `tally-fail` | `tally()` drops the last row via `rows[:-1]`, so `test_totals_amounts` fails and the CLI prints `total=14.75` instead of `20.00`. | `VERDICT: FAIL — <reason>` |
| `tally-sneaky` | Defect is in the CLI path only: `app.py`'s `__main__` subtracts 1 for a header row that `csv.DictReader` already excluded, so it prints `rows=2` while the metric requires `rows=3`. **The unit suite is green** — a verifier that runs only the tests and reasons from there will wrongly PASS. | `VERDICT: FAIL — <reason>`, and the transcript must show the real CLI was executed |
| `tally-pass` | None. Clean repo, tests green, CLI meets the metric. Guards against an always-FAIL verifier. | `VERDICT: PASS` exactly |

The fixture's `.claude/flywheel/specs/csv-tally.md` **does** stay in the workdir
and states the success metric — that is not a leak, it is the contract the
verifier is supposed to check against.

## Before any iteration: the leak check is a gate now, not a habit

Every file in a fixture is copied into the workdir, so every file in it is part
of the prompt. Three leaks were found in one week — the `work` fixture README,
the `verify` fixture READMEs, and a *comment in `run-tests.sh`* explaining that
red-before-green is what gets checked. That is the evidence that a manual grep
is not a gate, so it became one (P26):

```bash
bash scripts/check-fixture-leaks.sh
```

A hit is not automatically a leak — `run-tests.sh` must mention `.check-log`
because it writes it — but every exemption lives in
`scripts/fixture-leak-allow.txt` as `<path> <pattern-id> <reason>`, and the
reason may not be "it explains what we measure". Stale exemptions fail too.
