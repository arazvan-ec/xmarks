#!/usr/bin/env bash
# flywheel — test for the supply-chain pin gate, scripts/check-supply-chain-pin.sh (P13).
#
# The gate exists because pinning the caller's `uses:` does NOT close B10: the
# pinned reusable workflow still cloned an unpinned `main` and bashed the result
# under contents:write. So the two halves are tested INDEPENDENTLY — the cases
# named "revert 1" and "revert 2" below are the spec's own reverts, and revert 2
# (caller pinned, clone-step verification deleted) is the one that decides
# whether this gate is real or decoration.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${SRC}/scripts/check-supply-chain-pin.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

[ -f "${CHECK}" ] || fail "no gate at scripts/check-supply-chain-pin.sh"
bash -n "${CHECK}" || fail "gate is not valid bash"

# ---------------------------------------------------------------- fixtures --
# A sandbox is a fake repo root carrying only the two files the gate reads.
# good_installer / good_workflow are the post-fix shapes; each test mutates one.

good_installer() {
  cat <<'SH'
#!/usr/bin/env bash
SRC_COMMIT_FULL="$(git -C "${SRC}" rev-parse HEAD 2>/dev/null || echo unknown)"
vendor_file "${UPDATE_WORKFLOW_REL}" <<YAML
jobs:
  update:
    uses: arazvan-ec/xmarks/.github/workflows/flywheel-update.yml@${SRC_COMMIT_FULL}
    with:
      flywheel_sha: ${SRC_COMMIT_FULL}
YAML
SH
}

good_workflow() {
  cat <<'YML'
name: flywheel update (reusable)
on:
  workflow_call:
    inputs:
      flywheel_sha:
        required: true
        type: string
jobs:
  refresh:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - name: Fetch the pinned flywheel commit
        run: |
          SHA="${{ inputs.flywheel_sha }}"
          printf '%s' "$SHA" | grep -Eq '^[0-9a-fA-F]{40}$' || exit 1
          git -C "$RUNNER_TEMP/xmarks" fetch -q --depth 1 origin "$SHA"
          git -C "$RUNNER_TEMP/xmarks" checkout -q --detach "$SHA"
      - name: Refresh vendored copy
        run: bash "$RUNNER_TEMP/xmarks/scripts/install-vendored.sh" "$GITHUB_WORKSPACE"
      - uses: peter-evans/create-pull-request@271a8d0340265f705b14b6d32b9829c1cb33d45e # v7.0.8
YML
}

# sandbox <name> -> prints a root holding a good installer + good workflow
sandbox() {
  local root="${WORK}/$1"
  rm -rf "${root}"; mkdir -p "${root}/scripts" "${root}/.github/workflows"
  good_installer > "${root}/scripts/install-vendored.sh"
  good_workflow  > "${root}/.github/workflows/flywheel-update.yml"
  : > "${root}/allow.txt"
  echo "${root}"
}

# run_check <root> [env VAR=val ...] -> sets RC; output in ${WORK}/out
run_check() {
  local root="$1"; shift
  RC=0
  env FW_PIN_ROOT="${root}" FW_PIN_ALLOW="${root}/allow.txt" "$@" \
    bash "${CHECK}" >"${WORK}/out" 2>&1 || RC=$?
}

saw() { grep -q "$1" "${WORK}/out" || fail "expected output to mention '$1'; got: $(cat "${WORK}/out")"; }

# ------------------------------------------------------------------ cases ---

echo "== a fully pinned sandbox passes =="
R="$(sandbox clean)"
run_check "${R}"
[ "${RC}" -eq 0 ] || fail "clean sandbox must pass: $(cat "${WORK}/out")"
pass "clean sandbox green"

echo "== prose about the hole is not the hole (comments and descriptions) =="
# All three of these were real defects, found when the fixed workflow's own
# header comment — which explains the `git clone` it removed and the `uses:` pin
# it added — was reported as an unpinned clone. A gate that cannot survive being
# documented is a gate nobody can fix.
R="$(sandbox prose)"
python3 - "${R}/.github/workflows/flywheel-update.yml" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read()
header = (
    "# This workflow used to `git clone` the default branch and bash the result.\n"
    "# Pinning the caller's `uses:` alone does not close that.\n"
)
open(p, "w").write(header + t)
PY
python3 - "${R}/.github/workflows/flywheel-update.yml" <<'PY'
import sys
p = sys.argv[1]
t = open(p).read()
t = t.replace("        type: string\n",
              "        type: string\n"
              "        description: must match the caller's `uses:` pin\n")
open(p, "w").write(t)
PY
run_check "${R}"
[ "${RC}" -eq 0 ] || fail "comments and descriptions must not be read as behaviour: $(cat "${WORK}/out")"
pass "comments and description strings ignored"

echo "== revert 1: the caller template goes back to @main =="
R="$(sandbox revert1)"
sed -i 's|flywheel-update\.yml@\${SRC_COMMIT_FULL}|flywheel-update.yml@main|' "${R}/scripts/install-vendored.sh"
run_check "${R}"
[ "${RC}" -ne 0 ] || fail "an @main caller template must fail"
saw "install-vendored.sh"
saw "@main"
pass "revert 1 red, and it names the installer"

echo "== revert 2: caller still pinned, the clone-step verification deleted =="
# This is the decisive case. The caller is untouched and correct; only the
# workflow's pinned checkout is gone, replaced by the unpinned clone that
# shipped before this slice. A gate that only reads `uses:` passes this.
R="$(sandbox revert2)"
python3 - "${R}/.github/workflows/flywheel-update.yml" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p).read()
t = re.sub(
    r"      - name: Fetch the pinned flywheel commit\n(?:.*\n)*?(?=      - name: Refresh)",
    '      - name: Fetch latest flywheel\n'
    '        run: git clone --depth 1 https://github.com/arazvan-ec/xmarks "$RUNNER_TEMP/xmarks"\n',
    t)
open(p, "w").write(t)
PY
grep -q 'git clone' "${R}/.github/workflows/flywheel-update.yml" \
  || fail "fixture bug: revert 2 did not restore the unpinned clone"
grep -q 'flywheel-update.yml@\${SRC_COMMIT_FULL}' "${R}/scripts/install-vendored.sh" \
  || fail "fixture bug: revert 2 must leave the caller pinned"
run_check "${R}"
[ "${RC}" -ne 0 ] || fail "REVERT 2 PASSED — the gate only checks the caller's uses:, which is the exact decoration this slice exists to avoid"
saw "flywheel-update.yml"
saw "clone"
pass "revert 2 red, and it names the clone step (the two halves are independent)"

echo "== the two halves are independent in the other direction too =="
# revert 1 left the workflow correct; revert 2 left the caller correct. Neither
# failure can be explained by the other half, which is what "separately" means.
grep -q 'install-vendored.sh' "${WORK}/out" \
  && fail "revert 2's report blames the installer, so the halves are not separable"
pass "revert 2 does not implicate the installer"

echo "== the caller must pass the same SHA it pins (no drift) =="
R="$(sandbox drift)"
sed -i 's|flywheel_sha: \${SRC_COMMIT_FULL}|flywheel_sha: ${SOME_OTHER_VAR}|' "${R}/scripts/install-vendored.sh"
run_check "${R}"
[ "${RC}" -ne 0 ] || fail "a caller whose input differs from its pin must fail"
pass "pin/input drift red"

echo "== the caller must not pass a short SHA =="
R="$(sandbox short)"
sed -i 's|rev-parse HEAD|rev-parse --short HEAD|' "${R}/scripts/install-vendored.sh"
run_check "${R}"
[ "${RC}" -ne 0 ] || fail "a short SHA is not a valid uses: pin and must fail"
saw "short"
pass "short SHA red"

echo "== the caller template must exist at all =="
R="$(sandbox nocaller)"
sed -i '/flywheel-update\.yml@/d' "${R}/scripts/install-vendored.sh"
run_check "${R}"
[ "${RC}" -ne 0 ] || fail "a missing caller template must fail, not vacuously pass"
pass "absent caller template red (no vacuous pass)"

echo "== the workflow must validate the SHA and refuse when it is not one =="
R="$(sandbox noguard)"
sed -i "/grep -Eq/d" "${R}/.github/workflows/flywheel-update.yml"
run_check "${R}"
[ "${RC}" -ne 0 ] || fail "a workflow with no 40-hex validation must fail"
pass "missing fail-closed guard red"

echo "== the pinned checkout must precede the step that executes the tree =="
R="$(sandbox ordering)"
python3 - "${R}/.github/workflows/flywheel-update.yml" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p).read()
fetch = re.search(r"      - name: Fetch the pinned flywheel commit\n(?:.*\n)*?(?=      - name: Refresh)", t).group(0)
refresh = re.search(r"      - name: Refresh vendored copy\n(?:.*\n)*?(?=      - uses:)", t).group(0)
open(p, "w").write(t.replace(fetch + refresh, refresh + fetch))
PY
run_check "${R}"
[ "${RC}" -ne 0 ] || fail "executing the tree before checking it out must fail"
saw "before"
pass "step ordering enforced"

echo "== swapping the interpreter does not walk past the check =="
# The step that executes the fetched tree happens to say `bash`. If the only
# thing standing between a repo and unreviewed code is which interpreter the
# line names, the check is a spelling test.
for interp in sh python3 node; do
  R="$(sandbox "interp-${interp}")"
  sed -i "s|run: bash \"\$RUNNER_TEMP/xmarks/scripts/install-vendored.sh\" \"\$GITHUB_WORKSPACE\"|run: ${interp} \"\$RUNNER_TEMP/xmarks/scripts/install-vendored.sh\"|" \
    "${R}/.github/workflows/flywheel-update.yml"
  grep -q "${interp} \"\$RUNNER_TEMP" "${R}/.github/workflows/flywheel-update.yml" \
    || fail "fixture bug: ${interp} substitution did not apply"
  sed -i '/checkout -q --detach/d' "${R}/.github/workflows/flywheel-update.yml"
  run_check "${R}"
  [ "${RC}" -ne 0 ] || fail "an unguarded '${interp}' against the fetched tree must fail"
done
pass "sh, python3 and node are caught like bash"

echo "== manipulating the checkout is not executing it =="
# git -C "$RUNNER_TEMP/..." appears in the fetch step itself; reading it as an
# execution would make the fixed workflow unfixable.
R="$(sandbox gitonly)"
run_check "${R}"
[ "${RC}" -eq 0 ] || fail "git against the fetched tree must not count as executing it: $(cat "${WORK}/out")"
pass "git -C against the tree is not an execution"

echo "== an unpinned third-party action fails, and the allowlist can excuse it =="
R="$(sandbox actions)"
sed -i 's|actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2|actions/checkout@v4|' \
  "${R}/.github/workflows/flywheel-update.yml"
run_check "${R}"
[ "${RC}" -ne 0 ] || fail "an unpinned actions/checkout must fail"
saw "actions/checkout@v4"
echo ".github/workflows/flywheel-update.yml actions/checkout@v4 pinned in a later slice" > "${R}/allow.txt"
run_check "${R}"
[ "${RC}" -eq 0 ] || fail "an allowlisted unpinned action must pass: $(cat "${WORK}/out")"
pass "unpinned action red; allowlist excuses it"

echo "== an allowlist entry with no reason is unusable input =="
R="$(sandbox noreason)"
sed -i 's|actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2|actions/checkout@v4|' \
  "${R}/.github/workflows/flywheel-update.yml"
echo ".github/workflows/flywheel-update.yml actions/checkout@v4" > "${R}/allow.txt"
run_check "${R}"
[ "${RC}" -eq 2 ] || fail "an unreasoned allowlist entry must exit 2, got ${RC}"
pass "unreasoned allowlist entry exits 2"

echo "== a stale allowlist entry cannot rot silently =="
R="$(sandbox stale)"
echo ".github/workflows/flywheel-update.yml actions/nothing@v9 nothing matches this" > "${R}/allow.txt"
run_check "${R}"
[ "${RC}" -ne 0 ] || fail "an allowlist entry matching nothing must fail"
saw "matches nothing"
pass "stale allowlist entry red"

echo "== fail-closed: an unreadable workflow is a failure, not a pass =="
# Stated explicitly in the spec because every other flywheel script is fail-open
# and the reflex here would be wrong: this one is CI, not a hook.
R="$(sandbox unreadable)"
rm -f "${R}/.github/workflows/flywheel-update.yml"
run_check "${R}"
[ "${RC}" -ne 0 ] || fail "a missing reusable workflow must fail closed, not pass"
pass "missing workflow fails closed"

R="$(sandbox unreadable2)"
chmod 000 "${R}/.github/workflows/flywheel-update.yml"
run_check "${R}"
CHMOD_RC="${RC}"
chmod 644 "${R}/.github/workflows/flywheel-update.yml"
if [ "$(id -u)" = "0" ]; then
  echo "  skip: running as root, chmod 000 is still readable"
else
  [ "${CHMOD_RC}" -ne 0 ] || fail "an unreadable reusable workflow must fail closed"
  pass "unreadable workflow fails closed"
fi

echo "== the escape hatch is explicit and logged, never silent =="
R="$(sandbox skip)"
sed -i 's|flywheel-update\.yml@\${SRC_COMMIT_FULL}|flywheel-update.yml@main|' "${R}/scripts/install-vendored.sh"
run_check "${R}" SKIP_SUPPLY_CHAIN_PIN=1
[ "${RC}" -eq 0 ] || fail "SKIP_SUPPLY_CHAIN_PIN=1 must pass"
saw "SKIPPED"
pass "skip is logged"

echo "== the repo's own tree passes =="
# Red until T3 and T4 land — that is the point. This assertion is the spec's
# success metric reaching into the real files, not a sandbox.
RC=0
(cd "${SRC}" && bash "${CHECK}" >"${WORK}/out" 2>&1) || RC=$?
[ "${RC}" -eq 0 ] || fail "the repo's own tree must pass: $(cat "${WORK}/out")"
pass "repo tree green"

echo "PASS: check-supply-chain-pin.sh"
