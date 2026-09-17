#!/usr/bin/env bash
# flywheel — cost comparison over run telemetry (P23). Totals the per-transition
# cost proxies in a run's JSONL and, given a baseline, prints the delta — so
# "this release made the loop cheaper" becomes a number instead of a claim.
#
# The four fields are PROXIES, deliberately: bytes written, bytes read, tool
# calls and wall clock are observable from inside a session; token counts are
# not, and a guessed token number is exactly the unverifiable evidence P18 keeps
# out of the ledger. bytes_in (P40a) is a FLOOR on read volume: it charges once
# per read and nothing for the conversation itself.
# A `tokens` key in the data is reported as a warning, not consumed.
#
# Usage: run-cost.sh <run.jsonl> [baseline.jsonl]
#        run-cost.sh --all <runs-dir>      roll every run file up into one view
#
# --all (P48) is the transversal question the per-run form cannot answer: how
# many cycles ran, and which PHASE of the loop the cost sits in. It merges the
# per-FIELD coverage too, so a phase whose lines predate a field reports it
# UNMEASURED instead of totalling the absence as zero.

set -euo pipefail

[ "$#" -ge 1 ] || { echo "usage: run-cost.sh <run.jsonl> [baseline.jsonl]" >&2
                    echo "       run-cost.sh --all <runs-dir>" >&2; exit 2; }

python3 - "$@" <<'PY'
import json, sys, os
from collections import Counter

FIELDS = ("bytes_out", "bytes_in", "tool_calls", "elapsed_s")
UNITS = {"bytes_out": "bytes", "bytes_in": "bytes", "tool_calls": "calls", "elapsed_s": "s"}


def plural(n, word):
    return f"{n} {word}" + ("" if n == 1 else "s")


def load(path):
    if not os.path.isfile(path):
        return None, f"cannot read {path}: no such file"
    totals = dict.fromkeys(FIELDS, 0)
    # Per FIELD, not per line (P40a): bytes_in arrived after the other three, so
    # every run written before it has a cost object that is complete for three
    # fields and absent for the fourth. Counting that absence as 0 would make any
    # pre-P40a baseline look like it read nothing.
    coverage = dict.fromkeys(FIELDS, 0)
    measured = unmeasured = skipped = 0
    tokens_seen = 0
    routes, unrouted, escalations = {}, 0, Counter()
    phases, phaseless = {}, 0
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
                bucket = routes.setdefault(route, dict.fromkeys(FIELDS, 0) | {
                    "n": 0, "measured": 0, "cov": dict.fromkeys(FIELDS, 0)})
                bucket["n"] += 1
            else:
                unrouted += 1
            # Phase (P48): which step of the loop this transition belongs to.
            # Same discipline as `route` — a line that names none is counted
            # apart, never folded into one.
            phase = rec.get("phase") if isinstance(rec.get("phase"), str) else None
            phase = phase.strip() or None if phase else None
            if phase:
                phases.setdefault(phase, dict.fromkeys(FIELDS, 0) | {
                    "n": 0, "measured": 0, "cov": dict.fromkeys(FIELDS, 0)})["n"] += 1
            else:
                phaseless += 1
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
                coverage[f] += 1
                if route:
                    routes[route][f] += v
                    routes[route]["cov"][f] += 1
                if phase:
                    phases[phase][f] += v
                    phases[phase]["cov"][f] += 1
            if route:
                routes[route]["measured"] += 1
            if phase:
                phases[phase]["measured"] += 1
            measured += 1
    if measured == 0 and unmeasured == 0:
        return None, f"{path}: no transitions found (empty or no usable JSON lines; {skipped} skipped)"
    return {
        "path": path, "totals": totals, "coverage": coverage, "measured": measured,
        "unmeasured": unmeasured, "skipped": skipped, "tokens_seen": tokens_seen,
        "routes": routes, "unrouted": unrouted, "escalations": escalations,
        "routed": sum(b["n"] for b in routes.values()),
        "phases": phases, "phaseless": phaseless,
    }, None


def merge(parts):
    """-> one corpus view over per-file results. Coverage is carried through the
    merge, not recomputed: a field absent from every file must still report
    UNMEASURED rather than total as zero."""
    out = {"path": None, "totals": dict.fromkeys(FIELDS, 0),
           "coverage": dict.fromkeys(FIELDS, 0), "measured": 0, "unmeasured": 0,
           "skipped": 0, "tokens_seen": 0, "routes": {}, "unrouted": 0,
           "escalations": Counter(), "phases": {}, "phaseless": 0, "cycles": {}}
    for name, r in parts:
        for f in FIELDS:
            out["totals"][f] += r["totals"][f]
            out["coverage"][f] += r["coverage"][f]
        for k in ("measured", "unmeasured", "skipped", "tokens_seen", "unrouted", "phaseless"):
            out[k] += r[k]
        out["escalations"] += r["escalations"]
        for key, buckets in (("routes", r["routes"]), ("phases", r["phases"])):
            for name_, b in buckets.items():
                dst = out[key].setdefault(name_, dict.fromkeys(FIELDS, 0) | {
                    "n": 0, "measured": 0, "cov": dict.fromkeys(FIELDS, 0)})
                dst["n"] += b["n"]
                dst["measured"] += b["measured"]
                for f in FIELDS:
                    dst[f] += b[f]
                    dst["cov"][f] += b["cov"][f]
        cyc = out["cycles"].setdefault(name, dict.fromkeys(FIELDS, 0) | {
            "n": 0, "measured": 0, "cov": dict.fromkeys(FIELDS, 0)})
        cyc["n"] += r["measured"] + r["unmeasured"]
        cyc["measured"] += r["measured"]
        for f in FIELDS:
            cyc[f] += r["totals"][f]
            cyc["cov"][f] += r["coverage"][f]
    out["routed"] = sum(b["n"] for b in out["routes"].values())
    return out


def cells(b):
    return "  ".join(
        f"{'—':>9} {UNITS[f]}" if not b["cov"][f]
        else f"{b[f]:>8,}~ {UNITS[f]}" if b["cov"][f] < b["measured"]
        else f"{b[f]:>9,} {UNITS[f]}" for f in FIELDS)


def buckets(title, bk, missing, what):
    print(f"  {title}:")
    for name, b in sorted(bk.items(), key=lambda kv: -kv[1]["n"]):
        short = f" ({b['n'] - b['measured']} unmeasured)" if b["measured"] < b["n"] else ""
        print(f"    {name:<26} {plural(b['n'], 'transition'):<16}{cells(b)}{short}")
    if any(0 < b["cov"][f] < b["measured"] for b in bk.values() for f in FIELDS):
        print(f"    ~ = partial coverage: some transitions on that {what} do not"
              " carry the field")
    if missing:
        print(f"    {plural(missing, 'transition')} carr"
              + ("ies" if missing == 1 else "y")
              + f" no {what} — reported, not attributed to one")


def fields(r):
    for f in FIELDS:
        c = r["coverage"][f]
        if c == 0:
            print(f"  {f:<11} UNMEASURED — no transition carries it, so it is not"
                  f" totalled (never read as zero)")
        elif c < r["measured"]:
            print(f"  {f:<11} {r['totals'][f]:>12,} {UNITS[f]:<6} PARTIAL"
                  f" ({c} of {r['measured']} transitions carry it)")
        else:
            print(f"  {f:<11} {r['totals'][f]:>12,} {UNITS[f]}")


def report(r, label):
    print(f"{label}: {r['path']}")
    print(f"  transitions: {r['measured']} measured"
          + (f", {r['unmeasured']} UNMEASURED (no cost object — not counted as 0)" if r["unmeasured"] else ""))
    fields(r)
    # Stay silent on routes for a pre-P27 run, and on phases for a pre-P48 one:
    # none anywhere is history, not a finding, and "0 of 0" would be noise on
    # every legacy file.
    if r["phases"]:
        buckets("by phase", r["phases"], r["phaseless"], "phase")
    if r["routes"]:
        buckets("routes", r["routes"], r["unrouted"], "route")
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


if sys.argv[1] == "--all":
    root = sys.argv[2] if len(sys.argv) > 2 else None
    if not root or not os.path.isdir(root):
        print(f"run-cost: --all needs a runs directory"
              + (f": {root} is not one" if root else " — none given"), file=sys.stderr)
        sys.exit(2)
    parts, problems = [], []
    for dirpath, _, files in os.walk(root):
        for f in sorted(files):
            if not f.endswith(".jsonl"):
                continue
            r, err = load(os.path.join(dirpath, f))
            if err:
                problems.append(err)
                continue
            parts.append((os.path.relpath(dirpath, root), r))
    if not parts:
        # An empty corpus is not a green "nothing to report": it means the runs
        # directory is wrong, or no cycle has ever written telemetry.
        print(f"run-cost: {root} holds no usable run files"
              + (f" ({len(problems)} unreadable)" if problems else ""), file=sys.stderr)
        sys.exit(2)
    c = merge(parts)
    print("run-cost: figures are COST PROXIES, not token counts — bytes written, bytes")
    print("          read, tool calls and wall clock, all observable from inside the")
    print("          session. bytes_in is a floor on read volume, not its total.")
    print()
    print(f"corpus: {root}")
    print(f"  {plural(len(c['cycles']), 'cycle')}, "
          f"{plural(c['measured'] + c['unmeasured'], 'transition')}"
          + (f" ({c['unmeasured']} UNMEASURED — no cost object, not counted as 0)"
             if c["unmeasured"] else ""))
    fields(c)
    if c["phases"] or c["phaseless"]:
        buckets("by phase", c["phases"], c["phaseless"], "phase")
    if c["routes"] or c["unrouted"]:
        buckets("routes", c["routes"], c["unrouted"], "route")
    n_esc = sum(c["escalations"].values())
    if c["routes"] or n_esc:
        rate = f" ({n_esc / c['routed'] * 100:.1f}%)" if c["routed"] else ""
        print(f"  escalations: {n_esc} of {plural(c['routed'], 'routed transition')}{rate}")
        for (was, now), n in c["escalations"].most_common():
            print(f"    {was} → {now}   {n}")
    buckets("by cycle", c["cycles"], 0, "cycle")
    if c["skipped"]:
        print(f"  skipped {c['skipped']} unparseable line(s)")
    if c["tokens_seen"]:
        print(f"  WARNING: {c['tokens_seen']} line(s) carry a `tokens` key — ignored (P18).")
    for p in problems:
        print(f"  note: {p}")
    sys.exit(0)

new, err = load(sys.argv[1])
if err:
    print(f"run-cost: {err}", file=sys.stderr)
    sys.exit(2)

print("run-cost: figures are COST PROXIES, not token counts — bytes written, bytes")
print("          read, tool calls and wall clock, all observable from inside the")
print("          session. bytes_in is a floor on read volume, not its total.")
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
        # A field one side never recorded has no delta, only a fabricated one:
        # against a baseline blind to bytes_in, every run reads as +100%.
        if not new["coverage"][f] or not base["coverage"][f]:
            blind = "run" if not new["coverage"][f] else "baseline"
            print(f"  {f:<11} not comparable — the {blind} records no {f}")
            continue
        d = new["totals"][f] - base["totals"][f]
        b = base["totals"][f]
        pct = f"{d / b * 100:+.1f}%" if b else "n/a (baseline 0)"
        partial = ""
        if new["coverage"][f] < new["measured"] or base["coverage"][f] < base["measured"]:
            partial = f"  (partial: {new['coverage'][f]}/{new['measured']} vs {base['coverage'][f]}/{base['measured']})"
        print(f"  {f:<11} {d:>+12,} {UNITS[f]:<6} {pct}{partial}")
    n_new, n_base = sum(new["escalations"].values()), sum(base["escalations"].values())
    if new["routes"] or base["routes"] or n_new or n_base:
        d = n_new - n_base
        pct = f"{d / n_base * 100:+.1f}%" if n_base else "n/a (baseline 0)"
        print(f"  {'escalations':<11} {d:>+12,} {'events':<6} {pct}")
    if new["unmeasured"] or base["unmeasured"]:
        print("  NOTE: unmeasured transitions exist on at least one side — the delta covers")
        print("        only transitions that carry a cost object. Do not read it as complete.")
PY
