# flywheel 🎡

A **Claude Code plugin** that turns ad-hoc "vibe coding" into a disciplined, self-verifying **loop** for AI-assisted development. It distills the best practices from [obra/superpowers](https://github.com/obra/superpowers), [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin), [karpathy/autoresearch](https://github.com/karpathy/autoresearch), [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills), and [gszhangwei/open-spdd](https://github.com/gszhangwei/open-spdd) into one coherent system.

This repository **is** the plugin, served through the `xmarks` marketplace (`.claude-plugin/marketplace.json`).

## Install (Claude Code)

```
/plugin marketplace add arazvan-ec/xmarks
/plugin install flywheel@xmarks
```

Then `/reload-plugins` and run `/flywheel:help`. To make flywheel **auto-activate** in a repo, see [docs/add-flywheel-to-a-repo.md](docs/add-flywheel-to-a-repo.md).

> **Claude Code only** — the claude.ai chat app uses a different Skills system and does not run Claude Code plugins.

> **Claude Code web** — web sessions do not auto-install marketplace plugins, so neither `/plugin install` nor the `settings.json` marketplace keys make `/flywheel:*` appear there. Instead, **vendor** flywheel into the target repo once with [`scripts/install-vendored.sh`](scripts/install-vendored.sh); the commands then work on every surface as `/flywheel-help`, `/flywheel-loop`, … See [docs/add-flywheel-to-a-repo.md](docs/add-flywheel-to-a-repo.md).

## The idea: two nested loops

**Outer loop (development cycle)** — one unit of work flows through six gated phases:

```
spec → plan → work → verify → review → compound
```

**Inner loop (inside `work`)** — a tight *write failing test → implement → run → observe → fix* cycle that never declares "done" until an objective check is green.

Nothing advances on "seems right": `verify` runs the real app/tests, and every finished cycle deposits reusable knowledge into a ledger that primes the next one.

> 📚 New to loops as a concept? See [docs/getting-started-with-loops.md](docs/getting-started-with-loops.md) — the four loop types (turn-based, goal-based, time-based, proactive) and how flywheel maps onto them.
>
> ⏱️ Want to run flywheel on a schedule or unattended? See [docs/proactive-loops.md](docs/proactive-loops.md) — composing `/flywheel:verify`/`review` with `/loop`, `/schedule` routines, `/goal`, and workflows.

## The second pillar: an agent-native runtime (v0.15.0)

The loop above **builds** software. The `process`/`run` pair lets flywheel also
**operate** it — turning the repo [agent-native](https://every.to/go-agent-native):
Claude is a first-class part of the runtime, not a bolt-on. Instead of writing a
static backend function for a recurring domain operation ("analyze a car", "score
a lead", "ingest a report"), you define a **process contract** and let Claude run it.

- `/flywheel:process <desc>` scaffolds `.claude/flywheel/processes/<slug>.md`: the
  **fixed rules** the operation always follows, its **output schema**, and where
  results **persist** — following the repo's *own* data strategy declared once in
  `.claude/flywheel/DATA.md` (e.g. Postgres via the repo's client), never a
  datastore flywheel imposes.
- `/flywheel:run <slug> [input]` executes the contract **as the backend**: follow
  the rules, apply judgment only where the contract allows, write the result to
  the datastore and *prove* it landed (idempotent, read-back verified), then
  **mature** the contract — appending one evidence-based refinement so the next
  run is sharper. Fixed rules + a self-improving prompt, exactly as asked.

Full vision + the worked car example: [`docs/research/agent-native-processes.md`](docs/research/agent-native-processes.md).

## Commands

| Command | What it does |
| --- | --- |
| `/flywheel:help` | Onboarding + command map. |
| `/flywheel:loop <feature>` | Run the whole cycle end to end, gating between phases. |
| `/flywheel:brainstorm <idea>` | Sharpen a fuzzy idea into agreed requirements before the spec. |
| `/flywheel:spec <feature>` | Write a REASONS spec-contract + a machine-checkable success metric. |
| `/flywheel:plan <spec-slug>` | Turn the spec into ordered tasks, each with its own check. |
| `/flywheel:work <task>` | Implement with the inner iterate-until-green loop. |
| `/flywheel:debug <symptom>` | Systematic debugging: reproduce → hypothesis → isolate → fix → regression test. |
| `/flywheel:verify` | Objective PASS/FAIL gate — runs the real app/tests (via the `verifier` agent). |
| `/flywheel:review <ref>` | Multi-specialist review routed by diff type (docs diff ≠ full fan-out), synthesized. |
| `/flywheel:compound` | Append this cycle's decisions, gotchas, and patterns to the ledger. |
| `/flywheel:recall <query>` | On-demand ledger search — list matching learnings cheaply, expand one on request. |
| `/flywheel:ship <title>` | Clean commit + push + PR to close out the cycle. |
| `/flywheel:process <desc>` | Define an **agent-native process** — a reusable prompt-contract (fixed rules + output schema + persistence) for a recurring domain operation Claude runs as the backend. |
| `/flywheel:run <slug> [input]` | Execute a defined process as the runtime — follow its rules, persist the result to the repo's datastore, then mature the contract from the run. |
| `/flywheel:autoloop <goal>` ⚡ | Autonomous metric-driven loop — iterate hands-off until a metric is met or a budget is spent. |
| `/flywheel:sync <spec-slug>` ⚡ | Reconcile drift between a spec and the code (bidirectional). |
| `/flywheel:update [vendored\|marketplace]` | Update flywheel itself — autodetects marketplace vs vendored install, or takes the mode as an argument. |

## Agents

- `verifier` — runs the app/tests and returns an objective PASS/FAIL with evidence.
- `reviewer-correctness`, `reviewer-security`, `reviewer-performance` — adversarial specialist reviewers dispatched in parallel by `/flywheel:review`.
- `evaluator` — independent cross-check dispatched by `/flywheel:autoloop` on ambiguous keep/discard results and before it declares its target met; re-runs the metric command itself instead of trusting the working agent's self-report.

**Model routing by role** (v0.9.0): the mechanical `verifier` runs on **Haiku** (it runs commands and reports evidence); the judgment-heavy `reviewer-*` run on **Sonnet**. Override any agent via its `model:` frontmatter (e.g. a reviewer → `opus` for high-stakes reviews), or all at once with `CLAUDE_CODE_SUBAGENT_MODEL`.

**Token discipline** (v0.12.0): `/flywheel:autoloop` treats its iteration budget as a hard stop and recommends piloting on a small budget before scaling; `/flywheel:help` points to `/usage`, `/goal`, and `/workflows` for spend visibility. See `skills/autoloop/SKILL.md`.

**Delegation triggers** (v0.13.0): `/flywheel:work` names advisory thresholds for handing off to a fresh-context subagent — reading 4+ files, touching 2+ non-trivial files, or ~20 tool calls deep without converging — to keep each turn's context lean.

**Live progress** (v0.16.0, two-tier since v0.30.0): every process run (`/flywheel:run`) and dev cycle (`/flywheel:loop`/`work`) materializes its steps as visible tasks in the host task system — states updated at every transition — and keeps per-execution telemetry at `.claude/flywheel/runs/<slug>/<date>.jsonl` (one appended JSON line per transition) plus an HTML report at `…/<date>.html`, rendered from the JSONL **only at gates and at close** and republished to a stable artifact URL. Output tokens are the expensive ones: a transition costs one line, never a regenerated page. Chat stays reserved for gates, blockers, and the final summary. Fail-open: reporting never blocks execution.

**Cycle cost, measured** (P23): each transition line carries a `cost` object — `bytes_out`, `tool_calls`, `elapsed_s` — and the rendered report ends with a cost block. These are **proxies, labelled as such everywhere they appear, never token counts**: a session cannot observe its own token usage, so recording one would put unverifiable evidence in the ledger (P18) — `scripts/run-cost.sh` warns if it finds a `tokens` key. `bash scripts/run-cost.sh <run.jsonl> [baseline.jsonl]` totals a run and prints the per-field delta against a baseline, so "this made the loop cheaper" becomes a number. Transitions from before the schema are reported as *unmeasured*, never counted as zero — otherwise every old run would look free.

## State it keeps (in the project you use it on)

- `.claude/flywheel/specs/<slug>.md` — REASONS specs and `.plan.md` plans.
- `.claude/flywheel/processes/<slug>.md` — agent-native **process contracts** (fixed rules + output schema + persistence + an append-only improvement log), created by `/flywheel:process` and matured by `/flywheel:run`.
- `.claude/flywheel/DATA.md` — the repo's data-persistence strategy (Store / Access / Schema / Conventions) that every `/flywheel:run` writes through, so results land the way the repo already stores them.
- `.claude/flywheel/LEARNINGS.md` — the compounding ledger. Typed entries (`## <type>: <title>` + a greppable `<!-- fw: … -->` metadata line; `type` ∈ `decision`/`gotcha`/`pattern`/`bugfix`/`fixture`) let the `SessionStart` hook inject only a relevance-scored, budgeted subset (branch/files/recency, default top 12, `FLYWHEEL_LEARNINGS_INJECT` to override) instead of a blind reload; `/flywheel:recall <query>` reaches the rest on demand. Created by `/flywheel:compound`. Older free-prose entries still load, as always-eligible low-priority entries.
  - **`fixture` entries** (v0.21.0) capture *how to set up the world* — the recipe to build a valid stub for a domain entity, seed the datastore, or stand up a test harness — the costliest thing a session otherwise re-derives. `/flywheel:work` offers to record one when it spends real effort building test data, and `/flywheel:spec` + `work` prime from any that match the task's entities before the rediscovery.
  - **Evidence-gated** (v0.25.0): flywheel gates *knowledge* the way it gates *code*. Each entry carries `evidence=` — what proved it (a test, a run/PR, a `command → result`). A lesson that can't point to a proof is written `evidence=unverified` explicitly, and the SessionStart injection + `/flywheel:recall` **flag** those so a wrong-but-plausible conclusion can never masquerade as proven context. `/flywheel:compound` records only what a cycle actually proved.
- `.claude/flywheel/runs/<slug>/<date>.jsonl` + `.html` — per-execution telemetry for process runs and dev cycles (v0.16.0): one JSONL line appended per state transition; the HTML report (task ledger + states, gates, unit telemetry, verdict) rendered from the JSONL only at gates and close (v0.30.0).

## Read-priming hook (advisory)

Before reading a file, a `PreToolUse` hook greps the ledger's `files=` metadata for that path and, if any typed entry names it, injects a short "prior learnings touch this file" note into context via the hook's `additionalContext` field (v0.18.0 — plain stdout is transcript-only and never reaches the model) — cheap context ahead of an expensive read. A bash pre-filter skips the python parser entirely for the no-match majority. It never blocks the read (unlike claude-mem's File Read Gate) and fails silently (no ledger, no match, or no `python3`) so it can never slow down or break a read.

## Approval-coherent permissions

flywheel has exactly two deliberate approval gates, and both are *conversational*: the spec sign-off and the plan approval. The harness's tool-permission layer knows nothing about them — so without help it re-asks "allow?" for actions the approval already implied. Two allow-only `PreToolUse` hooks close the gap; **everything they don't match keeps the normal permission flow**, and (docs-guaranteed) a hook "allow" can never override a deny/ask rule you wrote yourself. Both are fail-open by contract: they never deny, never ask, never block; malformed input or a missing `python3` just falls back to the ordinary prompt.

- **State writes** (v0.27.0, `Write|Edit|MultiEdit|NotebookEdit`): a write whose target resolves inside `<project>/.claude/flywheel/` is auto-allowed — specs, plans, the ledger, process contracts, run reports. Repo code and `.claude/settings.json` are out of scope. Paths are `realpath`-resolved before the containment check, so `..` traversal, prefix siblings (`.claude/flywheel-evil/`) and symlinks planted inside the state dir that point elsewhere get no grant.
- **Loop-advancing git** (v0.28.0, `Bash`): one plain `git add`, `git commit`, `git stash` (bare/`push`/`pop`/`list`), or a force-free `git push [-u] origin <branch>` where `<branch>` is the **current, non-default** branch — checked live against the repo. Any shell metacharacter outside single quotes (chaining, pipes, redirects, `$(…)`/backticks even inside double quotes) disqualifies the whole command, so `git commit -m "x" && anything` never rides the grant while a quoted `-m "fix: A & B"` passes. Global git flags (`-C`, `-c`, `--git-dir`), foreign remotes, refspecs, `--force*`, `stash drop/clear` and every other verb stay prompted.

The commands the plugin *cannot* know — your test/metric command, your `DATA.md` datastore write path — get their grant at the gate that approves them: `/flywheel:spec` and `/flywheel:process` **offer** at sign-off (never write unasked) to append the matching narrow rule (e.g. `Bash(npm test*)`) to the project's `.claude/settings.json` `permissions.allow`, committed with the spec/contract; `/flywheel:sync` flags signed pre-v0.28.0 specs/contracts that lack their rule as drift.

## Deterministic completion gate (opt-in)

Drop an executable `.claude/flywheel/gate.sh` in your project with your verification command (e.g. `npm test && npm run lint`). While it exists **and you've trusted it**, flywheel's `Stop` hook runs it whenever Claude tries to finish and **blocks** finishing if it fails — so nothing is declared "done" with checks red.

**Trust it first (v0.20.0)**: because the gate is a repo file that runs automatically, a PR could plant a malicious one — so an unrecognized gate is *not executed*. The first time it's seen, the hook prints the one command to trust it (a content hash stored **outside the repo**, so a PR can't self-authorize); editing the gate revokes trust until you re-consent. It is a no-op when absent, **skips re-running when the git-tracked working tree is byte-for-byte the last-passing state** (a `git`-derived signature over tracked + untracked content; non-git state like env vars or ignored files isn't observed, and it only ever skips a re-run — a changed tree always re-runs), bounded to a few consecutive blocks *per failing tree* with a *persisted* bypass (so a red gate never re-traps you), and fails open on internal errors.

**One suite run per cycle (v0.30.0)**: `/flywheel:verify` uses the project's `gate.sh` as its suite command when present, and after a PASS runs `gate.sh seal` — recording the passing tree's signature so the `Stop` hook cache-hits instead of re-running the same suite minutes later. Seal accepts the caller's evidence, never creates it: it refuses an untrusted gate (a planted gate can't arrive pre-passed) and covers exactly one tree signature — any change re-runs.

## Skill evals (manual release gate — not in CI)

Skills are prompts, so structural checks can't catch a behavioral regression — `verify` starting to rationalize a FAIL into a PASS, `work` skipping the red step, or `process` emitting a contract with no fixed rules. The skills where that hurts most carry behavioral evals in the skill-creator format, each with `evals.json` (realistic prompts + objective assertions), fixtures whose ground truth is known, and `benchmarks/<date>/` holding the committed evidence of the last graded iteration:

- **Pillar 1** — `skills/verify/evals/` and `skills/work/evals/`: planted-bug mini-repos under `evals/fixtures/`, graded by a committed `check.sh` (last-line `VERDICT:` regex over the saved `report.md`/`transcript.md`; `.check-log` first-FAIL-with-pristine-`IMPL_SHA`-then-PASS against `baseline-sha`, plus a behaviour probe and an independent suite re-run).
- **Pillar 2** — `skills/process/evals/` and `skills/run/evals/`: a versioned mini target repo (DATA.md + the trivial `plate-audit` contract + a seeded datastore, its setup recipe captured as a `type=fixture` learning) and a committed grader script `check.sh` that greps the artifacts the run left behind.

All four graders share one contract — `bash skills/<name>/evals/check.sh <id> <workdir>`, one `PASS:`/`FAIL:` line per expectation, exit 0 only if all pass, exit 2 on an unknown id — and each mechanizes exactly the expectations in its own `evals.json`. **Two CI gates keep them honest** (P26), because both defects they exist to catch were found by accident rather than by a check:

- `scripts/test-eval-graders.sh` runs every grader against an **untouched fixture** and requires a red — the question "can this assertion even fail?" is what exposed the hollow `run` eval-2 grader — and runs the pillar-1 graders against a synthesized ideal outcome to require a green, so a grader that can never pass is caught too. Pillar 2's green side is not synthesized (that would reimplement what it grades); its green evidence is the committed benchmarks.
- `scripts/check-fixture-leaks.sh` fails the build when a fixture file contains the assertion vocabulary (`VERDICT:`, `baseline-sha`, `IMPL_SHA`, "the eval asserts", "pristine", "eval fixture", …). Legitimate hits — `run-tests.sh` must name the `.check-log` it writes — are allowlisted per path *and* per pattern with a reason in `scripts/fixture-leak-allow.txt`; stale entries fail. Ground truth belongs in `skills/<name>/evals/README.md`, which is never copied into a workdir.

**When to run**: manually, before bumping the version on any release whose diff touches one of those skills. They are deliberately **not in CI** — one iteration costs roughly 300–800k tokens.

**How to run one iteration** (from a Claude Code session on this repo):

1. Instantiate the eval's fixture into a scratch workdir — copy the fixture (`files`) and substitute `{{WORKDIR}}` in the prompt (pillar 1), or run the eval's `setup` command into `W=$(mktemp -d)` (pillar 2). Never point a run at the fixture template itself.
2. Spawn a **fresh-context** subagent per run, told to read `skills/<name>/SKILL.md` and execute it as if the user had invoked the eval's prompt, with every repo-relative path resolved against the workdir. Pillar 2 briefs add eval mode: gates are pre-approved and the host task system / artifact publishing are unavailable, so the skill's fail-open paths apply — the telemetry report still gets written. A baseline (no-skill) run per eval is optional: it measures the skill's *value*, while the release gate only needs the with-skill regression signal.
   - **`verify`: name the write mechanism in the brief.** Subagent harnesses can refuse `Write` on files they classify as reports, so instruct the executor to write `report.md` / `transcript.md` with a **Bash heredoc** and to confirm both are non-empty before finishing. State it **identically in both arms** — it is plumbing, and it hints at nothing. A first attempt on 2026-07-30 was voided precisely here: whether an executor routed around the block correlated with the arm, so the delta would have measured that instead of verification discipline (`benchmarks/2026-07-30/VOID-attempt-1.md`).
   - Any assertion that reads an artifact needs the brief to guarantee the artifact can exist. Otherwise an unproduced artifact is indistinguishable from a skill failure.
3. Grade with the skill's committed grader — `bash skills/<name>/evals/check.sh <id> "$W"` for all four skills now (one PASS/FAIL line per expectation, exit 0 = all green). Pillar 2: export `FW_EVAL_DATE=<run date>` when regrading a workdir on a later day. Pillar 1 `verify`: the grader reads `report.md` and `transcript.md` from the workdir root — save them there, or point `FW_EVAL_REPORT` / `FW_EVAL_TRANSCRIPT` at them. Never grade by re-deriving regexes by hand: that is how a vacuous assertion survives.
4. Aggregate into `benchmark.json`/`benchmark.md` (skill-creator schema) and commit them under `skills/<name>/evals/benchmarks/<date>/` as the release evidence.

A regression (with-skill pass rate below the committed benchmark, or any planted-bug eval rationalized into a PASS) blocks the release until the skill text is fixed.

### The baseline arm (value study) — run for `verify`, not yet for `process`/`run`

The release gate needs only the with-skill arm: it answers "did this skill text regress?". A **baseline arm** — the same eval run by a subagent that is *not* given the skill — answers a different and unanswered question: "is this behavior the skill's, or would a strong model do it anyway?". Run it as a deliberate study, never as part of a release:

1. Same fixture instantiation as step 1 above, into a separate workdir per arm so the two never share state.
2. Spawn the baseline subagent with the eval's prompt **and no reference to `skills/<name>/SKILL.md`** — no summary of it, no paraphrase. Everything else (eval-mode briefing, pre-approved gates, path resolution) stays identical, or the comparison measures the briefing instead of the skill.
3. Grade both arms with the same grader and record them as two `configuration` values (`with_skill`, `without_skill`) in one `benchmark.json`, as the pillar-1 benchmarks do.
4. Report the delta per assertion, not just per eval — a tie on pass rate can still hide which specific contract the baseline broke.

**`verify`: measured 2026-07-30 on the clean fixtures, and the answer is narrow.** With-skill **11/11** assertions across the 3 evals, baseline **8/11** (+0.29 pass rate). All three baseline runs failed *exactly one* assertion — the machine-parseable `VERDICT:` last line — and passed every other one. The baseline is **not** weak at verifying: it found the planted slice, found the double header subtraction, explained unprompted why green unit tests carry no information about a CLI metric, and ran 5-mutant mutation testing on the clean control. What the skill demonstrably supplies is the *contract* — a verdict a gate can read without a human — not the analysis. Cite it that way. The evidence-citation, ran-the-real-CLI and no-rationalized-PASS assertions passed in both arms and are regression guards, not skill value; that is now a measured conclusion rather than one the leak forced us to withhold. Evidence: `skills/verify/evals/benchmarks/2026-07-30/`, which supersedes the leak-tainted 2026-07-29 run. Cost: ~264k subagent tokens for both arms, ~6 runs.

**Status: not run for `process`/`run`.** Their committed iteration is with-skill only (~237k tokens), so their 49 green assertions are a regression baseline and **not** evidence that the skills beat an unaided model. Cost of closing that gap is roughly 120k tokens per skill. Until it is run, do not cite pillar-2 pass rates as skill value.

**`work`'s katas are regression-only, and that is now a measured conclusion rather than a caveat.** Three iterations tried to make them discriminate and all three tied at 100%: the v0.31.0 run (prompt named `./run-tests.sh`), the P25 run (prompt de-hinted, but the fixture README still stated the grading rule verbatim), and the 2026-07-30 run with that leak removed and the fixture reading like an ordinary repo — where the baseline **still** wrote the regression test first, ran it red against a pristine `cart.py`, and only then fixed it. A strong model does test-first on a kata this small whether or not the skill says so. That is a fact about the task, not a defect in the skill, and citing the 100% as skill value would be the kind of unverifiable claim these evals exist to remove. What the suite still earns its cost for: if a future edit to `work/SKILL.md` stops inducing the red step, the with-skill arm drops below 8/8 and that is a real regression signal. Evidence: `skills/work/evals/benchmarks/2026-07-30/benchmark.json`.

## Repo layout

The plugin lives at the repo root: `.claude-plugin/` (manifest + marketplace), `skills/`, `agents/`, `hooks/`, `scripts/`. Setup guides are in [`docs/`](docs/), and [`upgrades/`](upgrades/) holds the per-version, AI-authored migration notes that `/flywheel:update` executes in installed repos (CI requires one per release).

Design research and the improvement backlog live in [`docs/research/`](docs/research/) — see [`improvement-proposals.md`](docs/research/improvement-proposals.md) for the living roadmap (P1–P6).
