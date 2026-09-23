#!/usr/bin/env bash
# flywheel — renumber a release after the base took its version (P59).
#
#   renumber.sh <old> <new> [base]   the mechanics: git mv upgrades/v<old>.md and
#                                    every *-v<old> dir, rewrite the note's
#                                    frontmatter version and plugin.json.
#   renumber.sh --check <old> [base] list every <old> token left in files this
#                                    branch touches, as file:line. <old> may be
#                                    x.y.z or a P-number (P55).
#
# A leftover is classified by fixing it (the token is gone) or keeping it as
# history (`<!-- renumber: keep -->` on the line, or a `Renumbered from` line).
# Nothing else counts. .claude/flywheel/runs/** is immutable and never listed.
# Which leftover is a pointer is a judgment: skills/ship/references/renumber.md.
#
# Base: [base], then BASE_REF, then origin/main, then main.
# Exit: 0 ok · 1 refused, or unclassified leftovers · 2 unusable input

set -uo pipefail

die() { echo "renumber: $*" >&2; exit 2; }
VER='^[0-9]+\.[0-9]+\.[0-9]+$'

CHECK=0
[ "${1:-}" = "--check" ] && { CHECK=1; shift; }
if [ "${CHECK}" -eq 1 ]; then
  [ $# -ge 1 ] && [ $# -le 2 ] || die "usage: renumber.sh --check <old> [base]"
  OLD="$1"; BASE="${2:-}"
  [[ "${OLD}" =~ ${VER} || "${OLD}" =~ ^P[0-9]+$ ]] || die "'${OLD}' is neither x.y.z nor P<n>"
else
  [ $# -ge 2 ] && [ $# -le 3 ] || die "usage: renumber.sh <old> <new> [base]"
  OLD="$1"; NEW="$2"; BASE="${3:-}"
  [[ "${OLD}" =~ ${VER} && "${NEW}" =~ ${VER} ]] || die "'${OLD}' and '${NEW}' must both be x.y.z"
fi

TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repository"
cd "${TOP}" || die "cannot enter ${TOP}"
BASE="${BASE:-${BASE_REF:-}}"
if [ -z "${BASE}" ]; then
  if git rev-parse -q --verify origin/main >/dev/null; then BASE=origin/main; else BASE=main; fi
fi
git rev-parse -q --verify "${BASE}^{commit}" >/dev/null || die "'${BASE}' is not a ref this checkout has"

if [ "${CHECK}" -eq 1 ]; then
  MB="$(git merge-base "${BASE}" HEAD)" || die "no merge base between ${BASE} and HEAD"
  TOK="${OLD//./\\.}"
  if [[ "${OLD}" == P* ]]; then RE="(^|[^A-Za-z0-9])${TOK}([^0-9]|$)"; else RE="(^|[^0-9.])${TOK}([^0-9]|$)"; fi
  n=0; hits=""
  while IFS= read -r f; do
    [ -f "${f}" ] || continue
    case "${f}" in .claude/flywheel/runs/*) continue ;; esac
    n=$((n + 1))
    h="$(grep -nIE -- "${RE}" "${f}" | grep -vF -e 'Renumbered from' -e '<!-- renumber: keep -->')" || true
    [ -n "${h}" ] && hits+="$(printf '%s\n' "${h}" | sed "s|^|  ${f}:|")"$'\n'
  done < <({ git diff --name-only "${MB}"; git ls-files --others --exclude-standard; } | sort -u)
  if [ -n "${hits}" ]; then
    echo "renumber: unclassified ${OLD} in files this branch touches vs ${BASE}:" >&2
    printf '%s' "${hits}" >&2
    echo "  Fix each pointer, or keep history with '<!-- renumber: keep -->' (skills/ship/references/renumber.md)." >&2
    exit 1
  fi
  echo "renumber: OK — no unclassified ${OLD} in ${n} touched files vs ${BASE}"
  exit 0
fi

MANIFEST=".claude-plugin/plugin.json"
NOTE_OLD="upgrades/v${OLD}.md" NOTE_NEW="upgrades/v${NEW}.md"
[ -f "${NOTE_OLD}" ] || die "no ${NOTE_OLD} to renumber"
command -v python3 >/dev/null 2>&1 || die "no python3"
BASE_V="$(git show "${BASE}:${MANIFEST}" 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])' 2>/dev/null)"
[[ "${BASE_V}" =~ ${VER} ]] || die "cannot read a version from ${BASE}:${MANIFEST}"

if ! python3 -c 'import sys
p = lambda v: tuple(map(int, v.split(".")))
sys.exit(0 if p(sys.argv[2]) > p(sys.argv[1]) else 1)' "${BASE_V}" "${NEW}"; then
  echo "renumber: ${NEW} is not ahead of ${BASE}'s ${BASE_V} — pick a version above it" >&2
  exit 1
fi
[ ! -e "${NOTE_NEW}" ] || { echo "renumber: ${NOTE_NEW} already exists — ${NEW} is taken" >&2; exit 1; }

git mv "${NOTE_OLD}" "${NOTE_NEW}" || die "git mv ${NOTE_OLD} failed"
python3 - "${NOTE_NEW}" "${OLD}" "${NEW}" <<'PY' || die "cannot rewrite ${NOTE_NEW} frontmatter"
import re, sys
path, old, new = sys.argv[1:]
text = open(path).read()
m = re.match(r"---\n.*?\n---\n", text, re.S)
if m:
    head = re.sub(r"(?m)^version:\s*" + re.escape(old) + r"\s*$", "version: " + new, m.group(0))
    text = head + text[m.end():]
open(path, "w").write(text)
PY
sed -i.bak -E "s/(\"version\"[[:space:]]*:[[:space:]]*\")${OLD//./\\.}\"/\1${NEW}\"/" "${MANIFEST}" && rm -f "${MANIFEST}.bak"
git add "${NOTE_NEW}" "${MANIFEST}"

moved=0
while IFS= read -r d; do
  [ -n "${d}" ] || continue
  git mv "${d}" "${d%-v"${OLD}"}-v${NEW}" || die "git mv ${d} failed"
  moved=$((moved + 1))
done < <(git ls-files | grep -v '^\.claude/flywheel/runs/' \
  | awk -F/ '{ p = $1; for (i = 2; i <= NF; i++) { print p; p = p "/" $i } }' | sort -u \
  | grep -E -- "(^|/)[^/]*-v${OLD//./\\.}$" | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-)

echo "renumber: ${OLD} → ${NEW} (${NOTE_NEW}, ${MANIFEST}, ${moved} *-v${OLD} dir(s))"
echo "  Next: bash scripts/renumber.sh --check ${OLD} — classify every leftover it lists."
