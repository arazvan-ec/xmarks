"""Plan-task identity as a transition line spells it (P49).

One reader, two consumers: check-route-honored.sh pairs plan tasks with the
routes they ran at, check-task-closure.sh grades the checks of the tasks that
ran. Both must agree on what `"task": "T2-T3"` covers, and a second copy of
this is how the two drift.
"""
import re

ONE_RE = re.compile(r"^[Tt](\d+)$")
# Both sides carry the T, and the dash may be typographic: this is
# check-route-honored.sh's original pattern, preserved exactly. Widening it
# would silently re-map lines the ledger currently counts as unrecorded.
RANGE_RE = re.compile(r"^[Tt](\d+)\s*[-–—]\s*[Tt](\d+)$")


def task_ids(task):
    """-> the plan task ids a transition's `task` field covers, possibly none.

    `spec`, `plan` and phase names map to nothing on purpose: those transitions
    precede the plan and have no task to identify."""
    if isinstance(task, bool) or task is None:
        return set()
    if isinstance(task, int):
        return {f"T{task}"}
    s = str(task).strip()
    m = ONE_RE.match(s)
    if m:
        return {f"T{m.group(1)}"}
    m = RANGE_RE.match(s)
    if m:
        lo, hi = int(m.group(1)), int(m.group(2))
        return {f"T{i}" for i in range(min(lo, hi), max(lo, hi) + 1)}
    if s.isdigit():
        return {f"T{s}"}
    return set()
