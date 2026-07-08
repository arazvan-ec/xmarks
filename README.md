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
| `/flywheel:autoloop <goal>` ⚡ | Autonomous metric-driven loop — iterate hands-off until a metric is met or a budget is spent. |
| `/flywheel:sync <spec-slug>` ⚡ | Reconcile drift between a spec and the code (bidirectional). |
| `/flywheel:update [vendored\|marketplace]` | Update flywheel itself — autodetects marketplace vs vendored install, or takes the mode as an argument. |

## Agents

- `verifier` — runs the app/tests and returns an objective PASS/FAIL with evidence.
- `reviewer-correctness`, `reviewer-security`, `reviewer-performance` — adversarial specialist reviewers dispatched in parallel by `/flywheel:review`.

**Model routing by role** (v0.9.0): the mechanical `verifier` runs on **Haiku** (it runs commands and reports evidence); the judgment-heavy `reviewer-*` run on **Sonnet**. Override any agent via its `model:` frontmatter (e.g. a reviewer → `opus` for high-stakes reviews), or all at once with `CLAUDE_CODE_SUBAGENT_MODEL`.

## State it keeps (in the project you use it on)

- `.claude/flywheel/specs/<slug>.md` — REASONS specs and `.plan.md` plans.
- `.claude/flywheel/LEARNINGS.md` — the compounding ledger. Typed entries (`## <type>: <title>` + a greppable `<!-- fw: … -->` metadata line) let the `SessionStart` hook inject only a relevance-scored, budgeted subset (branch/files/recency, default top 12, `FLYWHEEL_LEARNINGS_INJECT` to override) instead of a blind reload; `/flywheel:recall <query>` reaches the rest on demand. Created by `/flywheel:compound`. Older free-prose entries still load, as always-eligible low-priority entries.

## Deterministic completion gate (opt-in)

Drop an executable `.claude/flywheel/gate.sh` in your project with your verification command (e.g. `npm test && npm run lint`). While it exists, flywheel's `Stop` hook runs it whenever Claude tries to finish and **blocks** finishing if it fails — so nothing is declared "done" with checks red. It is a no-op when absent, bounded to a few consecutive blocks (so you're never trapped), and fails open on internal errors.

## Repo layout

The plugin lives at the repo root: `.claude-plugin/` (manifest + marketplace), `skills/`, `agents/`, `hooks/`, `scripts/`. Setup guides are in [`docs/`](docs/), and [`upgrades/`](upgrades/) holds the per-version, AI-authored migration notes that `/flywheel:update` executes in installed repos (CI requires one per release).

Design research and the improvement backlog live in [`docs/research/`](docs/research/) — see [`improvement-proposals.md`](docs/research/improvement-proposals.md) for the living roadmap (P1–P6).
