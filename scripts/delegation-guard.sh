#!/usr/bin/env bash
# flywheel — PreToolUse hook: never open delegated work blind.
#
# A plan routes every task to a `<model>/<effort>` tier and `route-tiers.txt`
# (next to this script) is the authority for what a tier is. Opening a child
# session WITHOUT passing `model` silently inherits the caller's: on
# 2026-09-13 a coordinator on opus fanned out five jobs the plan routed to
# sonnet, and nobody saw it until the cost was asked for out loud. A subagent
# is different when its `subagent_type` names an agents/*.md whose frontmatter
# pins `model:`/`effort:` (every agent in this repo does, P37): the tier is
# already decided there, so TIER stands aside for exactly those pinned fields
# — it still asks when the definition is missing, unreadable, or leaves a
# field unpinned.
#
# Four families of check. The first three are how delegating badly costs, and
# only one of them is visible:
#   TIER    — the wrong model is paid in the bill.
#   CONTEXT — the child burns its window rediscovering what was already known.
#             It shows up in no metric; it just looks slow.
#   FANOUT  — the child that should not exist. Two shapes: the DUPLICATE
#             (delegating something that already has a live child) and the WIDTH
#             (N sessions drain the same quota N times faster).
#   REVIEW  — a delegated review that skips the start comment of
#             skills/review/references/delegated-review.md (P57).
#
# Contract: this hook NEVER decides for you and never denies. It returns `ask`,
# so the decision passes through a confirmation instead of an invisible default.
# Inheriting, pasting a contract and fanning out wide are all legitimate when
# deliberate — what must not happen is doing them without having decided.
#
# Fail-open everywhere else: no python3, unreadable JSON or any other tool and
# it prints nothing and exits 0 (the normal permission flow).
#
# The fanout state is written by `delegation-record.sh` on PostToolUse — only
# children that were actually created count, never proposals that were denied.

INPUT="$(cat 2>/dev/null)"

# Cheap pre-filter: this hook only looks at two tools.
case "${INPUT}" in
  *create_session*|*'"Agent"'*|*'"Task"'*) : ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

FW_TIERS="${SCRIPT_DIR}/route-tiers.txt" \
FW_SCRIPT_DIR="${SCRIPT_DIR}" \
FW_PROJECT_DIR="${PROJECT_DIR}" \
FW_HOOK_INPUT="${INPUT}" python3 - <<'PY' 2>/dev/null
import hashlib, json, os, re, sys, tempfile

try:
    payload = json.loads(os.environ.get("FW_HOOK_INPUT", "") or "{}")
except Exception:
    sys.exit(0)

tool = payload.get("tool_name") or ""
is_session = tool.endswith("create_session")
is_subagent = tool in ("Agent", "Task")
if not (is_session or is_subagent):
    sys.exit(0)

tool_input = payload.get("tool_input") or {}
if not isinstance(tool_input, dict):
    sys.exit(0)

# --- tier ---------------------------------------------------------------
# An empty `model` counts as absent: it would inherit just the same.
model = (tool_input.get("model") or "").strip()

# A subagent_type may name an agent definition that already pins its own
# model/effort in frontmatter — search order matches how the plugin is found
# at runtime: vendored install path first, then the plugin's own agents/ dir
# beside this script. Fails open: no type, no file, unreadable, no field ⇒
# that field stays undecided exactly as before.
agent_model = agent_effort = ""
subagent_type = str(tool_input.get("subagent_type") or "").strip() if is_subagent else ""
if subagent_type:
    frontmatter = ""
    for candidate in (
        os.path.join(os.environ.get("FW_PROJECT_DIR", ""), ".claude", "agents", subagent_type + ".md"),
        os.path.join(os.environ.get("FW_SCRIPT_DIR", ""), "..", "agents", subagent_type + ".md"),
    ):
        try:
            with open(candidate, encoding="utf-8") as fh:
                frontmatter = fh.read()
            break
        except Exception:
            continue
    fm = re.match(r"^---\n(.*?)\n---", frontmatter, re.S)
    if fm:
        mm = re.search(r"(?m)^model:\s*(\S.*)$", fm.group(1))
        agent_model = mm.group(1).strip() if mm else ""
        me = re.search(r"(?m)^effort:\s*(\S.*)$", fm.group(1))
        agent_effort = me.group(1).strip() if me else ""

# Effort is a parameter of NEITHER tool. It travels in the text that does reach
# the child, which then runs `/model <tier> <effort>`. Deliberately heuristic:
# naming the tier or the route column is enough for the guard to stand aside.
text = " ".join(
    str(tool_input.get(k) or "")
    for k in ("prompt", "append_system_prompt", "description")
).lower()
has_effort = any(w in text for w in ("effort", "route", "/model", "tier"))

missing = []
if not model and not agent_model:
    missing.append("`model`")
if not has_effort and not agent_effort:
    missing.append("the effort")

# --- context ------------------------------------------------------------
# Only meaningful when work is actually being sent: a session with no prompt is
# a blank one the owner will drive by hand.
prompt = str(tool_input.get("prompt") or "")
warnings = []
if prompt.strip():
    # An anchor is a SOURCE to read — an issue, a URL, a path — not a paraphrase.
    # Without one the child guesses, and a session launched through the API has
    # no channel back to ask.
    has_anchor = bool(
        re.search(r"#\d+", prompt)
        or "http" in prompt
        or re.search(r"[\w./-]+\.(md|js|json|sh|py|ts|tsx|go|rs|rb|java)\b", prompt)
        or re.search(r"\b(src|test|tests|docs|lib|app)/", prompt)
    )
    if not has_anchor:
        warnings.append((
            "context",
            "carries no ANCHOR (an issue, a URL or a path): with no source to "
            "read, the child guesses — and a launched session has no channel "
            "back to ask",
        ))
    # A pasted copy of the contract diverges the moment the source is edited.
    if len(prompt) > 8000:
        warnings.append((
            "context",
            "is %d characters: that looks like the contract PASTED rather than "
            "a pointer to it — and a copy diverges as soon as the source is "
            "edited" % len(prompt),
        ))

# --- review (P57) --------------------------------------------------------
# A delegated review that posts nothing looks the same whether it found
# nothing, could not post, or is still running (PR #95). The template makes
# the child announce itself on the PR first; its marker is what we look for.
low = prompt.lower()
is_review = ("/code-review" in low or "/flywheel:review" in low
             or ("review" in low and re.search(r"(#\d+|\bpr\s*\d+|/pull/\d+)", low)))
if is_review and "fw-review-start" not in low:
    warnings.append((
        "review",
        "asks for a review but does not follow skills/review/references/"
        "delegated-review.md: without its start comment (marker "
        "`fw-review-start`) a child that posts nothing reads the same as one "
        "that found nothing — on PR #95 that cost two relaunches",
    ))

# --- fanout -------------------------------------------------------------
WIDTH_THRESHOLD = 4   # ask from the fourth child of this session onwards

# Same derivation as `delegation-record.sh`: if the two ever disagreed, the
# guard would read a file nobody writes and would never warn.
parent = str(payload.get("session_id") or "no-session")
state_path = os.path.join(
    tempfile.gettempdir(),
    "flywheel-delegation-" + hashlib.sha256(parent.encode("utf-8")).hexdigest()[:16] + ".jsonl",
)

ledger = []
if os.path.exists(state_path):
    try:
        with open(state_path, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line:
                    ledger.append(json.loads(line))
    except Exception:
        ledger = []

anchors_now = set(re.findall(r"#(\d+)", prompt))
anchors_before = set()
for row in ledger:
    for a in (row.get("anchors") or []):
        anchors_before.add(str(a))

repeated = sorted(anchors_now & anchors_before, key=int)
if repeated:
    warnings.append((
        "fanout",
        "you already opened a child in this session for %s. If this is a "
        "deliberate RELAUNCH, first check what the previous one left behind "
        "(branch, PR, status comments): on 2026-09-13 a relaunch like this "
        "would have thrown away a finished PR. If it is not, it is duplicated "
        "work" % ", ".join("#" + a for a in repeated),
    ))

if len(ledger) + 1 >= WIDTH_THRESHOLD:
    warnings.append((
        "fanout",
        "this makes %d children opened from this session. N parallel sessions "
        "drain the SAME quota N times faster, and that is invisible until the "
        "limit cuts you off. If the plan's split calls for them, go ahead; if "
        "this is a fan that grew on its own, stop" % (len(ledger) + 1),
    ))

if not missing and not warnings:
    sys.exit(0)

# --- the ask ------------------------------------------------------------
what = "a parallel session" if is_session else "a subagent"
parts = ["You are about to open %s and something is still undecided." % what]

if missing:
    why = (
        "Without `model` the child silently INHERITS this session's — which is "
        "how five jobs routed to sonnet ended up running on opus. "
        if "`model`" in missing else
        "Effort is not a parameter of this tool: unless you tell the child, it "
        "keeps its own default and the plan's `Route` column is not honoured. "
    )
    # Name the tiers from route-tiers.txt itself rather than repeating them: a
    # copy goes stale the moment the ladder is retuned.
    tiers = ""
    try:
        with open(os.environ.get("FW_TIERS", ""), encoding="utf-8") as fh:
            rows = [l.split() for l in fh if l.strip() and not l.lstrip().startswith("#")]
        names = ["%s/%s" % (r[1], r[2]) for r in rows if len(r) >= 3]
        if names:
            tiers = " Tiers on the ladder: " + ", ".join(names) + "."
    except Exception:
        tiers = ""
    parts.append(
        "TIER — you have not chosen %s. %sThe ladder is `scripts/route-tiers.txt`;"
        " `model` is a parameter, effort goes in the child's prompt.%s"
        % (" or ".join(missing), why, tiers)
    )

for family, text_ in warnings:
    if family == "context":
        parts.append("CONTEXT — the prompt %s." % text_)
    elif family == "review":
        parts.append("REVIEW — the prompt %s." % text_)
    else:
        parts.append("FANOUT — %s." % text_)

parts.append(
    "What makes a context the right one, in this order: (1) ANCHOR, the pointer "
    "to its contract — never a copy; (2) DELTA, what changed since that contract "
    "was written and the child cannot know; (3) COLLISIONS, who else is running "
    "and which files are not theirs; (4) TRAPS, what the upstream work already "
    "learned and the child would repeat. All of this is fine when deliberate: "
    "say so and carry on."
)

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": " ".join(parts),
    }
}))
PY

exit 0
