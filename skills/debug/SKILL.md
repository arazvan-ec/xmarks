---
name: debug
description: Systematic debugging — reproduce, one hypothesis, isolate, fix the root cause, add a regression test. Use when something is broken or a test fails mysteriously.
argument-hint: "[what's broken]"
allowed-tools: Read, Edit, Grep, Glob, Bash
---

# /flywheel:debug — systematic debugging

Bug / symptom: **$ARGUMENTS**

Work the loop in order — do not jump to a fix:

1. **Reproduce reliably.** Find the smallest command/steps that trigger it every time. If you cannot reproduce it, getting a reliable repro IS the first task.
2. **One hypothesis.** State a single, specific hypothesis about the cause ("X is null because Y"). Not a list — the most likely one.
3. **Instrument.** Add logging / asserts / breakpoints that would confirm or kill the hypothesis. Run it and read the actual evidence. **If only someone else can run it** — a device you do not hold, a production system, a person — the loop SUSPENDS here: commit the instrumentation as instrumentation, say in the PR what it will discriminate and what the suite structurally cannot, and end the session. Step 4 needs evidence, and guessing is not a cheaper way to obtain it.
4. **Isolate.** Narrow to the smallest failing surface — `git bisect`, comment-out, or a minimal repro. Confirm the culprit.
5. **Fix the root cause** — not the symptom. Then add a regression test that fails without the fix and passes with it.
6. **Confirm.** Re-run the repro: it passes. Re-run the suite: still green.
7. **Commit.** The fix and its regression test are one logical change: `git commit -m "<imperative subject>" -- <paths>`, then `git push -u origin <branch>` — under `/flywheel:work`'s **Commit discipline** (pathspec only, no history rewriting, fails open, never on the default branch).

**Banned:** shotgun changes hoping something sticks; "fixing" by masking the symptom; declaring it fixed without re-running the repro; **a second instrumentation round with no new evidence between them** — two rounds mean the first one's evidence never arrived, and a third is guessing with extra steps; **raising effort or model tier to compensate for a missing discriminator** — with nothing able to kill a hypothesis, more reasoning produces more candidates, not fewer. If the evidence kills your hypothesis, go back to step 2 with what you learned — don't cling to it.
