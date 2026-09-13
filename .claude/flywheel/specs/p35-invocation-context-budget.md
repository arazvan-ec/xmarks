# Spec: P35 — invocation-context budget (progressive disclosure for skill bodies)

**Slug:** `p35-invocation-context-budget` · **Created:** 2026-09-13 · **Backlog:** P35
**Status:** verified PASS 2026-09-13 — metric exit 0 (six gates); eval release gate green before the bump (process 15/15, work 7/7, run 4/4, each at its committed rate); shipped as v0.44.0 on `claude/skill-context-optimization-l21ryh`. Ceiling revised to 5,300 B during work (see Revision below) → next: `/flywheel:review`, then `/flywheel:compound`
**Prime:** P24 (`p24-description-budget`) is the shape to copy — CI gate +
committed budget file + paired test + logged escape hatch. P12
(`p12-token-discipline`) already trimmed the *descriptions*; P23
(`p23-cycle-cost`) supplies the proxy-metric honesty rule (`bytes_out`, never a
guessed token count). `docs/research/token-efficiency.md` is the standing
research anchor. LEARNINGS entry *"writing-token discipline — terse code, never
echo files into chat, edit over rewrite"* is the same discipline applied to
input context instead of output.

## R — Requirements

A skill costs context at three levels, and flywheel governs only one:

| Level | What enters context | When | Governed? |
| --- | --- | --- | --- |
| 1 | `name` + `description` of all 17 skills | every session, always | **yes** — P24 ratchet |
| 2 | the whole body of one `SKILL.md` | on every invocation | **no** |
| 3 | supporting files under the skill dir | only when read | **n/a — no skill has any** |

**The evidence this spec exists for is a five-day natural experiment.** Between
`5ff9eb5` (2026-09-08) and `c32fda1` (2026-09-13), across v0.39.0–v0.43.0:

- the **governed** level held: descriptions went 3,301 → 3,326 of a 3,600 budget;
- the **ungoverned** level grew 14%: bodies went 60,527 → **69,065 B** total,
  with `work` +74% (4,829 → 8,385), `plan` +247% (1,194 → 4,138) and `help`
  7,555 → 8,395.

Nobody did anything wrong — every one of those diffs shipped through the loop
with a spec and a review. That is the point: the ratchet holds where it exists,
and where it does not, growth is invisible because no gate reports it.

Today's bodies, `wc -c` over `skills/*/SKILL.md`:

| over 4,500 B | | under | |
| --- | --- | --- | --- |
| `help` | 8,395 | `loop` | 4,474 |
| `work` | 8,385 | `plan` | 4,138 |
| `process` | 8,280 | `autoloop` | 3,547 |
| `run` | 5,703 | `spec` | 3,087 |
| `update` | 5,363 | + 7 more | ≤ 2,164 |
| `compound` | 4,716 | | |

Worst case is **8,395 B ≈ 2,100 tokens paid on every `/flywheel:help`** — a pure
onboarding reference, read once, charged in full at each invocation.

1. **Establish `references/` as the progressive-disclosure convention.** A
   `SKILL.md` holds the *procedure*: steps, gates, the rules that bite. Material
   consulted at one specific step — long rationale, format catalogues, worked
   examples, onboarding maps — moves to `skills/<name>/references/<topic>.md`
   and is **cited by path at the step that needs it**, entering context only
   when that step is reached.
2. **Per-skill ceiling, not a sum.** A session pays *one* body per invocation,
   so the governing invariant is a per-skill maximum. (Contrast P24:
   descriptions are all paid together, so their invariant is a total.) Ceiling:
   **5,300 bytes per `skills/*/SKILL.md`**.
3. **Refactor the 6 skills over the ceiling** — `help`, `work`, `process`,
   `run`, `update`, `compound` — by extraction into `references/`, **never by
   deleting a rule**. Every requirement, gate and guardrail that leaves a body
   must be findable at the step that needs it.
4. **`scripts/check-invocation-budget.sh` as a CI ratchet**, mirroring P24:
   fails when any `skills/*/SKILL.md` exceeds the committed ceiling, prints the
   per-skill breakdown largest-first so the diff says *which* skill grew, budget
   in its own committed file (`scripts/invocation-budget.txt`), logged escape
   hatch (`SKIP_INVOCATION_BUDGET=1`), never a silent skip.
5. **The installer must vendor `references/`.** `install-vendored.sh` copies
   only `${dir}SKILL.md` per skill (`scripts/install-vendored.sh:205-213`),
   deliberately skipping `evals/`. Left as-is, every vendored install — the
   Claude Code **web** path, i.e. every consumer repo — would receive bodies
   citing `references/*.md` files that do not exist. The vendor loop, the
   manifest, and the uninstall/restore path must all carry the new files.
6. **A body that cites a missing reference is a build failure.** Every
   `references/…md` path cited in a `SKILL.md` must resolve, checked in the same
   gate — a dangling citation is worse than the prose it replaced, because the
   model proceeds silently without the rule.

**Out of scope** (named so the gate is not asked to cover them): a chain-level
budget for `/flywheel:loop`, which pays six bodies in sequence (spec + plan +
work + verify + review + compound = **24,529 B** today, up from 18,029 five days
ago) — worth its own proposal once the per-skill ceiling holds; any change to
the P24 description budget; any behavioral change to the skills themselves.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| skill body | the procedure, ceiling-bound | `skills/<name>/SKILL.md` |
| reference | step-scoped detail, loaded on demand | `skills/<name>/references/<topic>.md` |
| budget file | single integer, the committed per-skill ceiling | `scripts/invocation-budget.txt` |
| gate script | measures every body, checks citations resolve | `scripts/check-invocation-budget.sh` |
| paired test | synthetic skill trees, red before green | `scripts/test-check-invocation-budget.sh` |
| installer | must vendor `references/` alongside `SKILL.md` | `scripts/install-vendored.sh` |
| upgrade note | release record, `requires-action: true` | `upgrades/v<version>.md` |

## A — Approach

**Chosen: extraction behind a per-skill byte ceiling, enforced in CI.**
Measurement in **bytes** (`wc -c`), not characters: `wc -m` is locale-dependent
(under `LC_ALL=C` it silently equals `wc -c`), and a gate whose verdict changes
with the runner's locale is not a gate. Bytes are also the honest proxy — a
mechanically observable count, per P23's rule against dressing an unobservable
token number up as evidence.

**Rejected: a total budget across all bodies (the P24 shape).** It measures a
cost nobody pays — no session loads all 17 bodies — and would let `process` sit
at 8 KB as long as `brainstorm` shrank, which is exactly backwards.

**Rejected: relying on spec/review discipline without a gate.** The five-day
drift above *is* the experiment: every one of those growth diffs passed a spec
and a review. Discipline did not catch it; a number would have.

## S — Structure

```
skills/<name>/
  SKILL.md                    ≤ 4,500 B — procedure, gates, rules that bite
  references/<topic>.md       cited by path from the step that needs it
scripts/
  invocation-budget.txt       4500
  check-invocation-budget.sh  → reads budget file, measures bodies, resolves citations
  test-check-invocation-budget.sh
  install-vendored.sh         → vendor loop extended to references/
  test-install-vendored.sh    → asserts references/ land in the vendored tree
.github/workflows/validate-plugins.yml  → new gate next to the P24 step
```

Dependency order: the gate and its test are independent of the refactors and
come **first** — the gate must be seen red against today's `main`, where 6
skills bust it. The installer change gates the refactors: a vendored install
that loses `references/` is a broken release, so it must be green before any
body is split.

## O — Operations

1. `scripts/test-check-invocation-budget.sh` first: scenarios for over/under
   budget, missing budget file, non-numeric budget, a skill with no body, a
   dangling `references/` citation, the logged escape hatch. Run it — **red**
   (exit 127, no script yet).
2. `scripts/check-invocation-budget.sh` until green. Breakdown largest-first;
   malformed input fails loudly, never silently as zero (P24 requirement 4).
3. `scripts/invocation-budget.txt` = `4500`. Run the gate against `main`:
   **must fail**, naming the 6 over-budget skills — that failure is the evidence
   the gate works.
4. Extend `install-vendored.sh` to vendor `skills/*/references/**` (manifest and
   uninstall/restore included); extend `test-install-vendored.sh` to assert it,
   red before green.
5. Refactor the 6 bodies, one skill per commit, gate green after each:
   `help`, `work`, `process`, `run`, `update`, `compound`.
6. Wire the gate into `validate-plugins.yml` beside the P24 step.
7. Release mechanics: bump `.claude-plugin/plugin.json`, add
   `upgrades/v<version>.md` (`requires-action: true` — vendored repos must
   re-run the installer to receive `references/`), keep `marketplace.json` and
   `plugin.json` descriptions in sync.
8. Document the convention in `CLAUDE.md` (repo conventions) and record P35 in
   `docs/research/improvement-proposals.md`.

## N — Norms

- **Test-first for every script** (`CLAUDE.md`): paired `scripts/test-<name>.sh`,
  failing test seen red before implementation; `check-test-pairing.sh` enforces
  the pair moving together.
- **Every change to `skills/`/`scripts/` is a release**: version bump + upgrade
  note, no exceptions.
- **Skill changes to `work`, `verify`, `process`, `run` are eval-gated** (P22
  phase 2). This spec touches `work`, `process` and `run`, so their evals run
  **before** the version bump, not after. (`loop` and `verify` also carry evals
  but are untouched.)
- Commits are atomic, one logical change each, pushed as they land.
- Never echo file contents into chat after writing them.

## S — Safeguards

- **Extraction must not lose a rule.** The failure mode is a silently weaker
  skill: prose leaves the body, the step never cites it, the model never reads
  it, and nothing fails. Mitigations: requirement 6's citation check, the eval
  gate on `work`/`process`/`run`, and one commit per skill so a regression
  bisects to a single body.
- **`help`, `update` and `compound` have no evals.** Their check is structural
  only (`test-docs-consistency.sh`, which asserts every skill appears in the
  README table and the `/flywheel:help` map). Extraction there stays
  conservative: move reference material, never the command map itself.
- **A dangling citation in a vendored install** is the highest-severity failure
  — it degrades every consumer repo silently — hence requirement 5 landing
  before any refactor, and `requires-action: true` on the upgrade note.
- **The ceiling is policy, not code**: it lives in its own file so raising it is
  a one-line reviewable diff that does not trip the script/test pairing gate
  (P24 requirement 3).
- Escape hatch `SKIP_INVOCATION_BUDGET=1` prints a notice and is never silent.

## Success metric

From the repo root on the feature branch, this exits 0:

```bash
bash scripts/check-invocation-budget.sh \
  && bash scripts/test-check-invocation-budget.sh \
  && bash scripts/check-description-budget.sh \
  && bash scripts/test-check-test-pairing.sh \
  && bash scripts/test-install-vendored.sh \
  && bash scripts/test-docs-consistency.sh
```

with `check-invocation-budget.sh` reporting **all 17 skills ≤ 5300 B** (worst
case down from 8,395 B), and the same command failing on `main` today by naming
the over-budget skills.

**Release precondition** (`CLAUDE.md`, not part of the metric): the `work`,
`process` and `run` evals pass at or above their committed rates before the
version bump.

## Revision 2026-09-13 — the ceiling is 5,300 B, not 4,500

Signed at 4,500 B. Five of the six skills in scope reached it with room to
spare; `work` did not. Extraction took it from 8,385 to 5,259 B — the transition
line's JSON shape, the three routing cases, the delegation thresholds, the
mis-route note and the reasoning behind each commit rule all moved — and what
remained was 759 B of nothing but rules: the five-step inner loop, the commit
rules stated imperatively, the route contract, the standing rule, and the
anti-rationalization table. Reaching 4,500 would have meant moving that table,
which is the guardrail against the exact failure the skill exists to prevent:
the silent weakening this spec's Safeguards name as the failure mode.

Owner chose to raise the ceiling globally to 5,300 rather than carry a per-skill
exception, with the known cost stated at the time: the other sixteen skills gain
between 800 and 4,000 B of slack the ratchet no longer reports. The measured
drift this spec exists to stop — 14% in five days — remains possible inside that
slack. A tighter ceiling, or per-skill exceptions, stays available as a
follow-up once `work` is split or its rules shrink.
