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
# A pre-flywheel agent with the same name as one of ours: the install must
# back it up, and the uninstall must restore it.
mkdir -p "${TARGET}/.claude/agents"
echo "my own verifier" > "${TARGET}/.claude/agents/verifier.md"
# Same for a pre-flywheel skill dir colliding with a vendored name: backed up
# on install, restored (dir kept) on uninstall.
mkdir -p "${TARGET}/.claude/skills/flywheel-help"
echo "my own help" > "${TARGET}/.claude/skills/flywheel-help/SKILL.md"
git -C "${TARGET}" remote add origin git@github.com:acme/demo.git

echo "== install (twice, must be idempotent) =="
if grep -q '0,/' "${INSTALLER}"; then
  fail "GNU-only sed '0,/re/' address in install-vendored.sh (dies on BSD/macOS sed)"
fi
pass "no GNU-only sed address ranges"
bash "${INSTALLER}" --auto-update "${TARGET}" > "${WORK}/install-out.txt" 2>"${WORK}/warnings.txt"
bash "${INSTALLER}" --auto-update "${TARGET}" > /dev/null

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
[ -x "${TARGET}/.claude/flywheel/bin/read-prime.sh" ] || fail "read-prime.sh missing or not executable"
[ -x "${TARGET}/.claude/flywheel/bin/gate.sh" ] || fail "gate.sh missing or not executable"
CLAUDE_PROJECT_DIR="${TARGET}" FLYWHEEL_NO_UPDATE_CHECK=1 \
  bash "${TARGET}/.claude/flywheel/bin/session-start.sh" > "${WORK}/hook-out.txt"
grep -q 'flywheel loaded' "${WORK}/hook-out.txt" || fail "session-start.sh does not run"
echo '{"tool_input": {"file_path": "nope.ts"}}' | CLAUDE_PROJECT_DIR="${TARGET}" \
  bash "${TARGET}/.claude/flywheel/bin/read-prime.sh" > "${WORK}/read-prime-out.txt"
[ ! -s "${WORK}/read-prime-out.txt" ] || fail "read-prime.sh printed output for a file with no ledger entry"
pass "hook scripts vendored, executable and runnable"

grep -q '^flywheel ' "${TARGET}/.claude/flywheel/VERSION" || fail "VERSION marker missing"
pass "VERSION marker written: $(head -1 "${TARGET}/.claude/flywheel/VERSION")"

grep -q 'agents/verifier.md' "${TARGET}/.claude/flywheel/.manifest" || fail "manifest missing or incomplete"
pass "manifest written"

[ "$(cat "${TARGET}/.claude/agents/verifier.md.pre-flywheel")" = "my own verifier" ] \
  || fail "pre-existing verifier.md was not backed up"
grep -q 'existed before flywheel' "${WORK}/warnings.txt" || fail "no backup warning emitted"
grep -q 'objective gate' "${TARGET}/.claude/agents/verifier.md" || fail "verifier.md not overwritten with ours"
pass "pre-existing agent backed up (with warning) before overwrite"

[ "$(cat "${TARGET}/.claude/skills/flywheel-help/SKILL.md.pre-flywheel")" = "my own help" ] \
  || fail "pre-existing flywheel-help skill was not backed up"
pass "pre-existing skill backed up before overwrite"

grep -q 'flywheel-update.yml@main' "${TARGET}/.github/workflows/flywheel-update.yml" \
  || fail "--auto-update did not write the caller workflow"
pass "--auto-update wrote .github/workflows/flywheel-update.yml"

grep -q 'https://github.com/acme/demo/settings/actions' "${WORK}/install-out.txt" \
  || fail "--auto-update did not print the repo's Actions settings URL"
pass "--auto-update printed the exact Actions settings URL"

python3 - "${TARGET}/.claude/settings.json" <<'PY'
import json, sys

s = json.load(open(sys.argv[1]))
assert s["permissions"]["allow"] == ["Bash(npm test)"], "pre-existing permissions lost"
ss = [h["command"] for g in s["hooks"]["SessionStart"] for h in g["hooks"]]
pre = [(g.get("matcher"), h["command"]) for g in s["hooks"]["PreToolUse"] for h in g["hooks"]]
stop = [h["command"] for g in s["hooks"]["Stop"] for h in g["hooks"]]
assert "echo existing" in ss, "pre-existing hook lost"
assert ss.count('"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/session-start.sh') == 1, \
    "flywheel SessionStart hook missing or duplicated"
assert pre.count(("Read", '"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/read-prime.sh')) == 1, \
    "flywheel PreToolUse read-prime hook missing, duplicated, or missing its Read matcher"
assert stop.count('"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/gate.sh') == 1, \
    "flywheel Stop hook missing or duplicated"
PY
pass "settings.json merged once, pre-existing content preserved"

echo "== upgrade pruning =="
# Simulate a file vendored by an older version that the new version dropped.
echo "stale content" > "${TARGET}/.claude/agents/obsolete-agent.md"
echo ".claude/agents/obsolete-agent.md" >> "${TARGET}/.claude/flywheel/.manifest"
sort -u -o "${TARGET}/.claude/flywheel/.manifest" "${TARGET}/.claude/flywheel/.manifest"
bash "${INSTALLER}" "${TARGET}" > "${WORK}/prune-out.txt"
[ ! -e "${TARGET}/.claude/agents/obsolete-agent.md" ] || fail "stale vendored file survived re-install"
grep -q 'pruned .claude/agents/obsolete-agent.md' "${WORK}/prune-out.txt" || fail "pruning was not logged"
if grep -qxF '.claude/agents/obsolete-agent.md' "${TARGET}/.claude/flywheel/.manifest"; then
  fail "stale entry still listed in manifest"
fi
pass "stale vendored file pruned on re-install (and logged)"
[ -f "${TARGET}/.github/workflows/flywheel-update.yml" ] \
  || fail "auto-update workflow lost on plain re-install (choice must be sticky)"
grep -qxF '.github/workflows/flywheel-update.yml' "${TARGET}/.claude/flywheel/.manifest" \
  || fail "auto-update workflow dropped from manifest on plain re-install"
pass "auto-update choice sticky across a plain re-install"

echo "== uninstall =="
mkdir -p "${TARGET}/.claude/flywheel"
echo "# flywheel learnings" > "${TARGET}/.claude/flywheel/LEARNINGS.md"
bash "${INSTALLER}" --uninstall "${TARGET}" > /dev/null

LEFT="$(ls -d "${TARGET}"/.claude/skills/flywheel-*/ 2>/dev/null || true)"
[ "${LEFT}" = "${TARGET}/.claude/skills/flywheel-help/" ] \
  || fail "vendored skills survived uninstall (or user skill dir was deleted): ${LEFT}"
pass "vendored skills removed (user's own flywheel-help dir kept)"
[ "$(cat "${TARGET}/.claude/skills/flywheel-help/SKILL.md")" = "my own help" ] \
  || fail "pre-existing flywheel-help skill was not restored on uninstall"
[ ! -e "${TARGET}/.claude/skills/flywheel-help/SKILL.md.pre-flywheel" ] || fail "skill backup left behind"
pass "pre-existing skill restored from backup"
[ ! -e "${TARGET}/.claude/agents/reviewer-security.md" ] || fail "vendored agents survived uninstall"
pass "vendored agents removed"
[ "$(cat "${TARGET}/.claude/agents/verifier.md")" = "my own verifier" ] \
  || fail "pre-existing verifier.md was not restored on uninstall"
[ ! -e "${TARGET}/.claude/agents/verifier.md.pre-flywheel" ] || fail "backup file left behind"
pass "pre-existing agent restored from backup"
[ ! -e "${TARGET}/.github/workflows/flywheel-update.yml" ] || fail "auto-update workflow survived uninstall"
pass "auto-update workflow removed"
[ ! -e "${TARGET}/.claude/flywheel/bin" ] || fail "hook scripts survived uninstall"
[ ! -e "${TARGET}/.claude/flywheel/VERSION" ] || fail "VERSION survived uninstall"
[ ! -e "${TARGET}/.claude/flywheel/.manifest" ] || fail "manifest survived uninstall"
pass "hook scripts, VERSION and manifest removed"
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
