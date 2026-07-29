---
name: spec
description: Turn a feature request into a REASONS spec-contract (Requirements, Entities, Approach, Structure, Operations, Norms, Safeguards) with one machine-checkable success metric. Use at the very start of a unit of work, before planning or writing code.
argument-hint: "[feature description]"
allowed-tools: Read, Grep, Glob, Write
---

# /flywheel:spec — spec-driven contract (the front of the loop)

Turn this request into a **contract**, not a suggestion: **$ARGUMENTS**

Prime from the repo's product definition when one exists (`PRODUCT.md`, or the north-star in `CLAUDE.md`/`AGENTS.md`) — the spec's Reasons must anchor in what the repo is building, and a feature the product definition doesn't cover starts by revising it in the same spec. Then prime from the SessionStart-injected learnings (pull specifics with `/flywheel:recall <topic>` — never read the whole ledger) and any related spec in `.claude/flywheel/specs/` for prior art. If the feature touches an entity the ledger has a `type=fixture` entry for (`/flywheel:recall fixture <entity>`), fold that setup recipe into the spec so planning starts with it rather than rediscovering it.

Produce a REASONS canvas and save it to `.claude/flywheel/specs/<slug>.md` (slug = short kebab-case name of the feature):

- **R — Requirements**: the user-facing goal and scope. What is explicitly in and out.
- **E — Entities**: the domain objects and their key fields/relationships (a small table or Mermaid diagram).
- **A — Approach**: the chosen strategy and the main trade-off vs. the alternative you rejected.
- **S — Structure**: the files/modules/components to add or change, and how they depend on each other.
- **O — Operations**: the concrete steps/functions to implement, in order.
- **N — Norms**: coding standards, patterns, and conventions to follow (match the existing codebase).
- **S — Safeguards**: constraints, failure modes, and guardrails (auth, secrets, rate limits, idempotency, data-loss risks).

Then define the **Success metric** — a single, objectively checkable pass condition (e.g. "all N tests pass and re-running the import changes 0 rows"). This is what `/flywheel:verify` checks against. If you cannot state a machine-checkable metric, the spec is not done.

GATE: present the spec and the metric, and get explicit sign-off before `/flywheel:plan`. Treat the signed spec as the contract; if reality later diverges, fix the spec first (see `/flywheel:sync`).

**At sign-off, materialize the metric's permission** (P21): the sign-off already approves running the metric command every cycle, so offer — in the same message as the gate, one question, once per repo — to append the matching rule (e.g. `Bash(npm test*)`) to `permissions.allow` in the project's `.claude/settings.json` (create file/key if needed, preserve everything else). On yes, write it and commit it with the spec so every future session inherits the grant; on no, drop it without argument. Never write it unasked — that settings write prompting IS the consent.
