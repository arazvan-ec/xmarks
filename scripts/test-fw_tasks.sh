#!/usr/bin/env bash
# flywheel — test for scripts/fw_tasks.py, the single reader of a transition
# line's `task` field. Two gates depend on it agreeing with itself, and
# check-test-pairing.sh only guards scripts/*.sh, so this file is the coverage
# a .py helper would otherwise never be required to have.

set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "${SRC}/scripts" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
from fw_tasks import task_ids

cases = [
    ("T3", {"T3"}),          ("t3", {"T3"}),        (3, {"T3"}),
    ("3", {"T3"}),           ("  T7  ", {"T7"}),
    ("T2-T3", {"T2", "T3"}), ("T2–T3", {"T2", "T3"}),   # en dash
    ("T2-3", set()),                               # no T on the right: not a range
    ("T3-T2", {"T2", "T3"}),                       # reversed still spans both
    ("T1-T4", {"T1", "T2", "T3", "T4"}),
    # Phase names identify no task: these transitions precede the plan.
    ("spec", set()), ("plan", set()), ("review", set()),
    (None, set()), (True, set()), (False, set()), ("", set()),
]
bad = [(i, task_ids(i), w) for i, w in cases if task_ids(i) != w]
if bad:
    for i, got, want in bad:
        print(f"FAIL: task_ids({i!r}) = {got!r}, want {want!r}", file=sys.stderr)
    sys.exit(1)
print(f"  ok: {len(cases)} task-field spellings map as documented")
PY
echo "fw-tasks: all assertions passed"
