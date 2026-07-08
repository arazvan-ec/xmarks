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
| P2 | Smarter learnings ledger (git-native memory) | ✅ shipped (v0.10.0) | Done — typed entries, budgeted injection, `/flywheel:recall` |
| P3 | Learnings-aware file-read priming hook | ✅ shipped (v0.11.0) | Done — advisory `PreToolUse` hook on `Read` |
| P4 | Goal-based evaluator for `autoloop` | ✅ shipped (v0.14.0) | Reopened — see decision log: the v0.12.0 rejection assessed a transcript-only evaluator; v0.14.0 ships a re-execution cross-check instead |
| P5 | Token-usage discipline | ✅ shipped (v0.12.0) | Done — autoloop + `/flywheel:help` carry the guidance |
| P6 | Time-based / proactive loop guidance | ✅ shipped (docs) | `docs/proactive-loops.md`; a runtime skill (e.g. `/flywheel:watch`) is still open |
| P7 | Delegation triggers (from gentle-ai) | ✅ shipped (v0.13.0) | Done — advisory thresholds in `/flywheel:work` |

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

**Open questions:**
- Does an evaluator that judges only from the transcript fit autoloop, whose stop
  condition is a **metric command's output** (the agent runs the command; the
  evaluator would judge the reported number)?
- Or is flywheel's existing deterministic metric-command check already stronger
  than `/goal`'s transcript-only evaluator, making this redundant?

**Decision (2026-07-08): deferred / decided against.**
`/goal`'s evaluator exists to compensate for having *no* deterministic check —
it can only judge from the transcript. Autoloop already forces the actual
metric command to run and its output to be recorded every iteration; a
read-only evaluator judging that same transcript can't verify anything the
metric command hasn't already proven, so it adds process without adding
rigor. Revisit only if a concrete failure mode shows up in practice (e.g. the
working agent fabricating a metric result instead of running the command).

**Decision (2026-07-08, superseded above): reopened, shipped v0.14.0.**
The v0.12.0 rejection is correct about the mechanism it evaluated — a
transcript-only judge, like `/goal`'s, genuinely adds nothing on top of a
metric command autoloop already runs. But that isn't the only way to build an
evaluator, and the rejection named its own revisit trigger explicitly: "the
working agent fabricating a metric result instead of running the command."
That's exactly the failure mode a **different** mechanism closes — one that
doesn't read the transcript at all, but **independently re-executes the
metric command itself** and compares its own reading against what was
claimed. This isn't asking the same question twice; it's checking whether the
one deterministic signal autoloop relies on was actually produced honestly.
Built as `agents/evaluator.md` (`model: haiku`, read-only tools besides the
re-run), consulted by `skills/autoloop/SKILL.md` before an ambiguous
keep/discard or a stop decision. Cheap (Haiku) and additive to the existing
budget — it doesn't replace the metric-command check, it independently
re-verifies it.

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

**Decision (2026-07-08): shipped as v0.12.0**, standalone (P4 was decided
against, so nothing to fold into). `skills/autoloop/SKILL.md` gained a "Token
discipline" section (hard budget stop, pilot-before-scaling, `/usage`
pointer, when to prefer `/goal`/`/loop`/workflows); `skills/help/SKILL.md`
and `README.md` got matching pointers. Version bumped twice at merge time —
0.10.0 → 0.11.0 → 0.12.0 — because P2 then P3 (this repo's other in-flight
briefs) each merged first and claimed the number this brief had picked.

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
- **2026-07-08** — **Shipped P2 (git-native memory, first release) as v0.10.0**,
  from the async brief in `briefs/P2-git-native-memory.md`. Typed ledger entries
  in `/flywheel:compound`, relevance-scored budgeted injection in
  `scripts/session-start.sh` (branch/files/recency, default top 12), and a new
  `/flywheel:recall <query>` skill for on-demand lookup. Backward-compatible
  with old free-prose entries; no index/staging/interop yet (deferred per the
  locked design). Added `upgrades/v0.10.0.md`; documented in README +
  `/flywheel:help`. P3 (read-priming hook) can now build on P2's `files=`
  metadata.
- **2026-07-08** — **Shipped P3 (read-priming hook) as v0.11.0**, from the
  async brief in `briefs/P3-read-priming-hook.md`, on top of the P2 release
  that landed in `main`. New `scripts/read-prime.sh`, wired as a
  `PreToolUse`/`Read` hook: greps the ledger's `files=` metadata for the file
  about to be read and prints a short note on a match — advisory only, never
  blocks the read; fails open (no ledger, no match, malformed hook input, or
  no `python3`) with no output. `install-vendored.sh` now vendors the script
  and merges the `PreToolUse` hook into target `settings.json`; `--uninstall`
  reverses it. Added `scripts/test-read-prime.sh` (wired into CI). All checks
  green. **The full P2 → P3 git-native memory sequence is now shipped.**
- **2026-07-08** — **Resolved T5 and shipped P5 as v0.12.0.** Per the P4 brief's
  own decision framework: assessed P4's evaluator against autoloop's existing
  deterministic metric-command check and decided it's **redundant** (a
  transcript-only evaluator can't verify anything the metric command's actual
  output hasn't already proven) — P4 marked ⚪ deferred, decided against. Built
  **P5 (token-usage discipline)** standalone: `skills/autoloop/SKILL.md` gained
  a "Token discipline" section (hard budget stop, pilot-before-scaling, `/usage`
  pointer, `/goal`/`/loop`/workflow guidance); `skills/help/SKILL.md` and
  `README.md` got matching pointers. Rebased its version twice at merge time
  (the exact scenario `briefs/README.md` warned about): P2 then P3 each merged
  into `main` first and claimed 0.10.0 then 0.11.0, so P5 lands as **v0.12.0**.
  docs-consistency + install-vendored + `plugin validate --strict` all green.
- **2026-07-08** — **Reopened P4 and shipped it as v0.14.0.** A second,
  independent session had reached a different conclusion on the same open
  question and built an evaluator before the P5 session's rejection merged;
  its PR lost the merge race and was closed as a duplicate. On review, the
  v0.12.0 decision is right about a **transcript-only** evaluator (redundant,
  as reasoned) but doesn't rule out every evaluator design — and it names its
  own revisit trigger ("the working agent fabricating a metric result instead
  of running the command"). Built exactly that check instead of a transcript
  judge: `agents/evaluator.md` (`model: haiku`) **independently re-executes
  the metric command** rather than reading what the working agent reported,
  closing the self-grading-bias gap without re-litigating the parts of the
  v0.12.0 reasoning that hold up. `skills/autoloop/SKILL.md` consults it
  before an ambiguous keep/discard or a stop decision; README + `/flywheel:help`
  document the new agent. Version bumped twice at merge time (the exact
  scenario `briefs/README.md` warned about): first to v0.13.0 (main had moved
  to v0.12.0 since the closed PR), then to **v0.14.0** when P7 independently
  claimed v0.13.0 first. docs-consistency + install-vendored +
  `plugin validate --strict` all green.
