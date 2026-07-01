# flywheel 🎡

A Claude Code plugin that turns "vibe coding" into a **disciplined, self-verifying loop** for AI-assisted development. It distills the best practices from five reference projects — [obra/superpowers](https://github.com/obra/superpowers), [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin), [karpathy/autoresearch](https://github.com/karpathy/autoresearch), [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills), and [gszhangwei/open-spdd](https://github.com/gszhangwei/open-spdd) — into one coherent system.

## The idea: two nested loops

**Outer loop (development cycle)** — one unit of work flows through six phases, each with a gate:

```
spec → plan → work → verify → review → compound
 └── SPDD contract      │        │        └── learning capture (compound engineering)
        objective gate ─┴────────┘
```

**Inner loop (execution, inside `work`)** — a tight *write-failing-test → implement → run → observe → fix* cycle that never declares "done" until an objective check is green (TDD + metric-driven iteration + per-task gates).

Nothing advances on "seems right." Verification is a real gate (the `verifier` agent runs the actual app/tests), and every finished cycle deposits reusable knowledge into a ledger that primes the next one.

## Commands

| Command | What it does |
| --- | --- |
| `/flywheel:loop <feature>` | Run the whole cycle end to end, gating between phases. |
| `/flywheel:brainstorm <idea>` | Sharpen a fuzzy idea into agreed requirements before the spec. |
| `/flywheel:spec <feature>` | Write a REASONS spec-contract + a machine-checkable success metric. |
| `/flywheel:plan <spec-slug>` | Turn the spec into ordered tasks, each with its own check. |
| `/flywheel:work <task>` | Implement with the inner iterate-until-green loop. |
| `/flywheel:debug <symptom>` | Systematic debugging: reproduce → hypothesis → isolate → fix → regression test. |
| `/flywheel:verify` | Objective PASS/FAIL gate — runs the real app/tests (forks to the `verifier` agent). |
| `/flywheel:review <ref>` | Parallel correctness / security / performance review, synthesized. |
| `/flywheel:compound` | Append this cycle's decisions, gotchas, and patterns to the ledger. |
| `/flywheel:ship <title>` | Clean commit + push + PR to close out the cycle. |
| `/flywheel:autoloop <goal>` ⚡ | Autonomous metric-driven loop — iterate hands-off until a metric is met or a budget is spent. |
| `/flywheel:sync <spec-slug>` ⚡ | Reconcile drift between a spec and the code (bidirectional). |

## Agents

- `verifier` — runs the app/tests and returns an objective PASS/FAIL with evidence.
- `reviewer-correctness`, `reviewer-security`, `reviewer-performance` — adversarial specialist reviewers dispatched in parallel by `/flywheel:review`.

## State it keeps (in your project, versioned)

- `.claude/flywheel/specs/<slug>.md` — REASONS specs and `.plan.md` plans.
- `.claude/flywheel/LEARNINGS.md` — the compounding ledger. The `SessionStart` hook loads its most recent entries into context every session, so past lessons carry forward. It is created by `/flywheel:compound`, not shipped with the plugin.

## Deterministic completion gate (opt-in)

By default the phase gates are enforced by instructions plus the `verifier` agent. For a *hard* gate, drop an executable `.claude/flywheel/gate.sh` in your project containing your verification command:

```bash
#!/usr/bin/env bash
npm test && npm run lint
```

While that file exists, flywheel's `Stop` hook runs it whenever Claude tries to finish a turn and **blocks** finishing if it fails — so nothing is declared "done" with checks red. It is a no-op when the file is absent, bounded to a few consecutive blocks (so you are never trapped), and fails open on internal errors. Add `.claude/flywheel/.gate-state` to your `.gitignore`.

## Installation

flywheel is distributed through the [`xmarks`](https://github.com/arazvan-ec/xmarks) plugin marketplace. Add the marketplace and install it from any Claude Code session:

```
/plugin marketplace add arazvan-ec/xmarks
/plugin install flywheel@xmarks
```

Run `/reload-plugins` to pick it up in a running session, or `/plugin` to inspect it.

**Working inside the xmarks repo.** The repo's `.claude/settings.json` registers the marketplace and enables `flywheel@xmarks`, so collaborators who clone and trust the folder are prompted to install it. To test local changes to the plugin without committing, load it directly with `claude --plugin-dir ./plugins/flywheel`.
