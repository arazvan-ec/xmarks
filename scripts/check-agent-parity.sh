#!/usr/bin/env bash
# flywheel — CI gate (P41): every agent exists twice and the two must agree.
#
# agents/*.md is what the plugin ships. .claude/agents/*.md is what actually
# registers as a subagent type in this repo's OWN sessions — Claude Code on the
# web never installs marketplace plugins, and agent discovery happens at session
# start, so a copy that is not in the clone is a route `work` cannot honor. The
# copies are the price of flywheel being able to delegate to its own executor;
# this gate is what keeps the price honest.
#
# Both directions: a shipped agent nobody registered is a tier the dev loop
# silently loses, and a registered agent nobody ships is a stale definition the
# loop would delegate to.
#
# Usage: check-agent-parity.sh [repo-root]   (default: this script's repo)
#   SKIP_AGENT_PARITY=1   skip with a logged notice, never silently
#
# Exit: 0 parity · 1 the copies disagree · 2 unusable input (no agents/ dir, no
#         agents in it, or the installer's rewrite is no longer what this gate
#         mirrors)

set -uo pipefail

if [ "${SKIP_AGENT_PARITY:-0}" = "1" ]; then
  echo "agent-parity: SKIPPED via SKIP_AGENT_PARITY=1"
  exit 0
fi

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SRC_DIR="${ROOT}/agents"
DST_DIR="${ROOT}/.claude/agents"
INSTALLER="${ROOT}/scripts/install-vendored.sh"

# The one line install-vendored.sh applies to every vendored file. Mirrored here
# rather than executed: the installer only runs against a real checkout, and this
# gate must work on a throwaway tree. Mirroring silently is the risk, so when the
# installer IS present its rewrite must still be the one below.
REWRITE='s|/flywheel:|/flywheel-|g'
rewrite() { sed "${REWRITE}" "$1"; }

[ -d "${SRC_DIR}" ] || {
  echo "agent-parity: no ${SRC_DIR} — nothing to compare" >&2
  exit 2
}
if [ -f "${INSTALLER}" ] && ! grep -qF "${REWRITE}" "${INSTALLER}"; then
  echo "agent-parity: install-vendored.sh no longer applies '${REWRITE}' — this" >&2
  echo "              gate mirrors that rewrite and can no longer be trusted." >&2
  exit 2
fi

shopt -s nullglob
src=("${SRC_DIR}"/*.md)
[ "${#src[@]}" -gt 0 ] || {
  echo "agent-parity: ${SRC_DIR} holds no agents — the glob is broken or the plugin ships none" >&2
  exit 2
}

rc=0
for f in "${src[@]}"; do
  b="$(basename "${f}")"
  d="${DST_DIR}/${b}"
  if [ ! -f "${d}" ]; then
    echo "agent-parity: ${b} ships in agents/ but is NOT registered in .claude/agents/"
    echo "              — flywheel's own sessions cannot delegate to it."
    echo "              fix: bash scripts/install-vendored.sh --agents-only ."
    rc=1
    continue
  fi
  if ! cmp -s <(rewrite "${f}") "${d}"; then
    echo "agent-parity: ${b} DRIFTED — agents/${b} and .claude/agents/${b} disagree."
    echo "              fix: bash scripts/install-vendored.sh --agents-only ."
    rc=1
  fi
done

for d in "${DST_DIR}"/*.md; do
  b="$(basename "${d}")"
  [ -f "${SRC_DIR}/${b}" ] && continue
  echo "agent-parity: ${b} is registered in .claude/agents/ but the plugin ships no"
  echo "              agents/${b} — a stale definition the loop would delegate to."
  rc=1
done

[ "${rc}" -eq 0 ] && echo "agent-parity: ${#src[@]} agents ship and register identically"
exit "${rc}"
