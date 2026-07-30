#!/usr/bin/env bash
# flywheel — test for scripts/run-cost.sh (P23), the two-run cost comparison over
# telemetry JSONL. Covers: single-run totals; two-run delta with sign and
# percentage; a zero baseline field prints n/a instead of a bogus percentage;
# lines with no cost object are reported as UNMEASURED, never as zero; a
# `tokens` key warns (the field is banned by design, P18); malformed lines are
# skipped and counted; missing/empty input fails with a clear error.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COST="${SRC}/scripts/run-cost.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

# line <ts> <bytes> <calls> <elapsed>
line() {
  printf '{"ts":"2026-07-30T10:%02d:00Z","task":"t%s","state":"completed","cost":{"bytes_out":%s,"tool_calls":%s,"elapsed_s":%s}}\n' \
    "$1" "$1" "$2" "$3" "$4"
}

run() { RC=0; bash "${COST}" "$@" >"${WORK}/out" 2>&1 || RC=$?; }

echo "== single-run totals =="
{ line 0 100 2 5; line 1 50 1 10; } > "${WORK}/a.jsonl"
run "${WORK}/a.jsonl"
[ "${RC}" -eq 0 ] || fail "single run must exit 0, got ${RC}: $(cat "${WORK}/out")"
grep -q 150 "${WORK}/out" || fail "bytes_out total 150 missing: $(cat "${WORK}/out")"
grep -qw 3 "${WORK}/out" || fail "tool_calls total 3 missing: $(cat "${WORK}/out")"
grep -qw 15 "${WORK}/out" || fail "elapsed_s total 15 missing: $(cat "${WORK}/out")"
grep -qw 2 "${WORK}/out" || fail "transition count 2 missing: $(cat "${WORK}/out")"
pass "totals: 2 transitions, 150 bytes, 3 calls, 15s"

echo "== output labels the figures as proxies, not tokens =="
grep -qiE "prox(y|ies)" "${WORK}/out" || fail "output must label the figures as proxies: $(cat "${WORK}/out")"
pass "figures labelled as proxies"

echo "== two-run delta carries sign and percentage =="
{ line 0 50 1 2; line 1 25 1 3; } > "${WORK}/b.jsonl"   # 75 bytes, 2 calls, 5s
run "${WORK}/b.jsonl" "${WORK}/a.jsonl"                  # new=b, baseline=a
[ "${RC}" -eq 0 ] || fail "two-run compare must exit 0, got ${RC}: $(cat "${WORK}/out")"
grep -q -- '-75' "${WORK}/out" || fail "absolute delta -75 missing: $(cat "${WORK}/out")"
grep -q '50' "${WORK}/out" || fail "percentage -50% missing: $(cat "${WORK}/out")"
pass "delta -75 bytes and -50% reported"

echo "== a zero baseline field prints n/a, not a bogus percentage =="
printf '{"ts":"2026-07-30T10:00:00Z","task":"z","state":"completed","cost":{"bytes_out":0,"tool_calls":0,"elapsed_s":0}}\n' > "${WORK}/zero.jsonl"
run "${WORK}/a.jsonl" "${WORK}/zero.jsonl"
[ "${RC}" -eq 0 ] || fail "zero baseline must not crash, got ${RC}: $(cat "${WORK}/out")"
grep -qi 'n/a' "${WORK}/out" || fail "a zero baseline must print n/a: $(cat "${WORK}/out")"
pass "zero baseline → n/a instead of a fake percentage"

echo "== lines with no cost object are UNMEASURED, never zero =="
{ line 0 100 2 5
  printf '{"ts":"2026-07-30T10:05:00Z","task":"old","state":"completed"}\n'; } > "${WORK}/mixed.jsonl"
run "${WORK}/mixed.jsonl"
[ "${RC}" -eq 0 ] || fail "mixed file must exit 0, got ${RC}"
grep -qi unmeasured "${WORK}/out" || fail "a line without cost must be reported unmeasured: $(cat "${WORK}/out")"
grep -q 100 "${WORK}/out" || fail "the measured line must still total: $(cat "${WORK}/out")"
pass "1 unmeasured transition reported, not counted as 0"

echo "== a tokens key warns: the field is banned by design =="
{ line 0 100 2 5
  printf '{"ts":"2026-07-30T10:06:00Z","task":"t","state":"completed","cost":{"bytes_out":10,"tool_calls":1,"elapsed_s":1},"tokens":4200}\n'; } > "${WORK}/tok.jsonl"
run "${WORK}/tok.jsonl"
grep -qi 'token' "${WORK}/out" || fail "a tokens key must be called out: $(cat "${WORK}/out")"
pass "tokens key → loud warning"

echo "== malformed lines are skipped and counted =="
{ line 0 100 2 5; echo 'not json at all'; } > "${WORK}/bad.jsonl"
run "${WORK}/bad.jsonl"
[ "${RC}" -eq 0 ] || fail "one bad line among good ones must not abort, got ${RC}"
grep -qi 'skip' "${WORK}/out" || fail "skipped lines must be reported: $(cat "${WORK}/out")"
run <(echo 'garbage') 2>/dev/null || true
printf 'garbage\n' > "${WORK}/allbad.jsonl"
run "${WORK}/allbad.jsonl"
[ "${RC}" -ne 0 ] || fail "a file with no usable line must fail"
pass "bad line skipped + counted; all-bad file fails"

echo "== missing and empty input fail clearly =="
run "${WORK}/nope.jsonl"
[ "${RC}" -ne 0 ] || fail "missing file must fail"
grep -qi 'no such\|not found\|cannot read' "${WORK}/out" || fail "missing file needs a clear message: $(cat "${WORK}/out")"
: > "${WORK}/empty.jsonl"
run "${WORK}/empty.jsonl"
[ "${RC}" -ne 0 ] || fail "empty file must fail"
grep -qi 'no transitions\|empty' "${WORK}/out" || fail "empty file needs a clear message: $(cat "${WORK}/out")"
pass "missing → clear error; empty → clear error"

echo "ALL PASS"
