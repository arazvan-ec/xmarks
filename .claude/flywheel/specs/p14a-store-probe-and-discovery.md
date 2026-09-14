# Spec: P14 slice 1 — prove the write path before the work, and let a repo see its processes

**Slug:** `p14a-store-probe-and-discovery` · **Created:** 2026-09-14 · **Backlog:** P14 (first of its 2–3 releases)
**Status:** drafted — awaiting sign-off

**Prime:** `skills/run/SKILL.md` steps 1 and 3; `skills/process/references/data-strategy-and-extensions.md`
step 1 (the detection list); `scripts/session-start.sh` (the banner); and the
fixture that settles the central question —
`skills/run/evals/fixtures/demo-repo/.claude/flywheel/DATA.md`.

## The finding that shrinks this slice

P14 lists "file-based DATA.md fallback" as something to build. **It already
works.** The `run` eval fixture's DATA.md declares a git-native markdown store
("the git repository itself — `data/plate-audits.md`… a write has landed when
the row is present **and staged**"), and `run` persists to it and proves the
write: that suite is green at 4/4 and has been since v0.32.0.

So `run` does not need a new store. What is missing is three narrower things,
and the first one is the crash:

1. **Nothing proves the declared write path before the run spends its work.**
   `process` writes DATA.md from *detection* — a `DATABASE_URL` in a
   `.env.example` is enough to declare `psql "$DATABASE_URL"` as the Access —
   and that declaration is first exercised at `run` step 3, **after** step 2 has
   done all the judgment work. A missing credential or a missing table there
   costs the entire run.
2. **The file store is not a detected outcome, only a fallback nobody names.**
   The detection list is nine database signals; when none hit, the skill "asks
   open-ended". A repo with no datastore is not an unclear case — it is the
   common case, and it has a proven answer already sitting in the eval fixture.
3. **Nothing lists the processes a repo has.** The banner names
   `/flywheel:process` and `/flywheel:run` but never the contracts; and a bare
   `/flywheel:run` parses an empty slug, fails to find
   `.claude/flywheel/processes/.md`, and tells the user to **define** a process
   — even when five exist. The guide's "context starvation", in the one place a
   user arrives first.

## R — Requirements

1. **A run never discovers an unusable store after doing the work.** The write
   path is verified at **step 1**, before the Rules execute. On failure the run
   stops there, having produced and persisted nothing, and says which check
   failed and what would fix it.
2. **`process` probes the Access it is about to declare, read-only**, before
   writing DATA.md: for a database, that the connection opens and the target
   exists; for the file store, that the path is writable and inside the repo.
   A probe that fails means DATA.md is **not written** declaring an unproven
   path — the user is told what failed and offered the file store.
3. **The file store is a first-class detected outcome.** "No database signal
   found" is a detection, not a failure to detect: `process` proposes the
   git-native strategy (the shape the eval fixture already proves) and asks only
   to confirm. Open-ended questions are for a repo that has *conflicting*
   signals, not for one that has none.
4. **`run` with no slug lists the repo's contracts** — slug + the Purpose
   one-liner — instead of telling the user to define one. With no contracts at
   all, and only then, it points at `/flywheel:process`.
5. **The session banner lists the contracts when any exist**, under the Runtime
   line it already prints, and stays silent when there are none.
6. **A missing DATA.md stops the run at step 1**, pointing at
   `/flywheel:process`. Today step 1 says to read it and nothing about its
   absence, so the run improvises a store — the failure mode DATA.md exists to
   prevent.

**Out of scope, deliberately** — the rest of P14, which is its slices 2–3:
`flywheel_runs` bookkeeping, approval tiers by stakes×reversibility, process→
process composition, `status: active|deprecated`, batch inputs, run→spec
escalation, `sync` over contracts, the `docs/proactive-loops.md` rewrite, and
generalizing `agents/evaluator.md`.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| probe | read-only check that the declared Access works | `skills/process/references/data-strategy-and-extensions.md`, `skills/run/SKILL.md` step 1 |
| file store | git-native markdown/JSON strategy, already proven | the shape in `skills/run/evals/fixtures/demo-repo/.claude/flywheel/DATA.md` |
| contract index | slug + Purpose, read from `processes/*.md` frontmatter | `scripts/session-start.sh`, `skills/run/SKILL.md` step 1 |

## A — Approach

**Move the verification, do not add a mechanism.** `run` step 3 already demands
proof that a write landed ("a persist you did not observe landing does not count
as done"). This slice applies that same standard **one step earlier and
read-only**: before the Rules run, confirm the path exists and is writable.
Nothing new is invented — the rule the skill already states is simply enforced
at the moment when failing is cheap.

**The probe is read-only by construction**, and that is what makes it safe to run
every time: open a connection and check the target exists; stat a directory.
Never a test row, never a temp table — a probe that writes is a mutation the
Guardrails did not approve, and would have to be undone.

**Rejected: probing at define time only.** Credentials rot, tables get dropped,
a contract outlives the laptop it was written on. The define-time probe stops a
DATA.md from being *written* on an unproven path; the run-time one stops a
*specific run* from starting on a broken one. They answer different questions,
and only the second one protects the work.

**Rejected: falling back automatically at run time.** A run that silently
switches from Postgres to a file because the database was unreachable produces
a result nobody can find, and half the records in one store and half in the
other. Stopping is the correct behaviour; the fallback is a decision for
`process`, made once, with a person.

**Discovery reads frontmatter, not a new index file.** A generated index is a
second source of truth that goes stale; `processes/*.md` already carry `slug`
and `Purpose`. The banner and the bare `/flywheel:run` read them at the moment
they print.

## S — Structure

- `skills/process/references/data-strategy-and-extensions.md` — the detection
  list gains its "no signal ⇒ the git-native store, confirmed not asked" branch
  and the define-time probe.
- `skills/run/SKILL.md` — step 1 gains: missing DATA.md stops; the read-only
  probe before step 2; and the no-slug listing branch.
- `scripts/session-start.sh` + `scripts/test-session-start.sh` — the contract
  list under the Runtime line, and its assertions.
- `skills/run/evals/` — a fixture with an unreachable declared store, plus the
  eval and its grader cases.
- README / `/flywheel:help` only if the surface wording changes; no new command.
- `.claude-plugin/plugin.json` + `upgrades/v0.49.0.md`.

## O — Operations

1. `scripts/test-session-start.sh` first: assert the banner lists a fixture
   repo's contracts and stays silent with none. Red, then implement, then green.
2. `run` step 1: missing DATA.md, the probe, the no-slug listing.
3. `process`: the no-signal branch and the define-time probe.
4. New `run` eval + grader: an unreachable store stops **before** any rule runs.
5. Eval gate (P22 phase 2) on the two skills this touches: `run` eval 1 (the
   happy path must not regress) and the new eval; `process` eval 1.
6. Full suite, every `check-*.sh`, then bump + upgrade note.

## N — Norms

Prose in two skills plus one hook script. bash + stdlib `python3` only. The
banner must stay fail-open: a malformed contract file makes it print nothing,
never break the session — the rule every other line of `session-start.sh`
already follows.

## S — Safeguards

- **The probe never writes.** Asserted in the eval, because a probe that
  mutates would be a Guardrail breach performed by the safety check itself.
- **No secrets in the banner or the ledger.** The contract list prints slug and
  Purpose only, never the Access line, which is where a connection string lives.
- **What this gate cannot see** (the rule this repo adopted after P36): the
  probe proves the path was reachable *at that moment*. It cannot prove the
  write will succeed — a permission revoked between step 1 and step 3 still
  fails at step 3, which is why step 3's read-back evidence stays exactly as it
  is. This narrows the window; it does not close it.
- **The stop path must not be a silent skip.** A run that stops for an
  unreachable store reports it as a **blocker**, not as a completed run with an
  empty result — the distinction the Guardrails' partial-failure path already
  draws.

## Success metric

One command, exit 0 = PASS:

```bash
bash scripts/test-session-start.sh \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/check-invocation-budget.sh \
  && bash scripts/check-test-pairing.sh \
  && grep -q 'processes/' scripts/session-start.sh \
  && grep -qi 'no slug' skills/run/SKILL.md \
  && grep -qi 'probe' skills/run/SKILL.md \
  && python3 -c "import json,sys; d=json.load(open('skills/run/evals/evals.json')); sys.exit(0 if len(d['evals'])>=4 else 1)"
```

Plus the eval gate, which is the only thing that can see the behaviour: **`run`
eval 1 green (no regression on the happy path), the new unreachable-store eval
green, and `process` eval 1 green**, all three before the version bump.

The decisive assertion is the new eval's, and it is stated as a negative on
purpose: with an unreachable store declared, the workdir afterwards contains
**no** result file, **no** partial row, and the transcript shows the run stopped
before the first Rule — not after.
