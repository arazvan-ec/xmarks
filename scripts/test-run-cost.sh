#!/usr/bin/env bash
# flywheel — test for scripts/run-cost.sh (P23), the two-run cost comparison over
# telemetry JSONL. Covers: single-run totals; two-run delta with sign and
# percentage; a zero baseline field prints n/a instead of a bogus percentage;
# lines with no cost object are reported as UNMEASURED, never as zero; a
# `tokens` key warns (the field is banned by design, P18); malformed lines are
# skipped and counted; missing/empty input fails with a clear error.
# P48: --all rolls the whole corpus up — cycles named and counted, totals grouped
# by phase, phase-less lines bucketed apart, and the per-FIELD coverage discipline
# carried through the merge so an absent field never totals as 0.

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

# rline <ts> <bytes> <calls> <elapsed> <route> [escalated-from]
rline() {
  local esc=""
  [ -n "${6:-}" ] && esc=",\"route_escalated_from\":\"$6\""
  printf '{"ts":"2026-07-30T10:%02d:00Z","task":"t%s","state":"completed","route":"%s"%s,"cost":{"bytes_out":%s,"tool_calls":%s,"elapsed_s":%s}}\n' \
    "$1" "$1" "$5" "${esc}" "$2" "$3" "$4"
}

# bline <ts> <bytes_out> <bytes_in> <calls> <elapsed> [route]
bline() {
  local route=""
  [ -n "${6:-}" ] && route=",\"route\":\"$6\""
  printf '{"ts":"2026-07-30T10:%02d:00Z","task":"t%s","state":"completed"%s,"cost":{"bytes_out":%s,"bytes_in":%s,"tool_calls":%s,"elapsed_s":%s}}\n' \
    "$1" "$1" "${route}" "$2" "$3" "$4" "$5"
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

echo "== cost proxies are grouped by route (P27) =="
{ rline 0 100 2 5 "sonnet/medium"; rline 1 50 1 10 "sonnet/medium"
  rline 2 20 1 1 "haiku/low+delegate"; } > "${WORK}/r.jsonl"
run "${WORK}/r.jsonl"
[ "${RC}" -eq 0 ] || fail "routed run must exit 0, got ${RC}: $(cat "${WORK}/out")"
grep -qE "sonnet/medium.*150" "${WORK}/out" || fail "sonnet bucket must total 150 bytes: $(cat "${WORK}/out")"
grep -qE "haiku/low\+delegate.*20" "${WORK}/out" || fail "haiku bucket must total 20 bytes: $(cat "${WORK}/out")"
pass "per-route totals: sonnet/medium 150, haiku/low+delegate 20"

echo "== a transition with no route is reported, never folded into one =="
{ rline 0 100 2 5 "sonnet/medium"; line 1 50 1 10; } > "${WORK}/mixed.jsonl"
run "${WORK}/mixed.jsonl"
grep -qi "no route" "${WORK}/out" || fail "unrouted transitions must be named: $(cat "${WORK}/out")"
pass "unrouted transition reported, not bucketed"

echo "== escalations are counted with their from → to pair =="
{ rline 0 10 1 1 "haiku/low+delegate"; rline 1 20 1 1 "sonnet/medium" "haiku/low+delegate"; } > "${WORK}/esc.jsonl"
run "${WORK}/esc.jsonl"
[ "${RC}" -eq 0 ] || fail "escalation run must exit 0, got ${RC}: $(cat "${WORK}/out")"
grep -qiE "escalation.*1 of 2" "${WORK}/out" || fail "escalation count/rate missing: $(cat "${WORK}/out")"
grep -qE "haiku/low\+delegate.*(→|->).*sonnet/medium" "${WORK}/out" || fail "the from → to pair must be shown: $(cat "${WORK}/out")"
pass "1 of 2 routed transitions escalated, pair shown"

echo "== zero escalations is stated, not omitted (the tiers held is evidence too) =="
run "${WORK}/r.jsonl"
grep -qiE "escalations: 0" "${WORK}/out" || fail "a run with no escalation must say so: $(cat "${WORK}/out")"
pass "escalations: 0 stated explicitly"

echo "== the delta reports the change in escalations =="
run "${WORK}/esc.jsonl" "${WORK}/r.jsonl"
[ "${RC}" -eq 0 ] || fail "compare must exit 0, got ${RC}: $(cat "${WORK}/out")"
grep -qiE "escalations .*[+-][0-9]" "${WORK}/out" || fail "delta must carry a signed escalation change: $(cat "${WORK}/out")"
pass "delta names the escalation change"

echo "== a tokens key on a routed line still warns, and never enters the bucket =="
printf '{"ts":"2026-07-30T10:00:00Z","task":"t0","state":"completed","route":"opus/high","cost":{"bytes_out":7,"tool_calls":1,"elapsed_s":1,"tokens":99999}}\n' > "${WORK}/rtok.jsonl"
run "${WORK}/rtok.jsonl"
[ "${RC}" -eq 0 ] || fail "a tokens key must warn, not fail: ${RC}"
grep -qi "WARNING" "${WORK}/out" || fail "a tokens key on a routed line must still warn (P18): $(cat "${WORK}/out")"
grep -q "99999" "${WORK}/out" && fail "the tokens value must never be reported: $(cat "${WORK}/out")"
grep -qE "opus/high.*7 bytes" "${WORK}/out" || fail "the route bucket must total only the proxies: $(cat "${WORK}/out")"
pass "tokens key warns; route bucket carries proxies only"

# --- P40a: bytes_in, the read-volume proxy ----------------------------------
# The trap these cases exist for: every run written before this field has a cost
# object with three keys and no bytes_in. Totalling those as 0 would make any
# pre-P40 baseline look like it read nothing, and fabricate an improvement for
# the very optimization this proxy was added to judge.

echo "== bytes_in totals like the other proxies =="
{ bline 0 100 900 2 5; bline 1 50 100 1 10; } > "${WORK}/bi.jsonl"
run "${WORK}/bi.jsonl"
[ "${RC}" -eq 0 ] || fail "a run with bytes_in must exit 0, got ${RC}: $(cat "${WORK}/out")"
grep -qE "bytes_in.*1,000" "${WORK}/out" || fail "bytes_in total 1,000 missing: $(cat "${WORK}/out")"
pass "bytes_in totals 1,000"

echo "== a pre-P40 run reports bytes_in UNMEASURED, never 0 =="
{ line 0 100 2 5; line 1 50 1 10; } > "${WORK}/old.jsonl"
run "${WORK}/old.jsonl"
[ "${RC}" -eq 0 ] || fail "a pre-P40 run must still exit 0, got ${RC}: $(cat "${WORK}/out")"
grep -qi "bytes_in.*unmeasured" "${WORK}/out" \
  || fail "bytes_in must be reported UNMEASURED on a pre-P40 run: $(cat "${WORK}/out")"
grep -qE "bytes_in +0 " "${WORK}/out" && fail "bytes_in must never be totalled as 0: $(cat "${WORK}/out")"
grep -q 150 "${WORK}/out" || fail "the three existing fields must still total: $(cat "${WORK}/out")"
pass "bytes_in unmeasured; bytes_out still totals 150"

echo "== partial coverage is stated with its count, not silently averaged =="
{ bline 0 100 900 2 5; line 1 50 1 10; } > "${WORK}/mixed.jsonl"
run "${WORK}/mixed.jsonl"
grep -qiE "bytes_in.*(partial|1 of 2)" "${WORK}/out" \
  || fail "a mixed run must state bytes_in coverage: $(cat "${WORK}/out")"
grep -qE "bytes_in.*900" "${WORK}/out" || fail "the covered line must still be totalled: $(cat "${WORK}/out")"
pass "bytes_in 900 over 1 of 2 transitions, stated"

echo "== the delta REFUSES bytes_in when the baseline never recorded it =="
run "${WORK}/bi.jsonl" "${WORK}/old.jsonl"
[ "${RC}" -eq 0 ] || fail "the comparison must exit 0, got ${RC}: $(cat "${WORK}/out")"
grep -qiE "bytes_in.*(not comparable|no coverage|refus)" "${WORK}/out" \
  || fail "the bytes_in delta must be refused with a reason: $(cat "${WORK}/out")"
grep -qE "bytes_in +\+1,000|bytes_in.*\+100\.0%|bytes_in.*-100\.0%" "${WORK}/out" \
  && fail "a bytes_in delta against an uncovered baseline is a fabricated number: $(cat "${WORK}/out")"
pass "bytes_in delta refused, no fabricated percentage"

echo "== with coverage on both sides the bytes_in delta is reported normally =="
{ bline 0 50 400 1 2; } > "${WORK}/bi2.jsonl"
run "${WORK}/bi2.jsonl" "${WORK}/bi.jsonl"
grep -qE "bytes_in +-600" "${WORK}/out" || fail "bytes_in delta -600 missing: $(cat "${WORK}/out")"
pass "bytes_in delta -600 reported"

echo "== the existing three fields are unaffected by a missing bytes_in =="
run "${WORK}/old.jsonl"
grep -qw 3 "${WORK}/out" || fail "tool_calls total 3 regressed: $(cat "${WORK}/out")"
grep -qw 15 "${WORK}/out" || fail "elapsed_s total 15 regressed: $(cat "${WORK}/out")"
pass "bytes_out/tool_calls/elapsed_s unchanged"

echo "== a route bucket carries bytes_in under the same coverage rule =="
{ bline 0 10 700 1 1 "opus/high"; } > "${WORK}/brt.jsonl"
run "${WORK}/brt.jsonl"
grep -qE "opus/high.*700" "${WORK}/out" || fail "the route bucket must carry bytes_in: $(cat "${WORK}/out")"
pass "route bucket carries bytes_in"

echo "== a route bucket marks a field it only partly covers =="
{ bline 0 10 700 1 1 "opus/high"; rline 1 20 1 1 "opus/high"; } > "${WORK}/prt.jsonl"
run "${WORK}/prt.jsonl"
[ "${RC}" -eq 0 ] || fail "a partly covered bucket must exit 0, got ${RC}: $(cat "${WORK}/out")"
grep -qE "opus/high.*700~" "${WORK}/out" \
  || fail "a bucket covering bytes_in on only some of its transitions must mark it: $(cat "${WORK}/out")"
grep -qE "~.*partial" "${WORK}/out" || fail "the ~ marker needs its legend: $(cat "${WORK}/out")"
pass "partial bucket coverage marked and explained"

# --- P48: the corpus, not one run ------------------------------------------
# pline <ts> <phase> <bytes_out> [route]
pline() {
  local route=""
  [ -n "${4:-}" ] && route=",\"route\":\"$4\""
  printf '{"ts":"2026-09-18T10:%02d:00Z","task":"t%s","phase":"%s","state":"completed"%s,"cost":{"bytes_out":%s,"tool_calls":1,"elapsed_s":2}}\n' \
    "$1" "$1" "$2" "${route}" "$3"
}

echo "== --all totals every run file in the corpus =="
CORPUS="${WORK}/corpus"
mkdir -p "${CORPUS}/alpha" "${CORPUS}/beta"
{ pline 0 spec 100; pline 1 work 200; } > "${CORPUS}/alpha/2026-09-18.jsonl"
{ pline 2 work 300; } > "${CORPUS}/beta/2026-09-18.jsonl"
run --all "${CORPUS}"
[ "${RC}" -eq 0 ] || fail "--all over a real corpus must exit 0, got ${RC}: $(cat "${WORK}/out")"
grep -qE "2 cycles" "${WORK}/out" || fail "--all must count the cycles: $(cat "${WORK}/out")"
grep -qE "3 transitions|transitions: 3" "${WORK}/out" || fail "--all must count the transitions: $(cat "${WORK}/out")"
grep -qE "bytes_out +600" "${WORK}/out" || fail "--all must total across files (600): $(cat "${WORK}/out")"
pass "--all totals the whole corpus"

echo "== --all groups the totals by phase =="
grep -qE "work.*500" "${WORK}/out" || fail "the work phase must total 500 across both cycles: $(cat "${WORK}/out")"
grep -qE "spec.*100" "${WORK}/out" || fail "the spec phase must total 100: $(cat "${WORK}/out")"
pass "by-phase totals cross cycle boundaries"

echo "== --all names each cycle, so 'how many ran' is answerable =="
grep -q "alpha" "${WORK}/out" || fail "each cycle must be named: $(cat "${WORK}/out")"
grep -q "beta" "${WORK}/out" || fail "each cycle must be named: $(cat "${WORK}/out")"
pass "cycles are named, not just counted"

echo "== a phase-less line is bucketed apart, never attributed to a phase =="
mkdir -p "${CORPUS}/gamma"
{ line 3 999 1 1; } > "${CORPUS}/gamma/2026-09-18.jsonl"
run --all "${CORPUS}"
grep -qiE "no phase" "${WORK}/out" || fail "phase-less lines need their own bucket: $(cat "${WORK}/out")"
grep -qE "(work|spec).*999" "${WORK}/out" && fail "a phase-less line must not be attributed: $(cat "${WORK}/out")"
pass "phase-less transitions are reported, not attributed"

echo "== a field no transition carries is UNMEASURED across the corpus, never 0 =="
grep -qE "bytes_in +UNMEASURED" "${WORK}/out" || fail "an absent field must not total as 0: $(cat "${WORK}/out")"
pass "corpus-wide coverage keeps the P40a discipline"

echo "== a field only some cycles carry is marked PARTIAL =="
mkdir -p "${CORPUS}/delta"
{ bline 4 10 700 1 1; } > "${CORPUS}/delta/2026-09-18.jsonl"
run --all "${CORPUS}"
grep -qE "bytes_in.*PARTIAL" "${WORK}/out" || fail "partial corpus coverage must be marked: $(cat "${WORK}/out")"
pass "partial coverage marked across the corpus"

echo "== --all on a path that is not a directory fails loudly =="
run --all "${WORK}/nope"
[ "${RC}" -eq 2 ] || fail "a missing corpus dir must exit 2, got ${RC}: $(cat "${WORK}/out")"
run --all
[ "${RC}" -eq 2 ] || fail "--all with no path must exit 2, got ${RC}: $(cat "${WORK}/out")"
pass "unusable --all input exits 2"

echo "== an empty corpus is not a green 'nothing to report' =="
mkdir -p "${WORK}/empty"
run --all "${WORK}/empty"
[ "${RC}" -eq 2 ] || fail "a corpus with no run files must exit 2, got ${RC}: $(cat "${WORK}/out")"
pass "an empty corpus fails loudly"

echo "== the repo's own corpus reports =="
run --all "${SRC}/.claude/flywheel/runs"
[ "${RC}" -eq 0 ] || fail "flywheel's own corpus must report, got ${RC}: $(cat "${WORK}/out")"
grep -qE "cycles" "${WORK}/out" || fail "the real corpus must report its cycles: $(cat "${WORK}/out")"
pass "flywheel's own corpus rolls up"

echo "ALL PASS"
