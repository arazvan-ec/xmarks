# P72 T5 — Thought Police

**Status:** signed 2026-10-04 (autonomous run).

## R — Requirements

CLAUDE.md: "never echo file contents into chat — after writing or editing a
file, report what and where; the diff is already in git; pasting pays for it
twice." Nothing observes it. The Thought Police reads the final reply at
`classic.Stop`:

- lines written this turn (`Write` content, `Edit` new_string; trimmed, ≥ 12
  chars) are remembered; the set resets on each idle prompt;
- if the reply's fenced code blocks repeat **8 or more** of those lines, the stop
  is blocked once with the reason ("report what and where, not the code"), so the
  reply is rewritten short;
- never twice in a row (`stop_hook_active`), so it cannot loop.

## A — gate (reshaped)

The roadmap had T5 also enforce the progress toolbar and replace `toolbar.sh
stop`. Analysis says drop that half: P56 already blocks a reply without the
toolbar line, and two blockers on one rule give two reasons for one fault, with
no gain. T5 takes the rule nothing enforces. A model classifier was the first
idea; a deterministic line overlap is cheaper (no call per stop), testable
(`model.classify` cannot be stubbed, T0b), and grades exactly the stated rule.

## S — Success metric

`bash scripts/check-mods.sh origin/main thought-police` green: echoed Write
blocked, echoed Edit blocked, a short snippet passes, unrelated code passes,
no second block, set resets per prompt.
