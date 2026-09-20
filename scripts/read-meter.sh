#!/usr/bin/env bash
# flywheel — the read meter (P44). Two halves of one measurement.
#
# As a PostToolUse hook it records what a tool call brought back into context;
# with --since it totals that record for a transition line's cost object. They
# live in one script because they must derive the same path from the same
# session id, and a split would let the two drift silently.
#
# It measures `tool_response`, not `tool_input`: the ask is cheap, the answer is
# what costs. Every string leaf counts, with no per-tool extractor — the shape
# differs per tool (Bash returns stdout/stderr, Read a nested file object) and a
# tool that does not exist yet must still be counted, not silently skipped. The
# one exception is a write tool, whose response echoes the file it changed
# without that text ever reaching context; the call counts, the bytes do not.
#
# bytes_in stays a FLOOR (P23/P40a): tool responses only, never the conversation
# and never content re-entering context. `max_read` and `by_tool` (P50) come out
# of the same rows: the state file has always carried `tool` and `bytes` per
# call, and --since used to collapse both into one number — which is why P40b's
# threshold question could only be bounded to an 18x interval and never answered.
#
# elapsed_s is `now - cut`, so it is the transition's true wall clock only when
# the line is written AT the transition — which is what the duty requires anyway.
# `--since first` cuts at the earliest recorded call, the only start a cycle's
# FIRST transition can observe: a commit delta needs a previous commit it does
# not have.
#
# THE TWO CUTS DIFFER, AND THEY HAVE TO (P53, found in review). A caller-supplied
# timestamp is the PREVIOUS transition's, and that transition already counted
# every call bearing it; rows are second-granular, so an inclusive cut hands them
# to the next transition as well. For bytes_in that is a small double-count; for
# max_read it is a maximum this transition never made. So an explicit --since is
# EXCLUSIVE. `first` stays inclusive: it names a row rather than a boundary, and
# excluding it would drop the one call a cycle's first transition exists to
# measure.
#
# State is keyed by session under the system temp dir, the delegation-record.sh
# derivation verbatim: in the project it would dirty `git status` and be committed.

set -u

if [ "${1:-}" = "--since" ]; then
  SINCE="${2:-}"
  [ -n "${SINCE}" ] || { echo "read-meter: --since needs a timestamp" >&2; exit 2; }
  command -v python3 >/dev/null 2>&1 || { echo "read-meter: UNMEASURED — no python3" >&2; exit 0; }
  FW_SINCE="${SINCE}" FW_SID="${CLAUDE_CODE_SESSION_ID:-}" python3 - <<'PY'
import calendar, hashlib, json, os, sys, tempfile, time

sid = os.environ.get("FW_SID") or ""
if not sid:
    print("read-meter: UNMEASURED — no CLAUDE_CODE_SESSION_ID; leave both fields out")
    sys.exit(0)

path = os.path.join(tempfile.gettempdir(),
                    "flywheel-reads-" + hashlib.sha256(sid.encode()).hexdigest()[:16] + ".jsonl")
if not os.path.exists(path):
    # Absent is not zero. No meter ran, so the fields are UNMEASURED and must be
    # omitted — printing 0 here is the exact fabrication P40a exists to stop.
    print("read-meter: UNMEASURED — no counter for this session; omit both fields")
    sys.exit(0)

since, total, calls, mx, by = os.environ["FW_SINCE"], 0, 0, 0, {}
from_first = since == "first"
try:
    rows = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except Exception:
                continue
except Exception:
    print("read-meter: UNMEASURED — the counter could not be read; omit the fields")
    sys.exit(0)

stamps = sorted(str(r.get("ts") or "") for r in rows if r.get("ts"))
if since == "first":
    if not stamps:
        print("read-meter: UNMEASURED — the counter holds no timestamped call; omit the fields")
        sys.exit(0)
    since = stamps[0]

for row in rows:
    ts = str(row.get("ts") or "")
    if (ts >= since) if from_first else (ts > since):
        n = int(row.get("bytes") or 0)
        total += n
        calls += 1
        mx = max(mx, n)
        # A write tool sits here with 0 bytes and a real call count, as P44
        # defined it: the call happened, its bytes never entered context.
        tool = str(row.get("tool") or "?")
        b, c = by.get(tool, (0, 0))
        by[tool] = (b + n, c + 1)

try:
    cut = calendar.timegm(time.strptime(since, "%Y-%m-%dT%H:%M:%SZ"))
except ValueError:
    # Caller error, not missing data: reporting UNMEASURED here would hide a
    # broken call behind a word that means "nothing was recorded".
    print(f"read-meter: --since needs an ISO timestamp like 2026-09-16T18:00:00Z"
          f" or the word 'first', not {since!r}", file=sys.stderr)
    sys.exit(2)
elapsed = max(0, int(time.time()) - cut)

# by_tool is written on one line, biggest first: the shape a transition line
# copies verbatim, and the order a reader needs first.
attrib = ",".join(f"{t}:{b}/{c}" for t, (b, c) in
                  sorted(by.items(), key=lambda kv: (-kv[1][0], kv[0])))
print(f"bytes_in={total} tool_calls={calls} elapsed_s={elapsed} max_read={mx}"
      + (f" by_tool={attrib}" if attrib else ""))
print(f"# floor: tool responses since {since}, from {path}", file=sys.stderr)
PY
  exit $?   # the reader's exit code is python's; a bad cut must not look like success
fi

INPUT="$(cat 2>/dev/null)"
command -v python3 >/dev/null 2>&1 || exit 0

FW_HOOK_INPUT="${INPUT}" python3 - <<'PY' 2>/dev/null
import hashlib, json, os, sys, tempfile, time

try:
    payload = json.loads(os.environ.get("FW_HOOK_INPUT", "") or "{}")
except Exception:
    sys.exit(0)

resp = payload.get("tool_response")
if resp is None:
    sys.exit(0)

# A write tool's response carries the file it just changed (Edit returns the
# whole `originalFile`) while what reaches context is a one-line confirmation.
# The call is real and counts; those bytes never entered context and must not.
WRITE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}

def leaves(node):
    if isinstance(node, str):
        return len(node.encode("utf-8"))
    if isinstance(node, dict):
        return sum(leaves(v) for v in node.values())
    if isinstance(node, list):
        return sum(leaves(v) for v in node)
    return 0

tool = str(payload.get("tool_name") or "")
n = 0 if tool in WRITE_TOOLS else leaves(resp)

sid = str(payload.get("session_id") or "no-session")
path = os.path.join(tempfile.gettempdir(),
                    "flywheel-reads-" + hashlib.sha256(sid.encode()).hexdigest()[:16] + ".jsonl")
row = {
    "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "tool": tool,
    "bytes": n,
}
try:
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, ensure_ascii=False) + "\n")
except Exception:
    pass
PY

exit 0
