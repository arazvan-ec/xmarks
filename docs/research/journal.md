# Design journal

A living, append-only journal of our flywheel design collaboration — so we can
pause, resume, and branch into new topics **without losing ideas**. This is the
narrative/discussion home; the structured backlog lives in
[`improvement-proposals.md`](improvement-proposals.md).

## How to use this journal

- **Resuming a session?** Read [Where we are now](#where-we-are-now) then
  [Open threads](#open-threads).
- **New idea mid-conversation?** Drop it in the [Parking lot](#parking-lot) so
  it isn't lost, even if we don't act on it yet.
- **Made a decision?** Record it in the Decision log of
  [`improvement-proposals.md`](improvement-proposals.md#decision-log) and add a
  dated line to the [Session log](#session-log) here.
- Append-only; newest entries at the bottom of each log.

## Where we are now

*Snapshot — 2026-07-08.*

- **Branch:** `claude/loop-analisis`. Everything so far is **docs-only** — no
  plugin code (`skills/`/`agents/`/`hooks/`/`scripts/`) changed, no version bump,
  CI green.
- **In the repo:**
  - [`../getting-started-with-loops.md`](../getting-started-with-loops.md) — adapted article + flywheel gap analysis.
  - The [`.`](README.md) research corpus — loop primitives, claude-mem, token efficiency, gentle-ai, comparisons, sources.
  - [`improvement-proposals.md`](improvement-proposals.md) — the living backlog (P1–P7).
  - [`strategy-build-vs-integrate.md`](strategy-build-vs-integrate.md) — the build-vs-integrate + git-native memory analysis.
  - [`git-native-memory-design.md`](git-native-memory-design.md) — the concrete design spec for that memory (P2/P3).
  - This journal.
- **Decided:** Option C (git-native curated memory) accepted; the P2/P3 design is
  **locked** ([`git-native-memory-design.md`](git-native-memory-design.md)).
  Implementation not started. Next decision: what to build first.
- **Active focus:** choosing the first real code change to implement.

## Session log

### 2026-07-08 — Session 1
- Reviewed the ClaudeDevs *"Getting started with loops"* article; saved an adapted
  reference doc.
- Mapped flywheel's loop coverage: turn-based ✅, goal-based 🟡 (no separate
  evaluator), time-based ❌, proactive ❌.
- Researched the official Claude Code loop primitives and **claude-mem**; saved
  the research corpus with sources.
- Drafted the improvement backlog P1–P6; user chose to **hold** and keep it as a
  living backlog for discussion.
- Reviewed **gentle-ai**: extracted a new idea (**P7 — delegation triggers**) and
  the **build-vs-integrate** strategic question; started the git-native memory
  strategy doc.
- Created this journal so we can resume and branch topics without losing ideas.
- Wrote the concrete **git-native memory design spec**
  ([`git-native-memory-design.md`](git-native-memory-design.md)) — entry format,
  SessionStart relevance/injection, `/recall`, read-priming hook, rotation,
  opt-in interop. Design draft only; no code changed.

### 2026-07-08 — Session 2
- **Locked the git-native memory feature.** Accepted the 4 design decisions:
  grep-live (no `.tsv` index yet); defer semi-auto staging; defer
  claude-mem/Engram interop; branch/files/recency scoring for v1. Marked T1
  (Option C accepted) and T2 (design locked) resolved. Feature design saved;
  implementation pending. Deciding what to build first.

## Open threads

The discussion queue. Status: 🔵 open · 🟡 in progress · ✅ resolved.

| ID | Thread | Status | Where |
| --- | --- | --- | --- |
| T1 | Build vs integrate (Q3) | ✅ Option C accepted | [`strategy-build-vs-integrate.md`](strategy-build-vs-integrate.md) |
| T2 | Git-native memory design | ✅ design locked | [`git-native-memory-design.md`](git-native-memory-design.md) |
| T3 | P1 model routing details (hard-code vs configurable; opus for hard reviews?) | 🔵 | [`improvement-proposals.md`](improvement-proposals.md#p1--model-routing-by-agent-role-) |
| T4 | P7 delegation triggers (adopt from gentle-ai) | 🔵 | [`improvement-proposals.md`](improvement-proposals.md#p7--delegation-triggers) |
| T5 | P4 evaluator — possibly redundant vs flywheel's metric-command check | 🔵 | [`improvement-proposals.md`](improvement-proposals.md#p4--goal-based-evaluator-for-autoloop) |
| T6 | Opt-in interop with claude-mem / Engram | 🔵 | [`strategy-build-vs-integrate.md`](strategy-build-vs-integrate.md) |

## Parking lot

Raw, un-triaged ideas. Anything lands here first; we triage into threads/proposals later.

- *(empty — add ideas here as they come up)*

## Artifact map

| File | Holds |
| --- | --- |
| [`README.md`](README.md) | Corpus index + how to use |
| [`claude-code-loops.md`](claude-code-loops.md) | Official loop primitives, caps, model routing |
| [`claude-mem.md`](claude-mem.md) | How claude-mem works |
| [`token-efficiency.md`](token-efficiency.md) | The token-saving numbers |
| [`gentle-ai.md`](gentle-ai.md) | How gentle-ai / Engram works |
| [`flywheel-vs-claude-mem.md`](flywheel-vs-claude-mem.md) | 3-way comparison + adoptable ideas |
| [`improvement-proposals.md`](improvement-proposals.md) | Living backlog P1–P7 + decision log |
| [`strategy-build-vs-integrate.md`](strategy-build-vs-integrate.md) | The strategic memory analysis |
| [`git-native-memory-design.md`](git-native-memory-design.md) | Concrete git-native memory design spec (P2/P3) |
| [`journal.md`](journal.md) | This journal |
| [`sources.md`](sources.md) | All source URLs |
