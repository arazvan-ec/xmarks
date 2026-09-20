#!/usr/bin/env bash
# flywheel — test for scripts/check-ci-gate-parity.sh (P52). The gate that asks
# whether the gates this repo ships are the gates CI runs. Covers: a fully wired
# tree passes; an unwired gate fails and is named; a gate referenced only from a
# COMMENT fails (the case that actually happened); a workflow invoking a script
# that does not exist fails; any workflow file counts as wiring; unusable input
# exits 2; the skip is logged; and the real tree is red naming exactly the one
# gate nobody wired.

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="${SRC}/scripts/check-ci-gate-parity.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

# repo <name> -> a throwaway tree with scripts/ and .github/workflows/
repo() {
  local r="${WORK}/$1"
  mkdir -p "${r}/scripts" "${r}/.github/workflows"
  printf '%s\n' "${r}"
}
gate() { printf '#!/usr/bin/env bash\nexit 0\n' > "$1/scripts/check-$2.sh"; }
# workflow <root> <name> <body-lines...>
workflow() {
  local r="$1" name="$2"; shift 2
  { printf 'name: %s\njobs:\n  a:\n    steps:\n' "${name}"; printf '%s\n' "$@"; } \
    > "${r}/.github/workflows/${name}.yml"
}

run() { RC=0; bash "${GATE}" "$@" >"${WORK}/out" 2>&1 || RC=$?; }

echo "== a tree whose every gate is invoked passes =="
R="$(repo wired)"; gate "${R}" alpha; gate "${R}" beta
workflow "${R}" ci "      - run: bash scripts/check-alpha.sh" \
                  "      - run: bash scripts/check-beta.sh"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a fully wired tree must pass, got ${RC}: $(cat "${WORK}/out")"
pass "a fully wired tree passes"

echo "== a gate no workflow invokes fails, and is NAMED =="
R="$(repo unwired)"; gate "${R}" alpha; gate "${R}" orphan
workflow "${R}" ci "      - run: bash scripts/check-alpha.sh"
run "${R}"
[ "${RC}" -eq 1 ] || fail "an unwired gate must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q "check-orphan.sh" "${WORK}/out" || fail "the unwired gate must be named: $(cat "${WORK}/out")"
grep -q "check-alpha.sh" "${WORK}/out" && fail "a wired gate must not be reported: $(cat "${WORK}/out")"
pass "an unwired gate exits 1 and is named alone"

echo "== a gate named only in a COMMENT is not wired =="
# The case that actually happened: check-supply-chain-pin.sh appears twice in
# .github/workflows/ and both are comments, so any check that greps without
# stripping them reports the tree as fine.
R="$(repo commented)"; gate "${R}" alpha; gate "${R}" orphan
workflow "${R}" ci "      # scripts/check-orphan.sh guards the thing" \
                  "      - run: bash scripts/check-alpha.sh"
run "${R}"
[ "${RC}" -eq 1 ] || fail "a comment must not count as wiring, got ${RC}: $(cat "${WORK}/out")"
grep -q "check-orphan.sh" "${WORK}/out" || fail "the commented gate must be named: $(cat "${WORK}/out")"
pass "a mention in a comment is not an invocation"

echo "== a workflow invoking a script that does not exist fails =="
# The converse. Without it, a green parity can be bought by renaming a step.
R="$(repo ghost)"; gate "${R}" alpha
workflow "${R}" ci "      - run: bash scripts/check-alpha.sh" \
                  "      - run: bash scripts/check-typo.sh"
run "${R}"
[ "${RC}" -eq 1 ] || fail "an invocation of a missing gate must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q "check-typo.sh" "${WORK}/out" || fail "the missing gate must be named: $(cat "${WORK}/out")"
pass "a workflow cannot invoke a gate that is not there"

echo "== wiring in ANY workflow file counts =="
R="$(repo anyfile)"; gate "${R}" alpha; gate "${R}" beta
workflow "${R}" ci "      - run: bash scripts/check-alpha.sh"
workflow "${R}" other "      - run: bash scripts/check-beta.sh"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a gate wired in a second workflow must count, got ${RC}: $(cat "${WORK}/out")"
pass "any workflow file is wiring"

echo "== a gate invoked without the bash prefix still counts =="
# The gate asserts that CI reaches the script, not how the step spells it.
R="$(repo prefix)"; gate "${R}" alpha
workflow "${R}" ci "      - run: ./scripts/check-alpha.sh --strict"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a direct invocation must count, got ${RC}: $(cat "${WORK}/out")"
pass "an invocation counts however it is spelled"

echo "== no workflows at all is unusable input, not a pass =="
R="$(repo noflows)"; gate "${R}" alpha
rm -rf "${R}/.github"
run "${R}"
[ "${RC}" -eq 2 ] || fail "a tree with no workflows must exit 2, got ${RC}: $(cat "${WORK}/out")"
pass "no workflows exits 2"

echo "== the skip is logged, never silent =="
R="$(repo skipme)"; gate "${R}" orphan
workflow "${R}" ci "      - run: true"
RC=0; SKIP_CI_GATE_PARITY="not now" bash "${GATE}" "${R}" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 0 ] || fail "the skip must exit 0, got ${RC}"
grep -qi "skip" "${WORK}/out" || fail "the skip must announce itself: $(cat "${WORK}/out")"
pass "skip exits 0 with a logged notice"

echo "== the real tree =="
run "${SRC}"
if [ "${RC}" -eq 0 ]; then
  pass "this repo wires every gate it ships"
else
  # Before T3 wires them, the decisive clause: red, and red ONLY for the two
  # gates known to be unwired at that point — the hole this cycle exists to
  # close, and this gate itself, which is not yet in the workflow. Anything
  # else named here is a real finding, not the expected transient.
  grep -q "check-supply-chain-pin.sh" "${WORK}/out" \
    || fail "the real tree is red but not for the known reason: $(cat "${WORK}/out")"
  unexpected="$(grep -oE "check-[a-z-]+\.sh" "${WORK}/out" | sort -u \
    | grep -vE "^check-(supply-chain-pin|ci-gate-parity)\.sh$" || true)"
  [ -z "${unexpected}" ] \
    || fail "the real tree names a gate beyond the known transient: ${unexpected}"
  pass "the real tree is red naming only the known unwired gates (both wired in T3)"
fi

echo "ALL PASS"
