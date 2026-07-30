# work — behavioral evals (P22 phase 2)

Manual release gate for `skills/work` — run before bumping the version when a
diff touches this skill. Not in CI (see README.md → "Skill evals" for cost and
runbook).

To instantiate an eval: copy its fixture (`files`) to a scratch workdir,
substitute `{{WORKDIR}}` in the prompt, and point the executor at the copy.
The fixture's `run-tests.sh` appends `RESULT=<PASS|FAIL> IMPL_SHA=<hash>` to
`.check-log` on every run, so "the test ran red before the implementation
changed" is graded mechanically from the log against `baseline-sha` — no
trust in the transcript needed.

## Nothing that describes the assertions may live inside a fixture

The fixture directory is **copied into the executor's workdir**, so anything in it
is something the executor reads. Until 2026-07-30 each fixture's `README.md`
spelled out the grading rule verbatim — "the eval asserts from `.check-log` that
the first logged run is `RESULT=FAIL` with `IMPL_SHA` equal to `baseline-sha`" —
which tells the executor that red-before-green is what is being measured. That is
a stronger hint than the `./run-tests.sh` mention P25 removed from the prompts,
and it is why the with-skill and baseline arms still tied 8/8 on 2026-07-30 after
the de-hinting.

Nor may a fixture announce that it *is* a fixture. The 2026-07-30 baseline run
flagged the line "this directory is an eval fixture template, work in a copy" as
contradicting its instructions — which means it also told the executor it was
being evaluated, and an executor that knows it is graded is not a baseline. The
template-protection warning is an instruction to whoever *operates* the harness,
so it lives here and in the root README runbook: **instantiate a copy per run and
never point an executor at the template.** The copy the executor sees must read
like an ordinary repository.

Grading rules therefore live **here** (and in `evals.json`, which executors are
instructed not to read). Fixture files may describe the *scenario* only — what the
module is, what the work item is, that it is a template. If you add a note to a
fixture explaining how the harness works, you have re-opened the leak.

## How each kata is graded

Both katas are graded mechanically from `.check-log`, which only `run-tests.sh`
writes (`test_cart.py` refuses to import without `KATA_HARNESS=1`, which only that
script sets — so the log exists whichever way the executor is prompted):

1. First entry `RESULT=FAIL` with `IMPL_SHA` equal to `baseline-sha` — the test
   ran red while `cart.py` was still pristine.
2. Last entry `RESULT=PASS`.
3. `test_cart.py` covers the required behaviour, including the `ValueError` path.
4. `cart.py` implements it and the suite is green on an independent re-run.

## Before any iteration: check the fixtures for leaks

Every file in a fixture is copied into the workdir, so every file in it is part
of the prompt. Three leaks were found this week — the `work` fixture README, the
`verify` fixture READMEs, and a *comment in `run-tests.sh`* explaining that
red-before-green is what gets checked. Run this first; it must print nothing:

```bash
grep -rinE 'VERDICT:|baseline-sha|the eval asserts|pristine|red.?(→|->|then )green|mechanically checkable|eval fixture|is graded' \
  skills/*/evals/fixtures/
```

A hit is not automatically a leak — `run-tests.sh` must mention `.check-log`
because it writes it — but every hit needs a reason that is not "it explains what
we measure".
