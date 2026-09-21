#!/usr/bin/env bash
# flywheel — test for scripts/check-task-closure.sh, the gate that EXECUTES the
# `check:` every plan task already carries. Covers: a passing check is PASS and a
# failing one is FAIL by name; a prose-only check is UNRUNNABLE and not silently
# green; a command outside the allowlist is UNRUNNABLE and provably never run
# (the sentinel it would create is absent); a plan predating the cutoff is
# reported without failing; rows equal tasks; and the skip lever, a missing file
# and a broken plan all behave.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="${SRC}/scripts/check-task-closure.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }
says() { grep -q -- "$1" "${WORK}/out" || fail "output must mention '$1': $(cat "${WORK}/out")"; }
denies() { grep -q -- "$1" "${WORK}/out" && fail "output must NOT mention '$1': $(cat "${WORK}/out")"; true; }

[ -f "${GATE}" ] || fail "scripts/check-task-closure.sh does not exist yet"

# A plan fixture in its own git repo, so the cutoff (which reads the file's add
# date) has something real to read. DATE seeds that commit.
plan() { # plan <dir> <date> <task-block...>
  local dir="$1" date="$2"; shift 2
  mkdir -p "${dir}/.claude/flywheel/specs" "${dir}/scripts"
  printf '%s\n' "$@" > "${dir}/.claude/flywheel/specs/f.plan.md"
  git -C "${dir}" init -q 2>/dev/null || true
  git -C "${dir}" add -A
  GIT_AUTHOR_DATE="${date}" GIT_COMMITTER_DATE="${date}" \
    git -C "${dir}" -c user.email=t@t -c user.name=t commit -q -m seed
}
run() { RC=0; bash "${GATE}" "$@" >"${WORK}/out" 2>&1 || RC=$?; }
rc() { [ "${RC}" -eq "$1" ] || fail "expected exit $1, got ${RC}: $(cat "${WORK}/out")"; }

NOW="2026-09-21T12:00:00Z"
OLD="2026-01-01T12:00:00Z"

echo "== a check whose command exits 0 is PASS =="
plan "${WORK}/a" "${NOW}" \
  '### T1 — green' '- route: `opus/high`' '- risk: highest' '- check: `true` and the sweep clean.'
run "${WORK}/a"; rc 0
says "T1"; says "PASS"
pass "a passing check is PASS and the gate exits 0"

echo "== a check whose command exits non-zero is FAIL, named, and reddens the gate =="
plan "${WORK}/b" "${NOW}" \
  '### T1 — red' '- route: `opus/high`' '- risk: highest' '- check: `false` is what it runs.'
run "${WORK}/b"; rc 1
says "T1"; says "FAIL"
pass "a failing check exits 1 and names the task"

echo "== a prose-only check is UNRUNNABLE, never PASS =="
plan "${WORK}/c" "${NOW}" \
  '### T1 — prose' '- route: `opus/high`' '- risk: highest' '- check: the operator reads it and agrees.'
run "${WORK}/c"; rc 1
says "T1"; says "UNRUNNABLE"; denies "PASS"
pass "a prose-only check after the cutoff is UNRUNNABLE and fails"

echo "== a command outside the allowlist is UNRUNNABLE and PROVABLY never executed =="
SENTINEL="${WORK}/sentinel"
plan "${WORK}/d" "${NOW}" \
  '### T1 — hostile' '- route: `opus/high`' '- risk: highest' \
  "- check: \`touch ${SENTINEL}\` proves it ran."
run "${WORK}/d"; rc 1
says "UNRUNNABLE"
[ -e "${SENTINEL}" ] && fail "the gate EXECUTED a command outside the allowlist — the allowlist is the whole security boundary"
pass "a non-allowlisted command is never executed and never green"

echo "== a shell operator after an allowlisted script is refused, and never runs =="
# Codex P1 on PR #92: `( .*)?` in the allowlist swallowed the whole suffix, and
# the span then went to `bash -c`. An allowlisted prefix bought arbitrary
# execution — the exact boundary the allowlist is claimed to be.
mkdir -p "${WORK}/n/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' > "${WORK}/n/scripts/test-ok.sh"
chmod +x "${WORK}/n/scripts/test-ok.sh"
PWNED="${WORK}/PWNED"
plan "${WORK}/n" "${NOW}" \
  '### T1 — chained' '- route: `sonnet/medium`' "- check: \`bash scripts/test-ok.sh && touch ${PWNED}.a\` green." \
  '### T2 — semicolon' '- route: `sonnet/medium`' "- check: \`bash scripts/test-ok.sh; touch ${PWNED}.b\` green." \
  '### T3 — substitution' '- route: `opus/high`' '- risk: highest' "- check: \`bash scripts/test-ok.sh \$(touch ${PWNED}.c)\` green."
run "${WORK}/n"; rc 1
says "UNRUNNABLE"; denies "PASS"
for sfx in a b c; do
  [ -e "${PWNED}.${sfx}" ] && fail "a shell operator executed (${sfx}) — the allowlisted prefix bought arbitrary execution"
done
pass "an allowlisted prefix cannot smuggle a second command"

echo "== ordinary arguments after an allowlisted script still run =="
mkdir -p "${WORK}/o/scripts"
printf '#!/usr/bin/env bash\n[ "$1" = "--flag" ] || exit 3\nexit 0\n' > "${WORK}/o/scripts/test-ok.sh"
chmod +x "${WORK}/o/scripts/test-ok.sh"
plan "${WORK}/o" "${NOW}" \
  '### T1 — args' '- route: `opus/high`' '- risk: highest' '- check: `bash scripts/test-ok.sh --flag` green.'
run "${WORK}/o"; rc 0
says "PASS"
pass "a plain argument list is not collateral damage"

echo "== a plan predating the cutoff is reported, never failed (P18: no backfill) =="
plan "${WORK}/e" "${OLD}" \
  '### T1 — old prose' '- route: `opus/high`' '- risk: highest' '- check: the operator agreed back then.'
run "${WORK}/e"; rc 0
says "UNRUNNABLE"
pass "pre-cutoff corpus is named and counted without reddening the gate"

echo "== rows equal tasks: nothing collapses two items into one line =="
plan "${WORK}/f" "${NOW}" \
  '### T1 — one' '- route: `sonnet/medium`' '- check: `true`' \
  '### T2 — two' '- route: `sonnet/medium`' '- check: `true`' \
  '### T3 — three' '- route: `opus/high`' '- risk: highest' '- check: `true`'
run "${WORK}/f"; rc 0
ROWS="$(grep -cE '^ *T[0-9]+ ' "${WORK}/out" || true)"
[ "${ROWS}" -eq 3 ] || fail "3 tasks must produce 3 rows, got ${ROWS}: $(cat "${WORK}/out")"
says "3"
pass "N tasks in, N rows out"

echo "== a single plan path resolves the repo root, not its parent =="
mkdir -p "${WORK}/m/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' > "${WORK}/m/scripts/test-thing.sh"
chmod +x "${WORK}/m/scripts/test-thing.sh"
plan "${WORK}/m" "${NOW}" \
  '### T1 — cites a repo script' '- route: `opus/high`' '- risk: highest' '- check: `bash scripts/test-thing.sh` green.'
run "${WORK}/m/.claude/flywheel/specs/f.plan.md"; rc 0
says "PASS"
# 127 is the tell: the check ran from a directory where scripts/ does not exist.
denies "127"
pass "a plan passed by path runs its checks from the repo root"

# run <dir> <json-line>   — give the fixture's cycle a telemetry record
runline() { mkdir -p "$1/.claude/flywheel/runs/f"; printf '%s\n' "$2" >> "$1/.claude/flywheel/runs/f/d.jsonl"; }

echo "== an instrumented cycle with no line for a task reports PENDING, and never runs its check =="
mkdir -p "${WORK}/p/scripts"
MARK="${WORK}/p-ran"
printf '#!/usr/bin/env bash\ntouch %s\nexit 0\n' "${MARK}" > "${WORK}/p/scripts/test-mark.sh"
chmod +x "${WORK}/p/scripts/test-mark.sh"
plan "${WORK}/p" "${NOW}" \
  '### T1 — not started' '- route: `opus/high`' '- risk: highest' '- check: `bash scripts/test-mark.sh` green.'
# The spec transition exists, so the cycle IS instrumented; T1 simply has no line.
runline "${WORK}/p" '{"ts":"2026-09-21T10:00:00Z","task":"spec","phase":"spec","state":"completed"}'
run "${WORK}/p"; rc 0
says "PENDING"; denies "FAIL"
[ -e "${MARK}" ] && fail "a PENDING task's check was executed — not-started must not be graded"
pass "a task the ledger never recorded is PENDING, not FAIL, and its check does not run"

echo "== a recorded task is still graded beside a pending one =="
mkdir -p "${WORK}/q/scripts"
printf '#!/usr/bin/env bash\nexit 1\n' > "${WORK}/q/scripts/test-red.sh"
chmod +x "${WORK}/q/scripts/test-red.sh"
plan "${WORK}/q" "${NOW}" \
  '### T1 — ran and fails' '- route: `sonnet/medium`' '- check: `bash scripts/test-red.sh` green.' \
  '### T2 — not started' '- route: `opus/high`' '- risk: highest' '- check: `bash scripts/test-red.sh` green.'
runline "${WORK}/q" '{"ts":"2026-09-21T10:00:00Z","task":"T1","phase":"work","state":"completed"}'
run "${WORK}/q"; rc 1
says "FAIL"; says "PENDING"
pass "PENDING does not launder a recorded task's red"

echo "== a merged transition line records every task it spans =="
mkdir -p "${WORK}/r/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' > "${WORK}/r/scripts/test-ok.sh"
chmod +x "${WORK}/r/scripts/test-ok.sh"
plan "${WORK}/r" "${NOW}" \
  '### T1 — a' '- route: `sonnet/medium`' '- check: `bash scripts/test-ok.sh` green.' \
  '### T2 — b' '- route: `opus/high`' '- risk: highest' '- check: `bash scripts/test-ok.sh` green.'
runline "${WORK}/r" '{"ts":"2026-09-21T10:00:00Z","task":"T1-T2","phase":"work","state":"completed"}'
run "${WORK}/r"; rc 0
says "PASS"; denies "PENDING"
pass "T1-T2 records both, so neither reads as unstarted"

echo "== an uninstrumented repo is graded as before, not silently un-graded =="
mkdir -p "${WORK}/s/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' > "${WORK}/s/scripts/test-ok.sh"
chmod +x "${WORK}/s/scripts/test-ok.sh"
plan "${WORK}/s" "${NOW}" \
  '### T1 — no telemetry anywhere' '- route: `opus/high`' '- risk: highest' '- check: `bash scripts/test-ok.sh` green.'
run "${WORK}/s"; rc 0
says "PASS"; denies "PENDING"
pass "no run directory means the cycle keeps no ledger, so every task is still graded"

echo "== the skip lever takes a reason and says so =="
plan "${WORK}/g" "${NOW}" \
  '### T1 — red' '- route: `opus/high`' '- risk: highest' '- check: `false`'
RC=0; SKIP_TASK_CLOSURE="checked by hand" bash "${GATE}" "${WORK}/g" >"${WORK}/out" 2>&1 || RC=$?
rc 0; says "SKIPPED"; says "checked by hand"
pass "SKIP_TASK_CLOSURE=<reason> skips loudly, never silently"

echo "== a tree with no plans is not a failure =="
mkdir -p "${WORK}/h/.claude/flywheel/specs"
run "${WORK}/h"; rc 0
pass "no plans → exit 0"

echo "== the allowlist matches the shape every real check uses =="
mkdir -p "${WORK}/j/scripts"
printf '#!/usr/bin/env bash\nexit 0\n' > "${WORK}/j/scripts/test-thing.sh"
chmod +x "${WORK}/j/scripts/test-thing.sh"
plan "${WORK}/j" "${NOW}" \
  '### T1 — bare path' '- route: `sonnet/medium`' '- check: `scripts/test-thing.sh` green.' \
  '### T2 — bash prefix' '- route: `sonnet/medium`' '- check: `bash scripts/test-thing.sh` green.' \
  '### T3 — dot-slash' '- route: `opus/high`' '- risk: highest' '- check: `bash ./scripts/test-thing.sh` green.'
run "${WORK}/j"; rc 0
[ "$(grep -c "PASS" "${WORK}/out")" -ge 3 ] || fail "all three spellings of a repo script must be runnable: $(cat "${WORK}/out")"
pass "bare, bash-prefixed and ./-prefixed repo scripts all run"

echo "== a pre-cutoff plan the linter rejects is corpus, not a red gate =="
mkdir -p "${WORK}/k/.claude/flywheel/specs"
printf 'no task blocks here at all\n' > "${WORK}/k/.claude/flywheel/specs/f.plan.md"
git -C "${WORK}/k" init -q 2>/dev/null || true
git -C "${WORK}/k" add -A
GIT_AUTHOR_DATE="${OLD}" GIT_COMMITTER_DATE="${OLD}" \
  git -C "${WORK}/k" -c user.email=t@t -c user.name=t commit -q -m seed
run "${WORK}/k"; rc 0
says "UNLINTABLE"
pass "an old unlintable plan is named and skipped, never exit 2"

echo "== a plan the linter rejects is unusable input, not a green =="
plan "${WORK}/i" "${NOW}" '### T1 — no route at all' '- check: `true`'
run "${WORK}/i"; rc 2
pass "an unlintable plan exits 2 and is never read as passing"

echo "ALL PASS"
