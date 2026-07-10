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

- **Shipped so far (on `main`): P1 model routing (v0.9.0), P2 git-native memory
  (v0.10.0), P3 read-priming hook (v0.11.0), P6 proactive loop guidance (docs,
  no version bump), P5 token-usage discipline (v0.12.0), P7 delegation triggers
  (v0.13.0), P4 goal evaluator (v0.14.0).** All seven original proposals are
  now shipped. P4 was briefly deferred/decided against in the P5 release, then
  **reopened** in Session 10 with a different mechanism than the one that was
  rejected (see T5), and rebased twice more at merge time after P7
  independently claimed v0.13.0 (Session 11). The P2 → P3 git-native memory
  sequence is complete. Prior work is the docs research corpus + this journal.
  All checks green (docs-consistency, install-vendored, read-prime,
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
  **locked** ([`git-native-memory-design.md`](git-native-memory-design.md)) and
  **implemented** (§1–§4 in v0.10.0, §6 in v0.11.0). §5/§7/§8 (flat index,
  rotation/archival, claude-mem/Engram interop) remain deliberate follow-ups,
  only if a measured need arises.
- **Active focus:** all of P1–P7 done — the original async-briefs backlog
  ([`briefs/`](briefs/README.md)) is fully shipped. The first routine attempt
  was blocked by a git-write permission issue (see the Async run state
  postmortem); several
  parallel sessions since then have built P2/P3/P4/P5/P6 directly (some
  duplicating each other — see Session 6–10 notes), and PRs are being reviewed
  and merged one at a time.

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
  (Note: a second, independent P2 attempt was also built and pushed in
  parallel by another session on `claude/beautiful-mendel-2wk69j` — this one,
  from `claude/tender-bardeen-xfa5vz`/PR #19, is the one that was merged.)

### 2026-07-08 — Session 7
- **Shipped P3 (read-priming hook) as v0.11.0**, on branch
  `claude/beautiful-mendel-2wk69j`, built directly on top of the merged P2
  (v0.10.0 on `main`) rather than the session's own now-superseded P2 attempt
  — that duplicate P2 commit was dropped by resetting the branch onto `main`
  before building P3 fresh. New `scripts/read-prime.sh` as an advisory
  `PreToolUse`/`Read` hook that surfaces ledger entries whose `files=` metadata
  names the file about to be read; wired into `hooks/hooks.json`, vendored by
  `install-vendored.sh`, covered by `scripts/test-read-prime.sh` (wired into
  CI). All checks green. T7's ledger thread (P2 → P3) is now fully shipped.

### 2026-07-08 — Session 8
- **Shipped P6 (proactive loop guidance)** from its brief, docs-only. Added
  `docs/proactive-loops.md` (babysitting a PR with `/loop`, scheduling
  flywheel checks with `/schedule`, bounding a stream with `/goal`, fanning out
  with workflows, plus the caps table) and linked it from the README. No
  version bump (docs-only, not vendored/checked by docs-consistency). A
  runtime skill (e.g. `/flywheel:watch`) remains open per the brief.

### 2026-07-08 — Session 9
- Ran the **P4-goal-evaluator.md** brief's own decide-first step for T5: is a
  separate evaluator agent worth building over autoloop's existing
  deterministic metric-command check? Decision: **no** — `/goal`'s evaluator
  compensates for having no other check, but a transcript-only evaluator can't
  verify anything autoloop's actual metric-command output hasn't already
  proven. **P4 deferred, decided against.**
- Built **P5 (token-usage discipline)** standalone: `skills/autoloop/SKILL.md`
  (hard budget stop, pilot-before-scaling, `/usage` pointer, `/goal`/`/loop`/
  workflow guidance), `skills/help/SKILL.md`, and `README.md` all updated. Hit
  the exact version collision `briefs/README.md` warned about — twice: this
  branch's own PR first bumped to v0.10.0, but P2 merged into `main` first and
  claimed it, so this rebased to v0.11.0; then P3 also merged first and
  claimed *that* number, so this landed as **v0.12.0**. `upgrades/v0.10.0.md`
  and `upgrades/v0.11.0.md` stayed P2's and P3's notes respectively; a new
  `upgrades/v0.12.0.md` was added for P5. All three checks (docs-consistency,
  install-vendored, `plugin validate --strict`) green after both merges.
- T5 resolved (decided against, not built). T7 progress: one more brief (P4+P5)
  worked directly in a fresh session per the async plan, since the MCP routine
  path is still blocked pending UI recreation.

### 2026-07-08 — Session 10
- A parallel P4+P5 attempt from this same period (branch
  `claude/exciting-ritchie-ei67f0`, PR #16) had independently built the
  evaluator agent and reached the **opposite** conclusion on T5 — before the
  Session 9 rejection had merged. Since PR #17 (Session 9's P5-only release,
  with P4 deferred) merged first, PR #16 was closed as a duplicate per the
  parallel-briefs collision rule.
- On review, **reopened T5**: the v0.12.0 rejection is right that a
  transcript-only evaluator (reading what the working agent reported, like
  `/goal`'s) is redundant with autoloop's own metric-command output — nothing
  new there. But it isn't the only possible evaluator, and the rejection named
  its own revisit condition explicitly: "the working agent fabricating a
  metric result instead of running the command." Built exactly that instead:
  `agents/evaluator.md` (`model: haiku`) **independently re-runs the metric
  command** rather than reading the working agent's self-report, closing the
  self-grading-bias gap the transcript-only design couldn't touch.
  `skills/autoloop/SKILL.md` consults it before an ambiguous keep/discard or a
  stop decision, on top of (not instead of) the existing metric-command check
  and the v0.12.0 token-discipline guidance. Restarted the branch from the
  current `main` (the old PR #16 commits predated P3/P5/P6 and were stale) and
  opened PR #23, versioned **v0.13.0**. docs-consistency + install-vendored +
  `plugin validate --strict` all green.

### 2026-07-08 — Session 11
- Hit the version-collision pattern **a second time on the same PR**: while
  PR #23 (P4, v0.13.0) sat open, **P7 (delegation triggers)** merged into
  `main` first and also claimed v0.13.0 — the exact scenario
  `briefs/README.md` warns about, just recurring. Merged current `main` into
  the PR branch; the only real conflict was the add/add on
  `upgrades/v0.13.0.md` (README, `improvement-proposals.md`, and
  `skills/help/SKILL.md` all auto-merged cleanly since P7 and P4 touch
  different sections). Kept P7's note as `v0.13.0.md`, moved P4's to
  **`upgrades/v0.14.0.md`**, and rebased `plugin.json` + every P4 version
  reference to **v0.14.0**. All seven original proposals (P1–P7) are now
  shipped on `main` (once this PR lands). docs-consistency + install-vendored
  + `plugin validate --strict` all green after the merge.

### 2026-07-10 — Session 12
- **New direction from the repo owner (P8): make flywheel agent-native.** Beyond
  the dev loop, flywheel should let Claude *operate* the repos it's installed in —
  run recurring domain operations ("analyze a car") as the backend, persist to the
  repo's own datastore (e.g. Postgres), and improve each operation per run. The
  owner's ask is captured verbatim in
  [`agent-native-processes.md`](agent-native-processes.md) and the north-star in a
  new root `CLAUDE.md`, per the explicit request to "leave it somewhere that helps
  you understand what I'm asking".
- **Shipped P8 as v0.15.0.** Two new skills: `/flywheel:process` (define + mature a
  process contract, bootstrap `.claude/flywheel/DATA.md`) and `/flywheel:run`
  (execute as the runtime, persist idempotently + verified, cross-check with the
  `evaluator` when a metric is declared, append ≤1 evidence-based refinement).
  Decisions: two verbs not one; persistence follows the repo, never imposed;
  maturation evidence-gated; reuse the existing `evaluator` rather than add an
  agent. README / `/flywheel:help` / SessionStart banner synced; roadmap gains P8
  (first entry beyond P1–P7). docs-consistency + install-vendored + read-prime +
  `plugin validate` all green. First pillar-2 (runtime) release; branch
  `claude/plugin-agent-native-repo-gckln4`.

## Open threads

The discussion queue. Status: 🔵 open · 🟡 in progress · ✅ resolved.

| ID | Thread | Status | Where |
| --- | --- | --- | --- |
| T1 | Build vs integrate (Q3) | ✅ Option C accepted | [`strategy-build-vs-integrate.md`](strategy-build-vs-integrate.md) |
| T2 | Git-native memory design | ✅ design locked | [`git-native-memory-design.md`](git-native-memory-design.md) |
| T3 | P1 model routing | ✅ shipped v0.9.0 | [`improvement-proposals.md`](improvement-proposals.md#p1--model-routing-by-agent-role-) |
| T4 | P7 delegation triggers (adopt from gentle-ai) | 🔵 | [`improvement-proposals.md`](improvement-proposals.md#p7--delegation-triggers) |
| T5 | P4 evaluator — possibly redundant vs flywheel's metric-command check | ✅ reopened; shipped v0.14.0 as a re-execution cross-check | [`improvement-proposals.md`](improvement-proposals.md#p4--goal-based-evaluator-for-autoloop) |
| T6 | Opt-in interop with claude-mem / Engram | 🔵 | [`strategy-build-vs-integrate.md`](strategy-build-vs-integrate.md) |
| T7 | Async execution of P2–P7 via bounded briefs | ✅ all shipped (P1–P7) | [`briefs/README.md`](briefs/README.md) |
| T8 | Agent-native runtime pillar (`process` + `run`) | ✅ shipped v0.15.0 (P8) | [`agent-native-processes.md`](agent-native-processes.md) |

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
| [`improvement-proposals.md`](improvement-proposals.md) | Living backlog P1–P8 + decision log |
| [`agent-native-processes.md`](agent-native-processes.md) | P8 vision + design — flywheel's agent-native runtime pillar |
| [`strategy-build-vs-integrate.md`](strategy-build-vs-integrate.md) | The strategic memory analysis |
| [`git-native-memory-design.md`](git-native-memory-design.md) | Concrete git-native memory design spec (P2/P3) |
| [`briefs/`](briefs/README.md) | Async-ready task briefs (P2–P7) + how-to-run guide |
| [`journal.md`](journal.md) | This journal |
| [`sources.md`](sources.md) | All source URLs |
