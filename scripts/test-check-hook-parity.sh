#!/usr/bin/env bash
# flywheel — test for the hook-parity gate, scripts/check-hook-parity.sh (P38).
# Proves the gate is BEHAVIORAL by mutation, not by inspection: it copies the
# repo into a scratch dir (never touching the real one), breaks one of the two
# hook wirings in the copy, and asserts the gate goes red naming the exact hook
# — for both failure directions the v0.44.0 incident and its post-mortem named
# (a hook missing from the installer's registration, and one registered but
# never copied into .claude/flywheel/bin/) — then asserts an unmutated copy of
# the same repo goes green. Also asserts the real, committed repo is in parity
# today.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${SRC}/scripts/check-hook-parity.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

[ -f "${CHECK}" ] || fail "no gate at scripts/check-hook-parity.sh"
bash -n "${CHECK}" || fail "gate is not valid bash"

# copy_repo <dest> — a throwaway copy of the whole repo (minus .git, which
# install-vendored.sh never reads and which only costs time to copy). The gate
# and the installer both resolve paths relative to their own location, so a
# full copy is what lets a mutation of the COPY run in isolation from SRC.
copy_repo() {
  local dest="$1"
  mkdir -p "${dest}"
  cp -r "${SRC}/." "${dest}/"
  rm -rf "${dest}/.git"
}

echo "== the committed repo is in parity today =="
RC=0
( cd "${SRC}" && bash "${CHECK}" >"${WORK}/out" 2>&1 ) || RC=$?
[ "${RC}" -eq 0 ] || fail "the real repo must be in parity: $(cat "${WORK}/out")"
grep -q 'OK' "${WORK}/out" || fail "no OK verdict: $(cat "${WORK}/out")"
pass "hooks.json and install-vendored.sh agree today"

echo "== an unmutated copy also passes =="
PRISTINE="${WORK}/pristine"
copy_repo "${PRISTINE}"
RC=0
bash "${PRISTINE}/scripts/check-hook-parity.sh" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 0 ] || fail "a pristine copy must pass: $(cat "${WORK}/out")"
pass "pristine copy passes"

echo "== a hook in hooks.json that the installer does not register is caught =="
MISSING_REG="${WORK}/missing-reg"
copy_repo "${MISSING_REG}"
INSTALLER="${MISSING_REG}/scripts/install-vendored.sh"
BLOCK='    ("PreToolUse", "mcp__.*__create_session|Agent|Task", {
        "type": "command",
        "command": os.environ["FW_DELEGATION_GUARD"],
        "timeout": 5,
    }),
'
python3 - "${INSTALLER}" "${BLOCK}" <<'PY'
import sys
path, block = sys.argv[1], sys.argv[2]
text = open(path).read()
if text.count(block) != 1:
    print(f"test setup: expected exactly one copy of the delegation-guard registration block, found {text.count(block)}", file=sys.stderr)
    sys.exit(1)
open(path, "w").write(text.replace(block, "", 1))
PY
RC=0
bash "${MISSING_REG}/scripts/check-hook-parity.sh" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 1 ] || fail "removing delegation-guard's installer registration must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q 'delegation-guard.sh' "${WORK}/out" || fail "the report must name delegation-guard.sh: $(cat "${WORK}/out")"
grep -q 'hooks.json registers' "${WORK}/out" || fail "the report must say hooks.json has it and the installer does not: $(cat "${WORK}/out")"
pass "missing installer registration is caught and named"

echo "== a hook the installer registers that hooks.json does not have is caught =="
EXTRA_REG="${WORK}/extra-reg"
copy_repo "${EXTRA_REG}"
HJ="${EXTRA_REG}/hooks/hooks.json"
python3 - "${HJ}" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
data["hooks"]["Stop"][0]["hooks"].pop()  # drop the gate.sh registration hooks.json carries
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PY
RC=0
bash "${EXTRA_REG}/scripts/check-hook-parity.sh" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 1 ] || fail "removing gate.sh from hooks.json must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q 'gate.sh' "${WORK}/out" || fail "the report must name gate.sh: $(cat "${WORK}/out")"
grep -q 'install-vendored.sh registers' "${WORK}/out" || fail "the report must say the installer has it and hooks.json does not: $(cat "${WORK}/out")"
pass "reverse drift (installer-only registration) is caught and named"

echo "== a hook registered by both but never copied into bin/ is caught =="
NOT_LANDED="${WORK}/not-landed"
copy_repo "${NOT_LANDED}"
INSTALLER2="${NOT_LANDED}/scripts/install-vendored.sh"
NEEDLE=' "${SRC}"/scripts/delegation-guard.sh'
python3 - "${INSTALLER2}" "${NEEDLE}" <<'PY'
import sys
path, needle = sys.argv[1], sys.argv[2]
text = open(path).read()
if text.count(needle) != 1:
    print(f"test setup: expected exactly one copy of the delegation-guard.sh vendoring entry, found {text.count(needle)}", file=sys.stderr)
    sys.exit(1)
open(path, "w").write(text.replace(needle, "", 1))
PY
RC=0
bash "${NOT_LANDED}/scripts/check-hook-parity.sh" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 1 ] || fail "a registered-but-uncopied script must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q 'delegation-guard.sh' "${WORK}/out" || fail "the report must name delegation-guard.sh: $(cat "${WORK}/out")"
grep -q 'not an executable file' "${WORK}/out" || fail "the report must say it is not an executable file in bin/: $(cat "${WORK}/out")"
pass "registered-but-not-vendored is caught as its own failure mode"

echo "== a real repo was never touched by any of the above =="
( cd "${SRC}" && git diff --quiet -- hooks/hooks.json scripts/install-vendored.sh ) \
  || fail "the real repo's hooks.json/install-vendored.sh must be untouched by this test"
pass "real repo untouched"

echo "== no hooks/hooks.json is unusable input, not a mismatch =="
NOJSON="${WORK}/nojson"
copy_repo "${NOJSON}"
rm -f "${NOJSON}/hooks/hooks.json"
RC=0
bash "${NOJSON}/scripts/check-hook-parity.sh" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 2 ] || fail "no hooks.json must exit 2, got ${RC}: $(cat "${WORK}/out")"
pass "missing hooks.json exits 2"

echo "== the escape hatch is explicit and logged =="
RC=0
SKIP_HOOK_PARITY=1 bash "${NOJSON}/scripts/check-hook-parity.sh" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 0 ] || fail "SKIP_HOOK_PARITY=1 must skip"
grep -qi 'skipped' "${WORK}/out" || fail "the skip must be logged, never silent: $(cat "${WORK}/out")"
pass "SKIP_HOOK_PARITY=1 skips with a notice"

echo "check-hook-parity: OK"
