#!/usr/bin/env bash
# flywheel — test for scripts/compound-due.sh (P69): a run this branch shipped
# must carry a compound line before the turn can end. Covers: shipped without
# compound blocks and names the slug; a compound line with 0 entries satisfies;
# a run only on the base, a run with no ship line, stop_hook_active, a non-git
# dir and bad stdin are no-ops; an uncommitted run counts; malformed lines are
# skipped.

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="${SRC}/scripts/compound-due.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

g() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}" >/dev/null 2>&1; }

repo() {
  local r="${WORK}/$1"
  mkdir -p "${r}/.claude/flywheel/runs"
  g "${r}" init -q -b main; echo x > "${r}/README"; g "${r}" add -A; g "${r}" commit -qm base
  g "${r}" checkout -q -b feature
  printf '%s\n' "${r}"
}

# line <root> <slug> <phase> [extra-json-fields]
line() {
  mkdir -p "$1/.claude/flywheel/runs/$2"
  printf '{"ts":"2026-09-28T10:00:00Z","task":"T1","phase":"%s","state":"completed"%s}\n' "$3" "${4:-}" \
    >> "$1/.claude/flywheel/runs/$2/2026-09-28.jsonl"
}
commit() { g "$1" add -A; g "$1" commit -qm "$2"; }

stop() {
  RC=0
  printf '{"hook_event_name":"Stop","cwd":"%s"%s}' "$1" "${2:-}" \
    | CLAUDE_PROJECT_DIR="$1" bash "${HOOK}" >"${WORK}/out" 2>"${WORK}/err" || RC=$?
}

echo "== shipped on this branch, no compound line: blocks and names the slug =="
R="$(repo due)"; line "${R}" alpha work; line "${R}" alpha ship; commit "${R}" run
stop "${R}"
[ "${RC}" -eq 2 ] || fail "expected exit 2, got ${RC}"
grep -q "alpha" "${WORK}/err" || fail "message must name the slug: $(cat "${WORK}/err")"
grep -q "/flywheel:compound" "${WORK}/err" || fail "message must name the fix: $(cat "${WORK}/err")"
grep -q '"entries": *0' "${WORK}/err" || fail "message must give the escape line: $(cat "${WORK}/err")"
pass "due run blocks"

echo "== a compound line with 0 entries and a reason satisfies =="
line "${R}" alpha compound ',"entries":0,"reason":"nothing durable"'; commit "${R}" compound
stop "${R}"; [ "${RC}" -eq 0 ] || fail "compound line must satisfy, got ${RC}: $(cat "${WORK}/err")"
pass "explicit outcome satisfies"

echo "== an uncommitted ship line counts =="
R="$(repo dirty)"; line "${R}" beta ship
stop "${R}"; [ "${RC}" -eq 2 ] || fail "uncommitted ship must block, got ${RC}"
pass "uncommitted run counts"

echo "== a run shipped only on the base is ignored =="
R="$(repo base)"; g "${R}" checkout -q main; line "${R}" old ship; commit "${R}" old
g "${R}" checkout -q feature; g "${R}" merge -q main
stop "${R}"; [ "${RC}" -eq 0 ] || fail "base-only run must not block, got ${RC}: $(cat "${WORK}/err")"
pass "base run ignored"

echo "== on the only branch there is nothing to compare against: old runs never block =="
R="${WORK}/solo"; mkdir -p "${R}/.claude/flywheel/runs"
g "${R}" init -q -b main; line "${R}" hist ship; commit "${R}" old
stop "${R}"; [ "${RC}" -eq 0 ] || fail "main-only history must not block, got ${RC}: $(cat "${WORK}/err")"
C="${WORK}/clone"; g "${WORK}" clone -q "${R}" "${C}"
stop "${C}"; [ "${RC}" -eq 0 ] || fail "a clone with only main + origin/main must not block, got ${RC}"
line "${C}" fresh ship
stop "${C}"; [ "${RC}" -eq 2 ] || fail "an uncommitted ship on the only branch must still block, got ${RC}"
pass "no comparison ref: only uncommitted runs count"

echo "== no ship line: not due =="
R="$(repo noship)"; line "${R}" gamma work; line "${R}" gamma verify; commit "${R}" run
stop "${R}"; [ "${RC}" -eq 0 ] || fail "no ship line must not block, got ${RC}"
pass "unshipped run ignored"

echo "== malformed lines are skipped, a valid ship still counts =="
R="$(repo junk)"; mkdir -p "${R}/.claude/flywheel/runs/delta"
printf 'not json\n[1,2]\n' > "${R}/.claude/flywheel/runs/delta/2026-09-28.jsonl"; line "${R}" delta ship; commit "${R}" run
stop "${R}"; [ "${RC}" -eq 2 ] || fail "valid ship among junk must block, got ${RC}"
pass "junk skipped"

echo "== stop_hook_active never re-traps =="
R="$(repo active)"; line "${R}" eps ship; commit "${R}" run
stop "${R}" ',"stop_hook_active":true'; [ "${RC}" -eq 0 ] || fail "stop_hook_active must pass, got ${RC}"
pass "no re-trap"

echo "== non-git dir and bad stdin are no-ops =="
N="${WORK}/nogit"; mkdir -p "${N}/.claude/flywheel/runs/z"; printf '{"phase":"ship"}\n' > "${N}/.claude/flywheel/runs/z/a.jsonl"
stop "${N}"; [ "${RC}" -eq 0 ] || fail "non-git must pass, got ${RC}"
RC=0; printf 'garbage' | CLAUDE_PROJECT_DIR="${N}" bash "${HOOK}" >/dev/null 2>&1 || RC=$?
[ "${RC}" -eq 0 ] || fail "bad stdin must pass, got ${RC}"
pass "fail-open"

echo "PASS: compound-due"
