#!/usr/bin/env bash
# flywheel — compound-due Stop hook (P69). A run this branch shipped must say
# what it learned: a `phase: compound` line, even one recording 0 entries.
# 14 of 16 shipped runs had none, and nothing noticed.
#
# Due: a `.claude/flywheel/runs/<slug>/*.jsonl` this branch touches (vs every
# other branch, or uncommitted) with a `phase: ship` line and no `phase:
# compound` line. Due → exit 2 naming the slugs and both fixes.
# Fail-open: anything it cannot read is a no-op; stop_hook_active never re-traps.

set -uo pipefail
INPUT="$(cat 2>/dev/null || true)"
command -v python3 >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

FW_IN="${INPUT}" python3 - <<'PY'
import glob, json, os, subprocess, sys

try:
    data = json.loads(os.environ.get("FW_IN") or "{}")
    if not isinstance(data, dict):
        sys.exit(0)
except ValueError:
    sys.exit(0)
if data.get("stop_hook_active"):
    sys.exit(0)

root = os.environ.get("CLAUDE_PROJECT_DIR") or data.get("cwd") or os.getcwd()


def git(*a):
    p = subprocess.run(["git", "-C", root, *a], capture_output=True, text=True)
    return p.stdout if p.returncode == 0 else None


if git("rev-parse", "--git-dir") is None:
    sys.exit(0)

RUNS = ".claude/flywheel/runs/"
cur = (git("rev-parse", "--abbrev-ref", "HEAD") or "").strip()
touched = set()
# With no ref besides this branch and its upstream, `--not` has nothing to
# subtract and every commit in history would read as this branch's work.
def other(ref):
    if ref.startswith("refs/heads/"):
        return ref[len("refs/heads/"):] != cur
    return ref.split("/", 3)[-1] not in (cur, "HEAD")


others = [r for r in (git("for-each-ref", "--format=%(refname)",
                          "refs/heads", "refs/remotes") or "").split() if other(r)]
if cur and cur != "HEAD" and others:
    out = git("log", "--format=", "--name-only", "HEAD", "--not",
              f"--exclude={cur}", "--branches", f"--exclude=*/{cur}", "--remotes",
              "--", RUNS)
    touched |= set((out or "").split())
for l in (git("status", "--porcelain", "--untracked-files=all", "--", RUNS) or "").splitlines():
    touched.add(l[3:].strip())

slugs = sorted({p.split("/")[3] for p in touched if p.startswith(RUNS) and p.count("/") >= 4})
due = []
for slug in slugs:
    phases = set()
    for f in glob.glob(os.path.join(root, RUNS, slug, "*.jsonl")):
        try:
            lines = open(f, encoding="utf-8").read().splitlines()
        except OSError:
            continue
        for raw in lines:
            try:
                rec = json.loads(raw)
            except ValueError:
                continue
            if isinstance(rec, dict):
                phases.add(rec.get("phase"))
    if "ship" in phases and "compound" not in phases:
        due.append(slug)

if not due:
    sys.exit(0)
sys.stderr.write(
    f"flywheel compound-due (P69): shipped without a compound outcome — {', '.join(due)}."
    " Run /flywheel:compound (it appends a `phase: compound` line), or, if this cycle"
    " proved nothing durable, append to runs/<slug>/<date>.jsonl:"
    ' {"phase": "compound", "task": "compound", "state": "completed", "entries": 0,'
    ' "reason": "<why nothing>"}\n')
sys.exit(2)
PY
