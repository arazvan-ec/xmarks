#!/usr/bin/env bash
# flywheel — test for scripts/sweep.sh (P60): the local sweep is the CI sweep.
# Covers: the gate list is the workflow's list, and a check-* added to the
# workflow joins it (a commented one does not); a failing script exits 1 and is
# named even when its output ends in a success line; the base ref reaches the two
# base-ref gates; a missing claude CLI is SKIPPED, not passed; and every script
# gets its own TMPDIR.

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWEEP="${SRC}/scripts/sweep.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

[ -f "${SWEEP}" ] || fail "scripts/sweep.sh does not exist"

NOCLAUDE="fw-no-such-claude-$$"

# tree <name> -> a throwaway repo: one passing test, one base-ref gate, one plain gate
tree() {
  local r="${WORK}/$1"
  mkdir -p "${r}/scripts" "${r}/.github/workflows"
  printf '#!/usr/bin/env bash\necho fine\n' > "${r}/scripts/test-ok.sh"
  printf '#!/usr/bin/env bash\necho "$@" > "%s/pairing.args"\n' "${r}" > "${r}/scripts/check-test-pairing.sh"
  printf '#!/usr/bin/env bash\necho "$@" > "%s/bump.args"\n' "${r}" > "${r}/scripts/check-release-bump.sh"
  printf '#!/usr/bin/env bash\necho "$TMPDIR" >> "%s/tmpdirs"\n' "${r}" > "${r}/scripts/check-plain.sh"
  cat > "${r}/.github/workflows/validate-plugins.yml" <<'YML'
jobs:
  test-installer:
    steps:
      # run: bash scripts/check-commented.sh
      - name: pairing
        run: bash scripts/check-test-pairing.sh "origin/${{ github.base_ref }}"
      - name: bump
        run: bash scripts/check-release-bump.sh "origin/${{ github.base_ref }}"
      - name: plain
        run: bash scripts/check-plain.sh
YML
  printf '%s\n' "${r}"
}

run() { RC=0; SWEEP_ROOT="$1" SWEEP_CLAUDE="${NOCLAUDE}" bash "${SWEEP}" "${@:2}" >"${WORK}/out" 2>&1 || RC=$?; }

echo "== the gate list is the workflow's list, on the real tree =="
want="$(grep -v '^[[:space:]]*#' "${SRC}/.github/workflows/validate-plugins.yml" \
        | grep -oE 'scripts/check-[A-Za-z0-9_-]+\.sh' | sort)"
got="$(SWEEP_CLAUDE="${NOCLAUDE}" bash "${SWEEP}" --list origin/main | grep -oE '^bash scripts/check-[A-Za-z0-9_-]+\.sh' | sed 's/^bash //' | sort)"
[ -n "${want}" ] || fail "the workflow names no check-* gate — the grep is broken"
[ "${want}" = "${got}" ] || fail "gate list differs from the workflow: want [${want}] got [${got}]"
pass "$(printf '%s\n' "${want}" | wc -l | tr -d ' ') gates, same as the workflow"

echo "== every scripts/test-*.sh is discovered on the real tree =="
nt="$(ls "${SRC}"/scripts/test-*.sh | wc -l | tr -d ' ')"
gt="$(SWEEP_CLAUDE="${NOCLAUDE}" bash "${SWEEP}" --list | grep -cE '^bash scripts/test-[A-Za-z0-9_.-]+\.sh$')"
[ "${nt}" = "${gt}" ] || fail "want ${nt} test scripts, listed ${gt}"
pass "${nt} test scripts listed"

echo "== a check-* added to the workflow joins the list; a commented one does not =="
R="$(tree added)"
printf '#!/usr/bin/env bash\nexit 0\n' > "${R}/scripts/check-new.sh"
printf '      - name: new\n        run: bash scripts/check-new.sh --flag\n' >> "${R}/.github/workflows/validate-plugins.yml"
run "${R}" --list
grep -qx 'bash scripts/check-new.sh --flag' "${WORK}/out" || fail "an added gate must be listed with its args: $(cat "${WORK}/out")"
grep -q 'check-commented' "${WORK}/out" && fail "a commented gate must not be listed: $(cat "${WORK}/out")"
pass "added gate listed with its arguments, commented one ignored"

echo "== a green tree passes and prints N/N =="
R="$(tree green)"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a green tree must exit 0, got ${RC}: $(cat "${WORK}/out")"
grep -qx '4/4 passed' "${WORK}/out" || fail "want '4/4 passed': $(cat "${WORK}/out")"
grep -qx 'PASS scripts/test-ok.sh' "${WORK}/out" || fail "each script prints PASS <name>: $(cat "${WORK}/out")"
pass "4/4 passed"

echo "== the base ref reaches check-release-bump.sh and check-test-pairing.sh =="
[ "$(cat "${R}/pairing.args")" = "origin/main" ] || fail "pairing got [$(cat "${R}/pairing.args")], want origin/main by default"
[ "$(cat "${R}/bump.args")" = "origin/main" ] || fail "bump got [$(cat "${R}/bump.args")], want origin/main by default"
run "${R}" origin/release-x
[ "$(cat "${R}/pairing.args")" = "origin/release-x" ] || fail "pairing got [$(cat "${R}/pairing.args")], want origin/release-x"
[ "$(cat "${R}/bump.args")" = "origin/release-x" ] || fail "bump got [$(cat "${R}/bump.args")], want origin/release-x"
pass "default origin/main, explicit ref passed through"

echo "== each script runs with a private TMPDIR =="
run "${R}"
[ "$(wc -l < "${R}/tmpdirs")" -ge 2 ] || fail "check-plain.sh should have recorded its TMPDIR"
[ "$(sort -u "${R}/tmpdirs" | wc -l)" -eq "$(wc -l < "${R}/tmpdirs")" ] || fail "two runs shared a TMPDIR: $(cat "${R}/tmpdirs")"
grep -qx "${TMPDIR:-/tmp}" "${R}/tmpdirs" && fail "the script ran in the caller's TMPDIR"
pass "a fresh TMPDIR per run"

echo "== a failing script exits 1 and is named, even if its output ends in success =="
R="$(tree red)"
printf '#!/usr/bin/env bash\necho "line one"\necho "all 9 passed"\nexit 1\n' > "${R}/scripts/test-liar.sh"
run "${R}"
[ "${RC}" -eq 1 ] || fail "a failing script must make the sweep exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -qx 'FAIL scripts/test-liar.sh' "${WORK}/out" || fail "the failing script must be named: $(cat "${WORK}/out")"
grep -q 'all 9 passed' "${WORK}/out" || fail "its tail must be shown: $(cat "${WORK}/out")"
grep -qx '4/5 passed' "${WORK}/out" || fail "want '4/5 passed': $(cat "${WORK}/out")"
pass "exit 1, FAIL named, tail shown, 4/5"

echo "== a missing claude CLI reports SKIPPED; a present one runs =="
R="$(tree cli)"
run "${R}"
grep -q '^SKIPPED claude plugin validate' "${WORK}/out" || fail "missing CLI must say SKIPPED: $(cat "${WORK}/out")"
mkdir -p "${WORK}/bin"
printf '#!/usr/bin/env bash\necho "$@" > "%s/claude.args"\n' "${R}" > "${WORK}/bin/fakeclaude"; chmod +x "${WORK}/bin/fakeclaude"
RC=0; SWEEP_ROOT="${R}" SWEEP_CLAUDE="${WORK}/bin/fakeclaude" bash "${SWEEP}" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 0 ] || fail "present CLI, green tree must pass: $(cat "${WORK}/out")"
[ "$(cat "${R}/claude.args")" = "plugin validate . --strict" ] || fail "claude got [$(cat "${R}/claude.args" 2>/dev/null)]"
grep -qx '5/5 passed' "${WORK}/out" || fail "the validator counts when it runs: $(cat "${WORK}/out")"
pass "SKIPPED when absent, run and counted when present"

echo "test-sweep: OK"
