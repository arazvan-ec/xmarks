#!/usr/bin/env bash
# flywheel — route linter for a plan's task blocks (P27). A plan written by
# /flywheel:plan routes every task to a model + effort tier; this checks the
# routes are present, legal, and that the plan's riskiest step runs at the top
# tier of route-tiers.txt — then prints the tier summary the plan gate
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

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 - "$1" "${FLYWHEEL_ROUTE_TIERS:-${HERE}/route-tiers.txt}" <<'PY'
import os, re, sys
from collections import Counter

# Ascending cost/strength. These are the CLI's legal values; which point on each
# axis defines a tier is policy, and lives in route-tiers.txt.
MODEL_LADDER = ("haiku", "sonnet", "opus")
EFFORT_LADDER = ("low", "medium", "high", "max")
MODELS = MODEL_LADDER + ("inherit",)
EFFORTS = EFFORT_LADDER
TASK_RE = re.compile(r"^###\s+T(\d+)\s*[—–-]*\s*(.*)$")
FIELD_RE = re.compile(r"^\s*[-*]\s*([a-z-]+):\s*(.*)$", re.I)
ROUTE_RE = re.compile(r"^([^/+]+)/([^+]+)(?:\+(.+))?$")

path, tiers_path = sys.argv[1], sys.argv[2]
if not os.path.isfile(path):
    print(f"plan-route: cannot read {path}: no such file", file=sys.stderr)
    sys.exit(2)


def load_tiers(p):
    """-> {tier: (model, effort, delegate)} from the route-tiers.txt table."""
    if not os.path.isfile(p):
        print(f"plan-route: cannot read the tier table (route-tiers.txt) at {p}: "
              "no such file — the riskiest-step rule has no definition without it",
              file=sys.stderr)
        sys.exit(2)
    out = {}
    for n, raw in enumerate(open(p), 1):
        line = raw.split("#", 1)[0].split()
        if not line:
            continue
        bad = None
        if len(line) < 3 or not line[0].isdigit():
            bad = "expected '<tier> <model> <effort> [delegate]'"
        elif line[1] not in MODEL_LADDER:
            bad = f"unknown model '{line[1]}'"
        elif line[2] not in EFFORT_LADDER:
            bad = f"unknown effort '{line[2]}'"
        elif len(line) > 3 and line[3] != "delegate":
            bad = f"unknown flag '{line[3]}'"
        if bad:
            print(f"plan-route: {p}:{n}: {bad}", file=sys.stderr)
            sys.exit(2)
        out[int(line[0])] = (line[1], line[2], len(line) > 3)
    if not out:
        print(f"plan-route: {p}: no tiers defined", file=sys.stderr)
        sys.exit(2)
    return out


TIERS = load_tiers(tiers_path)
TOP = max(TIERS)
TOP_MODEL, TOP_EFFORT, _ = TIERS[TOP]

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


def ranks(model, effort):
    """-> (model rank, effort rank); either is None when it cannot be ranked."""
    m = MODEL_LADDER.index(model) if model in MODEL_LADDER else None
    e = EFFORT_LADDER.index(effort) if effort in EFFORT_LADDER else None
    return m, e


def tier_of(model, effort):
    """The tier a route exactly matches, or None when it sits between tiers."""
    for n, (tm, te, _d) in TIERS.items():
        if (model, effort) == (tm, te):
            return n
    return None


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
    if hot:
        rm, re_ = ranks(r[0], r[1])
        top_rm, top_re = ranks(TOP_MODEL, TOP_EFFORT)
        if rm is None or re_ is None:
            errors.append(f"{t['id']} is the riskiest step but routed '{r[0]}/{r[1]}' — the riskiest "
                          "step needs a named model and a named effort (not 'inherit', not an "
                          f"integer) so its tier is checkable; the top tier is tier {TOP} "
                          f"({TOP_MODEL}/{TOP_EFFORT})")
        elif rm < top_rm or re_ < top_re:
            errors.append(f"{t['id']} is the riskiest step but routed '{r[0]}/{r[1]}' — the riskiest "
                          f"step runs at the top tier: tier {TOP} ({TOP_MODEL}/{TOP_EFFORT}) or above "
                          "(scripts/route-tiers.txt)")

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
    tier = tier_of(model, effort)
    print(f"  {label:<24} {n:>3}   {f'tier {tier}' if tier else ''}".rstrip())
if risky:
    print(f"  riskiest: {', '.join(risky)}")

if errors:
    print()
    for e in errors:
        print(f"plan-route: FAIL: {e}", file=sys.stderr)
    sys.exit(1)
print("plan-route: OK")
PY
