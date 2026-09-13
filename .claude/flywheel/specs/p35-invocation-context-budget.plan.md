# Plan — invocation-context budget (P35)

Spec: [`p35-invocation-context-budget.md`](p35-invocation-context-budget.md) ·
14 tasks · ceiling signed at **4,500 B**, 6 skills in scope.

## Routing

| Tier | Route | Tasks |
| --- | --- | --- |
| T1 mechanical | `haiku/low+delegate` | T3, T13 |
| T2 default | `sonnet/medium` | T1, T2, T4, T5, T12, T14 |
| T3 judgment | `opus/high` | T6, T7, T8, T9, T10, T11 |

Riskiest step: **T11** — `work` is the inner loop every cycle runs, it is
eval-gated, and it is the largest body in scope (8,385 B). Extraction there is
judgment about which prose is a *rule that bites* and which is reference: get it
wrong and every future cycle is silently weaker, with nothing failing.

**Ordering logic.** The gate lands before anything it governs (T1–T3), the
installer before any body is split (T4–T5, spec requirement 5), and the three
skills with **no evals** are extracted first (T6–T8) so the convention is shaken
out where a mistake is cheap, before the eval-gated three (T9–T11).

### T1 — Failing test for the invocation-budget gate
- route: `sonnet/medium`
- changes: `scripts/test-check-invocation-budget.sh` (new)
- check: `bash scripts/test-check-invocation-budget.sh` fails because `scripts/check-invocation-budget.sh` does not exist (exit 127)
- test-first: yes
- scenarios: over budget · under budget · missing budget file · non-numeric budget · skill with an empty body · dangling `references/` citation · `SKIP_INVOCATION_BUDGET=1` prints a notice and exits 0

### T2 — The gate: measure every body, resolve every citation
- route: `sonnet/medium`
- changes: `scripts/check-invocation-budget.sh` (new), `scripts/invocation-budget.txt` (new, `4500`)
- check: `bash scripts/test-check-invocation-budget.sh` prints `ALL PASS`
- test-first: yes
- notes: `wc -c` (bytes, locale-independent); breakdown largest-first; malformed input exits 2 loudly, never silently as zero; budget in its own file so retuning it does not trip `check-test-pairing.sh`

### T3 — See the gate red against `main`
- route: `haiku/low+delegate`
- changes: none (observation, recorded in the task's telemetry line)
- check: `bash scripts/check-invocation-budget.sh` exits non-zero and its breakdown names exactly `help`, `work`, `process`, `run`, `update`, `compound`
- test-first: no
- why a task: this failure is the spec's evidence that the gate measures the real thing; a gate first observed green proves nothing

### T4 — Failing test: the installer must vendor `references/`
- route: `sonnet/medium`
- changes: `scripts/test-install-vendored.sh`
- check: the new assertion fails — a source skill with `references/topic.md` produces a vendored tree without it
- test-first: yes

### T5 — Installer vendors `references/`
- route: `sonnet/medium`
- changes: `scripts/install-vendored.sh` (vendor loop at `:205-213`, manifest, uninstall/restore path)
- check: `bash scripts/test-install-vendored.sh` passes, including install-twice idempotence and a clean uninstall that removes the vendored `references/`
- test-first: yes
- notes: highest-severity failure in the spec — a vendored body citing a file that was never copied degrades every consumer repo silently

### T6 — Extract `help` (8,395 B → ≤ 4,500)
- route: `opus/high`
- changes: `skills/help/SKILL.md`, `skills/help/references/*.md` (new)
- check: `bash scripts/check-invocation-budget.sh` green for `help`; `bash scripts/test-docs-consistency.sh` passes
- test-first: no
- notes: no evals — the command map itself stays in the body (docs-consistency asserts it); only the onboarding narrative moves

### T7 — Extract `update` (5,363 B → ≤ 4,500)
- route: `opus/high`
- changes: `skills/update/SKILL.md`, `skills/update/references/*.md` (new)
- check: `bash scripts/check-invocation-budget.sh` green for `update`; `bash scripts/test-docs-consistency.sh` passes
- test-first: no

### T8 — Extract `compound` (4,716 B → ≤ 4,500)
- route: `opus/high`
- changes: `skills/compound/SKILL.md`, `skills/compound/references/*.md` (new)
- check: `bash scripts/check-invocation-budget.sh` green for `compound`; `bash scripts/test-docs-consistency.sh` passes
- test-first: no

### T9 — Extract `process` (8,280 B → ≤ 4,500)
- route: `opus/high`
- changes: `skills/process/SKILL.md`, `skills/process/references/*.md` (new)
- check: `bash scripts/check-invocation-budget.sh` green for `process`; `bash skills/process/evals/check.sh` at or above its committed pass rate
- test-first: no

### T10 — Extract `run` (5,703 B → ≤ 4,500)
- route: `opus/high`
- changes: `skills/run/SKILL.md`, `skills/run/references/*.md` (new)
- check: `bash scripts/check-invocation-budget.sh` green for `run`; `run`'s eval at or above its committed pass rate
- test-first: no

### T11 — Extract `work` (8,385 B → ≤ 4,500)
- route: `opus/high`
- risk: highest
- changes: `skills/work/SKILL.md`, `skills/work/references/*.md` (new)
- check: `bash scripts/check-invocation-budget.sh` green for every one of the 17 skills; `work`'s eval at or above its committed pass rate
- test-first: no
- notes: the iterate-until-green contract, the telemetry line format and the P27 route-honoring rules are rules that bite — they stay in the body; the rationale behind them is what moves

### T12 — Release precondition: the eval gate
- route: `sonnet/medium`
- changes: none (evals run; results recorded)
- check: `work`, `process` and `run` evals each at or above their committed pass rates, run **before** any version bump (`CLAUDE.md`, P22 phase 2)
- test-first: no

### T13 — Wire the gate into CI
- route: `haiku/low+delegate`
- changes: `.github/workflows/validate-plugins.yml`
- check: `grep -q check-invocation-budget .github/workflows/validate-plugins.yml`, the step sitting beside the P24 description-budget step
- test-first: no

### T14 — Convention, backlog entry, and the release
- route: `sonnet/medium`
- changes: `CLAUDE.md` (repo conventions), `docs/research/improvement-proposals.md` (P35 + decision-log entry), `upgrades/v<version>.md` (new, `requires-action: true`), `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
- check: the full success metric exits 0; `claude plugin validate . --strict` passes
- test-first: no
- notes: `requires-action: true` — vendored repos must re-run the installer to receive `references/`

## Files

**New:** `scripts/check-invocation-budget.sh`, `scripts/test-check-invocation-budget.sh`,
`scripts/invocation-budget.txt`, `skills/{help,update,compound,process,run,work}/references/*.md`,
`upgrades/v<version>.md`.
**Modified:** `scripts/install-vendored.sh`, `scripts/test-install-vendored.sh`,
the 6 `SKILL.md` bodies, `.github/workflows/validate-plugins.yml`, `CLAUDE.md`,
`docs/research/improvement-proposals.md`, both `.claude-plugin/*.json`.
**New dependencies:** none — bash, `python3` only where the existing gates already use it.

## Amendment 2026-09-13 — the extraction check, hardened

`main` recorded that no release has ever been blocked by an eval catching a
regression, and that ten benchmark runs found one skill defect against at least
three in the instrument itself. T12's eval gate is therefore **corroboration,
not the safety net** T9-T11 were leaning on. The owner reaffirmed the full scope
at 4,500 B with this known; the mitigation is to make each extraction prove
itself mechanically instead:

**Every extraction task (T6-T11) additionally checks, before its commit:**
every line removed from the body appears verbatim in a `references/` file that
the surviving body cites, and the citing step is the one that needed it.
Concretely, with `<n>` the skill: `diff` the original body against
`cat skills/<n>/SKILL.md skills/<n>/references/*.md` — the only permitted
differences are the citation lines added and pure reformatting. A removed line
that lands in no reference is a lost rule, and fails the task.

`update` (T7) carries the weakest independent check of the six: `main` names
`/flywheel:update` as the only untested thing that writes in a user's repo. Its
extraction is therefore conservative — the install/uninstall procedure and every
`requires-action` rule stay in the body; only rationale moves.

## Safeguards re-checked against the spec

| Spec safeguard | Where the plan discharges it |
| --- | --- |
| Extraction must not lose a rule | T2's citation resolution · the line-conservation diff in the amendment above (primary) · T12's eval gate (corroboration only) · one commit per skill (T6–T11) so a regression bisects to one body |
| `help`/`update`/`compound` have no evals | T6–T8 check structurally via `test-docs-consistency.sh`; T6 keeps the command map in the body |
| Dangling citation in a vendored install | T4–T5 land *before* the first extraction; `requires-action: true` in T14 |
| Ceiling is policy, not code | T2 puts the number in `invocation-budget.txt`, not the script |
| Escape hatch never silent | T1 scenario for `SKIP_INVOCATION_BUDGET=1` |
| Evals before the bump | T12 ordered ahead of T14 |
