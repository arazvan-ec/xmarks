#!/usr/bin/env bash
# flywheel — test for the state-write pre-approval PreToolUse hook (P19).
# Asserts the allow-only contract: a write targeting the flywheel state dir
# emits a permissionDecision=allow envelope; everything else — out-of-scope
# paths, `..` traversal, symlink escapes, malformed input, missing python3 —
# produces no output and exits 0 (i.e. falls back to the normal permission
# flow). The hook must never deny and never block.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${SRC}/scripts/write-allow.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

TARGET="${WORK}/target"
mkdir -p "${TARGET}/.claude/flywheel/specs" "${TARGET}/src" "${WORK}/outside"

run_hook() {
  local key="$1" file_path="$2"
  printf '{"tool_input": {"%s": "%s"}}' "${key}" "${file_path}" \
    | CLAUDE_PROJECT_DIR="${TARGET}" bash "${SCRIPT}"
}

# Note: `set -e` above means any of these command substitutions aborting the
# whole script with a nonzero exit already fails the test — the hook's
# always-exit-0 contract is enforced implicitly, not just by inspection below.

assert_allow() {
  FW_OUT="$1" python3 - <<'PY'
import json, os
payload = json.loads(os.environ["FW_OUT"])
h = payload["hookSpecificOutput"]
assert h["hookEventName"] == "PreToolUse", f"wrong hookEventName: {h}"
assert h["permissionDecision"] == "allow", f"expected allow: {h}"
assert "flywheel" in h["permissionDecisionReason"], f"reason missing context: {h}"
PY
}

echo "== state write (relative path) =="
OUT="$(run_hook file_path ".claude/flywheel/specs/my-feature.md")"
assert_allow "${OUT}" || fail "relative state write did not emit an allow envelope"
pass "relative path under .claude/flywheel/ is auto-allowed"

echo "== state write (absolute path) =="
OUT_ABS="$(run_hook file_path "${TARGET}/.claude/flywheel/LEARNINGS.md")"
assert_allow "${OUT_ABS}" || fail "absolute state write did not emit an allow envelope"
pass "absolute path under .claude/flywheel/ is auto-allowed"

echo "== notebook write inside state dir =="
OUT_NB="$(run_hook notebook_path ".claude/flywheel/runs/demo/analysis.ipynb")"
assert_allow "${OUT_NB}" || fail "notebook_path state write did not emit an allow envelope"
pass "notebook_path under .claude/flywheel/ is auto-allowed"

echo "== ordinary project file =="
OUT_SRC="$(run_hook file_path "src/app.ts")"
[ -z "${OUT_SRC}" ] || fail "produced output for an out-of-scope write: ${OUT_SRC}"
pass "ordinary project file: no output (normal permission flow)"

echo "== dotfile outside the state dir =="
OUT_SET="$(run_hook file_path ".claude/settings.json")"
[ -z "${OUT_SET}" ] || fail "granted a write outside .claude/flywheel/: ${OUT_SET}"
pass ".claude/settings.json is NOT covered by the grant"

echo "== traversal escape =="
OUT_DOTDOT="$(run_hook file_path ".claude/flywheel/../../src/app.ts")"
[ -z "${OUT_DOTDOT}" ] || fail "granted a .. traversal escape: ${OUT_DOTDOT}"
pass ".. traversal out of the state dir gets no grant"

echo "== prefix sibling dir =="
mkdir -p "${TARGET}/.claude/flywheel-evil"
OUT_SIB="$(run_hook file_path ".claude/flywheel-evil/x.md")"
[ -z "${OUT_SIB}" ] || fail "granted a write to a prefix-sibling dir: ${OUT_SIB}"
pass "prefix sibling (.claude/flywheel-evil/) gets no grant"

echo "== symlink escape =="
ln -s "${WORK}/outside" "${TARGET}/.claude/flywheel/link"
OUT_LINK="$(run_hook file_path ".claude/flywheel/link/escape.md")"
[ -z "${OUT_LINK}" ] || fail "granted a write through a symlink escaping the state dir: ${OUT_LINK}"
pass "symlink inside the state dir pointing outside gets no grant"

echo "== malformed hook input =="
OUT_BAD="$(printf 'not json' | CLAUDE_PROJECT_DIR="${TARGET}" bash "${SCRIPT}")"
[ -z "${OUT_BAD}" ] || fail "produced output on malformed input"
pass "malformed hook input: fails open, no output, exits 0"

echo "== fail-open without python3 =="
RESTRICTED="$(mktemp -d)"
for bin in bash cat sed head; do
  p="$(command -v "${bin}")" || fail "test setup: ${bin} not found on host PATH"
  ln -s "${p}" "${RESTRICTED}/${bin}"
done
OUT_NOPY="$(printf '{"tool_input": {"file_path": ".claude/flywheel/LEARNINGS.md"}}' \
  | CLAUDE_PROJECT_DIR="${TARGET}" PATH="${RESTRICTED}" bash "${SCRIPT}")"
[ -z "${OUT_NOPY}" ] || fail "produced output without python3 on PATH"
pass "falls back to the normal permission prompt when python3 is unavailable"

echo ""
echo "all write-allow tests passed"
