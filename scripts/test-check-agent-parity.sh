#!/usr/bin/env bash
# flywheel — test for scripts/check-agent-parity.sh (P41). The gate guards two
# copies of every agent: agents/*.md (what the plugin ships) and
# .claude/agents/*.md (what registers as a subagent type in this repo's own
# sessions). Covers: parity holds; a drifted copy fails; a source with no
# registered copy fails; an orphan copy fails; the installer's /flywheel:
# rewrite counts as parity, not drift; a missing agents/ dir is unusable input;
# the skip is logged, never silent; and the real repo passes.

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="${SRC}/scripts/check-agent-parity.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

# repo <name> — a throwaway tree with agents/ and .claude/agents/
repo() {
  local r="${WORK}/$1"
  mkdir -p "${r}/agents" "${r}/.claude/agents"
  printf '%s\n' "$r"
}

# agent <root> <dir> <name> <body>
agent() { mkdir -p "$1/$2"; printf -- '---\nname: %s\n---\n%s\n' "$3" "$4" > "$1/$2/$3.md"; }

run() { RC=0; bash "${GATE}" "$@" >"${WORK}/out" 2>&1 || RC=$?; }

echo "== parity holds =="
R="$(repo ok)"
agent "${R}" agents executor "mechanical tier"
agent "${R}" .claude/agents executor "mechanical tier"
run "${R}"
[ "${RC}" -eq 0 ] || fail "identical copies must pass, got ${RC}: $(cat "${WORK}/out")"
pass "identical copies pass"

echo "== a drifted copy fails and names the file =="
R="$(repo drift)"
agent "${R}" agents executor "mechanical tier"
agent "${R}" .claude/agents executor "STALE tier"
run "${R}"
[ "${RC}" -eq 1 ] || fail "drift must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q "executor" "${WORK}/out" || fail "drift must name the agent: $(cat "${WORK}/out")"
pass "drift exits 1 and names executor"

echo "== a source agent with no registered copy fails =="
R="$(repo missing)"
agent "${R}" agents executor "mechanical tier"
agent "${R}" agents verifier "objective gate"
agent "${R}" .claude/agents executor "mechanical tier"
run "${R}"
[ "${RC}" -eq 1 ] || fail "an unregistered agent must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q "verifier" "${WORK}/out" || fail "must name the unregistered agent: $(cat "${WORK}/out")"
pass "unregistered source agent exits 1 and is named"

echo "== an orphan registered copy fails (the other direction) =="
R="$(repo orphan)"
agent "${R}" agents executor "mechanical tier"
agent "${R}" .claude/agents executor "mechanical tier"
agent "${R}" .claude/agents ghost "no longer shipped"
run "${R}"
[ "${RC}" -eq 1 ] || fail "an orphan copy must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q "ghost" "${WORK}/out" || fail "must name the orphan: $(cat "${WORK}/out")"
pass "orphan copy exits 1 and is named"

echo "== the installer's /flywheel: rewrite is parity, not drift =="
R="$(repo rewrite)"
agent "${R}" agents executor "see /flywheel:work for the route contract"
agent "${R}" .claude/agents executor "see /flywheel-work for the route contract"
run "${R}"
[ "${RC}" -eq 0 ] || fail "the rewritten copy must count as parity, got ${RC}: $(cat "${WORK}/out")"
pass "rewritten copy counts as parity"

echo "== a rewrite the copy did NOT apply is still drift =="
R="$(repo norewrite)"
agent "${R}" agents executor "see /flywheel:work for the route contract"
agent "${R}" .claude/agents executor "see /flywheel:work for the route contract"
run "${R}"
[ "${RC}" -eq 1 ] || fail "an unrewritten copy must exit 1, got ${RC}: $(cat "${WORK}/out")"
pass "unrewritten copy is drift"

echo "== no agents/ dir is unusable input, not a pass =="
R="${WORK}/bare"; mkdir -p "${R}"
run "${R}"
[ "${RC}" -eq 2 ] || fail "a tree with no agents/ must exit 2, got ${RC}: $(cat "${WORK}/out")"
pass "missing agents/ exits 2"

echo "== an absent .claude/agents/ fails loudly (nothing is registered) =="
R="${WORK}/unregistered"; mkdir -p "${R}/agents"
agent "${R}" agents executor "mechanical tier"
run "${R}"
[ "${RC}" -eq 1 ] || fail "no registered agents at all must exit 1, got ${RC}: $(cat "${WORK}/out")"
pass "absent .claude/agents/ exits 1"

echo "== the skip is logged, never silent =="
R="$(repo skipme)"
agent "${R}" agents executor "mechanical tier"
agent "${R}" .claude/agents executor "STALE tier"
RC=0; SKIP_AGENT_PARITY=1 bash "${GATE}" "${R}" >"${WORK}/out" 2>&1 || RC=$?
[ "${RC}" -eq 0 ] || fail "the skip must exit 0, got ${RC}: $(cat "${WORK}/out")"
grep -qi "skip" "${WORK}/out" || fail "the skip must announce itself: $(cat "${WORK}/out")"
pass "skip exits 0 with a logged notice"

echo "== the real repo is in parity =="
run "${SRC}"
[ "${RC}" -eq 0 ] || fail "this repo must be in agent parity, got ${RC}: $(cat "${WORK}/out")"
pass "flywheel's own agents are registered and in parity"

echo "ALL PASS"
