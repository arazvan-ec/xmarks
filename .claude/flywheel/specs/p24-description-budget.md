# Spec: P24 — description budget as a CI ratchet

**Slug:** `p24-description-budget` · **Created:** 2026-07-30 · **Backlog:** P24
**Status:** shipped as v0.33.0 — metric PASS; gate green against the real repo (3301/3600), 8/8 test scenarios, test seen red (exit 127) before the gate existed
**Prime:** P24 section in `docs/research/improvement-proposals.md`; the
2026-07-30 measurement-audit decision-log entry; `scripts/check-test-pairing.sh`
as the shape to copy (CI gate + logged escape + paired test).

## R — Requirements

v0.30.0 cut the 17 skill `description` fields 22% (5,441 → 4,246 chars measured
whole-line; **3,301 chars** measured as values only, the figure this gate uses).
That saving is a *fixed cost paid in every session* and nothing protects it: the
next skill can add it back silently. Every other invariant here is a CI gate.

1. `scripts/check-description-budget.sh` sums the frontmatter `description`
   **value** length across `skills/*/SKILL.md` and fails when the total exceeds
   a committed budget.
2. On failure it prints the per-skill breakdown, largest first, so the diff says
   *which* skill grew — a bare "over budget" number is not actionable.
3. The budget lives in its own committed file, **not** inside the script, so
   raising it is a one-line reviewable diff that does **not** trip the
   script/test pairing gate (changing the script would force a test change for
   what is a pure policy decision).
4. Malformed input fails loudly, never silently as zero: a skill with no
   `description`, an empty value, or a YAML folded/block scalar
   (`description: >` / `|`) is an error, because a parser that quietly counts 0
   would let the budget be evaded.
5. A `description:` line in the skill *body* (after the frontmatter) is never
   counted — only the leading YAML frontmatter block.
6. Wired into `.github/workflows/validate-plugins.yml` next to the other gates.
7. Developed test-first, red→green, per the CLAUDE.md dev-loop rule.

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| gate script | sums description values, compares to budget | `scripts/check-description-budget.sh` |
| paired test | 8 scenarios against synthetic skill trees | `scripts/test-check-description-budget.sh` |
| budget file | single integer, the committed ceiling | `scripts/description-budget.txt` |
| CI wiring | one step in the existing `test-installer` job | `.github/workflows/validate-plugins.yml` |
| release | bump + upgrade note | `.claude-plugin/plugin.json`, `upgrades/v0.33.0.md` |

## A — Approach

Copy the `check-test-pairing.sh` shape: `set -euo pipefail`, a
`SKIP_DESCRIPTION_BUDGET=1` logged escape, one-line OK output, breakdown to
stderr on failure. Parse with `awk` scoped to the leading frontmatter
(`NR==1 && /^---$/` opens, next `^---$` closes) so body text can never be
counted. `FW_DESC_BUDGET` overrides the file for tests. Budget set to **3600**:
3,301 current + ~300 headroom, which is about one average description — a
single new skill lands free, a second one requires a deliberate budget bump.
That threshold *is* the ratchet; generous headroom would defeat the purpose.

Rejected: a per-skill cap (the proposal names the total only — a second rule is
scope creep, noted as a follow-up); counting the whole `description:` line
(the key prefix is not something an author controls); embedding the budget as a
script constant (see requirement 3).

## S — Structure

- `scripts/check-description-budget.sh` (new, executable)
- `scripts/test-check-description-budget.sh` (new, executable)
- `scripts/description-budget.txt` (new, `3600`)
- `.github/workflows/validate-plugins.yml` — one step
- `.claude-plugin/plugin.json` → **0.33.0** · `upgrades/v0.33.0.md`
  (`requires-action: false` — repo-development tooling, installed behavior
  unchanged)

## O — Operations

1. Write `test-check-description-budget.sh` first; run it, see it fail because
   the gate does not exist yet.
2. Write the budget file and the gate; run the test, see it green.
3. Run the gate against the real repo: 3,301 ≤ 3,600 → exit 0.
4. Wire CI; run the full local check suite.
5. Bump, upgrade note, decision-log entry, push the branch.

## N — Norms

The budget file is data, not a script, so the pairing gate ignores it. The gate
reads only files already in the repo — no network, no writes. Output stays
one line on success (this runs in every CI job; verbosity is its own cost).

## S — Safeguards

- **Loud on malformed input** (requirement 4): a folded scalar or missing field
  is an error, so the gate cannot be evaded by making it unparseable.
- **Escape hatch is logged**, never silent — same contract as
  `SKIP_TEST_PAIRING=1`.
- **No skill text changes**, so no eval gate applies and installed plugin
  behavior is untouched.
- The test builds synthetic skill trees in `mktemp -d`, never mutating the real
  `skills/`.

## Success metric

One command, exit 0 = PASS:

```bash
bash scripts/test-check-description-budget.sh \
  && bash scripts/check-description-budget.sh \
  && ! FW_DESC_BUDGET=100 bash scripts/check-description-budget.sh \
  && grep -q 'check-description-budget' .github/workflows/validate-plugins.yml \
  && grep -q '"version": "0.33.0"' .claude-plugin/plugin.json \
  && test -f upgrades/v0.33.0.md \
  && bash scripts/check-test-pairing.sh \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/test-install-vendored.sh
```
