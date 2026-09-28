#!/usr/bin/env bash
# flywheel — test for scripts/upstream-issue.sh (P70): one ledger entry becomes
# a prefilled flywheel-feedback issue URL. Covers: newest entry by default, a
# title match, the form's field ids, files kept to flywheel's surface, missing
# evidence shown as unverified, long prose truncated, the version read from the
# plugin, refusal inside flywheel's own repo, and a miss exiting 1.

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${SRC}/scripts/upstream-issue.sh"
FORM="${SRC}/.github/ISSUE_TEMPLATE/flywheel-feedback.yml"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

P="${WORK}/proj"; mkdir -p "${P}/.claude/flywheel"
LED="${P}/.claude/flywheel/LEARNINGS.md"
LONG="$(python3 -c 'print("word " * 3000)')"
cat > "${LED}" <<EOF
# flywheel learnings

## decision: flywheel se instala SOLO vendored
<!-- fw: type=decision; date=2026-09-10; files=scripts/install-vendored.sh,app/secret_domain.py,hooks/hooks.json; spec=x; branch=b; evidence=hooks fired twice in one session -->

Marketplace and vendored at once registers every hook twice.

## gotcha: the DATA.md example stops at staged
<!-- fw: type=gotcha; date=2026-09-11; files=.claude/flywheel/DATA.md -->

${LONG}
EOF

# q <url> <key> -> the decoded query value
q() { python3 -c 'import sys,urllib.parse as u; print(u.parse_qs(u.urlsplit(sys.argv[1]).query).get(sys.argv[2],[""])[0])' "$1" "$2"; }
run() { RC=0; OUT="$(CLAUDE_PROJECT_DIR="${P}" bash "${SCRIPT}" "$@" 2>"${WORK}/err")" || RC=$?; URL="$(printf '%s\n' "${OUT}" | head -1)"; }

echo "== newest entry by default, as an issue-form URL =="
run
[ "${RC}" -eq 0 ] || fail "expected 0, got ${RC}: $(cat "${WORK}/err")"
case "${URL}" in https://github.com/arazvan-ec/xmarks/issues/new\?*) ;; *) fail "bad URL: ${URL}" ;; esac
[ "$(q "${URL}" template)" = "flywheel-feedback.yml" ] || fail "template param"
[ "$(q "${URL}" labels)" = "flywheel-feedback" ] || fail "labels param"
[ "$(q "${URL}" title)" = "decision: flywheel se instala SOLO vendored" ] || fail "title: $(q "${URL}" title)"
[ "$(q "${URL}" type)" = "decision" ] || fail "type field"
q "${URL}" what | grep -q "registers every hook twice" || fail "what field"
[ "$(q "${URL}" evidence)" = "hooks fired twice in one session" ] || fail "evidence field"
pass "fields filled"

echo "== files keep only flywheel's surface =="
F="$(q "${URL}" files)"
[ "${F}" = "scripts/install-vendored.sh, hooks/hooks.json" ] || fail "files: ${F}"
pass "repo-private path dropped"

echo "== the version comes from the plugin =="
V="$(python3 -c 'import json;print(json.load(open("'"${SRC}"'/.claude-plugin/plugin.json"))["version"])')"
[ "$(q "${URL}" version)" = "${V}" ] || fail "version: $(q "${URL}" version) != ${V}"
pass "version ${V}"

echo "== a title match, missing evidence, long prose =="
run "DATA.md example"
[ "${RC}" -eq 0 ] || fail "match must succeed, got ${RC}"
[ "$(q "${URL}" type)" = "gotcha" ] || fail "matched the wrong entry"
[ "$(q "${URL}" evidence)" = "unverified" ] || fail "missing evidence must read unverified"
[ -z "$(q "${URL}" files)" ] || fail "a non-surface file must not leak: $(q "${URL}" files)"
[ "${#URL}" -lt 7500 ] || fail "URL too long: ${#URL}"
q "${URL}" what | grep -q "truncated" || fail "truncation must be said"
pass "match, unverified, truncated to ${#URL} chars"

echo "== the form carries every field the script fills =="
for id in type what evidence version files; do
  grep -qE "^ +id: ${id}\$" "${FORM}" || fail "form lacks field id ${id}"
done
grep -qE "labels: \[flywheel-feedback\]" "${FORM}" || fail "form lacks the label"
pass "form and script agree"

echo "== no match exits 1; no ledger exits 1 =="
run "nothing like this"; [ "${RC}" -eq 1 ] || fail "miss must exit 1, got ${RC}"
RC=0; CLAUDE_PROJECT_DIR="${WORK}/none" bash "${SCRIPT}" >/dev/null 2>&1 || RC=$?
[ "${RC}" -eq 1 ] || fail "no ledger must exit 1, got ${RC}"
pass "misses"

echo "== inside flywheel's own repo it refuses =="
RC=0; CLAUDE_PROJECT_DIR="${SRC}" bash "${SCRIPT}" >/dev/null 2>"${WORK}/err" || RC=$?
[ "${RC}" -eq 3 ] || fail "own repo must exit 3, got ${RC}"
grep -qi "already upstream" "${WORK}/err" || fail "refusal must say why"
pass "no self-loop"

echo "PASS: upstream-issue"
