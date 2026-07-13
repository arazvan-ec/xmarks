# Plan: p9-read-priming-real → release v0.18.0

Spec signed 2026-07-13. **Riskiest step:** T1/T3 — every new code path in the
two hooks must stay fail-open (pre-filter may only SKIP work; extraction
failure falls through to python, never exits). Test-first: T2/T4 assertions
are written against the spec contract, not the implementation.

| # | Task | Files | Local check |
| --- | --- | --- | --- |
| T1 | read-prime: bash pre-filter (sed-extract `file_path`, `grep -qF` basename against ledger) + JSON envelope via `json.dumps` on match; silence everywhere else | `scripts/read-prime.sh` | T2 green |
| T2 | test-read-prime: match cases assert `hookSpecificOutput.hookEventName=PreToolUse` + `additionalContext` content (parsed with python, not grep); silence cases unchanged | `scripts/test-read-prime.sh` | `bash scripts/test-read-prime.sh` |
| T3 | session-start: awk skips blank lines before `meta_seen`; bubble sort → bounded top-K selection; `date -d \|\| date -v-30d`; same-day curl stamp in `${TMPDIR:-/tmp}` | `scripts/session-start.sh` | T4 green |
| T4 | NEW test-session-start.sh: fixture git repo + 3-entry ledger (blank-line entry with `files=` match, recent unrelated, stale unrelated) → asserts files-match wins despite blank line, INJECT_N budget + tail, ranking order, no-ledger path, banner | `scripts/test-session-start.sh` | script exits 0 |
| T5 | CI: wire the new test into the `test-installer` job | `.github/workflows/validate-plugins.yml` | grep step present |
| T6 | README wording: the note is *injected as context*, not printed | `README.md` | grep 'additionalContext' README.md |
| T7 | Bump 0.17.0 → 0.18.0 + upgrade note | `plugin.json`, `upgrades/v0.18.0.md` | spec metric greps |
| T8 | Report + ledger transitions (P16 law) | `runs/p9-read-priming-real/…` | artifact republished per phase |
