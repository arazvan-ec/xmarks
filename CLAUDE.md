# CLAUDE.md — flywheel repo north-star

This repo **is** the `flywheel` Claude Code plugin (served via the `xmarks`
marketplace). Read this before working here so you understand what the owner is
building and the rules that keep releases consistent.

## What flywheel is becoming: agent-native, in two pillars

The direction (owner intent, 2026-07-10) is to make flywheel help every repo it's
installed in become **agent-native** — the agent is a first-class part of the
runtime, not bolted on (https://every.to/go-agent-native). Concretely, flywheel
has **two pillars**:

1. **Build the software** — the disciplined dev loop:
   `spec → plan → work → verify → review → compound` (+ `debug`, `autoloop`,
   `review`, `sync`, `ship`, `recall`). Claude is the *developer*.
2. **Operate the software** — the agent-native runtime:
   `/flywheel:process` defines a reusable **process contract** for a recurring
   domain operation (e.g. "analyze a car") and `/flywheel:run` executes it with
   Claude *as the backend* — following the contract's **fixed rules**, applying
   **judgment** where the contract allows, **persisting** the result to the
   repo's own datastore (per `.claude/flywheel/DATA.md`), and **maturing** the
   contract from each run's evidence. No static code backend — Claude is the
   execution. See [`docs/research/agent-native-processes.md`](docs/research/agent-native-processes.md)
   for the full vision + the owner's original ask.

When the owner asks for "a new process/idea", the deliverable is a **process
contract** (`/flywheel:process`), not one-off code: fixed rules + a maturation
loop that Claude improves with each execution.

## State flywheel keeps (in the repo it's used on)

- `.claude/flywheel/specs/<slug>.md` — REASONS specs + `.plan.md` plans (pillar 1).
- `.claude/flywheel/LEARNINGS.md` — the compounding, cross-cutting ledger.
- `.claude/flywheel/processes/<slug>.md` — process contracts (pillar 2).
- `.claude/flywheel/DATA.md` — the repo's data-persistence strategy that runs follow.

## Repo conventions (do not skip — CI enforces them)

- The plugin lives at the repo root: `.claude-plugin/` (manifest + marketplace),
  `skills/`, `agents/`, `hooks/`, `scripts/`.
- **Every change to `skills/`, `agents/`, `hooks/`, or `scripts/` is a release**:
  bump `.claude-plugin/plugin.json` `version`, add `upgrades/v<version>.md`
  (frontmatter `version` / `requires-action: true|false` / `summary:`, a
  `## What changed`, and a `## Strategy` only when `requires-action: true`).
- **A new skill must be listed in BOTH** the README command table **and** the
  `/flywheel:help` map — `scripts/test-docs-consistency.sh` fails otherwise. Every
  agent must be mentioned in the README.
- Run before pushing: `bash scripts/test-docs-consistency.sh`,
  `bash scripts/test-install-vendored.sh`, and `claude plugin validate . --strict`
  if the CLI is available.
- Design/roadmap discussion lives in [`docs/research/`](docs/research/) —
  `improvement-proposals.md` (living backlog + decision log) and `journal.md`.
- Keep `marketplace.json` and `plugin.json` descriptions in sync when the surface
  changes.
