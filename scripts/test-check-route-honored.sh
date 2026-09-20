#!/usr/bin/env bash
# flywheel — test for scripts/check-route-honored.sh (P49). The gate that asks
# whether the ladder a plan bought is the one the run recorded. Covers: a plan
# task with no transition line; a transition above its planned tier with and
# without `route_escalated_from`; a merged range reported, never read as drift;
# a route the tier ladder cannot rank reported, never read as honored; a
# transition that maps to no plan task ignored; pre-cutoff findings counted but
# never fatal (nothing may be backfilled, P18); unusable input exits 2; the skip
# is logged; and the real repo is green.

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="${SRC}/scripts/check-route-honored.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

# repo <name> -> a throwaway tree with the flywheel state dirs
repo() {
  local r="${WORK}/$1"
  mkdir -p "${r}/.claude/flywheel/specs" "${r}/.claude/flywheel/runs"
  printf '%s\n' "${r}"
}

# plan <root> <slug> <route-per-task...> — T1..Tn in order, T1 carries risk: highest
plan() {
  local r="$1" slug="$2"; shift 2
  local f="${r}/.claude/flywheel/specs/${slug}.plan.md" n=0
  printf '# Plan\n\n' > "${f}"
  for route in "$@"; do
    n=$((n + 1))
    printf '### T%s — task %s\n\n- route: `%s`\n- check: `true`\n%s\n' \
      "${n}" "${n}" "${route}" "$([ "${n}" -eq 1 ] && echo '- risk: highest')" >> "${f}"
  done
}

# line <root> <slug> <task> <route> <ts> [escalated-from]
line() {
  local esc=""
  [ -n "${6:-}" ] && esc=",\"route_escalated_from\":\"$6\""
  mkdir -p "$1/.claude/flywheel/runs/$2"
  printf '{"ts":"%s","task":"%s","phase":"work","state":"completed","route":"%s"%s,"cost":{"bytes_out":1}}\n' \
    "$5" "$3" "$4" "${esc}" >> "$1/.claude/flywheel/runs/$2/2026-09-18.jsonl"
}

POST="2026-09-18T10:00:00Z"   # after the cutoff
PRE="2026-09-15T10:00:00Z"    # before it

run() { RC=0; bash "${GATE}" "$@" >"${WORK}/out" 2>&1 || RC=$?; }

echo "== a plan whose every task is recorded at its route passes =="
R="$(repo honored)"; plan "${R}" alpha "opus/high" "sonnet/medium"
line "${R}" alpha T1 "opus/high" "${POST}"; line "${R}" alpha T2 "sonnet/medium" "${POST}"
run "${R}"
[ "${RC}" -eq 0 ] || fail "an honored plan must pass, got ${RC}: $(cat "${WORK}/out")"
pass "an honored plan passes"

echo "== a plan task with no transition line fails, and is NAMED =="
R="$(repo unrecorded)"; plan "${R}" alpha "opus/high" "haiku/low+delegate"
line "${R}" alpha T1 "opus/high" "${POST}"
run "${R}"
[ "${RC}" -eq 1 ] || fail "an unrecorded task must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q "T2" "${WORK}/out" || fail "the unrecorded task must be named: $(cat "${WORK}/out")"
pass "an unrecorded plan task exits 1 and is named"

echo "== absence is reported as unrecorded, never as a wrong tier =="
# The ledger cannot tell "ran and wrote nothing" from "never ran". A gate that
# claimed to know which would be inventing the evidence it exists to protect.
grep -qiE "unrecorded|no transition line|never ran|no line" "${WORK}/out" \
  || fail "the finding must say the line is absent, not that a tier was wrong: $(cat "${WORK}/out")"
grep -qiE "ran (above|below)" "${WORK}/out" && fail "absence must not be attributed to a tier: $(cat "${WORK}/out")"
pass "absence is reported as absence"

echo "== a transition above its planned tier with no escalation record fails =="
R="$(repo above)"; plan "${R}" alpha "opus/high" "sonnet/medium"
line "${R}" alpha T1 "opus/high" "${POST}"; line "${R}" alpha T2 "opus/high" "${POST}"
run "${R}"
[ "${RC}" -eq 1 ] || fail "an unrecorded upgrade must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q "T2" "${WORK}/out" || fail "the drifting task must be named: $(cat "${WORK}/out")"
pass "running above the plan without saying so exits 1"

echo "== the same transition passes once it records the escalation =="
R="$(repo escalated)"; plan "${R}" alpha "opus/high" "sonnet/medium"
line "${R}" alpha T1 "opus/high" "${POST}"
line "${R}" alpha T2 "opus/high" "${POST}" "sonnet/medium"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a recorded escalation must pass, got ${RC}: $(cat "${WORK}/out")"
pass "route_escalated_from is what makes an upgrade honest"

echo "== a merged range covers its tasks and is reported, not failed =="
R="$(repo merged)"; plan "${R}" alpha "opus/high" "sonnet/medium"
line "${R}" alpha T1-T2 "opus/high" "${POST}"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a merge is a notice, not a failure, got ${RC}: $(cat "${WORK}/out")"
grep -qiE "merge|covers|absorb" "${WORK}/out" || fail "the merge must be reported: $(cat "${WORK}/out")"
grep -q "T2" "${WORK}/out" || fail "the absorbed task must be named: $(cat "${WORK}/out")"
pass "a merge is reported and its cheaper task named"

echo "== a route the ladder cannot rank is reported, never read as honored =="
# The fixture must use an effort the ladder genuinely lacks. It used to say
# `xhigh`, which v0.67.0 added — a stale fixture turns a live assertion into a
# different one without anyone editing the assertion.
R="$(repo unrankable)"; plan "${R}" alpha "opus/high"
line "${R}" alpha T1 "opus/turbo" "${POST}"
run "${R}"
grep -qiE "rank" "${WORK}/out" || fail "an unrankable route must be reported: $(cat "${WORK}/out")"
grep -qi "turbo" "${WORK}/out" || fail "the unrankable route must be quoted: $(cat "${WORK}/out")"
pass "an unrankable route is reported"

echo "== a transition that maps to no plan task is ignored, not blamed =="
R="$(repo prephase)"; plan "${R}" alpha "opus/high"
line "${R}" alpha T1 "opus/high" "${POST}"; line "${R}" alpha spec "opus/high" "${POST}"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a spec/plan transition has no route to honor, got ${RC}: $(cat "${WORK}/out")"
pass "a transition preceding the plan is not compared"

echo "== a bare integer task id maps to T<n> (work's executor writes {\"task\": 3}) =="
R="$(repo inttask)"; plan "${R}" alpha "opus/high"
mkdir -p "${R}/.claude/flywheel/runs/alpha"
printf '{"ts":"%s","task":1,"phase":"work","state":"completed","route":"opus/high","cost":{"bytes_out":1}}\n' \
  "${POST}" > "${R}/.claude/flywheel/runs/alpha/2026-09-18.jsonl"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a numeric task id must map to T1, got ${RC}: $(cat "${WORK}/out")"
pass "a numeric task id maps to its plan task"

echo "== before the cutoff the same findings are COUNTED, never fatal =="
R="$(repo precut)"; plan "${R}" alpha "opus/high" "sonnet/medium"
line "${R}" alpha T1 "opus/high" "${PRE}"; line "${R}" alpha T2 "opus/high" "${PRE}"
run "${R}"
[ "${RC}" -eq 0 ] || fail "pre-cutoff drift must not fail the gate, got ${RC}: $(cat "${WORK}/out")"
grep -qiE "[0-9]+ .*(predate|pre-cutoff|before)" "${WORK}/out" \
  || fail "the pre-cutoff debt must be counted: $(cat "${WORK}/out")"
pass "pre-cutoff findings are counted, not fatal"

echo "== an unrecorded task is dated by the cycle's newest line =="
R="$(repo precutgap)"; plan "${R}" alpha "opus/high" "sonnet/medium"
line "${R}" alpha T1 "opus/high" "${PRE}"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a gap in a pre-cutoff cycle must not fail, got ${RC}: $(cat "${WORK}/out")"
pass "a gap is dated by the record that exists"

echo "== a slug with telemetry and no plan is not a finding =="
R="$(repo noplan)"; line "${R}" solo T1 "opus/high" "${POST}"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a standalone run has no plan to honor, got ${RC}: $(cat "${WORK}/out")"
pass "no plan, nothing to compare"

echo "== a plan the linter rejects is unusable input, not a pass =="
R="$(repo badplan)"; printf '# Plan\n\n### T1 — no route\n\n- check: `true`\n' \
  > "${R}/.claude/flywheel/specs/alpha.plan.md"
line "${R}" alpha T1 "opus/high" "${POST}"
run "${R}"
[ "${RC}" -eq 2 ] || fail "an unlintable plan must exit 2, got ${RC}: $(cat "${WORK}/out")"
pass "an unlintable plan exits 2"

echo "== the skip is logged, never silent =="
R="$(repo skipme)"; plan "${R}" alpha "opus/high"
RC=0; SKIP_ROUTE_CHECK="not now" bash "${GATE}" "${R}" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 0 ] || fail "the skip must exit 0, got ${RC}"
grep -qi "skip" "${WORK}/out" || fail "the skip must announce itself: $(cat "${WORK}/out")"
pass "skip exits 0 with a logged notice"

echo "== a record that drops a planned +delegate is a finding (P53/Codex) =="
# The plan bought delegation and the record does not show it. Not "above" or
# "below" — a different axis, and the one P41/P49 exist to track.
R="$(repo lostdelegate)"; plan "${R}" alpha "opus/high" "haiku/low+delegate"
line "${R}" alpha T1 "opus/high" "${POST}"; line "${R}" alpha T2 "haiku/low" "${POST}"
run "${R}"
[ "${RC}" -eq 1 ] || fail "a dropped +delegate must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q "T2" "${WORK}/out" || fail "the task must be named: $(cat "${WORK}/out")"
grep -qi "delegat" "${WORK}/out" || fail "the finding must say what was lost: $(cat "${WORK}/out")"
pass "a lost delegation is reported, not read as honored"

echo "== the same transition passes once the record carries the suffix =="
R="$(repo keptdelegate)"; plan "${R}" alpha "opus/high" "haiku/low+delegate"
line "${R}" alpha T1 "opus/high" "${POST}"; line "${R}" alpha T2 "haiku/low+delegate" "${POST}"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a recorded delegation must pass, got ${RC}: $(cat "${WORK}/out")"
pass "the suffix recorded is the suffix honored"

echo "== delegating where the plan did not ask is a notice, not a failure =="
# Paying for less than you were allowed is not a defect.
R="$(repo extradelegate)"; plan "${R}" alpha "opus/high" "haiku/low"
line "${R}" alpha T1 "opus/high" "${POST}"; line "${R}" alpha T2 "haiku/low+delegate" "${POST}"
run "${R}"
[ "${RC}" -eq 0 ] || fail "extra delegation must not fail, got ${RC}: $(cat "${WORK}/out")"
pass "extra delegation is not a finding"

echo "== a plan with no run directory is named, never silently skipped =="
R="$(repo noruns)"; plan "${R}" alpha "opus/high"
plan "${R}" ghost "opus/high" "sonnet/medium"
line "${R}" alpha T1 "opus/high" "${POST}"
run "${R}"
grep -q "ghost" "${WORK}/out" || fail "a plan with no run dir must be named: $(cat "${WORK}/out")"
pass "an uncompared plan is named"

echo "== an EMPTY run directory counts as no record either =="
R="$(repo emptyruns)"; plan "${R}" alpha "opus/high"; plan "${R}" hollow "opus/high"
line "${R}" alpha T1 "opus/high" "${POST}"
mkdir -p "${R}/.claude/flywheel/runs/hollow"
run "${R}"
grep -q "hollow" "${WORK}/out" || fail "an empty run dir must be named too: $(cat "${WORK}/out")"
pass "an empty run directory is an uncompared plan"

echo "== the real repo is green =="
run "${SRC}"
[ "${RC}" -eq 0 ] || fail "this repo must pass its own route gate, got ${RC}: $(cat "${WORK}/out")"
grep -qiE "p4[23]" "${WORK}/out" || fail "the historical drift must still be reported: $(cat "${WORK}/out")"
pass "flywheel's own tree passes, with its debt named"

echo "ALL PASS"
