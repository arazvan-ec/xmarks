# loop — behavioral evals (P29)

Manual release gate for `skills/loop` — and the **only suite that runs a whole
cycle**, which is why it exists: `work` writes its JSONL transition lines only
inside a `/flywheel:loop` cycle, so every other suite runs a skill standalone and
the telemetry it grades is never written. Before this suite, the two-tier
reporting and the `"commit": "<sha>"` field were verified by nothing.

Not in CI (see the root README → "Skill evals" for cost and runbook).

## What each eval instantiates

Both copy `fixtures/inventory-repo` into a scratch workdir. Eval 1's `setup`
`git init`s it and makes a seed commit; **eval 2 deliberately does not** — a
missing field cannot be proven by a passing run, so the fail-open path needs a
workdir where committing is impossible.

Brief the executor in eval mode: phase gates are pre-approved (no human is there
to sign off), the host task system and artifact publishing are unavailable, and
git operations inside the workdir are pre-approved. Point it at
`skills/loop/SKILL.md` and nothing else under this repo — in particular not
`evals/`.

## How it is graded

```bash
bash skills/loop/evals/check.sh <eval-id> "$W"   # one PASS:/FAIL: line per expectation
```

Exit 0 only if all pass; exit 2 on an unknown id. Artifacts only — the telemetry
the cycle wrote, the git objects it made, the behaviour of the code it left:

1. **The JSONL exists and parses** — at least two transitions, each an object
   with `ts` and `state`.
2. **No `tokens` key anywhere** (P18), matching what `run-cost.sh` warns about.
3. **Eval 1: every recorded `commit` resolves** via `git cat-file -e <sha>^{commit}`.
   This is the assertion the suite is for. A `commit` value is the only thing a
   flywheel skill writes down about something outside its own files, so it is the
   only field that can be *verified* instead of parsed — and the failure worth
   fearing is a plausible sha nobody ever made.
4. **Eval 1: no commit mixes `.py` source with `.claude/flywheel/` state.** That
   pairing is what `git add -A` mid-cycle produces and what a pathspec commit
   cannot, so it tests the rule rather than the wording of the rule.
5. **Eval 2: no `commit` key at all** — the executor must report that committing
   was impossible, not invent a sha.
6. **The feature actually works** — behaviour probes plus an independent
   `python3 -m unittest`, so "wrote plausible telemetry, built nothing" fails.

Deliberately **not** asserted: the number of commits, or the route taken.
Whether a two-function ask is one task or two is the skill's judgment, and
mechanizing a guess about it is how the `work` grader spent four releases
failing correct runs (v0.40.1).

## The grader must be able to fail

`scripts/test-eval-graders.sh` runs it on an untouched fixture (red), on a
synthesized ideal outcome (green), on that ideal with **one sha replaced by a
fabricated one** (red), and on that ideal plus **one swept commit** (red). The
first two are the P26 contract; the last two are the assertions this suite adds,
and an assertion nobody has watched fail is not evidence.

Two functions in the first draft passed vacuously in a workdir with no repo —
found by running exactly that case. Both now fail instead: the assertions only
mean something where committing was possible.

## Fixture hygiene

`fixtures/inventory-repo/` describes a warehouse module and a work item, and
nothing about how a run is graded (P26). `bash scripts/check-fixture-leaks.sh`
is the gate; ground truth lives here, in a file no workdir ever sees.
