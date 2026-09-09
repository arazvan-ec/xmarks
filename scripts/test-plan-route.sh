#!/usr/bin/env bash
# flywheel — test for scripts/plan-route.sh (P27), the route linter over a plan's
# pinned task blocks. Covers: a valid plan passes with a tier summary; invalid
# model/effort values fail by name; a task with no route fails; two routes on one
# task fail; the riskiest task below the top tier fails, and the tier table
# drives that rule (the safeguard that makes routing more than decoration); `+delegate` is accepted and an unknown
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
rc() { [ "${RC}" -eq "$1" ] || fail "expected exit $1, got ${RC}: $(cat "${WORK}/out")"; }
says() { grep -q -- "$1" "${WORK}/out" || fail "output must mention '$1': $(cat "${WORK}/out")"; }

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
rc 0
says "3 task"
says "haiku/low"
says "delegate"
grep -qi "token" "${WORK}/out" && fail "the linter must not claim tokens (P18/P23): $(cat "${WORK}/out")"
pass "valid plan → exit 0 + tier summary, no token claim"

echo "== the repo's own plan is valid under the linter (dogfood) =="
run "${SRC}/.claude/flywheel/specs/stage-routing.plan.md"
rc 0
pass "stage-routing.plan.md lints clean"

echo "== an invalid model fails by name =="
{ printf '# Plan\n\n'; task 1 "x" "gpt/low"; } > "${WORK}/badmodel.md"
run "${WORK}/badmodel.md"
rc 1
says "gpt"
says "T1"
pass "invalid model → exit 1 naming the value and the task"

echo "== an invalid effort fails by name =="
{ printf '# Plan\n\n'; task 1 "x" "sonnet/turbo"; } > "${WORK}/badeffort.md"
run "${WORK}/badeffort.md"
rc 1
says "turbo"
pass "invalid effort → exit 1 naming the value"

echo "== an integer effort is accepted (the CLI takes one) =="
{ printf '# Plan\n\n'; task 1 "x" "sonnet/8"; } > "${WORK}/inteffort.md"
run "${WORK}/inteffort.md"
rc 0
pass "integer effort accepted"

echo "== a task with no route fails =="
{ printf '# Plan\n\n'; task 1 "x" "sonnet/medium"; task 2 "unrouted" ""; } > "${WORK}/noroute.md"
run "${WORK}/noroute.md"
rc 1
says "T2"
pass "unrouted task → exit 1 naming it"

echo "== two routes on one task fail (ambiguous is not a route) =="
{ printf '# Plan\n\n'; task 1 "x" "sonnet/medium" "route: \`opus/high\`"; } > "${WORK}/tworoutes.md"
run "${WORK}/tworoutes.md"
rc 1
pass "two routes on one task → exit 1"

# risk <route> -> a 2-task plan whose riskiest task carries <route>
risky_plan() {
  { printf '# Plan\n\n'; task 1 "x" "sonnet/medium"; task 2 "the risky one" "$1" "risk: highest"; } > "${WORK}/risk.md"
  run "${WORK}/risk.md"
}

echo "== the riskiest task must run at the top tier, not merely off the cheapest =="
for r in haiku/low opus/low sonnet/high opus/medium inherit/high haiku/max; do
  risky_plan "${r}"
  rc 1
  says "riskiest"
  pass "riskiest routed ${r} → exit 1"
done
for r in opus/high opus/max; do
  risky_plan "${r}"
  rc 0
  pass "riskiest routed ${r} → exit 0 (at or above the top tier)"
done

echo "== the riskiest task's effort must be nameable, so its tier is checkable =="
risky_plan "opus/9"
rc 1
says "named effort"
pass "riskiest at an integer effort → exit 1 (integer cannot be ranked against the top tier)"

echo "== the tier table is the authority, not a hardcoded route =="
printf '1 haiku low delegate\n2 sonnet medium\n' > "${WORK}/tiers.txt"
risky_plan "sonnet/medium"
rc 1
FLYWHEEL_ROUTE_TIERS="${WORK}/tiers.txt" run "${WORK}/risk.md"
rc 0
pass "a table whose top tier is sonnet/medium accepts what the default table rejects"

echo "== the failure names the tier table it actually read =="
printf '1 haiku low delegate\n2 sonnet medium\n3 opus high\n' > "${WORK}/custom-tiers.txt"
risky_plan "sonnet/high"
FLYWHEEL_ROUTE_TIERS="${WORK}/custom-tiers.txt" run "${WORK}/risk.md"
rc 1
says "custom-tiers.txt"
pass "the message points at the table in use, not a hardcoded repo path"

echo "== a missing tier table fails loudly, never a silent pass =="
FLYWHEEL_ROUTE_TIERS="${WORK}/nope.txt" run "${WORK}/ok.md"
rc 2
says "route-tiers"
pass "missing tier table → exit 2"

echo "== a plan with no riskiest task marked fails =="
{ printf '# Plan\n\n'; task 1 "x" "sonnet/medium"; task 2 "y" "sonnet/medium"; } > "${WORK}/norisk.md"
run "${WORK}/norisk.md"
rc 1
says "risk: highest"
pass "no riskiest task marked → exit 1"

echo "== two riskiest tasks fail (the plan names one) =="
{ printf '# Plan\n\n'; task 1 "x" "opus/high" "risk: highest"; task 2 "y" "opus/high" "risk: highest"; } > "${WORK}/tworisk.md"
run "${WORK}/tworisk.md"
rc 1
pass "two riskiest tasks → exit 1"

echo "== a single-task plan is exempt from the risk marker =="
{ printf '# Plan\n\n'; task 1 "only task" "sonnet/medium"; } > "${WORK}/single.md"
run "${WORK}/single.md"
rc 0
pass "one-task plan → exit 0 without a risk marker"

echo "== an unknown route suffix fails =="
{ printf '# Plan\n\n'; task 1 "x" "sonnet/medium+parallel"; task 2 "y" "opus/high" "risk: highest"; } > "${WORK}/badsuffix.md"
run "${WORK}/badsuffix.md"
rc 1
says "parallel"
pass "unknown suffix → exit 1"

echo "== a task missing its check fails: a route without a gate is not a task =="
{ printf '# Plan\n\n### T1 — no check\n- route: `sonnet/medium`\n- changes: f.md\n\n'
  task 2 "y" "opus/high" "risk: highest"; } > "${WORK}/nocheck.md"
run "${WORK}/nocheck.md"
rc 1
says "check"
pass "task with no check → exit 1"

echo "== a file with no task blocks fails loudly, never a silent OK =="
printf '# Plan\n\nJust prose, no tasks.\n' > "${WORK}/empty.md"
run "${WORK}/empty.md"
[ "${RC}" -ne 0 ] || fail "a plan with no task blocks must not pass"
says "no task"
pass "no task blocks → non-zero with a clear message"

echo "== missing file and missing argument fail with usage =="
run "${WORK}/nope.md"
rc 2
says "no such\|cannot read\|not found"
run
rc 2
says "usage"
pass "missing file → exit 2; no argument → usage"

echo "ALL PASS"
