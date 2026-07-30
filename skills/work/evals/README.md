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
