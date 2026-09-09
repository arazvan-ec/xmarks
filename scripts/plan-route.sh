#!/usr/bin/env bash
# flywheel — route linter for a plan's task blocks (P27). A plan written by
# /flywheel:plan routes every task to a model + effort tier; this checks the
# routes are present, legal, and that the plan's riskiest step is not the one
# running on the cheapest tier — then prints the tier summary the plan gate
# shows. Cost is never claimed in tokens (P18/P23): the summary counts tasks.
#
# The task block format is pinned by skills/plan/SKILL.md. Enforced here: one
# `- route:` (`<model>/<effort>[+delegate]`), one `- check:`, and exactly one
# `- risk: highest` in a plan with 2+ tasks.
#
# Usage: plan-route.sh <plan.md>
# Exit: 0 OK · 1 lint failures · 2 unusable input (no file, no argument, no tasks)

set -euo pipefail

[ "$#" -ge 1 ] || { echo "usage: plan-route.sh <plan.md>" >&2; exit 2; }

python3 - "$1" <<'PY'
import os, re, sys
from collections import Counter

MODELS = ("haiku", "sonnet", "opus", "inherit")
EFFORTS = ("low", "medium", "high", "max")
TASK_RE = re.compile(r"^###\s+T(\d+)\s*[—–-]*\s*(.*)$")
FIELD_RE = re.compile(r"^\s*[-*]\s*([a-z-]+):\s*(.*)$", re.I)
ROUTE_RE = re.compile(r"^([^/+]+)/([^+]+)(?:\+(.+))?$")

path = sys.argv[1]
if not os.path.isfile(path):
    print(f"plan-route: cannot read {path}: no such file", file=sys.stderr)
    sys.exit(2)

tasks, cur = [], None
with open(path) as fh:
    for raw in fh:
        m = TASK_RE.match(raw)
        if m:
            cur = {"id": f"T{m.group(1)}", "title": m.group(2).strip(), "routes": [], "fields": {}}
            tasks.append(cur)
            continue
        if cur is None:
            continue
        f = FIELD_RE.match(raw)
        if not f:
            continue
        key, val = f.group(1).lower(), f.group(2).strip()
        if key == "route":
            cur["routes"].append(val)
        else:
            cur["fields"][key] = val

if not tasks:
    print(f"plan-route: {path}: no task blocks found — a plan's tasks are pinned to"
          "\n            '### T<n> — <title>' with a '- route:' line (see skills/plan/SKILL.md)",
          file=sys.stderr)
    sys.exit(2)

errors = []


def parse_route(spec):
    """-> ((model, effort, delegate) | None, [unprefixed error messages])."""
    m = ROUTE_RE.match(spec.strip().strip("`").strip().lower())
    if not m:
        return None, [f"route '{spec}' is not '<model>/<effort>[+delegate]'"]
    model, effort = m.group(1).strip(), m.group(2).strip()
    suffix = (m.group(3) or "").strip()
    if suffix and suffix != "delegate":
        return None, [f"unknown route suffix '+{suffix}' — the only suffix is '+delegate'"]
    msgs = []
    if model not in MODELS:
        msgs.append(f"invalid model '{model}' — one of {', '.join(MODELS)}")
    if effort not in EFFORTS and not (effort.isdigit() and 1 <= int(effort) <= 100):
        msgs.append(f"invalid effort '{effort}' — one of {', '.join(EFFORTS)} or an integer")
    return (None if msgs else (model, effort, suffix == "delegate")), msgs


def cheap(model, effort):
    """The cheapest tier: the fast model, or thinking turned down."""
    return model == "haiku" or effort == "low" or (effort.isdigit() and int(effort) < 5)


routed, risky = [], []
for t in tasks:
    hot = t["fields"].get("risk", "").lower().startswith("highest")
    if hot:
        risky.append(t["id"])
    if not t["fields"].get("check"):
        errors.append(f"{t['id']}: no '- check:' line — a route without a pass/fail check is not a task")
    if not t["routes"]:
        errors.append(f"{t['id']}: no '- route:' line — every task carries its model/effort tier")
        continue
    if len(t["routes"]) > 1:
        errors.append(f"{t['id']}: {len(t['routes'])} route lines — a task has exactly one route")
        continue
    r, msgs = parse_route(t["routes"][0])
    errors += [f"{t['id']}: {m}" for m in msgs]
    if not r:
        continue
    routed.append(r)
    if hot and cheap(r[0], r[1]):
        errors.append(f"{t['id']} is the riskiest step but routed '{r[0]}/{r[1]}' — the riskiest "
                      "step never runs on the cheapest tier (not haiku, not low effort)")

if len(tasks) > 1:
    if not risky:
        errors.append("no task carries '- risk: highest' — the plan must name its single riskiest step")
    elif len(risky) > 1:
        errors.append("more than one task carries '- risk: highest' ("
                      + ", ".join(risky) + ") — the plan names exactly one")

unusable = len(tasks) - len(routed)
print(f"plan-route: {path}")
print(f"  {len(tasks)} tasks routed" + (f", {unusable} unusable" if unusable else ""))
for (model, effort, delegate), n in Counter(routed).most_common():
    label = f"{model}/{effort}" + ("+delegate" if delegate else "")
    print(f"  {label:<24} {n:>3}")
if risky:
    print(f"  riskiest: {', '.join(risky)}")

if errors:
    print()
    for e in errors:
        print(f"plan-route: FAIL: {e}", file=sys.stderr)
    sys.exit(1)
print("plan-route: OK")
PY
