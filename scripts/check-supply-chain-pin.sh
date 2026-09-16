#!/usr/bin/env bash
# flywheel — CI gate (P13, B10): the only Critical in the pillar-2 threat model.
#
# install-vendored.sh --auto-update writes a caller workflow into every consuming
# repo. That caller invokes this repo's reusable flywheel-update.yml, which then
# fetches this repo and `bash`es the result under contents:write +
# pull-requests:write, weekly by cron. Anyone who could move what that fetch
# resolves to executed arbitrary bash in every consuming repo's CI, unattended.
#
# THE POINT OF THIS GATE, AND WHY IT IS NOT JUST A `uses:` CHECK.
# Pinning the caller's `uses:` does not close the hole: a pinned reusable
# workflow that still clones a moving branch is just as open, because the clone
# is what gets executed. So the gate asserts BOTH halves, and each one fails on
# its own:
#   A. scripts/install-vendored.sh writes a caller pinned to a full commit SHA,
#      and passes that same SHA as the flywheel_sha input.
#   B. .github/workflows/flywheel-update.yml resolves that input to a specific
#      commit, refuses anything that is not one, and checks it out BEFORE any
#      step executes the fetched tree.
# Delete either half and this must go red naming that half alone. A gate that
# only reads `uses:` passes half B with the hole fully open.
#
# Half A is a source-level check: the SHA is interpolated at install time, so
# what the gate can assert here is that the template pins an interpolation of a
# full-SHA variable rather than a branch, and that the `uses:` and the input come
# from the SAME variable. That the generated file then carries a real 40-hex pair
# is asserted in scripts/test-install-vendored.sh — the two together are the
# claim; neither is it alone.
#
# Usage: check-supply-chain-pin.sh   (run from the repo root)
#   FW_PIN_ROOT=<dir>          check this tree instead of the repo (tests)
#   FW_PIN_ALLOW=<file>        use this allowlist instead of the committed one
#   SKIP_SUPPLY_CHAIN_PIN=1    skip with a logged notice, never silently
#
# Exit: 0 ok · 1 an unpinned or unverified boundary · 2 unusable input
#
# FAIL-CLOSED, against this repo's reflex. Every other flywheel script is
# fail-open because a hook must never kill a session. This is CI, and a reusable
# workflow it cannot read is a workflow it cannot vouch for, so a missing or
# unreadable file is a failure and not a pass.

set -uo pipefail

if [ "${SKIP_SUPPLY_CHAIN_PIN:-0}" = "1" ]; then
  echo "supply-chain-pin: SKIPPED via SKIP_SUPPLY_CHAIN_PIN=1"
  exit 0
fi

ROOT="${FW_PIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ALLOW="${FW_PIN_ALLOW:-${ROOT}/scripts/supply-chain-pin-allow.txt}"

command -v python3 >/dev/null 2>&1 || { echo "supply-chain-pin: no python3" >&2; exit 2; }

FW_ROOT="${ROOT}" FW_ALLOW="${ALLOW}" python3 - <<'PY'
import os, re, sys

root, allow_path = os.environ["FW_ROOT"], os.environ["FW_ALLOW"]
INSTALLER_REL = "scripts/install-vendored.sh"
WORKFLOW_REL = ".github/workflows/flywheel-update.yml"
WORKFLOWS_DIR = ".github/workflows"

problems, notes = [], []

def read(rel):
    """Returns text, or None if it cannot be read. Unreadable is never 'fine'."""
    try:
        with open(os.path.join(root, rel), encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return None

# ---- the allowlist: a debt with a reason on it, and it cannot rot silently ----
allow = {}
if os.path.isfile(allow_path):
    try:
        raw_lines = open(allow_path, encoding="utf-8").readlines()
    except OSError as exc:
        print(f"supply-chain-pin: cannot read {allow_path}: {exc}", file=sys.stderr)
        sys.exit(2)
    for n, raw in enumerate(raw_lines, 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split(None, 2)
        if len(parts) < 3 or not parts[2].strip():
            print(f"supply-chain-pin: {allow_path}:{n}: '{' '.join(parts[:2])}' is exempted"
                  f" with no reason.\n           An exemption is a debt; the reason is what"
                  f" makes it payable.", file=sys.stderr)
            sys.exit(2)
        allow[(parts[0], parts[1])] = parts[2].strip()
used_allow = set()

# =============================================================== half A =====
# The caller template in the installer.
installer = read(INSTALLER_REL)
if installer is None:
    print(f"supply-chain-pin: cannot read {INSTALLER_REL} — refusing to vouch for a"
          f" caller template it cannot see", file=sys.stderr)
    sys.exit(2)

inst_lines = installer.splitlines()
USES_RE = re.compile(r"uses:\s*arazvan-ec/xmarks/\.github/workflows/flywheel-update\.yml@(\S+)")
INTERP_RE = re.compile(r"^\$\{([A-Za-z_]\w*)\}$")

pin_var = None
found_caller = False
for n, line in enumerate(inst_lines, 1):
    m = USES_RE.search(line)
    if not m:
        continue
    found_caller = True
    ref = m.group(1)
    im = INTERP_RE.match(ref)
    if im:
        pin_var = im.group(1)
    else:
        problems.append(
            f"{INSTALLER_REL}:{n}: the caller template pins @{ref} — a branch or tag"
            f" resolves to whatever it points at when the consuming repo's cron fires."
            f" It must interpolate the full commit SHA.")

if not found_caller:
    problems.append(
        f"{INSTALLER_REL}: no caller template found. This gate exists to assert what"
        f" that template pins; with no template to read it must fail rather than"
        f" pass vacuously.")

if pin_var:
    inputs = [(n, mm.group(1)) for n, line in enumerate(inst_lines, 1)
              for mm in [re.search(r"flywheel_sha:\s*(\S+)", line)] if mm]
    if not inputs:
        problems.append(
            f"{INSTALLER_REL}: the caller template pins a commit but passes no"
            f" flywheel_sha input, so the reusable workflow cannot learn which commit"
            f" it was pinned to — no context field carries it (probe, T1).")
    for n, val in inputs:
        if val != "${%s}" % pin_var:
            problems.append(
                f"{INSTALLER_REL}:{n}: flywheel_sha is {val} but the uses: pin is"
                f" ${{{pin_var}}}. These must come from ONE variable; two values are two"
                f" things to keep in sync and one of them will rot.")
    # A short SHA is not a valid `uses:` pin, and the existing SRC_COMMIT is short.
    assign = re.search(r"%s\s*=\s*\"?\$\(([^)]*rev-parse[^)]*)\)" % re.escape(pin_var), installer)
    if not assign:
        problems.append(
            f"{INSTALLER_REL}: cannot find where {pin_var} is computed, so the gate"
            f" cannot tell whether it is a full SHA.")
    elif "--short" in assign.group(1):
        problems.append(
            f"{INSTALLER_REL}: {pin_var} is computed with rev-parse --short; a short"
            f" SHA is not a valid uses: pin.")

# =============================================================== half B =====
# The reusable workflow. Messages here deliberately do NOT echo line contents:
# the step that executes the tree mentions install-vendored.sh, and quoting it
# would make half B's failure read as if half A were also broken. The two halves
# have to be separable in the OUTPUT, not just in the logic.
workflow = read(WORKFLOW_REL)
if workflow is None:
    print(f"supply-chain-pin: cannot read {WORKFLOW_REL} — a reusable workflow this"
          f" gate cannot read is one it cannot vouch for (fail-closed)", file=sys.stderr)
    sys.exit(2)

wf_lines = workflow.splitlines()

def code_only(lines):
    """Comment lines are prose, not behaviour. This file's own header explains the
    clone it removed, and a gate that reads that as a clone would be unfixable."""
    return [(n, l) for n, l in enumerate(lines, 1) if not l.lstrip().startswith("#")]

wf_code = code_only(wf_lines)

clone_lines = [n for n, l in wf_code if re.search(r"\bgit\s+clone\b", l)]
for n in clone_lines:
    problems.append(
        f"{WORKFLOW_REL}:{n}: a clone step resolves a branch at run time, so the tree"
        f" this workflow executes is whatever that branch points at then — not the"
        f" commit the caller pinned. Fetch and check out the pinned commit instead.")

# `git checkout -q --detach "$SHA"` is the shipped form, so flags may sit between.
detach = [n for n, l in wf_code if re.search(r"checkout\s+(?:-\S+\s+)*--detach", l)]
execs = [n for n, l in wf_code if re.search(r"\bbash\s+\"?\$\{?RUNNER_TEMP", l)]

if execs and not detach:
    problems.append(
        f"{WORKFLOW_REL}:{execs[0]}: this step executes the fetched tree under"
        f" contents:write, and no step checks out a pinned commit anywhere in the file.")
elif execs and detach and min(detach) > min(execs):
    problems.append(
        f"{WORKFLOW_REL}:{min(detach)}: the pinned checkout runs after line"
        f" {min(execs)} has already executed the fetched tree. It must come before it.")

wf_code_text = "\n".join(l for _, l in wf_code)
if not re.search(r"\[0-9a-fA-F\]\{40\}|\[0-9a-f\]\{40\}", wf_code_text):
    problems.append(
        f"{WORKFLOW_REL}: nothing validates that flywheel_sha is a full 40-hex commit."
        f" An absent or malformed input must stop the run before anything executes,"
        f" not fall through to a default.")
elif "exit 1" not in wf_code_text:
    problems.append(
        f"{WORKFLOW_REL}: the 40-hex validation never exits non-zero, so it reports"
        f" rather than refuses.")

# ============================================== every uses:, every workflow ==
wf_dir = os.path.join(root, WORKFLOWS_DIR)
if os.path.isdir(wf_dir):
    for name in sorted(os.listdir(wf_dir)):
        if not name.endswith((".yml", ".yaml")):
            continue
        rel = f"{WORKFLOWS_DIR}/{name}"
        text = read(rel)
        if text is None:
            problems.append(f"{rel}: unreadable (fail-closed)")
            continue
        for n, line in enumerate(text.splitlines(), 1):
            # Anchored: `uses:` must be the YAML key, optionally the first key of a
            # list item. Unanchored, this read every mention of `uses:` in a comment
            # or a description string as a reference and demanded a SHA for it.
            m = re.match(r"\s*-?\s*uses:\s*(\S+)", line)
            if not m:
                continue
            spec = m.group(1)
            if spec.startswith("./") or spec.startswith("${"):
                continue          # local path, or an interpolated pin (half A's job)
            ref = spec.rsplit("@", 1)[-1] if "@" in spec else ""
            if re.fullmatch(r"[0-9a-fA-F]{40}", ref):
                continue
            key = (rel, spec)
            if key in allow:
                used_allow.add(key)
                notes.append(f"{rel}:{n}: {spec} unpinned — allowed: {allow[key]}")
                continue
            problems.append(
                f"{rel}:{n}: {spec} is not pinned to a full commit SHA. A tag is a"
                f" pointer its owner can move.")

for key in sorted(set(allow) - used_allow):
    problems.append(
        f"{allow_path}: the entry for '{key[1]}' in {key[0]} matches nothing."
        f" A stale exemption is an exemption nobody re-argued.")

for n in notes:
    print(f"supply-chain-pin: note — {n}")
for p in problems:
    print(f"supply-chain-pin: {p}")

if problems:
    print(f"supply-chain-pin: {len(problems)} unpinned or unverified boundary(ies).")
    sys.exit(1)
print("supply-chain-pin: caller pins a full SHA, passes it as flywheel_sha, and the"
      " reusable workflow checks that commit out before executing it.")
PY
