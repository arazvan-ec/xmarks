#!/usr/bin/env bash
# flywheel — CI gate (P35, retargeted by P36): a session loads the body of every
# skill it invokes, so each `skills/*/SKILL.md` is a cost paid in full at every
# invocation. P24 governs the descriptions, which are all paid together and so
# share one total; a body is paid alone, so the invariant here is a PER-SKILL
# ceiling.
#
# P35 measured the body alone, and that number is gameable: moving a hot-path
# rule into `references/` shrinks the body while the same invocation still reads
# the file, so every capped skill got cheaper on paper and more expensive in
# fact. So two numbers are enforced per skill:
#
#   body  — bytes of SKILL.md. Always paid.
#   worst — body + every distinct references/*.md reachable from it, followed
#           transitively. The honest upper bound: every citation taken. It
#           charges a reference the invocation may not read, which is the price
#           of a number that is mechanically knowable — conditionality lives in
#           prose and cannot be measured.
#
# Ceilings live in scripts/invocation-budget.txt (defaults + named per-skill
# exceptions) so retuning policy is a one-line reviewable diff that does not
# drag the script, and therefore its paired test, along with it. One global
# number would hand every skill the slack its worst occupant needs.
#
# Also fails on a citation that does not resolve, in a body or in a reference:
# a pointer at a file nobody wrote is worse than the prose it replaced, because
# the model proceeds silently without the rule.
#
# Usage: check-invocation-budget.sh   (run from the repo root)
#   FW_INVOCATION_BUDGET=<n>      override the default BODY ceiling (tests, probes)
#   FW_INVOCATION_WORST=<n>       override the default WORST ceiling
#   SKIP_INVOCATION_BUDGET=1      skip with a logged notice, never silently
#
# Exit: 0 OK · 1 over a ceiling or a dangling citation · 2 unusable input

set -euo pipefail

if [ "${SKIP_INVOCATION_BUDGET:-0}" = "1" ]; then
  echo "invocation-budget: SKIPPED via SKIP_INVOCATION_BUDGET=1"
  exit 0
fi

python3 - "${FW_INVOCATION_BUDGET:-}" "${FW_INVOCATION_WORST:-}" <<'PY'
import glob, os, re, sys

body_override = sys.argv[1] if len(sys.argv) > 1 else ""
worst_override = sys.argv[2] if len(sys.argv) > 2 else ""
BUDGET_FILE = "scripts/invocation-budget.txt"

def die(msg, code=2):
    # Flush stdout first. The breakdown is printed to stdout, the verdict to
    # stderr, and CI redirects both into one stream: with stdout block-buffered
    # (any environment that does not set PYTHONUNBUFFERED, GitHub's runners
    # among them) the verdict would otherwise land BEFORE the breakdown it
    # refers to. Output a reader has to reorder in their head is a defect, and
    # one that only shows up on someone else's machine.
    sys.stdout.flush()
    print(f"invocation-budget: {msg}", file=sys.stderr)
    sys.exit(code)

NUM = re.compile(r"[0-9]+")
KV = re.compile(r"(body|worst)=([0-9]+)")

defaults, exceptions = {}, {}
if os.path.isfile(BUDGET_FILE):
    lines = [l.split("#", 1)[0].strip() for l in open(BUDGET_FILE)]
    lines = [l for l in lines if l]
    if len(lines) == 1 and NUM.fullmatch(lines[0]):
        die(f"{BUDGET_FILE} holds a bare number ({lines[0]}) — the single-ceiling "
            "format retired with P36. Coercing it would leave the other ceiling "
            "undefined. Write: 'body <n>' and 'worst <n>' defaults, plus "
            "'<skill> body=<n> worst=<n>' exception lines")
    for line in lines:
        tok = line.split()
        if len(tok) == 2 and tok[0] in ("body", "worst") and NUM.fullmatch(tok[1]):
            defaults[tok[0]] = int(tok[1])
            continue
        kv = [KV.fullmatch(t) for t in tok[1:]]
        if len(tok) >= 2 and all(kv):
            exceptions.setdefault(tok[0], {}).update(
                {m.group(1): int(m.group(2)) for m in kv})
            continue
        die(f"{BUDGET_FILE}: cannot parse {line!r}. Expected 'body <n>' / "
            "'worst <n>' defaults and '<skill> body=<n> worst=<n>' exceptions. "
            "A coerced budget is a budget nobody set")

for key, override, env in (("body", body_override, "FW_INVOCATION_BUDGET"),
                           ("worst", worst_override, "FW_INVOCATION_WORST")):
    if override:
        if not NUM.fullmatch(override):
            die(f"{env} is not a number: {override!r}. A coerced budget is a "
                "budget nobody set")
        defaults[key] = int(override)
    elif key not in defaults:
        die(f"no {key} ceiling — {BUDGET_FILE} does not set one and {env} is "
            "unset, so nothing can be judged")

def cap(name, key):
    return exceptions.get(name, {}).get(key, defaults[key])

files = sorted(glob.glob("skills/*/SKILL.md"))
if not files:
    die("no skills/*/SKILL.md found — run me from the repo root")

# Any references/ path, however it is written: repo-relative (skills/<n>/…) or
# bare (references/…), resolved against the citing FILE's own skill directory —
# a bare path inside skills/work/references/x.md means skills/work/references/.
CITE_RE = re.compile(r"(?:skills/[A-Za-z0-9._-]+/)?references/[A-Za-z0-9._/-]+\.md")
FRONTMATTER_RE = re.compile(r"\A---\r?\n.*?\r?\n---\r?\n", re.S)

def owner_of(path, fallback):
    parts = path.split("/")
    return parts[1] if path.startswith("skills/") and len(parts) > 1 else fallback

rows, hollow, dangling = [], [], []
for path in files:
    name = os.path.basename(os.path.dirname(path))
    blob = open(path, "rb").read()
    body = len(blob)
    text = blob.decode("utf-8", "replace")

    # An empty body must never read as the cheapest skill in the tree.
    if not FRONTMATTER_RE.sub("", text).strip():
        hollow.append(name)

    # Every citation followed, each distinct file charged once; `seen` is also
    # the cycle guard, since references may cite each other.
    seen, refs, queue = set(), 0, [(text, name, path)]
    while queue:
        src_text, owner, src = queue.pop()
        for cite in CITE_RE.findall(src_text):
            target = os.path.normpath(
                cite if cite.startswith("skills/") else os.path.join("skills", owner, cite))
            if target in seen:
                continue
            seen.add(target)
            if not os.path.isfile(target):
                dangling.append((name, src, cite))
                continue
            tblob = open(target, "rb").read()
            refs += len(tblob)
            queue.append((tblob.decode("utf-8", "replace"), owner_of(target, owner), target))

    rows.append((name, body, body + refs))

rows.sort(key=lambda r: (-r[2], -r[1], r[0]))
over = []
width = max(len(n) for n, _, _ in rows)
for name, body, worst in rows:
    flags = [k for k, v in (("body", body), ("worst", worst)) if v > cap(name, k)]
    over += [(name, k, body if k == "body" else worst, cap(name, k)) for k in flags]
    mark = "  OVER " + " ".join(flags) if flags else ""
    print(f"  {name:<{width}}  {body:>6}  {worst:>6}{mark}")

if hollow:
    die("body is empty (frontmatter only), which would count as the cheapest "
        "skill in the tree: " + ", ".join(sorted(hollow)))

if dangling:
    for name, src, cite in dangling:
        print(f"invocation-budget: {name} cites {cite} from {src}, which does not exist",
              file=sys.stderr)
    die(f"{len(dangling)} unresolved references/ citation(s) — a file that cites "
        "a file nobody wrote loses the rule silently", code=1)

if over:
    die(f"{len(over)} ceiling(s) breached: "
        + ", ".join(f"{n} {k} {v}/{c}" for n, k, v, c in over)
        + ". Over on body: move step-scoped detail into skills/<name>/references/ "
          "and cite it from the step that needs it. Over on worst: that detail has "
          "to go, not move — worst charges the reference either way", code=1)

wb = max(rows, key=lambda r: r[1])
ww = rows[0]
print(f"invocation-budget: OK — worst body {wb[0]} {wb[1]}/{cap(wb[0], 'body')} B, "
      f"worst total {ww[0]} {ww[2]}/{cap(ww[0], 'worst')} B across {len(rows)} skills")
PY
