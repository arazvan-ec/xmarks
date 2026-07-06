#!/usr/bin/env bash
# flywheel — end-to-end test for install-vendored.sh.
# Creates a throwaway git repo with pre-existing settings, installs twice
# (idempotence), checks the vendored result, then uninstalls and checks that
# only project state survives. Exits non-zero on the first failed assertion.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="${SRC}/scripts/install-vendored.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

TARGET="${WORK}/target"
mkdir -p "${TARGET}/.claude"
git init -q "${TARGET}"
cat > "${TARGET}/.claude/settings.json" <<'EOF'
{
  "permissions": { "allow": ["Bash(npm test)"] },
  "hooks": { "SessionStart": [ { "hooks": [ { "type": "command", "command": "echo existing" } ] } ] }
}
EOF

echo "== install (twice, must be idempotent) =="
bash "${INSTALLER}" "${TARGET}" > /dev/null
bash "${INSTALLER}" "${TARGET}" > /dev/null

SKILL_COUNT="$(ls -d "${TARGET}"/.claude/skills/flywheel-*/ | wc -l | tr -d ' ')"
EXPECTED="$(ls -d "${SRC}"/skills/*/ | wc -l | tr -d ' ')"
[ "${SKILL_COUNT}" = "${EXPECTED}" ] || fail "expected ${EXPECTED} vendored skills, got ${SKILL_COUNT}"
pass "${SKILL_COUNT} skills vendored"

for d in "${TARGET}"/.claude/skills/flywheel-*/; do
  name="$(basename "${d}")"
  grep -q "^name: ${name}\$" "${d}SKILL.md" || fail "frontmatter name does not match dir in ${name}"
done
pass "every skill's frontmatter name matches its directory"

if grep -rq '/flywheel:' "${TARGET}/.claude"; then
  fail "leftover /flywheel: references in vendored files"
fi
pass "no leftover /flywheel: references"

AGENT_COUNT="$(ls "${TARGET}"/.claude/agents/*.md | wc -l | tr -d ' ')"
[ "${AGENT_COUNT}" = "$(ls "${SRC}"/agents/*.md | wc -l | tr -d ' ')" ] || fail "agent count mismatch"
pass "${AGENT_COUNT} agents vendored"

[ -x "${TARGET}/.claude/flywheel/bin/session-start.sh" ] || fail "session-start.sh missing or not executable"
[ -x "${TARGET}/.claude/flywheel/bin/gate.sh" ] || fail "gate.sh missing or not executable"
CLAUDE_PROJECT_DIR="${TARGET}" bash "${TARGET}/.claude/flywheel/bin/session-start.sh" | grep -q 'flywheel loaded' \
  || fail "session-start.sh does not run"
pass "hook scripts vendored, executable and runnable"

grep -q '^flywheel ' "${TARGET}/.claude/flywheel/VERSION" || fail "VERSION marker missing"
pass "VERSION marker written: $(head -1 "${TARGET}/.claude/flywheel/VERSION")"

python3 - "${TARGET}/.claude/settings.json" <<'PY'
import json, sys

s = json.load(open(sys.argv[1]))
assert s["permissions"]["allow"] == ["Bash(npm test)"], "pre-existing permissions lost"
ss = [h["command"] for g in s["hooks"]["SessionStart"] for h in g["hooks"]]
stop = [h["command"] for g in s["hooks"]["Stop"] for h in g["hooks"]]
assert "echo existing" in ss, "pre-existing hook lost"
assert ss.count('"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/session-start.sh') == 1, \
    "flywheel SessionStart hook missing or duplicated"
assert stop.count('"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/gate.sh') == 1, \
    "flywheel Stop hook missing or duplicated"
PY
pass "settings.json merged once, pre-existing content preserved"

echo "== uninstall =="
mkdir -p "${TARGET}/.claude/flywheel"
echo "# flywheel learnings" > "${TARGET}/.claude/flywheel/LEARNINGS.md"
bash "${INSTALLER}" --uninstall "${TARGET}" > /dev/null

ls -d "${TARGET}"/.claude/skills/flywheel-*/ 2>/dev/null && fail "vendored skills survived uninstall"
pass "vendored skills removed"
[ ! -e "${TARGET}/.claude/agents/verifier.md" ] || fail "vendored agents survived uninstall"
pass "vendored agents removed"
[ ! -e "${TARGET}/.claude/flywheel/bin" ] || fail "hook scripts survived uninstall"
[ ! -e "${TARGET}/.claude/flywheel/VERSION" ] || fail "VERSION survived uninstall"
pass "hook scripts and VERSION removed"
[ -f "${TARGET}/.claude/flywheel/LEARNINGS.md" ] || fail "LEARNINGS.md was deleted by uninstall"
pass "project state (LEARNINGS.md) preserved"

python3 - "${TARGET}/.claude/settings.json" <<'PY'
import json, sys

s = json.load(open(sys.argv[1]))
assert s["permissions"]["allow"] == ["Bash(npm test)"], "pre-existing permissions lost"
cmds = [h["command"] for e in s.get("hooks", {}).values() for g in e for h in g["hooks"]]
assert cmds == ["echo existing"], f"unexpected hooks after uninstall: {cmds}"
PY
pass "settings.json back to pre-existing content only"

echo ""
echo "all installer tests passed"
