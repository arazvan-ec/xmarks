#!/usr/bin/env bash
# flywheel — route linter for a plan's task blocks (P27). A plan written by
# /flywheel:plan routes every task to a model + effort tier; this checks the
# routes are present, legal, and that the plan's riskiest step is not the one
# running on the cheapest tier — then prints the tier summary the plan gate
# shows. Cost is never claimed in tokens (P18/P23): the summary counts tasks.
#
# Pinned task block (the format skills/plan/SKILL.md writes):
#   ### T<n> — <title>
#   - route: `<model>/<effort>[+delegate]`
#   - risk: highest          (exactly one task, plans with 2+ tasks)
#   - changes: <files>
#   - check: <what proves it done>
#   - test-first: yes|no
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


def parse_route(task, spec):
    """-> (model, effort, delegate) or None, appending an error on bad syntax."""
    s = spec.strip().strip("`").strip()
    if "/" not in s:
        errors.append(f"{task['id']}: route '{spec}' is not '<model>/<effort>[+delegate]'")
        return None
    model, rest = s.split("/", 1)
    model = model.strip().lower()
    delegate = False
    if "+" in rest:
        rest, suffix = rest.split("+", 1)
        suffix = suffix.strip().lower()
        if suffix == "delegate":
            delegate = True
        else:
            errors.append(f"{task['id']}: unknown route suffix '+{suffix}' — the only suffix is '+delegate'")
            return None
    effort = rest.strip().lower()
    ok = True
    if model not in MODELS:
        errors.append(f"{task['id']}: invalid model '{model}' — one of {', '.join(MODELS)}")
        ok = False
    if effort not in EFFORTS and not (effort.isdigit() and 1 <= int(effort) <= 100):
        errors.append(f"{task['id']}: invalid effort '{effort}' — one of {', '.join(EFFORTS)} or an integer")
        ok = False
    return (model, effort, delegate) if ok else None


def cheap(model, effort):
    """The cheapest tier: the fast model, or thinking turned down."""
    return model == "haiku" or effort == "low" or (effort.isdigit() and int(effort) < 5)


routed, risky = [], []
for t in tasks:
    if not t["routes"]:
        errors.append(f"{t['id']}: no '- route:' line — every task carries its model/effort tier")
    elif len(t["routes"]) > 1:
        errors.append(f"{t['id']}: {len(t['routes'])} route lines — a task has exactly one route")
    else:
        r = parse_route(t, t["routes"][0])
        if r:
            routed.append((t, r))
    if not t["fields"].get("check"):
        errors.append(f"{t['id']}: no '- check:' line — a route without a pass/fail check is not a task")
    if t["fields"].get("risk", "").lower().startswith("highest"):
        risky.append(t)

if len(tasks) > 1:
    if not risky:
        errors.append("no task carries '- risk: highest' — the plan must name its single riskiest step")
    elif len(risky) > 1:
        errors.append("more than one task carries '- risk: highest' ("
                      + ", ".join(t["id"] for t in risky) + ") — the plan names exactly one")

for t, (model, effort, _d) in routed:
    if t in risky and cheap(model, effort):
        errors.append(f"{t['id']} is the riskiest step but routed '{model}/{effort}' — the riskiest "
                      "step never runs on the cheapest tier (not haiku, not low effort)")

print(f"plan-route: {path}")
print(f"  {len(tasks)} tasks routed" + (f", {len(tasks) - len(routed)} unusable" if len(routed) != len(tasks) else ""))
counts = Counter(f"{m}/{e}" for _t, (m, e, _d) in routed)
delegated = Counter(f"{m}/{e}" for _t, (m, e, d) in routed if d)
for route, n in counts.most_common():
    extra = f"  ({delegated[route]} delegated)" if delegated[route] else ""
    print(f"  {route:<16} {n:>3}{extra}")
if risky:
    print(f"  riskiest: {', '.join(t['id'] for t in risky)}")

if errors:
    print()
    for e in errors:
        print(f"plan-route: FAIL: {e}", file=sys.stderr)
    sys.exit(1)
print("plan-route: OK")
PY
