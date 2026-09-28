#!/usr/bin/env bash
# flywheel — upstream-issue (P70): render one ledger entry about flywheel itself
# as a prefilled flywheel-feedback issue URL on the plugin's repo. It never
# submits: the human reads the form and presses the button, which is the consent
# for a private repo's prose to reach a public one.
#
#   upstream-issue.sh [title-substring]   newest entry when none is given
#
# stdout: the URL. Exit 0 · 1 no ledger or no match · 3 this is flywheel's own
# repo (the entry is already upstream). FW_UPSTREAM overrides the repo URL.

set -uo pipefail
command -v python3 >/dev/null 2>&1 || { echo "upstream-issue: python3 required" >&2; exit 1; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FW_HERE="${HERE}" FW_MATCH="${1:-}" python3 - <<'PY'
import json, os, re, sys, urllib.parse

here = os.environ["FW_HERE"]
root = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()

try:
    if json.load(open(os.path.join(root, ".claude-plugin/plugin.json"))).get("name") == "flywheel":
        sys.stderr.write("upstream-issue: this is flywheel's own repo — the entry is already upstream\n")
        sys.exit(3)
except (OSError, ValueError, AttributeError):
    pass

ledger = os.path.join(root, ".claude/flywheel/LEARNINGS.md")
try:
    text = open(ledger, encoding="utf-8").read()
except OSError:
    sys.stderr.write(f"upstream-issue: no ledger at {ledger}\n")
    sys.exit(1)

entries = re.split(r"(?m)^(?=## )", text)[1:]
match = os.environ.get("FW_MATCH", "").lower()
entry = next((e for e in entries if match in e.splitlines()[0].lower()), None)
if entry is None:
    sys.stderr.write(f"upstream-issue: no entry whose title contains {match!r}\n")
    sys.exit(1)

lines = entry.splitlines()
title = lines[0][3:].strip()
meta = {}
m = re.search(r"<!--\s*fw:(.*?)-->", entry)
if m:
    for pair in m.group(1).split(";"):
        k, _, v = pair.strip().partition("=")
        if k:
            meta[k] = v.strip()
prose = re.sub(r"<!--.*?-->", "", "\n".join(lines[1:]), flags=re.S).strip()

SURFACE = ("skills/", "scripts/", "hooks/", "agents/", ".claude/flywheel/bin/",
           ".claude-plugin/", "upgrades/")
files = [f.strip() for f in meta.get("files", "").split(",")
         if f.strip().startswith(SURFACE)]

version = ""
try:
    version = json.load(open(os.path.join(here, "../.claude-plugin/plugin.json")))["version"]
except (OSError, ValueError, KeyError):
    try:
        first = (open(os.path.join(here, "../VERSION")).read().splitlines() or [""])[0]
        version = first.split()[-1] if first.split() else ""
    except OSError:
        pass

repo = os.environ.get("FW_UPSTREAM") or "https://github.com/arazvan-ec/xmarks"
typ = meta.get("type") or (title.split(":", 1)[0] if ":" in title else "")


def url(what):
    q = {"template": "flywheel-feedback.yml", "labels": "flywheel-feedback",
         "title": title, "type": typ, "what": what,
         "evidence": meta.get("evidence") or "unverified",
         "version": version, "files": ", ".join(files)}
    return f"{repo.rstrip('/')}/issues/new?" + urllib.parse.urlencode(q, quote_via=urllib.parse.quote)


what = prose
out = url(what)
while len(out) >= 7500 and what:
    what = what[: int(len(what) * 0.8)].rstrip()
    out = url(what + "\n\n[truncated — full entry in the source repo's LEARNINGS.md]")
print(out)
PY
