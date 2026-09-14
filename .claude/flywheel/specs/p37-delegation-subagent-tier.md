# Spec: P37 — TIER stands aside for a subagent whose tier is already pinned

**Slug:** `p37-delegation-subagent-tier` · **Created:** 2026-09-13 · **Backlog:** P37
**Status:** shipped as **v0.47.0** (PR #60) — 19 assertions green, and verified
independently of its own suite by running the pre-P37 script against the same
payload: it asks, the new one is silent, while an unresolvable `subagent_type`
and `create_session` both still ask.
**Prime:** owner report: `Agent` + `subagent_type: executor` (skills/work/SKILL.md:35)
trips a TIER ask on flywheel's own hot path even though every `agents/*.md`
pins `model:`/`effort:` in frontmatter. A guard that fires on a decision
already made teaches its reader to stop reading it.

## R — Requirements

1. `delegation-guard.sh`'s TIER check, for `Agent`/`Task` only, resolves
   `tool_input.subagent_type` to its agent definition and reads frontmatter
   `model:`/`effort:` before deciding what is `missing`.
2. A non-empty frontmatter `model:` decides the model; a non-empty `effort:`
   decides the effort — each independently, so a partially-pinned agent still
   asks for the unpinned half only.
3. Fail-open, unchanged, in every other case: no `subagent_type`, no
   resolvable file, unreadable file, or a field absent from frontmatter ⇒
   exactly today's behavior for that field.
4. `create_session` is untouched — it has no `subagent_type` and genuinely
   inherits the caller's model.
5. CONTEXT and FANOUT are untouched: a subagent with a fully pinned tier can
   still trip no-anchor, pasted-contract, duplicate, or width.
6. The header comment's premise is corrected to match: "opening a subagent
   without `model` always inherits" was false the moment agents started
   pinning their own tier.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| resolver | subagent_type → frontmatter model/effort | `scripts/delegation-guard.sh` (TIER section) |
| search order | vendored path, then plugin path | `$CLAUDE_PROJECT_DIR/.claude/agents/<n>.md`, then `<script dir>/../agents/<n>.md` |
| paired test | red→green assertions | `scripts/test-delegation-guard.sh` |

## A — Approach

Two path candidates, first hit wins: `scripts/install-vendored.sh:248` vendors
agents to `.claude/agents/`; the plugin's own tree has `agents/` beside
`scripts/`. Frontmatter parsed with one regex over the block between the
leading `---` and the next `---` — no YAML dependency, matching the file's
stdlib-only contract. `model`/`effort` resolved independently so a
half-pinned agent still asks for exactly the unpinned field. The `why`-text
branch explaining a missing `model` was coupled to the raw `tool_input.model`
field rather than to `missing`; left alone it would tell someone "the child
silently inherits" when only `effort` was undecided — so that branch now
reads `missing` instead.

This **narrows** a guard rather than widening one. That is correct here
specifically because the tier is not merely *likely* decided, it is decided:
`agents/*.md` frontmatter is the same file the runtime reads to launch the
subagent, so the guard and the launch cannot disagree. The residual is
deliberate: an agent definition with no `model:` still asks — this removes a
false positive, not the gate itself.

Rejected: trusting `subagent_type` alone as proof of a pinned tier (an agent
with no frontmatter model must still ask); a shared cache of agent tiers (one
file read is already cheap; a cache only adds staleness risk).

## S — Structure

- `scripts/delegation-guard.sh` — resolver in the TIER section, header comment
- `scripts/test-delegation-guard.sh` — new assertions, same file, same run

No release-owned files touched (plugin.json, upgrades/, agents/*.md, README,
hooks.json) — out of scope per the coordinator split.

## O — Operations

1. Add the new assertions to `test-delegation-guard.sh` first; run, see it
   fail (`executor's frontmatter pins model+effort; TIER must not ask`).
2. Add the resolver + `missing`/`why` changes to `delegation-guard.sh`.
3. Re-run; all assertions pass, including every one the test had before.
4. Run `check-test-pairing.sh`, `test-docs-consistency.sh`,
   `test-install-vendored.sh` — none touch surfaces this change doesn't;
   confirmed green.

## N — Norms

Bash + stdlib python3 only, no new dependency. Fail-open on any resolution
failure — the hook must never throw where it used to stay silent. The
resolver only ever *removes* an item from `missing`; it never adds one and
never turns an `ask` into a `deny`.

## S — Safeguards

- **Fail-open is the default**: unresolvable `subagent_type` (typo'd,
  deleted, unreadable) reproduces today's ask exactly — the "unknown
  subagent_type" assertion.
- **Independent fields**: an agent pinning only `model:` still asks for
  effort, and the ask no longer misclaims that the model itself inherits —
  the "model-only agent" assertion.
- **create_session unchanged**: a dedicated assertion pins that it still asks
  TIER with no model.
- Fixtures live under `mktemp -d`; the real `agents/` tree is only ever
  *read* (the executor happy-path case), never written.

## Success metric

One command, exit 0 = PASS:

```bash
bash scripts/test-delegation-guard.sh \
  && bash scripts/check-test-pairing.sh \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/test-install-vendored.sh
```
