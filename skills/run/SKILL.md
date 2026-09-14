---
name: run
description: Execute a process contract as the runtime — follow its fixed rules, persist to the repo's datastore per DATA.md, prove the write, mature the contract. Use to run an operation defined with /flywheel:process; Claude is the backend.
argument-hint: "[process-slug] [input...]"
allowed-tools: Read, Edit, Write, Grep, Glob, Bash
---

# /flywheel:run — execute a process (Claude as the backend)

Run this process against the given input: **$ARGUMENTS**

You are the execution: follow the contract the way a service would.

## 0. Progress ledger (spans the whole run)

At run start, materialize each contract Rule as a visible task (one per Rule, in order) and update its state **at every transition**. Append one JSON line per transition to `.claude/flywheel/runs/<slug>/<date>.jsonl` — **never tokens, never secrets** — and render the HTML report from it only at gates/blockers and the final report. Chat is for gates, blockers and the final report. Fail-open: if the task system or publishing is unavailable, proceed and say so, never block the run. Mechanics: `skills/run/references/ledger-and-extensions.md`.

## 1. Load the contract and the data strategy

Parse the first token as the process slug and the rest as input. Read `.claude/flywheel/processes/<slug>.md`; if it is missing, stop and point the user to `/flywheel:process <description>` — do not improvise a contract. Read `.claude/flywheel/DATA.md` and the contract's own **Persistence** section, which overrides it. Honor every `extensions:` the frontmatter declares for the whole run — **an extension never overrides the contract's Rules, Output schema, or Guardrails**. They may add: `skills/run/references/ledger-and-extensions.md`.

## 2. Execute against the fixed rules

Follow **Rules (fixed contract)** step by step on the given input, under the conventions of every declared extension (namespacing, isolation, added inputs). Within **Judgment latitude** — and only there — apply reasoning; never let judgment override Rules, Output schema, or Guardrails. Produce a result that conforms **exactly** to the **Output schema** (every field, correct type). If an input is invalid or a rule cannot be satisfied, follow the Guardrails' partial-failure path and record it — do not fabricate fields to make the output look complete.

## 3. Persist per the repo's strategy — and prove it landed

Write the result to the store named in DATA.md / the contract's Persistence section, using the concrete tool it specifies (a `psql`/CLI command, a Postgres/Supabase MCP call, an ORM/repo script). Rules:

- **Idempotent** — upsert on the declared idempotency key; re-running the same input must not create duplicate rows.
- **Safe** — wrap multi-statement writes in a transaction; obey the destructive-operation ban (no `DROP`/`DELETE`/`TRUNCATE`/schema changes without explicit human confirmation).
- **Verified** — show the actual write (the SQL/tool call) and confirm it with evidence: affected-row count or a read-back of the row. A persist you did not observe landing does not count as done.

If the process declares a `metric`, dispatch the `evaluator` agent to independently check the persisted result against it before reporting success.

## 4. Reflect and mature the contract

After a successful run, spend one short reflection on whether the contract should get sharper — but **only on evidence from this run**, at most one refinement, and never drift for its own sake. What qualifies: `skills/run/references/ledger-and-extensions.md`.

If (and only if) something qualifies, append a dated entry to the contract's **Improvement log**:

```
### <YYYY-MM-DD> — <one-line what changed>
<why, from this run's evidence>
```

If the refinement changes the fixed Rules, Output schema, or Persistence, also bump the contract's `version` and edit the relevant section — the Improvement log records *why*, the sections stay the source of truth. Stage the contract if you changed it.

## 5. Report

Report tersely: the input, the key output fields, **where it persisted** (table + row id/keys, with the read-back evidence), the evaluator verdict if one ran, and any maturation. If a durable, cross-process lesson emerged (not process-specific), suggest `/flywheel:compound`.
