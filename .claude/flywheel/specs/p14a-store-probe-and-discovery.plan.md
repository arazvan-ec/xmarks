# Plan: P14 slice 1 — store probe + process discovery

Spec: `.claude/flywheel/specs/p14a-store-probe-and-discovery.md` (signed 2026-09-14).

## Routing table

| Tier | Route | Tasks |
| --- | --- | --- |
| T1 mechanical | `haiku/low+delegate` | T7 |
| T2 default | `sonnet/medium` | T1, T2, T3, T5, T6, T8, T9, T10 |
| T3 judgment | `opus/high` | T4 |

**The riskiest step is T4** — the read-only probe and what happens when it
fails. It is the one task where a wrong choice is silent and expensive in both
directions: a probe that writes would be a Guardrail breach committed by the
safety check itself, and an automatic fallback would scatter a process's records
across two stores with nobody told. Everything else in this plan is prose or
plumbing around that decision.

## The constraint this plan has to design around

`run`'s body is **4,498 B against a 4,800 ceiling — 302 B of headroom** — and
T3/T4/T5 all add rules to its step 1. The new rules are rules that bite, so by
P39's own finding they belong in the body, not behind a citation. T2 therefore
comes **first** and buys the room the way P39 did: the argument leaves, the
rules stay. If T2 does not free enough, the plan stops and reports rather than
raising the ceiling — the `e4d552e` precedent, and the reason T2 is ordered
before the tasks that spend what it frees.

### T1 — the session banner lists the repo's contracts
- route: `sonnet/medium`
- changes: `scripts/session-start.sh`, `scripts/test-session-start.sh`
- check: `bash scripts/test-session-start.sh` — new assertions green: a fixture repo with two contracts prints both slugs with their Purpose one-liner under the Runtime line; a repo with none prints nothing extra; a malformed contract file prints nothing and exits 0
- test-first: yes

### T2 — buy the room in `run`'s body before spending it
- route: `sonnet/medium`
- changes: `skills/run/SKILL.md`, `docs/research/` (a rationale doc, uncited by any skill)
- check: `bash scripts/check-invocation-budget.sh` green and `run`'s body at least 400 B under 4,800, with every imperative it holds today still an imperative in the body
- test-first: no

### T3 — a missing DATA.md stops the run at step 1
- route: `sonnet/medium`
- changes: `skills/run/SKILL.md` step 1
- check: `grep` confirms step 1 states the stop and names `/flywheel:process`; `bash scripts/check-invocation-budget.sh` still green
- test-first: no

### T4 — the read-only write-path probe, and the blocker when it fails
- route: `opus/high`
- risk: highest
- changes: `skills/run/SKILL.md` step 1 (the probe, its read-only constraint, the stop-as-blocker report and the explicit ban on falling back silently)
- check: the new eval (T8) goes green — with an unreachable store declared, the workdir afterwards holds no result file and no partial row, and the run reports a blocker rather than a completed run with an empty result
- test-first: yes

### T5 — a bare `/flywheel:run` lists the contracts instead of dead-ending
- route: `sonnet/medium`
- changes: `skills/run/SKILL.md` step 1
- check: `grep -qi 'no slug' skills/run/SKILL.md`, and the branch points at `/flywheel:process` only when `processes/` is empty; budget gate still green
- test-first: no

### T6 — `process`: no database signal is a detection, not a dead end
- route: `sonnet/medium`
- changes: `skills/process/references/data-strategy-and-extensions.md`
- check: the reference states the git-native strategy as the proposal when no signal hits (confirm, don't ask open-ended) and requires the define-time probe before DATA.md is written; `process` eval 1 still green in T9
- test-first: no

### T7 — the eval fixture with an unreachable declared store
- route: `haiku/low+delegate`
- changes: `skills/run/evals/fixtures/unreachable-store-repo/` (copy of `demo-repo` whose DATA.md declares a Postgres on port 1 — reserved, never listening, so the refusal is deterministic and offline; nothing else differs)
- check: `bash scripts/check-fixture-leaks.sh` green and `diff -r` against `demo-repo` shows DATA.md as the only difference
- test-first: no

### T8 — the eval and its grader, asserted as negatives
- route: `sonnet/medium`
- changes: `skills/run/evals/evals.json`, `skills/run/evals/check.sh`
- check: the grader is red on an untouched fixture and green only when the run stopped before the first Rule — no result file, no partial row, no fabricated output fields
- test-first: yes

### T9 — the eval gate (P22 phase 2)
- route: `sonnet/medium`
- changes: `skills/run/evals/benchmarks/<date>/benchmark.json`, `skills/process/evals/benchmarks/<date>/benchmark.json`
- check: `run` eval 1 green (the happy path did not regress), the new eval green, `process` eval 1 green — all three recorded with their counts before any version bump
- test-first: no

### T10 — docs, bump, upgrade note
- route: `sonnet/medium`
- changes: `README.md` and `skills/help/SKILL.md` only if the surface wording changed, `docs/research/improvement-proposals.md`, `.claude-plugin/plugin.json`, `upgrades/v0.49.0.md`
- check: the spec's full success metric exits 0, 19+/19 `scripts/test-*.sh`, every `check-*.sh`, `claude plugin validate . --strict`
- test-first: no

## Safeguards, re-checked against the spec

- *The probe never writes* — T4 states it and T8 asserts it: the fixture's store is unreachable, so any write attempt fails loudly rather than passing silently.
- *No secrets in the banner* — T1's assertions print slug and Purpose only; the Access line, where a connection string lives, is never read.
- *What this gate cannot see* — T4 narrows the window between check and write; it cannot close it, so step 3's read-back evidence stays exactly as it is. Stated in the skill, not just here.
- *The stop path is a blocker, not a silent skip* — T8's grader asserts the distinction, since a run that "completes" with an empty result is the failure this slice exists to prevent.

## Revision (2026-09-14, during work)

**Execution order corrected: T7 and T8 run before T4.** T4 carries
`test-first: yes` and its check is "the new eval goes green" — an eval that T8
builds. Implementing T4 first and writing its test afterwards is precisely the
inversion `/flywheel:work`'s anti-rationalization table bans ("I'll verify
everything at the end"), and the plan's own ordering asked for it. The fixture
and the grader now come first, are seen **red** against the current skill (the
run proceeds into the Rules and fails late), and T4 is what turns them green.

Task content is unchanged; only the order is. Recorded here rather than
diverging silently, per `/flywheel:sync`'s rule that the plan is the contract.

## Revision 2 (2026-09-14) — T5 deferred to slice 2

T4's rules took the body to 4,819/4,800. The plan's own instruction at that point
is to stop and report rather than raise the ceiling, and that is what happened;
what unblocked it was the remedy the gate itself prints, not a bigger number:
the store-tool catalogue in step 3 (`a psql/CLI command, a Postgres/Supabase MCP
call, an ORM/repo script`) is a **catalogue**, which by the P35 convention
belongs in `references/`. Moved there with the probe recipes.

That lands the body at **4,746/4,800 — 54 B**, which fits T4 and does not fit
T5. So **T5 moves to slice 2**. It is the least costly deferral available: T1
already lists every contract in the session banner, so a repo can see its
processes from the moment it starts; what T5 adds is the same list from a bare
`/flywheel:run`.

Stated plainly: **54 B is not comfortable**, and it is the same brittleness this
line of work keeps naming. Slice 2 opens by buying room in `run` again — or by
deciding, with the numbers in hand, that a body of nothing but rules has outgrown
4,800 and the ceiling should move by the headroom rule, the way `work`'s did.
That is a decision for the start of slice 2, made deliberately, not a side effect
of needing space today.
