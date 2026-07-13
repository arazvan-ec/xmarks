# Spec: P9 — Read-priming that actually reaches the model + robust session-start

**Slug:** `p9-read-priming-real` · **Created:** 2026-07-13 · **Backlog:** P9
**Status:** signed 2026-07-13 (owner) — full cycle approved, PR at the end
**Prime:** LEARNINGS.md read (4 entries; "route review by diff type" → shell/hook
diff = adversarial correctness lens; "manifest not glob" mindset applies to any
rewrite). Source evidence: flow-audit run #1 (Critical C1 + 4 Mediums).

## R — Requirements

1. **The v0.11.0 flagship must actually work**: `read-prime.sh`'s advisory
   ("prior learnings touch this file") currently goes to PreToolUse stdout,
   which is shown only in transcript mode — it **never reaches the model**.
   Emit the supported hook JSON instead:
   `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": "<matches>"}}`
   on match; keep **silent plain exit 0** on no-match (and every failure path).
2. **No python spawn for the ~99% no-match majority**: a bash-level pre-filter
   greps the ledger for the target's basename before the heredoc; python runs
   only on a candidate hit. If the path can't be extracted cheaply, fall
   through to python (correctness over speed), never the reverse.
3. **Scoring robustness in `session-start.sh`**:
   - The awk metadata parser reads only the first line after a `## ` header —
     one blank line silently zeroes that entry's relevance (reproduced by the
     audit; read-prime searches the whole entry, so the two consumers
     disagree). Skip blank lines before the `meta_seen` check.
   - Replace the O(n²) bubble sort with top-K selection (O(n·k), k=INJECT_N) —
     the current sort dies against the 15s hook timeout near ~10k entries.
   - macOS: `date -d '-30 days'` is GNU-only → recency signal permanently dead
     on Macs. Add the `date -v-30d` fallback.
   - Cache the remote-version curl (~650ms every session start) behind a
     same-day stamp file in `${TMPDIR:-/tmp}` (the READ-ONLY contract covers
     the working tree; a temp stamp is fine). `FLYWHEEL_NO_UPDATE_CHECK=1`
     still skips everything.
4. **The scoring logic gets tests** (it is the most complex code in the repo
   and had zero): new `scripts/test-session-start.sh` with a fixture ledger —
   blank-line tolerance, files/branch/spec/recency scoring order, INJECT_N
   budget + "more learnings" tail, no-ledger path. `test-read-prime.sh`
   updated to assert the JSON envelope on match and silence elsewhere.
5. **Docs tell the truth**: README §read-priming + help wording updated from
   "prints a note" to context injection via `additionalContext`.

**Out of scope:** gate.sh (P11), any skill-body changes (P12), untrusted-data
framing of injected content (P13 — the injection mechanism changes here, the
trust framing lands with P13).

## E — Entities

| Entity | Fields | Files |
| --- | --- | --- |
| Hook JSON envelope | `hookSpecificOutput.hookEventName=PreToolUse`, `additionalContext` (JSON-escaped, built with `json.dumps`) | `scripts/read-prime.sh` |
| Pre-filter | basename extracted from hook input via sed; `grep -qF` against ledger | `scripts/read-prime.sh` |
| Scoring entry | date/files/branch/spec metadata; score = files(3)+branch/spec(2)+recency(1) | `scripts/session-start.sh` awk |
| Version stamp | `${TMPDIR:-/tmp}/flywheel-remote-version` — line 1 date, line 2 version | `scripts/session-start.sh` |

## A — Approach

Fix in place, in bash/awk/python — same zero-dependency, fail-open house
style. The JSON envelope is built inside the existing python heredoc
(`json.dumps` handles escaping; no hand-rolled JSON in bash). Rejected:
moving read-prime entirely to bash (no safe JSON parsing/escaping without
python) and moving scoring to python (awk is the established pattern; the fix
is 3 lines + a bounded selection loop, not a rewrite).

## S — Structure

- `scripts/read-prime.sh` — pre-filter + JSON envelope on match.
- `scripts/session-start.sh` — awk blank-line skip, top-K selection, date
  fallback, curl stamp cache.
- `scripts/test-read-prime.sh` — assertions updated to the JSON contract.
- **New** `scripts/test-session-start.sh` — fixture-ledger scoring tests.
- `README.md` + `skills/help/SKILL.md` — wording truth.
- `.claude-plugin/plugin.json` → **0.18.0** · `upgrades/v0.18.0.md`
  (`requires-action: false` for marketplace; vendored repos pick both hook
  scripts up on re-vendor).
- CI: new test wired wherever the existing test scripts run
  (`.github/workflows/validate-plugins.yml` — verify during work).

## O — Operations

1. read-prime: pre-filter, then JSON envelope (match) / silence (else).
2. test-read-prime: update assertions to the new contract.
3. session-start: blank-line skip in awk; top-K selection; date fallback;
   curl stamp.
4. New test-session-start.sh (fixture ledger, 5+ assertions); wire into CI.
5. README/help wording; bump; upgrades/v0.18.0.md.
6. Run all four test scripts.

## N — Norms

Fail-open on EVERY path (missing ledger, no python3, malformed input, broken
stamp file) — same guarantees as today, verified by tests. `ok:`/`fail:` test
idiom. Additions minimal; comments only for non-obvious constraints.

## S — Safeguards

- **Never block a read or a session start**: all new code paths exit 0 with
  no output on any error; the pre-filter can only *skip* work, never add a
  failure mode (extraction failure → fall through to python, not exit).
- **No secrets/content leakage**: additionalContext carries entry titles +
  dates (same as today's intended note), not bodies.
- **Injection budget unchanged** (INJECT_N=12 default); top-K must preserve
  the exact current ordering semantics (score desc, date desc tie-break).
- **Stamp cache fail-open**: unreadable/unwritable stamp → behave as today
  (curl with 2s cap); never persist anything in the working tree.

## Success metric

One command, exit 0 = PASS:

```bash
grep -q 'hookSpecificOutput' scripts/read-prime.sh \
  && grep -q 'additionalContext' scripts/read-prime.sh \
  && grep -q 'date -v-30d' scripts/session-start.sh \
  && test -f scripts/test-session-start.sh \
  && bash scripts/test-session-start.sh \
  && bash scripts/test-read-prime.sh \
  && bash scripts/test-docs-consistency.sh \
  && bash scripts/test-install-vendored.sh \
  && grep -q '"version": "0.18.0"' .claude-plugin/plugin.json \
  && test -f upgrades/v0.18.0.md
```
