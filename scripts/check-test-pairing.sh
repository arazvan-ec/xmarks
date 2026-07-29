#!/usr/bin/env bash
# flywheel — CI gate (P22): any diff touching scripts/<name>.sh must also touch
# its paired scripts/test-<name>.sh (add, change or delete — the pair moves
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

changed="$(git diff --name-only "${BASE}...HEAD" -- 'scripts/*.sh')"
[ -n "${changed}" ] || { echo "test-pairing: no script changes vs ${BASE}"; exit 0; }

rc=0
while IFS= read -r f; do
  name="$(basename "${f}")"
  case "${name}" in test-*) continue ;; esac
  pair="scripts/test-${name}"
  if ! printf '%s\n' "${changed}" | grep -qx "${pair}"; then
    echo "test-pairing: ${f} changed without its paired ${pair} (add/update/delete them together)" >&2
    rc=1
  fi
done <<< "${changed}"

[ "${rc}" -eq 0 ] && echo "test-pairing: OK (all changed scripts moved with their tests)"
exit "${rc}"
