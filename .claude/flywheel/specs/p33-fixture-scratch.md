# Spec: P33 — `fixture-scratch.sh`, the eval bench as a mechanism

**Slug:** `p33-fixture-scratch` · **Created:** 2026-09-10 · **Backlog:** P33
**Status:** shipped as v0.43.0 — metric **PASS** (all ten clauses; 14/14
`scripts/test-*.sh` green; `claude plugin validate . --strict` green). The
anti-regression clause holds: the 41 `  ok: ` lines are byte-identical before
and after, and `test-eval-graders.sh` went 403 → 241 lines with 13 heredocs → 1.
No eval gate was required — the diff touches no `skills/*/SKILL.md`, agent or
hook, so there is no skill behavior to regress. Requirement 9 says "all five
eval READMEs"; only three exist (`process` and `run` carry their harness notes
in `evals.json`), and all three were updated.

**Prime:** `README.md` "Skill evals" → "How to run one iteration" (steps 1 and 3,
the prose this replaces); `scripts/test-eval-graders.sh` (`fixture_copy`,
`run_grader`, and the four `*_ideal` synthesizers this extracts);
`scripts/check-fixture-leaks.sh` header ("a manual step is not a gate" — the
moral this repo already wrote down); the five `skills/*/evals/README.md`.

**Post-review (2026-09-10).** Code review before merge found four defects in
`fixture-scratch.sh`, each reproduced before being fixed and each now covered by
an assertion (the test went 45 → 49): GNU-only `sha256sum`/`sort -z`/`xargs
-0r`/`find -printf` (now probed with the `shasum -a 256` fallback
`scripts/gate.sh` carries); `BASED-ON` ignoring file modes, so dropping `+x`
from a fixture's `run-tests.sh` left the digest identical while executors could
no longer run it; `--suite` reporting a green suite on `Ran 0 tests`, which
`python3 -m unittest` exits 0 for — requirement 7's "must not corrupt what is
graded" now also means a zero-test run is a failure, matching the vacuous-pass
refusal in `check-fixture-leaks.sh`; and `--print-prompt` treating the workdir
as sed replacement syntax (`&` expanded to the whole match, `|` errored with its
status masked, both exiting 0). Adding the mode bit changed the digest
algorithm, so all seven committed `BASED-ON` files were regenerated — the
tripwire refusing to proceed, which is the behaviour it exists for.

## R — Requirements

1. **One invocable helper instantiates an eval.** `scripts/fixture-scratch.sh
   <skill> <eval-id>` builds the scratch workdir for any of the five suites,
   absorbing the two instantiation schemas that today have to be recalled from
   memory: a `setup` shell command (`loop`/`process`/`run`) versus a `files`
   list plus a `{{WORKDIR}}` prompt placeholder (`verify`/`work`).
2. **The fixture lands at the workdir root, never nested.** The `setup` commands
   in `evals.json` are `cp -r <fixture> "$W"`, which requires `$W` **not to
   exist**; `README.md` step 1 says `W=$(mktemp -d)`, which makes it exist and
   yields `$W/<fixture-name>/…`. Every grader then fails on a workdir that is
   correct in every other respect. The helper makes this unrepresentable.
3. **Reference solutions are committed assets, not heredocs in a CI test.**
   `skills/<skill>/evals/solutions/<name>/` holds what a correct outcome looks
   like, consumed identically by the helper (`--solution <name>`) and by
   `scripts/test-eval-graders.sh`. One source of truth.
4. **The solutions live outside `fixtures/`, and a check enforces it.** They
   *are* the answer key, so they must stay out of `check-fixture-leaks.sh`'s
   scan (`*/evals/fixtures/**`) and out of every executor's workdir. The
   existing gate structurally cannot police this: a solution placed *inside* a
   fixture would be copied verbatim into the executor's prompt, and while
   `verify`'s overlay (`VERDICT:`) and `work`'s patches (`RESULT=`, `IMPL_SHA`)
   would trip the vocabulary, **`loop`'s JSONL contains none of it and would
   sail through**. So "no `solutions/` directory under any `evals/fixtures/`" is
   its own assertion.
5. **A solution is bound to its fixture by declaration, not by inference.**
   `skills/work/evals/fixtures/cart-feature/cart.py` and `cart-bugfix/cart.py`
   are **byte-identical** (both `sha256|cut -c1-16` = `8b44f02e8e4f2e3b`, which
   is why both `baseline-sha` files agree), so either solution's patch applies
   cleanly to the other fixture. "The patch applied" therefore proves nothing
   about which fixture it was meant for.
6. **The helper's exit status is trustworthy.** One result line per requested
   step; every requested step runs even after one fails (one red must not hide
   the rest — the principle the CI workflow already states for `test-*.sh`);
   exit 0 only if every requested step passed; exit 2 on an unknown eval id —
   the graders' own contract, so a caller needs one rule, not two.
7. **`--suite` must not corrupt what is graded.** `work`'s `run-tests.sh`
   appends to `.check-log`, the artifact its grader reads, and its `test_cart.py`
   refuses to import without `KATA_HARNESS=1`. The helper mirrors each grader's
   `suite_green()` and never invokes `run-tests.sh`.
8. **`test-eval-graders.sh` keeps every assertion it has today.** This release
   changes *who builds the workdir*, never what is asserted about it — the
   committed benchmarks must stay comparable.
9. **The runbook stops describing a manual ritual**, in `README.md` and in all
   five `skills/*/evals/README.md`, and the `mktemp -d` defect in step 1 is
   corrected rather than left for the next reader to trip over.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| helper | instantiate + overlay + suite + probe + grade + teardown | `scripts/fixture-scratch.sh` |
| helper test | the seven properties below | `scripts/test-fixture-scratch.sh` |
| solution assets | `MANIFEST`, `BASED-ON`, `patch/`, `overlay/`, optional `apply.sh` | `skills/<skill>/evals/solutions/<name>/` |
| grader self-test | red-on-untouched (unchanged) + green-on-ideal (now from assets) | `scripts/test-eval-graders.sh` |
| runbook | steps 1 and 3 become one command | `README.md`, `skills/*/evals/README.md` |

## A — Approach

**Addressed by eval id, not by fixture path.** The id is what the grader already
takes, and it is the key under which `evals.json` records how that eval is
instantiated. It is also the only addressing that works: **`loop` evals 1 and 2
use the same `inventory-repo` fixture and differ solely in whether `setup` runs
`git init`** — eval 2 deliberately does not, because a missing `commit` field
cannot be proven in a workdir where committing is possible. Addressing by
fixture would make that pair inexpressible, and would push `git init` into a
solution's script, conflating "how the eval is instantiated" (already committed
in `evals.json`) with "what a correct outcome looks like".

The fixture is resolved, never guessed: `files[0]` where present, else the
`skills/<skill>/evals/fixtures/<name>` path inside `setup` — a form all nine
`setup` strings share, and whose uniformity the test asserts so drift fails
loudly. `--pristine` copies the fixture and skips `setup`, which is what the
red-on-untouched arm needs.

**Solution assets: patches for files the fixture has, overlay for files it
doesn't, `apply.sh` for ceremony only.** The four synthesizers being extracted
have three shapes, and this split puts each in the cheapest representation that
still fails loudly:

- a file the fixture does **not** have → `overlay/`, copied verbatim. Nothing to
  drift from. Covers `verify`'s `report.md`/`transcript.md` and the honest-stop
  JSONL.
- a file the fixture **does** have → `patch/NN-*.patch`, applied in lexical
  order with `git apply --whitespace=nowarn -p1`. Never a whole-file overlay
  copy.
- git ceremony and runtime-computed values → `apply.sh`, which carries **no
  source code**.

**The patches-for-existing-files rule is the load-bearing one.** A whole-file
overlay of `test_cart.py` would shadow its `KATA_HARNESS != "1"` guard — and
that guard is why only `run-tests.sh` can write `.check-log`, which is why "the
test ran red at the pristine sha" is a fact rather than a claim. Change the
guard in the fixture and an overlay-based green arm would stay green, being
internally self-consistent while no longer tracking the artifact executors
receive: the P26 failure class, reintroduced one layer up. A patch cannot do
that, so the rule is enforced mechanically — no `overlay/` file may shadow a
fixture file.

Verified in this environment, so the format rests on facts rather than on
expectation: `git apply -p1` **works outside a git repository** (rc 0), which
`work`'s fixtures and `loop` eval 2's workdir require; it **tolerates line
offsets** (a prepended header still applied, rc 0); and it **rejects context
drift** (renaming `total` gave rc 1 and `error: cart.py: patch does not apply`,
naming file and line). So drift detection is real but scoped to the patch's
context lines — hence `BASED-ON`, a sha256 of the fixture tree checked before
anything is applied, to cover the rest: `run-tests.sh` changing how it computes
`IMPL_SHA`, or `baseline-sha` going stale, would otherwise redden the ideal arm
in a way that reads as a *grader* bug. Never `--ignore-whitespace`: that would
disable exactly the detection being bought.

**What cannot live in a static asset, and why that is not a shortcoming.**
`loop`'s commit sha1s depend on tree, identity and timestamp, so a sha committed
to an asset is by definition a sha nobody made in that workdir — which is
precisely the `fabricated-sha` cheat the grader's `commits_resolve` exists to
reject. A static sha would make the ideal arm indistinguishable from the cheat it
is tested against. The *sequence* is equally irreducible: commit 1 must hold only
the `restock` append and commit 2 only `low_stock`, and an overlay can express
only an end state. So `loop`'s solution is two patches plus a short `apply.sh`
doing apply→commit→capture twice — the content reviewable, only the ceremony
script.

**Rejected: a placeholder vocabulary** (`@@BASELINE_SHA@@`,
`@@SHA16:<path>@@`) that would let `work`'s `.check-log` be a declarative
overlay and remove its `apply.sh` entirely. It is a mini-language, mini-languages
grow, and it would serve exactly one file in two solutions. A four-line
`apply.sh` computing the two shas is no less legible and introduces no new
concept.

**Stated plainly: the heredocs are not all eliminated, and the honest claim is
"deduplicated and made addressable".** `verify`'s three solutions and
`loop`'s honest-stop become pure overlay with no script at all; `work`'s two and
`loop`'s inventory keep a small `apply.sh` — but one holding only git and
`sha256sum` calls, because all source moved into reviewable patches. The gain is
that each solution is one greppable directory instead of a branch of a shared
`case`, that the assets are reachable *interactively* while a fixture is being
designed, and that the CI test shrinks by roughly a third.

**The patches are derived, not retyped.** Each is generated with `diff -u`
between a pristine fixture copy and one built by the *current* synthesizer, so
the assets are provably equivalent to today's behaviour.

**The test drives the helper for materialization only, and keeps grading to
itself.** `test-eval-graders.sh` needs to mutate a workdir after building it
(plant a fabricated sha, make a sweeping commit, weaken an assertion), so it
calls the helper with `--into <caller-owned dir>` — no mktemp, no teardown, and
`$WORK` ownership and its existing `trap` stay with the test.

**No CI arm grades through `--check`, and this is the sharp edge.** The helper
exits non-zero when *any* step fails — a bad fixture name, a patch that did not
apply, a red suite. In the arm whose entire purpose is "the grader can fail", a
*broken helper* would exit non-zero and read as a passing red arm. So the
division is: the helper owns "materialize a fixture plus a solution", the test
keeps owning "run the grader and assert on its exit code and output" via its own
`run_grader`. `--check` exists for humans.

**`process`/`run` still get no green arm, for the reason already documented.**
Synthesizing a valid process contract would reimplement what those graders
grade; solution assets lower the cost of the plumbing, not of that. For
`process` this format would make it worse: that grader's whole content is "does
the contract carry these sections", so an exemplary contract asserts only that a
file written to match the greps matches the greps — and it would stay green even
if the checklist drifted from `skills/process/SKILL.md`. `run`'s case is
genuinely weaker (its `staged`/`not_unstaged` pair and `FW_EVAL_DATE` handling
are non-tautological, and the hollow grader that motivated P26 lived there), so
it is recorded as **P34** rather than smuggled in here: a failure in a brand-new
`run` green arm shipped alongside a new asset format would be ambiguous between
"the format is wrong" and "the grader is wrong". Their green evidence remains the
committed benchmarks, and the test keeps saying so out loud.

Rejected: a `/flywheel:` command. The judgment content is nil — this is
mechanical — and a command would spend description budget (cap 3600) plus two
mandatory doc registrations for no behavioral gain. Rejected: vendoring the
helper via `install-vendored.sh`. That list is the scripts *skills invoke* in a
consuming repo; this one resolves `skills/*/evals/`, which does not exist there.

## S — Structure

- `scripts/fixture-scratch.sh` + `scripts/test-fixture-scratch.sh` (new, same diff)
- `skills/verify/evals/solutions/tally-{fail,sneaky,pass}-ideal/` (new, overlay only)
- `skills/work/evals/solutions/cart-{feature,bugfix}-ideal/` (new, patches + overlay + `apply.sh`)
- `skills/loop/evals/solutions/inventory-ideal/` (patches + overlay + `apply.sh`)
  and `contradiction-honest-stop/` (overlay only)

Each solution directory holds `MANIFEST` (`fixture:` + `evals:`, the binding
requirement 5 makes necessary), `BASED-ON`, `patch/`, `overlay/`, an optional
`apply.sh`, and a `README.md` saying why this is the ideal outcome.
- `scripts/test-eval-graders.sh` (refactor)
- `README.md`, `skills/*/evals/README.md` ×5
- `docs/research/improvement-proposals.md` — P33 + a dated decision-log entry
- `.claude-plugin/plugin.json` → **0.43.0** · `upgrades/v0.43.0.md`

Unchanged, deliberately: `evals.json` ×5 (moving a goalpost would void the
benchmarks), `.github/workflows/validate-plugins.yml` (it already discovers
`scripts/test-*.sh` by glob), `scripts/install-vendored.sh`.

## O — Operations

1. `scripts/test-fixture-scratch.sh` first; run it, see it red because the
   helper is absent.
2. Implement `scripts/fixture-scratch.sh`; red → green.
3. Migrate solutions one skill per commit, easiest shape first
   (`verify` overlay-only → `work` → `loop`), each patch generated with
   `diff -u` against the current synthesizer's output, and
   `test-eval-graders.sh` green after each — so a faithless asset reddens the
   commit that introduced it.
4. Refactor `test-eval-graders.sh` to consume the assets and delegate
   materialization; then `diff` the `ok:` capture against the baseline.
5. Docs: README runbook + the `mktemp -d` correction, five eval READMEs.
6. P33 + a deferred **P34** (`run`'s green arm) + decision-log entry.
7. Full suite, then bump + upgrade note.

## N — Norms

Bash + stdlib Python only, no new dependency, matching `plan-route.sh` and
`run-cost.sh`. The helper is the only writer of the scratch dir; graders stay
pure readers. Teardown via `trap`, so the failure path cleans up too.

## S — Safeguards

- **The helper arrives with a real test, not a smoke test** — and CI runs it by
  glob discovery, so it cannot sit in the tree unexecuted (the defect that hid
  `test-run-cost.sh` for four releases).
- **The solutions are exercised by discovery, not by a hand-written list.** The
  test globs `skills/*/evals/solutions/*/`, applies each to its declared fixture,
  runs its declared eval ids, and asserts the discovered count is non-zero and
  equals `ls -d skills/*/evals/solutions/*/ | wc -l` — so a solution cannot be
  added and never exercised. Same principle as the CI workflow's `test-*.sh`
  glob, which exists for the same reason.
- **No `solutions/` directory under any `evals/fixtures/`** (requirement 4) —
  the one hole the leak gate structurally cannot see.
- **The drift detector is proven live, not nominal:** the test mutates a fixture
  line a patch depends on and requires the apply to *fail*, and asserts
  `git apply` is never invoked with `--ignore-whitespace`. Proving a gate by
  making it fail is how `test-check-fixture-leaks.sh` proves its own.
- **`--solution` with an unknown name, or one whose `MANIFEST` names a different
  fixture, fails loudly.** Passing on absence is the failure mode that makes an
  instrument worthless, and the byte-identical `cart.py` files mean the mismatch
  case has no other detector.
- **No `evals.json` change**, so the committed benchmarks stay comparable and
  P22 phase 2's pre-bump eval gate does not apply: this diff touches no
  `skills/*/SKILL.md`, agent or hook, so there is no skill behavior to regress.
  Said out loud in the upgrade note rather than left as an inference.
- **The CI gate is rewritten in slices**, one skill per commit, never in one
  sweep.

## Success metric

One command, exit 0 = PASS:

```bash
bash scripts/test-fixture-scratch.sh \
  && bash scripts/test-eval-graders.sh \
  && bash scripts/check-fixture-leaks.sh \
  && bash scripts/test-check-fixture-leaks.sh \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/test-install-vendored.sh \
  && bash scripts/check-test-pairing.sh \
  && bash scripts/check-description-budget.sh \
  && ! grep -qE '^(report_ideal|work_ideal|loop_ideal|honest_stop)\(\)' scripts/test-eval-graders.sh \
  && [ "$(wc -l < scripts/test-eval-graders.sh)" -lt 300 ] \
  && [ "$(grep -c "<<'EOF'" scripts/test-eval-graders.sh)" -le 1 ] \
  && [ "$(grep -c 'python3 - ' scripts/test-eval-graders.sh)" -le 1 ]
```

The trailing clauses are what makes "the migration happened" checkable rather
than claimed. Baselines measured before any change: **403 lines, 13 `<<'EOF'`
heredocs, 4 `python3 -` invocations, 41 `  ok: ` lines, suite green.** Twelve of
the thirteen heredocs and three of the four `python3 -` calls are inside the four
synthesizers; the survivors are the `fabricated-sha` cheat mutation, which is a
probe *of* the grader and not a solution, so `-le 1` is the correct bound rather
than 0.

**Plus the anti-regression clause, which is the strongest one available for a
pure migration:** the sorted set of `  ok: ` lines printed by
`scripts/test-eval-graders.sh` must be **byte-identical** before and after. The
pre-change capture (41 lines) is taken at the start of the migration and
`diff`ed at step 4. A refactor that quietly dropped or renamed an assertion
passes every other clause and fails this one.
