# Spec: P17 — Setup/fixture knowledge as first-class compounded context

**Slug:** `p17-fixture-knowledge` · **Created:** 2026-07-20 · **Backlog:** P17
**Status:** signed 2026-07-20 (owner) · shipped as v0.21.0 — option 2 + owner's evidence-gate amendment; metric PASS; review SHIP (0 Critical/High, 2 Low, key no-plumbing-change claim empirically confirmed)
**Prime:** LEARNINGS.md (SessionStart-injected subset; the seeded `fixture`
entry — the hook-test recipe — is the reference shape). Source: the owner's ask
(P17 in the backlog) — "the costliest thing a session rediscovers is how to set
up the world: how to build a valid stub/fixture for a domain entity."

## R — Requirements

Make **setup/fixture knowledge** a first-class citizen of the memory pillar, so
every intervention captures "how to build one" and the next intervention gets
it as context *before* it starts rediscovering.

1. **A `fixture` learning type.** Alongside `decision`/`gotcha`/`pattern`/
   `bugfix`: a named entity or harness + the concrete recipe to construct a
   valid instance, and the fields/relationships easy to get wrong. (The owner's
   example: an editorial stub for `detalles`, for `homeTag`, for `amazononsite`.)
2. **`compound` captures it.** At cycle close, explicitly prompt for fixture/
   setup knowledge — "did we discover how to build a stub, seed data, or stand
   up a harness a future cycle shouldn't re-derive?" — and write it as a
   `type=fixture` entry with the entity name(s) in `files=`/title so the
   existing scorer can find it.
3. **`spec` and `work` prime from it.** Their prime steps surface any
   `type=fixture` entries whose entity/files intersect the task, so setup
   recipes are in context before work — not after the rediscovery. `recall`
   already lets a query match on `type=fixture`; no recall change needed.
4. **`process` (pillar 2) can reference fixtures** for the entities a contract
   reads/writes, tying setup knowledge to DATA.md.
5. **A capture trigger in `work`** (owner-selected: the "always" part). An
   advisory threshold — the same shape as `work`'s existing delegation triggers
   — that fires when a task spends significant effort standing up test data /
   fixtures (e.g. ~2+ non-trivial stub files or ~5 tool calls building a
   harness): *offer* to record a `fixture` entry so the recipe isn't lost to
   the next cycle. Advisory only (offers, never forces; never blocks the loop).
6. **Docs**: README's ledger/state description and `/flywheel:help` name the
   `fixture` type so users know it exists and when it fires.

**Out of scope:** any change to `session-start.sh` scoring or `recall` (both are
type-agnostic already — the new type flows through unchanged); a hard/enforced
trigger (the `work` prompt is advisory by design); a new datastore.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| `fixture` entry | `## fixture: <entity/harness> — <one-line>` + `<!-- fw: type=fixture; date=…; files=…; … -->` + a recipe body | `.claude/flywheel/LEARNINGS.md` (per-repo state) |
| Type list | the enumerated set `compound` writes | `skills/compound/SKILL.md` |
| Prime step | surfaces intersecting `fixture` entries | `skills/spec`, `skills/work` |

## A — Approach

Prompt-text edits only — the memory pillar's plumbing (typed entries, budgeted
injection, grep-based recall) already carries an arbitrary `type=`; P17 is about
*naming* one type, *prompting* to capture it, and *prompting* to consume it. No
script or scoring change — verified: `session-start.sh` scores by files/branch/
recency (type-agnostic) and `recall` greps the metadata (matches `type=fixture`
today). Rejected: a hook that detects fixture-building and auto-writes an entry
(runtime surface + false positives; the compound prompt is enough for v1, and
the auto-trigger is logged as an open question).

## S — Structure

- `skills/compound/SKILL.md` — add `fixture` to the type list + a capture prompt.
- `skills/spec/SKILL.md`, `skills/work/SKILL.md` — prime steps surface
  intersecting `fixture` entries; `work` also gains the advisory capture
  trigger alongside its existing delegation thresholds.
- `skills/process/SKILL.md` — a line: reference fixture entries for the
  contract's entities.
- `README.md` + `skills/help/SKILL.md` — document the type.
- `.claude-plugin/plugin.json` → **0.21.0** · `upgrades/v0.21.0.md`
  (`requires-action: false`).

## O — Operations

1. `compound`: extend the type list to include `fixture`; add the capture
   prompt (one bullet, keep it tight per P12's weight discipline).
2. `spec` + `work`: extend the existing prime line to name `fixture` entries as
   what to surface for the task's entities/files.
3. `process`: one line tying fixtures to the contract's entities/DATA.md.
4. README + help: name the type in the ledger/state description.
5. Bump + `upgrades/v0.21.0.md`; run the five test scripts.

## N — Norms

Additions stay minimal (P12 weight discipline — each skill gains ≤ a few lines).
Reuse the existing entry format exactly (`## <type>: <title>` + the `fw:`
metadata line); do not invent a parallel format. GATEs and fixed contracts
untouched.

## S — Safeguards

- **Backward compatible**: existing entries and the four existing types are
  untouched; `fixture` is additive. Old ledgers keep loading.
- **No format drift**: a `fixture` entry is a normal typed entry — same metadata
  keys — so `recall`, the SessionStart scorer, and the read-priming hook all
  handle it with zero changes (assert this in verify: the existing tests still
  pass, and a fixture entry is greppable by `recall`'s type match).
- **Evidence-gated capture (owner amendment, 2026-07-20)**: a `fixture` entry is
  recorded only from a recipe *observed to work this cycle* (it built a valid
  instance and the check using it went green) — never a plausible-but-unrun one.
  The `work` trigger offers only after that evidence exists. A false or
  unverified learning is worse than none — it silently misleads every future
  cycle — so compounding must hold the same "observe it green" bar as `work`/
  `verify`. (Generalized to all learning types as P18.)
- **No secrets in fixtures**: a stub recipe records *how to build* test data,
  never real credentials or PII (call this out in the compound prompt).
- **Weight**: don't bloat the always-loaded descriptions; the capture/prime
  prompts live in skill bodies (loaded on invocation), not frontmatter.

## Success metric

One command, exit 0 = PASS:

```bash
grep -q 'fixture' skills/compound/SKILL.md \
  && grep -q 'fixture' skills/spec/SKILL.md \
  && grep -q 'fixture' skills/work/SKILL.md \
  && grep -qi 'fixture' README.md \
  && grep -qi 'fixture' skills/help/SKILL.md \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/test-install-vendored.sh \
  && bash scripts/test-read-prime.sh \
  && bash scripts/test-session-start.sh \
  && bash scripts/test-gate.sh \
  && grep -q '"version": "0.21.0"' .claude-plugin/plugin.json \
  && test -f upgrades/v0.21.0.md
```
