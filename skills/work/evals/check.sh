#!/usr/bin/env bash
# Deterministic grader for skills/work evals. Usage: check.sh <eval_id> <workdir>
# Prints PASS/FAIL per expectation; exit 0 only if all pass.
#
# Graded from artifacts, never from the transcript: .check-log is written only by
# run-tests.sh, so "the test ran red while cart.py was still pristine" is a fact
# about what executed. The suite re-run below uses `python3 -m unittest`
# directly, which does NOT append to .check-log — grading must not mutate the log
# it grades.
set -u

ID="${1:?eval id}"; W="${2:?workdir}"
LOG="$W/.check-log"
BASE_FILE="$W/baseline-sha"
rc=0
ok()   { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; rc=1; }
check() { # check <expr...> -- <label>
  local args=(); while [ "$1" != "--" ]; do args+=("$1"); shift; done; shift
  if "${args[@]}" >/dev/null 2>&1; then ok "$1"; else fail "$1"; fi
}

entries()    { grep -E 'RESULT=' "$LOG" 2>/dev/null; }
first_entry(){ entries | head -1; }
last_entry() { entries | tail -1; }
baseline()   { tr -d '[:space:]' < "$BASE_FILE" 2>/dev/null; }

# first logged run: red, against the untouched implementation
red_first() {
  local e; e="$(first_entry)"
  [ -n "$e" ] || return 1
  case "$e" in *"RESULT=FAIL"*) ;; *) return 1 ;; esac
  local sha b; sha="${e##*IMPL_SHA=}"; sha="${sha%%[[:space:]]*}"; b="$(baseline)"
  [ -n "$b" ] && [ "$sha" = "$b" ]
}
green_last() { case "$(last_entry)" in *"RESULT=PASS"*) return 0 ;; *) return 1 ;; esac; }

# Independent re-run: the executor's own last line is a claim, this is the check.
suite_green() { ( cd "$W" && KATA_HARNESS=1 python3 -m unittest >/dev/null 2>&1 ); }

# probe <python> — run a snippet against the workdir's cart.py; exit status is
# the assertion. Behaviour, not a grep for `def`.
probe() { ( cd "$W" && python3 -c "$1" >/dev/null 2>&1 ); }

case "$ID" in
  1)
    check red_first -- "first .check-log entry is RESULT=FAIL with IMPL_SHA equal to baseline-sha (the test ran red BEFORE cart.py changed)"
    check green_last -- "last .check-log entry is RESULT=PASS"
    check grep -q 'apply_discount' "$W/test_cart.py" -- "test_cart.py exercises apply_discount"
    check grep -qE 'assertRaises|ValueError' "$W/test_cart.py" -- "test_cart.py covers the ValueError bounds behaviour"
    check probe 'import cart; assert cart.apply_discount([{"name":"tea","price":2.50,"qty":2}], 10) == 4.5' -- "cart.py implements apply_discount (10% off a 5.00 cart is 4.50)"
    check probe 'import cart
for bad in (-1, 101):
    try: cart.apply_discount([], bad)
    except ValueError: continue
    raise SystemExit(1)' -- "apply_discount raises ValueError outside 0..100"
    check suite_green -- "the final suite is green on an independent re-run"
    ;;
  2)
    check red_first -- "first .check-log entry is RESULT=FAIL with IMPL_SHA equal to baseline-sha (the regression test reproduced the bug BEFORE cart.py changed)"
    check green_last -- "last .check-log entry is RESULT=PASS"
    check grep -qE 'assertRaises|ValueError' "$W/test_cart.py" -- "test_cart.py asserts ValueError for non-positive qty"
    check probe 'import cart
for bad in (0, -3):
    try: cart.add_item([], "tea", 2.50, bad)
    except ValueError: continue
    raise SystemExit(1)' -- "add_item rejects qty <= 0 after the fix"
    check probe 'import cart; assert cart.total(cart.add_item([], "tea", 2.50, 2)) == 5.0' -- "the happy path still works (no fix-by-breaking)"
    check suite_green -- "the final suite is green on an independent re-run"
    ;;
  *) echo "unknown eval id: $ID" >&2; exit 2 ;;
esac

exit "$rc"
