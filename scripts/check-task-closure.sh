#!/usr/bin/env bash
# flywheel — CI gate: the `check:` a plan task already carries is EXECUTED.
#
# Every plan task is required to have one — plan-route.sh rejects a plan
# otherwise ("a route without a pass/fail check is not a task") — and until this
# gate, that field was linted for PRESENCE and never run. So "T4 is done" was a
# model reading its own work, over a field that in most checks already begins
# with a runnable command. This gate turns the field into an exit code.
#
# Verdicts, and they never collapse into one another:
#   PASS       — a command was extracted, matched the allowlist, ran, exited 0.
#   FAIL       — the same, and it exited non-zero.
#   PENDING    — the cycle keeps a ledger and this task has no transition line
#                in it, so it has not run. Reported, never graded, never failed:
#                the loop commits a plan at its approval gate, BEFORE the work,
#                and grading then would report "not started" as "broken". A
#                cycle with no run directory keeps no ledger to be absent from,
#                so its tasks are graded as normal rather than going ungraded.
#                check-telemetry.sh owns failing a spec that keeps no ledger and
#                check-route-honored.sh owns failing a task that never ran, so
#                nothing is lost by not failing here.
#   UNRUNNABLE — the check could not be run: no backticked span matched
#                scripts/task-closure-allow.txt, or the command it names is not
#                installed here (a property of the machine, not of the task):
#                a prose-only check, or a command outside the boundary. Reported
#                and counted, NEVER executed and never read as green. Reporting
#                absence as honored is the mistake check-route-honored.sh names.
#
# WHAT IT EXECUTES, and why that is safe: only spans matching the allowlist file,
# which admits this repo's own test/gate scripts and nothing that can be turned
# into arbitrary shell. A plan is repo content a PR can write, so running `bash -c`
# over any backticked span would hand /flywheel:verify the exposure gate.sh's
# trust store exists to close. The allowlist keeps it at what CI already runs.
#
# CUTOFF (P18, P48): a plan added before FLYWHEEL_TASK_CLOSURE_FROM is corpus.
# Its checks are reported and never fail the gate, and nothing may be rewritten
# to buy a green. The default sits just before this gate's own cycle, so the
# first plan it grades is the one that shipped it.
#
# WHAT IT DOES NOT GRADE: the prose around the command. A check reading
# "`bash t.sh` fails on the new arms" is graded on t.sh's exit code, not on the
# word "fails" — a red-first expectation is transitional, and a `check:` written
# after the cutoff states the condition that holds AT CLOSE.
#
# Self-reference is refused, not merely bounded: a `check:` naming this gate
# made it sweep every plan in the tree from inside one task and time out. It is
# reported UNRUNNABLE like any other command it will not run. A test that runs
# this gate against fixture plans is still fine — that is depth 2 over trivial
# commands, which is what the arms do.
#
# The plan is parsed by plan-route.sh --json, never here: two readers of one
# format is how the two drift.
#
# Usage: check-task-closure.sh [repo-root | plan.md]
#   SKIP_TASK_CLOSURE=<reason>      skip with a logged notice, never silently
#   FLYWHEEL_TASK_CLOSURE_FROM      move the cutoff (ISO 8601)
#   FLYWHEEL_TASK_CLOSURE_TIMEOUT   per-check seconds (default 300)
#
# Exit: 0 ok (PENDING included) · 1 a FAIL, or an UNRUNNABLE check after the cutoff
#         · 2 unusable input (no python3, or a plan the linter rejects)

set -uo pipefail

if [ -n "${SKIP_TASK_CLOSURE:-}" ]; then
  echo "task-closure: SKIPPED via SKIP_TASK_CLOSURE=${SKIP_TASK_CLOSURE}"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "task-closure: no python3" >&2; exit 2; }

TARGET="${1:-$(pwd)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FW_CLOSURE_FROM="$(python3 "${HERE}/fw_cutoffs.py" task-closure FLYWHEEL_TASK_CLOSURE_FROM)" || exit 2
[ -n "${FW_CLOSURE_FROM}" ] || { echo "task-closure: empty cutoff — an empty cut forgives the whole corpus" >&2; exit 2; }
FLYWHEEL_TASK_CLOSURE_FROM="${FW_CLOSURE_FROM}" \
FLYWHEEL_TASK_CLOSURE_TIMEOUT="${FLYWHEEL_TASK_CLOSURE_TIMEOUT:-300}" \
TC_TARGET="${TARGET}" TC_HERE="${HERE}" python3 - <<'PY'
import glob, json, os, re, shlex, subprocess, sys

sys.path.insert(0, os.environ["TC_HERE"])
from fw_tasks import task_ids  # one reader, shared with check-route-honored.sh
from fw_cutoffs import binds  # instants, not strings: one parser for every gate

target = os.environ["TC_TARGET"]
here = os.environ["TC_HERE"]
cutoff = os.environ["FLYWHEEL_TASK_CLOSURE_FROM"]
timeout = int(os.environ["FLYWHEEL_TASK_CLOSURE_TIMEOUT"])
linter = os.path.join(here, "plan-route.sh")

if target.endswith(".plan.md"):
    plans = [target]
    # specs/ -> flywheel/ -> .claude/ -> the repo root. A fourth level lands in
    # the repo's PARENT, where nothing a check cites resolves and every task
    # reports exit 127 — a failure that reads as the code being broken.
    root = os.path.abspath(os.path.join(os.path.dirname(target), "..", "..", ".."))
else:
    root = os.path.abspath(target)
    plans = sorted(glob.glob(os.path.join(root, ".claude/flywheel/specs/*.plan.md")))

allow_file = os.path.join(here, "task-closure-allow.txt")
patterns = []
try:
    with open(allow_file) as fh:
        for line in fh:
            line = line.strip()
            if line and not line.startswith("#"):
                patterns.append(re.compile(line + r"\Z"))
except OSError:
    print(f"task-closure: cannot read {allow_file}", file=sys.stderr)
    sys.exit(2)

SPAN = re.compile(r"`([^`]+)`")
# An allowlisted PREFIX is not an allowlisted COMMAND. `bash scripts/test-ok.sh
# && touch PWNED` matches any pattern ending in an optional argument tail, and a
# shell would then run both halves — the allowlist would be buying execution for
# whatever follows it. Spans carrying an operator are refused before the
# allowlist is consulted, and what survives is run as argv with no shell at all,
# so neither layer alone is load-bearing.
SHELL_META = re.compile(r"[&;|`$()<>\\\n\r]")

def runnable(span):
    """The argv to execute, or None when the span is not a single plain command."""
    if SHELL_META.search(span) or not any(p.match(span) for p in patterns):
        return None
    # A check citing this gate makes it sweep the whole corpus from inside one
    # task, which blew the per-check timeout the first time a plan tried it.
    # The claim such a check wants to make is about ANOTHER gate going quiet;
    # say that instead.
    # Anchored on a path boundary: `test-check-task-closure.sh` CONTAINS this
    # name and is a perfectly good thing to run, which a substring match got
    # wrong on two real plans.
    if re.search(r"(^|[\s/])check-task-closure\.sh\b", span):
        return None
    try:
        argv = shlex.split(span)
    except ValueError:
        return None
    return argv or None

def added(path):
    """ISO date the plan entered git, or '' when it is untracked (i.e. new)."""
    try:
        out = subprocess.run(["git", "-C", root, "log", "--diff-filter=A",
                              "--format=%aI", "-1", "--", path],
                             capture_output=True, text=True, timeout=30)
        return out.stdout.strip()
    except Exception:
        return ""

def recorded_tasks(slug):
    """-> the task ids this cycle's ledger has a line for, or None when the
    cycle keeps no ledger at all.

    The distinction is the whole rule. A cycle WITH a run directory is
    instrumented, so a task with no line has not run and grading its check
    would report "not started" as "broken" — which is what a plan committed at
    its approval gate, before any work, looks like. A cycle with NO run
    directory keeps no ledger to be absent from, so every task is graded as
    before rather than silently going ungraded."""
    d = os.path.join(root, ".claude", "flywheel", "runs", slug)
    if not os.path.isdir(d):
        return None
    ids = set()
    for f in sorted(glob.glob(os.path.join(d, "*.jsonl"))):
        with open(f) as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    ids |= task_ids(json.loads(line).get("task"))
                except (ValueError, AttributeError):
                    continue
    return ids

if not plans:
    print("task-closure: no plans under .claude/flywheel/specs/ — nothing to close")
    sys.exit(0)

failures, totals = [], {"PASS": 0, "FAIL": 0, "PENDING": 0, "UNRUNNABLE": 0}
graded_plans = 0

for plan in plans:
    # The cutoff is read BEFORE the linter, because it decides what an
    # unlintable plan means: corpus predating the pinned task format is a debt
    # to name, and failing on it would make this gate permanently red on the
    # very trees it shipped into.
    when = added(plan)
    corpus = bool(when) and not binds(when, cutoff)
    rel = os.path.relpath(plan, root)
    try:
        r = subprocess.run(["bash", linter, "--json", plan],
                           capture_output=True, text=True, timeout=60)
    except Exception as e:
        print(f"task-closure: cannot run the plan linter on {plan}: {e}", file=sys.stderr)
        sys.exit(2)
    if r.returncode != 0:
        if corpus:
            print(f"task-closure: {rel}  [UNLINTABLE pre-cutoff corpus — skipped]")
            continue
        print(f"task-closure: {rel}: the plan linter rejects this plan, so its tasks "
              f"cannot be graded:\n{r.stderr.strip()}", file=sys.stderr)
        sys.exit(2)
    tasks = json.loads(r.stdout)["tasks"]

    graded_plans += 1
    print(f"task-closure: {rel}" + ("  [pre-cutoff corpus — reported, never failed]" if corpus else ""))

    ran = recorded_tasks(os.path.basename(plan)[: -len(".plan.md")])
    rows = {"PASS": 0, "FAIL": 0, "PENDING": 0, "UNRUNNABLE": 0}
    for t in tasks:
        if ran is not None and t["id"] not in ran:
            print(f"  {t['id']:<4} {'PENDING':<10} no transition line — not started")
            rows["PENDING"] += 1
            totals["PENDING"] += 1
            continue
        cmds = [(s, a) for s in SPAN.findall(t.get("check", ""))
                for a in [runnable(s)] if a]
        if not cmds:
            verdict, detail = "UNRUNNABLE", "no allowlisted command in its check"
        else:
            verdict, detail = "PASS", " + ".join(c for c, _ in cmds)
            for c, argv in cmds:
                try:
                    # The marker lets a cited `scripts/sweep.sh` (P60) skip
                    # this gate rather than re-grade every plan inside one check.
                    p = subprocess.run(argv, cwd=root, capture_output=True,
                                       text=True, timeout=timeout,
                                       env={**os.environ, "FW_TASK_CLOSURE_ACTIVE": "1"})
                    ok = p.returncode == 0
                except subprocess.TimeoutExpired:
                    ok, p = False, None
                    detail = f"{c} — timed out after {timeout}s"
                except OSError as e:
                    # Whether a tool is installed is a property of the machine,
                    # not of the task, so this is "could not verify", never a
                    # red task. Uncaught it is worse than either: argv raises
                    # where `bash -c` returned 127, and the traceback aborted
                    # the whole run, leaving every later plan ungraded.
                    verdict = "UNRUNNABLE"
                    detail = f"{c} — not available on this machine ({e.strerror})"
                    break
                if not ok:
                    verdict = "FAIL"
                    if p is not None:
                        detail = f"{c} — exit {p.returncode}"
                    break
        # One row per task, always: rows equal tasks, or a dropped item is
        # invisible exactly where this gate is supposed to see it.
        print(f"  {t['id']:<4} {verdict:<10} {detail}")
        rows[verdict] += 1
        totals[verdict] += 1
        if not corpus and verdict != "PASS":
            failures.append(f"{rel} {t['id']}: {verdict} — {detail}")

    named = ", ".join(f"{n} {k}" for k, n in rows.items() if n)
    print(f"  {len(tasks)} task(s): {named}")

summary = ", ".join(f"{n} {k}" for k, n in totals.items() if n)
print(f"task-closure: {graded_plans} plan(s), {summary}")

if failures:
    print("task-closure: a task is not closed:", file=sys.stderr)
    for f in failures:
        print(f"  {f}", file=sys.stderr)
    sys.exit(1)
sys.exit(0)
PY
