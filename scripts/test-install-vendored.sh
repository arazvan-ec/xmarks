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
if grep -qE "sed ['\"]?0," "${INSTALLER}"; then
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
[ -x "${TARGET}/.claude/flywheel/bin/write-allow.sh" ] || fail "write-allow.sh missing or not executable"
[ -x "${TARGET}/.claude/flywheel/bin/bash-allow.sh" ] || fail "bash-allow.sh missing or not executable"
[ -x "${TARGET}/.claude/flywheel/bin/gate.sh" ] || fail "gate.sh missing or not executable"
CLAUDE_PROJECT_DIR="${TARGET}" FLYWHEEL_NO_UPDATE_CHECK=1 \
  bash "${TARGET}/.claude/flywheel/bin/session-start.sh" > "${WORK}/hook-out.txt"
grep -q 'flywheel loaded' "${WORK}/hook-out.txt" || fail "session-start.sh does not run"
echo '{"tool_input": {"file_path": "nope.ts"}}' | CLAUDE_PROJECT_DIR="${TARGET}" \
  bash "${TARGET}/.claude/flywheel/bin/read-prime.sh" > "${WORK}/read-prime-out.txt"
[ ! -s "${WORK}/read-prime-out.txt" ] || fail "read-prime.sh printed output for a file with no ledger entry"
echo '{"tool_input": {"file_path": ".claude/flywheel/LEARNINGS.md"}}' | CLAUDE_PROJECT_DIR="${TARGET}" \
  bash "${TARGET}/.claude/flywheel/bin/write-allow.sh" > "${WORK}/write-allow-out.txt"
grep -q '"permissionDecision": "allow"' "${WORK}/write-allow-out.txt" \
  || fail "vendored write-allow.sh did not grant a flywheel state write"
echo '{"tool_input": {"file_path": "src/app.ts"}}' | CLAUDE_PROJECT_DIR="${TARGET}" \
  bash "${TARGET}/.claude/flywheel/bin/write-allow.sh" > "${WORK}/write-allow-none.txt"
[ ! -s "${WORK}/write-allow-none.txt" ] || fail "vendored write-allow.sh granted an out-of-scope write"
echo '{"tool_input": {"command": "git add -A"}, "cwd": "'"${TARGET}"'"}' | CLAUDE_PROJECT_DIR="${TARGET}" \
  bash "${TARGET}/.claude/flywheel/bin/bash-allow.sh" > "${WORK}/bash-allow-out.txt"
grep -q '"permissionDecision": "allow"' "${WORK}/bash-allow-out.txt" \
  || fail "vendored bash-allow.sh did not grant a plain git add"
echo '{"tool_input": {"command": "git push --force origin main"}, "cwd": "'"${TARGET}"'"}' | CLAUDE_PROJECT_DIR="${TARGET}" \
  bash "${TARGET}/.claude/flywheel/bin/bash-allow.sh" > "${WORK}/bash-allow-none.txt"
[ ! -s "${WORK}/bash-allow-none.txt" ] || fail "vendored bash-allow.sh granted a force push"
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
assert pre.count(("Write|Edit|MultiEdit|NotebookEdit",
                  '"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/write-allow.sh')) == 1, \
    "flywheel PreToolUse write-allow hook missing, duplicated, or missing its Write|Edit matcher"
assert pre.count(("Bash", '"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/bash-allow.sh')) == 1, \
    "flywheel PreToolUse bash-allow hook missing, duplicated, or missing its Bash matcher"
assert stop.count('"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/gate.sh') == 1, \
    "flywheel Stop hook missing or duplicated"
PY
pass "settings.json merged once, pre-existing content preserved"

echo "== upgrade pruning =="
# Simulate a file vendored by an older version that the new version dropped.
echo "stale content" > "${TARGET}/.claude/agents/obsolete-agent.md"
echo ".claude/agents/obsolete-agent.md" >> "${TARGET}/.claude/flywheel/.manifest"
# And a dropped skill that had collided with a user's dir (backup exists):
# pruning must restore the user's SKILL.md, and uninstall must then KEEP it.
mkdir -p "${TARGET}/.claude/skills/flywheel-ghost"
echo "vendored ghost" > "${TARGET}/.claude/skills/flywheel-ghost/SKILL.md"
echo "my ghost" > "${TARGET}/.claude/skills/flywheel-ghost/SKILL.md.pre-flywheel"
echo ".claude/skills/flywheel-ghost/SKILL.md" >> "${TARGET}/.claude/flywheel/.manifest"
sort -u -o "${TARGET}/.claude/flywheel/.manifest" "${TARGET}/.claude/flywheel/.manifest"
bash "${INSTALLER}" "${TARGET}" > "${WORK}/prune-out.txt"
[ "$(cat "${TARGET}/.claude/skills/flywheel-ghost/SKILL.md")" = "my ghost" ] \
  || fail "pruning a dropped skill did not restore the user's pre-flywheel backup"
pass "pruned skill restored the user's pre-flywheel backup"
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

echo "== pending upgrade strategies =="
PENDING="${TARGET}/.claude/flywheel/PENDING-UPGRADES"
# Fresh and same-version installs (all runs so far) must never record debt.
[ ! -e "${PENDING}" ] || fail "PENDING-UPGRADES written without a version change"
pass "no pending marker on fresh/same-version installs"
# Simulate a repo carrying an old vendored copy: requires-action notes in
# (0.7.0, current] must be recorded (v0.8.0 and v0.20.0 are requires-action;
# v0.9.0 is not and must be skipped).
printf 'flywheel 0.7.0\n' > "${TARGET}/.claude/flywheel/VERSION"
bash "${INSTALLER}" "${TARGET}" > "${WORK}/pending-out.txt"
grep -qx '0.8.0' "${PENDING}" || fail "requires-action note 0.8.0 not recorded as pending"
grep -qx '0.20.0' "${PENDING}" || fail "requires-action note 0.20.0 not recorded as pending"
grep -qx '0.9.0' "${PENDING}" && fail "non-requires-action note 0.9.0 recorded as pending"
grep -q 'pending upgrade strategies recorded' "${WORK}/pending-out.txt" || fail "pending recording not logged"
grep -qxF '.claude/flywheel/PENDING-UPGRADES' "${TARGET}/.claude/flywheel/.manifest" \
  && fail "PENDING-UPGRADES leaked into the manifest (pruning would erase the debt)"
pass "pending strategies recorded for the (old, new] range, requires-action only, kept out of the manifest"
# Debt must survive a same-version re-install unchanged (no dupes, no clearing).
cp "${PENDING}" "${WORK}/pending-before.txt"
bash "${INSTALLER}" "${TARGET}" > /dev/null
cmp -s "${PENDING}" "${WORK}/pending-before.txt" || fail "same-version re-install changed PENDING-UPGRADES"
pass "pending debt survives a same-version re-install unchanged"

echo "== post-refresh smoke check =="
# A hook script that no longer parses must abort the install (non-zero) so a
# broken vendored copy is never recorded as installed.
BROKEN_SRC="${WORK}/broken-src"
mkdir -p "${BROKEN_SRC}/scripts"
cp -R "${SRC}/skills" "${SRC}/agents" "${SRC}/.claude-plugin" "${BROKEN_SRC}/"
cp "${SRC}"/scripts/*.sh "${BROKEN_SRC}/scripts/"
echo 'if [ -z "${broken}" ; then' >> "${BROKEN_SRC}/scripts/gate.sh"
BROKEN_TARGET="${WORK}/broken-target"
mkdir -p "${BROKEN_TARGET}"
git init -q "${BROKEN_TARGET}"
if bash "${BROKEN_SRC}/scripts/install-vendored.sh" "${BROKEN_TARGET}" > /dev/null 2>&1; then
  fail "installer succeeded despite a hook script that fails bash -n"
fi
[ ! -e "${BROKEN_TARGET}/.claude/flywheel/VERSION" ] \
  || fail "aborted install still recorded a VERSION marker"
pass "broken hook script aborts the install before VERSION/manifest are recorded"

echo "== uninstall =="
mkdir -p "${TARGET}/.claude/flywheel"
echo "# flywheel learnings" > "${TARGET}/.claude/flywheel/LEARNINGS.md"
# A user-owned flywheel-* dir that never collided with a vendored name:
# uninstall must not touch it (manifest-driven, not glob-driven).
mkdir -p "${TARGET}/.claude/skills/flywheel-mine"
echo "mine" > "${TARGET}/.claude/skills/flywheel-mine/SKILL.md"
bash "${INSTALLER}" --uninstall "${TARGET}" > /dev/null

for gone in flywheel-spec flywheel-loop flywheel-run; do
  [ ! -d "${TARGET}/.claude/skills/${gone}" ] || fail "vendored skill ${gone} survived uninstall"
done
pass "vendored skills removed"
[ "$(cat "${TARGET}/.claude/skills/flywheel-help/SKILL.md")" = "my own help" ] \
  || fail "pre-existing flywheel-help skill was not restored on uninstall"
[ ! -e "${TARGET}/.claude/skills/flywheel-help/SKILL.md.pre-flywheel" ] || fail "skill backup left behind"
pass "pre-existing skill restored from backup"
[ "$(cat "${TARGET}/.claude/skills/flywheel-ghost/SKILL.md")" = "my ghost" ] \
  || fail "uninstall deleted a user skill that pruning had restored"
[ "$(cat "${TARGET}/.claude/skills/flywheel-mine/SKILL.md")" = "mine" ] \
  || fail "uninstall deleted a user-owned flywheel-* dir it never vendored"
pass "user-owned flywheel-* dirs preserved (manifest-driven uninstall)"
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
[ ! -e "${TARGET}/.claude/flywheel/PENDING-UPGRADES" ] || fail "PENDING-UPGRADES survived uninstall"
pass "hook scripts, VERSION, manifest and pending marker removed"
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
