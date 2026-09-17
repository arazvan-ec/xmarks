#!/usr/bin/env bash
# flywheel — test for scripts/check-version-citations.sh (P47, assertion 2): a
# citation that SENDS A READER to an upgrade note must name a note that is there.
#
# The fixture's dead citations are composed at run time from ${DEAD} rather than
# written out literally. This file is tracked prose too, and a literal
# "see <path>" in it would be a live violation of the rule it is testing.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${SRC}/scripts/check-version-citations.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

DEAD="upgrades/v0.59.0.md"      # the note the 0.61.0 renumber left unwritten
LIVE="upgrades/v0.60.0.md"

REPO="${WORK}/repo"
mkdir -p "${REPO}/upgrades" "${REPO}/docs"
git init -q "${REPO}"
g() { git -C "${REPO}" -c user.email=t@t -c user.name=t "$@"; }
: > "${REPO}/${LIVE}"

# write <relative-path> <line...>; commits, runs the gate, sets RC
put() {
  local f="$1"; shift
  mkdir -p "$(dirname "${REPO}/${f}")"
  printf '%s\n' "$@" > "${REPO}/${f}"
  g add -A >/dev/null; g commit -qm t >/dev/null 2>&1 || true
  RC=0
  bash "${CHECK}" "${REPO}" >"${WORK}/out" 2>&1 || RC=$?
}
clear_prose() { rm -f "${REPO}/prose.md"; g add -A >/dev/null; g commit -qm c >/dev/null 2>&1 || true; }

echo "== a mention is not a pointer =="
put prose.md \
  "The renumber left \`${DEAD}\` cited in a shipped error message — a file that would never exist." \
  "Added \`${DEAD}\`; documented in README." \
  "Shipped v0.59.0. Renumbered from v0.59.0 before merge." \
  "<!-- fw: type=gotcha; evidence=broke in v0.59.0 -->" \
  "| P47 | ... pointing at \`${DEAD}\` ... |"
[ "${RC}" -eq 0 ] || fail "mentions of a missing note must pass, got ${RC}: $(cat "${WORK}/out")"
pass "5 mention forms of a missing note → exit 0"

echo "== a dead pointer is caught, in every form that means 'go here' =="
for verb in See see Read read Follow follow Consult consult "Refer to" "refer to"; do
  put prose.md "Remedy: re-vendor and commit the rewritten caller. ${verb} ${DEAD}."
  [ "${RC}" -eq 1 ] || fail "'${verb} <dead note>' must exit 1, got ${RC}: $(cat "${WORK}/out")"
  grep -q "${DEAD}" "${WORK}/out" || fail "'${verb}': the failure must name the note"
  grep -q "prose.md" "${WORK}/out" || fail "'${verb}': the failure must name the file"
done
pass "see/read/follow/consult/refer to + a missing note → exit 1"

put prose.md "See \`${DEAD}\` for the remedy."
[ "${RC}" -eq 1 ] || fail "a backticked dead pointer must exit 1, got ${RC}"
put prose.md "See [\`${DEAD}\`](${DEAD}) for the remedy."
[ "${RC}" -eq 1 ] || fail "a linked dead pointer must exit 1, got ${RC}"
put prose.md "The note is [here](${DEAD})."
[ "${RC}" -eq 1 ] || fail "a bare markdown link to a dead note must exit 1, got ${RC}"
pass "backticked / linked / bare-link dead pointers → exit 1"

echo "== a live pointer passes, including relative spellings =="
put prose.md "See ${LIVE}." "Full detail in [\`${LIVE}\`](../${LIVE})." "Read ./${LIVE} first."
[ "${RC}" -eq 0 ] || fail "live pointers must pass, got ${RC}: $(cat "${WORK}/out")"
pass "see/link/relative pointers at an existing note → exit 0"

echo "== a verb that merely precedes the path in a sentence is not a pointer =="
put prose.md "See the ledger entry about the renumber that left ${DEAD} behind."
[ "${RC}" -eq 0 ] || fail "a verb with prose between it and the path must pass, got ${RC}: $(cat "${WORK}/out")"
pass "'See the ledger entry ... <dead note>' → exit 0"

echo "== the corpus is tracked files =="
clear_prose
printf 'See %s\n' "${DEAD}" > "${REPO}/untracked.md"
RC=0; bash "${CHECK}" "${REPO}" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 0 ] || fail "an untracked file must not be scanned, got ${RC}: $(cat "${WORK}/out")"
g add -A >/dev/null && g commit -qm track >/dev/null
RC=0; bash "${CHECK}" "${REPO}" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 1 ] || fail "the same file, tracked, must exit 1, got ${RC}"
pass "untracked → exit 0; the same file tracked → exit 1"

echo "== not a git checkout exits 2, never 0 =="
mkdir -p "${WORK}/bare"
RC=0; bash "${CHECK}" "${WORK}/bare" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 2 ] || fail "a non-repo must exit 2, got ${RC}: $(cat "${WORK}/out")"
pass "no git checkout → exit 2"

# The two decisive arms: the real corpus, and the real corpus with the real
# mistake put back. Nothing synthetic, no exclusion list.
echo "== the repo as it stands is green =="
RC=0; bash "${CHECK}" "${SRC}" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 0 ] || fail "this repo must be green: $(cat "${WORK}/out")"
pass "$(tail -1 "${WORK}/out")"

echo "== the 0.61.0 renumber, reconstructed on that same corpus, is red =="
REC="${WORK}/rec"
mkdir -p "${REC}"
# The tracked files with their WORKING-TREE contents, so both decisive arms
# grade the same corpus — the one the green arm just passed.
(cd "${SRC}" && git ls-files -z | tar --null -T - -cf -) | tar -x -C "${REC}"
WF="${REC}/.github/workflows/flywheel-update.yml"
[ -f "${WF}" ] || fail "no flywheel-update.yml in the archived tree"
grep -q '::error::' "${WF}" || fail "no ::error:: in flywheel-update.yml — the reconstruction has nothing to put back"
# Exactly the renumber's mistake: the shipped refusal keeps pointing at the
# slice's pre-renumber note, which was never written.
python3 - "${WF}" "${DEAD}" <<'PY'
import sys, re
p, dead = sys.argv[1], sys.argv[2]
s = open(p).read()
out = []
for line in s.splitlines(keepends=True):
    if "::error::" in line:
        line = re.sub(r"upgrades/v\d+\.\d+\.\d+\.md", dead, line)
    out.append(line)
open(p, "w").write("".join(out))
PY
grep -q "${DEAD}" "${WF}" || fail "the reconstruction did not change the error message"
git init -q "${REC}"
git -C "${REC}" -c user.email=t@t -c user.name=t add -A >/dev/null
git -C "${REC}" -c user.email=t@t -c user.name=t commit -qm rec >/dev/null
RC=0; bash "${CHECK}" "${REC}" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 1 ] || fail "the reconstructed renumber must be caught, got ${RC}: $(cat "${WORK}/out")"
grep -q "flywheel-update.yml" "${WORK}/out" || fail "the failure must name the workflow that ships the pointer"
[ "$(grep -c "${DEAD}" "${WORK}/out")" -eq 1 ] \
  || fail "exactly one violation expected; the corpus's other 0.59.0 text is mentions: $(cat "${WORK}/out")"
pass "the mistake as it was → exit 1, naming .github/workflows/flywheel-update.yml, once"

echo "ALL PASS"
