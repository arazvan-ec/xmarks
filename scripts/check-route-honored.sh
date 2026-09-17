#!/usr/bin/env bash
# flywheel — CI gate (P49): the ladder a plan bought, against the one its run
# recorded.
#
# The aggregate said the route ladder had collapsed — 40 of 46 routed
# transitions on opus, haiku zero. Per task it is not disobedience: every
# transition mapping 1:1 to a plan task honored its route. The ladder evaporates
# three other ways, and no gate asked about any of them:
#
#   UNRECORDED — a plan task with no transition line at all. Five across p42 and
#                p43, including ALL FOUR haiku/low+delegate tasks. The ledger
#                cannot tell "ran and wrote nothing" from "never ran", so this is
#                reported as absence and never as a wrong tier.
#   MERGED     — one transition covering `T1-T2` runs at the max of the two, so
#                the cheaper task's route is bought and never used. A notice: the
#                merge is legal, going unsaid is what costs.
#   UNRANKABLE — 26 lines carry `opus/xhigh`, an effort route-tiers.txt does not
#                define. A route nothing can rank is compared against nothing;
#                reported, never read as honored. Whether `xhigh` is a tier is
#                the owner's call, not this gate's.
#
# What fails: a transition that ran ABOVE its plan's tier without
# `route_escalated_from` to say so, and a plan task with no line. Both only from
# the cutoff on — the corpus predates the rule and nothing may be backfilled
# (P18), exactly as in P48.
#
# The plan is parsed by plan-route.sh --json, never here: two readers of one
# format is how the two drift.
#
# Usage: check-route-honored.sh [repo-root]
#   SKIP_ROUTE_CHECK=<reason>     skip with a logged notice, never silently
#   FLYWHEEL_ROUTE_CHECK_FROM     move the cutoff (default: the P48 constant)
#
# Exit: 0 ok · 1 an unrecorded task or an unsaid upgrade after the cutoff
#         · 2 unusable input (no python3, or a plan the linter rejects)

set -uo pipefail

if [ -n "${SKIP_ROUTE_CHECK:-}" ]; then
  echo "route-honored: SKIPPED via SKIP_ROUTE_CHECK=${SKIP_ROUTE_CHECK}"
  exit 0
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$(cd "${HERE}/.." && pwd)}"

command -v python3 >/dev/null 2>&1 || { echo "route-honored: no python3" >&2; exit 2; }

FW_ROOT="${ROOT}" FW_HERE="${HERE}" \
FW_ROUTE_FROM="${FLYWHEEL_ROUTE_CHECK_FROM:-2026-09-17T20:00:00Z}" python3 - <<'PY'
import json, os, re, subprocess, sys

root, here = os.environ["FW_ROOT"], os.environ["FW_HERE"]
CUT = os.environ["FW_ROUTE_FROM"]
specs = os.path.join(root, ".claude", "flywheel", "specs")
runs = os.path.join(root, ".claude", "flywheel", "runs")

RANGE_RE = re.compile(r"^[Tt](\d+)\s*[-–—]\s*[Tt](\d+)$")
ONE_RE = re.compile(r"^[Tt](\d+)$")
ROUTE_RE = re.compile(r"^([^/+]+)/([^+]+)(?:\+(.+))?$")


def task_ids(task):
    """-> the plan task ids a transition's `task` field covers, possibly none.

    `spec`, `plan` and phase names map to nothing on purpose: those transitions
    precede the plan and have no route to honor."""
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


def rank(route, models, efforts):
    """-> (model rank, effort rank), or None when the ladder cannot rank it."""
    if not isinstance(route, str):
        return None
    m = ROUTE_RE.match(route.strip().strip("`").lower())
    if not m:
        return None
    model, effort = m.group(1).strip(), m.group(2).strip()
    if model not in models or effort not in efforts:
        return None
    return (models.index(model), efforts.index(effort))


fatal, notices, checked, pre = [], [], 0, 0
no_plan = []

for slug in sorted(os.listdir(runs)) if os.path.isdir(runs) else []:
    d = os.path.join(runs, slug)
    if not os.path.isdir(d):
        continue
    files = sorted(f for f in os.listdir(d) if f.endswith(".jsonl"))
    if not files:
        continue
    plan = os.path.join(specs, f"{slug}.plan.md")
    if not os.path.isfile(plan):
        # A standalone /flywheel:work run has no plan, so there is no route to
        # honor. Counted, never a finding.
        no_plan.append(slug)
        continue
    proc = subprocess.run(["bash", os.path.join(here, "plan-route.sh"), "--json", plan],
                          capture_output=True, text=True)
    if proc.returncode != 0:
        print(f"route-honored: {slug}: its plan does not lint, so the routes it bought"
              f" cannot be read — fix the plan first\n{proc.stderr.strip()}", file=sys.stderr)
        sys.exit(2)
    doc = json.loads(proc.stdout)
    models, efforts = doc["model_ladder"], doc["effort_ladder"]
    tasks = {t["id"]: t for t in doc["tasks"]}

    rows = []
    for f in files:
        for raw in open(os.path.join(d, f), encoding="utf-8"):
            raw = raw.strip()
            if not raw:
                continue
            try:
                rec = json.loads(raw)
            except ValueError:
                continue
            if isinstance(rec, dict):
                rows.append(rec)
    if not rows:
        continue

    newest = max((str(r.get("ts") or "") for r in rows), default="")
    covered = set()

    for rec in rows:
        mapped = task_ids(rec.get("task")) & set(tasks)
        if not mapped:
            continue
        covered |= mapped
        checked += 1
        post = str(rec.get("ts") or "") >= CUT
        where = f"{slug} {rec.get('task')!r}"
        got = rec.get("route")
        planned_id = max(mapped, key=lambda i: tuple(
            -1 if v is None else v for v in (tasks[i]["rank"] or [None, None])))
        planned = tasks[planned_id]["route"]
        if len(mapped) > 1:
            cheaper = sorted(i for i in mapped if tasks[i]["route"] != planned)
            if cheaper:
                notices.append(f"{where} covers {', '.join(sorted(mapped))} and runs at"
                               f" {planned} — {', '.join(cheaper)} routed cheaper and was"
                               f" absorbed, so the tier it bought was never used")
        if not got:
            notices.append(f"{where} records no route, so it cannot be compared with"
                           f" the plan's {planned}")
            continue
        rg = rank(got, models, efforts)
        rp = rank(planned, models, efforts)
        if rg is None:
            notices.append(f"{where} ran {got!r}, which route-tiers.txt cannot rank"
                           f" (efforts: {'|'.join(efforts)}) — not read as honoring"
                           f" {planned}")
            continue
        if rp is None:
            notices.append(f"{where}: the plan's own route {planned!r} cannot be ranked")
            continue
        if rg > rp and not rec.get("route_escalated_from"):
            msg = (f"{where} ran {got} where the plan routed {planned}, with no"
                   f" route_escalated_from to say so — an upgrade is a mis-route"
                   f" observed, and the record is where it is honest")
            (fatal if post else notices).append(msg)
            pre += 0 if post else 1
        elif rg < rp and not rec.get("route_escalated_from"):
            notices.append(f"{where} ran {got} below the plan's {planned}")

    missing = sorted(set(tasks) - covered, key=lambda i: int(i[1:]))
    if missing:
        post = newest >= CUT
        msg = (f"{slug}: {', '.join(missing)} ha{'s' if len(missing) == 1 else 've'} no"
               f" transition line — unrecorded, so the ledger cannot say whether"
               f" {'it' if len(missing) == 1 else 'they'} ran"
               f" ({', '.join(tasks[i]['route'] for i in missing)})")
        (fatal if post else notices).append(msg)
        pre += 0 if post else 1

for f in fatal:
    print(f"route-honored: {f}")
for n in notices:
    print(f"route-honored: note — {n}")

print(f"route-honored: {checked} transition(s) compared against a plan;"
      f" {len(no_plan)} cycle(s) ran without one, so there was no route to honor.")
if pre:
    print(f"route-honored: {pre} finding(s) predate the cutoff ({CUT}) and are counted,"
          f" not failed — nothing is backfilled to change them (P18).")

sys.exit(1 if fatal else 0)
PY
