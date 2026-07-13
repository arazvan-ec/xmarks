# flywheel learnings

## decision: progress obligations live in skill prompts, not hooks
<!-- fw: type=decision; date=2026-07-13; files=skills/run/SKILL.md,skills/loop/SKILL.md,skills/work/SKILL.md,skills/process/SKILL.md; spec=p16-live-progress; branch=claude/every-agent-native-config-be56a6 -->

P16 (v0.16.0) encodes the live task-ledger + telemetry-report duty as fixed
skill text instead of a PostToolUse tracker hook. The hook was rejected because
the flow-audit had just flagged per-call hook latency as a real cost (P9/P11)
and the host task system already renders live state — prompts keep it
agent-native and zero-latency. Trade-off: advisory strength, mitigated by
writing the duty as contract-law sections (like GATEs), not tips.

## gotcha: a live report you don't regenerate is a lie
<!-- fw: type=gotcha; date=2026-07-13; files=.claude/flywheel/runs/p16-live-progress/2026-07-13.html,skills/run/SKILL.md; spec=p16-live-progress; branch=claude/every-agent-native-config-be56a6 -->

The v0.16.0 review caught the feature's own pilot report committed stale —
"SIN VEREDICTO" while the spec metric had already passed — violating the
honesty rule the report itself demonstrates. Guard: the report is state, not
prose. Regenerate at every phase transition and always immediately before
committing it; a stale flagship example undercuts the whole feature.

## pattern: route the review by diff type before fanning out
<!-- fw: type=pattern; date=2026-07-13; files=skills/review/SKILL.md; spec=p16-live-progress; branch=claude/every-agent-native-config-be56a6 -->

A prompt/docs-only diff got one combined correctness+coherence reviewer
(~64k subagent tokens) instead of the unconditional 3-reviewer fan-out (the
4-way audit cost ~380k) — same confidence at a fraction of the cost. This is
P12's routing applied manually until it ships: docs diff → single reviewer;
security only when input/auth/secrets/deps are touched; performance only for
loops/queries/IO.
