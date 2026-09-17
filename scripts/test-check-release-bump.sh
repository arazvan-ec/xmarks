#!/usr/bin/env bash
# flywheel — test for scripts/check-release-bump.sh (P47, assertion 1): a diff
# touching skills/, agents/, hooks/ or scripts/ must carry a version bump and
# its upgrade note. Covers: docs-only passes; each release-bearing directory
# fails unbumped; a bump with no note fails; bump + note passes; a STALE branch
# whose version merely DIFFERS from the base fails; the exception passes only
# when it carries a reason; unusable input exits 2.
#
# The last arm replays PR #85 from this repo's real history, so it needs full
# history — the miss it reproduces is the reason this gate exists.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${SRC}/scripts/check-release-bump.sh"
WORK="$(mktemp -d)"
trap 'git -C "${SRC}" worktree remove --force "${WORK}/pr85" >/dev/null 2>&1 || true; rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

REPO="${WORK}/repo"
mkdir -p "${REPO}/scripts" "${REPO}/skills" "${REPO}/agents" "${REPO}/hooks" "${REPO}/upgrades" "${REPO}/.claude-plugin"
git init -q "${REPO}"
g() { git -C "${REPO}" -c user.email=t@t -c user.name=t "$@"; }
g checkout -qb main
ver() { printf '{"name":"flywheel","version":"%s"}\n' "$1" > "${REPO}/.claude-plugin/plugin.json"; }
ver 0.1.0
: > "${REPO}/upgrades/v0.1.0.md"
echo 'echo foo' > "${REPO}/scripts/foo.sh"
echo readme > "${REPO}/README.md"
g add -A && g commit -qm base

run_check() {
  RC=0
  (cd "${REPO}" && env "$@" bash "${CHECK}" main >"${WORK}/out" 2>&1) || RC=$?
}
branch() { g checkout -q main; g branch -qD feat 2>/dev/null || true; g checkout -qb feat; }

echo "== a docs-only diff is not a release =="
branch
echo more >> "${REPO}/README.md"
g add -A && g commit -qm docs
run_check
[ "${RC}" -eq 0 ] || fail "docs-only diff must pass, got ${RC}: $(cat "${WORK}/out")"
pass "docs-only → exit 0"

echo "== each release-bearing directory fails unbumped =="
for d in scripts skills agents hooks; do
  branch
  echo touched > "${REPO}/${d}/thing.txt"
  g add -A && g commit -qm "${d}"
  run_check
  [ "${RC}" -eq 1 ] || fail "${d}/ change without a bump must exit 1, got ${RC}: $(cat "${WORK}/out")"
  grep -q "plugin.json" "${WORK}/out" || fail "${d}/: the failure must name plugin.json"
  grep -q "${d}/thing.txt" "${WORK}/out" || fail "${d}/: the failure must name what triggered it"
  pass "${d}/ changed, no bump → exit 1"
done

echo "== a bump with no upgrade note fails =="
branch
echo touched > "${REPO}/scripts/thing.txt"
ver 0.2.0
g add -A && g commit -qm bump
run_check
[ "${RC}" -eq 1 ] || fail "bump without a note must exit 1, got ${RC}"
grep -q "upgrades/v0.2.0.md" "${WORK}/out" || fail "the failure must name the missing note"
pass "bump, no note → exit 1, names upgrades/v0.2.0.md"

echo "== a bump with its note passes =="
branch
echo touched > "${REPO}/scripts/thing.txt"
ver 0.2.0
: > "${REPO}/upgrades/v0.2.0.md"
g add -A && g commit -qm bump-noted
run_check
[ "${RC}" -eq 0 ] || fail "bump + note must pass, got ${RC}: $(cat "${WORK}/out")"
pass "bump + note → exit 0"

# A branch cut before the base moved carries an OLDER version. It differs from
# the base's, so a rule written as "must differ" passes it — which is exactly
# the shape of PR #85. The rule is "must be greater".
echo "== a stale branch whose version is merely DIFFERENT fails =="
g checkout -q main
ver 0.5.0
: > "${REPO}/upgrades/v0.5.0.md"
g add -A && g commit -qm "main moves on"
g checkout -qb stale HEAD~1
echo touched > "${REPO}/scripts/thing.txt"
g add -A && g commit -qm "stale branch touches scripts"
RC=0
(cd "${REPO}" && bash "${CHECK}" main >"${WORK}/out" 2>&1) || RC=$?
[ "${RC}" -eq 1 ] || fail "a version BELOW the base must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q "0.5.0" "${WORK}/out" || fail "the failure must name the base's version"
pass "0.1.0 vs base 0.5.0 → exit 1 (differs is not enough)"
g checkout -q main && g branch -qD stale

echo "== the exception is a debt with a reason on it =="
branch
echo touched > "${REPO}/scripts/thing.txt"
g add -A && g commit -qm no-bump
run_check SKIP_RELEASE_BUMP="orchestrator renumbers at integration"
[ "${RC}" -eq 0 ] || fail "an exception with a reason must pass, got ${RC}: $(cat "${WORK}/out")"
grep -q "orchestrator renumbers at integration" "${WORK}/out" || fail "the reason must be printed, not swallowed"
pass "SKIP_RELEASE_BUMP=<reason> → exit 0, reason echoed"

for bare in 1 true yes on TRUE; do
  run_check SKIP_RELEASE_BUMP="${bare}"
  [ "${RC}" -eq 2 ] || fail "SKIP_RELEASE_BUMP=${bare} must exit 2 (no reason), got ${RC}: $(cat "${WORK}/out")"
  grep -qi "reason" "${WORK}/out" || fail "SKIP_RELEASE_BUMP=${bare}: the refusal must ask for a reason"
done
pass "SKIP_RELEASE_BUMP=1|true|yes|on → exit 2, demands a reason"

run_check SKIP_RELEASE_BUMP=""
[ "${RC}" -eq 1 ] || fail "an empty SKIP_RELEASE_BUMP must be unset, not a pass, got ${RC}"
pass "SKIP_RELEASE_BUMP= (empty) → the gate still runs"

echo "== unusable input exits 2, never 0 =="
branch
echo touched > "${REPO}/scripts/thing.txt"
g add -A
g rm -q --cached .claude-plugin/plugin.json && rm -f "${REPO}/.claude-plugin/plugin.json"
g commit -qm no-manifest
run_check
[ "${RC}" -eq 2 ] || fail "a missing plugin.json must exit 2, got ${RC}: $(cat "${WORK}/out")"
pass "no plugin.json → exit 2"

echo "== replay: PR #85 (scripts/gate.sh + test-gate.sh, no release) =="
PR85=d52d2f0
g checkout -q main
git -C "${SRC}" rev-parse -q --verify "${PR85}^2" >/dev/null \
  || fail "this arm replays PR #85 from real history; run in a checkout with full history"
git -C "${SRC}" worktree add -q --detach "${WORK}/pr85" "${PR85}^2"
RC=0
(cd "${WORK}/pr85" && bash "${CHECK}" "${PR85}^1" >"${WORK}/out" 2>&1) || RC=$?
[ "${RC}" -eq 1 ] || fail "PR #85 shipped scripts/ with no release and must be caught, got ${RC}: $(cat "${WORK}/out")"
grep -q "scripts/gate.sh" "${WORK}/out" || fail "the replay's failure must name scripts/gate.sh"
pass "PR #85 replayed against its real base → exit 1"

echo "ALL PASS"
