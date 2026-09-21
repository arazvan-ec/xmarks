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
# And inside it, a references/ dir of the user's own (P35): one file whose name
# collides with a reference we vendor, one that is purely theirs. Uninstall must
# restore the first from its backup and leave the second alone — the dir belongs
# to the user, so removing it wholesale would destroy both.
mkdir -p "${TARGET}/.claude/skills/flywheel-help/references"
echo "MY OWN PRECIOUS NOTES" > "${TARGET}/.claude/skills/flywheel-help/references/good-to-know.md"
echo "my private notes" > "${TARGET}/.claude/skills/flywheel-help/references/my-private-notes.md"
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
# The analysis scripts the skills invoke, not just the hooks: without them a
# vendored repo cannot lint its plan's routes or read its own run cost, and the
# skills' fail-open turns that into silence rather than an error.
[ -x "${TARGET}/.claude/flywheel/bin/plan-route.sh" ] || fail "plan-route.sh missing or not executable"
[ -x "${TARGET}/.claude/flywheel/bin/run-cost.sh" ] || fail "run-cost.sh missing or not executable"
[ -f "${TARGET}/.claude/flywheel/bin/route-tiers.txt" ] || fail "route-tiers.txt missing — plan-route.sh and delegation-guard.sh read it beside themselves"
[ -x "${TARGET}/.claude/flywheel/bin/check-task-closure.sh" ] || fail "check-task-closure.sh missing or not executable — /flywheel:verify's closure step cannot run"
[ -f "${TARGET}/.claude/flywheel/bin/task-closure-allow.txt" ] || fail "task-closure-allow.txt missing — without it every check reads UNRUNNABLE and the closure verdict silently means nothing"
[ -f "${TARGET}/.claude/flywheel/bin/fw_tasks.py" ] || fail "fw_tasks.py missing — check-task-closure.sh imports it beside itself and dies on import without it"
# Importing is the assertion that matters: a present-but-unimportable file
# passes a -f check and still takes the gate down on first use.
bash "${TARGET}/.claude/flywheel/bin/check-task-closure.sh" "${TARGET}" >/dev/null 2>&1
[ "$?" -le 1 ] || fail "vendored check-task-closure.sh did not start (exit $? — an import error reads as unusable input)"
# The delegation hooks are the case this test did not cover when they landed:
# hooks/hooks.json reached installed plugins, but a VENDORED repo is wired by
# THIS script, and its hook list is hand-maintained. Copied but unregistered is
# the silent half-install — the scripts sit there and never fire.
[ -x "${TARGET}/.claude/flywheel/bin/delegation-guard.sh" ] || fail "delegation-guard.sh missing or not executable"
[ -x "${TARGET}/.claude/flywheel/bin/delegation-record.sh" ] || fail "delegation-record.sh missing or not executable"
[ -x "${TARGET}/.claude/flywheel/bin/read-meter.sh" ] || fail "read-meter.sh missing or not executable"
[ -x "${TARGET}/.claude/flywheel/bin/git-tracking-refs.sh" ] || fail "git-tracking-refs.sh missing or not executable"

# End-to-end from the vendored location: the linter must find its tier table
# there, and the riskiest-step rule must still bite.
{ printf '# Plan\n\n### T1 — a\n- route: `sonnet/medium`\n- check: c\n\n'
  printf '### T2 — b\n- route: `opus/high`\n- risk: highest\n- check: c\n'; } > "${WORK}/ok.plan.md"
bash "${TARGET}/.claude/flywheel/bin/plan-route.sh" "${WORK}/ok.plan.md" > "${WORK}/pr-out.txt" 2>&1 \
  || fail "vendored plan-route.sh must lint a good plan clean: $(cat "${WORK}/pr-out.txt")"
grep -q "tier 3" "${WORK}/pr-out.txt" || fail "vendored plan-route.sh did not find route-tiers.txt: $(cat "${WORK}/pr-out.txt")"
{ printf '# Plan\n\n### T1 — a\n- route: `sonnet/medium`\n- check: c\n\n'
  printf '### T2 — b\n- route: `sonnet/high`\n- risk: highest\n- check: c\n'; } > "${WORK}/bad.plan.md"
bash "${TARGET}/.claude/flywheel/bin/plan-route.sh" "${WORK}/bad.plan.md" > "${WORK}/pr-bad.txt" 2>&1 \
  && fail "vendored plan-route.sh must reject a riskiest step below the top tier"

printf '{"ts":"2026-09-09T10:00:00Z","task":"T1","state":"completed","route":"haiku/low+delegate","cost":{"bytes_out":10,"tool_calls":1,"elapsed_s":1}}\n' > "${WORK}/run.jsonl"
bash "${TARGET}/.claude/flywheel/bin/run-cost.sh" "${WORK}/run.jsonl" > "${WORK}/rc-out.txt" 2>&1 \
  || fail "vendored run-cost.sh must read a run: $(cat "${WORK}/rc-out.txt")"
grep -q "haiku/low+delegate" "${WORK}/rc-out.txt" || fail "vendored run-cost.sh must group by route: $(cat "${WORK}/rc-out.txt")"
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

CALLER="${TARGET}/.github/workflows/flywheel-update.yml"
[ -f "${CALLER}" ] || fail "--auto-update did not write the caller workflow"
pass "--auto-update wrote .github/workflows/flywheel-update.yml"

# P13/B10. The gate (scripts/check-supply-chain-pin.sh) reads the TEMPLATE and can
# only assert it interpolates one full-SHA variable. That the generated file then
# carries a real 40-hex pin, and the SAME sha as the input, is only observable
# here — on the artifact. Neither assertion is the claim on its own.
if grep -q 'flywheel-update\.yml@main' "${CALLER}"; then
  fail "the caller still pins @main: whatever that branch points at when the cron fires is what runs here under contents:write"
fi
PIN="$(sed -n 's|.*flywheel-update\.yml@\([0-9a-fA-F]*\).*|\1|p' "${CALLER}" | head -1)"
printf '%s' "${PIN}" | grep -Eq '^[0-9a-fA-F]{40}$' \
  || fail "the caller's uses: ref is '${PIN}', not a full 40-hex commit SHA (a short SHA is not a valid pin)"
pass "caller pins a full 40-hex commit SHA"

INPUT="$(sed -n 's|.*flywheel_sha:[[:space:]]*\([0-9a-fA-F]*\).*|\1|p' "${CALLER}" | head -1)"
[ -n "${INPUT}" ] || fail "the caller passes no flywheel_sha input, so the reusable workflow cannot learn which commit it was pinned to"
[ "${INPUT}" = "${PIN}" ] \
  || fail "the caller pins ${PIN} but passes ${INPUT}: the executed code and the trusted commit must be one value"
pass "flywheel_sha matches the uses: pin exactly"

[ "${PIN}" = "$(git -C "${SRC}" rev-parse HEAD)" ] \
  || fail "the caller pins ${PIN}, which is not this checkout's HEAD"
pass "the pin is this checkout's commit"

# The heredoc is unquoted now so the SHA interpolates. That makes every other `$`
# in it live, and a swallowed `${{ }}` would be invisible in the diff's intent.
if grep -q '\$(' "${CALLER}"; then
  fail "a command substitution survived into the written caller — the unquoted heredoc executed it"
fi
if grep -q '{{' "${CALLER}"; then
  grep -q '\${{' "${CALLER}" || fail "a GitHub expression in the caller lost its leading \$ to the unquoted heredoc"
fi
pass "nothing in the template was eaten by the unquoted heredoc"

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
DELEG = "mcp__.*__create_session|Agent|Task"
assert pre.count((DELEG, '"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/delegation-guard.sh')) == 1, \
    "flywheel PreToolUse delegation-guard hook missing, duplicated, or missing its matcher"
post = [(g.get("matcher"), h["command"]) for g in s["hooks"].get("PostToolUse", []) for h in g["hooks"]]
assert post.count((DELEG, '"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/delegation-record.sh')) == 1, \
    "flywheel PostToolUse delegation-record hook missing, duplicated, or missing its matcher"
assert post.count((".*", '"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/read-meter.sh')) == 1, \
    "flywheel PostToolUse read-meter hook missing, duplicated, or not matching every tool"
assert ss.count('"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/git-tracking-refs.sh') == 1, \
    "flywheel SessionStart git-tracking-refs hook missing or duplicated"
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
HREF="${TARGET}/.claude/skills/flywheel-help/references"
[ "$(cat "${HREF}/good-to-know.md" 2>/dev/null)" = "MY OWN PRECIOUS NOTES" ] \
  || fail "uninstall did not restore the user's own references/good-to-know.md from its backup"
[ ! -e "${HREF}/good-to-know.md.pre-flywheel" ] || fail "references backup file left behind"
[ "$(cat "${HREF}/my-private-notes.md" 2>/dev/null)" = "my private notes" ] \
  || fail "uninstall deleted a user file under references/ that flywheel never vendored"
pass "user-owned references/ restored and preserved on uninstall"
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

echo "== references/ travel with the body they belong to (P35) =="
# A body that cites skills/<n>/references/<topic>.md is only correct in a
# vendored repo if the referenced file travels with it; the vendor loop copies
# SKILL.md alone. Installed from a COPY of this source tree carrying one added
# reference, so the assertion is about the installer rather than about whichever
# skills happen to carry references today.
SRC2="${WORK}/src"
mkdir -p "${SRC2}"
tar -c --exclude=.git -C "${SRC}" . | tar -x -C "${SRC2}"
mkdir -p "${SRC2}/skills/help/references"
echo "step-scoped detail." > "${SRC2}/skills/help/references/detail.md"
TARGET2="${WORK}/target2"
mkdir -p "${TARGET2}/.claude"
git init -q "${TARGET2}"
REF="${TARGET2}/.claude/skills/flywheel-help/references/detail.md"

bash "${SRC2}/scripts/install-vendored.sh" "${TARGET2}" > /dev/null
[ -f "${REF}" ] || fail "references/ not vendored — every vendored body citing one would dangle"
grep -q "step-scoped detail." "${REF}" || fail "vendored reference content differs from source"
pass "references/ vendored alongside SKILL.md"

bash "${SRC2}/scripts/install-vendored.sh" "${TARGET2}" > /dev/null
[ -f "${REF}" ] || fail "references/ lost on a second, idempotent install"
pass "references/ survive a re-install"

bash "${SRC2}/scripts/install-vendored.sh" --uninstall "${TARGET2}" > /dev/null
[ ! -e "${REF}" ] || fail "vendored reference survived uninstall — it is ours to remove"
pass "references/ removed on uninstall"

# --- P41: the --agents-only mode -------------------------------------------
# Why it exists: flywheel's own repo cannot take a full vendored install (17
# duplicated skill bodies that drift), but without registered agents its dev
# loop cannot honor the `+delegate` routes it tells every other repo to plan.

echo ""
echo "== --agents-only writes agents and nothing else =="
TARGET3="${WORK}/target3"
mkdir -p "${TARGET3}/.claude"
git init -q "${TARGET3}"
echo '{"permissions":{"allow":[]}}' > "${TARGET3}/.claude/settings.json"
bash "${INSTALLER}" --agents-only "${TARGET3}" > /dev/null
[ -f "${TARGET3}/.claude/agents/executor.md" ] || fail "--agents-only did not register the executor"
[ ! -d "${TARGET3}/.claude/skills" ] || fail "--agents-only vendored skills — that is the mode's whole point"
[ ! -d "${TARGET3}/.claude/flywheel/bin" ] || fail "--agents-only wrote hook scripts"
grep -q flywheel "${TARGET3}/.claude/settings.json" && fail "--agents-only rewired settings.json"
pass "agents registered; no skills, no bin, no settings rewiring"

echo "== --agents-only never prunes an existing full install =="
TARGET4="${WORK}/target4"
mkdir -p "${TARGET4}/.claude"
git init -q "${TARGET4}"
bash "${INSTALLER}" "${TARGET4}" > /dev/null
[ -f "${TARGET4}/.claude/skills/flywheel-help/SKILL.md" ] || fail "setup: full install did not vendor skills"
bash "${INSTALLER}" --agents-only "${TARGET4}" > /dev/null
[ -f "${TARGET4}/.claude/skills/flywheel-help/SKILL.md" ] \
  || fail "--agents-only PRUNED the vendored skills — a narrowed manifest must never drive the prune"
[ -f "${TARGET4}/.claude/flywheel/bin/plan-route.sh" ] || fail "--agents-only pruned the vendored bin scripts"
pass "a narrowed run leaves the rest of a full install intact"

echo "== the flywheel repo may register its own agents, but not vendor itself =="
rm -rf "${SRC2}/.claude/agents"
bash "${SRC2}/scripts/install-vendored.sh" --agents-only "${SRC2}" > /dev/null
[ -f "${SRC2}/.claude/agents/executor.md" ] || fail "--agents-only must be allowed to self-target"
[ ! -d "${SRC2}/.claude/skills" ] || fail "a self-targeted --agents-only vendored skills into the plugin repo"
pass "self-targeted --agents-only registers the six agents"

RC=0; bash "${SRC2}/scripts/install-vendored.sh" "${SRC2}" >/dev/null 2>&1 || RC=$?
[ "${RC}" -ne 0 ] || fail "the FULL self-install must still be refused"
pass "full self-install still refused"

echo "== --uninstall is never allowed to self-target, not even with --agents-only =="
RC=0; bash "${SRC2}/scripts/install-vendored.sh" --uninstall --agents-only "${SRC2}" >/dev/null 2>&1 || RC=$?
[ "${RC}" -ne 0 ] || fail "--uninstall --agents-only must not be allowed to self-target"
[ -f "${SRC2}/.claude/agents/executor.md" ] \
  || fail "the refused uninstall DELETED the repo's committed agents"
pass "self-targeted uninstall refused, committed agents intact"

echo "== an agents-only refresh prunes an agent the plugin no longer ships =="
SRC3="${WORK}/src3"
cp -r "${SRC2}" "${SRC3}"
rm -rf "${SRC3}/.claude/agents"
TARGET5="${WORK}/target5"
mkdir -p "${TARGET5}/.claude"
git init -q "${TARGET5}"
bash "${SRC3}/scripts/install-vendored.sh" "${TARGET5}" > /dev/null
[ -f "${TARGET5}/.claude/agents/evaluator.md" ] || fail "setup: evaluator was not vendored"
[ -f "${TARGET5}/.claude/skills/flywheel-help/SKILL.md" ] || fail "setup: skills were not vendored"
rm "${SRC3}/agents/evaluator.md"            # the plugin drops an agent
bash "${SRC3}/scripts/install-vendored.sh" --agents-only "${TARGET5}" > /dev/null
[ ! -e "${TARGET5}/.claude/agents/evaluator.md" ] \
  || fail "a dropped agent survived an --agents-only refresh — the loop would still delegate to it"
grep -qxF ".claude/agents/evaluator.md" "${TARGET5}/.claude/flywheel/.manifest" \
  && fail "the dropped agent is still listed in the manifest"
[ -f "${TARGET5}/.claude/skills/flywheel-help/SKILL.md" ] \
  || fail "the agents-only prune removed a SKILL — it must only ever touch agent entries"
grep -qxF ".claude/skills/flywheel-help/SKILL.md" "${TARGET5}/.claude/flywheel/.manifest" \
  || fail "the agents-only refresh dropped a non-agent manifest entry"
pass "dropped agent pruned; skills and their manifest entries untouched"

echo "== --hooks-only wires the repo's own settings.json and writes nothing else (P43) =="
rm -rf "${SRC2}/.claude/skills" "${SRC2}/.claude/flywheel/bin"
bash "${SRC2}/scripts/install-vendored.sh" --hooks-only "${SRC2}" > /dev/null
python3 - "${SRC2}/.claude/settings.json" <<'PYCHK' || fail "--hooks-only did not register the hooks correctly"
import json, sys
d = json.load(open(sys.argv[1]))
cmds = [h["command"] for ev in d.get("hooks", {}).values() for g in ev for h in g["hooks"]]
assert len(cmds) >= 8, f"expected 8+ registrations, got {len(cmds)}"
assert all("/scripts/" in c for c in cmds), f"self-wiring must point at scripts/, got {cmds}"
assert not any("flywheel/bin" in c for c in cmds), "self-wiring must not point at vendored bin/"
PYCHK
[ ! -d "${SRC2}/.claude/skills" ] || fail "--hooks-only vendored skills"
[ ! -d "${SRC2}/.claude/flywheel/bin" ] || fail "--hooks-only wrote bin/ copies — the scripts are already there"
pass "hooks registered against scripts/; no skills, no bin/"

echo "== --hooks-only preserves unrelated settings keys =="
python3 - "${SRC2}/.claude/settings.json" <<'PYCHK' || fail "--hooks-only clobbered pre-existing settings"
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get("permissions", {}).get("allow"), "permissions.allow was lost"
assert "enabledPlugins" in d, "enabledPlugins was lost"
PYCHK
pass "permissions and marketplace keys survive"

echo "== --hooks-only is idempotent =="
cp "${SRC2}/.claude/settings.json" "${WORK}/settings-before.json"
bash "${SRC2}/scripts/install-vendored.sh" --hooks-only "${SRC2}" > /dev/null
cmp -s "${WORK}/settings-before.json" "${SRC2}/.claude/settings.json" \
  || fail "a second --hooks-only run changed settings.json"
pass "re-running changes nothing"

echo "== --hooks-only refuses a foreign target (the full install covers those) =="
RC=0; bash "${SRC2}/scripts/install-vendored.sh" --hooks-only "${TARGET3}" >/dev/null 2>&1 || RC=$?
[ "${RC}" -ne 0 ] || fail "--hooks-only must refuse a repo that is not the flywheel checkout"
pass "foreign target refused"

echo ""
echo "all installer tests passed"
