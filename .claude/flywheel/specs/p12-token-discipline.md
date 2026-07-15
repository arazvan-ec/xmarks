# Spec: P12 — Token-discipline pass over the skills

**Slug:** `p12-token-discipline` · **Created:** 2026-07-15 · **Backlog:** P12
**Status:** signed 2026-07-15 (owner) — full cycle approved, PR at the end
**Prime:** LEARNINGS.md (7 entries; the "route the review by diff type" pattern
this release codifies has already been applied manually in three cycles, saving
~300k tokens/review vs the fan-out). Source evidence: flow-audit run #1's three
High cost findings + two Lows.

## R — Requirements

Stop paying for context nobody uses — flywheel's own token-efficiency research,
applied to itself:

1. **No full-ledger reads.** `loop` (step 0), `spec` and `process` (prior-art
   steps) instruct a cover-to-cover `Read` of `LEARNINGS.md` (~18k tokens at
   200 entries, twice per loop cycle) on top of the budgeted SessionStart
   injection built precisely to avoid that. Prime steps become: *use the
   SessionStart-injected subset; pull specifics with `/flywheel:recall` —
   never read the whole ledger.*
2. **Diff-based review routing.** `review` unconditionally dispatches all
   three Sonnet reviewers (30–80k tokens even for a 5-line docs diff). Add a
   routing step before dispatch: docs/comment-only diff → correctness only;
   dispatch security only when the diff touches input handling, auth,
   secrets, or dependencies; performance only when it touches loops, queries,
   I/O, or data volume; a single combined-lens reviewer under ~20 changed
   lines. Always state which reviewers were skipped and why (no silent caps).
3. **Evaluator wording honesty.** `help` and README describe the autoloop
   evaluator as firing on every keep/discard — over-dispatching vs
   `autoloop`'s actual contract (ambiguous results + the final stop only).
   Align the wording.
4. **Frontmatter on a diet.** The four heaviest skill descriptions (`process`
   431 chars, `run` 405, `autoloop` 399, `debug` 345) load into every session
   of every repo. Trim each to trigger-conditions ≤ 300 chars; rationale
   lives in the body, which loads on invocation.
5. **Injection budget by size, not just count.** `session-start.sh` caps at 12
   entries but bodies are unbounded — one verbose entry can multiply the
   ~1.3k-token injection several-fold. Truncate each injected entry at ~500
   chars with a `[truncated — /flywheel:recall pulls the full entry]` tail;
   assert it in `test-session-start.sh`.

**Out of scope:** gate.sh re-run caching (P11); untrusted-data framing (P13);
banner trimming and SessionStart matcher changes (Low, deferred — re-injection
after compact is arguably a feature).

## E — Entities

| Entity | Constraint | Files |
| --- | --- | --- |
| Prime step | injected subset + recall, never whole-ledger `Read` | `skills/loop\|spec\|process` |
| Routing table | diff class → reviewer set, stated skips | `skills/review` |
| Description line | ≤ 300 chars, trigger-conditions only | `skills/process\|run\|autoloop\|debug` |
| Injected entry | ≤ ~500 chars + truncation tail | `scripts/session-start.sh` awk |

## A — Approach

Prompt-text edits plus one small awk change — same shape as P16 (prompts are
the implementation). Routing is expressed as a short decision table inside
`review`'s existing flow, not a new skill. Rejected: a hook that measures diff
size and injects routing hints — runtime surface + latency for something the
reviewer-dispatching model can decide from `git diff --stat` it already runs.

## S — Structure

- `skills/loop/SKILL.md` (step 0), `skills/spec/SKILL.md`,
  `skills/process/SKILL.md` — prime steps rewritten.
- `skills/review/SKILL.md` — routing table before dispatch.
- `skills/help/SKILL.md` + `README.md` — evaluator wording; README review line
  mentions routing.
- `skills/process|run|autoloop|debug/SKILL.md` — description trims.
- `scripts/session-start.sh` + `scripts/test-session-start.sh` — body
  truncation + assertion.
- `.claude-plugin/plugin.json` → **0.19.0** · `upgrades/v0.19.0.md`
  (`requires-action: false`).

## O — Operations

1. Rewrite the three prime steps (recall-first, never whole-ledger).
2. Add review's routing table + stated-skips rule.
3. Align evaluator wording in help + README.
4. Trim the four descriptions to ≤ 300 chars.
5. Truncate injected bodies in session-start awk; add the test assertion.
6. Bump + upgrade note; run all four test scripts.

## N — Norms

Keep every edit shorter than what it replaces (this is a *reduction* release —
net negative lines in skill bodies is the goal). GATEs and fixed contracts
untouched. Test idiom unchanged.

## S — Safeguards

- **No behavior loss:** recall/injection still surface the same knowledge —
  only the *delivery* gets cheaper; truncation always points to the full entry.
- **No silent caps:** review must name skipped reviewers and the rule that
  skipped them, so a wrong routing call is visible and correctable.
- **Descriptions keep their trigger semantics** — trim rationale, never the
  "use when" conditions (docs-consistency + plugin validate must stay green).
- Truncation only affects the SessionStart injection, never the ledger file.

## Success metric

One command, exit 0 = PASS:

```bash
! grep -l 'read `.claude/flywheel/LEARNINGS.md`' skills/loop/SKILL.md skills/spec/SKILL.md skills/process/SKILL.md 2>/dev/null | grep -q . \
  && grep -qi 'routing' skills/review/SKILL.md \
  && grep -q 'ambiguous' skills/help/SKILL.md \
  && for s in process run autoloop debug; do \
       [ "$(sed -n 's/^description: //p' "skills/${s}/SKILL.md" | head -1 | wc -c)" -le 300 ] || exit 1; done \
  && grep -q 'truncated' scripts/session-start.sh \
  && bash scripts/test-session-start.sh \
  && bash scripts/test-read-prime.sh \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/test-install-vendored.sh \
  && grep -q '"version": "0.19.0"' .claude-plugin/plugin.json \
  && test -f upgrades/v0.19.0.md
```
