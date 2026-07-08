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

- **Branch:** `claude/loop-analisis`. **Shipped so far: P1 model routing (v0.9.0),
  P2 git-native memory first release (v0.10.0).** Prior work is the docs research
  corpus + this journal. All checks green (docs-consistency, install-vendored,
  plugin validate).
- **In the repo:**
  - [`../getting-started-with-loops.md`](../getting-started-with-loops.md) — adapted article + flywheel gap analysis.
  - The [`.`](README.md) research corpus — loop primitives, claude-mem, token efficiency, gentle-ai, comparisons, sources.
  - [`improvement-proposals.md`](improvement-proposals.md) — the living backlog (P1–P7).
  - [`strategy-build-vs-integrate.md`](strategy-build-vs-integrate.md) — the build-vs-integrate + git-native memory analysis.
  - [`git-native-memory-design.md`](git-native-memory-design.md) — the concrete design spec for that memory (P2/P3).
  - [`briefs/`](briefs/README.md) — async-ready, self-contained task briefs for P2–P7.
  - This journal.
- **Decided:** Option C (git-native curated memory) accepted; the P2/P3 design is
  **locked** ([`git-native-memory-design.md`](git-native-memory-design.md)).
  P2's first release is now **implemented and shipped** (v0.10.0); P3 is unblocked.
- **Active focus:** P1 and P2 done. Remaining work (P3–P7) is packaged as
  **async-ready briefs** ([`briefs/`](briefs/README.md)). The first routine
  attempt was blocked by a git-write permission issue (see the Async run state
  postmortem) and has been cleaned up; the next step is recreating the routines
  via the official UI with the repo selected, or continuing to build manually.

## Async run state — postmortem (routines blocked, cleaned up)

The first attempt (2026-07-08) launched P2/P4/P6/P7 as routines via the
`create_trigger` MCP tool. **All were blocked:** the routine sessions could clone +
implement but hit `403 "Not authorized to access repository"` on `git push`, so no
branch reached origin. P2's work (committed as `2fdf65c` inside its container)
stayed trapped and is lost. The 5 MCP-created triggers were **deleted** on
2026-07-08 — they only burned run allowance.

### Root cause
The low-level `create_trigger` MCP tool has **no "Select repositories" step**, so
the spawned sessions had no write-authorized repo. This interactive session pushes
fine, so it is **not** an account/admin permission gap — it was the creation path.

### Fix — recreate via the official Routines UI
1. **claude.ai/code/routines → New routine.**
2. **Select repositories → `arazvan-ec/xmarks`** (this wires `claude/*` push auth).
3. Environment: **Default** (Trusted) is enough — git goes through the internal proxy.
4. Prompt: paste the brief's **Starter prompt** (in [`briefs/`](briefs/README.md));
   it already `git fetch`es `origin/claude/loop-analisis`, so it finds the briefs
   even though a routine clones `main`.
5. Leave **"Allow unrestricted branch pushes" OFF** (branches are `claude/*`).
6. **Run now.** If it still 403s, check GitHub auth (`/web-setup`, or the Claude
   GitHub App installed with write on the repo).

### Fallback
This interactive session *can* push — if the UI routines don't pan out, build the
briefs here directly (one branch per brief, then push).

**Merge guidance (once branches land):** each brief is its own release — merge in
**ascending version order**, resolving small README/help/version conflicts at
merge. Run P3 only after P2 is present (it needs P2's typed `files=` metadata).

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

### 2026-07-08 — Session 3
- **Shipped P1 (model routing) as v0.9.0** — the first real plugin code change.
  `verifier` → haiku (mechanical run-and-report); reviewers stay sonnet
  (judgment), opus opt-in. Added `upgrades/v0.9.0.md`; documented in README +
  `/flywheel:help`. docs-consistency + install-vendored + `plugin validate`
  green. The release pipeline (bump → note → docs sync → tests) is now validated
  end-to-end. T3 resolved.

### 2026-07-08 — Session 4
- Decided to build the remaining proposals **asynchronously, one per fresh
  bounded session**. Authored self-contained **task briefs** in [`briefs/`](briefs/README.md)
  (P2, P3, P4+P5, P6, P7), each with a copy-paste starter prompt, exact files,
  acceptance criteria, and the release checklist — plus a guide on avoiding
  version/docs collisions when running in parallel. Opened thread T7.

### 2026-07-08 — Session 5
- The routine attempt **failed**: MCP-created routines hit `403` on push (no repo
  write scope — the `create_trigger` tool has no repo-selection step). Deleted all
  5 broken triggers, wrote the postmortem + UI recreation checklist (see Async run
  state), and confirmed the fallback (build in this write-capable session). T7
  status: routine path blocked; next step is UI recreation by the user.

### 2026-07-08 — Session 6
- **Shipped P2 (git-native memory, first release) as v0.10.0**, kicked off from
  `briefs/P2-git-native-memory.md`. Typed ledger entries in `/flywheel:compound`;
  relevance-scored, budgeted SessionStart injection (branch/files/recency,
  default top 12, `FLYWHEEL_LEARNINGS_INJECT` to override); new
  `/flywheel:recall <query>` skill. Backward-compatible with old free-prose
  entries. Added `upgrades/v0.10.0.md`; documented in README + `/flywheel:help`.
  P3 (read-priming hook) can now build on P2's `files=` metadata.

### 2026-07-08 — Session 7
- Ran the **P4-goal-evaluator.md** brief's own decide-first step for T5: is a
  separate evaluator agent worth building over autoloop's existing
  deterministic metric-command check? Decision: **no** — `/goal`'s evaluator
  compensates for having no other check, but a transcript-only evaluator can't
  verify anything autoloop's actual metric-command output hasn't already
  proven. **P4 deferred, decided against.**
- Built **P5 (token-usage discipline)** standalone: `skills/autoloop/SKILL.md`
  (hard budget stop, pilot-before-scaling, `/usage` pointer, `/goal`/`/loop`/
  workflow guidance), `skills/help/SKILL.md`, and `README.md` all updated. Hit
  the exact version collision `briefs/README.md` warned about — P2 (this same
  branch's PR, after merging `main`) had already taken **v0.10.0**, so P5
  rebased to **v0.11.0**; `upgrades/v0.10.0.md` stayed P2's note and a new
  `upgrades/v0.11.0.md` was added for P5. All three checks (docs-consistency,
  install-vendored, `plugin validate --strict`) green after the merge.
- T5 resolved (decided against, not built). T7 progress: one more brief (P4+P5)
  worked directly in a fresh session per the async plan, since the MCP routine
  path is still blocked pending UI recreation.

## Open threads

The discussion queue. Status: 🔵 open · 🟡 in progress · ✅ resolved.

| ID | Thread | Status | Where |
| --- | --- | --- | --- |
| T1 | Build vs integrate (Q3) | ✅ Option C accepted | [`strategy-build-vs-integrate.md`](strategy-build-vs-integrate.md) |
| T2 | Git-native memory design | ✅ design locked | [`git-native-memory-design.md`](git-native-memory-design.md) |
| T3 | P1 model routing | ✅ shipped v0.9.0 | [`improvement-proposals.md`](improvement-proposals.md#p1--model-routing-by-agent-role-) |
| T4 | P7 delegation triggers (adopt from gentle-ai) | 🔵 | [`improvement-proposals.md`](improvement-proposals.md#p7--delegation-triggers) |
| T5 | P4 evaluator — possibly redundant vs flywheel's metric-command check | ✅ decided against (deferred) | [`improvement-proposals.md`](improvement-proposals.md#p4--goal-based-evaluator-for-autoloop) |
| T6 | Opt-in interop with claude-mem / Engram | 🔵 | [`strategy-build-vs-integrate.md`](strategy-build-vs-integrate.md) |
| T7 | Async execution of P2–P7 via bounded briefs | 🟡 in progress | [`briefs/README.md`](briefs/README.md) |

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
| [`briefs/`](briefs/README.md) | Async-ready task briefs (P2–P7) + how-to-run guide |
| [`journal.md`](journal.md) | This journal |
| [`sources.md`](sources.md) | All source URLs |
