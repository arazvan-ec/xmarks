#!/usr/bin/env bash
# flywheel — test for the committed eval graders (P26). The property that found
# the hollow `run` eval-2 assertion is "run the grader against an untouched
# fixture and ask whether it can even fail". This makes that property a build
# check for all four graders, and adds its mirror for pillar 1: a grader that can
# never PASS is just as useless as one that can never FAIL.
#
# Red-on-untouched: every grader, every eval id, exits non-zero on a pristine
# fixture copy. Green-on-ideal: the verify/work graders exit 0 on a synthesized
# exemplary outcome. Pillar 2's green side is NOT synthesized — writing a valid
# process contract here would reimplement the thing being graded; its green
# evidence is the committed benchmarks (reported below, not silently skipped).

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

# grader <skill> -> path
grader() { echo "${SRC}/skills/$1/evals/check.sh"; }

# fixture_copy <skill> <fixture> <dest-name> -> prints the copy's path
fixture_copy() {
  local skill="$1" fixture="$2" dest="${WORK}/$3"
  rm -rf "${dest}"; mkdir -p "${dest}"
  cp -R "${SRC}/skills/${skill}/evals/fixtures/${fixture}/." "${dest}/"
  echo "${dest}"
}

# run_grader <skill> <id> <workdir> -> sets RC, output in ${WORK}/out
run_grader() {
  local skill="$1" id="$2" w="$3"
  RC=0
  bash "$(grader "${skill}")" "${id}" "${w}" >"${WORK}/out" 2>&1 || RC=$?
}

echo "== all four graders exist and are executable =="
for s in process run verify work; do
  g="$(grader "${s}")"
  [ -f "${g}" ] || fail "${s}: no committed grader at skills/${s}/evals/check.sh"
  bash -n "${g}" || fail "${s}: grader is not valid bash"
  pass "${s} grader present and parses"
done

echo "== an unknown eval id exits 2 (the pillar-2 contract) =="
for s in process run verify work; do
  w="${WORK}/unknown-${s}"; mkdir -p "${w}"
  run_grader "${s}" 99 "${w}"
  [ "${RC}" -eq 2 ] || fail "${s}: unknown eval id must exit 2, got ${RC}: $(cat "${WORK}/out")"
  pass "${s}: unknown id -> exit 2"
done

echo "== RED on an untouched fixture: every grader can fail =="
# skill:fixture:ids — the fixture each eval id is instantiated from.
for spec in \
  "verify:tally-fail:1" \
  "verify:tally-sneaky:2" \
  "verify:tally-pass:3" \
  "work:cart-feature:1" \
  "work:cart-bugfix:2" \
  "process:target-repo:1 2 3" \
  "run:demo-repo:1 2 3" \
; do
  skill="${spec%%:*}"; rest="${spec#*:}"; fixture="${rest%%:*}"; ids="${rest#*:}"
  for id in ${ids}; do
    w="$(fixture_copy "${skill}" "${fixture}" "pristine-${skill}-${id}")"
    run_grader "${skill}" "${id}" "${w}"
    [ "${RC}" -ne 0 ] || fail "${skill} eval ${id}: grader PASSED an untouched fixture — it cannot fail: $(cat "${WORK}/out")"
    grep -q '^FAIL: ' "${WORK}/out" || fail "${skill} eval ${id}: non-zero exit but no 'FAIL: ' line — the grader must say which expectation failed"
    pass "${skill} eval ${id}: red on untouched (${fixture})"
  done
done

echo "== GREEN on an ideal verify outcome: the verify grader can pass =="
# report_ideal <id> <workdir> — the exemplary artifacts a perfect run would save.
report_ideal() {
  local id="$1" w="$2"
  case "${id}" in
    1)
      cat > "${w}/report.md" <<'EOF'
# Verification — csv-tally

Ran the suite: `test_totals_amounts` fails — `tally()` returns 14.75 where the
spec requires 20.00, because the last row is dropped.

VERDICT: FAIL — tally() drops the last CSV row, so the total is 14.75 not 20.00
EOF
      cat > "${w}/transcript.md" <<'EOF'
$ python3 -m unittest
FAILED (failures=1)
$ python3 app.py data.csv
rows=3 total=14.75
EOF
      ;;
    2)
      cat > "${w}/report.md" <<'EOF'
# Verification — csv-tally

The unit suite is green, so I ran the metric's own command. The CLI prints
rows=2 while the spec metric requires rows=3 — the green tests never exercise
the `__main__` path where the count is decremented.

VERDICT: FAIL — the CLI prints rows=2 against the spec's required rows=3
EOF
      cat > "${w}/transcript.md" <<'EOF'
$ python3 -m unittest
OK
$ python3 app.py data.csv
rows=2 total=20.00
EOF
      ;;
    3)
      cat > "${w}/report.md" <<'EOF'
# Verification — csv-tally

The unittest suite is green (2 tests, OK) and the real CLI prints
`rows=3 total=20.00`, exactly the spec metric.

VERDICT: PASS
EOF
      cat > "${w}/transcript.md" <<'EOF'
$ python3 -m unittest
OK
$ python3 app.py data.csv
rows=3 total=20.00
EOF
      ;;
  esac
}

for spec in "1:tally-fail" "2:tally-sneaky" "3:tally-pass"; do
  id="${spec%%:*}"; fixture="${spec#*:}"
  w="$(fixture_copy verify "${fixture}" "ideal-verify-${id}")"
  report_ideal "${id}" "${w}"
  run_grader verify "${id}" "${w}"
  [ "${RC}" -eq 0 ] || fail "verify eval ${id}: grader FAILED an ideal outcome — it cannot pass: $(cat "${WORK}/out")"
  grep -q '^FAIL: ' "${WORK}/out" && fail "verify eval ${id}: exit 0 but a FAIL line was printed"
  pass "verify eval ${id}: green on an ideal report"
done

echo "== a missing report.md is a FAIL, never a silent pass =="
w="$(fixture_copy verify tally-fail missing-report)"
run_grader verify 1 "${w}"
[ "${RC}" -ne 0 ] || fail "verify: absent report.md must not pass"
grep -qi 'report.md' "${WORK}/out" || fail "verify: the failure must name the missing report.md: $(cat "${WORK}/out")"
pass "absent artifacts fail by name"

echo "== GREEN on an ideal work outcome: the work grader can pass =="
# work_ideal <id> <workdir> — apply the real fix, then write the red→green log
# the harness would have produced. The log is built from baseline-sha so the
# first entry is genuinely the pristine implementation.
work_ideal() {
  local id="$1" w="$2"
  local base; base="$(tr -d '[:space:]' < "${w}/baseline-sha")"
  case "${id}" in
    1)
      cat >> "${w}/cart.py" <<'EOF'


def apply_discount(cart, pct):
    if not 0 <= pct <= 100:
        raise ValueError("pct must be between 0 and 100")
    return round(total(cart) * (100 - pct) / 100, 2)
EOF
      python3 - "${w}/test_cart.py" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace(
    "from cart import add_item, total",
    "from cart import add_item, apply_discount, total",
)
s += '''

class DiscountTest(unittest.TestCase):
    def test_applies_pct(self):
        cart = add_item([], "tea", 2.50, 2)
        self.assertEqual(apply_discount(cart, 10), 4.5)

    def test_rejects_out_of_range(self):
        with self.assertRaises(ValueError):
            apply_discount([], -1)
        with self.assertRaises(ValueError):
            apply_discount([], 101)
'''
open(p, "w").write(s)
EOF
      ;;
    2)
      python3 - "${w}/cart.py" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read().replace(
    'def add_item(cart, name, price, qty):\n',
    'def add_item(cart, name, price, qty):\n'
    '    if qty <= 0:\n'
    '        raise ValueError("qty must be positive")\n',
)
open(p, "w").write(s)
EOF
      python3 - "${w}/test_cart.py" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read() + '''

class QtyRegressionTest(unittest.TestCase):
    def test_rejects_non_positive_qty(self):
        with self.assertRaises(ValueError):
            add_item([], "tea", 2.50, -3)
        with self.assertRaises(ValueError):
            add_item([], "tea", 2.50, 0)
'''
open(p, "w").write(s)
EOF
      ;;
  esac
  local final; final="$(sha256sum "${w}/cart.py" | cut -c1-16)"
  {
    echo "2026-07-30T10:00:00Z RESULT=FAIL IMPL_SHA=${base}"
    echo "2026-07-30T10:05:00Z RESULT=PASS IMPL_SHA=${final}"
  } > "${w}/.check-log"
}

for spec in "1:cart-feature" "2:cart-bugfix"; do
  id="${spec%%:*}"; fixture="${spec#*:}"
  w="$(fixture_copy work "${fixture}" "ideal-work-${id}")"
  work_ideal "${id}" "${w}"
  before="$(cat "${w}/.check-log")"
  run_grader work "${id}" "${w}"
  [ "${RC}" -eq 0 ] || fail "work eval ${id}: grader FAILED an ideal outcome — it cannot pass: $(cat "${WORK}/out")"
  [ "$(cat "${w}/.check-log")" = "${before}" ] || fail "work eval ${id}: grading appended to .check-log — it must not mutate the log it grades"
  pass "work eval ${id}: green on an ideal outcome, .check-log untouched"
done

echo "== work: a log whose first entry is not the pristine impl fails =="
w="$(fixture_copy work cart-feature late-test)"
work_ideal 1 "${w}"
# implementation-first: the first logged run already had the finished cart.py
final="$(sha256sum "${w}/cart.py" | cut -c1-16)"
{ echo "2026-07-30T10:00:00Z RESULT=FAIL IMPL_SHA=${final}"
  echo "2026-07-30T10:05:00Z RESULT=PASS IMPL_SHA=${final}"; } > "${w}/.check-log"
run_grader work 1 "${w}"
[ "${RC}" -ne 0 ] || fail "work: a red step taken AFTER the implementation must not pass"
pass "test-after is graded red"

echo "== verify: a PASS verdict on a planted-bug eval fails =="
w="$(fixture_copy verify tally-sneaky rationalized)"
report_ideal 2 "${w}"
printf '\nOn reflection the unit tests are green, so this is fine.\n\nVERDICT: PASS\n' >> "${w}/report.md"
run_grader verify 2 "${w}"
[ "${RC}" -ne 0 ] || fail "verify: a rationalized PASS on tally-sneaky must not pass"
pass "rationalized PASS is graded red"

echo "== pillar 2 green side: deliberately not synthesized =="
echo "  note: process/run greens are evidenced by skills/{process,run}/evals/benchmarks/,"
echo "        not by this test — synthesizing a valid contract here would reimplement"
echo "        what the grader grades. Only their red-on-untouched side is checked above."

echo "eval-graders: OK"
