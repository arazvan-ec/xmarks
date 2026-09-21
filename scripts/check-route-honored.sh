#!/usr/bin/env bash
# flywheel — CI gate (P49): the ladder a plan bought, against the one its run
# recorded.
#
# The aggregate said the route ladder had collapsed — 40 of 46 routed
# transitions on opus, haiku zero. Per task it is not disobedience: every
# transition mapping 1:1 to a plan task honored its route. The ladder evaporates
# three other ways, and no gate asked about any of them:
#
#   NOT STARTED — a plan whose cycle has NO line for ANY of its tasks. The loop
#                commits a plan at its approval gate, before the work, so this is
#                a plan waiting to be built, not a record that went missing. A
#                notice; check-task-closure.sh calls the same state PENDING.
#   UNRECORDED — a plan task with no transition line at all. Five across p42 and
#                p43, including ALL FOUR haiku/low+delegate tasks. The ledger
#                cannot tell "ran and wrote nothing" from "never ran", so this is
#                reported as absence and never as a wrong tier.
#   MERGED     — one transition covering `T1-T2` runs at the max of the two, so
#                the cheaper task's route is bought and never used. A notice: the
#                merge is legal, going unsaid is what costs.
#   UNRANKABLE — a route route-tiers.txt cannot rank is compared against nothing;
#                reported, never read as honored. (26 lines carried `opus/xhigh`
#                until v0.67.0 gave the ladder that rung.)
#   UNCOMPARED — a plan whose slug has no run directory, or one holding no JSONL.
#                Twelve of them here, and the loop below never reached any: they
#                are named and counted, never failed, because check-telemetry.sh
#                owns the duty of failing a spec with no telemetry and its
#                baseline exempts exactly these cycles with a reason (P53).
#
# Tier and delegation are different axes. A record that drops a planned
# `+delegate` is neither above nor below the plan, and folding the suffix into
# the tier comparison is how a subagent that never ran passed as honored (P53).
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

CUT_FROM="$(python3 "${HERE}/fw_cutoffs.py" route-check FLYWHEEL_ROUTE_CHECK_FROM)" || exit 2
[ -n "${CUT_FROM}" ] || { echo "route-honored: empty cutoff — an empty cut forgives the whole corpus" >&2; exit 2; }

FW_ROOT="${ROOT}" FW_HERE="${HERE}" \
FW_ROUTE_FROM="${CUT_FROM}" python3 - <<'PY'
import json, os, re, subprocess, sys

root, here = os.environ["FW_ROOT"], os.environ["FW_HERE"]
CUT = os.environ["FW_ROUTE_FROM"]
specs = os.path.join(root, ".claude", "flywheel", "specs")
runs = os.path.join(root, ".claude", "flywheel", "runs")

sys.path.insert(0, here)
from fw_tasks import task_ids  # one reader, shared with check-task-closure.sh

ROUTE_RE = re.compile(r"^([^/+]+)/([^+]+)(?:\+(.+))?$")


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


def delegates(route):
    """Whether a recorded route carries +delegate.

    Tier and delegation are different axes, so this is read separately and
    compared separately: a record that drops a planned +delegate is neither
    above nor below the plan, and folding it into the tier comparison is how it
    went unnoticed."""
    if not isinstance(route, str):
        return False
    m = ROUTE_RE.match(route.strip().strip("`").lower())
    return bool(m and (m.group(3) or "").strip() == "delegate")


fatal, notices, checked, pre = [], [], 0, 0
no_plan, compared = [], set()

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

    compared.add(slug)
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
        want_d = bool(tasks[planned_id].get("delegate"))
        got_d = delegates(got)
        if want_d and not got_d and not rec.get("route_escalated_from"):
            msg = (f"{where} ran {got} where the plan routed {planned} — the"
                   f" delegation it bought is not in the record, and a subagent"
                   f" that never ran is the one thing the tier alone cannot show")
            (fatal if post else notices).append(msg)
            pre += 0 if post else 1
        elif got_d and not want_d:
            notices.append(f"{where} delegated where the plan routed {planned} —"
                           f" reported, not a finding: less was spent, not more")
        if rg > rp and not rec.get("route_escalated_from"):
            msg = (f"{where} ran {got} where the plan routed {planned}, with no"
                   f" route_escalated_from to say so — an upgrade is a mis-route"
                   f" observed, and the record is where it is honest")
            (fatal if post else notices).append(msg)
            pre += 0 if post else 1
        elif rg < rp and not rec.get("route_escalated_from"):
            notices.append(f"{where} ran {got} below the plan's {planned}")

    missing = sorted(set(tasks) - covered, key=lambda i: int(i[1:]))
    if missing and not covered:
        # NOT STARTED, and it is a different claim from UNRECORDED. The loop
        # commits a plan at its APPROVAL gate, before any work, so a plan-only
        # commit has a ledger (spec/plan transitions) and no task lines at all.
        # Failing it calls every task unrecorded for not having happened yet.
        # A cycle with SOME task lines has started, so a gap in it is genuinely
        # unrecorded and stays fatal below — that distinction is the whole rule,
        # and without it this branch would delete P49.
        notices.append(f"{slug}: no transition line for any of its {len(tasks)} task(s)"
                       f" — the cycle has not started, so there is no route to honor yet")
    elif missing:
        post = newest >= CUT
        msg = (f"{slug}: {', '.join(missing)} ha{'s' if len(missing) == 1 else 've'} no"
               f" transition line — unrecorded, so the ledger cannot say whether"
               f" {'it' if len(missing) == 1 else 'they'} ran"
               f" ({', '.join(tasks[i]['route'] for i in missing)})")
        (fatal if post else notices).append(msg)
        pre += 0 if post else 1

# A plan whose slug has no run directory, or an empty one, was never reached by
# the loop above — the gate simply said nothing about it (Codex, PR #91). It is
# named here and counted, not failed: `check-telemetry.sh` owns the duty of
# failing a spec with no telemetry, and the plans in this state are exactly the
# cycles its baseline exempts with a reason. Failing here would contradict a
# decision already taken; saying nothing was the actual defect.
uncompared = []
if os.path.isdir(specs):
    for f in sorted(os.listdir(specs)):
        if not f.endswith(".plan.md"):
            continue
        slug = f[: -len(".plan.md")]
        if slug not in compared:
            uncompared.append(slug)

for f in fatal:
    print(f"route-honored: {f}")
for n in notices:
    print(f"route-honored: note — {n}")

for u in uncompared:
    print(f"route-honored: note — {u} has a plan and no usable run record, so none"
          f" of its tasks could be compared with the routes it bought")

print(f"route-honored: {checked} transition(s) compared against a plan;"
      f" {len(no_plan)} cycle(s) ran without one, so there was no route to honor"
      + (f"; {len(uncompared)} plan(s) had no record to compare." if uncompared else "."))
if pre:
    print(f"route-honored: {pre} finding(s) predate the cutoff ({CUT}) and are counted,"
          f" not failed — nothing is backfilled to change them (P18).")

sys.exit(1 if fatal else 0)
PY
