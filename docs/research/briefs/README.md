# Task briefs — bounded, async-ready kickoffs

Each brief here is a **self-contained kickoff** for one flywheel improvement, so it
can be built in its **own fresh session with minimal context** — no need to reload
our whole design conversation. A new session reads *only* its brief (plus the one
design doc it links) and can execute end to end.

This is the git-native, bounded-context idea (see
[`../git-native-memory-design.md`](../git-native-memory-design.md)) applied to our
own workflow.

## The briefs

| Brief | Proposal | Size | Depends on | Suggested branch | Status |
| --- | --- | --- | --- | --- | --- |
| [`P2-git-native-memory.md`](P2-git-native-memory.md) | Smarter learnings ledger (memory) | Medium | — | `claude/flywheel-p2-memory` | ✅ shipped (v0.10.0) |
| [`P3-read-priming-hook.md`](P3-read-priming-hook.md) | Learnings-aware read priming | Medium | **P2** | `claude/flywheel-p3-read-priming` | ✅ shipped (v0.11.0) |
| [`P4-goal-evaluator.md`](P4-goal-evaluator.md) | Goal-based evaluator (+ P5 token discipline) | Medium | — | `claude/flywheel-p4-evaluator` | ✅ shipped (P5 v0.12.0, P4 evaluator v0.14.0) |
| [`P6-proactive-loops.md`](P6-proactive-loops.md) | Time-based / proactive loop guidance | Small (docs) | — | `claude/flywheel-p6-proactive` | ✅ shipped (docs) |
| [`P7-delegation-triggers.md`](P7-delegation-triggers.md) | Delegation triggers | Small | — | `claude/flywheel-p7-delegation` | ✅ shipped (v0.13.0) |
| [`P8-agent-native-processes.md`](P8-agent-native-processes.md) | Agent-native runtime pillar (`process` + `run`) | Medium | — | `claude/plugin-agent-native-repo` | ✅ shipped (v0.15.0) |

Order note: **the whole P1–P7 dev-loop roadmap has shipped** — P1 v0.9.0, P2
v0.10.0, P3 v0.11.0, P5 v0.12.0, P7 v0.13.0, P4 (evaluator) v0.14.0, and P6 as
docs. (P3 built on P2's typed `files=` metadata, in that order.) **P8 (v0.15.0)
opens a new direction** beyond the original dev-loop set — the agent-native
runtime pillar (`process` + `run`). These briefs are kept for reference.

> **Collision note (2026-07-08, resolved):** several parallel automated sessions
> built the same proposals independently — P2 reached two open PRs, and P4 had a
> build-it (#16) vs defer-it (#17) pair. Duplicates were closed and one of each
> was merged; P4 was later revived and shipped in v0.14.0. All PRs are now
> resolved and the roadmap is complete — this note stays as the record of why the
> "avoiding collisions" guidance below exists.

## How to run one async (the workflow)

1. **Open a fresh Claude Code session** on this repo (web or CLI). Bounded context
   is the whole point — don't carry over old chat.
2. **Paste the brief's "Starter prompt"** (at the bottom of each brief). It tells
   the session exactly which files to read, so it loads only what it needs.
3. The session works on the brief's **own branch**, runs the release checklist,
   and pushes. Review/merge when ready.

## Avoiding collisions when running in parallel

Every code brief is its own **release**, so parallel sessions can collide on:

- **`plugin.json` version + `upgrades/vX.Y.Z.md`** — two branches both bumping the
  version conflict. Fix: **finalize the version at merge time**, not at branch
  time. Each brief says "bump to the next unreleased version" and, at time of
  writing, the next is **0.10.0**; whoever merges first takes it, the next rebases
  to 0.11.0, etc.
- **`README.md` command/agent tables and `skills/help/SKILL.md`** — small,
  mergeable edits, but expect a trivial conflict if two briefs both add a skill.
- **Docs-consistency test** — a new skill must be added to *both* the README table
  and the help map in the *same* branch, or CI fails.

**Simplest safe mode:** run them **one at a time** in fresh sessions (async in the
sense of "separate optimal-context sessions", serialized on releases). **Parallel
mode:** one branch per brief off `main`, resolve the version/README/help conflicts
at merge — they're tiny.

## Spawning the sessions

- **Manual (recommended):** open a new session and paste the starter prompt.
- **Automated:** these can be turned into Claude Code **routines** (scheduled or
  on-demand) that each spawn a fresh session seeded with the starter prompt. Ask
  and I can set that up — it creates persistent triggers, so I'll confirm first.

## The release checklist (in every code brief)

1. Make the code change.
2. Bump `.claude-plugin/plugin.json` to the next unreleased version.
3. Add `upgrades/v<version>.md` — frontmatter `version` / `requires-action` /
   `summary`, a `## What changed`, and `## Strategy` only if `requires-action: true`.
4. If you added a skill: add it to the README command table **and** the
   `/flywheel:help` map (docs-consistency enforces both).
5. Run all three: `bash scripts/test-docs-consistency.sh`,
   `bash scripts/test-install-vendored.sh`, `claude plugin validate . --strict`.
6. Update [`../improvement-proposals.md`](../improvement-proposals.md) status +
   [`../journal.md`](../journal.md).
7. Commit + push the brief's branch.
