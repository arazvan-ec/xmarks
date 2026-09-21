#!/usr/bin/env bash
# flywheel — CI gate (P22): any diff touching a scripts/<stem>.<ext> script must
# also touch its paired scripts/test-<stem>.sh (add, change or delete — the pair moves
# together). Test-first is a convention; this makes skipping it visible.
# Usage: check-test-pairing.sh [base-ref]   (default: BASE_REF env, then
# origin/main, then main). SKIP_TEST_PAIRING=1 skips with a logged notice.

set -euo pipefail

if [ "${SKIP_TEST_PAIRING:-0}" = "1" ]; then
  echo "test-pairing: SKIPPED via SKIP_TEST_PAIRING=1"
  exit 0
fi

BASE="${1:-${BASE_REF:-}}"
if [ -z "${BASE}" ]; then
  if git rev-parse -q --verify origin/main >/dev/null; then BASE=origin/main; else BASE=main; fi
fi

# Every script language, not just the one the repo happened to start with:
# scripts/fw_tasks.py (v0.70.0) was invisible to a 'scripts/*.sh' glob, which is
# how a file lands with no test and the suite still says everything is paired.
# Data files (*.txt) are not scripts and are deliberately not listed.
changed="$(git diff --name-only "${BASE}...HEAD" -- 'scripts/*.sh' 'scripts/*.py')"
[ -n "${changed}" ] || { echo "test-pairing: no script changes vs ${BASE}"; exit 0; }

rc=0
while IFS= read -r f; do
  name="$(basename "${f}")"
  case "${name}" in test-*) continue ;; esac
  # Keyed on the STEM: a .py subject is exercised by a .sh harness like
  # everything else here, so the pair cannot carry the subject's extension.
  pair="scripts/test-${name%.*}.sh"
  if ! printf '%s\n' "${changed}" | grep -qx "${pair}"; then
    echo "test-pairing: ${f} changed without its paired ${pair} (add/update/delete them together)" >&2
    rc=1
  fi
done <<< "${changed}"

[ "${rc}" -eq 0 ] && echo "test-pairing: OK (all changed scripts moved with their tests)"
exit "${rc}"
