#!/usr/bin/env bash
# flywheel — PreToolUse hook on Bash (P21): pre-approve loop-advancing git.
#
# P20 (write-allow.sh) taught the harness that the plan approval covers
# persisting flywheel's state; this hook extends the same contract to the
# commands the loop runs to advance its OWN branch after that approval:
# `git add`, `git commit`, `git stash` (push/pop/list), and a force-free
# `git push` to the CURRENT, non-default branch on origin — the last two
# checked live against the repo, which is what a static permission rule
# cannot express. Everything else falls through to the normal prompt.
#
# Contract: ALLOW-ONLY and fail-open — never denies, never asks, never blocks.
# The grant applies to exactly ONE plain command: any shell metacharacter
# outside single quotes (chaining, pipes, redirects, substitution, escapes)
# falls through, so `git commit -m "x" && rm -rf /` is never matched by the
# `git commit` grant. Global git flags that relocate the repo or inject
# config (`-C`, `-c`, `--git-dir`, `--work-tree`, …) also fall through: the
# subcommand must be git's first argument. Force pushes, pushes to the
# default branch, other remotes, refspecs (`src:dst`), and every git verb
# not listed above are out of scope by construction. The harness still
# evaluates the owner's explicit deny/ask rules AFTER a hook allow, so this
# can never override a rule the owner wrote.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

INPUT="$(cat 2>/dev/null)"

# Cheap pre-filter: every grant below is a git command — skip the python
# spawn for the rest. A miss only means the normal permission prompt.
case "${INPUT}" in *git*) : ;; *) exit 0 ;; esac

command -v python3 >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

FW_PROJECT_DIR="${PROJECT_DIR}" FW_HOOK_INPUT="${INPUT}" python3 - <<'PY' 2>/dev/null
import json, os, shlex, subprocess, sys

def out(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)

try:
    payload = json.loads(os.environ.get("FW_HOOK_INPUT", "") or "{}")
except Exception:
    sys.exit(0)
if payload.get("tool_name", "Bash") != "Bash":
    sys.exit(0)
cmd = payload.get("tool_input", {}).get("command", "")
if not isinstance(cmd, str) or not cmd.strip():
    sys.exit(0)

# ONE plain command only. Walk the string tracking quote state: single quotes
# are fully literal; inside double quotes `$`, backtick and backslash still
# expand, so they disqualify; outside quotes any shell metacharacter
# (chaining, pipes, redirects, substitution, globs, escapes, newlines)
# disqualifies. Unterminated quotes disqualify. Conservative by design —
# a false negative is just the ordinary prompt.
def is_plain(s):
    in_s = in_d = False
    for c in s:
        if in_s:
            if c == "'":
                in_s = False
        elif in_d:
            if c == '"':
                in_d = False
            elif c in '$`\\':
                return False
        else:
            if c == "'":
                in_s = True
            elif c == '"':
                in_d = True
            elif c in ';&|<>`$\\\n(){}*?~!#':
                return False
    return not (in_s or in_d)

if not is_plain(cmd):
    sys.exit(0)

try:
    argv = shlex.split(cmd)
except ValueError:
    sys.exit(0)
# The subcommand must be git's FIRST argument — this excludes every global
# flag (-C/-c/--git-dir/--work-tree/--exec-path/…) in one stroke.
if len(argv) < 2 or argv[0] != "git":
    sys.exit(0)
sub, rest = argv[1], argv[2:]

# Scope: the session must be inside the project this flywheel governs.
project = os.path.realpath(os.environ["FW_PROJECT_DIR"])
cwd = os.path.realpath(payload.get("cwd") or project)
if cwd != project and not cwd.startswith(project + os.sep):
    sys.exit(0)

def git(*args):
    r = subprocess.run(("git", *args), cwd=cwd, capture_output=True,
                       text=True, timeout=5)
    return r.stdout.strip() if r.returncode == 0 else ""

if sub == "add" or sub == "commit":
    out(f"flywheel: git {sub} advances the loop's own branch — covered by the plan approval")

if sub == "stash":
    # bare `git stash` == `git stash push`; drop/clear/apply stay prompted
    if not rest or rest[0] in ("push", "pop", "list"):
        out("flywheel: git stash push/pop/list is a bounded, reversible revert — covered by the plan approval")
    sys.exit(0)

if sub == "push":
    positional, ok_flags = [], {"-u", "--set-upstream"}
    for a in rest:
        if a.startswith("-"):
            if a not in ok_flags:
                sys.exit(0)  # any force/delete/mirror/all/tags/… flag: no grant
        else:
            positional.append(a)
    if len(positional) != 2:
        sys.exit(0)  # explicit `origin <branch>` form only
    remote, ref = positional
    if remote != "origin" or ":" in ref or ref.startswith("+"):
        sys.exit(0)
    try:
        current = git("branch", "--show-current")
        if not current or ref != current:
            sys.exit(0)
        head = git("symbolic-ref", "refs/remotes/origin/HEAD")  # e.g. refs/remotes/origin/main
        defaults = {head.rsplit("/", 1)[-1]} if head else {"main", "master"}
        if current in defaults:
            sys.exit(0)
    except Exception:
        sys.exit(0)
    out(f"flywheel: force-free git push of the current feature branch ({current}) to origin — covered by the plan approval")

sys.exit(0)
PY

exit 0
