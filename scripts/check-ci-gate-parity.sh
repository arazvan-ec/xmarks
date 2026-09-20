#!/usr/bin/env bash
# flywheel — CI gate (P52): the gates this repo ships are the gates CI runs.
#
# `scripts/test-*.sh` is discovered by a glob, with a comment in the workflow
# explaining why — "so a new one cannot sit in the tree never executed (which is
# what happened to test-run-cost.sh for four releases)". Six lines below that
# comment, the `check-*.sh` gates are a hand-written list of steps, and the same
# failure had already happened to them:
#
#   scripts/check-supply-chain-pin.sh — its own header calls it "the only
#   Critical in the pillar-2 threat model" — appeared in .github/workflows/
#   exactly twice, both times inside a COMMENT. It had a test, it passed, and it
#   had never once run in CI.
#
# Which is why the comment stripping below is the whole gate: to anything that
# greps without it, that tree reads as fully wired.
#
# Two directions, because one is half a claim:
#   FORWARD — every scripts/check-*.sh is invoked by some workflow.
#   CONVERSE — every gate a workflow invokes exists in the tree, so a green
#              parity cannot be bought by renaming a step.
#
# NOT a replacement for the hand-written list. Two gates take the merge base as
# an argument (check-test-pairing.sh, check-release-bump.sh); a glob loop would
# call them without it and leave them green having compared nothing — this
# ledger's oldest mistake wearing a different hat. The list is fine; the list
# being unchecked was not.
#
# Usage: check-ci-gate-parity.sh [repo-root]
#   SKIP_CI_GATE_PARITY=<reason>   skip with a logged notice, never silently
#
# Exit: 0 ok · 1 a gate nobody runs, or a step nothing backs · 2 unusable input

set -uo pipefail

if [ -n "${SKIP_CI_GATE_PARITY:-}" ]; then
  echo "ci-gate-parity: SKIPPED via SKIP_CI_GATE_PARITY=${SKIP_CI_GATE_PARITY}"
  exit 0
fi

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
FLOWS="${ROOT}/.github/workflows"

[ -d "${FLOWS}" ] || { echo "ci-gate-parity: no ${FLOWS} — nothing to compare" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ci-gate-parity: no python3" >&2; exit 2; }

FW_ROOT="${ROOT}" FW_FLOWS="${FLOWS}" python3 - <<'PY'
import glob, os, re, sys

root, flows = os.environ["FW_ROOT"], os.environ["FW_FLOWS"]
REF = re.compile(r"scripts/(check-[A-Za-z0-9_-]+\.sh)")

shipped = {os.path.basename(p) for p in glob.glob(os.path.join(root, "scripts", "check-*.sh"))}

wired, files = {}, sorted(glob.glob(os.path.join(flows, "*.yml"))
                          + glob.glob(os.path.join(flows, "*.yaml")))
if not files:
    print(f"ci-gate-parity: {flows} holds no workflow files", file=sys.stderr)
    sys.exit(2)

for f in files:
    for n, raw in enumerate(open(f, encoding="utf-8"), 1):
        # A line that is only a comment is a MENTION, not a call. This is the
        # whole gate: both of check-supply-chain-pin.sh's appearances were this.
        if raw.lstrip().startswith("#"):
            continue
        for name in REF.findall(raw):
            wired.setdefault(name, f"{os.path.basename(f)}:{n}")

unwired = sorted(shipped - set(wired))
ghosts = sorted(set(wired) - shipped)

for g in unwired:
    print(f"ci-gate-parity: scripts/{g} is in the tree and no workflow invokes it —"
          f" a gate nobody runs is green for a reason that has nothing to do with"
          f" the code it guards")
for g in ghosts:
    print(f"ci-gate-parity: {wired[g]} invokes scripts/{g}, which is not in the tree")

print(f"ci-gate-parity: {len(shipped)} gate(s) shipped, {len(shipped) - len(unwired)}"
      f" invoked across {len(files)} workflow file(s).")

sys.exit(1 if (unwired or ghosts) else 0)
PY
