# Brief: P4 — goal-based evaluator for autoloop (+ P5 token discipline)

**One-liner:** add a separate cheap **evaluator** agent that judges autoloop's
stop condition (like `/goal`'s Haiku evaluator) instead of the working agent
self-judging — and, in the same release, tighten autoloop's token discipline (P5).

**Prereqs:** none. **Branch:** `claude/flywheel-p4-evaluator`. **Version:** next
unreleased at merge.

**Read first (bounded context):** this brief + [`../claude-code-loops.md`](../claude-code-loops.md)
(§1 `/goal` evaluator mechanism) + `skills/autoloop/SKILL.md`.

## Decide first — is P4 worth it? (open question T5)

flywheel's autoloop already checks a **metric command's output** (deterministic).
`/goal`'s evaluator only judges from the transcript, which is *weaker* than a real
metric check. So **first assess**: does an evaluator add rigor over autoloop's
existing metric check, or is it redundant? Options for the session:
- If it adds value (e.g. guards against the agent misreporting the metric): build
  the evaluator as a **cross-check** on top of the metric command.
- If redundant: **skip P4**, do only P5 (token discipline), and record the
  decision in the journal/decision log.

## Files to change (if building P4)

- **New** `agents/evaluator.md` — `model: haiku`; given the autoloop metric/stop
  condition + the last iteration's reported evidence, returns continue/stop +
  reason. Read-only tools.
- `skills/autoloop/SKILL.md` — consult the evaluator when the loop wants to stop;
  keep the existing max-iterations budget.
- `README.md` (Agents section) — mention `evaluator` (docs-consistency requires
  agents to appear in the README).

## P5 (fold in here) — token discipline

- `skills/autoloop/SKILL.md` + `skills/help/SKILL.md` + `README.md`: reference
  `/usage`, `/goal` status, `/workflows` for visibility; add pilot-before-scaling
  and interval-matching guidance; make the budget/stop-criteria explicit.

## Release

`.claude-plugin/plugin.json` + `upgrades/v<version>.md`. `requires-action`: false
(re-vendor picks up the new agent + skill text).

## Acceptance criteria

- A recorded decision (in the journal) on P4 build-vs-skip, with reasoning.
- If built: autoloop consults the evaluator before stopping; evaluator is `haiku`;
  README lists it. If skipped: only P5 lands.
- All three checks green.

## Starter prompt (paste into a fresh session)

> Work flywheel proposal **P4 (goal evaluator) + P5 (token discipline)** on branch
> `claude/flywheel-p4-evaluator`. Read only `docs/research/briefs/P4-goal-evaluator.md`,
> `docs/research/claude-code-loops.md`, and `skills/autoloop/SKILL.md`. First
> decide whether the evaluator adds rigor over autoloop's existing metric-command
> check (record the decision in `docs/research/journal.md`). Then implement
> accordingly + P5's token-discipline guidance, following the release checklist in
> `docs/research/briefs/README.md`. Commit and push. No PR unless asked.
