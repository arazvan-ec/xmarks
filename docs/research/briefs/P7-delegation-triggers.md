# Brief: P7 — delegation triggers

**One-liner:** encode concrete "when to hand off to a fresh-context subagent"
thresholds (from gentle-ai) into flywheel's `work` skill — cheap guardrails against
context bloat.

**Prereqs:** none. **Branch:** `claude/flywheel-p7-delegation`. **Version:** next
unreleased at merge. Smallest of the remaining code briefs.

**Read first (bounded context):** this brief + [`../gentle-ai.md`](../gentle-ai.md)
(the delegation-triggers section) + `skills/work/SKILL.md`.

## Goal & decisions

flywheel says "use subagents" but gives no heuristics for *when*. Adopt concrete
thresholds (tune to flywheel's phases as needed):
- **4-file rule** — reading 4+ files → delegate exploration to a subagent.
- **Multi-file write rule** — touching 2+ non-trivial files → trigger a fresh
  review before advancing.
- **Long-session rule** — after ~20 tool calls or ~5 exploratory reads → pause and
  re-plan.

Open question to settle in-session: adopt these numbers or tune them; and
**advisory guidance** vs a **hard rule** (start advisory — lower risk).

## Files to change

- `skills/work/SKILL.md` — add a short "when to delegate" section with the
  thresholds; tie into flywheel's existing fresh-context reviewers.
- `skills/help/SKILL.md` + `README.md` — a one-line mention.
- `.claude-plugin/plugin.json` + `upgrades/v<version>.md` (`requires-action: false`).

## Acceptance criteria

- `work` documents the thresholds and the delegate/review action.
- All three checks green.

## Starter prompt (paste into a fresh session)

> Implement flywheel proposal **P7 (delegation triggers)** on branch
> `claude/flywheel-p7-delegation`. Read only `docs/research/briefs/P7-delegation-triggers.md`,
> `docs/research/gentle-ai.md`, and `skills/work/SKILL.md`. Add advisory delegation
> thresholds (4-file / multi-file-write / long-session) to `skills/work/SKILL.md`
> with a one-line mention in help + README, then follow the release checklist in
> `docs/research/briefs/README.md`. Commit and push. No PR unless asked.
