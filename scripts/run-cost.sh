#!/usr/bin/env bash
# flywheel — cost comparison over run telemetry (P23). Totals the per-transition
# cost proxies in a run's JSONL and, given a baseline, prints the delta — so
# "this release made the loop cheaper" becomes a number instead of a claim.
#
# The three fields are PROXIES, deliberately: bytes written, tool calls and wall
# clock are observable from inside a session; token counts are not, and a guessed
# token number is exactly the unverifiable evidence P18 keeps out of the ledger.
# A `tokens` key in the data is reported as a warning, not consumed.
#
# Usage: run-cost.sh <run.jsonl> [baseline.jsonl]

set -euo pipefail

[ "$#" -ge 1 ] || { echo "usage: run-cost.sh <run.jsonl> [baseline.jsonl]" >&2; exit 2; }

python3 - "$@" <<'PY'
import json, sys, os
from collections import Counter

FIELDS = ("bytes_out", "tool_calls", "elapsed_s")
UNITS = {"bytes_out": "bytes", "tool_calls": "calls", "elapsed_s": "s"}


def plural(n, word):
    return f"{n} {word}" + ("" if n == 1 else "s")


def load(path):
    if not os.path.isfile(path):
        return None, f"cannot read {path}: no such file"
    totals = dict.fromkeys(FIELDS, 0)
    measured = unmeasured = skipped = 0
    tokens_seen = 0
    routes, unrouted, escalations = {}, 0, Counter()
    with open(path) as fh:
        for raw in fh:
            raw = raw.strip()
            if not raw:
                continue
            try:
                rec = json.loads(raw)
            except (ValueError, TypeError):
                skipped += 1
                continue
            if not isinstance(rec, dict):
                skipped += 1
                continue
            if "tokens" in rec or (isinstance(rec.get("cost"), dict) and "tokens" in rec["cost"]):
                tokens_seen += 1
            # Route (P27): which tier the plan bought for this transition, and
            # whether it had to be raised. Same discipline as `cost` — a
            # transition with no route is reported, never attributed to one.
            route = rec.get("route") if isinstance(rec.get("route"), str) else None
            if route:
                bucket = routes.setdefault(route, dict.fromkeys(FIELDS, 0) | {"n": 0, "measured": 0})
                bucket["n"] += 1
            else:
                unrouted += 1
            was = rec.get("route_escalated_from")
            if isinstance(was, str) and was:
                escalations[(was, route or "?")] += 1
            cost = rec.get("cost")
            if not isinstance(cost, dict):
                # No cost object: legitimate history (runs before this schema).
                # Reported as unmeasured — never folded in as 0, which would make
                # an old run look free and flatter every comparison against it.
                unmeasured += 1
                continue
            for f in FIELDS:
                v = cost.get(f)
                if isinstance(v, bool) or not isinstance(v, (int, float)):
                    continue
                totals[f] += v
                if route:
                    routes[route][f] += v
            if route:
                routes[route]["measured"] += 1
            measured += 1
    if measured == 0 and unmeasured == 0:
        return None, f"{path}: no transitions found (empty or no usable JSON lines; {skipped} skipped)"
    return {
        "path": path, "totals": totals, "measured": measured,
        "unmeasured": unmeasured, "skipped": skipped, "tokens_seen": tokens_seen,
        "routes": routes, "unrouted": unrouted, "escalations": escalations,
        "routed": sum(b["n"] for b in routes.values()),
    }, None


def report(r, label):
    t = r["totals"]
    print(f"{label}: {r['path']}")
    print(f"  transitions: {r['measured']} measured"
          + (f", {r['unmeasured']} UNMEASURED (no cost object — not counted as 0)" if r["unmeasured"] else ""))
    for f in FIELDS:
        print(f"  {f:<11} {t[f]:>12,} {UNITS[f]}")
    # Stay silent on routes for a pre-P27 run: no route anywhere is history, not
    # a finding, and "0 of 0" would be noise on every legacy file.
    if r["routes"]:
        print("  routes:")
        for route, b in sorted(r["routes"].items(), key=lambda kv: -kv[1]["n"]):
            cells = "  ".join(f"{b[f]:>9,} {UNITS[f]}" for f in FIELDS)
            short = f" ({b['n'] - b['measured']} unmeasured)" if b["measured"] < b["n"] else ""
            print(f"    {route:<22} {plural(b['n'], 'transition'):<16}{cells}{short}")
        if r["unrouted"]:
            print(f"    {plural(r['unrouted'], 'transition')} carr"
                  + ("ies" if r["unrouted"] == 1 else "y")
                  + " no route — reported, not attributed to one")
    n_esc = sum(r["escalations"].values())
    if r["routes"] or n_esc:
        rate = f" ({n_esc / r['routed'] * 100:.1f}%)" if r["routed"] else ""
        print(f"  escalations: {n_esc} of {plural(r['routed'], 'routed transition')}{rate}")
        for (was, now), n in r["escalations"].most_common():
            print(f"    {was} → {now}   {n}")
    if r["skipped"]:
        print(f"  skipped {r['skipped']} unparseable line(s)")
    if r["tokens_seen"]:
        print(f"  WARNING: {r['tokens_seen']} line(s) carry a `tokens` key. That field is not"
              f"\n           supported and is ignored: a session cannot observe its own token"
              f"\n           usage, so recording it puts unverifiable evidence in the ledger"
              f"\n           (P18). Use the proxies below it or measure spend outside the run.")


new, err = load(sys.argv[1])
if err:
    print(f"run-cost: {err}", file=sys.stderr)
    sys.exit(2)

print("run-cost: figures are COST PROXIES, not token counts — bytes written, tool")
print("          calls and wall clock, all observable from inside the session.")
print()
report(new, "run")

if len(sys.argv) > 2:
    base, err = load(sys.argv[2])
    if err:
        print(f"run-cost: {err}", file=sys.stderr)
        sys.exit(2)
    print()
    report(base, "baseline")
    print()
    print("delta (run vs baseline):")
    for f in FIELDS:
        d = new["totals"][f] - base["totals"][f]
        b = base["totals"][f]
        pct = f"{d / b * 100:+.1f}%" if b else "n/a (baseline 0)"
        print(f"  {f:<11} {d:>+12,} {UNITS[f]:<6} {pct}")
    n_new, n_base = sum(new["escalations"].values()), sum(base["escalations"].values())
    if new["routes"] or base["routes"] or n_new or n_base:
        d = n_new - n_base
        pct = f"{d / n_base * 100:+.1f}%" if n_base else "n/a (baseline 0)"
        print(f"  {'escalations':<11} {d:>+12,} {'events':<6} {pct}")
    if new["unmeasured"] or base["unmeasured"]:
        print("  NOTE: unmeasured transitions exist on at least one side — the delta covers")
        print("        only transitions that carry a cost object. Do not read it as complete.")
PY
