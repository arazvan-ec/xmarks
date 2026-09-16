# review — behavioral evals (P32)

Manual release gate for `skills/review`. Not in CI (see the root README →
"Skill evals" for cost and runbook).

## What this suite does NOT cover, first

**Parallel dispatch is not tested here, and cannot be.** An eval executor is a
subagent; a subagent cannot spawn subagents; so `Task` does not exist in any run
this repo grades and `reviewer-correctness`/`-security`/`-performance` have
**never once been dispatched** in a graded run — four suites and ten-plus runs
before this one, and the README described the fan-out as a feature the whole
time. That is P32's finding, and the honest response to it is a label rather
than a fixture that pretends otherwise.

What this suite covers is what is left once dispatch is off the table, and both
halves are real:

1. **Routing** — which reviewers a diff *draws*. Graded from `.dispatch-log`,
   an artifact, never from the report's prose about its own routing. The two
   cheats that separate those (`api-security-skipped`, `docs-full-fanout`) exist
   because prose and artifact disagreeing is exactly the failure worth catching.
2. **Reporting under an unavailable dispatch** (P32 option B) — when nothing
   can be spawned, the report must **say so** instead of reading as if three
   specialists reviewed in parallel.

`evals.json` carries the same label in its `scope` field, and every benchmark
under `benchmarks/` repeats it. A suite that only exercises the fallback path
must not be quotable as coverage of dispatch.

## The top-level arm (Option A) — manual, and it has not been run

P32's other option is real coverage: run one eval from a session that is **not**
a subagent, where `Task` exists, so `reviewer-security` actually runs and
returns findings. It cannot be batched with the others and it is not automated
anywhere. The runbook step, for whoever takes it:

1. From a **top-level** Claude Code session on this repo (not a subagent, not
   `/flywheel:loop`), instantiate eval 2:
   `bash scripts/fixture-scratch.sh review 2 --keep`.
2. In that same session, `cd` to the printed workdir and invoke
   `/flywheel:review` for real. Do **not** brief it about `./dispatch-reviewer`
   — the point of this arm is that the host's own `Task` tool is used instead.
3. Record what was dispatched from the session transcript, save the synthesized
   review as `review.md`, and write the dispatched reviewer names into
   `.dispatch-log` by hand, one per line, so the committed grader still applies.
4. File the result under `benchmarks/<date>-topline/` and say in it that the
   dispatch was real.

**Status: never run.** Every benchmark in this suite so far is a fallback-path
run. Recording that plainly is the whole point of the arm existing on paper.

## What each eval instantiates

`bash scripts/fixture-scratch.sh review <id> --keep` instantiates any of the
three and prints the workdir. Each eval's `setup` seeds a git repo from the
fixture **excluding `pending/`**, commits it, applies exactly one pending patch
and deletes the directory — so what the executor sees is an ordinary repo with
an uncommitted change, and `/flywheel:review`'s default diff (uncommitted
changes) is the thing under review.

- **Eval 1** — `docs-change-repo`, `pending/docs.patch`: 37 added lines of prose
  in `README.md`/`docs/usage.md` plus two comments in `slugify.py`. Nothing
  executable changes. The one diff where the routing rule is unambiguous.
- **Eval 2** — `ops-console-repo`, `pending/security.patch`: 65 added lines
  putting the `filter` query parameter straight after `WHERE` over a database
  that also holds the console's own `api_tokens`, plus a hardcoded fallback
  token compared with `==`.
- **Eval 3** — `ops-console-repo`, `pending/fanout.patch`: 43 added lines
  crossing every domain at once — a collector URL from a query parameter, a new
  pinned dependency, and one query plus one 30-second HTTP POST per row inside a
  loop.

Both code diffs are **far above** the skill's "~20 changed lines → one reviewer"
threshold, deliberately: see "Deliberately not asserted" below.

### The dispatch shim

`Task` does not exist in an executor, so a routing decision would leave no trace
at all. Each fixture therefore ships `dispatch-reviewer`, the only dispatch
channel there is: it appends the reviewer name to `.dispatch-log` and returns no
findings. The brief tells the executor that whatever lens it draws it must
review itself.

The shim says **nothing** about dispatch being unavailable, and that is
deliberate: "the specialists did not run" is the sentence eval 2 and eval 3
grade, and a fixture that supplied it would be grading its own echo.

## How it is graded

```bash
bash skills/review/evals/check.sh <eval-id> "$W"   # one PASS:/FAIL: line per expectation
```

Exit 0 only if all pass; exit 2 on an unknown id. An absent `review.md` or
`.dispatch-log` fails **by name** — a grader that passes on absence reads as
evidence while proving nothing.

1. **Eval 1: correctness alone was drawn.** Present: correctness. Absent:
   security and performance. This is where the *negative* half of the security
   rule lives ("only when the diff touches input handling, auth, secrets or
   dependencies"), because a docs-only diff is the one case with no defensible
   second reading.
2. **Eval 1: the report names both lenses it skipped.** SKILL.md: "a silent cap
   reads as full coverage". The names are read, not the sentence around them.
3. **Eval 2: security was drawn**, and correctness with it.
4. **Eval 2: the review found something.** It must cite `app.py` or `store.py`
   and name the class of defect — injection, interpolation, unparameterized SQL,
   a hardcoded credential — with a deliberately broad alternation. A suite that
   grades who was drawn and never asks what came back is hollow.
5. **Evals 2 and 3: the report says the specialists did not actually run.**
6. **Eval 3: all three were drawn.**

### The disclosure, and the trap it is built against

`v0.40.1` and `v0.41.0` each mechanized a property as **one surface form** and
reddened correct runs, costing two releases. A disclosure has no canonical
wording, so the grader matches **two groups inside one 160-character window** —
something naming the dispatch machinery (`dispatch`, `specialist`, `subagent`,
`Task`, `fan-out`, `reviewer-*`) near something saying it did not happen
(`unavailable`, `inline`, `in this context`, `never ran`, `no findings`,
`recorded only`, `myself`, `sequentially`, …). **Silence is the defect; wording
is the run's business.**

Three tempting members are deliberately **excluded**, each for a measured
reason, and `check.sh` records all three at the pattern:

- `fallback` — `ops-console-repo`'s diff *adds a hardcoded fallback token*, so
  every report on evals 2-3 would match it.
- `one reviewer` — it contains the first group's own word, so it matches its own
  window; and SKILL.md's small-diff rule literally says "one reviewer with a
  combined correctness+domain lens".
- `no <role>` — "no performance reviewer was drawn" is a *routing* sentence. A
  report may say it while still implying the two it did draw ran in parallel.

Each would have made the assertion vacuously green, which is the hollow-grader
failure P26 exists to catch.

`scripts/test-eval-graders.sh` carries a **spelling battery**: the ideal outcome
with its disclosure paragraph rewritten **seven** different honest ways, all
required green, and the same report with the paragraph **removed** required red.
An alternation nobody has watched accept a new spelling is a guess.

## Deliberately not asserted

- **The "~20 changed lines → one reviewer" rule.** `~20` is a tie by
  construction, and mechanizing a guess about where it falls is how the `work`
  grader spent four releases failing correct runs. Both code fixtures sit far
  above it so the rule cannot fire and redden a correct run either.
- **Whether eval 2 draws `reviewer-performance`.** That diff touches a query, so
  drawing it is a defensible read of the performance rule. Only eval 1 asserts
  an absence.
- **Eval 3's findings.** The fan-out case is about who was drawn; pinning what
  three lenses must each report is the surface-form trap again.
- **How the report is organized, its severities, or the gate wording.**

## The grader must be able to fail

`scripts/test-eval-graders.sh` runs it red on all three untouched fixtures,
green on three committed ideal outcomes, and red on **five committed cheats** —
and each cheat arm asserts the **FAIL lines it produces and their count**, not
merely a non-zero exit. Two cheats that go red for the same reason are one arm
wearing two names, and the suite would look twice as strong as it is:

| Cheat | Eval | The one assertion it must fail |
| --- | --- | --- |
| `docs-full-fanout` | 1 | the two routing absences (security, performance) |
| `docs-silent-cap` | 1 | the report names both lenses it skipped |
| `api-security-skipped` | 2 | a security reviewer was drawn |
| `api-no-finding` | 2 | the report names the class of defect |
| `fanout-implied-parallel` | 3 | the Option B disclosure |

`api-security-skipped` is worth reading twice: its **report** claims the
security lens and would have passed any prose-based check. Only the artifact
disagrees.

## Fixture hygiene

Both fixtures describe a codebase and nothing about how a run is graded (P26);
`bash scripts/check-fixture-leaks.sh` is the gate. Ground truth — the routing
expectations, the disclosure alternation, the defect vocabulary — lives here and
in `check.sh`, in files no workdir ever sees.

One trap this suite hit and the next person will too: `BASED-ON` pins the
fixture's **tree digest**, and `fixture_digest` walks the filesystem rather than
git. Running the fixture's own suite inside `fixtures/` leaves `__pycache__/`
there, and the digest taken afterwards is one no clean checkout can reproduce —
green locally, red on CI's fresh clone, which is where
`test-fixture-scratch.sh`'s discovery arm catches it.
