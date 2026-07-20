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
| P17 | Setup/fixture knowledge as first-class compounded context | 🔵 proposed | New `fixture` learning type; `compound` captures stub/setup recipes; `spec`/`work` prime from them |

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
