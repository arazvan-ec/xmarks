#!/usr/bin/env bash
# flywheel — test for scripts/renumber.sh (P59): the mechanics of a renumber are
# performed, and what is left is listed until every leftover is classified.
#
# The last arms replay #81: the 0.59→0.61 renumber left three 0.59.0 pointers in
# flywheel-update.yml, one inside the ::error:: remedy. The fixture's pointer is
# composed from ${OLD} at run time, because a literal "See upgrades/v<x>.md" here
# would be a live dead citation for check-version-citations.sh.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RN="${SRC}/scripts/renumber.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

OLD=0.59.0 MAIN=0.60.0 NEW=0.61.0
REPO="${WORK}/repo"
mkdir -p "${REPO}/.claude-plugin" "${REPO}/upgrades" "${REPO}/docs"
git init -q "${REPO}"
g() { git -C "${REPO}" -c user.email=t@t -c user.name=t "$@"; }
ver() { printf '{\n  "name": "flywheel",\n  "version": "%s"\n}\n' "$1" > "${REPO}/.claude-plugin/plugin.json"; }
note() { printf -- '---\nversion: %s\nrequires-action: false\nsummary: s\n---\n\n## What changed\n\nx\n' "$1" > "${REPO}/upgrades/v$1.md"; }
g checkout -qb main
ver 0.58.0; note 0.58.0
echo "Untouched prose naming ${OLD} in passing." > "${REPO}/docs/old.md"
g add -A && g commit -qm base

g checkout -qb feat
ver "${OLD}"; note "${OLD}"
mkdir -p "${REPO}/benchmarks/eval-v${OLD}" "${REPO}/.github/workflows" "${REPO}/.claude/flywheel/runs/x"
echo r > "${REPO}/benchmarks/eval-v${OLD}/result.txt"
cat > "${REPO}/.github/workflows/flywheel-update.yml" <<EOF
name: flywheel-update
# WHAT CHANGED IN ${OLD}, AND WHAT IT COSTS.
on: workflow_call
jobs:
  u:
    steps:
      # means the caller predates flywheel ${OLD} and still says @main
      - run: echo "::error::Remedy: re-vendor and commit the rewritten caller. See upgrades/v${OLD}.md."
EOF
printf '%s\n' "# Journal" "" "Shipped ${OLD} on the branch; main then took ${MAIN}." > "${REPO}/docs/journal.md"
echo "{\"note\": \"released ${OLD}\"}" > "${REPO}/.claude/flywheel/runs/x/a.jsonl"
g add -A && g commit -qm "feat at ${OLD}"

g checkout -q main
ver "${MAIN}"; note "${MAIN}"
g add -A && g commit -qm "main took ${MAIN}"
g checkout -q feat
g merge -q -X ours --no-edit main >/dev/null

rn() { RC=0; (cd "${REPO}" && bash "${RN}" "$@" main >"${WORK}/out" 2>&1) || RC=$?; }
out() { cat "${WORK}/out"; }

echo "== usage errors exit 2 =="
rn "${OLD}"
[ "${RC}" -eq 2 ] || fail "one argument must exit 2, got ${RC}: $(out)"
rn 0.59 "${NEW}"
[ "${RC}" -eq 2 ] || fail "a non-x.y.z version must exit 2, got ${RC}: $(out)"
rn 0.57.0 "${NEW}"
[ "${RC}" -eq 2 ] || fail "an <old> with no note must exit 2, got ${RC}: $(out)"
pass "missing argument / bad version / no note → exit 2"

echo "== a <new> that is not ahead of the base is refused =="
for bad in "${MAIN}" 0.58.5; do
  rn "${OLD}" "${bad}"
  [ "${RC}" -eq 1 ] || fail "<new> ${bad} is not ahead of ${MAIN}, must exit 1, got ${RC}: $(out)"
  grep -q "not ahead" "${WORK}/out" || fail "the refusal must say 'not ahead': $(out)"
done
[ -f "${REPO}/upgrades/v${OLD}.md" ] || fail "a refused renumber must move nothing"
pass "<new> equal to or behind the base → exit 1, nothing moved"

echo "== a <new> whose note already exists is refused =="
note 0.62.0
rn "${OLD}" 0.62.0
[ "${RC}" -eq 1 ] || fail "an existing upgrades/v0.62.0.md must refuse, got ${RC}: $(out)"
grep -q "already exists" "${WORK}/out" || fail "the refusal must say 'already exists': $(out)"
rm "${REPO}/upgrades/v0.62.0.md"
pass "existing note for <new> → exit 1"

echo "== the mechanics move the note, frontmatter, plugin.json and *-v<old> dirs =="
rn "${OLD}" "${NEW}"
[ "${RC}" -eq 0 ] || fail "the renumber must succeed, got ${RC}: $(out)"
[ ! -e "${REPO}/upgrades/v${OLD}.md" ] || fail "the old note is still there"
grep -qx "version: ${NEW}" "${REPO}/upgrades/v${NEW}.md" || fail "frontmatter not rewritten: $(cat "${REPO}/upgrades/v${NEW}.md")"
grep -q "\"version\": \"${NEW}\"" "${REPO}/.claude-plugin/plugin.json" || fail "plugin.json not rewritten"
[ -f "${REPO}/benchmarks/eval-v${NEW}/result.txt" ] || fail "the *-v<old> dir was not moved"
[ ! -e "${REPO}/benchmarks/eval-v${OLD}" ] || fail "the *-v<old> dir is still there"
g status --porcelain | grep -q "^R  upgrades/v${OLD}.md -> upgrades/v${NEW}.md" || fail "the note move must be a staged git mv: $(g status --porcelain)"
pass "note + frontmatter + plugin.json + benchmarks dir renumbered, as a git mv"

echo "== #81 replay: --check names all three stale pointers =="
rn --check "${OLD}"
[ "${RC}" -eq 1 ] || fail "--check with stale pointers must exit 1, got ${RC}: $(out)"
YML=.github/workflows/flywheel-update.yml
for n in $(grep -n "${OLD}" "${REPO}/${YML}" | cut -d: -f1); do
  grep -q "^  ${YML}:${n}:" "${WORK}/out" || fail "--check must name ${YML}:${n}: $(out)"
done
[ "$(grep -c "^  ${YML}:" "${WORK}/out")" -eq 3 ] || fail "exactly three pointers in ${YML}: $(out)"
grep -q "^  docs/journal.md:3:" "${WORK}/out" || fail "an unclassified history line must be listed: $(out)"
pass "3 flywheel-update.yml pointers + 1 journal line listed, as file:line"

echo "== runs/, 'Renumbered from' lines and untouched files are never listed =="
grep -q "runs/" "${WORK}/out" && fail "runs/ is immutable and exempt: $(out)"
grep -q "docs/old.md" "${WORK}/out" && fail "a file the branch did not touch is out of scope: $(out)"
echo "Renumbered from v${OLD}: main took ${MAIN}." >> "${REPO}/upgrades/v${NEW}.md"
rn --check "${OLD}"
grep -q "upgrades/v${NEW}.md" "${WORK}/out" && fail "a 'Renumbered from' line is exempt: $(out)"
pass "runs/ + untouched file + 'Renumbered from' → not listed"

echo "== fixing the pointers leaves only the unclassified history line =="
sed -i.bak "s/${OLD}/${NEW}/g" "${REPO}/${YML}" && rm "${REPO}/${YML}.bak"
rn --check "${OLD}"
[ "${RC}" -eq 1 ] || fail "an unclassified history line must still fail, got ${RC}: $(out)"
grep -q "${YML}" "${WORK}/out" && fail "fixed pointers must not be listed: $(out)"
pass "pointers fixed, history unclassified → exit 1"

echo "== a keep marker classifies history; --check exits 0 =="
sed -i.bak "3s/\$/ <!-- renumber: keep -->/" "${REPO}/docs/journal.md" && rm "${REPO}/docs/journal.md.bak"
rn --check "${OLD}"
[ "${RC}" -eq 0 ] || fail "every leftover classified must exit 0, got ${RC}: $(out)"
pass "all fixed or kept → exit 0"

echo "== an uncommitted touched file is in scope, and the token is matched whole =="
echo "Pointer to ${OLD}; not 1${OLD} nor ${OLD}1." > "${REPO}/docs/new.md"
rn --check "${OLD}"
[ "${RC}" -eq 1 ] || fail "an untracked file with the token must fail, got ${RC}: $(out)"
[ "$(grep -c "docs/new.md" "${WORK}/out")" -eq 1 ] || fail "one listed line: $(out)"
printf '%s\n' "Pointer to ${NEW}; 1${OLD} and ${OLD}1 are other numbers." > "${REPO}/docs/new.md"
rn --check "${OLD}"
[ "${RC}" -eq 0 ] || fail "1<old> and <old>1 are not the token, got ${RC}: $(out)"
pass "untracked file scanned; embedded digits are not the token"

echo "== the P-number variant: --check P<n> =="
printf '%s\n' "| P55 | row |" "| P550 | other |" > "${REPO}/docs/backlog.md"
rn --check P55
[ "${RC}" -eq 1 ] || fail "--check P55 with a P55 row must exit 1, got ${RC}: $(out)"
grep -q "^  docs/backlog.md:1:" "${WORK}/out" || fail "the P55 row must be listed: $(out)"
grep -q "^  docs/backlog.md:2:" "${WORK}/out" && fail "P550 is not P55: $(out)"
pass "--check P55 lists P55, not P550"

echo "PASS: renumber"
