# Spec: P56 — the progress toolbar is enforced, not remembered

**Slug:** `p56-the-toolbar-is-enforced` · **Created:** 2026-09-23 · **Backlog:** P56
**Status:** in progress

**Prime:** CLAUDE.md "Progress toolbar" (2026-09-21), and the ledger entry *"an
instruction nothing can observe failing is not enforced"*.

## R — Requirements

On 2026-09-23 a session materialized a 4-task plan and answered for several
turns without the toolbar; told once, it put the line on the apology and dropped
it again on the next note. The rule lived only in this repo's CLAUDE.md — loaded
once, far back in context by the time it applies, and observed by nothing. The
owner asked for it to hold in new sessions without being reminded, in the
plugin, and accepted one clarification: **the toolbar is required on the final
reply of each turn; mid-turn notes between tool calls are exempt.**

1. **An open list is detected from state, not from the conversation.** A plan
   `.claude/flywheel/specs/<slug>.plan.md` that the branch touches (vs its
   base, or uncommitted) and that has a task with no transition line in
   `runs/<slug>/*.jsonl` is open. No such plan → every hook is a no-op.
2. **Remind (`UserPromptSubmit`).** With an open list, inject the toolbar format
   and the list's live count (`slug done/total`, open task ids) as
   `additionalContext`, so the rule sits at the end of context every turn.
3. **Enforce (`Stop`).** With an open list, a final message whose first
   non-empty line is not `<🟢|⏸️|🔴|🏁> <n>/<N> …` blocks the stop (exit 2) with
   the expected line. `stop_hook_active` never re-traps. Any internal error is
   fail-open.
4. **Wired in both install paths**: `hooks/hooks.json` and the vendored
   installer.

## Success metric

`bash scripts/test-toolbar.sh` green: no plan → no-op both modes; open plan →
remind emits the count, stop blocks a bare reply and passes a toolbar reply;
closed plan → no-op; `stop_hook_active` → pass; transcript fallback when
`last_assistant_message` is absent. `test-install-vendored.sh`, the full sweep,
`test-docs-consistency.sh` and `claude plugin validate . --strict` green.
