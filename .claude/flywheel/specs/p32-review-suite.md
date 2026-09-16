# Spec: P32 — a `review` eval suite, and an honest label on what it covers

**Slug:** `p32-review-suite` · **Created:** 2026-09-16 · **Backlog:** P32
**Status:** in progress.

**Prime:** P32 (the two options and the dishonest third), P26 (ground truth lives
in the grader, never in the workdir), P33 (solutions as committed assets), P31
(when a fixture ties, the honest deliverable is the label), and the
v0.40.1/v0.41.0 record of a property mechanized as **one surface form** failing
correct runs twice.

## R — Requirements

`skills/review/` has **no evals directory at all**. Its routing rules are prose
that nothing checks — a docs-only diff draws correctness alone; `reviewer-security`
is drawn only when the diff touches input handling, auth, secrets or dependencies
— and every run so far has applied them by hand.

Underneath that sits the older gap: a subagent cannot spawn subagents, so `Task`
is unavailable in every eval executor this repo runs, and **parallel specialist
dispatch has never once been exercised**. The README nevertheless describes the
fan-out as a feature.

In scope:

1. A `review` suite in the shape of the existing ones — `evals.json`, fixtures,
   `check.sh`, committed solutions with a `MANIFEST`, arms in
   `scripts/test-eval-graders.sh`.
2. **Routing graded from an artifact**: which reviewers the run *drew* for a
   given diff, not the prose describing the choice.
3. **Option B** — when dispatch cannot happen, the report must **say so**
   instead of reading as if three specialists ran.
4. One README edit describing the fan-out as **untested by the suites**, and an
   `evals.json`/README/benchmark label saying this suite covers **reporting and
   routing, not dispatch**.
5. Option A as a **documented manual arm** only: a runbook step saying it is run
   by hand from a top-level session where `Task` exists, and a benchmark that
   says plainly it has not been run.

Out of scope: making dispatch happen inside a subagent. It cannot, and pretending
otherwise is the dishonest option this proposal exists to refuse.

Out of scope as an assertion: the **"under ~20 changed lines → one reviewer"**
rule. `~20` is a tie by construction, and mechanizing a guess about where it
falls is how the `work` grader spent four releases failing correct runs. Both
graded fixtures sit far from it (a docs-only diff, and diffs of 40+ lines).

## E — Entities

- **`docs-change-repo`** — a small library whose pending change touches only
  `README.md`, `docs/usage.md` and two code comments. The unambiguous case: the
  docs-only rule and the small-diff rule agree, so correctness alone is right.
- **`ops-console-repo`** — a Flask ops console. Two pending changes live under
  `pending/`, and each eval's `setup` applies exactly one and removes the
  directory: `security.patch` (a new handler interpolating the `filter` query
  parameter into SQL, plus a hardcoded fallback token) and `fanout.patch`
  (input handling **and** a per-row query inside a loop **and** a new pinned
  dependency — the substantial cross-domain diff).
- **`.dispatch-log`** — the routing artifact. `Task` does not exist in an eval
  executor, so the fixture ships `dispatch-reviewer`, the only dispatch channel
  there is: it records the request and returns no findings. One line per
  reviewer drawn.
- **`review.md`** — the synthesized report, the artifact `verify`'s `report.md`
  already establishes as the place a prose deliverable lands.
- **A disclosure** — any wording that tells the reader the specialists did not
  actually run. The defect is **silence**, not a missing phrase.

## A — Approach

**Routing is graded from `.dispatch-log`, never from the report's prose.** The
names in that file are what the run *did*; a sentence claiming a routing decision
is what it *said*. Only the first is an artifact.

**Option B is graded as an alternation, and the battery is the gate.** A
disclosure may be spelled a dozen ways; this repo has twice shipped a property
mechanized as one surface form and reddened correct runs. So
`scripts/test-eval-graders.sh` carries a **spelling battery**: the same ideal
outcome, its disclosure sentence rewritten several different honest ways, all
required to stay green — and the same file with the disclosure removed required
to go red. An alternation nobody has watched accept a new spelling is a guess.

**The negative side of the security rule is eval 1's job.** "Security only when
the diff touches input/auth/secrets/deps" is asserted where it is unambiguous:
a docs-only diff must draw neither security nor performance. On the
security-touching diff the suite asserts only that security **was** drawn —
`reviewer-performance` is left unasserted there on purpose, because the same
diff touches a query and drawing performance for it is a defensible read.

**One quality assertion, on eval 2 only.** A suite that grades routing and says
nothing about whether the review found the planted defect is hollow, so the
report must cite the changed file and name the class of problem with a broad
alternation (injection / interpolation / sanitising / hardcoded credential …).
Eval 3 has no such assertion: the fan-out case is about who was drawn.

## S — Structure

```
skills/review/evals/fixtures/docs-change-repo/
skills/review/evals/fixtures/ops-console-repo/          (+ pending/*.patch)
skills/review/evals/{evals.json,check.sh,README.md}
skills/review/evals/solutions/<3 green, 3 red>/
skills/review/evals/benchmarks/2026-09-16-v0.60.0/
skills/review/SKILL.md            (one clause: disclose an unavailable dispatch)
scripts/test-eval-graders.sh, scripts/test-fixture-scratch.sh   (register review)
README.md (one line), upgrades/v0.60.0.md, .claude-plugin/plugin.json
```

## O — Operations

- T1 fixtures + `evals.json` + suite README; no grader yet → the harness goes red.
- T2 `check.sh`; register `review` in both harness lists; every arm watched red
  on an untouched fixture before any solution exists.
- T3 solutions: three ideal outcomes green, three committed cheats red, each
  cheat watched failing its own assertion; the spelling battery.
- T4 real executor runs, one per eval, graded — the only thing that can show an
  assertion reddens a correct run — then an honest benchmark.
- T5 release: SKILL.md clause, README line, version bump, upgrade note, gates.

## N — Norms

Test-first. Terse. Atomic commits, pushed per task. Ground truth in the grader,
never in the fixture (P26). No assertion ships without having been watched fail.

## S — Safeguards

- **No fixture leak.** `check-fixture-leaks.sh` over both fixtures; the
  disclosure alternation and the routing expectations live in `check.sh`.
- **The shim states a mechanism, not an expectation.** `dispatch-reviewer`
  records a name and says it returns no findings. It never says "dispatch is
  unavailable" — that is the sentence the report is graded on, and a fixture
  that supplies it would be grading its own echo.
- **Label, everywhere.** `evals.json` notes, the suite README and the benchmark
  all say this suite covers **reporting and routing under an unavailable
  dispatch** — not dispatch itself, which only a top-level manual arm can cover.

## Success metric

```
for t in scripts/test-*.sh; do bash "$t" || exit 1; done
for c in scripts/check-*.sh; do bash "$c" || exit 1; done
```

(Discovery, not a named list: CI globs `scripts/test-*.sh` and runs every
`check-*` gate, and a previous session's named list missed a real defect.)

Decisive clause: within `scripts/test-eval-graders.sh`, the `review` grader is
**red on all three untouched fixtures**, **green on three committed ideal
outcomes**, and **red on three committed cheats that fail three different
assertions** — the docs-only diff fanned out to all three reviewers, the
security-touching diff reviewed without security drawn, and the fan-out report
that implies three specialists ran. Plus the spelling battery: **at least five
different honest disclosures grade green** and the same report with the
disclosure removed grades red.
