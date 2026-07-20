# Plan: p11-gate-hardening → release v0.20.0

Spec signed 2026-07-15 (trust-on-first-use fail-safe). **Riskiest step:** T1 —
the trust boundary. It must be fail-SAFE (unknown gate never runs) yet never
block the turn, and the consent store must be outside the repo. Test-first: the
untrusted-gate test proves a sentinel gate never executed.

| # | Task | Files | Local check |
| --- | --- | --- | --- |
| T1 | Consent gate: sha256 of gate.sh vs `${FLYWHEEL_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/flywheel}/trusted-gates`; miss → print trust command + `exit 0`, never exec | `scripts/gate.sh` | T5 untrusted case |
| T2 | Cost cache: tree signature (`git rev-parse HEAD` + sha of porcelain+diff) recorded on green; equal signature → `exit 0` without running; no git → always run | `scripts/gate.sh` | T5 cache case |
| T3 | Escape valve: persist bypass keyed to failing signature (cleared on green); honor `stop_hook_active` from stdin (python3 best-effort) | `scripts/gate.sh` | T5 bypass-persists case |
| T4 | Fail-open on every internal error (no sha tool, unreadable store, malformed stdin, no git) → today's behavior, never block | `scripts/gate.sh` | T5 fail-open cases |
| T5 | NEW `scripts/test-gate.sh`: not-opted-in no-op; untrusted skips (sentinel never ran); trusted+green allows + caches; trusted+red blocks (exit 2) → bypass after MAX; cache skips unchanged-tree re-run; bypass persists until green | `scripts/test-gate.sh` | `bash scripts/test-gate.sh` |
| T6 | Wire test-gate into CI | `.github/workflows/validate-plugins.yml` | grep step |
| T7 | Docs: consent step in README gate section + help | `README.md`, `skills/help/SKILL.md` | greps |
| T8 | Bump 0.19.0 → 0.20.0 + upgrade note with `## Strategy` (existing users consent once) | `plugin.json`, `upgrades/v0.20.0.md` | metric greps |
| T9 | Report + ledger transitions (P16 law) | `runs/p11-gate-hardening/…` | artifact per phase |
