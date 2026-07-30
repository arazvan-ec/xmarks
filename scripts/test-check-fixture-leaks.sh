#!/usr/bin/env bash
# flywheel — test for the fixture-leak gate, scripts/check-fixture-leaks.sh (P26).
# Covers: the committed fixtures pass; a planted leak in each shape fails and is
# reported with file, line and pattern; an emptied allowlist makes the legitimate
# run-tests.sh hits fail (proving the allowlist is load-bearing, not decoration);
# an allowlist entry is scoped to one path and one pattern; a stale allowlist
# entry is reported; SKIP_FIXTURE_LEAKS=1 is an explicit, logged escape.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${SRC}/scripts/check-fixture-leaks.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

# sandbox <name> -> prints a fixtures root holding one clean fixture
sandbox() {
  local root="${WORK}/$1"
  rm -rf "${root}"; mkdir -p "${root}/demo/evals/fixtures/mini"
  printf '# mini\n\nAn ordinary little repo.\n' > "${root}/demo/evals/fixtures/mini/README.md"
  printf 'print("hi")\n' > "${root}/demo/evals/fixtures/mini/app.py"
  echo "${root}"
}

# run_check <fixtures-root> <allowlist> [env VAR=val ...] -> sets RC, out in ${WORK}/out
run_check() {
  local root="$1" allow="$2"; shift 2
  RC=0
  env FW_FIXTURE_ROOT="${root}" FW_LEAK_ALLOW="${allow}" "$@" \
    bash "${CHECK}" >"${WORK}/out" 2>&1 || RC=$?
}

[ -f "${CHECK}" ] || fail "no gate at scripts/check-fixture-leaks.sh"
bash -n "${CHECK}" || fail "gate is not valid bash"

echo "== the committed fixtures pass with the committed allowlist =="
RC=0
(cd "${SRC}" && bash "${CHECK}" >"${WORK}/out" 2>&1) || RC=$?
[ "${RC}" -eq 0 ] || fail "the repo's own fixtures must pass: $(cat "${WORK}/out")"
pass "repo fixtures clean"

echo "== a clean sandbox passes =="
R="$(sandbox clean)"; : > "${WORK}/empty-allow"
run_check "${R}" "${WORK}/empty-allow"
[ "${RC}" -eq 0 ] || fail "a clean fixture must pass: $(cat "${WORK}/out")"
pass "clean sandbox passes"

echo "== each leak shape is caught =="
# The four real leaks this gate exists to prevent, plus the vocabulary P26 names.
for leak in \
  'The eval asserts that the first logged run is RESULT=FAIL.' \
  'The only correct verdict here is VERDICT: FAIL.' \
  'The test must run red against a pristine cart.py.' \
  'This directory is an eval fixture template, work in a copy.' \
  'IMPL_SHA must equal baseline-sha before the fix.' \
  'Red then green is what is graded.' \
; do
  R="$(sandbox leak)"
  printf '%s\n' "${leak}" >> "${R}/demo/evals/fixtures/mini/README.md"
  run_check "${R}" "${WORK}/empty-allow"
  [ "${RC}" -ne 0 ] || fail "not caught: ${leak}"
  grep -q 'mini/README.md' "${WORK}/out" || fail "the report must name the offending file for: ${leak}"
  grep -qE ':[0-9]+:' "${WORK}/out" || fail "the report must name the line number for: ${leak}"
  pass "caught: ${leak}"
done

echo "== a leak in a non-README fixture file is caught too =="
R="$(sandbox leak-code)"
printf '# the eval asserts red-before-green here\n' >> "${R}/demo/evals/fixtures/mini/app.py"
run_check "${R}" "${WORK}/empty-allow"
[ "${RC}" -ne 0 ] || fail "a leak in app.py must be caught (the run-tests.sh leak was a code comment)"
pass "code comments are scanned"

echo "== files outside evals/fixtures/ are not scanned =="
R="$(sandbox outside)"
mkdir -p "${R}/demo/evals"
printf 'The eval asserts RESULT=FAIL first.\n' > "${R}/demo/evals/README.md"
run_check "${R}" "${WORK}/empty-allow"
[ "${RC}" -eq 0 ] || fail "only fixture files are copied into the workdir; evals/README.md must be free to explain grading: $(cat "${WORK}/out")"
pass "eval READMEs stay free to hold ground truth"

echo "== the allowlist is load-bearing: emptying it fails the real fixtures =="
RC=0
(cd "${SRC}" && env FW_LEAK_ALLOW="${WORK}/empty-allow" bash "${CHECK}" >"${WORK}/out" 2>&1) || RC=$?
[ "${RC}" -ne 0 ] || fail "with no allowlist, run-tests.sh's .check-log/RESULT=/IMPL_SHA hits must fail — otherwise the vocabulary is too loose to catch anything"
grep -q 'run-tests.sh' "${WORK}/out" || fail "the unallowlisted run should name run-tests.sh: $(cat "${WORK}/out")"
pass "vocabulary is strict; the allowlist is what lets the runner through"

echo "== an allowlist entry is scoped to one path and one pattern =="
R="$(sandbox scoped)"
printf 'RESULT=FAIL is logged here.\n' >> "${R}/demo/evals/fixtures/mini/app.py"
printf 'RESULT=FAIL is logged here too.\n' >> "${R}/demo/evals/fixtures/mini/README.md"
printf 'demo/evals/fixtures/mini/app.py result it writes the line\n' > "${WORK}/scoped-allow"
run_check "${R}" "${WORK}/scoped-allow"
[ "${RC}" -ne 0 ] || fail "allowlisting app.py must not also allow README.md"
grep -q 'mini/README.md' "${WORK}/out" || fail "the un-allowlisted file must be reported"
grep -q 'mini/app.py' "${WORK}/out" && fail "the allowlisted file must not be reported"
pass "allowlist entries are per path + pattern"

echo "== an allowlist entry for the wrong pattern does not blanket the file =="
R="$(sandbox wrongpat)"
printf 'The only correct verdict is VERDICT: FAIL.\n' >> "${R}/demo/evals/fixtures/mini/app.py"
printf 'demo/evals/fixtures/mini/app.py result unrelated reason\n' > "${WORK}/wrong-allow"
run_check "${R}" "${WORK}/wrong-allow"
[ "${RC}" -ne 0 ] || fail "an entry for pattern 'result' must not silence pattern 'verdict'"
pass "patterns are not blanket-allowed per file"

echo "== an allowlist entry needs a reason =="
printf 'demo/evals/fixtures/mini/app.py result\n' > "${WORK}/noreason-allow"
R="$(sandbox noreason)"
printf 'RESULT=FAIL\n' >> "${R}/demo/evals/fixtures/mini/app.py"
run_check "${R}" "${WORK}/noreason-allow"
[ "${RC}" -ne 0 ] || fail "an allowlist entry with no reason must be rejected — 'it explains what we measure' is exactly what a reason must rule out"
pass "reasonless allowlist entries are rejected"

echo "== an unknown pattern id in the allowlist is rejected =="
printf 'demo/evals/fixtures/mini/app.py nosuchpattern a reason\n' > "${WORK}/badid-allow"
R="$(sandbox badid)"
run_check "${R}" "${WORK}/badid-allow"
[ "${RC}" -ne 0 ] || fail "a typo'd pattern id must fail loudly, not silently allow nothing"
pass "unknown pattern ids are rejected"

echo "== a stale allowlist entry is reported =="
R="$(sandbox stale)"
printf 'demo/evals/fixtures/mini/app.py result the hit that no longer exists\n' > "${WORK}/stale-allow"
run_check "${R}" "${WORK}/stale-allow"
[ "${RC}" -ne 0 ] || fail "an allowlist entry matching nothing must be reported — stale exemptions silently widen the gate"
grep -qi 'stale\|unused\|no longer' "${WORK}/out" || fail "the report must say the entry is stale: $(cat "${WORK}/out")"
pass "stale entries are reported"

echo "== the escape hatch is explicit and logged =="
R="$(sandbox skipme)"
printf 'The eval asserts VERDICT: FAIL.\n' >> "${R}/demo/evals/fixtures/mini/README.md"
run_check "${R}" "${WORK}/empty-allow" SKIP_FIXTURE_LEAKS=1
[ "${RC}" -eq 0 ] || fail "SKIP_FIXTURE_LEAKS=1 must skip"
grep -qi 'skipped' "${WORK}/out" || fail "the skip must be logged, never silent: $(cat "${WORK}/out")"
pass "SKIP_FIXTURE_LEAKS=1 skips with a notice"

echo "== no fixtures at all is an error, not a pass =="
R="${WORK}/nofixtures"; mkdir -p "${R}"
run_check "${R}" "${WORK}/empty-allow"
[ "${RC}" -eq 2 ] || fail "an empty fixtures root must exit 2 — a vacuous green is how this gate would rot, got ${RC}"
pass "empty scan exits 2"

echo "check-fixture-leaks: OK"
