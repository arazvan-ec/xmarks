#!/usr/bin/env bash
# flywheel — test for the read meter (P44).
# Asserts the PostToolUse half records what a tool call brought back, keyed by
# session and outside the project; that it stays silent and exits 0 on anything
# it cannot measure; and that the --since half distinguishes an OBSERVED zero
# (the meter ran, nothing was read) from UNMEASURED (no meter ran at all) —
# the P40a rule one level down, where conflating the two fabricates the win.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${SRC}/scripts/read-meter.sh"
WORK="$(mktemp -d)"
export TMPDIR="${WORK}"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

meter_for() {
  FW_SID="$1" FW_TMP="${WORK}" python3 -c '
import hashlib, os
print(os.path.join(os.environ["FW_TMP"],
      "flywheel-reads-" + hashlib.sha256(os.environ["FW_SID"].encode()).hexdigest()[:16] + ".jsonl"))'
}

feed() {
  FW_SID="$1" FW_TOOL="$2" FW_RESP="$3" python3 -c '
import json, os
resp = os.environ["FW_RESP"]
print(json.dumps({"session_id": os.environ["FW_SID"],
                  "tool_name": os.environ["FW_TOOL"],
                  "hook_event_name": "PostToolUse",
                  "tool_response": json.loads(resp) if resp else None}))' | bash "${SCRIPT}"
}

rows() { FW_F="$1" python3 -c '
import json, os
print(json.dumps([json.loads(l) for l in open(os.environ["FW_F"], encoding="utf-8") if l.strip()]))'; }

# --- a Read records the bytes that came back ------------------------------
feed s1 Read '{"type":"text","file":{"filePath":"/p/a.txt","content":"0123456789"}}'
M1="$(meter_for s1)"
[ -f "${M1}" ] || fail "no meter file written at ${M1}"
pass "a measurable tool call writes a meter line"

FW_M="${M1}" python3 - <<'PY' || fail "the meter row is malformed"
import json, os, sys
rows = [json.loads(l) for l in open(os.environ["FW_M"], encoding="utf-8") if l.strip()]
if len(rows) != 1:
    print("expected 1 row, got %d" % len(rows), file=sys.stderr); sys.exit(1)
r = rows[0]
if r["tool"] != "Read":
    print("tool not captured: %r" % (r,), file=sys.stderr); sys.exit(1)
# filePath (8) + content (10) + type "text" (4) = 22 string-leaf bytes.
if r["bytes"] != 22:
    print("bytes should sum every string leaf, got %r" % (r["bytes"],), file=sys.stderr); sys.exit(1)
if not r.get("ts"):
    print("no timestamp", file=sys.stderr); sys.exit(1)
PY
pass "the row carries the tool, a timestamp, and every string leaf's bytes"

# --- the dict shape differs per tool; the meter must not assume one --------
feed s1 Bash '{"stdout":"abcde","stderr":"xy","interrupted":false,"isImage":false}'
R="$(rows "${M1}")"
FW_R="${R}" python3 - <<'PY' || fail "a Bash response was not measured"
import json, os, sys
rows = json.loads(os.environ["FW_R"])
if len(rows) != 2:
    print("the second call did not append: %d rows" % len(rows), file=sys.stderr); sys.exit(1)
if rows[1]["bytes"] != 7:  # stdout 5 + stderr 2; booleans are not text
    print("Bash bytes wrong: %r" % (rows[1]["bytes"],), file=sys.stderr); sys.exit(1)
PY
pass "a differently shaped response is measured without a per-tool extractor"

# --- a shape that does not exist yet still counts --------------------------
feed s1 FutureTool '{"a":{"b":["xxx",{"c":"yy"}]},"n":42}'
FW_R="$(rows "${M1}")" python3 - <<'PY' || fail "a nested/unknown shape was not measured"
import json, os, sys
rows = json.loads(os.environ["FW_R"])
if rows[-1]["bytes"] != 5:  # "xxx" + "yy"; keys and numbers are not payload
    print("nested leaves not summed: %r" % (rows[-1]["bytes"],), file=sys.stderr); sys.exit(1)
PY
pass "an unanticipated nested shape is still measured"

# --- per session, and outside the project ----------------------------------
feed s2 Read '{"file":{"content":"zz"}}'
[ "$(wc -l < "${M1}")" -eq 3 ] || fail "another session's call leaked into s1"
case "$(meter_for s2)" in "${WORK}"/*) : ;; *) fail "state is not under TMPDIR" ;; esac
[ -z "$(find "${SRC}" -name 'flywheel-reads-*' -print -quit)" ] \
  || fail "the meter wrote counter state inside the project"
pass "state is per session, under the temp dir, and never in the project"

# --- a write tool's response never entered context: counted, not charged ---
# Probed 2026-09-16: an Edit response carries `originalFile`, the WHOLE file
# before the edit, while what reaches context is a one-line confirmation.
# Charging it would let edit echoes dominate bytes_in and invert P40b.
feed s1 Edit '{"filePath":"/p/a.txt","oldString":"a","newString":"b","originalFile":"0123456789ABCDEFGHIJ"}'
FW_R="$(rows "${M1}")" python3 - <<'EDIT_CASE' || fail "a write tool was mis-metered"
import json, os, sys
r = json.loads(os.environ["FW_R"])[-1]
if r["tool"] != "Edit":
    print("the write call was not recorded at all: %r" % (r,), file=sys.stderr); sys.exit(1)
if r["bytes"] != 0:
    print("originalFile was charged to bytes_in: %r" % (r["bytes"],), file=sys.stderr); sys.exit(1)
EDIT_CASE
pass "a write tool is counted as a call and charged zero bytes"

# --- nothing measurable: silent, no line, exit 0 ---------------------------
BEFORE="$(wc -l < "${M1}")"
printf 'not json at all' | bash "${SCRIPT}" || fail "malformed input must exit 0"
feed s1 Read ''                        || fail "a missing tool_response must exit 0"
[ "$(wc -l < "${M1}")" -eq "${BEFORE}" ] || fail "an unmeasurable call left a line"
pass "unmeasurable input is silent, writes nothing, and never fails the call"

# --- a real call that returned nothing is still a call ---------------------
feed s1 Bash '{"stdout":"","stderr":""}'
FW_R="$(rows "${M1}")" python3 - <<'EMPTY_CASE' || fail "an empty response was dropped"
import json, os, sys
r = json.loads(os.environ["FW_R"])[-1]
if r["tool"] != "Bash" or r["bytes"] != 0:
    print("an empty-but-real response must count as a 0-byte call: %r" % (r,), file=sys.stderr)
    sys.exit(1)
EMPTY_CASE
pass "a call that returned nothing counts as a call, at zero bytes"

# --- --since totals only what came after -----------------------------------
CUT="$(FW_M="${M1}" python3 -c '
import json, os
rows=[json.loads(l) for l in open(os.environ["FW_M"], encoding="utf-8") if l.strip()]
print(rows[-1]["ts"])')"
OUT="$(CLAUDE_CODE_SESSION_ID=s1 bash "${SCRIPT}" --since "${CUT}")" || fail "--since failed"
case "${OUT}" in
  *bytes_in=*tool_calls=*) : ;;
  *) fail "--since printed neither field: ${OUT}" ;;
esac
pass "--since reports bytes_in and tool_calls"

ALL="$(CLAUDE_CODE_SESSION_ID=s1 bash "${SCRIPT}" --since 1970-01-01T00:00:00Z)"
case "${ALL}" in
  *"bytes_in=34"*) : ;;   # 22 + 7 + 5; the write and empty calls add 0
  *) fail "--since over everything did not total the rows: ${ALL}" ;;
esac
case "${ALL}" in
  *"tool_calls=5"*) : ;;  # every call counts, including the 0-byte ones
  *) fail "--since did not count every call: ${ALL}" ;;
esac
pass "--since totals the bytes and counts every call"

# --- elapsed_s comes from the cut, so line 1 of a cycle can carry it -------
# Every run in the repo omits elapsed_s on its FIRST line: a commit-time delta
# needs a previous commit and the first transition has none.
EL="$(CLAUDE_CODE_SESSION_ID=s1 bash "${SCRIPT}" --since 1970-01-01T00:00:00Z)"
case "${EL}" in
  *elapsed_s=*) : ;;
  *) fail "--since must report elapsed_s: ${EL}" ;;
esac
pass "--since reports elapsed_s alongside the other two"

FW_OUT="${EL}" python3 - <<'HUGE' || fail "elapsed_s must be the span from the cut to now"
import os, sys, time
v = int(dict(kv.split("=") for kv in os.environ["FW_OUT"].split())["elapsed_s"])
# The cut is the epoch, so elapsed_s must be the time since 1970 — proving it is
# measured from the cut and not from some fixed window.
if abs(v - int(time.time())) > 120:
    print("elapsed_s is not now-minus-cut: %r" % (v,), file=sys.stderr); sys.exit(1)
HUGE
pass "elapsed_s is now minus the cut, not a canned number"

FIRST="$(CLAUDE_CODE_SESSION_ID=s1 bash "${SCRIPT}" --since first)"
case "${FIRST}" in
  *elapsed_s=*bytes_in=*|*bytes_in=*elapsed_s=*) : ;;
  *) fail "--since first must report the same fields: ${FIRST}" ;;
esac
FW_A="${FIRST}" FW_B="${EL}" python3 - <<'FIRSTCUT' || fail "--since first did not resolve to the earliest row"
import os, sys
a = dict(kv.split("=") for kv in os.environ["FW_A"].split())
b = dict(kv.split("=") for kv in os.environ["FW_B"].split())
# Same rows as the epoch cut (every row is after the earliest one) ...
if a["bytes_in"] != b["bytes_in"] or a["tool_calls"] != b["tool_calls"]:
    print("first must cover every row: %r vs %r" % (a, b), file=sys.stderr); sys.exit(1)
# ... but a start of minutes, not decades.
if int(a["elapsed_s"]) > 3600:
    print("first must start at the earliest row, not the epoch: %r" % (a["elapsed_s"],),
          file=sys.stderr); sys.exit(1)
FIRSTCUT
pass "--since first starts at the earliest metered call, giving line 1 a start"

NOMETER="$(CLAUDE_CODE_SESSION_ID=never-metered bash "${SCRIPT}" --since first)"
case "${NOMETER}" in
  *elapsed_s=*) fail "no counter must not report an elapsed number: ${NOMETER}" ;;
  *UNMEASURED*) : ;;
  *) fail "no counter with --since first must say UNMEASURED: ${NOMETER}" ;;
esac
pass "--since first with no counter is UNMEASURED, not a zero-length run"

# --- a cut that is not a timestamp is caller error, not silence ------------
set +e
BAD="$(CLAUDE_CODE_SESSION_ID=s1 bash "${SCRIPT}" --since not-a-date 2>&1)"; BADRC=$?
set -e
[ "${BADRC}" -eq 2 ] || fail "a malformed cut must exit 2, got ${BADRC}: ${BAD}"
case "${BAD}" in
  *Traceback*) fail "a malformed cut must not throw: ${BAD}" ;;
  *bytes_in=*) fail "a malformed cut must not report numbers: ${BAD}" ;;
esac
case "${BAD}" in
  *timestamp*) : ;;
  *) fail "a malformed cut must say what is wrong: ${BAD}" ;;
esac
pass "a cut that is not a timestamp fails loudly, without a traceback or a number"

# --- an OBSERVED zero is not UNMEASURED ------------------------------------
ZERO="$(CLAUDE_CODE_SESSION_ID=s1 bash "${SCRIPT}" --since 2999-01-01T00:00:00Z)"
case "${ZERO}" in
  *"bytes_in=0"*) : ;;
  *) fail "a running meter with nothing since the cut must report 0: ${ZERO}" ;;
esac
pass "the meter ran and read nothing since the cut: an observed zero"

NONE="$(CLAUDE_CODE_SESSION_ID=never-metered bash "${SCRIPT}" --since 1970-01-01T00:00:00Z)"
case "${NONE}" in
  *bytes_in=*) fail "no meter file must NOT report a number: ${NONE}" ;;
esac
[ -n "${NONE}" ] || fail "no meter file must still say something, not print silence"
case "${NONE}" in
  *UNMEASURED*) : ;;
  *) fail "no meter file must name itself UNMEASURED: ${NONE}" ;;
esac
pass "no meter file reports UNMEASURED, never a zero that fabricates a win"

# --- the payload reaches the meter whatever its size -----------------------
# It used to reach python through an environment variable; a single env string
# is capped (128 KiB on Linux) and the exec fails WHOLE, so the largest tool
# responses — the ones that actually fill the context — were dropped in silence
# while the meter still called its total a floor. This harness's own `feed` has
# the same cap, which is why the big payload is built inside the helper.

feed_big() {  # sid bytes [budget]
  FW_SID="$1" FW_N="$2" python3 -c '
import json, os
print(json.dumps({"session_id": os.environ["FW_SID"], "tool_name": "Bash",
                  "hook_event_name": "PostToolUse",
                  "tool_response": {"stdout": "x" * int(os.environ["FW_N"])}}))' \
  | FLYWHEEL_CONTEXT_BUDGET_BYTES="${3-}" bash "${SCRIPT}"
}

feed_big s9 200000 >/dev/null
BIG="$(CLAUDE_CODE_SESSION_ID=s9 bash "${SCRIPT}" --since first)"
case "${BIG}" in
  *"bytes_in=200000"*) : ;;
  *) fail "a 200 KB response must be counted, not dropped for its size: ${BIG}" ;;
esac
pass "a tool response larger than the env-var cap is metered, not silently lost"

# --- the context budget: the meter says when the session should hand off ----
# The cost of one more tool call is the whole context re-read, so it grows with
# the session's own length. The meter already holds the running total; these
# assertions are what turns it from a post-hoc number into a live advisory.

QUIET="$(feed_big b1 100000 600000)"
[ -z "${QUIET}" ] || fail "under the budget the meter must stay silent: ${QUIET}"
pass "under the budget the meter says nothing"

WARN="$(feed_big b1 550000 600000)"
[ -n "${WARN}" ] || fail "crossing the budget must produce an advisory"
FW_W="${WARN}" python3 -c '
import json, os
h = json.loads(os.environ["FW_W"])["hookSpecificOutput"]
assert h["hookEventName"] == "PostToolUse", h
t = h["additionalContext"]
for word in ("handoff", "budget"):
    assert word in t.lower(), f"advisory must name {word}: {t}"
' || fail "the advisory is not a PostToolUse additionalContext envelope naming the handoff: ${WARN}"
pass "crossing the budget emits a handoff advisory"

AGAIN="$(feed_big b1 10000 600000)"
[ -z "${AGAIN}" ] || fail "the advisory must not repeat inside the same multiple: ${AGAIN}"
pass "the advisory fires once per threshold, not once per call"

SECOND="$(feed_big b1 600000 600000)"
[ -n "${SECOND}" ] || fail "crossing twice the budget must advise again"
pass "a session that keeps going is told again at the next multiple"

OFF="$(feed_big b2 900000 0)"
[ -z "${OFF}" ] || fail "budget 0 must disable the advisory: ${OFF}"
pass "FLYWHEEL_CONTEXT_BUDGET_BYTES=0 disables the advisory"

# The advisory is not a measurement: it must not add a call or a byte to what
# the transition line reports, or the meter would be inflating its own numbers.
COUNT="$(CLAUDE_CODE_SESSION_ID=b1 bash "${SCRIPT}" --since first)"
case "${COUNT}" in
  *"tool_calls=4"*) : ;;
  *) fail "four calls were fed; the advisory must not count as a fifth: ${COUNT}" ;;
esac
case "${COUNT}" in
  *"bytes_in=1260000"*) : ;;
  *) fail "the advisory must not add bytes to the total: ${COUNT}" ;;
esac
pass "advising does not inflate what the meter reports"

echo "read-meter: all assertions passed"
