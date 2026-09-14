# Plan: P14 slice 3 — the contract defect escalates

Spec: `.claude/flywheel/specs/p14c-contract-defect-escalates.md` (signed 2026-09-14).

## Routing table

| Tier | Route | Tasks |
| --- | --- | --- |
| T2 default | `sonnet/medium` | T1, T3, T4, T5 |
| T3 judgment | `opus/high` | T2 |

**The riskiest step is T2** — splitting step 2's single sentence into two
failures without breaking the one that already works. The Guardrails
partial-failure path is load-bearing for every invalid input a contract will
ever see; a split that accidentally routes those to the new branch would turn
ordinary rejections into blocked runs, and the eval that would catch it
(`run` eval 3, the guardrail case) is not the one this slice is about. Hence
T4 re-runs more than the new eval.

## The constraint

`run`'s body has **552 B** against its 5,800 ceiling. The rules fit only if the
stub's *shape* goes to the reference, which is where it belongs anyway — what to
seed into each REASONS section is a procedure a step consults, not a rule that
bites. If the body does not fit after T3, the plan **stops and reports**: that
ceiling was set two releases ago from a measured body, and moving it again in
the slice that spends it would be exactly the drift the ratchet exists to stop.

### T1 — the fixture and the eval, seen red
- route: `sonnet/medium`
- changes: `skills/run/evals/fixtures/contradictory-contract-repo/` (copy of `demo-repo` whose Output schema caps `digit_sum` at `0–27` while its own Rule 3 computes a sum reaching 36), `skills/run/evals/evals.json`, `skills/run/evals/check.sh`, `scripts/test-eval-graders.sh`
- check: red on today's skill — no stub exists under `specs/`, because the skill offers a blocked run nothing to do; and red on an untouched fixture (P26), which the stub-must-exist assertion gives for free
- test-first: yes

### T2 — step 2 names the two failures apart, and the defect branch
- route: `opus/high`
- risk: highest
- changes: `skills/run/SKILL.md` step 2
- check: `run` eval 3 (the existing guardrail-invalid-input case) still green in T4 — the input-level path is untouched — and eval 5 green; `bash scripts/check-invocation-budget.sh` green
- test-first: yes

### T3 — the stub's shape, in the reference
- route: `sonnet/medium`
- changes: `skills/run/references/ledger-and-extensions.md`
- check: the reference states what evidence seeds which REASONS section and that the stub applies nothing; `run`'s body still under 5,800 with T2 in
- test-first: no

### T4 — the eval gate (P22 phase 2)
- route: `sonnet/medium`
- changes: `skills/run/evals/benchmarks/<date>/benchmark.json`
- check: `run` evals 1, 3, 4 and 5 green — 1 for the happy path, **3 because T2 touches the sentence that routes ordinary rejections**, 4 for the shared stop path, 5 for the new behaviour
- test-first: no

### T5 — docs, bump, upgrade note
- route: `sonnet/medium`
- changes: `docs/research/improvement-proposals.md`, `.claude-plugin/plugin.json`, `upgrades/v0.51.0.md`
- check: the spec's success metric exits 0, 19/19 `scripts/test-*.sh`, every `check-*.sh`, `claude plugin validate . --strict`
- test-first: no

## Safeguards, re-checked against the spec

- *The stub is inert* — T1's grader asserts the contract is byte-identical after the run: no version bump, no schema edit, no Improvement log entry. A run that "escalates" by fixing the thing has not escalated.
- *A defect never becomes a rejection* — asserted on `## Rejections` being untouched, and cross-checked by eval 3 staying green so real rejections still land there.
- *What this gate cannot see* — whether the right defect was diagnosed. The eval proves a stub exists, names both conflicting clauses and applies nothing; the diagnosis stays human, which is why escalating beats fixing.
- *The fixture's path is reachable* — the contradiction blocks the run and the behaviour under test is what happens **at** the block, not behind it. That is the P14b lesson applied at design time instead of discovered at grading time.
