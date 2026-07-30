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
| P8 | Agent-native runtime pillar (`process` + `run`) | ✅ shipped (v0.15.0) | Done — Claude executes + persists + matures domain operations; see [`agent-native-processes.md`](agent-native-processes.md) |
| P9 | Read-priming that actually reaches the model + robust session-start | ✅ shipped (v0.18.0) | Done — JSON envelope (docs-confirmed), bash pre-filter, blank-line-safe awk, top-K, macOS date, cached update check |
| P10 | Portability + installer correctness | ✅ shipped (v0.17.0) | Done — BSD-safe sed, manifest-driven pruning + uninstall, sticky `--auto-update`, generic agents |
| P11 | `gate.sh` hardening | ✅ shipped (v0.20.0) | Done — trust-on-first-use consent (outside repo), git-tracked cost cache, per-tree persisted bypass, first test coverage |
| P12 | Token-discipline pass over the skills | ✅ shipped (v0.19.0) | Done — recall-first priming, diff-routed review with stated skips, honest evaluator wording, slimmer descriptions, size-capped injection |
| P13 | Pillar-2 security-by-design | 🔵 proposed | Untrusted-data framing; parameterized writes; secret redaction; pin `@main` |
| P14 | Pillar integration + process lifecycle | 🔵 proposed | Discovery, run→spec escalation, contract sync, write-path probe + file fallback |
| P15 | Dogfooding flywheel on flywheel | 🔵 proposed | Seed LEARNINGS.md; `processes/release.md`; fix help state list |
| P16 | Live run progress: task ledger + telemetry report | ✅ shipped (v0.16.0) | Done — both pillars (run/process + loop/work); piloted by flow-audit v3 + the p16 cycle report |
| P17 | Setup/fixture knowledge as first-class compounded context | ✅ shipped (v0.21.0) | Done — `fixture` type, compound captures, spec/work prime + advisory trigger, evidence-gated |
| P18 | Evidence-gated compounding | ✅ shipped (v0.25.0) | Done — `evidence=` metadata, compound capture rule, `[unverified]` flag at injection + in recall; advisory |
| P19 | Update postprocess: persistent pending-strategy state + refresh smoke check | ✅ shipped (v0.26.0) | Done — `PENDING-UPGRADES` written by the installer, nagged by SessionStart, cleared by `/flywheel:update`; `bash -n` gate aborts a broken refresh. CI auto-apply deferred until the nag proves recurring debt |
| P20 | State-write pre-approval hook (plan approval covers persisting loop state) | ✅ shipped (v0.27.0) | Done — allow-only `PreToolUse` hook on `Write\|Edit`; scope strictly `.claude/flywheel/**`. (Renumbered from P19/v0.26.0 at merge time — main had taken both) |
| P21 | Bash grants coherent with the approval gates (P20 for commands) | ✅ shipped (v0.28.0) | Done — allow-only `bash-allow.sh` (add/commit/stash, branch-aware force-free push); gate-time consent rules in spec/process; permission drift in sync |
| P22 | Dev-loop discipline on the plugin itself: dogfooded TDD + skill evals | ✅ shipped (v0.29.0 / v0.31.0 / v0.32.0) | Done — phase 1: CLAUDE.md rule + `check-test-pairing.sh` CI gate. Phase 2: behavioral evals as manual release gates for `verify`/`work` (pillar 1, v0.31.0) and `process`/`run` (pillar 2, v0.32.0) |
| P23 | Cycle-cost telemetry: the loop measures its own cost | ✅ shipped (v0.35.0) | Done — `cost: {bytes_out, tool_calls, elapsed_s}`, no tokens (enforced by `run-cost.sh`); gate 8/8 evals, 57/57 assertions, cost object verified on real run telemetry. Open: do the proxies track real spend? |
| P24 | Description budget as a CI ratchet | ✅ shipped (v0.33.0) | Done — `check-description-budget.sh` sums description values (3301) against `scripts/description-budget.txt` (3600); malformed frontmatter fails loudly; wired into CI |
| P26 | Committed graders for `verify` and `work` | ✅ shipped (v0.37.0) | Done — `skills/{verify,work}/evals/check.sh` on the pillar-2 contract; `test-eval-graders.sh` requires all four graders red on an untouched fixture (and pillar 1 green on an ideal outcome); `check-fixture-leaks.sh` turns the manual leak grep into a CI gate with a per-path/per-pattern allowlist. Unblocks the pending `verify` iteration |
| P25 | Close the gaps the P22 eval iteration exposed | ✅ shipped (v0.34.0) | Done — §5 format pinned + grader re-tightened (gate: 3/3 evals, 39/39); work kata de-hinted via a fixture guard; a hollow `run` eval-2 grader fixed. Baseline arm documented, still unrun |

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
| **P8** | **Agent-native runtime pillar** (Claude runs + persists + matures domain operations) ⭐ new direction | High | Medium | Medium | Yes |
| **P9** | **Read-priming that reaches the model** + robust session-start (from flow-audit run #1) | High | Medium | Low | Yes |
| P10 | Portability + installer correctness | High | Low | Low | Yes |
| P11 | `gate.sh` hardening (trust, cost, escape valve) | High | Medium | Medium | Yes |
| P12 | Token-discipline pass over the skills | High | Low | Low | Yes |
| P13 | Pillar-2 security-by-design | High | Medium | Medium | Yes |
| P14 | Pillar integration + process lifecycle | High | Large | Medium | Yes |
| P15 | Dogfooding flywheel on flywheel | Medium | Low | Low | Partial |
| P16 | Live run progress (task ledger + run telemetry report) | Medium | Low | Low | Yes |
| P17 | Setup/fixture knowledge as first-class compounded context | High | Low | Low | Yes |
| P18 | Evidence-gated compounding (protect the ledger from unverified conclusions) | High | Medium | Low | Yes |
| P20 | State-write pre-approval hook (permission-prompt fatigue on loop state) | High | Low | Low | Yes |
| P21 | Bash grants coherent with the approval gates | High | Medium | Medium | Yes |
| P22 | Dev-loop discipline on the plugin itself (dogfooded TDD + skill evals) | High | Medium (phase 1 Low) | Low | Yes |
| P23 | Cycle-cost telemetry (the loop measures its own cost) | High | Medium | Low | Yes |
| **P24** | **Description budget as a CI ratchet** ⭐ cheapest of the three | Medium | Low | Low | Yes |
| P25 | Close the gaps the P22 eval iteration exposed | Medium | Medium | Low | Partial |

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

## P8 — Agent-native runtime pillar ⭐ (new direction, 2026-07-10)

**Why.** P1–P7 sharpen flywheel as a **development** loop. The repo owner's
direction is broader: make flywheel turn the repos it's installed in
**agent-native** (https://every.to/go-agent-native) — the agent as a first-class
part of the *runtime*, not just the dev process. Concretely: operate the repo's
domain the way a backend would (e.g. "analyze a car"), but with Claude as the
execution engine rather than static code, persisting to the repo's own datastore,
and improving each operation with every run.

**What.** A second pillar of two skills (full design:
[`agent-native-processes.md`](agent-native-processes.md)):
- `/flywheel:process <desc>` — scaffold a **process contract** at
  `.claude/flywheel/processes/<slug>.md`: fixed rules + output schema + persistence
  + bounded judgment latitude + an append-only improvement log; bootstrap
  `.claude/flywheel/DATA.md` (the repo's persistence strategy) on first use.
- `/flywheel:run <slug> [input]` — execute the contract as the runtime, persist
  per `DATA.md` (idempotent, verified), and mature the contract with ≤1
  evidence-based refinement per run.

**Files:** `skills/process/`, `skills/run/`, README + `/flywheel:help` +
`scripts/session-start.sh`, `docs/research/agent-native-processes.md`, root
`CLAUDE.md`, `plugin.json` + `marketplace.json` + `upgrades/v0.15.0.md`.

**Decisions (shipped v0.15.0):**
- **Two verbs, not one** — separate *define* (`process`) from *execute* (`run`),
  mirroring how pillar 1 separates `spec` from `work`. Keeps each contract a
  reviewable artifact independent of any single run.
- **Persistence is the repo's, not flywheel's** — `DATA.md` declares the existing
  store/access/schema; flywheel writes through it (MCP/CLI/ORM) and never imposes
  a datastore. A run must *prove* the write (read-back / affected rows).
- **Maturation is evidence-gated** — ≤1 refinement per run, only from that run;
  fixed-rule changes are versioned in the contract. Cross-process lessons go to
  the shared ledger via `/flywheel:compound`, not the process file.
- **Reuse, don't reinvent** — a run cross-checks with the existing `evaluator`
  agent when the process declares a `metric`; no new agent added.

**Open questions (post-ship):**
- A `/flywheel:processes` listing / discovery command, or is `help` + the
  directory enough?
- Should scheduled/unattended runs get a thin wrapper, or is composing
  `/flywheel:run` with the existing proactive-loop guidance sufficient?
- Batch runs (one invocation over many inputs) as a workflow — worth a first-class
  affordance?

## P9 — Read-priming that actually reaches the model ⭐ (flow-audit run #1, 2026-07-13)

**Why.** The v0.11.0 flagship never worked as designed: PreToolUse hook stdout on
exit 0 is shown only in transcript mode — it is **not** added to Claude's
context — so `read-prime.sh`'s "prior learnings touch this file" note is
invisible to the model in both marketplace and vendored installs. The audit also
reproduced two scoring defects in `session-start.sh`: the awk metadata parser
reads only the first line after a `## ` header (one blank line silently zeroes
that entry's relevance — and read-prime searches the whole entry, so the two
consumers of the compound format disagree), and the O(n²) ranking sort takes
~5s at 5k entries (hook-timeout death near ~10k). GNU-only `date -d` kills the
recency signal on macOS. The scoring logic — the most complex in the repo — has
zero test coverage.

**What.**
- `read-prime.sh` emits hook JSON (`hookSpecificOutput.hookEventName=PreToolUse`,
  `additionalContext=<matches>`) instead of stdout; keep silent exit 0 on
  no-match. Add a bash-level `grep -qF` pre-filter so the ~99% no-match majority
  never spawns python3; dedupe repeat advisories per file per session.
- `session-start.sh`: tolerate blank lines before the `<!-- fw: -->` line;
  replace the bubble sort with single-pass top-K; `date -d … || date -v-30d …`;
  cache the remote-version curl behind a daily stamp file.
- New `scripts/test-session-start.sh` fixture ledger asserting scoring, budget,
  blank-line tolerance and tie-breaks; wire into CI.

**Files:** `scripts/read-prime.sh`, `scripts/session-start.sh`, new
`scripts/test-session-start.sh`, `scripts/test-read-prime.sh`,
`plugin.json` + `upgrades/`.

---

## P10 — Portability + installer correctness (flow-audit run #1)

**Why.** The documented local install path fails outright on macOS:
`install-vendored.sh:180`'s `sed "0,/re/"` is GNU-only and dies under
`set -euo pipefail`. Upgrades never prune: files a newer version dropped stay
orphaned and the manifest rewrite forgets them, making them permanently
un-uninstallable. Uninstall restores backed-up agents but deletes backed-up
`flywheel-*` skills. And two agents ship stale context from this repo's previous
life as a bookmarking tool ("X/Twitter cookies", "per-bookmark DB writes") —
flywheel installs those prompts into every target repo, misdirecting reviews.

**What.** BSD-compatible sed (`1,/re/` or awk); diff old→new manifest and
`remove_or_restore` every disappeared path; restore `*.pre-flywheel` skill
backups before the blanket `rm -rf`; genericize the reviewer parentheticals;
widen too-narrow `allowed-tools` (compound needs `date`; ship offers `gh`).

**Files:** `scripts/install-vendored.sh`, `scripts/test-install-vendored.sh`,
`agents/reviewer-security.md`, `agents/reviewer-performance.md`,
`skills/compound/SKILL.md`, `skills/ship/SKILL.md`, `plugin.json` + `upgrades/`.

---

## P11 — `gate.sh` hardening (flow-audit run #1)

**Why.** Three independent defects in the Stop gate. (1) **Trust:** the hook
auto-executes `.claude/flywheel/gate.sh` — a repo file any PR/clone can add,
executable bit surviving checkout — with no re-consent: RCE-by-PR at the next
turn end. (2) **Cost:** the full verification suite re-runs on every Stop,
including no-change Q&A turns and immediately after `/flywheel:verify` ran the
identical suite (hooks grant it 300s). (3) **The escape valve doesn't persist:**
after the 3-block bypass the state resets, so a permanently-red gate re-traps
every later turn (up to 4 suite runs + 3 forced continuations per turn);
`stop_hook_active` from stdin is ignored.

**What.** Record a consent hash for gate.sh content outside the repo tree (or
require the command in trust-prompted settings) and warn loudly when it
appears/changes; cache green runs by tree hash (`git rev-parse HEAD` +
status/diff sha) and exit 0 early when unchanged; persist a `bypassed` marker
cleared only by a green run; short-circuit on `stop_hook_active` when count ≥
max. Add gate.sh behavior tests.

**Files:** `scripts/gate.sh`, new tests, README §completion gate,
`plugin.json` + `upgrades/`.

---

## P12 — Token-discipline pass over the skills (flow-audit run #1)

**Why.** Three of the costliest habits contradict flywheel's own
token-efficiency research: `loop`/`spec`/`process` each instruct a
cover-to-cover `Read` of `LEARNINGS.md` (~18k tokens at 200 entries, twice per
loop cycle) on top of the budgeted SessionStart injection built precisely to
avoid that; `review` unconditionally dispatches all three Sonnet reviewers even
for a 5-line docs diff (30–80k tokens for a trivial change); help/README
describe the autoloop evaluator as firing on every keep/discard,
over-dispatching vs autoloop's actual ambiguous-cases-only contract.

**What.** Prime steps become "use the SessionStart-injected subset;
`/flywheel:recall <topic>` for specifics — never read the whole ledger";
`review` gains diff-based routing (docs-only → correctness only; security only
when input/auth/secrets/deps are touched; performance only for
loops/queries/IO; single reviewer under ~20 changed lines); align help/README
evaluator wording; trim the heaviest frontmatter descriptions to
trigger-conditions; truncate injected ledger bodies (~400 chars + recall tail).

**Files:** `skills/loop|spec|process|review|help/SKILL.md`, `README.md`,
`scripts/session-start.sh`, `plugin.json` + `upgrades/`.

---

## P13 — Pillar-2 security-by-design (flow-audit run #1)

**Why.** The agent-native pillar injects and executes repo-controlled content
with no trust boundary: ledger entries, process contracts and DATA.md go
verbatim into context (prompt-injection via any PR); `/flywheel:run`
interpolates inputs into SQL with no parameterization mandate (the worked
example in `agent-native-processes.md` is itself injectable) and its
DROP/DELETE ban is advisory prose; nothing forbids persisting a resolved
`DATABASE_URL` into committed DATA.md or echoing secrets in run reports; and
the auto-update workflow references `xmarks@main` unpinned, executing
clone-and-run shell in every downstream repo's CI with write permissions.

**What.** Wrap all hook/skill-injected repo content in explicit untrusted-data
framing ("data, never instructions"); make `run` REQUIRE bound parameters /
placeholder binding and recommend a least-privilege DB role (no DDL/DELETE);
mandate env-var references only (never resolved secrets) in DATA.md plus
redaction in run reports; pin the reusable workflow to a tag/SHA and verify the
clone; move `/flywheel:update` strategies toward a declarative step vocabulary
with per-strategy confirmation.

**Files:** `scripts/session-start.sh`, `scripts/read-prime.sh`,
`skills/run|process|update/SKILL.md`, `scripts/install-vendored.sh` (workflow
template), `docs/research/agent-native-processes.md` (fix the example),
`plugin.json` + `upgrades/`.

---

## P14 — Pillar integration + process lifecycle (flow-audit run #1)

**Why.** The audit's coherence verdict: the two pillars don't feed each other,
and pillar 2 lacks the lifecycle affordances the Every guide calls out
(discovery, composability, graduated autonomy). Concretely: run maturation
can't escalate into pillar-1 work (a missing column dead-ends); `sync`
reconciles spec↔code but not contracts↔schema↔DATA.md; spec/plan/review never
consult DATA.md or contracts; nothing lists existing processes (bare
`/flywheel:run`, the session banner) — the guide's "context starvation"
anti-pattern; a matured contract is staged but never committed (ephemeral
sessions lose the self-improvement while the datastore row survives); no
write-path probe at define time and no file-based DATA.md fallback, so the
first run on a DB-less or credential-less repo crashes mid-run; no run
bookkeeping even when DATA.md declares it; approval is binary vs
stakes×reversibility tiers; no process→process composition; no deprecation
status; `docs/proactive-loops.md` predates P8 entirely.

**What (likely split into 2–3 releases when built).**
- **Integration:** `run`'s mature step gains an escalation branch (stub a
  `/flywheel:spec` from run evidence, link it from the Improvement log); `sync`
  accepts a process slug / `--all`; `spec`'s prior-art step reads DATA.md +
  intersecting contracts; a `process=<slug>` ledger metadata key scored by
  session-start/recall; `run` ends by committing the matured contract.
- **Lifecycle:** session banner + bare `/flywheel:run` list contracts (slug +
  Purpose one-liner); define-time read-only write-path probe (connect, target
  exists — hand off to pillar 1 when the table is missing); file-based DATA.md
  fallback (`data/<process>/<key>.json`, git as datastore) + a `run` dry-run
  mode; honor `flywheel_runs` bookkeeping when declared; `status:
  active|deprecated` + `superseded-by`; per-operation approval tiers in
  Guardrails; Rules may invoke sub-processes (cycle guard, per-sub persistence
  verification); batch inputs (file/glob) under one budget + a single
  maturation; a "Schedule a process run" section in `docs/proactive-loops.md`
  (credentials caveat, maturation-commit rule); generalize `agents/evaluator.md`
  beyond autoloop vocabulary.

**Files:** `skills/run|process|sync|spec|help/SKILL.md`,
`scripts/session-start.sh`, `skills/compound/SKILL.md`, `agents/evaluator.md`,
`docs/proactive-loops.md`, README, `plugin.json` + `upgrades/`.

---

## P15 — Dogfooding flywheel on flywheel (flow-audit run #1)

**Why.** The plugin repo practices neither pillar: no LEARNINGS.md, no specs/,
and its real memory lives in a parallel bespoke system (`docs/research/`
journal + proposals + briefs) that re-implements spec/plan/compound outside
flywheel state — P8 itself shipped with no spec and no compound entry. Run #1
of `flow-audit` (this audit) created the repo's first `.claude/flywheel/`
state; the rest should follow, both for credibility and because the maintainers
are pillar-2's best test users.

**What.** Seed `LEARNINGS.md` from the decision log's genuinely reusable
lessons (the version-collision-at-merge gotcha, the routine-auth postmortem,
the transcript-only vs re-execution evaluator decision); define the release
checklist (bump → upgrade note → README/help sync → three test scripts) as
`processes/release.md` — a textbook recurring operation with a
machine-checkable metric; fix help's state list to include `processes/` +
`DATA.md`; align the banner's 8 phases with loop's 6 (label brainstorm/ship as
optional bookends); standardize the ledger on prepend-newest-first everywhere.

**Files:** `.claude/flywheel/LEARNINGS.md` + `.claude/flywheel/processes/release.md`
(state only, no bump); `skills/help/SKILL.md`, `skills/loop/SKILL.md`,
`scripts/session-start.sh`, `skills/compound/SKILL.md`, README (release, bump).

---

## P16 — Live run progress: task ledger + telemetry report (owner ask, 2026-07-13)

**Why.** Run #1 exposed a UX hole the owner named directly: while Claude executes
a process, progress is opaque — reviewer results arrive as prose walls and the
owner has no live view of what the run is doing, what remains, or where it is
stuck. Pillar 2's whole premise is Claude-as-backend; a backend without
observability is not operable. Piloted immediately as `flow-audit` v3 (fixed
**Progress reporting** section) + the first machine-issued run report
(`.claude/flywheel/runs/flow-audit/2026-07-13.html`).

**What.** Generalize the pilot into the machinery:
- `skills/run/SKILL.md` gains a fixed progress step: at run start, materialize
  each contract Rule as a visible task in the host task system; update states at
  every transition in real time; regenerate the run's telemetry report
  (`.claude/flywheel/runs/<slug>/<date>.html`) at each transition and republish
  its artifact to a stable URL; chat is reserved for gates, blockers and the
  final synthesis ("signal, don't narrate").
- `skills/process/SKILL.md`'s contract template gains the **Progress reporting**
  section so every new contract inherits the obligation.
- Report content convention: task ledger with states + timings, verify gates,
  unit/agent telemetry (tokens, duration), findings by severity, backlog/output
  delta, maturation events, metric verdict.

**Files:** `skills/run/SKILL.md`, `skills/process/SKILL.md`, README +
`skills/help/SKILL.md`, `plugin.json` + `upgrades/`.

---

## P17 — Setup/fixture knowledge as first-class compounded context (owner ask, 2026-07-15)

**Why.** The owner's insight, in their words: *"hemos perdido mucho tiempo
descubriendo cómo crear el dato stub para las pruebas — una editorial para
detalles, una editorial para homeTag, otra para amazononsite … quiero que
nuestras intervenciones siempre creen este conocimiento del repo y usarlo como
contexto para enriquecer las siguientes."* The costliest thing a session
rediscovers is not decisions or bugs — it is **how to set up the world**: how to
build a valid stub/fixture for a domain entity, how to seed the datastore, the
exact incantation to bring a test harness to life. flywheel's memory pillar
(`compound` → `LEARNINGS.md` → SessionStart injection → read-priming) captures
`decision`/`gotcha`/`pattern`/`bugfix`, but "setup recipes" fall through the
cracks — they read as one-off scaffolding, so nobody compounds them, so the next
session pays the discovery cost again. This session proved the loss on flywheel
itself (every hook test rebuilt the same git-fixture scaffold); the owner's
example (editorial fixtures for `detalles` / `homeTag` / `amazononsite`) is the
same failure in a product repo.

**What.**
- A new learning **type `fixture`** (alongside decision/gotcha/pattern/bugfix):
  a named entity/harness + the concrete recipe to construct a valid instance of
  it, with the fields/relationships that are easy to get wrong. Seeded already:
  the hook-test-fixture recipe in `LEARNINGS.md`.
- `skills/compound/SKILL.md` — explicitly prompt for fixture/setup knowledge at
  cycle close ("did we discover how to build a stub, seed data, or stand up a
  harness that a future cycle shouldn't have to rediscover?").
- `skills/spec/SKILL.md` + `skills/work/SKILL.md` — the prime step surfaces any
  `type=fixture` entries whose entity intersects the task, so setup knowledge is
  in context *before* work starts (not after the rediscovery).
- `skills/process/SKILL.md` — pillar-2 contracts can reference fixture entries
  for the entities they read/write (ties into DATA.md).
- Scoring: `scripts/session-start.sh` already ranks by files/branch/recency;
  fixture entries carry `files=`/entity tags so the existing relevance scorer
  surfaces them — no scorer change needed, just the new type flowing through.

**Files:** `skills/compound|spec|work|process/SKILL.md`, README + help (document
the new type), `plugin.json` + `upgrades/`. (`LEARNINGS.md` fixture entries are
per-repo state, no bump.)

**Open questions:**
- Is `fixture` a distinct type, or a tag on `pattern`? (Leaning distinct — it
  answers "how do I build one?", which `pattern` doesn't privilege.)
- Should `/flywheel:work` *offer to write* a fixture entry when it spends N tool
  calls constructing test data, the way delegation triggers fire on thresholds?

## P18 — Evidence-gated compounding (owner ask, 2026-07-20)

**Why.** The owner named a structural inconsistency: flywheel refuses to call
*code* done on reasoning alone — `verify` runs the real thing, `review` is
adversarial, "unrun tests don't count" — but `compound` writes *knowledge* on
belief. A learning enters `LEARNINGS.md` because the agent believes it, then is
injected as trusted context into every future session. A false or unverified
conclusion is worse than none: it misleads silently and compounds. The framework
protects the code but not the memory. (Surfaced while adding P17's fixture-
capture trigger, whose false-positive risk is the specific case; P17 already
gates fixture capture on observed evidence — P18 generalizes the guard to all
types.)

**What.** Make compounded knowledge evidence-backed by construction:
- **A capture bar in `compound`** (partly shipped in v0.21.0 as prose: "only
  compound what this cycle proved"): a learning is recorded only when it rests
  on observed evidence — a test that went green, a run/PR, output actually seen
  — not on reasoning. Unverifiable insight is left out or explicitly marked
  unverified, never written as a durable conclusion.
- **An `evidence=` metadata key** on the `fw:` line — a short pointer to what
  proved it (test name, PR, run id, the command + result). Optional at first;
  entries without it read as lower-trust.
- **Surface trust at consumption**: `session-start` injection and `recall` can
  note when an entry is unverified (or de-prioritize it), so a reader weighs it
  accordingly — the same way `verify` output carries its evidence.
- **Optional hard gate later**: a compound lint that refuses an entry with no
  evidence basis unless flagged `unverified`, mirroring the deterministic
  completion gate for code.

**Files:** `skills/compound/SKILL.md`, `scripts/session-start.sh` (+ its test)
if trust is surfaced at injection, `skills/recall/SKILL.md`, README + help,
`plugin.json` + `upgrades/`.

**Open questions:**
- Is `evidence=` a hard requirement or an advisory field with a trust signal?
  (Leaning advisory first — a hard gate risks suppressing genuine
  cross-cutting lessons that are real but hard to point a single test at.)
- Does surfacing "unverified" at injection cost more tokens than it saves in
  avoided wrong-context? Measure before committing to the injection change.
- How to backfill: existing entries have no `evidence=` — treat absent as
  "legacy, untagged," not "unverified."

## P20 — State-write pre-approval hook (owner ask, 2026-07-29)

**Why.** The owner named a UX inconsistency in the loop: flywheel's only two
deliberate approval gates are *conversational* — the spec sign-off and the plan
approval — and once "apruebo" lands, the loop is designed to run to completion
without further questions. But the harness's tool-permission layer knows
nothing about those gates: every save of a spec, plan, ledger entry, process
contract, `DATA.md` or run report raised a fresh "allow write?" prompt, asking
again for what the plan approval already implied. Two permission systems, one
of them blind to the other.

**What.** Teach the harness that flywheel state is pre-approved — and nothing
else is:
- **`scripts/write-allow.sh`**, a `PreToolUse` hook on
  `Write|Edit|MultiEdit|NotebookEdit` that emits `permissionDecision: allow`
  when the target resolves inside `<project>/.claude/flywheel/`.
- **Allow-only, fail-open**: never denies, never blocks; out-of-scope paths,
  malformed input or missing `python3` fall through silently to the ordinary
  permission prompt.
- **Strict scope**: `realpath` containment check — `..` traversal, prefix
  siblings and symlink escapes planted inside the state dir get no grant. A
  bash pre-filter skips the python spawn for the out-of-scope majority.
- **Both install modes**: plugin (`hooks/hooks.json`) and vendored
  (`install-vendored.sh` merge + uninstall).

**Files:** `scripts/write-allow.sh` (+ `scripts/test-write-allow.sh`),
`hooks/hooks.json`, `scripts/install-vendored.sh` (+ its test), CI workflow,
README, `plugin.json` + `upgrades/v0.26.0.md`.

## P21 — Bash grants coherent with the approval gates (owner ask, 2026-07-29)

**Why.** P20 fixed state *writes*; the same incoherence remains for *commands*.
The owner's model is explicit: after the plan approval, the loop runs to
completion — commits and pushes included — yet the harness still prompts for
much of what the loop shells out. The analysis found three root causes,
confirmed against the official docs
(code.claude.com/docs — skills, permissions, plugins, subagents):

1. **`allowed-tools` grants are turn-scoped.** A skill's `allowed-tools`
   frontmatter DOES pre-approve its patterns — but only for the turn that
   invokes the skill, and *the grant clears on the next user message*. The
   loop's gates are user messages by design ("apruebo"), so the post-gate
   action lands in a **new** turn where no skill was re-invoked and the grant
   is gone. That is exactly the owner's reported moment: approve the plan →
   the very next thing (saving/committing it) prompts again. The frontmatter
   grants (`ship: Bash(git *)`, `work/verify/run: Bash`) were never wrong —
   they just evaporate at each gate.
2. **Plugins cannot ship `permissions.allow` rules.** Plugin `settings.json`
   supports no permission keys; hooks (`PreToolUse` → `permissionDecision:
   allow`) are the only durable plugin-native grant — the P20 mechanism.
3. **The riskiest prompts are repo-specific and the plugin can't know them.**
   The test/metric command (`npm test`, `pytest …`) and pillar-2 datastore
   commands come from the repo (spec metric, `DATA.md`), not from flywheel.

**Command inventory** (what the loop actually shells out post-approval):
git read-only forms (status/diff/log/show/branch — already covered by Claude
Code's built-in read-only list, no prompt); git state-advancing on the feature
branch (`add`, `commit`, `push -u origin <branch>` from work/ship/compound;
`stash` in autoloop reverts); the repo's verification/metric commands
(work/verify/autoloop/debug); pillar-2 datastore commands per `DATA.md`
(run); `gh pr create` (ship).

**What — three layers, each grant anchored to the approval that implies it:**

- **Layer 1 — `scripts/bash-allow.sh`** (plugin-native, dynamic; the P20
  contract applied to Bash): allow-only, fail-open `PreToolUse` hook on
  `Bash`. Grants ONLY single, unchained commands (any `&&`, `;`, `|`, `$()`,
  backtick or redirect falls through to the normal prompt) in two classes:
  (a) `git add` / `git commit` without repo-relocation flags
  (`-C`, `--git-dir`, `--work-tree`); (b) `git push` only when force-free,
  remote is `origin`, and the target branch **is the current branch and is
  not the default branch** — checked live inside the hook (`git branch
  --show-current` vs `origin/HEAD`), which is precisely what static rules
  cannot express. Never grants: force pushes, pushes to default, `reset`,
  `rebase`, `checkout`, `clean`, `rm`, network commands, installs,
  `git config`. Docs guarantee a hook "allow" can never override an explicit
  user `deny`/`ask` rule, so the owner keeps the last word.
- **Layer 2 — gate-time consent writes durable repo rules.** The repo-specific
  commands get their grant *at the conversational gate that approves them*:
  `/flywheel:spec` — when the success metric fixes a command — and
  `/flywheel:process` — when `DATA.md`/the contract fixes datastore commands —
  **offer** to append the matching `Bash(<cmd>*)` rules to the project's
  `.claude/settings.json` `permissions.allow` as part of the sign-off. One
  question, once, at the moment the owner is already approving that exact
  command; committed with the spec/contract so every future session inherits
  it. (Same consent pattern as gate.sh trust: explicit, durable, visible in
  the diff.)
- **Layer 3 — keep frontmatter grants, document the turn-scoping.** They still
  eliminate prompts *within* each skill-invoking turn; skills gain a one-line
  note to prefer single commands over `&&` chains so grants and rules actually
  match (compound commands must match rule-by-rule).

**Files:** `scripts/bash-allow.sh` (+ test), `hooks/hooks.json`,
`scripts/install-vendored.sh` (+ test), `skills/spec/SKILL.md`,
`skills/process/SKILL.md`, README, CI, `plugin.json` + `upgrades/`.

**Decisions (owner, 2026-07-29):**
- **`git stash`: yes** — grant `stash push/pop/list` (bounded, reversible);
  `git checkout -- <path>` keeps prompting (it can silently discard the
  owner's own uncommitted edits — the one revert autoloop must never
  auto-fire).
- **`gh pr create`: no** — outward-facing, one prompt per cycle is cheap,
  and opening a PR is the loop's boundary with the outside world.
- **Layer 2 lives inside `spec`/`process`, not a standalone skill** — the
  whole P21 thesis is that the conversational gate IS the authorization, so
  the grant must be offered at the exact moment of sign-off, in the same
  breath as the metric/datastore command it covers. A standalone
  `/flywheel:permissions` skill would detach consent from approval and
  become one more thing to remember to run. If a retrofit need appears
  (contracts signed before this ships), `/flywheel:sync` can flag the
  missing rules as drift — no new surface needed.

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

**Post-audit sequencing (2026-07-13, P9–P15):** P10 first (cheapest, unbreaks
macOS installs), then P9 (restores a shipped-but-inert feature), P12 (immediate
token savings), P11 and P13 (security posture), P15 (dogfooding), and P14 last
(largest surface; split into integration + lifecycle releases when built).

**Post-audit sequencing (2026-07-30, P23–P26 and the eval follow-ups):** the
order is a dependency, not a preference — **P26 before re-running any pillar-1
eval.** `verify`'s expectations are prose applied by hand, so an iteration run
today spends ~250k subagent tokens on assertions nobody can audit for a vacuous
pass. That is exactly how the `run` eval-2 grader stayed incapable of failing
until a committed `check.sh` let someone run it against an untouched fixture.
Build the instrument, then measure.

After P26: the `verify` iteration on the cleaned fixtures (3 evals × 2 arms — its
bug-detection assertions currently have **no** trustworthy measurement), then the
pillar-2 baseline arm (meaningful only now that v0.36.0 removed the
`demo-repo`/`target-repo` leak that would have poisoned it), then P23's open
question — whether the cost proxies track real token spend, which needs two
comparable real cycles and therefore a session with the plugin actually
installed. Smallest last: pin whether `run_end` carries its own cost, and the
per-skill cap left out of P24.

---

## P22 — Dev-loop discipline on the plugin itself: dogfooded TDD + skill evals (owner ask, 2026-07-29)

**Why.** The owner asked directly: why don't we follow TDD when developing
plugin features? Diagnosis: the repo has a real test net (every script has a
paired `test-*.sh`, run in CI, plus docs-consistency and `plugin validate
--strict`) but it is test-*after*, not test-first, and nothing enforces the
pairing; ~90% of the surface (skills/agents = prompts) has only structural
validation, no behavioral check; and "small" sessions skip the very
`spec → work → verify` loop the plugin prescribes — the exact rationalization
`/flywheel:work`'s table bans. P15 seeds dogfooding state; P22 makes the
discipline binding.

**What — two phases:**

- **Phase 1 (cheap, root cause).** (a) CLAUDE.md convention: every plugin
  feature runs the loop on this repo, no size exception; scripts are developed
  red→green. (b) CI gate `scripts/check-test-pairing.sh` (+ its own test,
  itself written test-first): any PR diff touching `scripts/<name>.sh` must
  also touch `scripts/test-<name>.sh` — add, change or delete together;
  `SKIP_TEST_PAIRING=1` is a logged escape, never silent.
- **Phase 2 (behavioral evals as release gates, selective).** Skills are
  prompts: the only real test is running a session and grading the output.
  Adopt the skill-creator eval harness (`evals/evals.json` per skill: realistic
  prompts + objectively verifiable assertions; with-skill vs baseline subagent
  runs; grader → `benchmark.json`) for the skills where a silent regression
  hurts most: `verify` (must not rationalize FAIL→PASS), `work` (must induce
  red→green), `process`/`run` (pillar 2, Claude-as-backend). Fixtures: a
  planted-bug mini-repo per eval, captured as `type=fixture` learnings. Cost
  is real (a 3-case × 2-config iteration ≈ 300–800k tokens), so evals run
  **manually before a release that touches one of those skills**, not in CI.
  Parallelizes as two independent sessions: pillar 1 (`work`/`verify`) and
  pillar 2 (`process`/`run`).

**Files:** phase 1: `CLAUDE.md`, `scripts/check-test-pairing.sh` (+
`scripts/test-check-test-pairing.sh`), `.github/workflows/validate-plugins.yml`,
`plugin.json` + `upgrades/`. Phase 2: `skills/<name>/evals/evals.json` +
fixtures, README testing section; no runtime skill changes required.

---

## P23 — Cycle-cost telemetry: the loop measures its own cost (analysis, 2026-07-30)

**Why.** v0.30.0 shipped four changes whose entire justification is output-token
cost (two-tier telemetry, micro-cycle routing, `gate.sh seal`, trimmed
descriptions) and **only the last one can be verified after the fact** — the
description trim is measurable with `git` (5,441 → 4,246 chars, −22.0%); the
other three have no before/after at all. The repo preaches machine-checkable
success metrics and then shipped its own optimization release on a design
argument. The telemetry JSONL (P16 + v0.30.0) already writes one line per
transition, so the ledger exists — it records *what* happened, never *what it
cost*.

**What.** Extend the JSONL transition line with cost fields, summarize them in
the HTML report at close, and add a helper that diffs two run JSONLs so
"cheaper" becomes a number instead of a claim.

**Open question — this is the crux, not a detail.** Self-reported token counts
are unreliable: a session cannot see its own usage accurately, so a
`tokens:` field would invite exactly the fabricated evidence P18 exists to keep
out of the ledger. Candidate honest substitutes, all mechanically observable:
bytes written per transition, tool-call count, files touched, wall-clock
between transitions. Decide the proxy set *before* building, and label it a
proxy in the report.

**Files:** `skills/{work,loop,run,process}/SKILL.md` (line schema + close-time
summary), a new `scripts/run-cost.sh` (+ its paired test), README; `plugin.json`
+ `upgrades/`.

---

## P24 — Description budget as a CI ratchet (analysis, 2026-07-30)

**Why.** The 17 skill `description` fields load into context every session, so
their length is a fixed cost paid on every invocation forever. v0.30.0 cut them
22% — and nothing stops the next skill from adding 400 chars back. A one-off
measurement that isn't a gate decays; every other invariant in this repo (test
pairing, docs consistency, `plugin validate`) is enforced in CI.

**What.** `scripts/check-description-budget.sh`: sum the frontmatter
`description` chars across `skills/*/SKILL.md`, compare against a committed
budget, fail above it. Report the per-skill breakdown on failure so the diff
says which skill grew. Budget starts at the current total plus modest headroom
for new skills; raising it is a deliberate, reviewable commit — the ratchet is
that it can't move silently. Developed test-first per the CLAUDE.md rule.

**Why this one first.** Cheapest of the three, no open design question, and it
protects a saving that is already banked and already measured.

**Files:** `scripts/check-description-budget.sh` +
`scripts/test-check-description-budget.sh`,
`.github/workflows/validate-plugins.yml`, `plugin.json` + `upgrades/`.

---

## P25 — Close the gaps the P22 eval iteration exposed (analysis, 2026-07-30)

**Why.** The committed benchmarks are honest about their own limits, and those
limits are the follow-up work:

- **`work`'s evals don't discriminate** — 8/8 with the skill and 8/8 without.
  The kata prompt names `./run-tests.sh`, so a strong model does red→green
  unaided; the eval currently proves the model, not the skill.
- **`process`/`run` have no baseline arm** (deliberately skipped: the release
  gate needs regression detection, not a value study). So their 49 green
  assertions cannot answer whether the contract shape is skill-induced or
  model-default — an open question about the whole pillar-2 premise.
- **`process` §5 pins no Improvement-log entry format** while `run` §4 does, so
  the grader was loosened rather than the skill tightened (already flagged as a
  follow-up in the v0.32.0 log entry).

**What.** (a) Rewrite the `work` kata prompt so the test runner isn't named,
making the red step attributable — or, if it still won't discriminate, say so
explicitly in the README instead of letting 100% read as skill value. (b) Run
one baseline iteration for `process`/`run` (~120k tokens each) purely as a
value study, separate from the gate. (c) Pin the Improvement-log format in
`process` §5 and re-tighten `check.sh`.

**Files:** `skills/work/evals/`, `skills/{process,run}/evals/`,
`skills/process/SKILL.md` (§5), README; version bump only for the §5 change.

---

## P26 — Committed graders for `verify` and `work` (analysis, 2026-07-30)

**Why.** `process` and `run` each ship a deterministic `evals/check.sh`; that is
the only reason the hollow `run` eval-2 assertion was ever found — a committed
grader can be *run against an untouched fixture* to ask "can this even fail?".
`verify` and `work` have no grader: their expectations are prose, and each
iteration re-derives the regexes by hand. Two defects have now been found by
accident in pillar 1 (the `work` fixture README leaking the grading rule, then
the `verify` fixtures carrying the full answer key), and neither would have
survived a `check.sh` that someone had run red-first.

**What.** `skills/{verify,work}/evals/check.sh <id> <workdir>`, same contract as
pillar 2: one PASS/FAIL line per expectation, exit 0 only if all pass, verified
red on an untouched fixture before any real run. For `work` most assertions are
already mechanical (`.check-log` vs `baseline-sha`); for `verify` they are
regexes over `report.md`/`transcript.md`.

**Also worth encoding as a check**: no fixture file may match the assertion
vocabulary (`VERDICT:`, `baseline-sha`, `.check-log`, "the eval asserts"), which
would have caught both leaks mechanically instead of by an executor volunteering
that the instructions contradicted each other.

**Files:** `skills/{verify,work}/evals/check.sh`, README runbook.

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
- **2026-07-10** — **Opened and shipped P8 (agent-native runtime pillar) as
  v0.15.0.** New direction from the repo owner: flywheel should not only *build*
  software but make the repos it's installed in *agent-native* — Claude as the
  runtime for recurring domain operations, persisting to the repo's own datastore
  and improving each operation per run (see the owner's ask, captured verbatim in
  [`agent-native-processes.md`](agent-native-processes.md)). Built two skills:
  `/flywheel:process` (define + mature a process contract, bootstrap
  `.claude/flywheel/DATA.md`) and `/flywheel:run` (execute as the backend, persist
  idempotently + verified, cross-check with the `evaluator` when a metric is
  declared, append ≤1 evidence-based refinement). Decisions: two verbs not one;
  persistence follows the repo (never imposed); maturation evidence-gated; reuse
  the `evaluator` agent rather than add one. Captured durably in a new root
  `CLAUDE.md` + `agent-native-processes.md`; README/help/banner synced.
  docs-consistency + install-vendored + read-prime + `plugin validate` all green.
  This is the roadmap's first entry beyond the original P1–P7 dev-loop set.
- **2026-07-13** — **First `/flywheel:run flow-audit` (run #1, scope=full) —
  pillar-2 dogfooding on flywheel itself.** Created `.claude/flywheel/DATA.md`
  (git-native markdown persistence) and `processes/flow-audit.md` v1 via
  `/flywheel:process`, then executed the contract: verify green (all three test
  scripts), four parallel fresh-context reviewers (correctness, security,
  performance/tokens, agent-native coherence checked against the Every guide)
  returned ~45 raw findings → ~32 after dedupe: **2 Critical** (read-prime's
  PreToolUse stdout never reaches the model — the v0.11.0 feature is inert;
  vendored install broken on macOS by GNU-only sed), **11 High** (gate.sh
  RCE-by-PR trust boundary; unframed prompt-injection surface; run's SQL
  parameterization gap; unpinned `@main` supply chain; suite re-run every Stop;
  full-ledger reads; dispatch-all review; pillar feedback gaps; pillar-2
  onboarding cliff; no process discovery; zero dogfooding), plus ~12 Medium and
  ~7 Low. Opened **P9–P15**. Owner signed off on the synthesis **before**
  persistence — and that gate proved valuable enough to become contract law:
  `flow-audit` matured to **v2** (new owner-sign-off rule between screening and
  persisting). Clean bill (explicitly not to touch): evidence-gated maturation +
  read-back rigor, model routing, recall's progressive disclosure, work's
  delegation thresholds. Docs + `.claude/flywheel/` state only — no version bump.
- **2026-07-13** — **Owner revision: live run progress.** After run #1 the owner
  asked for organized, live-visible progress ("a task list of what you'll do,
  states updated live"). `flow-audit` matured to **v3** (deliberate revision per
  `process` §4): new fixed **Progress reporting** section — one visible task per
  Rule updated at every transition, a per-run telemetry report at
  `.claude/flywheel/runs/<slug>/<date>.html` regenerated per transition and
  republished to a stable artifact URL, chat reserved for gates/blockers/synthesis.
  First report issued for run #1. Opened **P16** to generalize into
  `skills/process` + `skills/run` (release). DATA.md schema gained the runs/
  location. Docs + state only — no version bump.
- **2026-07-13** — **Shipped P16 as v0.16.0**, built through the full pillar-1
  cycle **on flywheel's own state for the first time**: signed REASONS spec +
  plan with per-task checks live in `.claude/flywheel/specs/p16-live-progress.*`.
  Owner's sequencing call: P16 first, so every later build (P9–P15) runs with
  live progress from minute one — and extended to **both pillars** for exactly
  that reason. Progress obligations added to `run`/`process`(template)/`loop`/
  `work`; README/help synced (help's state-list gap from P15 shipped early
  here); spec metric VERIFIED PASS. Diff review routed per P12's logic (single
  combined-lens reviewer, ~64k tokens vs ~380k for the audit fan-out): verdict
  SHIP, 0 Critical/High — the one Medium was the feature's own pilot report
  committed stale, regenerated and compounded as a gotcha. `LEARNINGS.md`
  seeded with the cycle's first three typed entries (P15's dogfooding begins).
  docs-consistency + install-vendored + read-prime all green.
- **2026-07-13** — **Shipped P10 as v0.17.0**, first full cycle under P16's live
  progress (ledger + live cycle report from minute one). BSD/macOS-safe sed
  (with a real inner-loop lesson: `s//` has no previous regex on line 1 of a
  `1,/re/` range — spell the regex out); manifest pruning on re-install with a
  **sticky `--auto-update` choice** (improvement over plan, closes the
  orphaned-workflow finding completely); manifest-driven uninstall; generic
  reviewer agents; honest `allowed-tools`. Review (routed: single adversarial
  correctness reviewer, ~63k tokens) returned **HOLD** with a High the tests
  had missed: the rewritten uninstall loop was still glob-driven and could
  delete user-owned `flywheel-*` dirs — including one prune had just restored.
  Fixed with an `in_manifest` guard; both adversarial scenarios are now
  permanent test assertions (26 total); metric re-verified PASS. Gotcha
  compounded to the ledger. The HOLD is the system working: verify green ≠
  reviewable — the reviewer earns its dispatch.
- **2026-07-13** — **Shipped P9 as v0.18.0.** The v0.11.0 flagship finally
  reaches the model: read-prime matches now travel in the hook JSON contract's
  `hookSpecificOutput.additionalContext` (shape confirmed against the live
  hooks docs by the reviewer) — PreToolUse stdout was transcript-only, so the
  feature had been inert for two releases. Plus: a bash pre-filter that skips
  the python spawn for the no-match majority (with the fall-through-on-
  uncertainty invariant), blank-line-tolerant awk metadata parsing, top-K
  selection instead of the O(n²) sort, macOS `date -v` fallback, a same-day
  per-uid symlink-guarded cache for the update-check curl, a NEW
  `test-session-start.sh` wired into CI (the scoring logic's first coverage),
  and the read-prime tests upgraded to the JSON contract. Review (routed,
  adversarial): **SHIP** with 4 Lows — all fixed in-release (`grep -qF --`,
  backslash fall-through, stamp hardening + test, fact-not-imperative
  phrasing) + 1 tie-ordering Info accepted. Three entries compounded. The
  audit's Critical C1 and all four session-start Mediums are now closed.
- **2026-07-15** — **Shipped P11 as v0.20.0.** Hardened the opt-in completion
  gate against the flow-audit's most serious finding. Trust-on-first-use
  (fail-safe): an unrecognized `.claude/flywheel/gate.sh` is no longer
  auto-run — the hook prints a one-time trust command whose consent hash lives
  **outside the repo** (owner picked this model at the sign-off gate over a
  weaker warn-and-run). Plus a git-tracked cost cache (skip re-running an
  unchanged tree), a per-failing-tree persisted bypass, `stop_hook_active`
  honoring, and `scripts/test-gate.sh` — the gate's first coverage. Review
  (adversarial, security lens) returned **HOLD** with two confirmed *false-skip*
  Highs on a security release: (1) a global block counter that stopped
  enforcing on all new regressions after the first bypass, and (2) a cost cache
  over `git diff` that skipped staged-only and untracked-content changes —
  either could let a red gate read as green. Fixed in-release (counter keyed to
  the failing signature; signature uses `git diff HEAD` + untracked content and
  excludes flywheel's own state dir; store path rejected if inside the repo;
  genuine `stop_hook_active` test; overclaim wording corrected). Three gotchas
  compounded. `requires-action: true` — existing gate users trust once. All
  five test scripts green.
- **2026-07-15** — **Shipped P12 as v0.19.0.** flywheel's token-efficiency
  research applied to itself: recall-first priming in loop/spec/process (no
  more ~18k-token whole-ledger reads), diff-routed review with mandatory
  stated skips (the pattern that saved ~300k tokens applied manually across
  three cycles is now law), honest evaluator wording, the four heaviest
  descriptions trimmed to ≤300 chars, and size-capped injection with a recall
  tail. Review verdict **HOLD** with a meta-lesson: the spec's signed metric
  failed verbatim (`grep 'routing'`) while verify had passed a widened
  paraphrase — the reviewer caught the verifier; plus a real mawk UTF-8
  byte-split bug in the new truncation (found via dash-dense boundary
  fixtures) and stale wording in review's/evaluator's own descriptions. All
  fixed in-release; overstated "reduction" claims corrected in the spec and
  upgrade note (session-loaded surface shrinks; review's body grows by a
  routing table that pays for itself). Two gotchas compounded. Metric
  re-verified **verbatim** PASS.
- **2026-07-27** — **v0.22.0**: generalized the **multi-runtime profiles**
  pattern from the `keep` repo's `keep-experiences` contract (v2) into the
  plugin. `/flywheel:process` gains an opt-in profiles section (per-profile
  namespacing, composite `(profile, key)` idempotency, isolation guardrail,
  runtime-dependent capability clauses, root `AGENTS.md` runbook for external
  agents like Manus); `/flywheel:run` accepts `profile=<id>` and enforces
  isolation. Rationale: pillar 2 says the agent is the runtime — profiles make
  the runtime *pluggable and comparable*, and owner verdicts between competing
  portfolios become Improvement-log evidence every profile inherits.
- **2026-07-27** — **v0.23.0**: course-correction on v0.22.0 (owner feedback,
  same day): the profiles pattern must live **in the repo, not the plugin**,
  and repos must be able to **extend how agents intervene** in them. New
  generic mechanism: `.claude/flywheel/extensions/<name>.md` (repo-owned,
  self-maturing intervention conventions) + `extensions:` frontmatter on
  contracts + /flywheel:run loading/enforcing them. The multi-runtime
  profiles text moved out of the skills into `keep`'s
  `extensions/profiles.md`. Plugin ships mechanism; repo owns pattern.
- **2026-07-27** — **v0.24.0**: repos carry their **product definition**
  (`PRODUCT.md` / north-star in `CLAUDE.md`/`AGENTS.md`) and the plugin now
  anchors on it: `/flywheel:spec` grounds Reasons in what the repo is
  building (revising the definition in the same spec when a feature falls
  outside it); `/flywheel:process` names the business capability a contract
  implements. Completes the division from v0.23.0: mechanism in the plugin,
  business in the repo. First user: `keep`'s PRODUCT.md (personal tracking &
  development app evolved from the owner's content).
- **2026-07-29** — **Shipped P19 (v0.26.0): update postprocess.** Owner asked
  whether post-update processing was worth adding; audit found the real hole —
  the auto-update PR's `requires-action` warning is ephemeral, so merging
  without running `/flywheel:update` lost pending strategies silently. Fix:
  the installer (the single writer that holds both the old version and the
  notes) persists the `(old, new]` requires-action range to
  `.claude/flywheel/PENDING-UPGRADES` (state, never in the manifest);
  SessionStart nags every session, offline; `/flywheel:update` clears per
  applied version; uninstall removes it. Plus a `bash -n` smoke gate that
  aborts a refresh before VERSION/manifest are recorded when a vendored hook
  script no longer parses. Deferred: CI auto-applying strategies — revisit if
  the nag shows recurring debt. Spec: `specs/p19-update-postprocess.md`.
- **2026-07-29** — **Shipped P20 (state-write pre-approval hook) as v0.27.0**
  (owner ask, same day): the plan approval is the loop's real write
  authorization, so the harness must stop re-asking for flywheel's own state.
  New allow-only `PreToolUse` hook (`scripts/write-allow.sh`) on
  `Write|Edit|MultiEdit|NotebookEdit` grants writes that `realpath`-resolve
  inside `.claude/flywheel/` and touches nothing else — repo code and
  `.claude/settings.json` keep the normal permission flow. Wired in both
  install modes (plugin hooks.json + vendored settings merge/uninstall),
  tested (`scripts/test-write-allow.sh`, incl. traversal/symlink/prefix-sibling
  escapes and fail-open), documented in README. docs-consistency +
  install-vendored + write-allow tests green.
- **2026-07-29** — **P21 analysis recorded (docs-only, no version bump)**:
  mapped every Bash command the loop shells out post-approval to the approval
  gate that implies it, and confirmed the mechanics against the official docs
  — skill `allowed-tools` grants are real but turn-scoped (they clear at each
  user gate, which is why "apruebo" is immediately followed by a prompt),
  plugins cannot ship `permissions.allow`, and a PreToolUse "allow" can never
  override an owner's explicit deny/ask. Proposed three layers: a P20-style
  allow-only `bash-allow.sh` hook for branch-aware git advancement, gate-time
  consent that writes the repo-specific test/datastore rules into project
  settings at spec/process sign-off, and documented turn-scoping for the
  existing frontmatter grants. Status 🟡 — awaiting owner go/no-go.
- **2026-07-29** — **P21 open questions resolved by the owner** (same day as
  the analysis): `git stash` yes (`push/pop/list`; `checkout --` keeps
  prompting), `gh pr create` no (outward-facing boundary), and layer 2 lives
  **inside `spec`/`process`** rather than a standalone permissions skill —
  consent stays welded to the gate that grants it, with `/flywheel:sync`
  as the retrofit path for pre-existing contracts. P21 stays 🟡 pending the
  explicit go to build (target: v0.28.0).
- **2026-07-29** — **Renumbered at merge time** (the exact scenario
  `briefs/README.md` warns about, third occurrence after v0.12.0 and
  v0.25.0): a parallel session merged its own P19 as v0.26.0 into `main`
  (update postprocess), so this branch's state-write hook renumbers
  **P19→P20, v0.26.0→v0.27.0**, and the bash-grants proposal **P20→P21**
  (target v0.28.0). Content unchanged; only identifiers moved.
- **2026-07-29** — **Shipped P21 (bash grants coherent with the approval
  gates) as v0.28.0**, on the owner's go, per the three-layer design and the
  resolved questions: `scripts/bash-allow.sh` (allow-only `PreToolUse`/`Bash`;
  one plain command; add/commit/stash push-pop-list; force-free push of the
  current non-default branch to origin, checked live; global-flag,
  metacharacter, foreign-remote/-cwd and refspec escapes all fall through to
  the prompt); spec/process sign-offs now offer to write the repo-specific
  metric/datastore rules into project `permissions.allow` (committed with the
  spec/contract, never unasked); sync gains permission drift as a third
  class; work/ship document the prefer-single-commands rule. 40-assertion
  hook test + installer coverage wired into CI. Full suite +
  `plugin validate --strict` green.
- **2026-07-29** — **P22 opened and phase 1 shipped as v0.29.0** (owner ask:
  "why no TDD on the plugin itself?"; owner approved the two-phase plan).
  Phase 1: CLAUDE.md dev-loop discipline section (loop on every feature,
  test-first scripts) + `check-test-pairing.sh` CI gate, developed red→green
  — its test existed and failed before the gate did. Phase 2 (skill evals for
  `verify`/`work` and `process`/`run` as manual release gates) stays open,
  split into two parallel sessions, one per pillar.
- **2026-07-29** — **P22 phase 2, pillar 1 shipped as v0.31.0** (parallel
  session; pillar 2 `process`/`run` runs separately). Behavioral evals in the
  skill-creator format for `verify` (planted failing bug → must end
  `VERDICT: FAIL — <reason>`; tests-green-but-CLI-wrong "sneaky" trap → must
  actually run the real thing and still FAIL; clean control → must PASS) and
  `work` (fixture `run-tests.sh` logs `RESULT` + impl hash per run, so
  red-before-impl is graded mechanically from `.check-log` vs `baseline-sha`).
  Iteration 1 executed for real (with-skill vs baseline, ~360k tokens
  total including a rerun of the with-skill arm against the v0.30.0 text
  after rebase): with_skill 10/10 + 8/8 assertions; baseline correct on
  analysis but broke the parseable verdict-line contract on all 3 verify
  evals; work evals non-discriminating vs baseline this iteration (both did
  red→green) — their gate value is regression detection on the skill text.
  Benchmarks committed under `skills/<name>/evals/benchmarks/2026-07-29/`;
  runbook in README (manual, never CI); fixtures captured as `type=fixture`
  learnings.
- **2026-07-30** — **P22 phase 2, pillar 2 shipped as v0.32.0** (async session
  B; renumbered twice at rebase — v0.30.0 went to the optimization release and
  v0.31.0 to pillar 1, the exact collision `briefs/README.md` warns about).
  Behavioral eval suites for `process` and `run` per the skill-creator
  harness: `skills/{process,run}/evals/` with 3 realistic prompts each,
  objective expectations, a committed deterministic `check.sh` grader
  (verified red on an untouched fixture, green on correct output, and red on
  adversarial output — a fabricated row and a silently rewritten rule), and
  the versioned `plate-audit` fixture repo (recipe captured as a
  `type=fixture` learning). One real iteration with fresh-context subagents:
  6/6 evals green, 49/49 assertions, ~237k subagent tokens (with-skill only —
  the release gate needs regression detection, not the value baseline);
  benchmarks committed under `evals/benchmarks/2026-07-29/`. Two findings,
  both in the *grader* rather than the skills: `process` §5 pins no
  Improvement-log entry format (`run` §4 does), so the grader over-specified
  `### <date>` and was loosened — tightening the skill text is a follow-up;
  and a dated assertion compared against the grading clock, so a correct run
  regraded after midnight failed (`check.sh` now pins the run date via
  `FW_EVAL_DATE`). The README's eval section now covers both pillars as one
  runbook. Runs manual-only pre-release, never CI. **P22 is now complete.**
- **2026-07-30** — **Measurement audit of v0.29.0–v0.32.0** (analysis session,
  no code changed). Reading the four releases against their committed evidence
  turned up one real A/B and three gaps, filed as P23–P25. What is measured:
  `verify` with-skill 10/10 assertions vs baseline 7/10 (+30 pp) — but the
  baseline got the *analysis* right in all three evals and failed only the
  parseable verdict-line contract, so the measured value is output discipline,
  not analytical ability; and the v0.30.0 description trim, 5,441 → 4,246 chars
  (−22.0%), reproducible with `git show c17e7bf^`. What is **not** measured:
  v0.30.0's two-tier telemetry, micro-cycle routing and `gate.sh seal` have no
  before/after at all (→ P23); the description saving has no ratchet (→ P24);
  `work`'s evals didn't discriminate and `process`/`run` have no baseline arm
  (→ P25). All benchmark iterations are n=1 — adequate as a regression gate,
  not as a value study, and the README should keep saying so.
- **2026-07-30** — **P24 shipped as v0.33.0.** The v0.30.0 description saving is
  now a ratchet: `scripts/check-description-budget.sh` sums the frontmatter
  `description` values across `skills/*/SKILL.md` (3,301 today) and fails above
  `scripts/description-budget.txt` (3,600 — roughly one average description of
  headroom, so one new skill is free and a second needs a deliberate bump).
  Developed red→green per the CLAUDE.md rule: the test failed with exit 127
  before the gate existed. Two design calls worth recording: the budget lives in
  its own file so a policy bump does not trip the script/test pairing gate; and
  malformed frontmatter (missing, empty, or a YAML folded `>` / `|` value) exits
  2 naming the skill rather than counting as 0, because a silent-zero parser
  could be used to evade the budget. Deliberately *not* included: a per-skill
  cap — the proposal names the total only, and a second rule is scope the spec
  didn't buy. Note the two ways to measure the same trim: 5,441 → 4,246 chars
  whole-line (the audit's figure) vs 3,301 values-only (what the gate sums).
- **2026-07-30** — **P25 implemented; release deliberately held.** Three gaps
  the P22 iteration named are closed in code. (a) `work`'s katas no longer hint
  the method: both prompts are now a plain feature request / bug report, and the
  runner requirement moved from the prompt into the fixture — `test_cart.py`
  refuses to import without `KATA_HARNESS=1`, which only `run-tests.sh` sets, so
  `.check-log` still exists for grading whichever arm runs. Verified by hand
  before the prompts lost their hint: direct `python3 -m unittest` aborts with a
  message naming the runner, and `./run-tests.sh` writes
  `RESULT=PASS IMPL_SHA=8b44f02e8e4f2e3b`, matching `baseline-sha`. The old
  benchmark is marked `SUPERSEDED.md` rather than deleted — it no longer matches
  `evals.json`, and the rewrite's discriminating power is **unverified** until an
  authorized run. (b) `process` §5 now pins the same
  `### <YYYY-MM-DD> — …` Improvement-log shape `run` §4 uses, and
  `evals/check.sh` re-tightens to require it — fixing the skill, which v0.32.0
  flagged as the real follow-up, instead of keeping the loosened grader. Verified
  red on a dated bullet, green on the heading, eval 3 exit 0. (c) The missing
  baseline arm is now a documented procedure in the README with its cost and an
  explicit *not run* status, so 49/49 green is never cited as skill value.
  **Why no bump:** CLAUDE.md requires the skill's eval to run *before* the
  version moves, and this diff touches `skills/process/SKILL.md`. That run needs
  fresh-context subagents and owner authorization, so v0.34.0 is reserved and
  unclaimed. CI stays green — `test-docs-consistency.sh` only requires the
  *current* version to have its note.
- **2026-07-30** — **P25 shipped as v0.34.0; eval gate run and green.** The
  `process` eval suite ran with fresh-context subagents against the P25 branch:
  3/3 evals, 39/39 assertions, ~133k subagent tokens, and — unlike 2026-07-29 —
  **no grader changes were needed**. The headline result is eval 3: with §5
  pinning `### <YYYY-MM-DD> — …`, the executor emitted that heading unprompted
  and the **re-tightened** assertion passed. v0.32.0 had loosened that exact
  check because the executor used a dated bullet; fixing the skill rather than
  the grader was the right direction and is now proven, not asserted.
  **A third gap surfaced while preparing the gate, worse than the two P25 knew
  about:** `skills/run/evals/check.sh` eval 2 (idempotent-upsert) passed on an
  **untouched fixture** — all three assertions were satisfied by the seed, so a
  run that did nothing scored 3/3 and the idempotency gate could never fail.
  v0.32.0's claim that the graders were "verified red on an untouched fixture"
  did not cover eval 2. It now requires the row's `audited` field to hold the run
  date and the datastore to be staged (DATA.md's own definition of landed), and
  was verified red on the untouched fixture, green on a correct simulated upsert,
  and red again on a duplicated row. Lesson for the ledger: *check every eval id
  for a vacuous pass, not a sample* — a grader that cannot fail is worse than no
  grader, because it reports confidence.
- **2026-07-30** — **P23 implemented; release deliberately held.** The open
  question is closed by owner decision: the transition line carries
  `cost: {bytes_out, tool_calls, elapsed_s}` — three mechanically observable
  proxies — and **no `tokens` field**, because a session cannot observe its own
  usage and a guessed number is precisely the unverifiable evidence P18 exists to
  keep out of the ledger. The ban is enforced rather than documented:
  `scripts/run-cost.sh` warns when it finds a `tokens` key. The proxies are
  labelled as proxies in both surfaces (the rendered cost block and the script's
  header), so `bytes_out` can never be misread as a token count later.
  `run-cost.sh <run.jsonl> [baseline.jsonl]` totals a run and prints the
  per-field delta with sign and percentage; a zero baseline prints `n/a` rather
  than a fake percentage. The load-bearing honesty rule: transitions with no
  `cost` object — every run from v0.16.0 to v0.32.0 — are reported as
  **UNMEASURED, never folded in as 0**, which would make old runs look free and
  flatter every comparison against them. Developed red→green (test failed with
  exit 127 first, 8 scenarios). **Why no bump:** the diff touches
  `skills/{work,loop,run,process}/SKILL.md` and three of those four have evals,
  so CLAUDE.md's gate applies; v0.35.0 is reserved and unclaimed. **What this
  still cannot tell you:** whether the proxies actually track token spend. That
  needs two comparable real cycles, and it is the first thing to do once this
  ships — otherwise P23 repeats P30's mistake of shipping an unverifiable cost
  claim, one level up.
- **2026-07-30** — **P23 shipped as v0.35.0; eval gate run across three
  suites.** 8/8 evals green, 57/57 assertions (`work` 8/8, `process` 39/39,
  `run` 10/10), ~356k subagent tokens. Two results worth keeping:
  **(1) The `run` suite is what actually verified the release, and the `work`
  suite could not.** `work`'s telemetry applies only inside a `/flywheel:loop`
  cycle, and its eval runs `work` standalone — both executors independently
  reported writing no JSONL for that reason — so its 8/8 proves only that the
  added text broke nothing. The `run` suite exercised the real thing: all three
  runs emitted a `cost` object on every transition of their own telemetry (14/14,
  14/14, 15/16), none emitted a `tokens` key, and `run-cost.sh` produced a real
  two-run delta (−1,143 bytes, −57.1%). Lesson: *check which suite actually
  covers the change before treating a green gate as verification* — a passing
  eval that cannot see the diff is not evidence about it.
  **(2) The unmeasured-≠-free safeguard fired on real data, unplanned.** One
  executor omitted `cost` from its closing `run_end` line; `run-cost.sh` reported
  1 UNMEASURED transition and an incompleteness note instead of counting it as 0.
  Follow-up: pin whether `run_end` carries its own cost or the run totals.
  Still open, and the reason this release is not self-congratulatory: **whether
  the proxies track real token spend is unverified.** Two comparable cycles are
  needed. Until then P23 has built the instrument, not the measurement.
- **2026-07-30** — **Causal evidence for P25's format pin, from an accident.**
  The `process` eval 3 ran the same day against both branches. On the P23 branch,
  whose §5 is unchanged, the executor emitted a dated **bullet**. On the P25
  branch, whose §5 pins the format, it emitted the **`### <date>` heading**. Same
  prompt, same model, same fixture, different skill text, different output — so
  the v0.32.0 grader loosening really was treating a skill defect as a grader
  problem, and pinning §5 fixed the cause. Recorded because neither spec planned
  this comparison; it fell out of running the two gates on the same day.
- **2026-07-30** — **The `work` kata does not discriminate, and the reason the
  last two attempts looked inconclusive was a leak I introduced.** After merging
  v0.34.0 into the P23 branch the katas became P25's de-hinted ones, which
  invalidated that branch's `work` benchmark, so it was re-run with a baseline
  arm. Both arms scored 100% — and one baseline executor volunteered why: the
  **fixture `README.md`, which is copied into the executor's workdir**, stated the
  grading rule verbatim ("the eval asserts from `.check-log` that the first logged
  run is `RESULT=FAIL` with `IMPL_SHA` equal to `baseline-sha`"). That is a
  stronger hint than the `./run-tests.sh` mention P25 removed from the prompt, and
  P25 *added* a paragraph to that same file explaining the guard. The de-hinting
  moved the leak instead of closing it.
  Fixed: grading rules now live in `skills/work/evals/README.md` (not copied,
  and executors are told not to read it), fixtures describe the scenario only,
  and the rule is written down — *nothing describing the assertions may live
  inside a fixture, and a fixture may not announce that it is one*; the second
  baseline flagged even "this is an eval fixture template" as telling it the run
  was graded. Re-ran the bugfix kata on the cleaned fixture: **still 4/4 vs 4/4.**
  So after three attempts the conclusion is that the kata measures the model, not
  the skill. Taking P25's own documented fallback: the suite is now labelled
  **regression-only** in the README instead of having its 100% presented as skill
  value. It still earns its keep — a future edit that stops inducing the red step
  drops the with-skill arm below 8/8 — but it is not evidence the skill adds
  anything on a kata this small.
  Also removed four `__pycache__/*.pyc` files that leaked into v0.34.0 from
  running the fixture suites in place while verifying the guard, and added
  `__pycache__/` + `*.pyc` to `.gitignore`; fixture templates must stay
  byte-identical.
- **2026-07-30** — **The `verify` fixtures contained the answer key; found while
  auditing pillar 1 for the same defect class as the `work` leak.** Each
  fixture's `README.md` is copied into the executor's workdir, and
  `tally-sneaky`'s named the defect's location, named the rationalization trap
  ("a verifier that only runs the tests and rationalizes from there will wrongly
  PASS") and stated the required verdict verbatim; `tally-fail`'s and
  `tally-pass`'s stated the correct verdict outright. **Both arms of the
  2026-07-29 iteration read it.** Cleaned in v0.36.0: fixtures now read as an
  ordinary repo, ground truth moved to `skills/verify/evals/README.md`, and
  `COMPROMISED.md` sits beside the old benchmark stating precisely what survives.
  What survives: the **+30 pp headline (10/10 vs 7/10) holds and is probably an
  understatement** — the leak stated the required `VERDICT: FAIL — <reason>`
  format verbatim and the baseline still closed in prose all three times, so the
  hint worked against that result. What does not survive: the bug-detection,
  evidence-citation and ran-the-real-CLI assertions, which both arms passed and
  which the benchmark already flagged as non-discriminating — now with a cause.
  The fixture's `specs/csv-tally.md` stays in the workdir: stating the success
  metric is the contract, not a leak.
  **The pattern is the lesson, and it is now twice-confirmed:** when a fixture is
  copied into the workdir, every file in it is part of the prompt. Both leaks were
  found only because an executor volunteered the contradiction; neither the specs
  nor the reviews caught them. Hence P26 — pillar 1 has no committed grader, so
  nobody can run "can this assertion fail?" the way the pillar-2 `check.sh` let me.
  **Open:** no iteration has run against the clean `verify` fixtures, so the
  bug-detection assertions currently have no trustworthy measurement at all.
- **2026-07-30 (same audit, continued)** — **Six leaks, not one, and the count
  only stopped because the check was re-run after every fix.** Beyond the three
  `verify` fixture READMEs: a comment in the `work` fixtures' `run-tests.sh`
  ("whether the impl was still pristine at red time is mechanically checkable"),
  the pillar-2 fixture READMEs announcing themselves as "Eval fixture for flywheel
  pillar-2 skills", and the `work` guard message added in v0.34.0 — mine, written
  the same day — saying the runner records "the audit log this kata is **graded**
  from". Every one of them is a file copied into the executor's workdir.
  The generalizable rule, now in both eval READMEs as a mandatory pre-iteration
  grep: **a fixture is a prompt, so audit every file in it, not just the obvious
  one — and re-run the audit after each fix, because fixing a leak is itself an
  edit that can add one.** I added two of these six while closing the first three.
- **2026-07-30** — **Shipped P26 (committed graders for pillar 1) as v0.37.0** —
  the sequencing dependency this backlog named: build the instrument, then
  measure. `skills/{verify,work}/evals/check.sh` now grade on pillar 2's
  contract (one `PASS:`/`FAIL:` per expectation, exit 0 only if all pass, exit 2
  on an unknown id), each mechanizing exactly the `expectations` already in its
  `evals.json` — deliberately no new assertion, so the pending `verify`
  iteration measures the skill and not a moved goalpost. `work` is graded from
  `.check-log` plus a behaviour probe and an independent suite re-run
  (`python3 -m unittest`, which does not append to the log it grades); `verify`
  from `report.md`/`transcript.md`, where a **missing artifact is a `FAIL:`
  naming the path** — a grader that passes on absence is worse than none,
  because it reads as evidence.
  Two CI gates, both aimed at how the previous defects were actually found —
  by accident. `scripts/test-eval-graders.sh` runs **all four** graders against
  an untouched fixture and requires red (the "can this assertion even fail?"
  question that exposed the hollow `run` eval-2 grader, now asked by the build),
  and requires the pillar-1 graders green on a synthesized ideal outcome so the
  mirror defect — a grader that can never pass — is caught too. Pillar 2's green
  side is deliberately not synthesized: writing a valid process contract in bash
  would reimplement the thing being graded, and the test prints that gap rather
  than implying coverage. `scripts/check-fixture-leaks.sh` promotes the manual
  pre-iteration grep to a gate: 14 vocabulary patterns over every file under
  `*/evals/fixtures/`, exemptions per **path *and* pattern with a written
  reason** in `scripts/fixture-leak-allow.txt` (6 entries, all `run-tests.sh`
  naming the `.check-log` it writes), stale exemptions failing, and
  `SKIP_FIXTURE_LEAKS=1` logged rather than silent. Its own test proves the
  allowlist is load-bearing by emptying it and requiring the real fixtures to
  fail — a vocabulary loose enough to let the runner through unaided would have
  let the `work` README leak through too.
  Built test-first per CLAUDE.md: both test scripts were written and seen red
  (graders absent, gate absent) before either implementation existed.
  Skill text is untouched, so P22 phase 2's eval-before-bump gate does not apply
  to this release — stated in the upgrade note rather than left as an inference.
  **Open (new, small):** the gate scans file *contents*, so the fixture file
  *named* `baseline-sha` is still a standing hint sitting in the executor's
  workdir. Its contents are an opaque hash; renaming it would change the `work`
  eval definition and invalidate the committed benchmark, so it is recorded in
  the allowlist header and both eval READMEs instead of quietly accepted. Worth
  folding into the next change that touches those fixtures for another reason.
  **Next per the sequencing note, now unblocked:** the `verify` iteration on the
  cleaned fixtures (3 evals × 2 arms), whose bug-detection assertions have had no
  trustworthy measurement since the answer-key leak.
