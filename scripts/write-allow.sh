#!/usr/bin/env bash
# flywheel — PreToolUse hook on Write/Edit (P19): pre-approve state writes.
#
# The loop's real approval gates are conversational — the spec sign-off and the
# plan approval. Once those pass, persisting flywheel's OWN state (specs,
# plans, LEARNINGS.md, process contracts, DATA.md, run reports) is implied by
# that approval — yet the harness's tool-permission layer knows nothing about
# it and prompts for every Write/Edit again. This hook closes that gap: writes
# whose target resolves inside <project>/.claude/flywheel/ are auto-allowed;
# everything else falls through untouched to the normal permission flow.
#
# Contract: ALLOW-ONLY and fail-open — the hook never denies, never asks, and
# never blocks a write. Any parse error, missing python3, or out-of-scope path
# produces no output and exit 0 (i.e. the default permission prompt). Scope is
# strictly the flywheel state dir: symlinks are resolved (a link inside
# .claude/flywheel/ pointing elsewhere gets NO grant) and `..` traversal is
# normalized away before the containment check.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Drain stdin (the PreToolUse hook input is JSON: {"tool_input": {"file_path": …}, …}).
INPUT="$(cat 2>/dev/null)"

# Cheap pre-filter: this hook fires on EVERY Write/Edit and most targets are
# ordinary project files — skip the python spawn for that majority. Any path
# inside the state dir literally contains ".claude/flywheel" (a symlinked
# alias that doesn't would merely miss the grant and fall back to a normal
# prompt — safe). If the sed extraction yields nothing usable, fall through to
# python (correctness over speed, never the reverse).
TARGET_PATH="$(printf '%s' "${INPUT}" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' 2>/dev/null | head -1 2>/dev/null)"
if [ -z "${TARGET_PATH}" ]; then
  TARGET_PATH="$(printf '%s' "${INPUT}" | sed -n 's/.*"notebook_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' 2>/dev/null | head -1 2>/dev/null)"
fi
case "${TARGET_PATH}" in *\\*) TARGET_PATH="" ;; esac  # escaped quotes → sed garbage; let python decide
if [ -n "${TARGET_PATH}" ]; then
  case "${TARGET_PATH}" in
    *.claude/flywheel*) : ;;  # candidate — python does the strict check
    *) exit 0 ;;
  esac
fi

command -v python3 >/dev/null 2>&1 || exit 0

FW_PROJECT_DIR="${PROJECT_DIR}" FW_HOOK_INPUT="${INPUT}" python3 - <<'PY' 2>/dev/null
import json, os, sys

try:
    payload = json.loads(os.environ.get("FW_HOOK_INPUT", "") or "{}")
    tool_input = payload.get("tool_input", {})
    target = tool_input.get("file_path") or tool_input.get("notebook_path") or ""
except Exception:
    target = ""

if not target:
    sys.exit(0)

project_dir = os.path.realpath(os.environ["FW_PROJECT_DIR"])
state_root = os.path.join(project_dir, ".claude", "flywheel")

target_abs = target if os.path.isabs(target) else os.path.join(project_dir, target)
# realpath resolves symlinks in every existing component and normalizes the
# rest lexically — so both a `..` escape and a symlink planted inside the
# state dir pointing outside it resolve OUT of scope and get no grant.
resolved = os.path.realpath(target_abs)

if resolved == state_root or resolved.startswith(state_root + os.sep):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "permissionDecisionReason": (
                "flywheel state write (.claude/flywheel/**) — persisting loop "
                "state is covered by the spec/plan approval gates"
            ),
        }
    }))
PY

exit 0
