#!/usr/bin/env bash
# flywheel — CI gate (P74): a lesson that leaves work open says so in its
# metadata line (`followup=`), and the backlog row that carries it exists
# (`backlog=P<n>` with a `| P<n> |` row). Before this, six follow-ups written into
# P72's lessons reached the backlog zero times: prose in a ledger is read by
# nobody whose job is to schedule work.
#
# Usage: check-followups.sh [repo-root]
#   FLYWHEEL_BACKLOG  backlog file (default docs/research/improvement-proposals.md,
#                     else .claude/flywheel/BACKLOG.md)
# Exit: 0 ok · 1 an open follow-up with no backlog row

set -uo pipefail
ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "${ROOT}" || exit 2
LEDGER=".claude/flywheel/LEARNINGS.md"
[ -f "${LEDGER}" ] || { echo "followups: no ledger — nothing to check"; exit 0; }
BACKLOG="${FLYWHEEL_BACKLOG:-}"
if [ -z "${BACKLOG}" ]; then
  BACKLOG="docs/research/improvement-proposals.md"
  [ -f "${BACKLOG}" ] || BACKLOG=".claude/flywheel/BACKLOG.md"
fi

python3 - "${LEDGER}" "${BACKLOG}" <<'PY'
import os, re, sys
ledger, backlog = sys.argv[1], sys.argv[2]
rows = set()
if os.path.isfile(backlog):
    rows = set(re.findall(r"^\|\s*(P\d+[a-z]?)\s*\|", open(backlog).read(), re.M))
title, open_n, bad = "?", 0, []
for line in open(ledger):
    h = re.match(r"^## (.+)$", line)
    if h:
        title = h.group(1).strip()
    m = re.search(r"<!-- fw:(.*?)-->", line)
    if not m or not re.search(r"(^|;)\s*followup=", m.group(1)):
        continue
    open_n += 1
    b = re.search(r"(?:^|;)\s*backlog=([^;]+)", m.group(1))
    ids = re.findall(r"P\d+[a-z]?", b.group(1)) if b else []
    if not ids:
        bad.append(f"'{title}': followup= with no backlog=P<n>")
    for i in ids:
        if i not in rows:
            bad.append(f"'{title}': backlog={i} has no | {i} | row in {backlog}")
if bad:
    print(f"followups: {len(bad)} open follow-up(s) not in the backlog:", file=sys.stderr)
    for x in bad:
        print(f"  {x}", file=sys.stderr)
    print("  Fix: add the row to the backlog (next free P-number) and write backlog=P<n> in the entry.", file=sys.stderr)
    sys.exit(1)
print(f"followups: OK — {open_n} open follow-up(s), each with its backlog row")
PY
