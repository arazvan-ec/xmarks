#!/usr/bin/env bash
# flywheel — test for scripts/check-followups.sh (P74).

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${SRC}/scripts/check-followups.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

R="${WORK}/repo"
mkdir -p "${R}/.claude/flywheel" "${R}/docs/research"
L="${R}/.claude/flywheel/LEARNINGS.md"
B="${R}/docs/research/improvement-proposals.md"
entry() { printf '## gotcha: %s\n\n<!-- fw: type=gotcha; date=2026-10-04; %s -->\n\nbody\n\n' "$1" "$2" >> "${L}"; }
run() { RC=0; (cd "${R}" && env "$@" bash "${CHECK}" >"${WORK}/out" 2>&1) || RC=$?; }
out() { cat "${WORK}/out"; }

echo "== no ledger passes =="
run
[ "${RC}" -eq 0 ] || fail "no ledger must pass, got ${RC}: $(out)"
pass "no ledger → 0"

echo "== entries without followup= pass =="
printf '# flywheel learnings\n\n' > "${L}"
entry "plain" "files=a.sh; evidence=x"
printf '| P1 | thing | ✅ |\n' > "${B}"
run
[ "${RC}" -eq 0 ] || fail "no followup must pass, got ${RC}: $(out)"
pass "no followup= → 0"

echo "== followup= without backlog= fails, names the entry =="
entry "open work" "followup=measure the gap; evidence=y"
run
[ "${RC}" -eq 1 ] || fail "followup without backlog must exit 1, got ${RC}: $(out)"
grep -q "open work" "${WORK}/out" || fail "must name the entry: $(out)"
pass "followup= alone → 1, named"

echo "== backlog= naming a missing row fails =="
sed -i 's/followup=measure the gap;/followup=measure the gap; backlog=P9;/' "${L}"
run
[ "${RC}" -eq 1 ] || fail "missing row must exit 1, got ${RC}: $(out)"
grep -q "P9" "${WORK}/out" || fail "must name the missing row: $(out)"
pass "backlog=P9 with no row → 1"

echo "== the row makes it pass =="
printf '| P9 | Measure the gap | 🔵 needs data |\n' >> "${B}"
run
[ "${RC}" -eq 0 ] || fail "row present must pass, got ${RC}: $(out)"
pass "row | P9 | → 0"

echo "== a P-number that only appears in prose is not a row =="
sed -i 's/backlog=P9;/backlog=P19;/' "${L}"
printf '\nSee P19 later.\n' >> "${B}"
run
[ "${RC}" -eq 1 ] || fail "prose mention must not count, got ${RC}: $(out)"
pass "P19 in prose only → 1"

echo "== P1 does not satisfy P19 and vice versa =="
sed -i 's/backlog=P19;/backlog=P1;/' "${L}"
run
[ "${RC}" -eq 0 ] || fail "P1 row exists, got ${RC}: $(out)"
pass "P1 matches | P1 | only"

echo "== several rows: every one must exist =="
sed -i 's/backlog=P1;/backlog=P1,P9;/' "${L}"
run
[ "${RC}" -eq 0 ] || fail "P1,P9 both exist, got ${RC}: $(out)"
sed -i 's/backlog=P1,P9;/backlog=P1,P7;/' "${L}"
run
[ "${RC}" -eq 1 ] || fail "P7 missing must fail, got ${RC}: $(out)"
grep -q "P7" "${WORK}/out" || fail "must name P7: $(out)"
sed -i 's/backlog=P1,P7;/backlog=P1;/' "${L}"
pass "backlog=P1,P9 → 0; P1,P7 → 1 naming P7"

echo "== no backlog file with a followup fails =="
rm "${B}"
run
[ "${RC}" -eq 1 ] || fail "followup with no backlog file must fail, got ${RC}: $(out)"
pass "no backlog file → 1"

echo "== .claude/flywheel/BACKLOG.md is the fallback =="
printf '| P1 | x | 🔵 |\n' > "${R}/.claude/flywheel/BACKLOG.md"
run
[ "${RC}" -eq 0 ] || fail "fallback backlog must count, got ${RC}: $(out)"
pass "fallback BACKLOG.md → 0"

echo "== FLYWHEEL_BACKLOG overrides =="
printf '| P2 | y |\n' > "${WORK}/other.md"
run FLYWHEEL_BACKLOG="${WORK}/other.md"
[ "${RC}" -eq 1 ] || fail "override without P1 must fail, got ${RC}: $(out)"
pass "override read"

echo "all check-followups arms passed"
