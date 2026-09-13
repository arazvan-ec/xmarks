#!/usr/bin/env bash
# flywheel — CI gate (P35): a session loads the body of every skill it invokes,
# so each `skills/*/SKILL.md` is a cost paid in full at every invocation. P24
# governs the descriptions, which are all paid together and so share one total;
# a body is paid alone, so the invariant here is a PER-SKILL ceiling. Detail
# belongs in `skills/<name>/references/*.md`, cited from the step that needs it
# and loaded only when that step is reached.
#
# Also fails on a citation that does not resolve: a body pointing at a reference
# that was never written is worse than the prose it replaced, because the model
# proceeds silently without the rule.
#
# Usage: check-invocation-budget.sh   (run from the repo root)
#   FW_INVOCATION_BUDGET=<n>      override the committed ceiling (tests, probes)
#   SKIP_INVOCATION_BUDGET=1      skip with a logged notice, never silently
#
# Exit: 0 OK · 1 over the ceiling or a dangling citation · 2 unusable input

set -euo pipefail

if [ "${SKIP_INVOCATION_BUDGET:-0}" = "1" ]; then
  echo "invocation-budget: SKIPPED via SKIP_INVOCATION_BUDGET=1"
  exit 0
fi

python3 - "${FW_INVOCATION_BUDGET:-}" <<'PY'
import glob, os, re, sys

override = sys.argv[1] if len(sys.argv) > 1 else ""
BUDGET_FILE = "scripts/invocation-budget.txt"

def die(msg, code=2):
    print(f"invocation-budget: {msg}", file=sys.stderr)
    sys.exit(code)

# The ceiling is policy, not code: it lives in its own committed file so
# retuning it is a one-line reviewable diff that does not drag the script (and
# therefore its paired test) along with it.
if override:
    raw, source = override, "FW_INVOCATION_BUDGET"
elif os.path.isfile(BUDGET_FILE):
    raw, source = open(BUDGET_FILE).read().strip(), BUDGET_FILE
else:
    die(f"no {BUDGET_FILE} and no FW_INVOCATION_BUDGET — the budget has no "
        "definition, so nothing can be judged")

if not re.fullmatch(r"[0-9]+", raw):
    die(f"budget from {source} is not a number: {raw!r}. A coerced budget is a "
        "budget nobody set")
budget = int(raw)

files = sorted(glob.glob("skills/*/SKILL.md"))
if not files:
    die("no skills/*/SKILL.md found — run me from the repo root")

# Any references/ path, however it is written: repo-relative (skills/<n>/…) or
# bare (references/…), resolved against the citing skill's own directory.
CITE_RE = re.compile(r"(?:skills/[A-Za-z0-9._-]+/)?references/[A-Za-z0-9._/-]+\.md")
FRONTMATTER_RE = re.compile(r"\A---\r?\n.*?\r?\n---\r?\n", re.S)

rows, hollow, dangling = [], [], []
for path in files:
    name = os.path.basename(os.path.dirname(path))
    blob = open(path, "rb").read()
    size = len(blob)
    text = blob.decode("utf-8", "replace")

    # An empty body must never read as the cheapest skill in the tree.
    if not FRONTMATTER_RE.sub("", text).strip():
        hollow.append(name)

    for cite in CITE_RE.findall(text):
        target = cite if cite.startswith("skills/") else os.path.join("skills", name, cite)
        if not os.path.isfile(target):
            dangling.append((name, cite))

    rows.append((size, name))

rows.sort(key=lambda r: (-r[0], r[1]))
over = [(s, n) for s, n in rows if s > budget]

width = max(len(n) for _, n in rows)
for size, name in rows:
    mark = "  OVER" if size > budget else ""
    print(f"  {name:<{width}}  {size:>6}{mark}")

if hollow:
    die("body is empty (frontmatter only), which would count as the cheapest "
        "skill in the tree: " + ", ".join(sorted(hollow)))

if dangling:
    for name, cite in dangling:
        print(f"invocation-budget: {name} cites {cite}, which does not exist",
              file=sys.stderr)
    die(f"{len(dangling)} unresolved references/ citation(s) — a body that cites "
        "a file nobody wrote loses the rule silently", code=1)

if over:
    die(f"{len(over)} skill(s) over the {budget} B ceiling: "
        + ", ".join(f"{n} ({s})" for s, n in over)
        + ". Move step-scoped detail into skills/<name>/references/ and cite it "
          "from the step that needs it", code=1)

worst_size, worst_name = rows[0]
print(f"invocation-budget: OK — worst case {worst_name} at {worst_size}/{budget} B "
      f"across {len(rows)} skills")
PY
