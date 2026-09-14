# Spec: P39 — pay `work`'s invocation debt, by moving the argument out

**Slug:** `p39-work-invocation-debt` · **Created:** 2026-09-13 · **Backlog:** P39
**Status:** shipped as **v0.48.0** (PR #61) — pays the debt P36 recorded and P35
named on the way out (*"Revisit with per-skill exceptions, or by splitting
`work`"*). Metric **PASS**: 11,245 → 6,241 B, the `worst` exception deleted,
every clause of the success metric exit 0. Eval gate green on both suites that
can see the change — `work` eval 1 (7/7) and `loop` eval 1 (11/11), benchmarks
under `skills/{work,loop}/evals/benchmarks/2026-09-13-v0.48.0/`. 19/19
`scripts/test-*.sh`, every `check-*.sh`, `claude plugin validate . --strict`.

**Prime:** `skills/work/SKILL.md` and `skills/work/references/work-detail.md` (the
two files this re-partitions); `scripts/invocation-budget.txt` (the exception
being deleted); commit `e4d552e` (the extraction that created the debt, and the
precedent for stopping rather than buying bytes with a rule).

## R — Requirements

1. **`work`'s worst-case invocation cost falls under the 9,200 B default**, so
   its `worst=11400` exception is **deleted** rather than retuned. Today: 11,245 B
   (body 5,259 + reference 5,986).
2. **The body stays within its existing 5,400 B exception** while the
   re-partition happens. That exception is not raised to buy room. If the rules
   do not fit, this spec stops and says so — the precedent `e4d552e` set when it
   refused to move the anti-rationalization table for 759 B. (See **Revision**:
   it held at 5,396, and the ceiling was then set by the headroom rule, which is
   a different act.)
3. **No rule is lost or weakened.** Every imperative in either file today is
   still an imperative the model reads at execution, or it was a duplicate of one
   that already is.
4. **The three routing cases return to the body.** `+delegate` → the `executor`
   agent and never argue with an `ESCALATE`; a route above the session's tier;
   a route that could not be honored, which must be *said*. These are rules that
   bite, and `e4d552e` summarized them into a pointer — the one place the
   extraction did weaken the skill.
5. **The argument leaves the loaded set entirely**, to
   `docs/research/work-loop-rationale.md`, which the skill does **not** cite.
   Not charged by the gate, and not loaded at execution, because it is not for
   the model: it is why a rule is what it is, for the person deciding whether to
   change it.
6. **The reference keeps only what a step consults and cannot restate**: the
   transition line's JSON shape. A format, not an argument.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| body | the rules that bite, each stated once | `skills/work/SKILL.md` |
| reference | the transition line's shape | `skills/work/references/work-detail.md` |
| rationale | the argument behind the rules, uncited | `docs/research/work-loop-rationale.md` |
| ceiling | `worst` exception deleted, `body` untouched | `scripts/invocation-budget.txt` |

## A — Approach

**The finding that reframes the work: most of `work-detail.md` is not detail.**
Measured section by section, of its 5,986 B:

- *Why the git pair is force-free* (339 B) restates the body's own two commands.
- *Commit discipline — the reasoning behind each rule* (1,101 B) restates all
  four bullets the body already carries imperatively.
- *Escalation — why two reds and not three* (456 B) restates the body's rule and
  adds one sentence of argument.
- *Delegation thresholds* (1,416 B) restates the four thresholds the body
  already names inline, and explains each.

So ~3,300 B is the body said twice, the second time with its reasoning. P35
booked that as an extraction. It was a copy, and the copy is charged on every
invocation that follows any of the three citations — which is every cycle.

**One rule, one place.** The re-partition applies a single test to every line:
does a run executing the loop need this to act? If yes it is a rule and belongs
in the body, stated once. If it is a shape the run must reproduce exactly, it is
a reference. If it explains why the rule is right, it is for a human and belongs
in `docs/research/`, where this repo already keeps design argument.

**The rule applies to the body too, not only to the reference.** The body also
carries argument — *"you cannot observe your own usage, and a guess is the
unverifiable evidence P18 exists to keep out"*, *"Long solo runs bloat context
and bury signal"*, *"the plan gate approved the route along with the task"*.
Moving that out is what buys the room for requirement 4 without raising the body
ceiling. A consistency the reviewer of this change should check: an argument left
in the body while its twin was moved is the same defect, smaller.

**What stays argument-shaped in the body, deliberately.** The
anti-rationalization table is *reasons*, and it stays: it is not explaining a
rule, it is the rule — the guardrail against the exact failure this skill
exists to prevent, and the thing `e4d552e` refused to move. A one-clause reason
attached to an imperative ("`git add -A` is banned: it sweeps in whatever was
already dirty") also stays: the clause is what makes the rule obeyable, and it
costs a line, not a section.

**Rejected: splitting the skill.** P35's other suggestion. The body is not two
procedures wearing one name — it is one inner loop with its commit and route
obligations, and splitting it would put a rule one invocation away from the step
that must honor it, which is the defect being paid off, relocated.

**Rejected: splitting `work-detail.md` into four files.** It would make a run
that needs only the transition shape pay 1,255 B instead of 5,986 — a real gain
in practice, and **zero** against `worst`, which charges every cited reference.
That is P36's deliberate upper bound, so this spec cuts bytes rather than
rearranging them. Worth recording that the metric cannot tell a well-partitioned
reference from a monolith, and that this is the price of not inferring
conditionality from prose.

## S — Structure

- `skills/work/SKILL.md` — absorbs the three routing cases, the mis-route
  learning clause and the fixture-recipe clause; sheds its argument.
- `skills/work/references/work-detail.md` — reduced to the transition line.
- `docs/research/work-loop-rationale.md` (new) — the argument, uncited by any
  skill.
- `scripts/invocation-budget.txt` — `work worst=11400` deleted; `work body=5400`
  kept, and it becomes the only remaining `work` debt.
- `docs/research/improvement-proposals.md` — P39 + decision-log entry.
- `.claude-plugin/plugin.json` + `upgrades/v0.48.0.md`.

## O — Operations

1. Write `docs/research/work-loop-rationale.md`, moving every argument verbatim
   so the diff shows conservation rather than rewriting.
2. Re-partition the body and the reference.
3. `bash scripts/check-invocation-budget.sh` — read the two numbers.
4. Delete the `worst` exception; re-run. If the body exceeds 5,400, stop and
   report rather than raise it.
5. Eval gate (P22 phase 2), **two suites**, because the skill's own is not the
   one that grades what moved: `work` eval 1 (the skill's inner loop) and `loop`
   eval 1 (the transition line and the commits, which `work`'s evals do not
   assert at all).
6. Full `scripts/test-*.sh` + every `check-*.sh`, then bump and upgrade note.

## N — Norms

Prose, except the one-line `SIGPIPE` fix the Revision records, which moves with
an assertion in its existing pair. Moved text is moved verbatim wherever it
survives, so the diff is reviewable as conservation.

## S — Safeguards

- **The rules are enumerated before and after.** Every imperative in today's two
  files is listed, and each is accounted for in the new partition as kept, moved
  to the body, or identified as a duplicate of one already there. A rule that
  merely "reads covered" is the silent weakening this whole line of work exists
  to catch.
- **The gate cannot see requirement 3.** `check-invocation-budget.sh` measures
  bytes; it would report a triumphant number for a body with every rule deleted.
  That blind spot is why requirement 3 is graded by the evals and by the
  enumeration above, not by the ceiling going green.
- **The evals are the gate that can see behavior**, and the reason two suites
  run rather than one is that `work`'s own evals grade test-first discipline and
  never look at a commit or a transition line — precisely what this diff moves.
- **The body ceiling is not raised.** The room for the returning rules is bought
  by deleting argument, never by loosening the constraint.

## Success metric

One command, exit 0 = PASS:

```bash
bash scripts/check-invocation-budget.sh \
  && ! grep -qE '^work .*worst=' scripts/invocation-budget.txt \
  && grep -qE '^work body=5700$' scripts/invocation-budget.txt \
  && [ "$(( $(wc -c < skills/work/SKILL.md) + $(wc -c < skills/work/references/work-detail.md) ))" -le 9200 ] \
  && grep -q 'executor' skills/work/SKILL.md \
  && grep -q 'ESCALATE' skills/work/SKILL.md \
  && grep -q 'not honored' skills/work/SKILL.md \
  && [ -z "$(grep -rl 'work-loop-rationale' skills/ || true)" ] \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/check-test-pairing.sh
```

The `grep` clauses are what makes requirement 4 checkable rather than claimed:
the three routing cases must be present **in the body**, not behind a pointer.
The two negative clauses hold requirement 5 — the rationale file is not cited by
the skill, in either direction, so it is neither charged nor loaded.

Plus the eval gate, which the ceiling cannot stand in for: `work` eval 1 and
`loop` eval 1 both green before the version bump.

## Revision (2026-09-13, during the cycle)

**Two corrections, recorded rather than left to diverge — the `d76efc1`
precedent.**

**The body ceiling.** The re-partition landed the body at **5,396 B**, inside
the 5,400 exception requirement 2 protects, with all three routing rules back in
it. The exception was then moved to **5,700** — not to make a failing thing
pass, but because 4 B of headroom is the exact defect this whole line of work
exists to name (P35 shipped 41 B, P36's first cut left `help` 121 B). The
ceiling now follows the file's own ~300 B rule against the occupant, which is
the rule every other ceiling in that file already follows. Stated plainly
because "I met the constraint and then loosened it" is a shape that deserves
scrutiny: the constraint was met on the merits first, and the number that
replaced it comes from a rule, not from the diff.

**A success-metric clause was aimed wrong.** `! grep -q 'references/'
docs/research/work-loop-rationale.md` was meant to prove the rationale is not
loaded at execution. It proves nothing of the sort — that file is never scanned
by the gate, and the string matched its own prose explaining the convention. The
invariant that matters is that **nothing under `skills/` names the rationale
file**, so no invocation can reach it; that is what the metric asserts now, and
the pointer that did exist in `work-detail.md` was removed to make it true.

**Out of scope but found here, and fixed in the same release:** piping the
gate's stdout (`| head`) produced an unhandled `BrokenPipeError` traceback —
a P36 defect, invisible in CI where nothing pipes, and exactly the "only shows
up on someone else's machine" class the script's own `die()` comment warns
about. One `SIGPIPE` line, with an assertion that a piped read prints no
traceback.

**Final numbers:** body 5,259 → 5,396 (+137, and it gained three rules that were
behind a pointer); reference 5,986 → 845; **worst 11,245 → 6,241, a 44% cut**,
and `work` is no longer the most expensive skill to invoke — `process` (10,331)
is, which is the next debt.
