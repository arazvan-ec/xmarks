---
name: process
description: Define or revise an agent-native process contract (fixed rules + output schema + persistence) for a recurring domain operation Claude runs as the backend. Use when a repeatable operation ('analyze a car', 'score a lead') should become something /flywheel:run executes.
argument-hint: "[process description, e.g. 'analyze a car by registration plate']"
allowed-tools: Read, Grep, Glob, Write, Edit, Bash
---

# /flywheel:process — define an agent-native process (Claude as the runtime)

Turn this recurring operation into a **process contract**, not one-off code: **$ARGUMENTS**

Prime, in order: the repo's product definition (`PRODUCT.md`, or the north-star in `CLAUDE.md`/`AGENTS.md`) — a contract's Purpose must name the business capability it implements; the SessionStart-injected learnings (`/flywheel:recall <topic>` for specifics — never the whole ledger); existing `.claude/flywheel/processes/*.md` for prior art; and `/flywheel:recall fixture <entity>` for the entities this process reads or writes, whose build recipe belongs in the contract's Inputs, tied to DATA.md.

## 1. Establish the repo's data strategy (once per repo)

Read `.claude/flywheel/DATA.md`. **If it is missing, create it first** — a process that cannot say where its results go is not done. Detect how this repo already persists data before asking the user, confirm the finding with them, and write DATA.md with its four parts: **Store**, **Access** (the one concrete command a run uses), **Schema**, and **Conventions** (idempotency key, timestamps, and never `DROP`/`DELETE`/`TRUNCATE` without explicit human confirmation).

The detection order and the full shape of each part: `skills/process/references/data-strategy-and-extensions.md`.

## 2. Interview for the fixed rules (only what's genuinely open)

Infer as much as you can from the description and the codebase; ask only what you cannot decide. Pin down: the inputs, the deterministic procedure, the exact output fields, and where results land.

## 3. Write the contract

Save to `.claude/flywheel/processes/<slug>.md` (slug = short kebab-case name), with this shape:

Save to `.claude/flywheel/processes/<slug>.md` (slug = short kebab-case name), following `skills/process/references/contract-template.md` exactly — read it now. Every section it defines is required; a contract missing one fails the graders.

Fill Rules, Output schema, and Persistence concretely — a vague contract yields a vague run. Leave **Improvement log** empty; `/flywheel:run` matures it.

## 4. Repo extensions (the repo defines how agents intervene)

A repo can extend *how* agents intervene in it beyond the fixed contract shape — runtime profiles, branch/PR policy, review gates. These conventions are **repo-owned**: they live in `.claude/flywheel/extensions/<name>.md`, never in this plugin. Before writing or revising a contract, read the repo's `extensions/` and declare the ones it honors in its frontmatter (`extensions: [profiles, …]`) — the contract owns its Rules, the extension owns the shared convention, neither duplicates the other. Detail: `skills/process/references/data-strategy-and-extensions.md`.

## 5. Maturing an existing process

If `$ARGUMENTS` names a process that already exists, this is a **deliberate revision**, never a recreation: apply the change, bump `version`, record it in the Improvement log, and **never silently rewrite the fixed rules**. The procedure and the log-entry shape — the same one `/flywheel:run` uses — are in `skills/process/references/data-strategy-and-extensions.md`.

GATE: present the contract (or the diff, when revising) and the data strategy, and get explicit sign-off. Then tell the user how to run it: `/flywheel:run <slug> <input>`. Stage the contract (and DATA.md) so it is committed with the work.

**At sign-off, materialize the datastore permission** (P21): approving the contract approves the write path DATA.md names, so offer — in the same message as the gate — to append the matching rule(s) (e.g. `Bash(psql:*)`, `Bash(npm run db:exec:*)` — always the `:*` suffix form, never a bare trailing `*`, which also matches unrelated longer commands) to `permissions.allow` in the project's `.claude/settings.json`, so `/flywheel:run` persists without re-prompting every run. On yes, write and commit with the contract; on no, drop it. Scope rules to the exact Access command from DATA.md — never a broad `Bash(*)`.
