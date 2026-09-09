#!/usr/bin/env bash
# flywheel — test for scripts/plan-route.sh (P27), the route linter over a plan's
# pinned task blocks. Covers: a valid plan passes with a tier summary; invalid
# model/effort values fail by name; a task with no route fails; two routes on one
# task fail; the riskiest task on the cheapest tier fails (the safeguard that
# makes routing more than decoration); `+delegate` is accepted and an unknown
# suffix is not; a file with no task blocks, a missing file and no argument all
# fail with a clear message and never a silent exit 0.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINT="${SRC}/scripts/plan-route.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

run() { RC=0; bash "${LINT}" "$@" >"${WORK}/out" 2>&1 || RC=$?; }

# task <n> <title> <route> [extra line ...]
task() {
  local n="$1" title="$2" route="$3"; shift 3
  printf '### T%s — %s\n' "${n}" "${title}"
  [ -n "${route}" ] && printf -- '- route: `%s`\n' "${route}"
  local extra
  for extra in "$@"; do printf -- '- %s\n' "${extra}"; done
  printf -- '- changes: file.md\n- check: it passes\n- test-first: no\n\n'
}

echo "== a valid plan passes and prints a tier summary =="
{ printf '# Plan — sample\n\n'
  task 1 "cheap thing" "haiku/low+delegate"
  task 2 "normal thing" "sonnet/medium"
  task 3 "hard thing" "opus/high" "risk: highest"; } > "${WORK}/ok.md"
run "${WORK}/ok.md"
[ "${RC}" -eq 0 ] || fail "valid plan must exit 0, got ${RC}: $(cat "${WORK}/out")"
grep -qi "3 task" "${WORK}/out" || fail "summary must report 3 tasks: $(cat "${WORK}/out")"
grep -q "haiku/low" "${WORK}/out" || fail "summary must name the routes used: $(cat "${WORK}/out")"
grep -qi "delegate" "${WORK}/out" || fail "summary must count delegated tasks: $(cat "${WORK}/out")"
pass "valid plan → exit 0 + tier summary"

echo "== the repo's own plan is valid under the linter (dogfood) =="
run "${SRC}/.claude/flywheel/specs/stage-routing.plan.md"
[ "${RC}" -eq 0 ] || fail "this cycle's own plan must lint clean, got ${RC}: $(cat "${WORK}/out")"
pass "stage-routing.plan.md lints clean"

echo "== an invalid model fails by name =="
{ printf '# Plan\n\n'; task 1 "x" "gpt/low"; } > "${WORK}/badmodel.md"
run "${WORK}/badmodel.md"
[ "${RC}" -eq 1 ] || fail "invalid model must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q "gpt" "${WORK}/out" || fail "the offending model must be named: $(cat "${WORK}/out")"
grep -q "T1" "${WORK}/out" || fail "the offending task must be named: $(cat "${WORK}/out")"
pass "invalid model → exit 1 naming the value and the task"

echo "== an invalid effort fails by name =="
{ printf '# Plan\n\n'; task 1 "x" "sonnet/turbo"; } > "${WORK}/badeffort.md"
run "${WORK}/badeffort.md"
[ "${RC}" -eq 1 ] || fail "invalid effort must exit 1, got ${RC}"
grep -q "turbo" "${WORK}/out" || fail "the offending effort must be named: $(cat "${WORK}/out")"
pass "invalid effort → exit 1 naming the value"

echo "== an integer effort is accepted (the CLI takes one) =="
{ printf '# Plan\n\n'; task 1 "x" "sonnet/8"; } > "${WORK}/inteffort.md"
run "${WORK}/inteffort.md"
[ "${RC}" -eq 0 ] || fail "integer effort must be accepted, got ${RC}: $(cat "${WORK}/out")"
pass "integer effort accepted"

echo "== a task with no route fails =="
{ printf '# Plan\n\n'; task 1 "x" "sonnet/medium"; task 2 "unrouted" ""; } > "${WORK}/noroute.md"
run "${WORK}/noroute.md"
[ "${RC}" -eq 1 ] || fail "an unrouted task must exit 1, got ${RC}"
grep -q "T2" "${WORK}/out" || fail "the unrouted task must be named: $(cat "${WORK}/out")"
pass "unrouted task → exit 1 naming it"

echo "== two routes on one task fail (ambiguous is not a route) =="
{ printf '# Plan\n\n'; task 1 "x" "sonnet/medium" "route: \`opus/high\`"; } > "${WORK}/tworoutes.md"
run "${WORK}/tworoutes.md"
[ "${RC}" -eq 1 ] || fail "two routes must exit 1, got ${RC}: $(cat "${WORK}/out")"
pass "two routes on one task → exit 1"

echo "== the riskiest task may not run on the cheapest tier =="
{ printf '# Plan\n\n'; task 1 "x" "sonnet/medium"; task 2 "risky but cheap" "haiku/low" "risk: highest"; } > "${WORK}/cheaprisk.md"
run "${WORK}/cheaprisk.md"
[ "${RC}" -eq 1 ] || fail "riskiest-on-cheap must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -qi "risk" "${WORK}/out" || fail "the failure must explain the risk rule: $(cat "${WORK}/out")"
{ printf '# Plan\n\n'; task 1 "x" "sonnet/medium"; task 2 "risky low effort" "opus/low" "risk: highest"; } > "${WORK}/lowrisk.md"
run "${WORK}/lowrisk.md"
[ "${RC}" -eq 1 ] || fail "riskiest at low effort must exit 1 even on a strong model, got ${RC}"
pass "riskiest task on haiku or at low effort → exit 1"

echo "== a plan with no riskiest task marked fails =="
{ printf '# Plan\n\n'; task 1 "x" "sonnet/medium"; task 2 "y" "sonnet/medium"; } > "${WORK}/norisk.md"
run "${WORK}/norisk.md"
[ "${RC}" -eq 1 ] || fail "a plan with no risk marker must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -qi "risk: highest" "${WORK}/out" || fail "the message must name the missing marker: $(cat "${WORK}/out")"
pass "no riskiest task marked → exit 1"

echo "== two riskiest tasks fail (the plan names one) =="
{ printf '# Plan\n\n'; task 1 "x" "opus/high" "risk: highest"; task 2 "y" "opus/high" "risk: highest"; } > "${WORK}/tworisk.md"
run "${WORK}/tworisk.md"
[ "${RC}" -eq 1 ] || fail "two risk markers must exit 1, got ${RC}"
pass "two riskiest tasks → exit 1"

echo "== a single-task plan is exempt from the risk marker =="
{ printf '# Plan\n\n'; task 1 "only task" "sonnet/medium"; } > "${WORK}/single.md"
run "${WORK}/single.md"
[ "${RC}" -eq 0 ] || fail "a one-task plan must not need a risk marker, got ${RC}: $(cat "${WORK}/out")"
pass "one-task plan → exit 0 without a risk marker"

echo "== an unknown route suffix fails =="
{ printf '# Plan\n\n'; task 1 "x" "sonnet/medium+parallel"; task 2 "y" "opus/high" "risk: highest"; } > "${WORK}/badsuffix.md"
run "${WORK}/badsuffix.md"
[ "${RC}" -eq 1 ] || fail "unknown suffix must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q "parallel" "${WORK}/out" || fail "the offending suffix must be named: $(cat "${WORK}/out")"
pass "unknown suffix → exit 1"

echo "== a task missing its check fails: a route without a gate is not a task =="
{ printf '# Plan\n\n### T1 — no check\n- route: `sonnet/medium`\n- changes: f.md\n\n'
  task 2 "y" "opus/high" "risk: highest"; } > "${WORK}/nocheck.md"
run "${WORK}/nocheck.md"
[ "${RC}" -eq 1 ] || fail "a task with no check must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -qi "check" "${WORK}/out" || fail "the message must name the missing check: $(cat "${WORK}/out")"
pass "task with no check → exit 1"

echo "== a file with no task blocks fails loudly, never a silent OK =="
printf '# Plan\n\nJust prose, no tasks.\n' > "${WORK}/empty.md"
run "${WORK}/empty.md"
[ "${RC}" -ne 0 ] || fail "a plan with no task blocks must not pass"
grep -qi "no task" "${WORK}/out" || fail "the message must say no tasks were found: $(cat "${WORK}/out")"
pass "no task blocks → non-zero with a clear message"

echo "== missing file and missing argument fail with usage =="
run "${WORK}/nope.md"
[ "${RC}" -eq 2 ] || fail "missing file must exit 2, got ${RC}: $(cat "${WORK}/out")"
grep -qi "no such\|cannot read\|not found" "${WORK}/out" || fail "missing file needs a clear message: $(cat "${WORK}/out")"
run
[ "${RC}" -eq 2 ] || fail "no argument must exit 2, got ${RC}"
grep -qi "usage" "${WORK}/out" || fail "no argument must print usage: $(cat "${WORK}/out")"
pass "missing file → exit 2; no argument → usage"

echo "== the summary never claims tokens =="
run "${WORK}/ok.md"
grep -qi "token" "${WORK}/out" && fail "the linter must not make token claims (P18/P23): $(cat "${WORK}/out")"
pass "no token claim in the output"

echo "ALL PASS"
