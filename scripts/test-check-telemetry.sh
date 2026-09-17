#!/usr/bin/env bash
# flywheel — test for scripts/check-telemetry.sh (P42). The gate that notices
# when a cycle ships without telemetry. Covers: conforming telemetry passes; a
# line missing the contract keys fails; a `tokens` key fails (P18); a spec with
# neither telemetry nor a baseline entry fails and is NAMED; a baselined spec
# passes; a baseline entry carrying no reason is unusable input; `.plan.md` is
# not a spec; the skip is logged; and the real repo is green.
# P48: a line written after the cutoff names its phase; before it, the same line
# is a counted notice — the corpus predates the rule and nothing may be backfilled.

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

echo "== a tokens field is checked BEFORE shape, so a broken line cannot smuggle it =="
R="$(repo tokfirst)"; spec "${R}" alpha; telemetry "${R}" alpha "${GOOD}"; spec "${R}" legacy
telemetry "${R}" legacy '{"state":"completed","tokens":123}'
printf 'legacy  its runs/ file predates the contract\n' >> "${R}/scripts/telemetry-baseline.txt"
run "${R}"
[ "${RC}" -eq 1 ] || fail "a malformed line carrying tokens must still fail on a baselined slug, got ${RC}: $(cat "${WORK}/out")"
grep -qi "tokens" "${WORK}/out" || fail "the tokens ban must be what reports: $(cat "${WORK}/out")"
pass "tokens is checked before shape, never skipped by a shape exemption"

echo "== a present-but-empty key does not count as a key =="
R="$(repo emptykeys)"; spec "${R}" alpha
telemetry "${R}" alpha '{"ts":null,"state":[],"task":"T1","cost":{"bytes_out":1}}'
run "${R}"
[ "${RC}" -eq 1 ] || fail "ts=null / state=[] must fail, got ${RC}: $(cat "${WORK}/out")"
pass "null/empty values are not values"

echo "== a transition that identifies nothing fails (no task and no phase) =="
R="$(repo noid)"; spec "${R}" alpha
telemetry "${R}" alpha '{"ts":"2026-09-15T10:00:00Z","state":"completed","cost":{"bytes_out":1}}'
run "${R}"
[ "${RC}" -eq 1 ] || fail "a line naming no task or phase must fail, got ${RC}: $(cat "${WORK}/out")"
pass "a transition must say which transition it is"

echo "== a numeric task id identifies a transition (plan tasks are numbered) =="
# work's plan tasks are numbered, and its own executor writes {"task": 3}.
# Demanding a string here would have made CI reject the lines the skill produces.
R="$(repo numtask)"; spec "${R}" alpha
telemetry "${R}" alpha '{"ts":"2026-09-15T10:00:00Z","state":"completed","task":3,"cost":{"bytes_out":1}}'
run "${R}"
[ "${RC}" -eq 0 ] || fail "a numeric task id must identify a transition, got ${RC}: $(cat "${WORK}/out")"
pass "task may be a plan task number, not only a name"

echo "== but a boolean is not an id =="
R="$(repo booltask)"; spec "${R}" alpha
telemetry "${R}" alpha '{"ts":"2026-09-15T10:00:00Z","state":"completed","task":true,"cost":{"bytes_out":1}}'
run "${R}"
[ "${RC}" -eq 1 ] || fail "task=true must not identify a transition, got ${RC}: $(cat "${WORK}/out")"
pass "a boolean task is not an identifier"

echo "== phase satisfies identification too (pillar 2 runs are Rule-based) =="
R="$(repo phaseok)"; spec "${R}" alpha
telemetry "${R}" alpha '{"ts":"2026-09-15T10:00:00Z","state":"completed","phase":"spec","cost":{"elapsed_s":3}}'
run "${R}"
[ "${RC}" -eq 0 ] || fail "phase must satisfy identification, got ${RC}: $(cat "${WORK}/out")"
pass "phase is accepted where task would be"

echo "== a transition that measures nothing fails =="
R="$(repo nocost)"; spec "${R}" alpha
telemetry "${R}" alpha '{"ts":"2026-09-15T10:00:00Z","state":"completed","task":"T1"}'
run "${R}"
[ "${RC}" -eq 1 ] || fail "a line with no cost object must fail, got ${RC}: $(cat "${WORK}/out")"
telemetry "${R}" alpha '{"ts":"2026-09-15T10:00:00Z","state":"completed","task":"T1","cost":{"note":"n/a"}}'
run "${R}"
[ "${RC}" -eq 1 ] || fail "a cost object with no numeric proxy must fail, got ${RC}: $(cat "${WORK}/out")"
pass "cost must carry at least one numeric proxy"

echo "== a line written after the cutoff must name its phase (P48) =="
R="$(repo nophase)"; spec "${R}" alpha
telemetry "${R}" alpha '{"ts":"2026-09-18T10:00:00Z","state":"completed","task":3,"cost":{"bytes_out":1}}'
run "${R}"
[ "${RC}" -eq 1 ] || fail "a post-cutoff line with no phase must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -qi "phase" "${WORK}/out" || fail "the failure must name phase: $(cat "${WORK}/out")"
pass "post-cutoff line with no phase exits 1"

echo "== the same line with a phase passes =="
telemetry "${R}" alpha '{"ts":"2026-09-18T10:00:00Z","state":"completed","task":3,"phase":"work","cost":{"bytes_out":1}}'
run "${R}"
[ "${RC}" -eq 0 ] || fail "a post-cutoff line naming its phase must pass, got ${RC}: $(cat "${WORK}/out")"
pass "phase satisfies the rule"

echo "== an empty phase is not a phase =="
telemetry "${R}" alpha '{"ts":"2026-09-18T10:00:00Z","state":"completed","task":3,"phase":"   ","cost":{"bytes_out":1}}'
run "${R}"
[ "${RC}" -eq 1 ] || fail "phase='   ' must not satisfy the rule, got ${RC}: $(cat "${WORK}/out")"
pass "a blank phase does not count"

echo "== before the cutoff a phase-less line passes, and is COUNTED =="
# Nothing may be backfilled (P18), so the corpus that predates the rule is a
# debt to report, never a failure to fix. Silent would be the same as absent.
R="$(repo precutoff)"; spec "${R}" alpha
telemetry "${R}" alpha '{"ts":"2026-09-15T10:00:00Z","state":"completed","task":3,"cost":{"bytes_out":1}}'
run "${R}"
[ "${RC}" -eq 0 ] || fail "a pre-cutoff phase-less line must not fail, got ${RC}: $(cat "${WORK}/out")"
grep -qiE "1 .*phase" "${WORK}/out" || fail "the pre-cutoff debt must be counted: $(cat "${WORK}/out")"
pass "pre-cutoff lines pass and their count is stated"

echo "== the cutoff is overridable, and moving it back reddens the same line =="
R="$(repo cutoffenv)"; spec "${R}" alpha
telemetry "${R}" alpha '{"ts":"2026-09-15T10:00:00Z","state":"completed","task":3,"cost":{"bytes_out":1}}'
RC=0; FLYWHEEL_PHASE_REQUIRED_FROM=2026-01-01T00:00:00Z bash "${GATE}" "${R}" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 1 ] || fail "the same line must fail under an earlier cutoff, got ${RC}: $(cat "${WORK}/out")"
pass "the cutoff is one constant, and it is what decides"

echo "== a baselined slug's post-cutoff phase-less line is a notice, not a failure =="
R="$(repo exemptphase)"; spec "${R}" alpha
telemetry "${R}" alpha '{"ts":"2026-09-18T10:00:00Z","state":"completed","task":3,"phase":"work","cost":{"bytes_out":1}}'
spec "${R}" legacy
telemetry "${R}" legacy '{"ts":"2026-09-18T10:00:00Z","state":"completed","task":3,"cost":{"bytes_out":1}}'
printf 'legacy  its runs/ file predates the contract\n' >> "${R}/scripts/telemetry-baseline.txt"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a baselined slug must not fail on shape, got ${RC}: $(cat "${WORK}/out")"
grep -qi "legacy" "${WORK}/out" || fail "the notice must name it: $(cat "${WORK}/out")"
pass "the phase rule routes through the baseline like every other shape rule"

echo "== by_tool is not a numeric proxy (P50) =="
# A dict of per-tool bytes is a breakdown, not a measurement of the transition:
# a cost object carrying only it has still measured nothing.
R="$(repo bytool)"; spec "${R}" alpha
telemetry "${R}" alpha '{"ts":"2026-09-18T10:00:00Z","state":"completed","task":3,"phase":"work","cost":{"by_tool":{"Bash":{"bytes":10,"calls":1}}}}'
run "${R}"
[ "${RC}" -eq 1 ] || fail "a cost object of only by_tool must fail, got ${RC}: $(cat "${WORK}/out")"
telemetry "${R}" alpha '{"ts":"2026-09-18T10:00:00Z","state":"completed","task":3,"phase":"work","cost":{"max_read":10,"by_tool":{"Bash":{"bytes":10,"calls":1}}}}'
run "${R}"
[ "${RC}" -eq 0 ] || fail "max_read alongside it is a numeric proxy, got ${RC}: $(cat "${WORK}/out")"
pass "by_tool alone does not satisfy the cost rule; max_read does"

echo "== the real repo is green =="
run "${SRC}"
[ "${RC}" -eq 0 ] || fail "this repo must pass its own telemetry gate, got ${RC}: $(cat "${WORK}/out")"
pass "flywheel's own tree passes"

echo "ALL PASS"
