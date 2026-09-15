# Spec: P14 slice 3 — a contract that cannot be satisfied escalates instead of dead-ending

**Slug:** `p14c-contract-defect-escalates` · **Created:** 2026-09-14 · **Backlog:** P14 (third slice)
**Status:** shipped as **v0.53.0** — signed at the gate 2026-09-14. Metric
**PASS**. Eval gate green on all four paths: `run` eval 1 (7/7), eval 3 (3/3,
the guardrail half of the split sentence), eval 4 (7/7) and the new eval 5 (6/6,
seen red at 2 FAIL before the escalation existed).

**Prime:** `skills/run/SKILL.md` step 2, the sentence that caused the split —
*"If an input is invalid **or a rule cannot be satisfied**, follow the
Guardrails' partial-failure path and record it"*; the v0.50.0 benchmark's
FINDING note (the two executors' transcripts); P14's own backlog line, *"run
maturation can't escalate into pillar-1 work (a missing column dead-ends)"*;
`.claude/flywheel/LEARNINGS.md` → *"when two competent runs disagree about what
a skill requires, the skill is silent"*.

## The evidence this starts from

Building v0.50.0's eval produced a fixture whose contract contradicted itself —
its Output schema capped `digit_sum` at `0–27` while its own Rule 3 computes a
sum that reaches 36. Two fresh-context executors ran it and behaved **oppositely**,
neither breaking a stated rule:

- one proceeded with the true value (36), treating the bound as the defect, and
  matured the contract to widen it;
- one refused to emit a non-conforming output **and** refused to mature, holding
  that a schema change with a version bump is not a blocked run's call.

The second is correct on the skill as written — *"produce a result that conforms
**exactly** to the Output schema"* is unconditional. But the skill offers that
run nothing to do next, so a real defect in a real contract dies in a transcript
and the next run walks into the same wall.

## R — Requirements

1. **The two failures are named separately.** Step 2's *"an input is invalid or a
   rule cannot be satisfied"* conflates them. **Input-level**: this input cannot
   satisfy the contract → the Guardrails' partial-failure path, unchanged, which
   is what that path was built for. **Contract-level**: no input of this class
   could, because the contract contradicts itself → not a rejection. Filing a
   contract defect as a rejection mislabels a valid input, which is precisely
   what the second executor refused to do.
2. **A contract defect stops the run as a blocker**, on the path v0.49.0 already
   built for the unreachable store: record the blocker, persist nothing, produce
   no non-conforming output.
3. **The fixed rules are never rewritten to make the current input pass.** Not by
   widening a bound, not by relaxing a regex, not by dropping a field. A runtime
   that edits its own contract to accept what it is holding has no contract —
   and `process` already states the principle (*"never silently rewrite the fixed
   rules"*); this puts it where a **run** will read it.
4. **The run escalates instead of dead-ending.** It stubs a spec from its own
   evidence — the rule, the schema clause, the input that exposed the conflict —
   at `.claude/flywheel/specs/<slug>.md`, and names it in the report. The defect
   becomes pillar-1 work with a paper trail, which is P14's "escalate into
   pillar-1" line, reached from the case that actually needs it.

**Out of scope, deliberately:** `flywheel_runs` bookkeeping, approval tiers by
stakes×reversibility, process→process composition, batch inputs, `sync` over
contracts, `spec`'s prior-art step reading DATA.md, the `process=<slug>` ledger
key, `docs/proactive-loops.md`, and generalizing `agents/evaluator.md`.

**Not in scope and worth saying: the stub is not a fix.** It does not edit the
contract, bump a version, or pre-decide the answer. A human — or a later
`/flywheel:spec` cycle — does that. The stub exists so the evidence survives the
session, the same reason v0.50.0 committed the maturation.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| contract defect | a conflict between Rules, Output schema or Persistence that no input can satisfy | `skills/run/SKILL.md` step 2 |
| escalation stub | a spec seeded from the run's evidence, applying nothing | `skills/run/references/ledger-and-extensions.md` (shape), `.claude/flywheel/specs/<slug>.md` (output) |

## A — Approach

**Reuse the blocker, do not invent a third outcome.** v0.49.0 built stop-as-a-
blocker for the unreachable store, with a ledger transition and a report. A
contract defect takes the same exit; only the reason and the escalation differ.
One stop path, two causes — a run that ends without a result always looks the
same to whoever reads the ledger.

**The stub is a spec, not a note**, because this repo already has a shape for
"work that needs deciding" and a skill that consumes it. Writing the evidence
anywhere else invents a second inbox.

**The stub's content is a procedure, so it lives in the reference** — what to
seed into R/E/A/S/O/N/S from a run's evidence is a format a step consults, not a
rule that bites. The body carries the rules: name the defect, stop, never
rewrite, stub and report. `run`'s body has **552 B** of headroom against its
5,800 ceiling, so the split is what makes this fit — and if it does not, the
plan stops and reports rather than raising a ceiling set two releases ago.

**Rejected: letting the run fix the contract when the fix is "obvious".** It was
obvious in the fixture — a four-digit sum reaches 36, so the bound was simply
wrong — and one executor did exactly that. The reason to refuse anyway is that
*obvious* is the runtime's judgment about a document whose whole purpose is to
constrain that judgment. A contract a run may edit under pressure is a
suggestion.

**Rejected: recording the defect in the contract's Improvement log.** That log is
for refinements that were *applied*, and `run` now commits it (v0.50.0). An entry
describing an unfixed defect would be committed as though something had changed,
and the next reader could not tell the two apart.

## S — Structure

- `skills/run/SKILL.md` — step 2 splits the two failures; the contract-defect
  branch stops, forbids the rewrite, and escalates.
- `skills/run/references/ledger-and-extensions.md` — the stub's shape and what
  evidence seeds which section.
- `skills/run/evals/` — eval 5 returns, this time on a fixture that is
  **reachable**: the contradiction must block the run, and the behaviour under
  test must be what the run does *at* the block. (v0.50.0's deleted eval graded
  a path behind the block; this one grades the block itself.)
- `.claude-plugin/plugin.json` + `upgrades/v0.53.0.md`.

## O — Operations

1. Eval 5 and its grader first, seen red: today's skill offers the blocked run
   no escalation, so no stub exists and nothing names the defect.
2. Step 2's split and the contract-defect branch.
3. The stub's shape, in the reference.
4. Eval gate: `run` evals 1, 4 and 5 — 1 for no regression, 4 because the stop
   path is shared, 5 for the new behaviour.
5. Full suite, every `check-*.sh`, then bump and upgrade note.

## N — Norms

Prose in one skill and one reference. The stub is written with `Write`, inside
the repo's own `specs/` directory; no new permission surface, and no push.

## S — Safeguards

- **The stub is inert.** The eval asserts the contract is byte-identical after
  the run: no version bump, no schema edit, no Improvement log entry. A run that
  "escalates" by fixing the thing has not escalated.
- **A defect never becomes a rejection.** The eval asserts the `## Rejections`
  section is untouched: mislabelling a valid input is the failure the second
  executor avoided and the one this slice must not reintroduce.
- **What this gate cannot see:** whether the *right* defect was identified. The
  eval can prove a stub exists, names the conflicting sections and applies
  nothing; it cannot prove the diagnosis is correct. That judgment stays human,
  which is the point of escalating rather than fixing.
- **The blocked run still reports.** Escalation is additional, never a substitute
  for saying plainly that nothing was persisted and why.

## Success metric

One command, exit 0 = PASS:

```bash
bash scripts/check-invocation-budget.sh \
  && bash scripts/test-eval-graders.sh \
  && bash scripts/check-fixture-leaks.sh \
  && bash scripts/test-docs-consistency.sh \
  && grep -qi 'contract defect' skills/run/SKILL.md \
  && grep -qi 'never rewrite' skills/run/SKILL.md \
  && python3 -c "import json,sys; d=json.load(open('skills/run/evals/evals.json')); sys.exit(0 if len(d['evals'])>=5 else 1)"
```

Plus the eval gate: **`run` evals 1, 4 and 5 green** before the version bump.

The decisive assertions are eval 5's, and two of the three are **negative on the
contract**: after a run that hit a contract defect, a stub exists under
`specs/` naming both conflicting clauses, **and** the contract is byte-identical,
**and** `## Rejections` is untouched. A run that fixed the contract, or that
filed the valid input as a rejection, fails — and both are the behaviours real
executors chose when the skill was silent.
