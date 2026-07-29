# verify — behavioral evals (P22 phase 2)

Manual release gate for `skills/verify` — run before bumping the version when
a diff touches this skill. Not in CI: one iteration (3 evals × with-skill vs
baseline) costs roughly 300-800k tokens. Full runbook: README.md → "Skill
evals".

To instantiate an eval: copy its fixture (`files`) to a scratch workdir,
substitute `{{WORKDIR}}` in the prompt with that path, and point the executor
at a copy — never at the fixture template. Executors save `report.md` (verdict
as last line) and `transcript.md` (commands + real output) for grading.
