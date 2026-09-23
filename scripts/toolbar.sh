#!/usr/bin/env bash
# flywheel — progress toolbar hook (P56). The toolbar rule is enforced by the
# harness, not remembered by the model.
#
#   toolbar.sh remind   UserPromptSubmit: with an open list, inject the format
#                       and the live count as additionalContext.
#   toolbar.sh stop     Stop: with an open list, a final reply whose first
#                       non-empty line is not `<🟢|⏸️|🔴|🏁> <n>/<N> …` blocks
#                       (exit 2). Mid-turn notes are exempt by construction:
#                       Stop sees only the turn's final message.
#
# An open list is a `.claude/flywheel/specs/<slug>.plan.md` this branch touches
# (vs its base, or uncommitted) with a task no `runs/<slug>/*.jsonl` line covers.
# Fail-open: anything it cannot read is a no-op, and stop_hook_active never
# re-traps.

set -uo pipefail
MODE="${1:-}"
INPUT="$(cat 2>/dev/null || true)"
command -v python3 >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FW_MODE="${MODE}" FW_IN="${INPUT}" FW_HERE="${HERE}" python3 - <<'PY'
import glob, json, os, re, subprocess, sys

mode, here = os.environ["FW_MODE"], os.environ["FW_HERE"]
try:
    data = json.loads(os.environ.get("FW_IN") or "{}")
    if not isinstance(data, dict):
        sys.exit(0)
except ValueError:
    sys.exit(0)
if mode == "stop" and data.get("stop_hook_active"):
    sys.exit(0)

root = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()
sys.path.insert(0, here)
try:
    from fw_tasks import task_ids
except Exception:
    sys.exit(0)


def git(*a):
    p = subprocess.run(["git", "-C", root, *a], capture_output=True, text=True)
    return p.stdout if p.returncode == 0 else None


if git("rev-parse", "--git-dir") is None:
    sys.exit(0)

SPECS = ".claude/flywheel/specs/"
touched = set()
for ref in ("origin/HEAD", "origin/main", "origin/master", "main", "master"):
    if git("rev-parse", "--verify", "-q", ref) is None:
        continue
    base = (git("merge-base", "HEAD", ref) or "").strip()
    if base:
        touched |= set((git("diff", "--name-only", base, "HEAD", "--", SPECS) or "").split())
    break
for line in (git("status", "--porcelain", "--untracked-files=all", "--", SPECS) or "").splitlines():
    touched.add(line[3:].strip())

TASK_RE = re.compile(r"^###\s+(T\d+)\b", re.M)
open_lists = []
for rel in sorted(touched):
    if not rel.endswith(".plan.md"):
        continue
    path = os.path.join(root, rel)
    if not os.path.isfile(path):
        continue
    ids = list(dict.fromkeys(TASK_RE.findall(open(path, encoding="utf-8").read())))
    if not ids:
        continue
    slug = os.path.basename(rel)[: -len(".plan.md")]
    covered = set()
    for f in glob.glob(os.path.join(root, ".claude/flywheel/runs", slug, "*.jsonl")):
        for raw in open(f, encoding="utf-8"):
            try:
                rec = json.loads(raw)
            except ValueError:
                continue
            if isinstance(rec, dict):
                covered |= task_ids(rec.get("task"))
    left = [i for i in ids if i not in covered]
    if left:
        open_lists.append((slug, len(ids) - len(left), len(ids), left))

if not open_lists:
    sys.exit(0)

FORMAT = ("<state> <done>/<total> <bar> · ▶ <current item> · «<what you are doing, in the"
          " owner's words>» — state 🟢 advanced · ⏸️ no advance (say why) · 🔴 blocked ·"
          " 🏁 all resolved; bar one glyph per item ▓ closed ▒ in flight ░ untouched")
lists = "; ".join(f"{s} {d}/{n} (open: {', '.join(l)})" for s, d, n, l in open_lists)

if mode == "remind":
    ctx = (f"flywheel toolbar (P56): open list — {lists}. Start the FINAL reply of this"
           f" turn with one line: {FORMAT}. Mid-turn notes between tool calls are exempt.")
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit",
                                             "additionalContext": ctx}}, ensure_ascii=False))
    sys.exit(0)
if mode != "stop":
    sys.exit(0)

msg = data.get("last_assistant_message")
if not isinstance(msg, str):
    msg = None
    tp = data.get("transcript_path")
    if isinstance(tp, str) and os.path.isfile(tp):
        for raw in open(tp, encoding="utf-8"):
            try:
                rec = json.loads(raw)
            except ValueError:
                continue
            if not isinstance(rec, dict) or rec.get("type") != "assistant":
                continue
            content = (rec.get("message") or {}).get("content")
            texts = [c.get("text", "") for c in content if isinstance(c, dict)
                     and c.get("type") == "text"] if isinstance(content, list) else []
            if any(t.strip() for t in texts):
                msg = "\n".join(texts)
if msg is None:
    sys.exit(0)

first = next((l.strip() for l in msg.splitlines() if l.strip()), "")
m = re.match(r"^(?:🟢|⏸️|⏸|🔴|🏁)\s*(\d+)/(\d+)", first)
if m and int(m.group(2)) in {n for _, _, n, _ in open_lists}:
    sys.exit(0)
why = ("its total is not any open list's" if m else "it does not start with the toolbar")
sys.stderr.write(f"flywheel toolbar (P56): this reply cannot end the turn — {why}. Open list:"
                 f" {lists}. Re-send the final reply opening with: {FORMAT}\n")
sys.exit(2)
PY
