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
# and never content re-entering context. elapsed_s is `now - cut`, so it is the
# transition's true wall clock only when the line is written AT the transition —
# which is what the duty requires anyway. `--since first` cuts at the earliest
# recorded call, the only start a cycle's FIRST transition can observe: a commit
# delta needs a previous commit it does not have.
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

since, total, calls = os.environ["FW_SINCE"], 0, 0
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
    if str(row.get("ts") or "") >= since:
        total += int(row.get("bytes") or 0)
        calls += 1

try:
    cut = calendar.timegm(time.strptime(since, "%Y-%m-%dT%H:%M:%SZ"))
except ValueError:
    # Caller error, not missing data: reporting UNMEASURED here would hide a
    # broken call behind a word that means "nothing was recorded".
    print(f"read-meter: --since needs an ISO timestamp like 2026-09-16T18:00:00Z"
          f" or the word 'first', not {since!r}", file=sys.stderr)
    sys.exit(2)
elapsed = max(0, int(time.time()) - cut)

print(f"bytes_in={total} tool_calls={calls} elapsed_s={elapsed}")
print(f"# floor: tool responses since {since}, from {path}", file=sys.stderr)
PY
  exit $?   # the reader's exit code is python's; a bad cut must not look like success
fi

# Via a FILE, never an env var: a single env string is capped (128 KiB on
# Linux) and the exec fails whole, so every tool response past the cap was
# dropped in silence — the largest reads, which are the ones that matter.
command -v python3 >/dev/null 2>&1 || exit 0
INPUT_FILE="$(mktemp "${TMPDIR:-/tmp}/flywheel-meter-in.XXXXXX" 2>/dev/null)" || exit 0
trap 'rm -f "${INPUT_FILE}"' EXIT
cat > "${INPUT_FILE}" 2>/dev/null

FW_HOOK_INPUT_FILE="${INPUT_FILE}" python3 - <<'PY' 2>/dev/null
import hashlib, json, os, sys, tempfile, time

try:
    with open(os.environ["FW_HOOK_INPUT_FILE"], encoding="utf-8") as fh:
        payload = json.load(fh)
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

# The budget. One more tool call costs the whole accumulated context re-read,
# so a session's bill grows with the square of its own length: past a point the
# cheapest thing it can do is END, and no amount of reading less will match it.
# The advisory is a READ of the total already recorded above, never a second
# measurement — it must not add a call or a byte to what `--since` reports.
raw = (os.environ.get("FLYWHEEL_CONTEXT_BUDGET_BYTES") or "").strip()
try:
    budget = int(raw) if raw else 600000
except ValueError:
    budget = 600000          # a typo must not silently disarm the guard
if budget <= 0:
    sys.exit(0)

total = 0
try:
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                total += int(json.loads(line).get("bytes") or 0)
            except Exception:
                continue
except Exception:
    sys.exit(0)

crossed = total // budget
if crossed < 1:
    sys.exit(0)

# Fires once per multiple: once is an advisory, every call is noise that costs
# the very context it is warning about. The mark is a sidecar, not a meter row.
mark = (path[: -len(".jsonl")] if path.endswith(".jsonl") else path) + ".warned"
try:
    with open(mark, encoding="utf-8") as fh:
        warned = int((fh.read() or "0").strip() or 0)
except Exception:
    warned = 0
if crossed <= warned:
    sys.exit(0)
try:
    with open(mark, "w", encoding="utf-8") as fh:
        fh.write(str(crossed))
except Exception:
    sys.exit(0)   # cannot remember it fired, so stay silent rather than repeat

def human(n):
    return "%.1f MB" % (n / 1000000.0) if n >= 1000000 else "%d KB" % (n // 1000)

print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": (
        "flywheel context budget: this session has pulled %s of tool output into context "
        "(%s budget, crossed %dx). Every further tool call re-reads all of it, so the cost "
        "grows with the length of the session rather than with the work. Finish the step you "
        "are on, then write the handoff \u2014 what is done, what is next, the first file the "
        "next session should read \u2014 commit and push it, and end the session. Continuing "
        "here is the expensive choice, not the thorough one."
    ) % (human(total), human(budget), crossed)}}, ensure_ascii=False))
PY

exit 0
