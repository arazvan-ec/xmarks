#!/usr/bin/env bash
# flywheel — test for the invocation-budget gate, scripts/check-invocation-budget.sh
# (P35). The description budget (P24) governs what every session pays always;
# this one governs what a single invocation pays, so its invariant is a
# per-skill ceiling rather than a total. Covers: under/over the ceiling; the
# breakdown ordered largest first; every over-budget skill named, not just the
# worst; a dangling references/ citation failing even when every body fits; a
# resolvable citation passing; missing/non-numeric budget and an empty body
# failing loudly rather than counting as zero; FW_INVOCATION_BUDGET overriding
# the committed file; SKIP_INVOCATION_BUDGET=1 as an explicit, logged escape.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${SRC}/scripts/check-invocation-budget.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

# skill <root> <name> <body-bytes> [citation...] — a SKILL.md padded to an exact
# total size, so the ceiling under test is an exact boundary and not an estimate.
skill() {
  local root="$1" name="$2" target="$3"; shift 3
  local dir="${root}/skills/${name}"
  mkdir -p "${dir}"
  { echo "---"; echo "name: ${name}"; echo "description: a test skill."; echo "---"; echo
    echo "# /flywheel:${name}"
    for c in "$@"; do echo "See \`${c}\` for the detail."; done; } > "${dir}/SKILL.md"
  local now pad
  now=$(wc -c < "${dir}/SKILL.md")
  pad=$(( target - now ))
  if [ "${pad}" -gt 0 ]; then head -c "${pad}" < /dev/zero | tr '\0' 'x' >> "${dir}/SKILL.md"; fi
}

# reference <root> <skill> <topic> — the file a citation must resolve to
reference() {
  mkdir -p "$1/skills/$2/references"
  echo "detail." > "$1/skills/$2/references/$3"
}

# run_check <root> [VAR=val ...] -> sets RC, output in ${WORK}/out
run_check() {
  local root="$1"; shift
  RC=0
  (cd "${root}" && env "$@" bash "${CHECK}" >"${WORK}/out" 2>&1) || RC=$?
}

echo "== every body under the ceiling passes =="
R1="${WORK}/r1"; mkdir -p "${R1}/scripts"
echo 4500 > "${R1}/scripts/invocation-budget.txt"
skill "${R1}" alpha 4500          # exactly at the ceiling — must pass
skill "${R1}" beta  1200
run_check "${R1}"
[ "${RC}" -eq 0 ] || fail "bodies at/under the ceiling must pass, got ${RC}: $(cat "${WORK}/out")"
grep -q 4500 "${WORK}/out" || fail "success output must report the worst case: $(cat "${WORK}/out")"
pass "at/under the ceiling → exit 0, reports the worst case"

echo "== over the ceiling fails and names every offender =="
R2="${WORK}/r2"; mkdir -p "${R2}/scripts"
echo 2000 > "${R2}/scripts/invocation-budget.txt"
skill "${R2}" tiny  500
skill "${R2}" hoggy 6000
skill "${R2}" middy 2500
run_check "${R2}"
[ "${RC}" -ne 0 ] || fail "a body over the ceiling must fail"
grep -q hoggy "${WORK}/out" || fail "failure must name the worst skill: $(cat "${WORK}/out")"
grep -q middy "${WORK}/out" || fail "failure must name EVERY over-budget skill, not only the worst"
grep -q 2000  "${WORK}/out" || fail "failure must state the ceiling"
pass "over the ceiling → fails, names hoggy and middy and the ceiling"

echo "== breakdown is ordered, largest first =="
[ "$(grep -n hoggy "${WORK}/out" | cut -d: -f1 | head -1)" -lt \
  "$(grep -n middy "${WORK}/out" | cut -d: -f1 | head -1)" ] \
  || fail "breakdown must list the largest body before the smaller one"
[ "$(grep -n middy "${WORK}/out" | cut -d: -f1 | head -1)" -lt \
  "$(grep -n tiny  "${WORK}/out" | cut -d: -f1 | head -1)" ] \
  || fail "breakdown must list every skill in descending size order"
pass "breakdown ordered largest first"

echo "== the breakdown precedes the verdict it refers to =="
# Regression: the breakdown goes to stdout and the verdict to stderr, and CI
# redirects both into one stream. With stdout block-buffered — any environment
# that does not set PYTHONUNBUFFERED, GitHub's runners among them — an unflushed
# stdout puts the verdict first, and a reader has to reorder the output in their
# head. Asserted with the buffering the runner actually has, not the one this
# machine happens to have.
(cd "${R2}" && env -u PYTHONUNBUFFERED bash "${CHECK}" >"${WORK}/buf" 2>&1) || true
[ "$(grep -n "^  hoggy" "${WORK}/buf" | cut -d: -f1 | head -1)" -lt \
  "$(grep -n "^invocation-budget:" "${WORK}/buf" | cut -d: -f1 | head -1)" ] \
  || fail "the verdict landed before the breakdown: $(cat "${WORK}/buf")"
pass "breakdown precedes the verdict under block-buffered stdout"

echo "== a resolvable citation passes =="
R3="${WORK}/r3"; mkdir -p "${R3}/scripts"
echo 4500 > "${R3}/scripts/invocation-budget.txt"
skill "${R3}" cited 1000 "skills/cited/references/detail.md"
reference "${R3}" cited detail.md
run_check "${R3}"
[ "${RC}" -eq 0 ] || fail "a citation that resolves must pass, got ${RC}: $(cat "${WORK}/out")"
pass "citation that resolves → exit 0"

echo "== a dangling citation fails even when every body fits =="
R4="${WORK}/r4"; mkdir -p "${R4}/scripts"
echo 4500 > "${R4}/scripts/invocation-budget.txt"
skill "${R4}" dangler 1000 "skills/dangler/references/missing.md"
run_check "${R4}"
[ "${RC}" -ne 0 ] || fail "a body citing a reference that does not exist must fail"
grep -q dangler    "${WORK}/out" || fail "the error must name the skill: $(cat "${WORK}/out")"
grep -q missing.md "${WORK}/out" || fail "the error must name the unresolved path"
pass "dangling citation → fails, names skill and path"

echo "== a bare references/ citation resolves against the skill dir =="
R5="${WORK}/r5"; mkdir -p "${R5}/scripts"
echo 4500 > "${R5}/scripts/invocation-budget.txt"
skill "${R5}" bare 1000 "references/detail.md"
reference "${R5}" bare detail.md
run_check "${R5}"
[ "${RC}" -eq 0 ] || fail "a bare references/ path must resolve against its own skill dir, got ${RC}: $(cat "${WORK}/out")"
pass "bare references/ citation resolves against the skill dir"

echo "== missing budget file fails loudly =="
R6="${WORK}/r6"; mkdir -p "${R6}/scripts"
skill "${R6}" alpha 100
run_check "${R6}"
[ "${RC}" -eq 2 ] || fail "no budget file and no override must exit 2, got ${RC}"
grep -qi "budget" "${WORK}/out" || fail "the error must say the budget is missing"
pass "missing budget file → exit 2, loud"

echo "== non-numeric budget fails loudly =="
R7="${WORK}/r7"; mkdir -p "${R7}/scripts"
echo "four thousand" > "${R7}/scripts/invocation-budget.txt"
skill "${R7}" alpha 100
run_check "${R7}"
[ "${RC}" -eq 2 ] || fail "a non-numeric budget must exit 2, not be coerced, got ${RC}"
pass "non-numeric budget → exit 2, loud"

echo "== an empty body fails loudly, never as zero =="
R8="${WORK}/r8"; mkdir -p "${R8}/scripts"
echo 4500 > "${R8}/scripts/invocation-budget.txt"
mkdir -p "${R8}/skills/hollow"
{ echo "---"; echo "name: hollow"; echo "description: frontmatter only."; echo "---"; echo; } \
  > "${R8}/skills/hollow/SKILL.md"
run_check "${R8}"
[ "${RC}" -ne 0 ] || fail "a skill whose body is empty must fail, not pass as the cheapest skill"
grep -q hollow "${WORK}/out" || fail "the error must name the hollow skill"
pass "empty body → fails loudly, names the skill"

echo "== FW_INVOCATION_BUDGET overrides the committed file =="
run_check "${R2}" FW_INVOCATION_BUDGET=10000
[ "${RC}" -eq 0 ] || fail "FW_INVOCATION_BUDGET must override the file upward, got ${RC}"
run_check "${R1}" FW_INVOCATION_BUDGET=100
[ "${RC}" -ne 0 ] || fail "FW_INVOCATION_BUDGET must override the file downward"
pass "FW_INVOCATION_BUDGET wins over scripts/invocation-budget.txt"

echo "== SKIP_INVOCATION_BUDGET=1 escape is logged =="
run_check "${R2}" SKIP_INVOCATION_BUDGET=1
[ "${RC}" -eq 0 ] || fail "SKIP_INVOCATION_BUDGET=1 must pass, got ${RC}"
grep -qi skip "${WORK}/out" || fail "the escape must be logged, not silent"
pass "SKIP_INVOCATION_BUDGET=1 → exit 0, logged"

echo "ALL PASS"
