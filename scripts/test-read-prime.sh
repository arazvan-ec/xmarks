#!/usr/bin/env bash
# flywheel — test for the read-priming PreToolUse hook (P3).
# Asserts the advisory-only contract: a matching file surfaces its prior
# learnings, a non-matching file (or a missing ledger, or missing python3)
# produces no output, and the hook always exits 0 (it never blocks the read).

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${SRC}/scripts/read-prime.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

TARGET="${WORK}/target"
mkdir -p "${TARGET}/.claude/flywheel" "${TARGET}/src/auth"
cat > "${TARGET}/.claude/flywheel/LEARNINGS.md" <<'EOF'
# flywheel learnings

## gotcha: logout didn't clear the session cookie
<!-- fw: type=gotcha; date=2026-07-08; files=src/auth/login.ts,src/auth/session.ts -->

Session cookies survived logout because the redirect fired before clearSession().

## decision: unrelated to auth
<!-- fw: type=decision; date=2026-07-01; files=other.ts -->

Not related.

## 2020-01-01 — pre-typed entry
- Decision: no metadata line at all, must not crash the matcher.
EOF

run_hook() {
  local file_path="$1"
  printf '{"tool_input": {"file_path": "%s"}}' "${file_path}" \
    | CLAUDE_PROJECT_DIR="${TARGET}" bash "${SCRIPT}"
}

# Note: `set -e` above means any of these command substitutions aborting the
# whole script with a nonzero exit already fails the test — the hook's
# always-exit-0 contract is enforced implicitly, not just by inspection below.

# A match must be delivered through the hook JSON contract — PreToolUse stdout
# on exit 0 is transcript-only and never reaches the model (P9).
assert_envelope() {
  FW_OUT="$1" FW_EXPECT="$2" python3 - <<'PY'
import json, os
payload = json.loads(os.environ["FW_OUT"])
h = payload["hookSpecificOutput"]
assert h["hookEventName"] == "PreToolUse", f"wrong hookEventName: {h}"
ctx = h["additionalContext"]
assert os.environ["FW_EXPECT"] in ctx, f"expected learning missing from additionalContext: {ctx!r}"
assert "/flywheel:recall" in ctx, f"recall pointer missing: {ctx!r}"
assert "unrelated to auth" not in ctx, f"unrelated learning leaked: {ctx!r}"
PY
}

echo "== matching file (relative path) =="
OUT="$(run_hook "src/auth/login.ts")"
assert_envelope "${OUT}" "logout didn't clear the session cookie" \
  || fail "relative-path match did not emit a valid hookSpecificOutput envelope"
pass "matching file emits hookSpecificOutput JSON with exactly its own learning"

echo "== matching file (absolute path) =="
OUT_ABS="$(run_hook "${TARGET}/src/auth/session.ts")"
assert_envelope "${OUT_ABS}" "logout didn't clear the session cookie" \
  || fail "absolute-path match did not emit a valid hookSpecificOutput envelope"
pass "absolute path resolves against the project dir"

echo "== no match =="
OUT_NONE="$(run_hook "src/unrelated/whatever.ts")"
[ -z "${OUT_NONE}" ] || fail "produced output for a file with no matching learning: ${OUT_NONE}"
pass "no match produces no output and exits 0"

echo "== no ledger =="
EMPTY="${WORK}/empty"
mkdir -p "${EMPTY}"
OUT_EMPTY="$(printf '{"tool_input": {"file_path": "x.ts"}}' | CLAUDE_PROJECT_DIR="${EMPTY}" bash "${SCRIPT}")"
[ -z "${OUT_EMPTY}" ] || fail "produced output with no ledger present"
pass "no ledger: no output, exits 0"

echo "== malformed hook input =="
OUT_BAD="$(printf 'not json' | CLAUDE_PROJECT_DIR="${TARGET}" bash "${SCRIPT}")"
[ -z "${OUT_BAD}" ] || fail "produced output on malformed input"
pass "malformed hook input: fails open, no output, exits 0"

echo "== fail-open without python3 =="
RESTRICTED="$(mktemp -d)"
for bin in bash cat; do
  p="$(command -v "${bin}")" || fail "test setup: ${bin} not found on host PATH"
  ln -s "${p}" "${RESTRICTED}/${bin}"
done
OUT_NOPY="$(printf '{"tool_input": {"file_path": "src/auth/login.ts"}}' \
  | CLAUDE_PROJECT_DIR="${TARGET}" PATH="${RESTRICTED}" bash "${SCRIPT}")"
[ -z "${OUT_NOPY}" ] || fail "produced output without python3 on PATH"
pass "falls back to silent no-op (never blocks) when python3 is unavailable"

echo ""
echo "all read-prime tests passed"
