#!/usr/bin/env bash
# flywheel — test for scripts/fw_cutoffs.py and scripts/cutoffs.txt (P54b).
#
# The registry replaces one date literal per gate. The arm that matters is the
# PIN: extracting a literal must not move the value it served, or a stretch of
# history is forgiven or failed by accident and nothing may be backfilled to
# undo it (P18).

set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CUT="${SRC}/scripts/fw_cutoffs.py"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

[ -f "${CUT}" ] || fail "scripts/fw_cutoffs.py does not exist yet"

echo "== the registry serves the value the gate used before extraction =="
# Pinned, not derived: these are the literals as of v0.70.0, read out of the
# three gates before the registry existed. A change here is a policy change and
# must be argued in the row's reason, never arrive as a refactor.
for pair in "route-check 2026-09-17T20:00:00Z" \
            "phase-required 2026-09-17T20:00:00Z" \
            "task-closure 2026-09-21T00:00:00Z" \
            "route-reason 2026-09-23T18:30:00Z"; do
  set -- ${pair}
  got="$(python3 "${CUT}" "$1")" || fail "fw_cutoffs.py $1 exited non-zero"
  [ "${got}" = "$2" ] || fail "cutoff '$1' serves '${got}', pinned at '$2' — extracting a literal must not move it"
done
pass "all four cutoffs serve their pre-extraction value byte for byte"

echo "== two cutoffs share a date on purpose, and the registry says so =="
[ "$(python3 "${CUT}" route-check)" = "$(python3 "${CUT}" phase-required)" ] \
  || fail "route-check and phase-required were placed by one decision (P48) and must match"
grep -qE '^(route-check|phase-required)\b.*\bP48\b' "${SRC}/scripts/cutoffs.txt" \
  || fail "the shared date needs its reason in the registry, or the coupling is again undocumented"
pass "the coupling the copies could not state is stated"

echo "== an env var still overrides, so every existing escape hatch works =="
got="$(FLYWHEEL_ROUTE_CHECK_FROM=2020-01-01T00:00:00Z python3 "${CUT}" route-check FLYWHEEL_ROUTE_CHECK_FROM)"
[ "${got}" = "2020-01-01T00:00:00Z" ] || fail "the env var must win, got '${got}'"
got="$(python3 "${CUT}" route-check FLYWHEEL_ROUTE_CHECK_FROM)"
[ "${got}" = "2026-09-17T20:00:00Z" ] || fail "an unset env var must fall through to the registry, got '${got}'"
got="$(FLYWHEEL_ROUTE_CHECK_FROM= python3 "${CUT}" route-check FLYWHEEL_ROUTE_CHECK_FROM)"
[ "${got}" = "2026-09-17T20:00:00Z" ] || fail "an EMPTY env var must not blank the cutoff — that would forgive the whole corpus, got '${got}'"
pass "env wins, unset and empty both fall through"

echo "== an unknown name fails loudly, never as an empty string =="
RC=0; out="$(python3 "${CUT}" no-such-cutoff 2>&1)" || RC=$?
[ "${RC}" -ne 0 ] || fail "an unknown cutoff must not exit 0 (it would compare against ''), got '${out}'"
case "${out}" in *no-such-cutoff*) ;; *) fail "the error must name the cutoff: ${out}" ;; esac
pass "an unknown name is an error, not a silent empty cut"

echo "== comments and blank lines are not rows =="
grep -q '^#' "${SRC}/scripts/cutoffs.txt" || fail "the registry must carry its reasons as comments"
python3 "${CUT}" route-check >/dev/null || fail "comments must not break parsing"
pass "the registry parses with its prose in it"

echo "== every cutoff in the registry is a well-formed instant =="
python3 - "${SRC}/scripts/cutoffs.txt" <<'PY' || fail "a malformed cutoff would compare as a string and silently mis-sort"
import datetime, sys
bad = []
for raw in open(sys.argv[1]):
    raw = raw.strip()
    if not raw or raw.startswith("#"):
        continue
    parts = raw.split(None, 2)
    if len(parts) < 3:
        bad.append(f"{raw!r}: a row is <name> <iso> <reason>, and the reason is not optional")
        continue
    try:
        datetime.datetime.strptime(parts[1], "%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        bad.append(f"{parts[0]}: {parts[1]!r} is not an ISO instant")
for b in bad:
    print(f"FAIL: {b}", file=sys.stderr)
sys.exit(1 if bad else 0)
PY
pass "every row is <name> <instant> <reason>"

echo "== binds() compares instants, through the one parser every gate uses =="
FW_HERE="${SRC}/scripts" python3 - <<'PY' || fail "binds() must place a timestamp by its instant"
import os, sys
sys.path.insert(0, os.environ["FW_HERE"])
from fw_cutoffs import binds
CUT = "2026-09-17T20:00:00Z"
cases = [
    ("2026-09-17T20:00:00Z", True),        # at the cut
    ("2026-09-17T20:00:00.5Z", True),      # as text, sorts before the cut
    ("2026-09-17T19:59:59.999999Z", False),
    ("2026-09-17T17:30:00-03:00", True),   # 20:30Z; as text, before
    ("2026-09-17T20:30:00+02:00", False),  # 18:30Z; as text, after
    ("2026-09-17T20:00:00+00:00", True),
    ("2026-09-17T20:00:00", True),         # naive reads as UTC
    ("", False),                           # absent: the telemetry gate's to fail
    ("not-a-time", True),                  # unplaceable: never buys forgiveness
]
bad = [(ts, want) for ts, want in cases if binds(ts, CUT) is not want]
for ts, want in bad:
    print(f"FAIL: binds({ts!r}, {CUT!r}) should be {want}", file=sys.stderr)
try:
    binds("2026-09-18T00:00:00Z", "yesterday")
    print("FAIL: an unparsable cut must raise, not compare", file=sys.stderr); bad.append(1)
except ValueError:
    pass
sys.exit(1 if bad else 0)
PY
pass "fractional seconds, offsets and naive times are placed by instant; a bad cut raises"

echo "== an override that is not an instant fails loudly, before any gate compares =="
RC=0; out="$(FW_X=yesterday python3 "${CUT}" route-check FW_X 2>&1)" || RC=$?
[ "${RC}" -eq 2 ] || fail "an unparsable override must exit 2, got ${RC}: ${out}"
pass "a malformed cut exits 2 instead of comparing as text"

echo "fw-cutoffs: all assertions passed"
