#!/usr/bin/env bash
# flywheel — test for the description-budget gate, scripts/check-description-budget.sh
# (P24). Covers: under budget passes; over budget fails and names the biggest
# skill; the breakdown is ordered; a body-level `description:` is never counted;
# missing/empty/folded values fail loudly rather than counting as zero; the
# budget comes from the committed file and FW_DESC_BUDGET overrides it;
# SKIP_DESCRIPTION_BUDGET=1 is an explicit, logged escape.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${SRC}/scripts/check-description-budget.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

# skill <root> <name> <description-line...> — writes a minimal SKILL.md
skill() {
  local root="$1" name="$2"; shift 2
  mkdir -p "${root}/skills/${name}"
  { echo "---"; echo "name: ${name}"; printf '%s\n' "$@"; echo "---"; echo
    echo "# /flywheel:${name}"; } > "${root}/skills/${name}/SKILL.md"
}

# run_check <root> [env VAR=val ...] -> sets RC, output in ${WORK}/out
run_check() {
  local root="$1"; shift
  RC=0
  (cd "${root}" && env "$@" bash "${CHECK}" >"${WORK}/out" 2>&1) || RC=$?
}

echo "== under budget passes =="
R1="${WORK}/r1"; mkdir -p "${R1}/scripts"
echo 100 > "${R1}/scripts/description-budget.txt"
skill "${R1}" alpha "description: 12345678901234567890"  # exactly 20
skill "${R1}" beta  "description: 09876543210987654321"  # exactly 20
run_check "${R1}"
[ "${RC}" -eq 0 ] || fail "40 chars under a 100 budget must pass, got ${RC}: $(cat "${WORK}/out")"
grep -q 40 "${WORK}/out" || fail "success output must report the total, got: $(cat "${WORK}/out")"
pass "under budget → exit 0, reports the total"

echo "== over budget fails and names the biggest skill =="
R2="${WORK}/r2"; mkdir -p "${R2}/scripts"
echo 30 > "${R2}/scripts/description-budget.txt"
skill "${R2}" small "description: short one."
skill "${R2}" hoggy "description: this description is deliberately the long one in the tree."
run_check "${R2}"
[ "${RC}" -ne 0 ] || fail "over budget must fail"
grep -q hoggy "${WORK}/out" || fail "failure must name the biggest skill: $(cat "${WORK}/out")"
grep -q 30 "${WORK}/out" || fail "failure must state the budget"
pass "over budget → fails, names hoggy and the budget"

echo "== breakdown is ordered, largest first =="
[ "$(grep -n hoggy "${WORK}/out" | cut -d: -f1 | head -1)" -lt \
  "$(grep -n small "${WORK}/out" | cut -d: -f1 | head -1)" ] \
  || fail "breakdown must list the largest skill before the smaller one"
pass "breakdown ordered largest first"

echo "== a body-level description: is never counted =="
R3="${WORK}/r3"; mkdir -p "${R3}/scripts"
echo 100 > "${R3}/scripts/description-budget.txt"
mkdir -p "${R3}/skills/bodytext"
{ echo "---"; echo "name: bodytext"; echo "description: 12345678901234567890"; echo "---"; echo
  echo "# body"; echo "description: this line is prose and must not be counted at all."; } \
  > "${R3}/skills/bodytext/SKILL.md"
run_check "${R3}"
[ "${RC}" -eq 0 ] || fail "body description must be ignored, got ${RC}: $(cat "${WORK}/out")"
grep -qw 20 "${WORK}/out" || fail "only the frontmatter value counts (expected total 20): $(cat "${WORK}/out")"
pass "body-level description: ignored, total is frontmatter-only"

echo "== missing description fails loudly =="
R4="${WORK}/r4"; mkdir -p "${R4}/scripts"
echo 1000 > "${R4}/scripts/description-budget.txt"
mkdir -p "${R4}/skills/nodesc"
{ echo "---"; echo "name: nodesc"; echo "---"; echo; echo "# no description"; } \
  > "${R4}/skills/nodesc/SKILL.md"
run_check "${R4}"
[ "${RC}" -ne 0 ] || fail "a skill with no description must fail, not count as zero"
grep -q nodesc "${WORK}/out" || fail "the error must name the offending skill"
pass "missing description → fails loudly, names the skill"

echo "== empty and folded values fail loudly =="
for bad in "description:" "description: >" "description: |"; do
  R="${WORK}/r5-$(echo "${bad}" | tr -dc 'a-z|>')"; mkdir -p "${R}/scripts"
  echo 1000 > "${R}/scripts/description-budget.txt"
  skill "${R}" folded "${bad}" "  wrapped continuation text that a naive parser would miss."
  run_check "${R}"
  [ "${RC}" -ne 0 ] || fail "'${bad}' must fail loudly, not count as ~0"
  grep -q folded "${WORK}/out" || fail "'${bad}' error must name the skill"
done
pass "empty / '>' / '|' values → fail loudly"

echo "== FW_DESC_BUDGET overrides the committed file =="
run_check "${R2}" FW_DESC_BUDGET=10000
[ "${RC}" -eq 0 ] || fail "FW_DESC_BUDGET must override the file upward, got ${RC}"
run_check "${R1}" FW_DESC_BUDGET=10
[ "${RC}" -ne 0 ] || fail "FW_DESC_BUDGET must override the file downward"
pass "FW_DESC_BUDGET wins over scripts/description-budget.txt"

echo "== SKIP_DESCRIPTION_BUDGET=1 escape is logged =="
run_check "${R2}" SKIP_DESCRIPTION_BUDGET=1
[ "${RC}" -eq 0 ] || fail "SKIP_DESCRIPTION_BUDGET=1 must pass, got ${RC}"
grep -qi skip "${WORK}/out" || fail "the escape must be logged, not silent"
pass "SKIP_DESCRIPTION_BUDGET=1 → exit 0, logged"

echo "ALL PASS"
