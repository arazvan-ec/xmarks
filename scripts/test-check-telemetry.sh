#!/usr/bin/env bash
# flywheel — test for scripts/check-telemetry.sh (P42). The gate that notices
# when a cycle ships without telemetry. Covers: conforming telemetry passes; a
# line missing the contract keys fails; a `tokens` key fails (P18); a spec with
# neither telemetry nor a baseline entry fails and is NAMED; a baselined spec
# passes; a baseline entry carrying no reason is unusable input; `.plan.md` is
# not a spec; the skip is logged; and the real repo is green.

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="${SRC}/scripts/check-telemetry.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

# repo <name> -> a throwaway tree with the flywheel state dirs
repo() {
  local r="${WORK}/$1"
  mkdir -p "${r}/.claude/flywheel/specs" "${r}/.claude/flywheel/runs" "${r}/scripts"
  : > "${r}/scripts/telemetry-baseline.txt"
  printf '%s\n' "${r}"
}
spec() { printf '# Spec\n' > "$1/.claude/flywheel/specs/$2.md"; }
# telemetry <root> <slug> <line-json>
telemetry() {
  mkdir -p "$1/.claude/flywheel/runs/$2"
  printf '%s\n' "$3" > "$1/.claude/flywheel/runs/$2/2026-09-15.jsonl"
}
GOOD='{"ts":"2026-09-15T10:00:00Z","task":"T1","state":"completed","route":"sonnet/medium","cost":{"bytes_out":10,"bytes_in":20,"tool_calls":1,"elapsed_s":2}}'

run() { RC=0; bash "${GATE}" "$@" >"${WORK}/out" 2>&1 || RC=$?; }

echo "== conforming telemetry passes =="
R="$(repo ok)"; spec "${R}" alpha; telemetry "${R}" alpha "${GOOD}"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a covered spec must pass, got ${RC}: $(cat "${WORK}/out")"
pass "covered spec passes"

echo "== a line missing the contract keys fails =="
R="$(repo badline)"; spec "${R}" alpha
telemetry "${R}" alpha '{"phase":"spec","state":"completed","note":"hand-written"}'
run "${R}"
[ "${RC}" -eq 1 ] || fail "a non-conforming line must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q "ts" "${WORK}/out" || fail "the report must name the missing key: $(cat "${WORK}/out")"
pass "non-conforming line exits 1 and names the missing key"

echo "== a tokens key fails (P18) =="
R="$(repo tok)"; spec "${R}" alpha
telemetry "${R}" alpha '{"ts":"2026-09-15T10:00:00Z","state":"completed","cost":{"bytes_out":1,"tokens":4200}}'
run "${R}"
[ "${RC}" -eq 1 ] || fail "a tokens key must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -qi "tokens" "${WORK}/out" || fail "the report must name the tokens key: $(cat "${WORK}/out")"
pass "tokens key exits 1"

echo "== a spec with no telemetry and no baseline entry fails, and is named =="
R="$(repo uncovered)"; spec "${R}" alpha; telemetry "${R}" alpha "${GOOD}"; spec "${R}" orphan
run "${R}"
[ "${RC}" -eq 1 ] || fail "an uncovered spec must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q "orphan" "${WORK}/out" || fail "the uncovered spec must be named: $(cat "${WORK}/out")"
pass "uncovered spec exits 1 and is named"

echo "== a baselined spec passes, and the debt is stated =="
printf 'orphan  shipped before the duty had a running owner (P42)\n' >> "${R}/scripts/telemetry-baseline.txt"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a baselined spec must pass, got ${RC}: $(cat "${WORK}/out")"
grep -qiE "1 .*(exempt|baselin|debt)" "${WORK}/out" \
  || fail "the gate must state the size of the debt, not hide it: $(cat "${WORK}/out")"
pass "baselined spec passes and the debt is counted"

echo "== a baseline entry with no reason is unusable input =="
R="$(repo noreason)"; spec "${R}" alpha; telemetry "${R}" alpha "${GOOD}"; spec "${R}" orphan
printf 'orphan\n' >> "${R}/scripts/telemetry-baseline.txt"
run "${R}"
[ "${RC}" -eq 2 ] || fail "a reasonless baseline entry must exit 2, got ${RC}: $(cat "${WORK}/out")"
grep -qi "reason" "${WORK}/out" || fail "the error must say a reason is required: $(cat "${WORK}/out")"
pass "reasonless baseline entry exits 2"

echo "== a .plan.md is not a spec =="
R="$(repo plans)"; spec "${R}" alpha; telemetry "${R}" alpha "${GOOD}"
printf '# Plan\n' > "${R}/.claude/flywheel/specs/alpha.plan.md"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a .plan.md must not demand its own telemetry, got ${RC}: $(cat "${WORK}/out")"
pass ".plan.md is not counted as a spec"

echo "== the skip is logged, never silent =="
R="$(repo skipme)"; spec "${R}" orphan
RC=0; SKIP_TELEMETRY_CHECK=1 bash "${GATE}" "${R}" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 0 ] || fail "the skip must exit 0, got ${RC}"
grep -qi "skip" "${WORK}/out" || fail "the skip must announce itself: $(cat "${WORK}/out")"
pass "skip exits 0 with a logged notice"

echo "== a baselined slug's non-conforming lines are a notice, not a failure =="
R="$(repo exemptbad)"; spec "${R}" alpha; telemetry "${R}" alpha "${GOOD}"; spec "${R}" legacy
telemetry "${R}" legacy '{"phase":"spec","state":"completed","note":"hand-written"}'
printf 'legacy  its runs/ file predates the contract\n' >> "${R}/scripts/telemetry-baseline.txt"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a baselined slug's old shape must not fail the gate forever, got ${RC}: $(cat "${WORK}/out")"
grep -qi "legacy" "${WORK}/out" || fail "the notice must still name it — exempt is not invisible: $(cat "${WORK}/out")"
pass "baselined non-conforming lines are a notice"

echo "== but a tokens key fails even on a baselined slug (P18 has no exemption) =="
R="$(repo exempttok)"; spec "${R}" alpha; telemetry "${R}" alpha "${GOOD}"; spec "${R}" legacy
telemetry "${R}" legacy '{"ts":"2026-09-15T10:00:00Z","state":"completed","cost":{"tokens":4200}}'
printf 'legacy  its runs/ file predates the contract\n' >> "${R}/scripts/telemetry-baseline.txt"
run "${R}"
[ "${RC}" -eq 1 ] || fail "a tokens field must fail regardless of the baseline, got ${RC}: $(cat "${WORK}/out")"
grep -qi "tokens" "${WORK}/out" || fail "the failure must name the tokens field: $(cat "${WORK}/out")"
pass "tokens is never exempt"

echo "== the real repo is green =="
run "${SRC}"
[ "${RC}" -eq 0 ] || fail "this repo must pass its own telemetry gate, got ${RC}: $(cat "${WORK}/out")"
pass "flywheel's own tree passes"

echo "ALL PASS"
