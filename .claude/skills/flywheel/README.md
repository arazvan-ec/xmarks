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
| `/flywheel:spec <feature>` | Write a REASONS spec-contract + a machine-checkable success metric. |
| `/flywheel:plan <spec-slug>` | Turn the spec into ordered tasks, each with its own check. |
| `/flywheel:work <task>` | Implement with the inner iterate-until-green loop. |
| `/flywheel:verify` | Objective PASS/FAIL gate — runs the real app/tests (forks to the `verifier` agent). |
| `/flywheel:review <ref>` | Parallel correctness / security / performance review, synthesized. |
| `/flywheel:compound` | Append this cycle's decisions, gotchas, and patterns to the ledger. |
| `/flywheel:autoloop <goal>` ⚡ | Autonomous metric-driven loop — iterate hands-off until a metric is met or a budget is spent. |
| `/flywheel:sync <spec-slug>` ⚡ | Reconcile drift between a spec and the code (bidirectional). |

## Agents

- `verifier` — runs the app/tests and returns an objective PASS/FAIL with evidence.
- `reviewer-correctness`, `reviewer-security`, `reviewer-performance` — adversarial specialist reviewers dispatched in parallel by `/flywheel:review`.

## State it keeps (in your project, versioned)

- `.claude/flywheel/specs/<slug>.md` — REASONS specs and `.plan.md` plans.
- `.claude/flywheel/LEARNINGS.md` — the compounding ledger. The `SessionStart` hook loads its most recent entries into context every session, so past lessons carry forward. It is created by `/flywheel:compound`, not shipped with the plugin.

## How it is installed here

This plugin lives at `.claude/skills/flywheel/` and loads automatically as **`flywheel@skills-dir`** on the next session once you trust the workspace folder — no marketplace and no install step. Run `/reload-plugins` to pick it up in an already-running session, or `/plugin` to inspect it. Because it is checked into the repo, every collaborator who clones and trusts the folder gets it.

**Distributing it elsewhere (optional).** To share flywheel with other repos, publish this directory as its own git repo and add a `.claude-plugin/marketplace.json` that points at it, then install with `/plugin marketplace add <repo>` + `/plugin install flywheel@<marketplace>`.
