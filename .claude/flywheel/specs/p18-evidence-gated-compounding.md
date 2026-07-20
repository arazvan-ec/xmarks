# Spec: P18 — Evidence-gated compounding

**Slug:** `p18-evidence-gated-compounding` · **Created:** 2026-07-20 · **Backlog:** P18
**Status:** signed 2026-07-20 (owner, advisory v1) · shipped as v0.22.0 — metric PASS; review SHIP (0 Critical/High; backward-compat + rank-invariance empirically confirmed; 1 Low doc nit fixed)
**Prime:** LEARNINGS.md — the `decision` entry "gate knowledge the way flywheel
gates code" (shipped v0.21.0 as prose) is this release's own prior art; P18
makes it structural. Source: the owner's ask (P18 in the backlog).

## R — Requirements

Protect the ledger from unverified conclusions — generalize P17's evidence gate
(fixtures only, as prose) to **all** learning types, structurally.

1. **An `evidence=` metadata key** on the `fw:` line: a short pointer to what
   proved the lesson — a test name, a PR/run id, or a `command → result`. Free
   text, one field. Its **absence vs. an explicit `evidence=unverified`** are
   different: absent = legacy/untagged (pre-P18 entries); `unverified` = the
   author wrote it on reasoning and *flagged* it.
2. **A capture rule in `compound`**: every new entry carries `evidence=<proof>`
   when a concrete proof exists (a `fixture`/`bugfix` always can; most
   `decision`/`pattern` can name the run/PR/discussion that settled them). If a
   genuinely cross-cutting lesson can't point to one, write `evidence=unverified`
   explicitly rather than omitting — so "written on reasoning" is visible, never
   silent.
3. **Trust surfaced at consumption**: an entry explicitly tagged
   `evidence=unverified` is marked as such where it's injected (SessionStart)
   and listed (`recall`), so a reader weighs it accordingly. Verified and legacy
   entries inject unchanged.
4. **Advisory, not a hard gate (v1)**: nothing *refuses* to write an entry; the
   discipline is the capture rule + the visible `unverified` flag. (A
   deterministic compound-lint is a deferred open question — a hard gate risks
   suppressing real cross-cutting lessons that resist a single test.)

## E — Entities

| Entity | What | Where |
| --- | --- | --- |
| `evidence=` field | proof pointer, or the literal `unverified` | `fw:` metadata line in `LEARNINGS.md` |
| Capture rule | compound writes `evidence=` on every new entry | `skills/compound/SKILL.md` |
| Trust marker | a compact tag on explicitly-unverified entries | `scripts/session-start.sh` injection, `skills/recall` list |

## A — Approach

Extend the existing typed-entry format with one optional key and teach the two
consumers to read it — no format break. `session-start.sh`'s awk already parses
`key=value` pairs from the `fw:` line; add `evidence` to the keys it reads
(one line) and, when it equals `unverified`, prepend a short marker to that
entry's injected block. `recall` is prompt-only — its layer-1 list gains the
evidence pointer. Rejected for v1: a hard compound-lint that blocks entries with
no evidence (the owner's own concern — some true lessons are cross-cutting and
hard to pin; ship the visible-flag discipline first, measure, harden later as a
follow-up). Rejected: changing the relevance *score* by evidence (would
entangle trust with ranking; keep them orthogonal — trust is shown, not ranked).

## S — Structure

- `skills/compound/SKILL.md` — document `evidence=` in the metadata spec + the
  capture rule (verified proof, or explicit `unverified`).
- `scripts/session-start.sh` — read `evidence` from metadata; prepend a compact
  `[unverified]` marker to entries tagged `evidence=unverified`. Legacy (absent)
  and verified entries unchanged.
- `scripts/test-session-start.sh` — assert: an `evidence=unverified` entry gets
  the marker; a legacy entry (no `evidence=`) does **not**; a verified entry
  does not.
- `skills/recall/SKILL.md` — layer-1 list surfaces the evidence pointer / an
  `unverified` flag.
- README + `skills/help/SKILL.md` — document the key + the trust signal.
- `.claude-plugin/plugin.json` → **0.22.0** · `upgrades/v0.22.0.md`
  (`requires-action: false`).

## O — Operations

1. `compound`: add `evidence=` to the `key=value` list + the capture rule.
2. `session-start.sh`: parse `evidence`; mark `unverified` entries at injection.
3. `test-session-start.sh`: three assertions (unverified→marked, legacy→clean,
   verified→clean).
4. `recall`: surface evidence in the cheap list.
5. README + help wording.
6. Bump + `upgrades/v0.22.0.md`; run the five test scripts.

## N — Norms

Existing format is sacred: `evidence=` is one more `key=value` on the same
single-line comment, omissible (per the compound spec's "omit a key when it
doesn't apply"). Keep the marker compact (P12 weight discipline). No scoring
change. `ok:`/`fail:` test idiom.

## S — Safeguards

- **Backward compatible**: pre-P18 entries have no `evidence=`; they are
  **legacy/untagged**, NOT marked unverified — only an *explicit*
  `evidence=unverified` triggers the marker. Assert this (a legacy fixture entry
  injects with no marker).
- **No plumbing break**: `evidence` is an additional key the awk reads; entries
  without it parse and score exactly as today. The read-priming hook and recall
  greps are unaffected (they don't enumerate keys). Verify: all five test
  scripts still pass.
- **Trust ≠ rank**: evidence never changes an entry's relevance score, only how
  it's labeled — a wrong-but-relevant entry must still surface (flagged), not be
  hidden.
- **No secrets**: `evidence=` is a pointer (test name / PR / run id), never a
  credential or raw output dump.

## Success metric

One command, exit 0 = PASS:

```bash
grep -q 'evidence=' skills/compound/SKILL.md \
  && grep -q 'evidence' scripts/session-start.sh \
  && grep -qi 'evidence\|unverified' skills/recall/SKILL.md \
  && grep -qi 'evidence' README.md \
  && bash scripts/test-session-start.sh \
  && bash scripts/test-read-prime.sh \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/test-install-vendored.sh \
  && bash scripts/test-gate.sh \
  && grep -q '"version": "0.22.0"' .claude-plugin/plugin.json \
  && test -f upgrades/v0.22.0.md
```
