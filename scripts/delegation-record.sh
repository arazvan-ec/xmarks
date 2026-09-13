#!/usr/bin/env bash
# flywheel — PostToolUse hook: record the child that WAS created.
#
# The writing half of `delegation-guard.sh`. It sits on PostToolUse and not on
# PreToolUse deliberately: in Pre the child may still never exist — the user
# denies, the call fails — and a counter of intentions would accuse a child that
# never happened of being a duplicate. The counter has to count facts.
#
# State lives in the system temp dir, keyed by parent session. NOT under the
# project: a counter there would dirty `git status` and end up committed. It is
# ephemeral by design — losing it only means the guard stops warning, never that
# it blocks.

INPUT="$(cat 2>/dev/null)"

case "${INPUT}" in
  *create_session*|*'"Agent"'*|*'"Task"'*) : ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0

FW_HOOK_INPUT="${INPUT}" python3 - <<'PY' 2>/dev/null
import hashlib, json, os, re, sys, tempfile, time

try:
    payload = json.loads(os.environ.get("FW_HOOK_INPUT", "") or "{}")
except Exception:
    sys.exit(0)

tool = payload.get("tool_name") or ""
if not (tool.endswith("create_session") or tool in ("Agent", "Task")):
    sys.exit(0)

tool_input = payload.get("tool_input") or {}
if not isinstance(tool_input, dict):
    sys.exit(0)

# Same derivation as `delegation-guard.sh`.
parent = str(payload.get("session_id") or "no-session")
path = os.path.join(
    tempfile.gettempdir(),
    "flywheel-delegation-" + hashlib.sha256(parent.encode("utf-8")).hexdigest()[:16] + ".jsonl",
)

prompt = str(tool_input.get("prompt") or "")
row = {
    "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "tool": tool,
    "model": (tool_input.get("model") or "") or None,
    "anchors": sorted(set(re.findall(r"#(\d+)", prompt)), key=int),
    "title": str(tool_input.get("title") or tool_input.get("description") or "")[:120],
}

try:
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(row, ensure_ascii=False) + "\n")
except Exception:
    pass
PY

exit 0
