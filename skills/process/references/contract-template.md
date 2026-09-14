# The process contract template

## What a process is

A *process* is a domain operation a traditional app would implement as a backend function. flywheel implements it instead as a **prompt-contract that Claude executes** (`/flywheel:run`): fixed rules the run must follow, a machine-checkable output schema, a persistence target in the repo's own datastore, and an improvement log that matures with every run. This is the agent-native pillar — the agent *is* the runtime, not a bolt-on (see `docs/research/agent-native-processes.md`).

Reference for `/flywheel:process` step 3. Write the contract to this shape
exactly — the graders check for every section named here.

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
`cost` proxies: bytes_out, bytes_in, tool_calls, elapsed_s — never tokens) to
.claude/flywheel/runs/<slug>/<date>.jsonl; the HTML report at
.claude/flywheel/runs/<slug>/<date>.html rendered from that JSONL only at
gates and at the final report, republished to a stable artifact URL. Chat
only for gates, blockers, and the final report. Fail-open: reporting never
blocks the run. Never include secrets.

## Improvement log
<!-- Append-only. /flywheel:run adds a dated entry when a run surfaces a durable
     refinement. Empty at creation. -->
```
