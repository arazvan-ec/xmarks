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

# line <root> <slug> <task> <route> <ts> [escalated-from] [route-reason]
line() {
  local esc=""
  [ -n "${6:-}" ] && esc=",\"route_escalated_from\":\"$6\""
  [ -n "${7:-}" ] && esc="${esc},\"route_reason\":\"$7\""
  mkdir -p "$1/.claude/flywheel/runs/$2"
  printf '{"ts":"%s","task":"%s","phase":"work","state":"completed","route":"%s"%s,"cost":{"bytes_out":1}}\n' \
    "$5" "$3" "$4" "${esc}" >> "$1/.claude/flywheel/runs/$2/2026-09-18.jsonl"
}

POST="2026-09-18T10:00:00Z"   # after the cutoff
LATE="2026-09-24T10:00:00Z"   # after the route-reason cutoff too (P55)
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

echo "== a cycle with no line for ANY of its tasks has not started: named, never failed =="
# The loop commits a plan at its APPROVAL gate, before the work. Failing then
# calls every task unrecorded for not having happened yet, and a plan-only
# commit is red by construction. check-task-closure.sh calls this PENDING
# (v0.70.0); this is the same discriminator in the sibling gate.
R="$(repo notstarted)"; plan "${R}" alpha "opus/high" "sonnet/medium"
mkdir -p "${R}/.claude/flywheel/runs/alpha"
printf '{"ts":"%s","task":"spec","phase":"spec","state":"completed","cost":{"bytes_out":1}}\n' \
  "${POST}" > "${R}/.claude/flywheel/runs/alpha/2026-09-18.jsonl"
printf '{"ts":"%s","task":"plan","phase":"plan","state":"completed","cost":{"bytes_out":1}}\n' \
  "${POST}" >> "${R}/.claude/flywheel/runs/alpha/2026-09-18.jsonl"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a cycle whose work has not started must not fail, got ${RC}: $(cat "${WORK}/out")"
grep -qi "not started" "${WORK}/out" || fail "it must be named, not silently skipped: $(cat "${WORK}/out")"
grep -qi "unrecorded" "${WORK}/out" && fail "not-started must not be reported as unrecorded — they are different claims: $(cat "${WORK}/out")"
pass "a cycle with no task line at all is NOT STARTED, reported and not failed"

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

echo "== after the route-reason cutoff, an escalation with no reason fails (P55) =="
# 19 escalations in the tree, 0 reasons, 18 of them sonnet/medium -> opus/high:
# the record said THAT the ladder was declined and never WHY.
R="$(repo noreason)"; plan "${R}" alpha "opus/high" "sonnet/medium"
line "${R}" alpha T1 "opus/high" "${LATE}"
line "${R}" alpha T2 "opus/high" "${LATE}" "sonnet/medium"
run "${R}"
[ "${RC}" -eq 1 ] || fail "an escalation with no route_reason must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q "T2" "${WORK}/out" && grep -q "route_reason" "${WORK}/out" \
  || fail "the finding must name the task and the missing field: $(cat "${WORK}/out")"
pass "an unexplained escalation exits 1 and is named"

echo "== a reason makes it pass, and the reason is printed for study =="
R="$(repo reason)"; plan "${R}" alpha "opus/high" "sonnet/medium"
line "${R}" alpha T1 "opus/high" "${LATE}"
line "${R}" alpha T2 "opus/high" "${LATE}" "sonnet/medium" "two-line edit, a subagent would re-read more than it writes"
run "${R}"
[ "${RC}" -eq 0 ] || fail "an explained escalation must pass, got ${RC}: $(cat "${WORK}/out")"
grep -q "alpha T2 sonnet/medium → opus/high: two-line edit" "${WORK}/out" \
  || fail "the deviation must be listed with its reason: $(cat "${WORK}/out")"
pass "the reason is required and readable in one place"

echo "== a whitespace-only reason is no reason =="
R="$(repo blankreason)"; plan "${R}" alpha "opus/high" "sonnet/medium"
line "${R}" alpha T1 "opus/high" "${LATE}"
line "${R}" alpha T2 "opus/high" "${LATE}" "sonnet/medium" "   "
run "${R}"
[ "${RC}" -eq 1 ] || fail "a blank route_reason must exit 1, got ${RC}: $(cat "${WORK}/out")"
pass "a blank reason is rejected"

echo "== a dropped +delegate, even escalated, needs a reason too =="
R="$(repo delegatenoreason)"; plan "${R}" alpha "opus/high" "haiku/low+delegate"
line "${R}" alpha T1 "opus/high" "${LATE}"
line "${R}" alpha T2 "opus/high" "${LATE}" "haiku/low+delegate"
run "${R}"
[ "${RC}" -eq 1 ] || fail "a declined delegation with no reason must exit 1, got ${RC}: $(cat "${WORK}/out")"
pass "a declined delegation says why"

echo "== before the route-reason cutoff an unexplained escalation stays green (P18) =="
R="$(repo oldnoreason)"; plan "${R}" alpha "opus/high" "sonnet/medium"
line "${R}" alpha T1 "opus/high" "${POST}"
line "${R}" alpha T2 "opus/high" "${POST}" "sonnet/medium"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a pre-cutoff escalation must not be backfilled into a failure, got ${RC}: $(cat "${WORK}/out")"
pass "the corpus is counted, never backfilled"

echo "== a merged range covers its tasks and is reported, not failed =="
R="$(repo merged)"; plan "${R}" alpha "opus/high" "sonnet/medium"
line "${R}" alpha T1-T2 "opus/high" "${POST}"
run "${R}"
[ "${RC}" -eq 0 ] || fail "a merge is a notice, not a failure, got ${RC}: $(cat "${WORK}/out")"
grep -qiE "merge|covers|absorb" "${WORK}/out" || fail "the merge must be reported: $(cat "${WORK}/out")"
grep -q "T2" "${WORK}/out" || fail "the absorbed task must be named: $(cat "${WORK}/out")"
pass "a merge is reported and its cheaper task named"

echo "== a merge of two tasks tied on tier gets one verdict, whatever the hash seed =="
# The planned task used to be max() over a set: on a tier tie, iteration order
# (PYTHONHASHSEED) picked it, so one tree exited 0 or 1 from run to run.
R="$(repo tied)"; plan "${R}" alpha "opus/high" "opus/high+delegate"
line "${R}" alpha T1-T2 "opus/high" "${POST}"
SEEN=""
for seed in $(seq 0 15); do
  RC=0; PYTHONHASHSEED="${seed}" bash "${GATE}" "${R}" >"${WORK}/out" 2>&1 || RC=$?
  SEEN="${SEEN} ${RC}"
done
[ "$(echo "${SEEN}" | tr ' ' '\n' | sort -u | grep -c .)" -eq 1 ] \
  || fail "one tree, several verdicts across hash seeds:${SEEN}"
[ "${RC}" -eq 0 ] || fail "a tied merge is a notice, not a failure, got ${RC}: $(cat "${WORK}/out")"
grep -q "T2 routed cheaper" "${WORK}/out" || fail "the delegated task must be named as absorbed: $(cat "${WORK}/out")"
pass "a tied merge runs at the non-delegated task and names the delegated one"

echo "== a timestamp with an offset is placed by its instant, not its text =="
# 17:30-03:00 is 20:30Z, after the 20:00Z cut; as text it sorts before it, and
# an unsaid upgrade was downgraded from a failure to a pre-cutoff notice.
R="$(repo offset)"; plan "${R}" alpha "opus/high" "sonnet/medium"
line "${R}" alpha T1 "opus/high" "${POST}"
line "${R}" alpha T2 "opus/high" "2026-09-17T17:30:00-03:00"
run "${R}"
[ "${RC}" -eq 1 ] || fail "a post-cutoff upgrade with an offset ts must fail, got ${RC}: $(cat "${WORK}/out")"
pass "an offset timestamp after the cut binds"

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

echo "== the task-field reader is shared, not copied =="
# Both this gate and check-task-closure.sh must agree on what "T2-T3" covers.
# A second copy is how the two drift, so the drift guard is structural.
grep -q "from fw_tasks import task_ids" "${SRC}/scripts/check-route-honored.sh" \
  || fail "check-route-honored.sh must import the shared reader, not define its own"
grep -q "^def task_ids" "${SRC}/scripts/check-route-honored.sh" \
  && fail "check-route-honored.sh defines task_ids again — that is the copy this import removed"
[ -f "${SRC}/scripts/fw_tasks.py" ] || fail "scripts/fw_tasks.py missing — the import cannot resolve"
grep -q "from fw_tasks import task_ids" "${SRC}/scripts/check-task-closure.sh" \
  || fail "check-task-closure.sh must read task ids through the same module"
pass "one reader, imported by both gates"

echo "ALL PASS"
