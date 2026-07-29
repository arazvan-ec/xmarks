#!/usr/bin/env bash
# flywheel — test for the script/test pairing gate, scripts/check-test-pairing.sh
# (P22). Covers: docs-only diffs pass; a script changed without its paired
# test-*.sh fails; script+test together pass; new script needs a new test;
# test-only changes pass; deleting a script requires deleting its test;
# SKIP_TEST_PAIRING=1 is an explicit, logged escape.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${SRC}/scripts/check-test-pairing.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

REPO="${WORK}/repo"
mkdir -p "${REPO}/scripts"
git init -q "${REPO}"
g() { git -C "${REPO}" -c user.email=t@t -c user.name=t "$@"; }
g checkout -qb main
echo 'echo foo' > "${REPO}/scripts/foo.sh"
echo 'echo test-foo' > "${REPO}/scripts/test-foo.sh"
echo readme > "${REPO}/README.md"
g add -A && g commit -qm base

# run_check [env VAR=val ...] -> sets RC; the gate diffs main...HEAD.
run_check() {
  RC=0
  (cd "${REPO}" && env "$@" bash "${CHECK}" main >"${WORK}/out" 2>&1) || RC=$?
}
# fresh feature branch off main for each scenario
branch() { g checkout -q main && g branch -qD feat 2>/dev/null || true; g checkout -qb feat; }

echo "== docs-only diff passes =="
branch
echo more >> "${REPO}/README.md"
g add -A && g commit -qm docs
run_check
[ "${RC}" -eq 0 ] || fail "docs-only diff must pass, got ${RC}: $(cat "${WORK}/out")"
pass "docs-only diff → exit 0"

echo "== script without its test fails =="
branch
echo 'echo changed' >> "${REPO}/scripts/foo.sh"
g add -A && g commit -qm change
run_check
[ "${RC}" -ne 0 ] || fail "foo.sh changed without test-foo.sh must fail"
grep -q "test-foo.sh" "${WORK}/out" || fail "failure must name the missing paired test"
pass "foo.sh alone → fails, names scripts/test-foo.sh"

echo "== script + paired test passes =="
branch
echo 'echo changed' >> "${REPO}/scripts/foo.sh"
echo 'echo new assert' >> "${REPO}/scripts/test-foo.sh"
g add -A && g commit -qm change
run_check
[ "${RC}" -eq 0 ] || fail "foo.sh + test-foo.sh must pass, got ${RC}: $(cat "${WORK}/out")"
pass "foo.sh + test-foo.sh → exit 0"

echo "== new script needs a new paired test =="
branch
echo 'echo bar' > "${REPO}/scripts/bar.sh"
g add -A && g commit -qm add-bar
run_check
[ "${RC}" -ne 0 ] || fail "new bar.sh without test-bar.sh must fail"
branch
echo 'echo bar' > "${REPO}/scripts/bar.sh"
echo 'echo test-bar' > "${REPO}/scripts/test-bar.sh"
g add -A && g commit -qm add-bar-tested
run_check
[ "${RC}" -eq 0 ] || fail "new bar.sh + test-bar.sh must pass, got ${RC}"
pass "new script → fails alone, passes with its test"

echo "== test-only change passes =="
branch
echo 'echo extra assert' >> "${REPO}/scripts/test-foo.sh"
g add -A && g commit -qm test-only
run_check
[ "${RC}" -eq 0 ] || fail "test-only change must pass, got ${RC}"
pass "test-only diff → exit 0"

echo "== deleting a script requires deleting its test =="
branch
g rm -q scripts/foo.sh && g commit -qm rm-foo
run_check
[ "${RC}" -ne 0 ] || fail "deleting foo.sh while test-foo.sh stays must fail"
branch
g rm -q scripts/foo.sh scripts/test-foo.sh && g commit -qm rm-both
run_check
[ "${RC}" -eq 0 ] || fail "deleting foo.sh + test-foo.sh must pass, got ${RC}"
pass "delete script → fails alone, passes with its test"

echo "== SKIP_TEST_PAIRING=1 escape =="
branch
echo 'echo changed' >> "${REPO}/scripts/foo.sh"
g add -A && g commit -qm change
run_check SKIP_TEST_PAIRING=1
[ "${RC}" -eq 0 ] || fail "SKIP_TEST_PAIRING=1 must pass, got ${RC}"
grep -qi "skip" "${WORK}/out" || fail "the escape must be logged, not silent"
pass "SKIP_TEST_PAIRING=1 → exit 0, logged"

echo "ALL PASS"
