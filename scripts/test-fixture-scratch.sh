#!/usr/bin/env bash
# flywheel — test for scripts/fixture-scratch.sh (P33).
#
# Most assertions run against a synthetic eval tree built here and pointed at
# with FW_EVAL_ROOT, so every failure path (a patch that must not apply, a stale
# BASED-ON, an overlay shadowing a fixture file) is reachable without planting
# anything in the committed suites. The rest run against the real repo, because
# two properties are about the committed tree itself: every eval resolves to a
# fixture that exists, and no solution sits inside a fixture.
#
# The nesting assertions are the reason this file exists. `setup` in evals.json
# is `cp -r <fixture> "$W"`, which yields $W/<fixture-name>/ when $W already
# exists — and README's runbook said `W=$(mktemp -d)`. Every grader then fails
# on a workdir that is correct in every other respect.

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUT="${SRC}/scripts/fixture-scratch.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

# run <args...> — sets RC, stdout+stderr in ${WORK}/out
run() { RC=0; bash "${SUT}" "$@" >"${WORK}/out" 2>&1 || RC=$?; }
out() { cat "${WORK}/out"; }

[ -f "${SUT}" ] || fail "no script at scripts/fixture-scratch.sh"
bash -n "${SUT}" || fail "fixture-scratch.sh is not valid bash"

# ---------------------------------------------------------------- synthetic root
# One skill carrying both instantiation schemas, because a schema is per-eval:
# id 1 uses `files`, ids 2 and 3 use `setup` — 2 git-inits and 3 deliberately
# does not, mirroring loop evals 1 and 2, whose only difference is that.
R="${WORK}/root"
E="${R}/skills/demo/evals"
mkdir -p "${E}/fixtures/mini"

cat > "${E}/fixtures/mini/app.py" <<'PY'
def label():
    return "broken"
PY
cat > "${E}/fixtures/mini/test_app.py" <<'PY'
import unittest
from app import label


class LabelTest(unittest.TestCase):
    def test_label(self):
        self.assertEqual(label(), "fixed")
PY
printf 'a fixture file the solution must not shadow\n' > "${E}/fixtures/mini/keep.txt"

python3 - "${E}/evals.json" <<'PY'
import json, sys
setup = 'cp -r skills/demo/evals/fixtures/mini "$W"'
gitinit = ' && git -C "$W" init -q -b main'
json.dump({
    "skill_name": "demo",
    "evals": [
        {"id": 1, "prompt": "work in {{WORKDIR}} please",
         "files": ["evals/fixtures/mini"]},
        {"id": 2, "prompt": "git one in {{WORKDIR}}", "setup": setup + gitinit},
        {"id": 3, "prompt": "no git in {{WORKDIR}}", "setup": setup},
    ],
}, open(sys.argv[1], "w"), indent=2)
PY

cat > "${E}/check.sh" <<'SH'
#!/usr/bin/env bash
set -u
ID="${1:?}"; W="${2:?}"
case "${ID}" in 1|2|3) ;; *) echo "unknown eval id: ${ID}" >&2; exit 2 ;; esac
if grep -q fixed "${W}/app.py" 2>/dev/null; then echo "PASS: app.py fixed"; exit 0; fi
echo "FAIL: app.py not fixed"; exit 1
SH

# The reference solution: a patch for the file the fixture has, an overlay file
# it does not, and an apply.sh for a value that exists only after patching.
S="${E}/solutions/mini-ideal"
mkdir -p "${S}/patch" "${S}/overlay"
mkdir -p "${WORK}/gen"
cp "${E}/fixtures/mini/app.py" "${WORK}/gen/app.py.orig"
sed 's/"broken"/"fixed"/' "${WORK}/gen/app.py.orig" > "${WORK}/gen/app.py"
( cd "${WORK}/gen" && diff -u app.py.orig app.py \
    | sed '1s|.*|--- a/app.py|; 2s|.*|+++ b/app.py|' ) > "${S}/patch/01-app.py.patch"
printf 'the ideal outcome\n' > "${S}/overlay/note.md"
cat > "${S}/apply.sh" <<'SH'
#!/usr/bin/env bash
set -eu
W="${1:?workdir}"
sha256sum "${W}/app.py" | cut -c1-16 > "${W}/computed.txt"
SH
printf 'fixture: mini\nevals: 1 2 3\n' > "${S}/MANIFEST"

# BASED-ON comes from the script itself, so the digest algorithm has exactly one
# implementation. A test that recomputed it here would pass on a shared bug.
run --digest demo 1
[ "${RC}" -eq 0 ] || fail "--digest must exit 0: $(out)"
DIGEST="$(tail -1 "${WORK}/out")"
[ -n "${DIGEST}" ] || fail "--digest printed nothing"
printf '%s\n' "${DIGEST}" > "${S}/BASED-ON"
pass "--digest prints a fixture digest"

export FW_EVAL_ROOT="${R}"
export FW_SCRATCH_ROOT="${WORK}/scratch"
mkdir -p "${FW_SCRATCH_ROOT}"

echo "== usage and addressing errors refuse to start =="
run
[ "${RC}" -ne 0 ] || fail "no arguments must not exit 0"
pass "no arguments exits non-zero"

run --help
[ "${RC}" -eq 0 ] || fail "--help must exit 0: $(out)"
grep -qi 'usage' "${WORK}/out" || fail "--help must print usage: $(out)"
pass "--help prints usage and exits 0"

run demo 9
[ "${RC}" -eq 2 ] || fail "an unknown eval id must exit 2, got ${RC}: $(out)"
pass "unknown eval id exits 2 (the graders' contract)"

run nosuchskill 1
[ "${RC}" -ne 0 ] || fail "an unknown skill must not exit 0"
grep -q 'nosuchskill' "${WORK}/out" || fail "the failure must name the skill: $(out)"
pass "unknown skill fails and names it"

run demo 1 --solution nosuchsolution
[ "${RC}" -ne 0 ] || fail "an unknown solution must not exit 0"
grep -q 'nosuchsolution' "${WORK}/out" || fail "the failure must name the solution: $(out)"
pass "unknown solution fails and names it"

run demo 1 --probe "${WORK}/nosuchprobe.py"
[ "${RC}" -ne 0 ] || fail "a missing probe file must not exit 0"
grep -q 'nosuchprobe' "${WORK}/out" || fail "the failure must name the probe: $(out)"
pass "missing probe file fails and names it"

echo "== the fixture lands at the workdir root, in BOTH schemas =="
# The regression this script exists for: `cp -r <fixture> "$W"` nests when $W
# already exists, and every grader then fails on an otherwise correct workdir.
for id in 1 2 3; do
  W="${WORK}/root-${id}"
  run demo "${id}" --into "${W}"
  [ "${RC}" -eq 0 ] || fail "demo ${id}: instantiation failed: $(out)"
  [ -f "${W}/app.py" ] || fail "demo ${id}: app.py is not at the workdir root: $(find "${W}" -type f)"
  [ ! -d "${W}/mini" ] || fail "demo ${id}: the fixture was nested at \$W/mini/"
  pass "demo ${id}: fixture at the workdir root, not nested"
done

echo "== setup runs, and --pristine skips it =="
[ -d "${WORK}/root-2/.git" ] || fail "eval 2's setup git-inits; .git is absent"
[ ! -d "${WORK}/root-3/.git" ] || fail "eval 3's setup does not git-init; .git is present"
pass "each eval's own setup ran (git-init present only where declared)"

run demo 2 --pristine --into "${WORK}/pristine"
[ "${RC}" -eq 0 ] || fail "--pristine failed: $(out)"
[ -f "${WORK}/pristine/app.py" ] || fail "--pristine must still copy the fixture"
[ ! -d "${WORK}/pristine/.git" ] || fail "--pristine must skip the eval's setup"
pass "--pristine copies the fixture and skips setup"

echo "== --into is caller-owned: no teardown, and it refuses a dirty dir =="
[ -f "${WORK}/root-1/app.py" ] || fail "--into must not tear down the caller's dir"
pass "--into leaves the directory in place"

run demo 1 --into "${WORK}/root-1"
[ "${RC}" -ne 0 ] || fail "--into must refuse a non-empty directory"
pass "--into refuses a non-empty directory"

echo "== teardown and --keep =="
BEFORE="$(find "${FW_SCRATCH_ROOT}" -mindepth 1 -maxdepth 1 | wc -l)"
run demo 1
[ "${RC}" -eq 0 ] || fail "a plain instantiation failed: $(out)"
AFTER="$(find "${FW_SCRATCH_ROOT}" -mindepth 1 -maxdepth 1 | wc -l)"
[ "${BEFORE}" -eq "${AFTER}" ] || fail "the scratch dir was not torn down: $(out)"
pass "without --keep the scratch dir is removed"

# The failure path too: a trap, not a final rm that set -e would skip.
run demo 1 --check
[ "${RC}" -ne 0 ] || fail "--check on a pristine fixture must not exit 0"
AFTER="$(find "${FW_SCRATCH_ROOT}" -mindepth 1 -maxdepth 1 | wc -l)"
[ "${BEFORE}" -eq "${AFTER}" ] || fail "a failing run leaked its scratch dir"
pass "the scratch dir is removed on the failure path too"

run demo 1 --keep
[ "${RC}" -eq 0 ] || fail "--keep failed: $(out)"
KEPT="$(grep -o '/[^ ]*' "${WORK}/out" | grep "^${FW_SCRATCH_ROOT}" | head -1)"
[ -n "${KEPT}" ] || fail "--keep must print the scratch path: $(out)"
[ -f "${KEPT}/app.py" ] || fail "--keep must leave the populated workdir behind"
rm -rf "${KEPT}"
pass "--keep prints the path and leaves the workdir"

echo "== the grader's verdict decides the exit code =="
run demo 1 --check --into "${WORK}/red"
[ "${RC}" -ne 0 ] || fail "--check must fail on a pristine fixture — success must not be independent of the grader"
grep -q '^FAIL: ' "${WORK}/out" || fail "a failing step must print a FAIL: line: $(out)"
pass "--check is red on an untouched fixture"

run demo 1 --solution mini-ideal --check --into "${WORK}/green"
[ "${RC}" -eq 0 ] || fail "--check must be green with the reference solution: $(out)"
! grep -q '^FAIL: ' "${WORK}/out" || fail "exit 0 but a FAIL: line was printed: $(out)"
pass "--check is green with the committed solution applied"

echo "== the solution's three shapes all land =="
G="${WORK}/green"
grep -q 'fixed' "${G}/app.py" || fail "the patch did not reach app.py"
[ -f "${G}/note.md" ] || fail "the overlay file was not copied"
[ -f "${G}/computed.txt" ] || fail "apply.sh did not run"
[ -s "${G}/computed.txt" ] || fail "apply.sh ran but computed nothing — it must receive the workdir"
pass "patch, overlay and apply.sh all applied"

echo "== --suite reflects the suite, and --probe reflects the probe =="
run demo 1 --suite --into "${WORK}/suite-red"
[ "${RC}" -ne 0 ] || fail "--suite must be red on the pristine fixture"
pass "--suite red suite exits non-zero"

run demo 1 --solution mini-ideal --suite --into "${WORK}/suite-green"
[ "${RC}" -eq 0 ] || fail "--suite must be green once fixed: $(out)"
pass "--suite green suite exits 0"

printf 'import sys\nsys.exit(3)\n' > "${WORK}/bad-probe.py"
printf 'print("fine")\n' > "${WORK}/good-probe.py"
run demo 1 --solution mini-ideal --probe "${WORK}/good-probe.py" --into "${WORK}/probe-ok"
[ "${RC}" -eq 0 ] || fail "a passing probe must exit 0: $(out)"
run demo 1 --solution mini-ideal --probe "${WORK}/bad-probe.py" --check --into "${WORK}/probe-bad"
[ "${RC}" -ne 0 ] || fail "a failing probe must exit non-zero even when every other step passed"
pass "a failing probe alone reddens the run"

echo "== one attributable result line per step, and every step runs =="
run demo 1 --solution mini-ideal --suite --probe "${WORK}/bad-probe.py" --check --into "${WORK}/lines"
[ "${RC}" -ne 0 ] || fail "the run must be red: $(out)"
N="$(grep -cE '^(PASS|FAIL): ' "${WORK}/out")"
[ "${N}" -eq 5 ] || fail "expected 5 result lines (copy, solution, suite, probe, check), got ${N}: $(out)"
for step in copy solution suite probe check; do
  grep -qE "^(PASS|FAIL): ${step}" "${WORK}/out" || fail "no result line names the '${step}' step: $(out)"
done
grep -qE '^PASS: check' "${WORK}/out" || fail "the check step must still have run after the probe failed — one red must not hide the rest: $(out)"
pass "5 named result lines, and a mid-sequence failure does not stop the rest"

echo "== --print-prompt substitutes {{WORKDIR}} =="
run demo 1 --print-prompt --into "${WORK}/prompt"
[ "${RC}" -eq 0 ] || fail "--print-prompt failed: $(out)"
# The whole prompt, not just the path: the workdir line alone would satisfy a
# substring check even if --print-prompt emitted nothing at all.
grep -qF "work in ${WORK}/prompt please" "${WORK}/out" \
  || fail "--print-prompt must emit the eval's prompt with the path substituted: $(out)"
! grep -q 'WORKDIR' "${WORK}/out" || fail "--print-prompt left the placeholder behind: $(out)"
pass "--print-prompt resolves {{WORKDIR}} in the eval's prompt"

echo "== a solution that could silently lie is refused =="
# Each of these is a way an asset stops describing the fixture executors get,
# while still applying cleanly. None has any other detector.
clone_solution() { rm -rf "${E}/solutions/$1"; cp -R "${S}" "${E}/solutions/$1"; }

clone_solution stale-based-on
printf '%s\n' "0000000000000000000000000000000000000000000000000000000000000000" \
  > "${E}/solutions/stale-based-on/BASED-ON"
run demo 1 --solution stale-based-on --into "${WORK}/stale"
[ "${RC}" -ne 0 ] || fail "a stale BASED-ON must not pass"
grep -qi 'based-on' "${WORK}/out" || fail "the failure must name BASED-ON: $(out)"
pass "a stale BASED-ON fails and names itself"

clone_solution wrong-fixture
printf 'fixture: notmini\nevals: 1\n' > "${E}/solutions/wrong-fixture/MANIFEST"
run demo 1 --solution wrong-fixture --into "${WORK}/wrongfix"
[ "${RC}" -ne 0 ] || fail "a MANIFEST naming another fixture must not pass — cart-feature and cart-bugfix have byte-identical cart.py, so the patch applying proves nothing"
pass "a solution bound to another fixture is refused"

clone_solution wrong-eval
printf 'fixture: mini\nevals: 2\n' > "${E}/solutions/wrong-eval/MANIFEST"
run demo 1 --solution wrong-eval --into "${WORK}/wrongeval"
[ "${RC}" -ne 0 ] || fail "a solution that does not claim this eval id must not pass"
pass "a solution not claiming this eval id is refused"

clone_solution shadowing
printf 'a shadowing copy\n' > "${E}/solutions/shadowing/overlay/keep.txt"
run demo 1 --solution shadowing --into "${WORK}/shadow"
[ "${RC}" -ne 0 ] || fail "an overlay file shadowing a fixture file must not pass — a whole-file copy of test_cart.py would shadow its KATA_HARNESS guard and keep the green arm green after the fixture moved"
grep -q 'keep.txt' "${WORK}/out" || fail "the failure must name the shadowing file: $(out)"
pass "an overlay shadowing a fixture file is refused"

echo "== the drift detector is live, not nominal =="
DRIFT="${R}-drift"
rm -rf "${DRIFT}"; cp -R "${R}" "${DRIFT}"
sed -i 's/^def label(/def relabel(/' "${DRIFT}/skills/demo/evals/fixtures/mini/app.py"
FW_EVAL_ROOT="${DRIFT}" run demo 1 --solution mini-ideal --into "${WORK}/drift"
[ "${RC}" -ne 0 ] || fail "a patch whose context moved must fail to apply, not apply at a guess"
pass "context drift in the fixture reddens the apply"

grep -q 'ignore-whitespace' "${SUT}" && fail "git apply must not be given --ignore-whitespace: it disables exactly the drift detection being bought"
pass "git apply is never called with --ignore-whitespace"

echo "== the committed tree: every eval resolves, and no answer key is in a fixture =="
unset FW_EVAL_ROOT
COUNT=0
for s in loop process run verify work; do
  ids="$(python3 -c "
import json;print(' '.join(str(e['id']) for e in json.load(open('${SRC}/skills/${s}/evals/evals.json'))['evals']))")"
  for id in ${ids}; do
    run --resolve "${s}" "${id}"
    [ "${RC}" -eq 0 ] || fail "${s} eval ${id}: the fixture does not resolve: $(out)"
    d="$(tail -1 "${WORK}/out")"
    [ -d "${d}" ] || fail "${s} eval ${id}: resolved to '${d}', which is not a directory"
    COUNT=$((COUNT + 1))
  done
done
[ "${COUNT}" -ge 14 ] || fail "expected at least 14 committed evals, resolved ${COUNT} — the loop is not covering the suites"
pass "all ${COUNT} committed evals resolve to a fixture directory that exists"

# check-fixture-leaks.sh copies verdict vocabulary, but loop's ideal JSONL
# contains none of it — a solution parked inside a fixture would be handed to
# the executor as the answer key and that gate could not see it.
STRAY="$(find "${SRC}/skills" -type d -name solutions -path '*/evals/fixtures/*' | head -5)"
[ -z "${STRAY}" ] || fail "a solutions/ directory sits inside a fixture and would be copied into the executor's workdir: ${STRAY}"
pass "no solutions/ directory sits inside any evals/fixtures/"

echo "== work's suite runs through unittest with KATA_HARNESS, never run-tests.sh =="
# cart-bugfix's pristine suite is green with KATA_HARNESS=1 and red without it,
# so this exit code is a real discriminator rather than a smoke check.
run work 2 --suite --into "${WORK}/kata"
[ "${RC}" -eq 0 ] || fail "work eval 2's pristine suite is green under KATA_HARNESS=1; a red result means the helper did not set it: $(out)"
pass "work's suite is run with KATA_HARNESS=1"

[ ! -f "${WORK}/kata/.check-log" ] || fail "--suite invoked run-tests.sh: it appended to .check-log, the artifact the work grader reads"
pass "--suite did not invoke run-tests.sh (.check-log absent)"

echo "== every committed solution is exercised, by discovery not by a list =="
# Same principle as the CI workflow's test-*.sh glob: a solution that is added
# and never applied is the defect that hid test-run-cost.sh for four releases.
mapfile -t SOLS < <(cd "${SRC}" && find skills -mindepth 4 -maxdepth 4 -type d -path 'skills/*/evals/solutions/*' | sort)
if [ "${#SOLS[@]}" -eq 0 ]; then
  echo "  note: no solutions committed yet — the discovery arm is vacuous until P33 step 3"
else
  for sol in "${SOLS[@]}"; do
    name="$(basename "${sol}")"; skill="$(echo "${sol}" | cut -d/ -f2)"
    man="${SRC}/${sol}/MANIFEST"
    [ -f "${man}" ] || fail "${sol}: no MANIFEST, so nothing declares its fixture or eval ids"
    ids="$(sed -n 's/^evals:[[:space:]]*//p' "${man}")"
    [ -n "${ids}" ] || fail "${sol}: MANIFEST declares no eval ids"
    for id in ${ids}; do
      run "${skill}" "${id}" --solution "${name}" --check --into "${WORK}/sol-${skill}-${name}-${id}"
      [ "${RC}" -eq 0 ] || fail "${sol}: does not grade green on ${skill} eval ${id}: $(out)"
    done
    pass "${sol}: green on its declared evals (${ids})"
  done
  pass "exercised all ${#SOLS[@]} committed solutions by discovery"
fi

echo "fixture-scratch: OK"
