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
| `/flywheel:review <ref>` | Parallel correctness / security / performance review, synthesized. |
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
- `evaluator` — independent cross-check dispatched by `/flywheel:autoloop` before it keeps/discards an iteration or declares its target met; re-runs the metric command itself instead of trusting the working agent's self-report.

**Model routing by role** (v0.9.0): the mechanical `verifier` runs on **Haiku** (it runs commands and reports evidence); the judgment-heavy `reviewer-*` run on **Sonnet**. Override any agent via its `model:` frontmatter (e.g. a reviewer → `opus` for high-stakes reviews), or all at once with `CLAUDE_CODE_SUBAGENT_MODEL`.

**Token discipline** (v0.12.0): `/flywheel:autoloop` treats its iteration budget as a hard stop and recommends piloting on a small budget before scaling; `/flywheel:help` points to `/usage`, `/goal`, and `/workflows` for spend visibility. See `skills/autoloop/SKILL.md`.

**Delegation triggers** (v0.13.0): `/flywheel:work` names advisory thresholds for handing off to a fresh-context subagent — reading 4+ files, touching 2+ non-trivial files, or ~20 tool calls deep without converging — to keep each turn's context lean.

## State it keeps (in the project you use it on)

- `.claude/flywheel/specs/<slug>.md` — REASONS specs and `.plan.md` plans.
- `.claude/flywheel/processes/<slug>.md` — agent-native **process contracts** (fixed rules + output schema + persistence + an append-only improvement log), created by `/flywheel:process` and matured by `/flywheel:run`.
- `.claude/flywheel/DATA.md` — the repo's data-persistence strategy (Store / Access / Schema / Conventions) that every `/flywheel:run` writes through, so results land the way the repo already stores them.
- `.claude/flywheel/LEARNINGS.md` — the compounding ledger. Typed entries (`## <type>: <title>` + a greppable `<!-- fw: … -->` metadata line) let the `SessionStart` hook inject only a relevance-scored, budgeted subset (branch/files/recency, default top 12, `FLYWHEEL_LEARNINGS_INJECT` to override) instead of a blind reload; `/flywheel:recall <query>` reaches the rest on demand. Created by `/flywheel:compound`. Older free-prose entries still load, as always-eligible low-priority entries.

## Read-priming hook (advisory)

Before reading a file, a `PreToolUse` hook greps the ledger's `files=` metadata for that path and, if any typed entry names it, prints a short "prior learnings touch this file" note first — cheap context ahead of an expensive read. It never blocks the read (unlike claude-mem's File Read Gate) and fails silently (no ledger, no match, or no `python3`) so it can never slow down or break a read.

## Deterministic completion gate (opt-in)

Drop an executable `.claude/flywheel/gate.sh` in your project with your verification command (e.g. `npm test && npm run lint`). While it exists, flywheel's `Stop` hook runs it whenever Claude tries to finish and **blocks** finishing if it fails — so nothing is declared "done" with checks red. It is a no-op when absent, bounded to a few consecutive blocks (so you're never trapped), and fails open on internal errors.

## Repo layout

The plugin lives at the repo root: `.claude-plugin/` (manifest + marketplace), `skills/`, `agents/`, `hooks/`, `scripts/`. Setup guides are in [`docs/`](docs/), and [`upgrades/`](upgrades/) holds the per-version, AI-authored migration notes that `/flywheel:update` executes in installed repos (CI requires one per release).

Design research and the improvement backlog live in [`docs/research/`](docs/research/) — see [`improvement-proposals.md`](docs/research/improvement-proposals.md) for the living roadmap (P1–P6).
