#!/usr/bin/env bash
# flywheel — test for the invocation-budget gate, scripts/check-invocation-budget.sh
# (P35, retargeted by P36). P35 measured the body alone, which paid a skill for
# moving a hot-path rule into a reference the very same invocation then reads;
# P36 adds `worst` = body + every distinct reference reachable from it, so the
# measured number cannot be gamed. Covers: both ceilings; per-skill exceptions;
# transitive citations, a file cited twice counted once, and citation cycles;
# dangling citations in a body AND one level down; the retired single-number
# budget file failing loudly instead of being coerced; the breakdown ordered
# largest first and flushed before the verdict; the env overrides and the
# logged escape.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${SRC}/scripts/check-invocation-budget.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

# A citation cycle must terminate; without a bound a regression hangs CI instead
# of failing it.
TMO=(); command -v timeout >/dev/null 2>&1 && TMO=(timeout 30)

# budget <root> <line>... — the keyed budget file
budget() {
  local root="$1"; shift
  mkdir -p "${root}/scripts"
  printf '%s\n' "$@" > "${root}/scripts/invocation-budget.txt"
}

# skill <root> <name> <body-bytes> [citation...] — a SKILL.md padded to an exact
# total size, so the ceiling under test is an exact boundary and not an estimate.
skill() {
  local root="$1" name="$2" target="$3"; shift 3
  local dir="${root}/skills/${name}"
  mkdir -p "${dir}"
  { echo "---"; echo "name: ${name}"; echo "description: a test skill."; echo "---"; echo
    echo "# /flywheel:${name}"
    for c in "$@"; do echo "See \`${c}\` for the detail."; done; } > "${dir}/SKILL.md"
  local now pad
  now=$(wc -c < "${dir}/SKILL.md")
  pad=$(( target - now ))
  if [ "${pad}" -gt 0 ]; then head -c "${pad}" < /dev/zero | tr '\0' 'x' >> "${dir}/SKILL.md"; fi
}

# reference <root> <skill> <topic> <bytes> [citation...] — the file a citation
# must resolve to, padded like a body so `worst` is an exact boundary too.
reference() {
  local root="$1" name="$2" topic="$3" target="$4"; shift 4
  local f="${root}/skills/${name}/references/${topic}"
  mkdir -p "$(dirname "${f}")"
  { echo "detail."; for c in "$@"; do echo "See \`${c}\`."; done; } > "${f}"
  local now pad
  now=$(wc -c < "${f}")
  pad=$(( target - now ))
  if [ "${pad}" -gt 0 ]; then head -c "${pad}" < /dev/zero | tr '\0' 'x' >> "${f}"; fi
}

# run_check <root> [VAR=val ...] -> sets RC, output in ${WORK}/out
run_check() {
  local root="$1"; shift
  RC=0
  (cd "${root}" && env "$@" "${TMO[@]}" bash "${CHECK}" >"${WORK}/out" 2>&1) || RC=$?
}

echo "== every skill under both ceilings passes =="
R1="${WORK}/r1"
budget "${R1}" "# defaults, bytes" "body 4500" "worst 9000"
skill "${R1}" alpha 4500          # exactly at the body ceiling — must pass
skill "${R1}" beta  1200
run_check "${R1}"
[ "${RC}" -eq 0 ] || fail "skills at/under both ceilings must pass, got ${RC}: $(cat "${WORK}/out")"
grep -q 4500 "${WORK}/out" || fail "success output must report the worst case: $(cat "${WORK}/out")"
pass "at/under both ceilings → exit 0, reports the worst case"

echo "== over the body ceiling fails and names every offender =="
R2="${WORK}/r2"
budget "${R2}" "body 2000" "worst 9000"
skill "${R2}" tiny  500
skill "${R2}" hoggy 6000
skill "${R2}" middy 2500
run_check "${R2}"
[ "${RC}" -eq 1 ] || fail "a body over the ceiling must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q hoggy "${WORK}/out" || fail "failure must name the worst skill: $(cat "${WORK}/out")"
grep -q middy "${WORK}/out" || fail "failure must name EVERY over-budget skill, not only the worst"
grep -q 2000  "${WORK}/out" || fail "failure must state the ceiling"
grep -q "OVER body" "${WORK}/out" || fail "the breakdown must mark WHICH ceiling the row breached"
pass "over the body ceiling → exit 1, names hoggy and middy and the ceiling"

echo "== breakdown is ordered, largest first =="
[ "$(grep -n hoggy "${WORK}/out" | cut -d: -f1 | head -1)" -lt \
  "$(grep -n middy "${WORK}/out" | cut -d: -f1 | head -1)" ] \
  || fail "breakdown must list the largest skill before the smaller one"
[ "$(grep -n middy "${WORK}/out" | cut -d: -f1 | head -1)" -lt \
  "$(grep -n tiny  "${WORK}/out" | cut -d: -f1 | head -1)" ] \
  || fail "breakdown must list every skill in descending size order"
pass "breakdown ordered largest first"

echo "== the breakdown precedes the verdict it refers to =="
# Regression: the breakdown goes to stdout and the verdict to stderr, and CI
# redirects both into one stream. With stdout block-buffered — any environment
# that does not set PYTHONUNBUFFERED, GitHub's runners among them — an unflushed
# stdout puts the verdict first, and a reader has to reorder the output in their
# head. Asserted with the buffering the runner actually has, not the one this
# machine happens to have.
(cd "${R2}" && env -u PYTHONUNBUFFERED bash "${CHECK}" >"${WORK}/buf" 2>&1) || true
[ "$(grep -n "^  hoggy" "${WORK}/buf" | cut -d: -f1 | head -1)" -lt \
  "$(grep -n "^invocation-budget:" "${WORK}/buf" | cut -d: -f1 | head -1)" ] \
  || fail "the verdict landed before the breakdown: $(cat "${WORK}/buf")"
pass "breakdown precedes the verdict under block-buffered stdout"

echo "== a fine body whose references blow the worst case fails =="
# The P36 invariant: moving a rule the invocation still reads out of the body
# must not improve the measured number.
R3="${WORK}/r3"
budget "${R3}" "body 2000" "worst 3000"
skill "${R3}" fatref 1000 "references/detail.md"
reference "${R3}" fatref detail.md 5000
run_check "${R3}"
[ "${RC}" -eq 1 ] || fail "body under, worst over must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q fatref "${WORK}/out" || fail "the failure must name the skill: $(cat "${WORK}/out")"
grep -q "OVER worst" "${WORK}/out" || fail "the breakdown must mark the WORST ceiling breached, not the body"
grep -q 6000 "${WORK}/out" || fail "the failure must state the measured worst case (1000 body + 5000 ref)"
pass "body ok, worst over → exit 1, names worst and the measured total"

echo "== a per-skill exception lets a skill exceed the defaults =="
R4="${WORK}/r4"
budget "${R4}" "body 1000" "worst 2000"
skill "${R4}" greedy 1500 "references/detail.md"
reference "${R4}" greedy detail.md 1000
run_check "${R4}"
[ "${RC}" -eq 1 ] || fail "without an exception greedy must fail, got ${RC}: $(cat "${WORK}/out")"
budget "${R4}" "body 1000" "worst 2000" "# debt, not a new normal" "greedy body=1600 worst=2600"
run_check "${R4}"
[ "${RC}" -eq 0 ] || fail "a per-skill exception must let greedy exceed the defaults, got ${RC}: $(cat "${WORK}/out")"
budget "${R4}" "body 1000" "worst 2000" "greedy body=1600"
run_check "${R4}"
[ "${RC}" -eq 1 ] || fail "an exception must raise only the key it names — worst 2000 still binds"
pass "per-skill exception applies, and only to the key it names"

echo "== an exception naming no skill is stale, and fails =="
R4B="${WORK}/r4b"
budget "${R4B}" "body 1000" "worst 2000" "ghost body=9000"
skill "${R4B}" real 500
run_check "${R4B}"
[ "${RC}" -eq 1 ] || fail "an exception for a skill that does not exist must fail, got ${RC}: $(cat "${WORK}/out")"
grep -q "ghost" "${WORK}/out" || fail "the failure must name the stale exception"
pass "a stale exception (renamed or deleted skill) fails and is named"

echo "== a transitive citation is counted =="
R5="${WORK}/r5"
budget "${R5}" "body 2000" "worst 2500"
skill "${R5}" chain 1000 "references/one.md"
reference "${R5}" chain one.md 1000 "references/two.md"
reference "${R5}" chain two.md 1000
run_check "${R5}"
[ "${RC}" -eq 1 ] || fail "a reference cited BY a reference must count toward worst, got ${RC}: $(cat "${WORK}/out")"
grep -q 3000 "${WORK}/out" || fail "worst must be 1000+1000+1000: $(cat "${WORK}/out")"
budget "${R5}" "body 2000" "worst 3000"
run_check "${R5}"
[ "${RC}" -eq 0 ] || fail "the transitive total is exactly 3000, so 3000 must pass: $(cat "${WORK}/out")"
pass "transitive citation counted, exactly once each"

echo "== a file cited twice is counted once =="
R6="${WORK}/r6"
budget "${R6}" "body 2000" "worst 2500"
skill "${R6}" twice 1000 "references/detail.md" "references/detail.md"
reference "${R6}" twice detail.md 1000
run_check "${R6}"
[ "${RC}" -eq 0 ] || fail "a reference cited twice is loaded once; double counting breaks the budget: $(cat "${WORK}/out")"
grep -q 2000 "${WORK}/out" || fail "worst must be 1000+1000, not 1000+2000: $(cat "${WORK}/out")"
pass "repeated citation counted once"

echo "== a citation cycle terminates =="
R7="${WORK}/r7"
budget "${R7}" "body 2000" "worst 4000"
skill "${R7}" cyclic 1000 "references/a.md"
reference "${R7}" cyclic a.md 1000 "references/b.md"
reference "${R7}" cyclic b.md 1000 "references/a.md"
run_check "${R7}"
[ "${RC}" -eq 0 ] || fail "a reference cycle must terminate and count each file once, got ${RC}: $(cat "${WORK}/out")"
pass "citation cycle → terminates, each file counted once"

echo "== a resolvable citation passes =="
R8="${WORK}/r8"
budget "${R8}" "body 4500" "worst 9000"
skill "${R8}" cited 1000 "skills/cited/references/detail.md"
reference "${R8}" cited detail.md 100
run_check "${R8}"
[ "${RC}" -eq 0 ] || fail "a citation that resolves must pass, got ${RC}: $(cat "${WORK}/out")"
pass "citation that resolves → exit 0"

echo "== a dangling citation fails even when every body fits =="
R9="${WORK}/r9"
budget "${R9}" "body 4500" "worst 9000"
skill "${R9}" dangler 1000 "skills/dangler/references/missing.md"
run_check "${R9}"
[ "${RC}" -eq 1 ] || fail "a body citing a reference that does not exist must exit 1, got ${RC}"
grep -q dangler    "${WORK}/out" || fail "the error must name the skill: $(cat "${WORK}/out")"
grep -q missing.md "${WORK}/out" || fail "the error must name the unresolved path"
pass "dangling citation → fails, names skill and path"

echo "== a dangling citation INSIDE a reference fails too =="
# A rule lost one level down is lost just as silently as one lost in the body.
R10="${WORK}/r10"
budget "${R10}" "body 4500" "worst 9000"
skill "${R10}" deep 1000 "references/one.md"
reference "${R10}" deep one.md 200 "references/gone.md"
run_check "${R10}"
[ "${RC}" -eq 1 ] || fail "a reference citing a missing file must exit 1, got ${RC}: $(cat "${WORK}/out")"
grep -q gone.md "${WORK}/out" || fail "the error must name the unresolved path: $(cat "${WORK}/out")"
grep -q deep    "${WORK}/out" || fail "the error must name the owning skill"
pass "dangling citation one level down → fails, names skill and path"

echo "== a bare references/ citation resolves against the skill dir =="
R11="${WORK}/r11"
budget "${R11}" "body 4500" "worst 9000"
skill "${R11}" bare 1000 "references/detail.md"
reference "${R11}" bare detail.md 100
run_check "${R11}"
[ "${RC}" -eq 0 ] || fail "a bare references/ path must resolve against its own skill dir, got ${RC}: $(cat "${WORK}/out")"
pass "bare references/ citation resolves against the skill dir"

echo "== missing budget file fails loudly =="
R12="${WORK}/r12"; mkdir -p "${R12}/scripts"
skill "${R12}" alpha 100
run_check "${R12}"
[ "${RC}" -eq 2 ] || fail "no budget file and no override must exit 2, got ${RC}"
grep -qi "budget" "${WORK}/out" || fail "the error must say the budget is missing"
pass "missing budget file → exit 2, loud"

echo "== an unparseable budget line fails loudly =="
R13="${WORK}/r13"
budget "${R13}" "four thousand"
skill "${R13}" alpha 100
run_check "${R13}"
[ "${RC}" -eq 2 ] || fail "an unparseable budget must exit 2, not be coerced, got ${RC}"
pass "unparseable budget line → exit 2, loud"

echo "== the retired single-number budget file fails loudly =="
# v0.45.0 shipped a bare integer here. Coercing it to one of the two keys would
# leave the other silently undefined — exactly the unset ceiling P36 exists to
# remove.
R14="${WORK}/r14"
budget "${R14}" "5300"
skill "${R14}" alpha 100
run_check "${R14}"
[ "${RC}" -eq 2 ] || fail "a bare legacy number must exit 2, got ${RC}: $(cat "${WORK}/out")"
grep -qiE "format|body|worst" "${WORK}/out" || fail "the error must tell the maintainer the format changed: $(cat "${WORK}/out")"
pass "legacy bare number → exit 2, says the format changed"

echo "== comments and blank lines are ignored =="
R15="${WORK}/r15"
budget "${R15}" "# defaults, bytes" "" "body 4500   # the tightest current occupant + headroom" "worst 9000" ""
skill "${R15}" alpha 1000
run_check "${R15}"
[ "${RC}" -eq 0 ] || fail "comments and blank lines must be ignored, got ${RC}: $(cat "${WORK}/out")"
pass "comments and blank lines ignored"

echo "== an empty body fails loudly, never as zero =="
R16="${WORK}/r16"
budget "${R16}" "body 4500" "worst 9000"
mkdir -p "${R16}/skills/hollow"
{ echo "---"; echo "name: hollow"; echo "description: frontmatter only."; echo "---"; echo; } \
  > "${R16}/skills/hollow/SKILL.md"
run_check "${R16}"
[ "${RC}" -ne 0 ] || fail "a skill whose body is empty must fail, not pass as the cheapest skill"
grep -q hollow "${WORK}/out" || fail "the error must name the hollow skill"
pass "empty body → fails loudly, names the skill"

echo "== FW_INVOCATION_BUDGET / FW_INVOCATION_WORST override the committed file =="
run_check "${R2}" FW_INVOCATION_BUDGET=10000
[ "${RC}" -eq 0 ] || fail "FW_INVOCATION_BUDGET must override the body default upward, got ${RC}"
run_check "${R1}" FW_INVOCATION_BUDGET=100
[ "${RC}" -ne 0 ] || fail "FW_INVOCATION_BUDGET must override the body default downward"
run_check "${R1}" FW_INVOCATION_WORST=100
[ "${RC}" -ne 0 ] || fail "FW_INVOCATION_WORST must override the worst default downward"
run_check "${R3}" FW_INVOCATION_WORST=10000
[ "${RC}" -eq 0 ] || fail "FW_INVOCATION_WORST must override the worst default upward, got ${RC}: $(cat "${WORK}/out")"
pass "both env overrides win over scripts/invocation-budget.txt"

echo "== per-skill exceptions still apply under an env override =="
budget "${R4}" "body 1000" "worst 2000" "greedy body=1600 worst=2600"
run_check "${R4}" FW_INVOCATION_BUDGET=1
[ "${RC}" -eq 0 ] || fail "an env override of the default must not erase the committed exceptions: $(cat "${WORK}/out")"
pass "exceptions survive an env override of the defaults"

echo "== SKIP_INVOCATION_BUDGET=1 escape is logged =="
run_check "${R2}" SKIP_INVOCATION_BUDGET=1
[ "${RC}" -eq 0 ] || fail "SKIP_INVOCATION_BUDGET=1 must pass, got ${RC}"
grep -qi skip "${WORK}/out" || fail "the escape must be logged, not silent"
pass "SKIP_INVOCATION_BUDGET=1 → exit 0, logged"

echo "ALL PASS"
