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
| P2 | Smarter learnings ledger (git-native memory) | ✅ shipped (v0.10.0) | Done — typed entries + relevance injection + `/flywheel:recall` |
| P3 | Learnings-aware file-read priming hook | 🟢 design locked | Build now — P2's typed `files=` metadata is available |
| P4 | Goal-based evaluator for `autoloop` | 🔵 proposed | Discuss whether it supersedes self-judging |
| P5 | Token-usage discipline | 🔵 proposed | Could fold into P4 |
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

## P2 — Smarter learnings ledger ✅ shipped (v0.10.0)

**Why.** flywheel's SessionStart hook reloads `LEARNINGS.md` (capped at ~50 lines
today) with no relevance filtering; claude-mem shows that **selective, typed,
progressively-disclosed** memory is far more token-efficient than a whole-file
reload that grows into a fixed per-session tax.

**What shipped (keeps markdown as source of truth, no DB):**
- **Typed entries** — `/flywheel:compound` writes `## <type>: <title>` +
  `<!-- fw: type=…; date=…; files=…; spec=…; pr=…; branch=… -->` + prose, one
  entry per learning. Old free-prose entries still load (always-eligible,
  low-priority).
- **Relevant injection** — `scripts/session-start.sh` scores every entry
  (`+3` files overlap, `+2` branch/spec match, `+1` recency ≤30d) and injects
  the top `FLYWHEEL_LEARNINGS_INJECT` (default 12) full entries + a one-line
  pointer for the rest, instead of the first ~50 lines.
- **`/flywheel:recall <query>`** — new skill for on-demand progressive
  disclosure: list matching titles cheaply, expand one entry on request.

**Files changed:** `skills/compound/SKILL.md`, `scripts/session-start.sh`, new
`skills/recall/SKILL.md` (+ README/help entries), `plugin.json` +
`upgrades/v0.10.0.md`.

**Deferred (per the locked design):** a `.tsv` metadata index, semi-auto
Stop-hook staging, claude-mem/Engram interop — no measured need yet.

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

**Open questions:**
- Does an evaluator that judges only from the transcript fit autoloop, whose stop
  condition is a **metric command's output** (the agent runs the command; the
  evaluator would judge the reported number)?
- Or is flywheel's existing deterministic metric-command check already stronger
  than `/goal`'s transcript-only evaluator, making this redundant?

---

## P5 — Token-usage discipline

**Why.** The article's whole "managing token usage" section maps cleanly onto
flywheel's autonomous `autoloop`.

**What.** Add explicit guidance: reference `/usage`, `/goal` status, and
`/workflows` for visibility; add pilot-before-scaling and interval-matching
advice; make the autoloop budget/stop-criteria discipline explicit.

**Files:** `skills/autoloop/SKILL.md`, `skills/help/SKILL.md`, README,
`plugin.json` + `upgrades/`.

**Open questions:**
- Fold into P4 (both touch autoloop) as one release, or keep separate?

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
