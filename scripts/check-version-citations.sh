#!/usr/bin/env bash
# flywheel — CI gate (P47): a citation that sends a reader to an upgrade note
# must name a note that is there.
#
# The 0.61.0 renumber left the workflow's shipped ::error:: telling a refused
# third-party repo to go read an upgrade note for the slice's pre-renumber
# number — a file that was never written, quoted to a reader who cannot see this
# tree. Nothing checked it.
#
# WHAT THIS DOES NOT CHECK, on purpose. Not every version named in prose. This
# repo's prose names old versions constantly and legitimately — upgrade notes
# reference predecessors, the backlog says "shipped v0.42.0", learnings carry
# them in evidence=. Counted on the tree this shipped with, exactly one cited
# note is absent, and both of its citations sit in the backlog entry describing
# THIS defect: a rule keyed on the version appearing would redden on the
# description of the bug it exists to catch, and the only way out of that is an
# exclusion list. So the rule keys on the claim the text makes. "The renumber
# left <note> cited" asserts nothing about the file system. "See <note>" asserts
# the file is there. Only the second is checkable, and only the second was wrong.
#
# A pointer is a link whose target is the note, or one of a small set of
# directives immediately before its path. Resolution ignores any ./ or ../
# prefix and looks for upgrades/v<x.y.z>.md at the repo root: what varies is the
# version, and a mis-spelled relative path is a different defect with no
# evidence behind it here.
#
# Usage: check-version-citations.sh [repo-root]
# Exit: 0 ok · 1 a pointer with no note behind it · 2 unusable input

set -uo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "${ROOT}" 2>/dev/null || { echo "version-citations: no such directory: ${ROOT}" >&2; exit 2; }
git rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "version-citations: ${ROOT} is not a git checkout — the corpus is its tracked files" >&2; exit 2; }

VERB='([Ss]ee|[Rr]ead|[Ff]ollow|[Cc]onsult|[Rr]efer to)'
NOTE='(\.{0,2}/)*upgrades/v[0-9]+\.[0-9]+\.[0-9]+\.md'
RE="(\\]\\([^)]*|(^|[^A-Za-z])${VERB}[^A-Za-z0-9]{0,6})${NOTE}"

hits="$(git ls-files -z | xargs -0 grep -HnIoE "${RE}" 2>/dev/null || true)"

rc=0
seen=""
n=0
while IFS= read -r hit; do
  [ -n "${hit}" ] || continue
  where="${hit%%:*}"; rest="${hit#*:}"
  line="${rest%%:*}"; text="${rest#*:}"
  note="upgrades/$(printf '%s' "${text}" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+\.md')"
  key="${where}:${line}:${note}"
  case "${seen}" in *"|${key}|"*) continue ;; esac
  seen="${seen}|${key}|"
  n=$((n + 1))
  if [ ! -f "${note}" ]; then
    if [ "${rc}" -eq 0 ]; then
      echo "version-citations: a citation sends a reader to an upgrade note that is not in this repo:" >&2
    fi
    echo "  ${where}:${line}: ${note}" >&2
    rc=1
  fi
done <<< "${hits}"

if [ "${rc}" -ne 0 ]; then
  echo "  Write the note, or make the text a mention rather than a destination." >&2
  echo "  A renumber has to carry its pointers with it — that is what this gate is for." >&2
else
  echo "version-citations: OK (${n} remedy pointers, all resolving)"
fi
exit "${rc}"
