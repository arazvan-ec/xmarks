# flywheel improvement proposals — living backlog

Synthesized from [`claude-code-loops.md`](claude-code-loops.md) (official loop
primitives) and [`claude-mem.md`](claude-mem.md) / [`token-efficiency.md`](token-efficiency.md)
(memory + token efficiency). This is a **living document**: we discuss and refine
it here, record decisions in the [Decision log](#decision-log), and only then
implement. Each proposal names the flywheel files it touches and whether it bumps
the plugin version (any change to `skills/`, `agents/`, `hooks/`, or `scripts/`
requires a `plugin.json` bump **and** a matching `upgrades/vX.Y.Z.md` note —
enforced by `scripts/test-docs-consistency.sh`).

> **Strategic context:** whether P2/P3 (memory) should be *built*, *integrated*,
> or *differentiated* is analyzed in [`strategy-build-vs-integrate.md`](strategy-build-vs-integrate.md)
> — current lean: a **git-native, curated** memory that borrows selectivity from
> claude-mem / gentle-ai without their infrastructure.

## Status

Legend: 🔵 proposed · 🟡 discussing · 🟢 approved to build · ✅ done · ⚪ deferred

| # | Proposal | Status | Next action |
| --- | --- | --- | --- |
| P1 | Model routing by agent role | ✅ shipped (v0.9.0) | Done — verifier→haiku, reviewers→sonnet |
| P2 | Smarter learnings ledger (git-native memory) | 🟢 design locked | Build the small first release: typed format + injection + `/recall` |
| P3 | Learnings-aware file-read priming hook | 🟢 design locked | Build after P2 (needs typed `files=` metadata) |
| P4 | Goal-based evaluator for `autoloop` | ✅ shipped (v0.10.0) | Done — `evaluator` agent (Haiku) re-runs the metric command as a cross-check |
| P5 | Token-usage discipline | ✅ shipped (v0.10.0) | Done — folded into the P4 release |
| P6 | Time-based / proactive loop guidance | ⚪ deferred | Start as a doc later |
| P7 | Delegation triggers (from gentle-ai) | 🔵 proposed | Discuss thresholds; where they live |

## Priority overview

| # | Proposal | Value | Effort | Risk | Version bump? |
| --- | --- | --- | --- | --- | --- |
| **P1** | **Model routing by agent role** ⭐ recommended first | High | Low | Low | Yes |
| P2 | Smarter learnings ledger (typed entries + capped/relevant injection) | High | Medium | Low | Yes |
| P3 | Learnings-aware file-read priming hook | High | Medium | Medium | Yes |
| P4 | Goal-based evaluator for `autoloop` | Medium | Medium | Medium | Yes |
| P5 | Token-usage discipline in autoloop + help | Medium | Low | Low | Yes |
| P6 | Time-based / proactive loop guidance (routines) | Medium | Large | Medium | Yes (+docs) |
| P7 | Delegation triggers (when to spin up a fresh-context subagent) | Medium | Low | Low | Yes |

---

## P1 — Model routing by agent role ⭐

**Why.** The loops article prescribes routing routine/mechanical work to cheaper,
faster models and reserving the most capable model for judgment calls; claude-mem
does exactly this (Haiku for compression). flywheel pins **all four agents to
`model: sonnet`** — no distinction between the mechanical `verifier` (run tests,
report) and the judgment-heavy `reviewer-*` agents. The subagent `model:` field
and resolution order are confirmed in the docs.

**What.** Set a deliberate model per role:
- `agents/verifier.md` → **`haiku`** (mechanical: runs commands, reports evidence).
- `agents/reviewer-correctness.md`, `reviewer-security.md`, `reviewer-performance.md`
  → keep **`sonnet`** (or offer **`opus`** for the hardest judgment); document the
  rationale so it's a deliberate choice, not a default.
- Optionally note the `CLAUDE_CODE_SUBAGENT_MODEL` override.

**Files:** the 4 `agents/*.md`; a short "model routing" note in `skills/help/SKILL.md`
and the README; `plugin.json` version bump + `upgrades/vX.Y.Z.md`.

**Decisions (shipped v0.9.0):**
- **verifier → `haiku`** (mechanical run-and-report). Caveat documented: if a
  rationalized false-green ever appears, raise it to `sonnet` (one-line change).
  Behavioral pilot happens in real use — model routing is enforced by Claude
  Code's runtime, not by a shell test.
- **reviewers → `sonnet`** (judgment). `opus` left as an opt-in for high-stakes
  reviews.
- **No new config surface** — override via each agent's `model:` frontmatter or
  the upstream `CLAUDE_CODE_SUBAGENT_MODEL` env var.

---

## P2 — Smarter learnings ledger

**Why.** flywheel's SessionStart hook reloads `LEARNINGS.md` (capped at ~50 lines
today) with no relevance filtering; claude-mem shows that **selective, typed,
progressively-disclosed** memory is far more token-efficient than a whole-file
reload that grows into a fixed per-session tax.

**What (keep markdown as source of truth):**
- **Typed entries** — lightweight metadata per `/flywheel:compound` entry (type:
  bugfix/decision/gotcha/pattern; files; date; spec/PR link).
- **Relevant injection** — `scripts/session-start.sh` injects the N entries most
  relevant to the current branch/spec (match by files/branch), not just the last
  50 lines.
- **`/flywheel:recall <query>`** — a new skill for on-demand progressive
  disclosure: list matching titles cheaply, expand detail on request.

**Files:** `skills/compound/SKILL.md`, `scripts/session-start.sh`, new
`skills/recall/` (+ README/help entry — required by the docs-consistency test),
`plugin.json` + `upgrades/`.

**Open questions:**
- Pure-markdown + grep index, or a small SQLite/FTS5 sidecar (heavier, but the
  claude-mem model)? Trade-off: portability/git-diffability vs power.
- Is relevance-by-branch/files enough, or do we need semantic matching?
- Ship the `/recall` command and injection together, or injection first?

---

## P3 — Learnings-aware file-read priming hook

**Why.** claude-mem's File Read Gate saves ~95% per file by surfacing prior
observations before a raw read. flywheel has no equivalent; its learnings sit
unused until a session reload.

**What.** A **PreToolUse** hook that, when Claude is about to read a file for
which the ledger has entries, first injects those entries as cheap context. Keep
it **advisory** (never block the read) to stay low-risk, unlike claude-mem's
blocking gate.

**Files:** `hooks/hooks.json` (+ a new `scripts/read-prime.sh`), the vendoring
installer (`scripts/install-vendored.sh`) must vendor the new hook script,
`plugin.json` + `upgrades/`. Note: `test-install-vendored.sh` asserts hook scripts
are vendored — update it too.

**Open questions:**
- Depends on P2's typed/indexed ledger to be useful — sequence P2 → P3?
- Advisory-only (inject a note) vs a size threshold like claude-mem's 1,500 bytes?
- Performance: a PreToolUse hook fires on every read — keep it fast/fail-open.

---

## P4 — Goal-based evaluator for `autoloop`

**Why.** `/goal` enforces its stop condition with a **separate cheap evaluator
model** (Haiku) that judges from the transcript after every turn. flywheel's
`autoloop` has a metric + budget but the **same agent judges its own score** — no
independent evaluator. Adding one mirrors the official mechanism and reduces
premature/over-optimistic stops.

**What.** An `evaluator` agent (`model: haiku`) that checks the autoloop
metric/stop condition and returns continue/stop + reason; rewrite the autoloop
body to consult it. Bound by the existing max-iterations budget.

**Files:** new `agents/evaluator.md`, `skills/autoloop/SKILL.md`, README/help,
`plugin.json` + `upgrades/`.

**Open questions (resolved — see Decision log):**
- Does an evaluator that judges only from the transcript fit autoloop, whose stop
  condition is a **metric command's output** (the agent runs the command; the
  evaluator would judge the reported number)?
- Or is flywheel's existing deterministic metric-command check already stronger
  than `/goal`'s transcript-only evaluator, making this redundant?

**Decision (shipped v0.10.0):** not redundant — built as a **cross-check**, not
a `/goal`-style transcript judge. `/goal`'s evaluator is weaker than autoloop's
metric-command check (it never runs anything, only reads the transcript), but
the real gap it exposed is different: in autoloop, the **same agent that made
the change also grades it**, which is exactly the setup self-grading bias lives
in. So `agents/evaluator.md` (`model: haiku`, read-only tools) **re-runs the
metric command itself** rather than trusting the working agent's self-report,
and autoloop consults it before keeping/discarding an ambiguous iteration or
declaring the target met. Cheap (Haiku) and additive to the existing budget —
it doesn't replace the metric-command check, it independently re-verifies it.

---

## P5 — Token-usage discipline

**Why.** The article's whole "managing token usage" section maps cleanly onto
flywheel's autonomous `autoloop`.

**What.** Add explicit guidance: reference `/usage`, `/goal` status, and
`/workflows` for visibility; add pilot-before-scaling and interval-matching
advice; make the autoloop budget/stop-criteria discipline explicit.

**Files:** `skills/autoloop/SKILL.md`, `skills/help/SKILL.md`, README,
`plugin.json` + `upgrades/`.

**Open questions (resolved):**
- Fold into P4 (both touch autoloop) as one release, or keep separate?

**Decision (shipped v0.10.0):** folded into the P4 release, as suggested — both
touch `skills/autoloop/SKILL.md` and one version bump covers both cleanly.

---

## P6 — Time-based / proactive loop guidance

**Why.** flywheel covers only turn-based loops; time-based (`/loop`, routines) and
proactive (event/schedule, no human) are absent.

**What (start as docs, not new runtime):** a `docs/` guide on composing
`/schedule` routines + `/goal` + flywheel's verify/review with `/loop` for PR
babysitting; optionally a thin `/flywheel:watch` skill later. Respect the caps
(routines 1-hour min; `/loop` 50 tasks / 7-day expiry).

**Files:** new `docs/` page (no version bump if docs-only); a runtime skill would
bump the version + upgrade note.

**Open questions:**
- Is guidance/docs enough, or do users want a flywheel-branded skill wrapper?

---

## P7 — Delegation triggers

**Why.** gentle-ai defines concrete thresholds for *when* to delegate to a
fresh-context subagent ("4-file rule"; "2+ non-trivial files → fresh review";
"~20 tool calls or ~5 reads → pause and re-plan"). flywheel tells agents to use
subagents but gives no heuristics for *when* — so context bloats before anyone
delegates. These are cheap, high-value guardrails.

**What.** Encode the thresholds into `skills/work/SKILL.md` (surfaced in
`skills/help`): when a task crosses a read/write/tool-call threshold, delegate
exploration or trigger a fresh review before advancing. Aligns with flywheel's
existing fresh-context reviewers.

**Files:** `skills/work/SKILL.md`, `skills/help/SKILL.md`, README, `plugin.json`
+ `upgrades/`.

**Open questions:**
- Adopt gentle-ai's exact numbers, or tune them to flywheel's phases?
- Advisory guidance vs a hard rule enforced by a hook?
- Cheap enough to ride along with P1 or P5 in one release.

---

## Suggested sequencing

1. **P1** (clean, self-contained win; validates the release flow end-to-end).
2. **P2** then **P3** (the ledger/token-efficiency theme, biggest long-term payoff).
3. **P4 / P5** (loop rigor + token discipline).
4. **P6** (largest new surface; start as a doc).

Each build step is one release: code change → `plugin.json` bump →
`upgrades/vX.Y.Z.md` → README/help sync → `scripts/test-docs-consistency.sh` +
`scripts/test-install-vendored.sh` green → `claude plugin validate . --strict`.

**Async execution:** each remaining proposal has a self-contained kickoff in
[`briefs/`](briefs/README.md) so it can be built in its own fresh, bounded session
(with a copy-paste starter prompt + collision-avoidance guidance).

---

## Decision log

Append-only. Newest at the bottom.

- **2026-07-08** — Research corpus gathered and saved (`docs/research/`). Roadmap
  P1–P6 drafted. Decision: **hold on implementation**; keep the proposals in the
  repo as a living backlog and continue the discussion before building. No plugin
  code changed yet; all work so far is docs-only (no version bump).
- **2026-07-08** — Reviewed **gentle-ai**. Added **P7 (delegation triggers)** and
  made the landscape comparison 3-way. Opened the **build-vs-integrate** strategy
  ([`strategy-build-vs-integrate.md`](strategy-build-vs-integrate.md)); current
  lean is **git-native curated memory** (Option C). Started the
  [design journal](journal.md) to track threads. Still docs-only; no decision to
  build yet.
- **2026-07-08** — Wrote the concrete **git-native memory design spec**
  ([`git-native-memory-design.md`](git-native-memory-design.md)) for P2/P3 —
  typed entries, budgeted SessionStart injection, `/flywheel:recall`, advisory
  read-priming hook, rotation, opt-in interop. Design draft; awaiting go/no-go.
- **2026-07-08** — **Design locked & accepted.** Q3 closed as Option C
  (git-native curated memory). Four decisions fixed: grep-live (no index yet);
  defer semi-auto staging; defer interop; branch/files/recency scoring for v1.
  P2/P3 move to 🟢 design locked. Feature saved; implementation still pending.
- **2026-07-08** — **Shipped P1 (model routing) as v0.9.0** — first real plugin
  code change. `verifier` → haiku (mechanical); reviewers stay sonnet (judgment),
  opus opt-in. Added `upgrades/v0.9.0.md`; documented in README + `/flywheel:help`.
  docs-consistency + install-vendored + `plugin validate --strict` all green.
- **2026-07-08** — **Shipped P4 + P5 as v0.10.0** (brief:
  [`briefs/P4-goal-evaluator.md`](briefs/P4-goal-evaluator.md)). T5 resolved:
  the evaluator is **not redundant** with autoloop's metric-command check — the
  gap it closes is self-grading bias (the same agent that makes the change also
  judges it), not evaluator quality. Built `agents/evaluator.md` (`model: haiku`)
  as a **cross-check** that independently re-runs the metric command, consulted
  by `skills/autoloop/SKILL.md` before keeping/discarding an ambiguous iteration
  or declaring the target met. P5's token-discipline guidance (pilot-before-
  scaling, interval-matching, explicit stall criteria, `/usage`/`/goal`/
  `/workflows` for visibility) folded into the same release. Added
  `upgrades/v0.10.0.md`; documented in README + `/flywheel:help`.
  docs-consistency + install-vendored + `plugin validate --strict` all green.
