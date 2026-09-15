#!/usr/bin/env bash
# flywheel — CI gate (P42): a cycle that ships without telemetry must not be able
# to do so quietly.
#
# The duty is fail-open by design — a cycle must never die over a reporting line
# — and for ten cycles nothing noticed that it was never discharged at all. This
# is the half that was missing: fail-open in the skill, visible afterwards here.
#
# Two checks:
#   CONFORMANCE — every runs/**/*.jsonl line carries the contract's keys and no
#                 `tokens` field (P18: a session cannot observe its own usage).
#   COVERAGE    — every spec slug has telemetry, unless scripts/telemetry-baseline.txt
#                 exempts it WITH A REASON. The baseline lists what is exempt, not
#                 what is expected: a new spec is covered by default, and silencing
#                 one is a line in the diff.
#
# Usage: check-telemetry.sh [repo-root]
#   SKIP_TELEMETRY_CHECK=1        skip with a logged notice, never silently
#   FLYWHEEL_TELEMETRY_BASELINE   override the baseline path
#
# Exit: 0 ok · 1 non-conforming telemetry or an unexplained gap · 2 unusable
#         input (no specs dir, no python3, or a baseline entry with no reason)

set -uo pipefail

if [ "${SKIP_TELEMETRY_CHECK:-0}" = "1" ]; then
  echo "telemetry: SKIPPED via SKIP_TELEMETRY_CHECK=1"
  exit 0
fi

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SPECS="${ROOT}/.claude/flywheel/specs"
RUNS="${ROOT}/.claude/flywheel/runs"
BASELINE="${FLYWHEEL_TELEMETRY_BASELINE:-${ROOT}/scripts/telemetry-baseline.txt}"

[ -d "${SPECS}" ] || { echo "telemetry: no ${SPECS} — nothing to check" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "telemetry: no python3" >&2; exit 2; }

FW_SPECS="${SPECS}" FW_RUNS="${RUNS}" FW_BASELINE="${BASELINE}" python3 - <<'PY'
import json, os, sys

specs, runs, baseline = os.environ["FW_SPECS"], os.environ["FW_RUNS"], os.environ["FW_BASELINE"]

exempt = {}
if os.path.isfile(baseline):
    for n, raw in enumerate(open(baseline), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split(None, 1)
        if len(parts) < 2 or not parts[1].strip():
            print(f"telemetry: {baseline}:{n}: '{parts[0]}' is exempted with no reason."
                  f"\n           An exemption is a debt; the reason is what makes it payable.",
                  file=sys.stderr)
            sys.exit(2)
        exempt[parts[0]] = parts[1].strip()

slugs = sorted(f[:-3] for f in os.listdir(specs)
               if f.endswith(".md") and not f.endswith(".plan.md"))

# A baselined slug's file predates the contract, so its shape is part of the
# debt, not a new violation: reported, never fatal. The tokens ban is the one
# rule with no exemption — P18 is about what may enter the ledger at all.
bad, notices, covered = [], [], set()
for dirpath, _, files in os.walk(runs):
    for f in files:
        if not f.endswith(".jsonl"):
            continue
        path = os.path.join(dirpath, f)
        slug = os.path.relpath(dirpath, runs)
        shape = bad if slug not in exempt else notices
        ok_lines = 0
        for n, raw in enumerate(open(path), 1):
            raw = raw.strip()
            if not raw:
                continue
            where = f"{os.path.relpath(path, os.path.dirname(runs))}:{n}"
            try:
                rec = json.loads(raw)
            except ValueError:
                shape.append(f"{where}: not JSON")
                continue
            if not isinstance(rec, dict):
                shape.append(f"{where}: not a JSON object")
                continue
            # The tokens ban is checked FIRST and never routed through `shape`:
            # a malformed line on a baselined slug would otherwise carry one past
            # the exemption, which is the opposite of the stated rule.
            if "tokens" in rec or (isinstance(rec.get("cost"), dict) and "tokens" in rec["cost"]):
                bad.append(f"{where}: carries a tokens field — banned (P18), and no"
                           " baseline entry exempts it")
                continue
            problem = None
            for k in ("ts", "state"):
                if not isinstance(rec.get(k), str) or not rec[k].strip():
                    problem = f"{k} is missing or not a non-empty string"
                    break
            # Identification: pillar 1 names a task, pillar 2 a Rule phase. One or
            # the other, or the line cannot say which transition it is.
            if problem is None and not any(
                    isinstance(rec.get(k), str) and rec[k].strip() for k in ("task", "phase")):
                problem = "names neither a task nor a phase"
            cost = rec.get("cost")
            if problem is None:
                if not isinstance(cost, dict):
                    problem = "has no cost object"
                elif not any(isinstance(v, (int, float)) and not isinstance(v, bool)
                             for v in cost.values()):
                    problem = "cost carries no numeric proxy"
            if problem:
                shape.append(f"{where}: {problem}")
                continue
            ok_lines += 1
        if ok_lines:
            covered.add(slug)

gaps = [s for s in slugs if s not in covered and s not in exempt]

for b in bad:
    print(f"telemetry: {b}")
for n in notices:
    print(f"telemetry: note — {n} (baselined; its shape is part of the debt)")
for g in gaps:
    print(f"telemetry: {g} has no conforming telemetry and no baseline entry."
          f"\n           Either the cycle wrote none, or the debt needs a reason in"
          f" {os.path.basename(baseline)}.")

n_ex = sum(1 for s in slugs if s in exempt)
print(f"telemetry: {len(covered & set(slugs))} of {len(slugs)} specs carry telemetry;"
      f" {n_ex} exempt via the baseline — each one a cycle that shipped unmeasured.")

sys.exit(1 if (bad or gaps) else 0)
PY
