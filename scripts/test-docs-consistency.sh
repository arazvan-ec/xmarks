#!/usr/bin/env bash
# flywheel — docs consistency check.
# Every skill must be listed in the README command table and in the
# /flywheel:help command map (help doesn't list itself), so adding a skill
# without documenting it fails CI instead of silently drifting.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATUS=0

fail() { echo "FAIL: $*" >&2; STATUS=1; }
pass() { echo "  ok: $*"; }

for dir in "${SRC}"/skills/*/; do
  name="$(basename "${dir}")"
  grep -q "/flywheel:${name}" "${SRC}/README.md" \
    || fail "/flywheel:${name} is missing from the README command table"
  if [ "${name}" != "help" ]; then
    grep -q "/flywheel:${name}" "${SRC}/skills/help/SKILL.md" \
      || fail "/flywheel:${name} is missing from the /flywheel:help command map"
  fi
done

# Every agent must be mentioned in the README.
for f in "${SRC}"/agents/*.md; do
  agent="$(basename "${f}" .md)"
  grep -q "${agent}" "${SRC}/README.md" \
    || fail "agent '${agent}' is not mentioned in the README"
done

[ "${STATUS}" -eq 0 ] && pass "all $(ls -d "${SRC}"/skills/*/ | wc -l | tr -d ' ') skills and $(ls "${SRC}"/agents/*.md | wc -l | tr -d ' ') agents are documented"
exit "${STATUS}"
