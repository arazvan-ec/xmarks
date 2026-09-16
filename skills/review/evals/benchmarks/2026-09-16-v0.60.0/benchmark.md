# review evals — 2026-09-16 (release gate for v0.60.0, P32)

**Scope, before any number: this is a fallback-path benchmark.** `Task` does not
exist inside a subagent, so in all three runs **no `reviewer-*` was dispatched**.
What was measured is which reviewers each run *drew* and what its report *said*
about the dispatch. Nothing here is evidence about the parallel fan-out.

**P32 Option A — the top-level arm, where dispatch would be real — has not been
run.** It is written down as a manual runbook step in `../../README.md` and that
is all it is today.

## Result

| Eval | Drew | Assertions | Result | Tokens | Tool calls | Time |
| --- | --- | --- | --- | --- | --- | --- |
| 1 docs-only | correctness | 4 | **4/4 PASS** | 63,252 | 11 | 167 s |
| 2 input-handling | correctness, security, **performance** | 5 | **5/5 PASS** | 64,439 | 14 | 177 s |
| 3 cross-domain | all three | 4 | **4/4 PASS** | 58,920 | 11 | 184 s |

13 of 13 assertions green, 3 of 3 runs.

## What 3/3 green actually proves, and what it does not

It proves **no assertion reddened a correct run** — the failure this repo has
paid for twice (v0.40.1, v0.41.0). It does **not** prove the suite
discriminates: on first contact nothing was caught, because nothing went wrong.

The discrimination evidence is elsewhere, and it is mechanical: five committed
cheats, each required to go red **on exactly its own assertion** (the arm asserts
the FAIL lines and their count, so two cheats cannot quietly collapse into one),
plus a seven-spelling battery on the option-B alternation and a silence case
required red. That is `scripts/test-eval-graders.sh`, run in CI's discovery glob.

## The near-miss worth keeping

**Eval 2's run drew all three reviewers**, where the committed ideal outcome
draws two. The suite asserts only that *security was drawn* on that diff. Had it
also asserted that **performance was not** — which was the tempting symmetry
with eval 1 — the first real run the assertion ever saw would have been red, and
the run would have been right: `security.patch` adds two `SELECT`s per request,
and the performance rule says "loops, queries, I/O". The absence assertion lives
only on eval 1, where a docs-only diff leaves no second reading.

This is the whole v0.40.1 failure mode caught before shipping, by measurement
rather than by reasoning about it.

## The disclosure, in three different spellings

None of the three runs was prompted for a form of words, and no two produced the
same one:

- **Eval 1** — "the correctness lens below was executed directly in this context".
- **Eval 2** — "all three lenses synthesized here in one context since dispatch
  returns no findings".
- **Eval 3** — "All three lenses were therefore applied by the synthesizing
  context itself, not by three independent adversarial reviewers. That is
  strictly weaker than a real dispatch: one context, one set of blind spots, no
  disagreement to surface."

None matches the committed ideal outcome's wording either. An alternation is the
right shape for this property, and a single-phrase match would have failed at
least two of these three.

**A caveat on what that evidence covers.** The option-B clause was added to
`skills/review/SKILL.md` at 22:38:25Z. Run 3's report was written at 22:35:05Z,
so it is unambiguously the *unprompted* behaviour P32 predicted. Runs 1 and 2
were launched before the clause and finished after it (22:40:26Z, 22:40:41Z);
which text they read is not established, so they are not counted as unprompted
evidence. Eval 1 does not assert disclosure at all, so only eval 2's option-B
PASS carries the ambiguity.

## Incidental: the reviews were good

Not asserted, and not a gate — but worth recording, because a routing suite that
never looks at the findings would miss it. Eval 2's run confirmed the injection
end-to-end against a throwaway copy of the app instead of asserting it from the
source, and found the committed token as a second Critical. Eval 1's run ran the
code to check the *prose*, and caught that documented uniqueness does not survive
the documented 80-character truncation. Eval 3's run closed by recommending a
real three-reviewer dispatch — Option A, volunteered.

## The grader changed after these runs, and they were re-graded

A bot review of the PR found three assertions that a report asserting their
*opposite* could satisfy: the bare phrase "in this context" made
`"dispatched in parallel in this context"` pass option B; two name matches made
`"the security and performance reviewers both ran"` pass the skip check; and a
bare grep made `"found no SQL injection and no hardcoded credential"` pass the
defect-class check. All three were reproduced green against the shipped grader,
then fixed, and each is now a committed cheat with its own red arm.

**The three saved workdirs were re-graded against the tightened grader: 13/13
again, unchanged.** That is the evidence the tightening cost no correct run —
and it is the reason the runs are still quoted here, though they were produced
before it.

## Limitations

- No dispatch exercised. Not an omission: it cannot be done from a subagent.
- One run per eval — nothing here is a variance measurement.
- 3/3 green on first contact, so these runs did not discriminate (see above).
- The clause-timing ambiguity on runs 1 and 2, stated in full above.
