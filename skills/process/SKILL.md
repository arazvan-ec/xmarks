---
name: process
description: Define or revise an agent-native process contract (fixed rules + output schema + persistence) for a recurring domain operation Claude runs as the backend. Use when a repeatable operation ('analyze a car', 'score a lead') should become something /flywheel:run executes.
argument-hint: "[process description, e.g. 'analyze a car by registration plate']"
allowed-tools: Read, Grep, Glob, Write, Edit, Bash
---

# /flywheel:process — define an agent-native process (Claude as the runtime)

Turn this recurring operation into a **process contract**, not one-off code: **$ARGUMENTS**

A *process* is a domain operation a traditional app would implement as a backend function. flywheel implements it instead as a **prompt-contract that Claude executes** (`/flywheel:run`): fixed rules the run must follow, a machine-checkable output schema, a persistence target in the repo's own datastore, and an improvement log that matures with every run. This is the agent-native pillar — the agent *is* the runtime, not a bolt-on (see `docs/research/agent-native-processes.md`).

Prime from the repo's product definition when one exists (`PRODUCT.md`, or the north-star in `CLAUDE.md`/`AGENTS.md`) — a contract's Purpose must name the business capability it implements. Then prime from the SessionStart-injected learnings (`/flywheel:recall <topic>` for specifics — never read the whole ledger) and any existing `.claude/flywheel/processes/*.md` for prior art and house conventions. For the entities this process reads or writes, check for `type=fixture` entries (`/flywheel:recall fixture <entity>`) — the recipe to build a valid instance belongs in the contract's Inputs/persistence, tied to DATA.md.

## 1. Establish the repo's data strategy (once per repo)

Read `.claude/flywheel/DATA.md`. **If it is missing, create it first** — a process that cannot say where its results go is not done. Detect how this repo persists data before asking the user, by looking for (in order): `DATABASE_URL`/`*_DATABASE_URL` env or `.env(.example)`, `prisma/schema.prisma`, `drizzle.config.*`, `knexfile.*`, `sequelize`/`typeorm` config, `supabase/config.toml`, a `postgres`/`mysql` service in `docker-compose*.yml`, `*.sql` migrations, or an ORM in `package.json`/`requirements.txt`/`pyproject.toml`. Confirm the finding with the user; only ask open-ended if nothing is detectable.

Write `.claude/flywheel/DATA.md` with:
- **Store** — the backend (e.g. `PostgreSQL`).
- **Access** — exactly how a run writes to it: the concrete tool/command (`psql "$DATABASE_URL"`, a Postgres/Supabase MCP server + project ref, `npm run db:exec`, an ORM script…). Name the one a run should use.
- **Schema** — the tables/columns processes read and write, or a pointer to the migrations that define them.
- **Conventions** — idempotency key, timestamps, a `flywheel_runs` metadata table if the repo wants run bookkeeping, and safety rules (transactions; never `DROP`/`DELETE`/`TRUNCATE` without explicit human confirmation).

## 2. Interview for the fixed rules (only what's genuinely open)

Infer as much as you can from the description and the codebase; ask only what you cannot decide. Pin down: the inputs, the deterministic procedure, the exact output fields, and where results land.

## 3. Write the contract

Save to `.claude/flywheel/processes/<slug>.md` (slug = short kebab-case name), with this shape:

```
---
name: <slug>
kind: process
version: 1
created: <YYYY-MM-DD>          # from `date +%F`
persistence: <e.g. postgres:public.car_analyses — or "see DATA.md">
metric: <optional: a machine-checkable pass condition for one run>
---

# Process: <Title>

## Purpose
The operation and the backend function it replaces.

## Inputs
Each argument /flywheel:run takes — name, type, required/optional, example.

## Rules (fixed contract)
The deterministic, numbered procedure a run MUST follow. This is the part that
does NOT drift between runs. Be specific enough that two runs on the same input
produce the same structured result.

## Output schema
The exact structured result — field, type, constraint — mapped 1:1 to the
persistence columns. This is what makes a run checkable.

## Persistence
Table + column mapping, the idempotency key, and the connection/tool from
DATA.md. State the read-back or affected-rows check that proves the write landed.

## Judgment latitude
Where Claude is expected to apply reasoning BEYOND the fixed rules — the analysis
quality the user wants improved over time. Bounded: it enriches the output, it
never overrides Rules, Output schema, or Guardrails.

## Guardrails
Validation, PII handling, idempotency, what to do on partial failure, and the
destructive-operation ban from DATA.md.

## Progress reporting
How /flywheel:run shows this process live: one host-task per Rule updated at
every state transition; one JSON line appended per transition (including its
`cost` proxies: bytes_out, tool_calls, elapsed_s — never tokens) to
.claude/flywheel/runs/<slug>/<date>.jsonl; the HTML report at
.claude/flywheel/runs/<slug>/<date>.html rendered from that JSONL only at
gates and at the final report, republished to a stable artifact URL. Chat
only for gates, blockers, and the final report. Fail-open: reporting never
blocks the run. Never include secrets.

## Improvement log
<!-- Append-only. /flywheel:run adds a dated entry when a run surfaces a durable
     refinement. Empty at creation. -->
```

Fill Rules, Output schema, and Persistence concretely — a vague contract yields a vague run. Leave **Improvement log** empty; `/flywheel:run` matures it.

## 4. Repo extensions (the repo defines how agents intervene)

A repo can extend *how* agents intervene in it beyond the fixed contract shape — runtime profiles for multiple competing AIs, branch/PR policy, review gates, capability fallbacks. These conventions are **repo-owned**: they live in `.claude/flywheel/extensions/<name>.md`, versioned and matured with the repo — never hardcoded in this plugin.

- An extension doc states: `name`, `applies-to` (all processes or named slugs), the inputs/conventions it adds, its guardrails, and its own append-only Improvement log.
- Before writing or revising a contract, read the repo's `extensions/`; declare the ones the contract honors in its frontmatter (`extensions: [profiles, …]`). The contract stays the source of truth for its Rules; the extension is the source of truth for the shared convention — don't duplicate its text into every contract.
- When the owner asks for a **cross-cutting intervention pattern** (e.g. "the same process run by different AI runtimes with comparable outputs"), the deliverable is an extension doc, not per-contract prose — write it, wire it via frontmatter, and let runs mature it in place.

## 5. Maturing an existing process

If `$ARGUMENTS` names a process that already exists, do not recreate it — treat this as a **deliberate revision**: read the contract and its Improvement log, apply the requested change to Rules/Output schema/Persistence, bump `version`, and record the change (what and why) in the Improvement log. Never silently rewrite the fixed rules.

GATE: present the contract (or the diff, when revising) and the data strategy, and get explicit sign-off. Then tell the user how to run it: `/flywheel:run <slug> <input>`. Stage the contract (and DATA.md) so it is committed with the work.

**At sign-off, materialize the datastore permission** (P21): approving the contract approves the write path DATA.md names, so offer — in the same message as the gate — to append the matching rule(s) (e.g. `Bash(psql*)`, `Bash(npm run db:exec*)`) to `permissions.allow` in the project's `.claude/settings.json`, so `/flywheel:run` persists without re-prompting every run. On yes, write and commit with the contract; on no, drop it. Scope rules to the exact Access command from DATA.md — never a broad `Bash(*)`.
