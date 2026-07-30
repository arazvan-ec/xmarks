# Fixture leak — read this before citing these numbers (found 2026-07-30)

This iteration ran against fixtures whose `README.md` — copied into the
executor's workdir — **contained the answer key**. `tally-sneaky`'s named the
defect's location, named the rationalization trap, and stated the required
verdict; `tally-fail`'s and `tally-pass`'s stated the correct verdict outright.
Both arms saw it.

## What survives

The headline delta — **with-skill 10/10 assertions vs baseline 7/10** — rests
entirely on the machine-parseable verdict line, and the leak worked *against*
that result rather than for it: the fixture README stated the required
`VERDICT: FAIL — <reason>` format verbatim and the baseline still closed its
report in prose all three times. If anything the leak makes the skill's measured
contribution an **understatement**.

## What does not survive

The "detected the bug", "cites concrete failure evidence" and "ran the real CLI"
assertions. Both arms passed them and the benchmark already noted they did not
discriminate — now there is a reason: the fixture told the executor where to look
and that the CLI had to be run. Those assertions measured reading
comprehension, not verification discipline.

## Status — superseded 2026-07-30

Fixtures were cleaned in v0.36.0 and the ground truth moved to
`skills/verify/evals/README.md`. The re-run has now happened:
**`../2026-07-30/` is the current regression baseline** — clean fixtures, graded
by the committed `check.sh` (P26 / v0.37.0).

Both predictions on this page held. The delta survived: **+3/11 on clean fixtures
against +3/10 here**, still resting entirely on the machine-parseable verdict
line. And the "does not survive" list was right — with the leak gone, the
bug-detection, evidence-citation and ran-the-real-CLI assertions **still** pass in
both arms, so they are regression guards rather than evidence of skill value.
That is now a measured conclusion instead of one this file had to withhold.

This file stays as the record of what was actually measured on 2026-07-29.
