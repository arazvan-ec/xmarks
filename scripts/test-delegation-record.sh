#!/usr/bin/env bash
# flywheel — test for the delegated-work PostToolUse recorder.
# Asserts it appends one JSON line per created child, keyed by parent session,
# with the anchors the guard reads back; that it writes outside the project; and
# that an unrelated tool, malformed input or an unwritable state path leave no
# trace and exit 0. The recorder must never fail a tool call.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${SRC}/scripts/delegation-record.sh"
WORK="$(mktemp -d)"
export TMPDIR="${WORK}"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

ledger_for() {
  FW_SID="$1" FW_TMP="${WORK}" python3 -c '
import hashlib, os
sid = os.environ["FW_SID"]
print(os.path.join(os.environ["FW_TMP"],
      "flywheel-delegation-" + hashlib.sha256(sid.encode()).hexdigest()[:16] + ".jsonl"))'
}

record() {
  FW_SID="$1" FW_TOOL="$2" FW_EXTRA="$3" python3 -c '
import json, os
print(json.dumps({"session_id": os.environ["FW_SID"],
                  "tool_name": os.environ["FW_TOOL"],
                  "tool_input": json.loads(os.environ["FW_EXTRA"])}))' | bash "${SCRIPT}"
}

# --- one line per created child -------------------------------------------
record s1 mcp__Claude_Code_Remote__create_session \
  '{"model":"sonnet","title":"Job 1","prompt":"Job 1, issue #28 and #99."}'
LEDGER="$(ledger_for s1)"
[ -f "${LEDGER}" ] || fail "no ledger written at ${LEDGER}"
pass "a created child writes a ledger line"

FW_LEDGER="${LEDGER}" python3 - <<'PY' || fail "the ledger row is malformed"
import json, os, sys
rows = [json.loads(l) for l in open(os.environ["FW_LEDGER"], encoding="utf-8") if l.strip()]
if len(rows) != 1:
    print("expected 1 row, got %d" % len(rows), file=sys.stderr); sys.exit(1)
r = rows[0]
if r["anchors"] != ["28", "99"]:
    print("anchors not captured in order: %r" % (r["anchors"],), file=sys.stderr); sys.exit(1)
if r["model"] != "sonnet" or r["title"] != "Job 1":
    print("model/title not captured: %r" % (r,), file=sys.stderr); sys.exit(1)
if not r.get("ts"):
    print("no timestamp", file=sys.stderr); sys.exit(1)
PY
pass "the row carries anchors in order, model, title and a timestamp"

# --- it appends, and it is per parent --------------------------------------
record s1 mcp__Claude_Code_Remote__create_session '{"model":"opus","prompt":"Job 2, issue #29."}'
[ "$(wc -l < "${LEDGER}")" -eq 2 ] || fail "the second child did not append"
pass "a second child appends rather than replacing"

record s2 mcp__Claude_Code_Remote__create_session '{"model":"sonnet","prompt":"Other, issue #28."}'
[ "$(wc -l < "${LEDGER}")" -eq 2 ] || fail "another parent wrote into this ledger"
[ -f "$(ledger_for s2)" ] || fail "the other parent has no ledger of its own"
pass "each parent session keeps its own ledger"

# --- subagents are recorded too --------------------------------------------
record s3 Agent '{"description":"review","prompt":"check issue #41"}'
[ -f "$(ledger_for s3)" ] || fail "a subagent was not recorded"
pass "a subagent is recorded like a session"

# --- it writes outside the project -----------------------------------------
case "${LEDGER}" in "${WORK}"/*) pass "the ledger lives in the temp dir, not the project" ;;
  *) fail "the ledger escaped the temp dir: ${LEDGER}" ;; esac

# --- fail-open --------------------------------------------------------------
before="$(ls -1 "${WORK}" | wc -l)"
record s9 Bash '{"command":"ls"}'
[ "$(ls -1 "${WORK}" | wc -l)" -eq "${before}" ] || fail "an unrelated tool was recorded"
pass "an unrelated tool leaves no trace"

printf 'create_session {not json' | bash "${SCRIPT}" || fail "malformed input must exit 0"
printf '' | bash "${SCRIPT}" || fail "empty input must exit 0"
[ "$(ls -1 "${WORK}" | wc -l)" -eq "${before}" ] || fail "malformed input wrote a ledger"
pass "malformed and empty input fail open, writing nothing"

# An unwritable state dir must not fail the tool call.
BAD="${WORK}/readonly"; mkdir -p "${BAD}"; chmod 500 "${BAD}"
TMPDIR="${BAD}" record s10 mcp__Claude_Code_Remote__create_session '{"prompt":"issue #1"}' \
  || fail "an unwritable state path must still exit 0"
chmod 700 "${BAD}"
pass "an unwritable state path still exits 0"

echo "delegation-record: all assertions passed"
