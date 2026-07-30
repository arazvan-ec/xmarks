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

FIELDS = ("bytes_out", "tool_calls", "elapsed_s")
UNITS = {"bytes_out": "bytes", "tool_calls": "calls", "elapsed_s": "s"}


def load(path):
    if not os.path.isfile(path):
        return None, f"cannot read {path}: no such file"
    totals = dict.fromkeys(FIELDS, 0)
    measured = unmeasured = skipped = 0
    tokens_seen = 0
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
            measured += 1
    if measured == 0 and unmeasured == 0:
        return None, f"{path}: no transitions found (empty or no usable JSON lines; {skipped} skipped)"
    return {
        "path": path, "totals": totals, "measured": measured,
        "unmeasured": unmeasured, "skipped": skipped, "tokens_seen": tokens_seen,
    }, None


def report(r, label):
    t = r["totals"]
    print(f"{label}: {r['path']}")
    print(f"  transitions: {r['measured']} measured"
          + (f", {r['unmeasured']} UNMEASURED (no cost object — not counted as 0)" if r["unmeasured"] else ""))
    for f in FIELDS:
        print(f"  {f:<11} {t[f]:>12,} {UNITS[f]}")
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
    if new["unmeasured"] or base["unmeasured"]:
        print("  NOTE: unmeasured transitions exist on at least one side — the delta covers")
        print("        only transitions that carry a cost object. Do not read it as complete.")
PY
