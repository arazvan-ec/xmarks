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

## Status

Fixtures were cleaned in v0.36.0 and the ground truth moved to
`skills/verify/evals/README.md`. **No iteration has yet run against the clean
fixtures**, so `verify` currently has no trustworthy measurement of the
bug-detection assertions. Re-running is the open follow-up; this file stays as
the record of what was actually measured on 2026-07-29.
