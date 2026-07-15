# Plan: p12-token-discipline → release v0.19.0

Spec signed 2026-07-15. **Riskiest step:** T6 — description trims must keep
trigger semantics (docs-consistency + `plugin validate --strict` stay green).
This is a reduction release: every edit should be shorter than what it replaces.

| # | Task | Files | Local check |
| --- | --- | --- | --- |
| T1 | loop step 0: injected subset + recall, never whole-ledger | `skills/loop/SKILL.md` | metric grep |
| T2 | spec prime: same | `skills/spec/SKILL.md` | metric grep |
| T3 | process prime: same | `skills/process/SKILL.md` | metric grep |
| T4 | review: routing table before dispatch + stated skips | `skills/review/SKILL.md` | `grep -qi routing` |
| T5 | evaluator wording (ambiguous-only) in help + README; review rows mention routing | `skills/help/SKILL.md`, `README.md` | `grep -q ambiguous skills/help/SKILL.md` |
| T6 | 4 descriptions ≤300 chars (process/run/autoloop/debug) | 4 frontmatters | `wc -c` loop in metric |
| T7 | session-start: truncate injected bodies ~500 chars + tail; test assertion | `scripts/session-start.sh`, `scripts/test-session-start.sh` | `bash scripts/test-session-start.sh` |
| T8 | Bump 0.18.0 → 0.19.0 + upgrade note | `plugin.json`, `upgrades/v0.19.0.md` | metric greps |
| T9 | Report + ledger transitions (P16 law) | `runs/p12-token-discipline/…` | artifact republished per phase |
