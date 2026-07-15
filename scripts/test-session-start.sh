#!/usr/bin/env bash
# flywheel — test for the SessionStart hook's relevance scoring (P9).
# Asserts: blank-line-tolerant metadata parsing, files/recency ranking, the
# INJECT_N budget + "more learnings" tail, the no-ledger path, and the banner.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${SRC}/scripts/session-start.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

TARGET="${WORK}/target"
mkdir -p "${TARGET}/.claude/flywheel"
git init -q "${TARGET}"
git -C "${TARGET}" -c user.email=t@t -c user.name=t checkout -qb main 2>/dev/null || true
echo base > "${TARGET}/foo.txt"
git -C "${TARGET}" add foo.txt
git -C "${TARGET}" -c user.email=t@t -c user.name=t commit -qm base
echo changed >> "${TARGET}/foo.txt"   # unstaged change → foo.txt is "changed"

TODAY="$(date +%F)"
# Entry A: files= matches the changed file, but a BLANK LINE separates the
# header from the metadata — the exact case that used to zero its relevance.
# Entry B: recent but unrelated. Entry C: stale and unrelated.
cat > "${TARGET}/.claude/flywheel/LEARNINGS.md" <<EOF
# flywheel learnings

## gotcha: touches foo

<!-- fw: type=gotcha; date=${TODAY}; files=foo.txt -->

The entry the scorer must rank first.

## decision: recent unrelated
<!-- fw: type=decision; date=${TODAY}; files=bar.ts -->

Recent but touches nothing changed.

## pattern: stale unrelated
<!-- fw: type=pattern; date=2020-01-01; files=baz.ts -->

Old and unrelated.
EOF

run_hook() {
  CLAUDE_PROJECT_DIR="${TARGET}" FLYWHEEL_NO_UPDATE_CHECK=1 \
    FLYWHEEL_LEARNINGS_INJECT="${1:-12}" bash "${SCRIPT}"
}

echo "== banner =="
OUT="$(run_hook)"
echo "${OUT}" | grep -q 'flywheel loaded' || fail "banner missing"
pass "banner printed"

echo "== blank-line-tolerant files match wins the budget =="
OUT1="$(run_hook 1)"
echo "${OUT1}" | grep -q 'touches foo' \
  || fail "entry with blank line before metadata lost its files= relevance"
echo "${OUT1}" | grep -q 'recent unrelated' && fail "budget of 1 leaked a second entry"
echo "${OUT1}" | grep -q 'more learning' || fail "'more learnings' tail missing"
pass "files-match ranks first despite blank line; INJECT_N=1 budget + tail hold"

echo "== full ranking: files > recency > stale =="
OUT3="$(run_hook 3)"
POS_A="$(printf '%s\n' "${OUT3}" | grep -n 'touches foo' | head -1 | cut -d: -f1)"
POS_B="$(printf '%s\n' "${OUT3}" | grep -n 'recent unrelated' | head -1 | cut -d: -f1)"
POS_C="$(printf '%s\n' "${OUT3}" | grep -n 'stale unrelated' | head -1 | cut -d: -f1)"
[ -n "${POS_A}" ] && [ -n "${POS_B}" ] && [ -n "${POS_C}" ] || fail "an entry vanished at INJECT_N=3"
[ "${POS_A}" -lt "${POS_B}" ] || fail "files-match did not outrank recency"
[ "${POS_B}" -lt "${POS_C}" ] || fail "recency did not outrank a stale entry"
pass "top-K ordering: files-match > recent > stale"

echo "== oversized entry is truncated =="
{
  printf '## pattern: verbose entry\n<!-- fw: type=pattern; date=%s; files=foo.txt -->\n\n' "${TODAY}"
  for i in $(seq 1 40); do printf 'This line pads the entry body well past the injection size budget. '; done
  printf 'ENDMARKER\n'
} >> "${TARGET}/.claude/flywheel/LEARNINGS.md"
OUT_TRUNC="$(run_hook 12)"
echo "${OUT_TRUNC}" | grep -q '\[truncated' || fail "oversized entry was not truncated"
echo "${OUT_TRUNC}" | grep -q 'ENDMARKER' && fail "truncation kept the oversized entry's tail"
pass "oversized entry truncated with a recall pointer"

echo "== no ledger =="
EMPTY="${WORK}/empty"
mkdir -p "${EMPTY}"
OUT_EMPTY="$(CLAUDE_PROJECT_DIR="${EMPTY}" FLYWHEEL_NO_UPDATE_CHECK=1 bash "${SCRIPT}")"
echo "${OUT_EMPTY}" | grep -q 'No flywheel learnings yet' || fail "no-ledger message missing"
pass "no ledger: friendly message, exits 0"

echo "== update-check stamp cache =="
# A same-day stamp must be trusted (no curl needed) and a symlinked stamp must
# be ignored — both offline-safe because a valid cache short-circuits curl.
TMP_STAMP_DIR="${WORK}/tmpstamp"
mkdir -p "${TMP_STAMP_DIR}"
echo "flywheel 0.0.1" > "${TARGET}/.claude/flywheel/VERSION"
printf '%s\n9.9.9\n' "$(date +%F)" > "${TMP_STAMP_DIR}/flywheel-remote-version.$(id -u)"
OUT_STAMP="$(CLAUDE_PROJECT_DIR="${TARGET}" TMPDIR="${TMP_STAMP_DIR}" bash "${SCRIPT}")"
echo "${OUT_STAMP}" | grep -q '9\.9\.9 is available' || fail "same-day stamp cache not used for the update notice"
rm -f "${TMP_STAMP_DIR}/flywheel-remote-version.$(id -u)"
touch "${TMP_STAMP_DIR}/evil-target"
ln -s "${TMP_STAMP_DIR}/evil-target" "${TMP_STAMP_DIR}/flywheel-remote-version.$(id -u)"
printf '%s\n6.6.6\n' "$(date +%F)" > "${TMP_STAMP_DIR}/evil-target"
OUT_SYM="$(CLAUDE_PROJECT_DIR="${TARGET}" FLYWHEEL_NO_UPDATE_CHECK= TMPDIR="${TMP_STAMP_DIR}" bash "${SCRIPT}" 2>/dev/null || true)"
echo "${OUT_SYM}" | grep -q '6\.6\.6' && fail "symlinked stamp content was trusted"
rm -f "${TARGET}/.claude/flywheel/VERSION"
pass "stamp cache honored same-day; symlinked stamp ignored"

echo ""
echo "all session-start tests passed"
