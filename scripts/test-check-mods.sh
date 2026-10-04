#!/usr/bin/env bash
# flywheel — test for scripts/check-mods.sh (P72 T0). The CLI is a stub
# ($CLAUDE) so the arms grade the gate, not the engine.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${SRC}/scripts/check-mods.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

STUB="${WORK}/claude"
cat > "${STUB}" <<'EOF'
#!/usr/bin/env bash
case "$2" in
  validate) [ -e "$3/.fail-validate" ] && { echo "stub: invalid" >&2; exit 1; }; echo "stub: validated $3" ;;
  test) [ -e "$3/.fail-test" ] && { echo "stub: 1 fail" >&2; exit 1; }; echo "stub: tested $3" ;;
esac
EOF
chmod +x "${STUB}"

REPO="${WORK}/repo"
mkdir -p "${REPO}/.claude-plugin"
git init -q "${REPO}"
g() { git -C "${REPO}" -c user.email=t@t -c user.name=t "$@"; }
g checkout -qb main

market() {
  python3 - "${REPO}/.claude-plugin/marketplace.json" "$@" <<'EOF'
import json, sys
p, names = sys.argv[1], sys.argv[2:]
json.dump({"name": "m", "plugins": [{"name": "flywheel", "source": "./"}] +
           [{"name": n, "source": f"./mods/{n}"} for n in names]}, open(p, "w"))
EOF
}
mod() { # mod <name> <version>
  local d="${REPO}/mods/$1"
  mkdir -p "${d}/.claude-plugin" "${d}/hooks"
  echo "{\"name\":\"$1\",\"version\":\"$2\",\"description\":\"x\",\"author\":{\"name\":\"t\"}}" > "${d}/.claude-plugin/plugin.json"
  echo '{"modules":["./register.ts"]}' > "${d}/hooks/hooks.json"
  echo 'export const register = () => {}' > "${d}/hooks/register.ts"
  echo "test('x', () => {})" > "${d}/hooks/$1.test.ts"
}

market
g add -A && g commit -qm base

run_check() { # run_check [VAR=val ...] -- [args...]
  local envs=() ; while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift || true
  RC=0
  (cd "${REPO}" && env CLAUDE="${STUB}" "${envs[@]}" bash "${CHECK}" main "$@" >"${WORK}/out" 2>&1) || RC=$?
}
branch() { g checkout -q main && { g branch -qD feat 2>/dev/null || true; } && g checkout -qb feat; }
out() { cat "${WORK}/out"; }

echo "== no mods dir passes =="
branch
run_check --
[ "${RC}" -eq 0 ] || fail "no mods must pass, got ${RC}: $(out)"
grep -q "no mods" "${WORK}/out" || fail "must say there are no mods: $(out)"
pass "no mods → exit 0, says so"

echo "== a complete, listed mod passes and runs validate + test =="
branch
mod alpha 0.1.0; market alpha
g add -A && g commit -qm alpha
run_check --
[ "${RC}" -eq 0 ] || fail "complete mod must pass, got ${RC}: $(out)"
grep -q "validated mods/alpha" "${WORK}/out" || fail "must run validate on the mod: $(out)"
grep -q "tested mods/alpha" "${WORK}/out" || fail "must run plugin test on the mod: $(out)"
pass "alpha → validate + test ran, exit 0"
g checkout -q main && g merge -q --ff-only feat

echo "== a mod with no *.test.ts fails =="
branch
mod beta 0.1.0; rm "${REPO}/mods/beta/hooks/beta.test.ts"; market alpha beta
g add -A && g commit -qm beta
run_check --
[ "${RC}" -ne 0 ] || fail "a mod with no test must fail"
grep -q "beta.*test" "${WORK}/out" || fail "must name the mod missing a test: $(out)"
pass "beta without a test → fails, named"

echo "== a mod missing from marketplace.json fails =="
branch
mod gamma 0.1.0
g add -A && g commit -qm gamma
run_check --
[ "${RC}" -ne 0 ] || fail "an unlisted mod must fail"
grep -q "gamma.*marketplace" "${WORK}/out" || fail "must name the unlisted mod: $(out)"
pass "gamma unlisted → fails, named"

echo "== a marketplace entry with no mod dir fails =="
branch
market alpha ghost
g add -A && g commit -qm ghost
run_check --
[ "${RC}" -ne 0 ] || fail "a listed mod with no dir must fail"
grep -q "ghost" "${WORK}/out" || fail "must name the missing dir: $(out)"
pass "ghost listed, no dir → fails, named"

echo "== validate failing fails the gate =="
branch
touch "${REPO}/mods/alpha/.fail-validate"; sed -i 's/0.1.0/0.1.1/' "${REPO}/mods/alpha/.claude-plugin/plugin.json"
g add -A && g commit -qm bad
run_check --
[ "${RC}" -ne 0 ] || fail "a validate failure must fail the gate"
grep -q "alpha.*validate" "${WORK}/out" || fail "must name mod and step: $(out)"
pass "validate red → fails, named"

echo "== plugin test failing fails the gate =="
branch
touch "${REPO}/mods/alpha/.fail-test"; sed -i 's/0.1.0/0.1.1/' "${REPO}/mods/alpha/.claude-plugin/plugin.json"
g add -A && g commit -qm bad
run_check --
[ "${RC}" -ne 0 ] || fail "a plugin test failure must fail the gate"
grep -q "alpha.*test" "${WORK}/out" || fail "must name mod and step: $(out)"
pass "plugin test red → fails, named"

echo "== no CLI: structure still checked, engine steps SKIPPED =="
branch
run_check CLAUDE="${WORK}/nope" --
[ "${RC}" -eq 0 ] || fail "no CLI must not fail a sound tree, got ${RC}: $(out)"
grep -q "SKIPPED" "${WORK}/out" || fail "must say the engine steps were skipped: $(out)"
pass "no CLI → exit 0, SKIPPED named"

echo "== a changed mod without a version bump fails =="
branch
echo '// x' >> "${REPO}/mods/alpha/hooks/register.ts"
g add -A && g commit -qm nobump
run_check --
[ "${RC}" -ne 0 ] || fail "a changed mod without a bump must fail"
grep -q "alpha.*0.1.0" "${WORK}/out" || fail "must name the mod and its stale version: $(out)"
pass "alpha changed, still 0.1.0 → fails"

echo "== a version that moved backwards is not a bump =="
sed -i 's/0.1.0/0.0.9/' "${REPO}/mods/alpha/.claude-plugin/plugin.json"
g add -A && g commit -qm back
run_check --
[ "${RC}" -ne 0 ] || fail "0.0.9 after 0.1.0 must fail"
pass "0.1.0 → 0.0.9 → fails"

echo "== the bump passes =="
sed -i 's/0.0.9/0.2.0/' "${REPO}/mods/alpha/.claude-plugin/plugin.json"
g add -A && g commit -qm bump
run_check --
[ "${RC}" -eq 0 ] || fail "a bumped mod must pass, got ${RC}: $(out)"
pass "0.1.0 → 0.2.0 → exit 0"

echo "== SKIP_MOD_BUMP takes a reason, not a 1 =="
branch
echo '// y' >> "${REPO}/mods/alpha/hooks/register.ts"
g add -A && g commit -qm nobump
run_check SKIP_MOD_BUMP=1 --
[ "${RC}" -ne 0 ] || fail "SKIP_MOD_BUMP=1 must not count as a reason"
run_check "SKIP_MOD_BUMP=comment-only change" --
[ "${RC}" -eq 0 ] || fail "a reasoned skip must pass, got ${RC}: $(out)"
grep -q "comment-only change" "${WORK}/out" || fail "the reason must be logged: $(out)"
pass "skip with a reason → exit 0, logged; '1' refused"

echo "== a named mod limits the run to it =="
branch
mod delta 0.1.0; touch "${REPO}/mods/delta/.fail-test"; market alpha delta
g add -A && g commit -qm delta
run_check -- alpha
[ "${RC}" -eq 0 ] || fail "naming alpha must not grade delta, got ${RC}: $(out)"
run_check -- delta
[ "${RC}" -ne 0 ] || fail "naming delta must grade it"
run_check -- nosuch
[ "${RC}" -ne 0 ] || fail "naming a mod that does not exist must fail"
pass "named mod → only that one graded; unknown name fails"

echo "all check-mods arms passed"
