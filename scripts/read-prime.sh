#!/usr/bin/env bash
# flywheel — PreToolUse hook on Read (P3): advisory read-priming.
#
# Before an expensive file read, surface any ledger entries whose typed
# `files=` metadata (see docs/research/git-native-memory-design.md §6) names
# the target file, as cheap prior context.
#
# Contract: ADVISORY ONLY — never blocks the read (unlike claude-mem's File
# Read Gate). Fast and fail-open: no ledger, no match, not a git repo, missing
# python3, or any parse error all produce no output and exit 0.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LEDGER="${PROJECT_DIR}/.claude/flywheel/LEARNINGS.md"

# Drain stdin (the PreToolUse hook input is JSON: {"tool_input": {"file_path": …}, …}).
INPUT="$(cat 2>/dev/null)"

[ -f "${LEDGER}" ] || exit 0

# Cheap pre-filter: this hook fires on EVERY Read and ~all of them have no
# matching ledger entry — skip the python spawn for that majority. The sed
# extraction is naive on purpose (exact parsing stays in python): if it yields
# a basename the ledger never mentions, nothing can match; if it yields
# nothing, fall through to python (correctness over speed, never the reverse).
TARGET_PATH="$(printf '%s' "${INPUT}" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' 2>/dev/null | head -1 2>/dev/null)"
case "${TARGET_PATH}" in *\\*) TARGET_PATH="" ;; esac  # escaped quotes → sed garbage; let python decide
if [ -n "${TARGET_PATH}" ]; then
  BASE="${TARGET_PATH##*/}"
  if [ -n "${BASE}" ] && ! grep -qF -- "${BASE}" "${LEDGER}" 2>/dev/null; then
    exit 0
  fi
fi

command -v python3 >/dev/null 2>&1 || exit 0

FW_LEDGER="${LEDGER}" FW_PROJECT_DIR="${PROJECT_DIR}" FW_HOOK_INPUT="${INPUT}" python3 - <<'PY' 2>/dev/null
import json, os, re, sys

ledger_path = os.environ["FW_LEDGER"]
project_dir = os.environ["FW_PROJECT_DIR"]

try:
    payload = json.loads(os.environ.get("FW_HOOK_INPUT", "") or "{}")
    target = payload.get("tool_input", {}).get("file_path", "")
except Exception:
    target = ""

if not target:
    sys.exit(0)

# Match the ledger's `files=` entries (repo-relative) against the absolute or
# relative path the tool was called with.
target_abs = os.path.normpath(os.path.join(project_dir, target) if not os.path.isabs(target) else target)
try:
    target_rel = os.path.relpath(target_abs, project_dir)
except ValueError:
    target_rel = target

candidates = {target, target_abs, target_rel, os.path.basename(target)}

with open(ledger_path, encoding="utf-8", errors="replace") as fh:
    text = fh.read()

parts = re.split(r"(?m)^(?=## )", text)
entries = [p for p in parts if p.lstrip().startswith("## ")]
meta_re = re.compile(r"^<!--\s*fw:\s*(.*?)\s*-->", re.M)
title_re = re.compile(r"^## (.*)$", re.M)

matches = []
for entry in entries:
    m = meta_re.search(entry)
    if not m:
        continue
    kv = {}
    for pair in m.group(1).split(";"):
        pair = pair.strip()
        if "=" in pair:
            k, v = pair.split("=", 1)
            kv[k.strip()] = v.strip()
    files = {f.strip() for f in kv.get("files", "").split(",") if f.strip()}
    if files & candidates:
        title_m = title_re.search(entry)
        title = title_m.group(1).strip() if title_m else "untitled"
        date = kv.get("date", "")
        matches.append(f"- {title}" + (f" ({date})" if date else ""))

# PreToolUse stdout on exit 0 is only shown in transcript mode — to actually
# reach the model, the note must go through the hook JSON contract's
# additionalContext field (json.dumps handles all escaping).
if matches:
    n = len(matches)
    noun = "learning" if n == 1 else "learnings"
    verb = "touches" if n == 1 else "touch"
    # Stated as fact, not as an instruction — imperative phrasing can trip the
    # model's prompt-injection defenses and surface instead of priming.
    lines = [f"flywheel: {n} prior {noun} {verb} this file; /flywheel:recall lists the full entries:"]
    lines.extend(matches)
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "additionalContext": "\n".join(lines),
        }
    }))
PY

exit 0
