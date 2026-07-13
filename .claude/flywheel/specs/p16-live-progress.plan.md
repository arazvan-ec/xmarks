# Plan: p16-live-progress → release v0.16.0

Spec: `p16-live-progress.md` (signed 2026-07-13). Ordered tasks, each with its
local check. Test-first does not apply (prompt/docs release — the checks *are*
greps + the repo's test scripts). **Riskiest step:** T5/T6 — docs-consistency
and install-vendored interplay (vendoring rewrites `/flywheel:` references;
keep them in standard form so the installer handles them).

| # | Task | Files | Local check |
| --- | --- | --- | --- |
| T1 | Fixed **Progress** step in run (ledger per Rule, update per transition, regenerate + republish report, signal-don't-narrate) | `skills/run/SKILL.md` | `grep -q 'Progress' skills/run/SKILL.md` |
| T2 | **Progress reporting** section in the contract template | `skills/process/SKILL.md` | `grep -q 'Progress' skills/process/SKILL.md` |
| T3 | Per-phase ledger + cycle report obligation | `skills/loop/SKILL.md` | `grep -q 'Progress' skills/loop/SKILL.md` |
| T4 | Per-plan-task ledger line for standalone work | `skills/work/SKILL.md` | `grep -q 'Progress' skills/work/SKILL.md` |
| T5 | README feature note + state list gains `runs/`; help "Good to know" + state list (also closes P15's help-state-list gap: add `processes/` + `DATA.md`) | `README.md`, `skills/help/SKILL.md` | `grep -q 'runs/' README.md && grep -q 'runs/' skills/help/SKILL.md` |
| T6 | Version bump + upgrade note | `.claude-plugin/plugin.json`, `upgrades/v0.16.0.md` | `grep -q '"version": "0.16.0"' .claude-plugin/plugin.json && test -f upgrades/v0.16.0.md` |
| T7 | Pilot: live cycle report for THIS build (pillar-1 first) | `.claude/flywheel/runs/p16-live-progress/2026-07-13.html` + artifact | file exists + artifact URL returned |
| T8 | **verify** — spec's success metric | — | the spec's one-command metric exits 0 |
| T9 | **review** — fresh-context review of the diff (routing per P12 logic: prompt/docs diff → correctness+coherence lens, no perf/security fan-out) | — | no unresolved Critical/High |
| T10 | **compound + ship** — seed `LEARNINGS.md` (typed entries), backlog P16 → ✅ shipped, decision log, commit + push | `.claude/flywheel/LEARNINGS.md`, `docs/research/improvement-proposals.md` | push succeeds; `grep -q 'P16.*shipped' docs/research/improvement-proposals.md` |

Safeguards check (from spec): additions ≤ ~10 lines per skill (P12 discipline);
no secrets in the report; fail-open wording in every obligation; report
regenerated at transitions only.
