#!/usr/bin/env bash
# flywheel — test for scripts/toolbar.sh (P56): the progress toolbar is enforced
# by hooks, not remembered. Covers: no open plan → both modes no-op; an open plan
# → remind carries the live count, stop blocks a bare final reply and passes a
# toolbar one; a count naming the wrong total blocks; a closed plan, a plan only
# on the base, stop_hook_active, a non-git dir and bad stdin are all no-ops; an
# uncommitted plan counts; the transcript is read when last_assistant_message is
# absent.

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="${SRC}/scripts/toolbar.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

g() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}" >/dev/null 2>&1; }

# repo <name> -> a git repo on branch `feature`, cut from `main`
repo() {
  local r="${WORK}/$1"
  mkdir -p "${r}/.claude/flywheel/specs" "${r}/.claude/flywheel/runs"
  g "${r}" init -q -b main; echo x > "${r}/README"; g "${r}" add -A; g "${r}" commit -qm base
  g "${r}" checkout -q -b feature
  printf '%s\n' "${r}"
}

# plan <root> <slug> <n-tasks> [commit]
plan() {
  local f="$1/.claude/flywheel/specs/$2.plan.md" i
  printf '# Plan\n\n' > "${f}"
  for i in $(seq 1 "$3"); do printf '### T%s — task %s\n\n- route: `opus/high`\n\n' "${i}" "${i}" >> "${f}"; done
  [ -n "${4:-}" ] && { g "$1" add -A; g "$1" commit -qm plan; }
  return 0
}

done_line() {
  mkdir -p "$1/.claude/flywheel/runs/$2"
  printf '{"ts":"2026-09-23T10:00:00Z","task":"%s","phase":"work","state":"completed"}\n' "$3" \
    >> "$1/.claude/flywheel/runs/$2/2026-09-23.jsonl"
}

msg_json() { python3 -c 'import json,sys; print(json.dumps({"hook_event_name":"Stop","cwd":sys.argv[1],"last_assistant_message":sys.argv[2]}))' "$1" "$2"; }

stop() { RC=0; msg_json "$1" "$2" | CLAUDE_PROJECT_DIR="$1" bash "${HOOK}" stop >"${WORK}/out" 2>"${WORK}/err" || RC=$?; }
remind() { RC=0; printf '{"hook_event_name":"UserPromptSubmit","cwd":"%s"}' "$1" | CLAUDE_PROJECT_DIR="$1" bash "${HOOK}" remind >"${WORK}/out" 2>"${WORK}/err" || RC=$?; }

BAR="🟢 1/2 ▓░ · ▶ 2 wire · «wiring the hook»"

echo "== no plan on the branch: both modes are no-ops =="
R="$(repo none)"
remind "${R}"; [ "${RC}" -eq 0 ] && [ ! -s "${WORK}/out" ] || fail "remind must be silent, got ${RC}: $(cat "${WORK}/out")"
stop "${R}" "all done"; [ "${RC}" -eq 0 ] || fail "stop must pass with no open list, got ${RC}"
pass "no open list, no toolbar"

echo "== an open plan: remind carries the live count and the open tasks =="
R="$(repo open)"; plan "${R}" alpha 2 commit; done_line "${R}" alpha T1
remind "${R}"
[ "${RC}" -eq 0 ] || fail "remind must exit 0, got ${RC}"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1]))["hookSpecificOutput"]; assert d["hookEventName"]=="UserPromptSubmit"; c=d["additionalContext"]; assert "alpha" in c and "1/2" in c and "T2" in c, c' "${WORK}/out" \
  || fail "remind must emit additionalContext with slug, count and open ids: $(cat "${WORK}/out")"
pass "remind names alpha 1/2, open T2"

echo "== an open plan: a bare final reply is blocked with the expected line =="
stop "${R}" "Evals 2/2 en verde. Ahora paso la batería."
[ "${RC}" -eq 2 ] || fail "a bare reply must exit 2, got ${RC}"
grep -q "1/2" "${WORK}/err" || fail "the block must say the count: $(cat "${WORK}/err")"
pass "a reply without the toolbar cannot end the turn"

echo "== an open plan: a toolbar reply passes, whatever its state glyph =="
for first in "${BAR}" "⏸️ 1/2 ▓░ · ▶ 2 wire · «waiting on CI»" "🔴 1/2 ▓░ · ▶ 2 wire · «blocked»"; do
  stop "${R}" "$(printf '%s\n\nbody' "${first}")"
  [ "${RC}" -eq 0 ] || fail "a toolbar reply must pass, got ${RC} for: ${first} — $(cat "${WORK}/err")"
done
stop "${R}" "$(printf '\n\n%s\nbody' "${BAR}")"; [ "${RC}" -eq 0 ] || fail "leading blank lines must not hide the toolbar"
pass "🟢 ⏸️ 🔴 all pass; leading blank lines are skipped"

echo "== a toolbar counting the wrong total is blocked =="
stop "${R}" "🟢 1/3 ▓░░ · ▶ 2 wire · «x»"
[ "${RC}" -eq 2 ] || fail "a total that is not the plan's must exit 2, got ${RC}"
pass "the count is the plan's, not a feeling"

echo "== stop_hook_active never re-traps =="
RC=0; printf '{"cwd":"%s","stop_hook_active":true,"last_assistant_message":"bare"}' "${R}" \
  | CLAUDE_PROJECT_DIR="${R}" bash "${HOOK}" stop >/dev/null 2>&1 || RC=$?
[ "${RC}" -eq 0 ] || fail "stop_hook_active must pass, got ${RC}"
pass "one block per turn at most"

echo "== the transcript is read when last_assistant_message is absent =="
T="${WORK}/t.jsonl"
printf '%s\n' '{"type":"user","message":{"content":"hi"}}' \
  '{"type":"assistant","message":{"content":[{"type":"text","text":"bare note"}]}}' > "${T}"
RC=0; printf '{"cwd":"%s","transcript_path":"%s"}' "${R}" "${T}" | CLAUDE_PROJECT_DIR="${R}" bash "${HOOK}" stop >/dev/null 2>&1 || RC=$?
[ "${RC}" -eq 2 ] || fail "a bare transcript reply must exit 2, got ${RC}"
python3 -c 'import json,sys; print(json.dumps({"type":"assistant","message":{"content":[{"type":"text","text":sys.argv[1]}]}}))' "${BAR}" >> "${T}"
RC=0; printf '{"cwd":"%s","transcript_path":"%s"}' "${R}" "${T}" | CLAUDE_PROJECT_DIR="${R}" bash "${HOOK}" stop >/dev/null 2>&1 || RC=$?
[ "${RC}" -eq 0 ] || fail "the last assistant text is what counts, got ${RC}"
pass "transcript fallback reads the last assistant text"

echo "== a closed plan is a no-op =="
done_line "${R}" alpha T2
stop "${R}" "bare"; [ "${RC}" -eq 0 ] || fail "a closed plan must not require the toolbar, got ${RC}"
remind "${R}"; [ ! -s "${WORK}/out" ] || fail "remind must be silent on a closed plan: $(cat "${WORK}/out")"
pass "every task recorded → the list is closed"

echo "== a range line closes the tasks it covers =="
R="$(repo range)"; plan "${R}" alpha 3 commit; done_line "${R}" alpha T1; done_line "${R}" alpha "T2-T3"
stop "${R}" "bare"; [ "${RC}" -eq 0 ] || fail "T2-T3 must close T2 and T3, got ${RC}"
pass "task ids are read by the shared reader"

echo "== an open plan that lives only on the base is not this branch's list =="
R="${WORK}/onbase"; mkdir -p "${R}/.claude/flywheel/specs"
g "${R}" init -q -b main; plan "${R}" old 2; g "${R}" add -A; g "${R}" commit -qm base; g "${R}" checkout -q -b feature
stop "${R}" "bare"; [ "${RC}" -eq 0 ] || fail "a plan the branch did not touch must not bind, got ${RC}"
pass "only plans this branch touches are open lists"

echo "== an uncommitted plan counts =="
R="$(repo dirty)"; plan "${R}" beta 2
stop "${R}" "bare"; [ "${RC}" -eq 2 ] || fail "an untracked open plan must bind, got ${RC}"
pass "a plan not yet committed is already the list"

echo "== a non-git directory and bad stdin are no-ops =="
N="${WORK}/nogit"; mkdir -p "${N}"
stop "${N}" "bare"; [ "${RC}" -eq 0 ] || fail "non-git must pass, got ${RC}"
R="$(repo bad)"; plan "${R}" alpha 1 commit
RC=0; echo 'not json' | CLAUDE_PROJECT_DIR="${R}" bash "${HOOK}" stop >/dev/null 2>&1 || RC=$?
[ "${RC}" -eq 0 ] || fail "bad stdin must fail open, got ${RC}"
pass "fail-open on everything it cannot read"

echo "ALL PASS"
