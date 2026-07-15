#!/usr/bin/env bash
# flywheel — test for the completion gate (Stop hook), scripts/gate.sh (P11).
# Covers: not-opted-in no-op; the trust boundary (an untrusted gate is NEVER
# executed); trusted green allows + caches; trusted red blocks then bypasses
# after MAX; the cost cache skips an unchanged-tree re-run; the bypass persists
# so a permanently-red gate can't re-trap.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="${SRC}/scripts/gate.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

TARGET="${WORK}/target"
mkdir -p "${TARGET}/.claude/flywheel"
git init -q "${TARGET}"
git -C "${TARGET}" -c user.email=t@t -c user.name=t checkout -qb main 2>/dev/null || true
echo base > "${TARGET}/file.txt"
git -C "${TARGET}" add file.txt
git -C "${TARGET}" -c user.email=t@t -c user.name=t commit -qm base

GATE="${TARGET}/.claude/flywheel/gate.sh"
RAN="${WORK}/ran.log"                 # the gate appends here every time it runs
STORE="${WORK}/state"                 # consent store, outside the repo tree

# Run the hook: run_hook <stdin-json> -> sets RC (never aborts the test).
run_hook() {
  RC=0
  printf '%s' "${1:-'{}'}" \
    | CLAUDE_PROJECT_DIR="${TARGET}" FLYWHEEL_STATE_DIR="${STORE}" bash "${HOOK}" >"${WORK}/out" 2>"${WORK}/err" \
    || RC=$?
}
gate_hash() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "${GATE}" | cut -d' ' -f1
  else shasum -a 256 "${GATE}" | cut -d' ' -f1; fi
}
trust_gate() { mkdir -p "${STORE}"; gate_hash >> "${STORE}/trusted-gates"; }
ran_count() { [ -f "${RAN}" ] && wc -l < "${RAN}" | tr -d ' ' || echo 0; }

echo "== not opted in =="
run_hook '{}'
[ "${RC}" -eq 0 ] || fail "no gate present should be a no-op (exit 0), got ${RC}"
pass "no gate → no-op, exit 0"

# A gate that records each execution, then passes or fails per GATE_MODE file.
cat > "${GATE}" <<EOF
#!/usr/bin/env bash
echo ran >> "${RAN}"
exit \$(cat "${WORK}/mode" 2>/dev/null || echo 0)
EOF
chmod +x "${GATE}"
echo 0 > "${WORK}/mode"

echo "== untrusted gate is never executed (fail-safe) =="
run_hook '{}'
[ "${RC}" -eq 0 ] || fail "untrusted gate must not block the turn (exit 0), got ${RC}"
[ "$(ran_count)" -eq 0 ] || fail "untrusted gate WAS executed — trust boundary breached"
grep -q 'not trusted yet' "${WORK}/err" || fail "no trust guidance printed"
grep -q 'trusted-gates' "${WORK}/err" || fail "trust command not shown"
pass "untrusted gate skipped, sentinel proves it never ran, exit 0"

echo "== trusted + green allows and caches =="
trust_gate
run_hook '{}'
[ "${RC}" -eq 0 ] || fail "trusted green gate should allow (exit 0), got ${RC}"
[ "$(ran_count)" -eq 1 ] || fail "trusted gate should have run exactly once, ran $(ran_count)"
pass "trusted + green → exit 0, gate ran once"

echo "== cost cache skips an unchanged-tree re-run =="
run_hook '{}'
[ "${RC}" -eq 0 ] || fail "cached pass should allow (exit 0), got ${RC}"
[ "$(ran_count)" -eq 1 ] || fail "unchanged tree should NOT re-run the gate, ran $(ran_count)"
pass "unchanged tree → gate not re-run (cost cache hit)"

echo "== cache does NOT skip a staged-only change (false-skip guard) =="
echo staged > "${TARGET}/staged.txt"
git -C "${TARGET}" add staged.txt        # staged, working==index → old 'git diff' missed this
BEFORE="$(ran_count)"
run_hook '{}'
[ "$(ran_count)" -eq "$((BEFORE + 1))" ] || fail "staged-only change was NOT re-run (cache false-skip)"
pass "staged-only change re-runs the gate"

echo "== cache does NOT skip an untracked-content change (false-skip guard) =="
# get back to a green cached state first
git -C "${TARGET}" -c user.email=t@t -c user.name=t commit -qm staged
run_hook '{}'                             # green → caches the new signature
BEFORE="$(ran_count)"
run_hook '{}'; [ "$(ran_count)" -eq "${BEFORE}" ] || fail "unchanged tree should be cached"
printf 'artifact\n' > "${TARGET}/build-artifact.log"   # untracked, content-only
run_hook '{}'
[ "$(ran_count)" -eq "$((BEFORE + 1))" ] || fail "untracked-content change was NOT re-run (cache false-skip)"
pass "untracked-content change re-runs the gate"
rm -f "${TARGET}/build-artifact.log"

echo "== changed tree re-runs; red gate blocks =="
echo more >> "${TARGET}/file.txt"
echo 1 > "${WORK}/mode"          # now the gate fails
run_hook '{}'
[ "${RC}" -eq 2 ] || fail "trusted red gate should block (exit 2), got ${RC}"
grep -q 'FAILED' "${WORK}/err" || fail "failure output not fed back"
pass "changed tree re-runs; red gate blocks (exit 2)"

echo "== bounded blocks then bypass (tree A) =="
run_hook '{}'; [ "${RC}" -eq 2 ] || fail "2nd red should still block, got ${RC}"
run_hook '{}'; [ "${RC}" -eq 2 ] || fail "3rd red should still block, got ${RC}"
run_hook '{}'; [ "${RC}" -eq 0 ] || fail "after MAX blocks should bypass (exit 0), got ${RC}"
grep -q 'bypassing' "${WORK}/err" || fail "bypass message missing"
pass "blocks up to MAX, then fail-open bypass"

echo "== bypass persists on the SAME red tree (no re-trap) =="
run_hook '{}'
[ "${RC}" -eq 0 ] || fail "a bypassed failing tree must not re-trap next turn, got ${RC}"
pass "bypass persists until green (no re-trap)"

echo "== a DIFFERENT new regression still blocks (counter keyed to tree) =="
# After tree A's bypass, a fresh breakage must get its OWN MAX attempts —
# it must NOT inherit tree A's exhausted counter and bypass with zero blocks.
echo different >> "${TARGET}/file.txt"    # new failing signature
run_hook '{}'
[ "${RC}" -eq 2 ] || fail "new regression after a bypass must block, not inherit the counter (got ${RC})"
pass "new failing tree gets its own MAX budget (counter keyed to signature)"

echo "== stop_hook_active short-circuits a fresh failing tree (COUNT<MAX) =="
# Reset to green so the next failing tree starts at COUNT=0, then prove
# stop_hook_active alone flips exit 2 → exit 0 (not the MAX ceiling doing it).
echo 0 > "${WORK}/mode"; run_hook '{}'; [ "${RC}" -eq 0 ] || fail "reset-to-green failed, got ${RC}"
echo 1 > "${WORK}/mode"; echo trip >> "${TARGET}/file.txt"   # fresh failing tree, COUNT=0
run_hook '{}';                     [ "${RC}" -eq 2 ] || fail "fresh red at COUNT=0 without flag should block, got ${RC}"
echo trip2 >> "${TARGET}/file.txt"                            # another fresh failing tree, COUNT=0
run_hook '{"stop_hook_active": true}'; [ "${RC}" -eq 0 ] || fail "stop_hook_active at COUNT<MAX should short-circuit (exit 0), got ${RC}"
pass "stop_hook_active flips a would-be block to exit 0 on its own"

echo "== recovering to green clears the block =="
echo 0 > "${WORK}/mode"
run_hook '{}'
[ "${RC}" -eq 0 ] || fail "green gate should allow, got ${RC}"
pass "green run clears state"

echo ""
echo "all gate tests passed"
