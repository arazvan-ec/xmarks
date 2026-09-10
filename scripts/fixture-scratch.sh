#!/usr/bin/env bash
# flywheel — instantiate an eval into a scratch workdir, optionally apply a
# committed reference solution, run its suite/probes, and grade it (P33).
#
# Replaces the ~40-line ad-hoc command every eval iteration used to retype, and
# the prose in README's "How to run one iteration". Addressed by <skill>
# <eval-id> rather than by fixture path because a fixture is not enough to
# identify an eval: loop evals 1 and 2 share `inventory-repo` and differ only in
# whether their `setup` runs `git init` — eval 2 deliberately does not, so that a
# missing `commit` field can be proven.
#
# Usage:
#   fixture-scratch.sh <skill> <eval-id> [options]
#   fixture-scratch.sh --resolve <skill> <eval-id>     # print the fixture dir
#   fixture-scratch.sh --digest  <skill> <eval-id>     # print its tree digest
#
# Options:
#   --solution <name>  apply skills/<skill>/evals/solutions/<name>/
#   --suite            run the skill's suite command in the scratch
#   --probe <file>     run a probe file in the scratch (repeatable)
#   --check            run skills/<skill>/evals/check.sh <eval-id> <scratch>
#   --print-prompt     print the eval's prompt with {{WORKDIR}} substituted
#   --pristine         copy the fixture and skip the eval's own setup
#   --into <dir>       populate this caller-owned dir; no mktemp, no teardown
#   --keep             print the scratch path and skip teardown
#
# Env: FW_EVAL_ROOT (tree to resolve skills/ under; default: this repo)
#      FW_SCRATCH_ROOT (parent for the mktemp scratch dir)
#
# Exit: 0 every requested step passed · 1 a step failed · 2 it could not start
# (bad usage, unknown skill/eval id, unusable solution). Every requested step
# runs even after one fails — one red must not hide the rest.
#
# Not vendored by install-vendored.sh: its inputs are skills/*/evals/**, which a
# consuming repo does not have. Same class as the check-*/test-* scripts.

set -uo pipefail

SELF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="${FW_EVAL_ROOT:-${SELF_ROOT}}"

die() { echo "fixture-scratch: $*" >&2; exit 2; }

# sha256 of stdin. Probed rather than assumed: stock macOS ships `shasum`, not
# `sha256sum`. Same fallback scripts/gate.sh already carries.
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | cut -d' ' -f1
  else echo "fixture-scratch: need sha256sum or shasum" >&2; return 1; fi
}
step_pass() { echo "PASS: $*"; }
step_fail() { echo "FAIL: $*"; STEP_RC=1; }

# run_in <dir> <cmd...> — run the command there, echo its output indented, and
# return ITS status. Indented so the helper's own result lines stay the only
# ones at column 0 and `grep -cE '^(PASS|FAIL): '` counts steps rather than a
# grader's expectations. The status must come from the command and not from a
# pipeline tail, or a failing step gets reported as a pass.
run_in() {
  local d="$1"; shift
  local o rc=0
  o="$(mktemp)"
  ( cd "${d}" && "$@" ) >"${o}" 2>&1 || rc=$?
  [ -s "${o}" ] && sed 's/^/  /' "${o}"
  rm -f "${o}"
  return "${rc}"
}

SKILL="" ID="" SOLUTION="" INTO="" MODE=""
DO_SUITE=0 DO_CHECK=0 DO_PROMPT=0 PRISTINE=0 KEEP=0
PROBES=()

usage() { sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --resolve|--digest) MODE="${1#--}" ;;
    --solution) SOLUTION="${2:-}"; [ -n "${SOLUTION}" ] || die "--solution needs a name"; shift ;;
    --probe) [ -n "${2:-}" ] || die "--probe needs a file"; PROBES+=("$2"); shift ;;
    --into) INTO="${2:-}"; [ -n "${INTO}" ] || die "--into needs a directory"; shift ;;
    --suite) DO_SUITE=1 ;;
    --check) DO_CHECK=1 ;;
    --print-prompt) DO_PROMPT=1 ;;
    --pristine) PRISTINE=1 ;;
    --keep) KEEP=1 ;;
    -*) die "unknown option: $1" ;;
    *) if [ -z "${SKILL}" ]; then SKILL="$1"; elif [ -z "${ID}" ]; then ID="$1"; else die "unexpected argument: $1"; fi ;;
  esac
  shift
done

[ -n "${SKILL}" ] && [ -n "${ID}" ] || { usage >&2; die "need <skill> <eval-id>"; }

EVALS_DIR="${ROOT}/skills/${SKILL}/evals"
EVALS_JSON="${EVALS_DIR}/evals.json"
[ -f "${EVALS_JSON}" ] || die "unknown skill '${SKILL}': no ${EVALS_JSON#"${ROOT}"/}"

# One reader for evals.json. `fixture` is resolved, never guessed: `files[0]`
# where the skill-creator schema provides it, else the fixtures path inside the
# eval's own `setup` — a form all nine committed setup strings share.
read_eval() {
  python3 - "${EVALS_JSON}" "${ID}" "${SKILL}" "$1" <<'PY'
import json, re, sys
path, want_id, skill, field = sys.argv[1:5]
evals = json.load(open(path))["evals"]
for e in evals:
    if str(e.get("id")) == want_id:
        break
else:
    sys.exit(3)
if field == "fixture":
    files = e.get("files") or []
    if files:
        print(f"skills/{skill}/{files[0]}")
    else:
        m = re.search(rf"skills/{re.escape(skill)}/evals/fixtures/([A-Za-z0-9._-]+)", e.get("setup", ""))
        if not m:
            sys.exit(4)
        print(f"skills/{skill}/evals/fixtures/{m.group(1)}")
else:
    print(e.get(field, ""), end="")
PY
}

FIXTURE_REL="$(read_eval fixture)" || case "$?" in
  3) die "unknown eval id '${ID}' for skill '${SKILL}'" ;;
  4) die "${SKILL} eval ${ID}: neither a files list nor a fixtures path in setup" ;;
  *) die "could not read ${EVALS_JSON#"${ROOT}"/}" ;;
esac
FIXTURE="${ROOT}/${FIXTURE_REL}"
[ -d "${FIXTURE}" ] || die "${SKILL} eval ${ID}: fixture ${FIXTURE_REL} does not exist"

# Digest of the fixture tree, relative paths only so it is location-independent.
# Solutions pin it in BASED-ON: `git apply` detects drift in a patch's context
# lines, and this covers the rest of the tree (run-tests.sh changing how it
# computes IMPL_SHA, or baseline-sha going stale against cart.py).
# The executable bit is part of the digest. Content alone is not enough:
# dropping +x from a fixture's run-tests.sh leaves every byte identical, so
# BASED-ON would still match while an executor can no longer run the
# `./run-tests.sh` the eval requires. Only that bit — it is the only mode git
# records.
#
# Plain `find | sort` rather than -print0/-z/-0r, and `sha256` rather than
# sha256sum: BSD sort has no -z, BSD xargs no -r, and stock macOS ships shasum
# instead of sha256sum. Fixture paths are committed files with no newlines.
fixture_digest() {
  ( cd "${FIXTURE}" || exit 1
    find . -type f | LC_ALL=C sort | while IFS= read -r f; do
      if [ -x "${f}" ]; then m=x; else m=-; fi
      printf '%s %s %s\n' "$(sha256 < "${f}")" "${m}" "${f}"
    done | sha256 | cut -c1-64 )
}

case "${MODE}" in
  resolve) printf '%s\n' "${FIXTURE}"; exit 0 ;;
  digest)  fixture_digest; exit 0 ;;
esac

for p in "${PROBES[@]+"${PROBES[@]}"}"; do
  [ -f "${p}" ] || die "probe file not found: ${p}"
done

SOL_DIR=""
if [ -n "${SOLUTION}" ]; then
  SOL_DIR="${EVALS_DIR}/solutions/${SOLUTION}"
  [ -d "${SOL_DIR}" ] || die "unknown solution '${SOLUTION}': no ${SOL_DIR#"${ROOT}"/}"
  MANIFEST="${SOL_DIR}/MANIFEST"
  [ -f "${MANIFEST}" ] || die "solution '${SOLUTION}' has no MANIFEST, so nothing declares its fixture or eval ids"

  want_fixture="$(sed -n 's/^fixture:[[:space:]]*//p' "${MANIFEST}" | head -1)"
  want_evals="$(sed -n 's/^evals:[[:space:]]*//p' "${MANIFEST}" | head -1)"
  [ -n "${want_fixture}" ] || die "solution '${SOLUTION}': MANIFEST declares no fixture:"
  [ -n "${want_evals}" ] || die "solution '${SOLUTION}': MANIFEST declares no evals:"

  # Declared, not inferred: cart-feature/cart.py and cart-bugfix/cart.py are
  # byte-identical, so either solution's patch applies cleanly to the other and
  # "the patch applied" proves nothing about which fixture it was written for.
  [ "${want_fixture}" = "$(basename "${FIXTURE}")" ] \
    || die "solution '${SOLUTION}' is for fixture '${want_fixture}', but ${SKILL} eval ${ID} uses '$(basename "${FIXTURE}")'"
  case " ${want_evals} " in
    *" ${ID} "*) ;;
    *) die "solution '${SOLUTION}' claims evals '${want_evals}', not ${ID}" ;;
  esac

  BASED_ON="${SOL_DIR}/BASED-ON"
  [ -f "${BASED_ON}" ] || die "solution '${SOLUTION}' has no BASED-ON, so fixture drift outside the patches' context would go unnoticed"
  have="$(fixture_digest)"; want="$(tr -d '[:space:]' < "${BASED_ON}")"
  [ "${have}" = "${want}" ] || die "solution '${SOLUTION}': BASED-ON is ${want} but ${FIXTURE_REL} now digests to ${have} — re-derive the solution against the current fixture, then refresh BASED-ON with: fixture-scratch.sh --digest ${SKILL} ${ID}"

  # Patches for files the fixture has, overlay for files it does not. A
  # whole-file overlay copy would shadow the original — for test_cart.py that
  # means shadowing its KATA_HARNESS guard, the thing that makes .check-log
  # trustworthy, and the ideal arm would stay green after the fixture moved.
  # A steps/ directory is applied by the solution's own apply.sh; without one it
  # would sit there applying nothing while the solution still reported success.
  [ ! -d "${SOL_DIR}/steps" ] || [ -f "${SOL_DIR}/apply.sh" ] \
    || die "solution '${SOLUTION}': steps/ is applied by the solution's apply.sh, and there is none — rename it to patch/ to have this script apply it, or add apply.sh"

  if [ -d "${SOL_DIR}/overlay" ]; then
    while IFS= read -r rel; do
      [ -n "${rel}" ] || continue
      [ ! -e "${FIXTURE}/${rel}" ] \
        || die "solution '${SOLUTION}': overlay/${rel} shadows a fixture file — express an edit to an existing file as a patch/ entry instead"
    done < <(cd "${SOL_DIR}/overlay" && find . -type f | sed 's|^\./||')
  fi
fi

# ------------------------------------------------------------------- the workdir
SETUP="$(read_eval setup)"
TEARDOWN=1
if [ -n "${INTO}" ]; then
  TEARDOWN=0
  if [ -e "${INTO}" ]; then
    [ -d "${INTO}" ] || die "--into ${INTO} is not a directory"
    [ -z "$(ls -A "${INTO}")" ] || die "--into ${INTO} is not empty"
  fi
  W="${INTO}"
else
  [ -z "${FW_SCRATCH_ROOT:-}" ] || mkdir -p "${FW_SCRATCH_ROOT}"
  W="$(mktemp -d "${FW_SCRATCH_ROOT:-${TMPDIR:-/tmp}}/fw-scratch-XXXXXX")"
fi
[ "${KEEP}" -eq 1 ] && TEARDOWN=0
# A trap, so the failure path cleans up too.
cleanup() { [ "${TEARDOWN}" -eq 1 ] && rm -rf "${W}"; }
trap cleanup EXIT

STEP_RC=0

if [ "${PRISTINE}" -eq 1 ] || [ -z "${SETUP}" ]; then
  mkdir -p "${W}"
  cp -R "${FIXTURE}/." "${W}/" \
    && step_pass "copy ${FIXTURE_REL} -> ${W}" \
    || step_fail "copy ${FIXTURE_REL}"
else
  # `cp -r <fixture> "$W"` nests into $W/<fixture-name>/ when $W exists, so the
  # eval's own setup must find it absent. This is the defect README's runbook
  # carried: it said W=$(mktemp -d), which creates it.
  mkdir -p "$(dirname "${W}")"; rmdir "${W}" 2>/dev/null || true
  if ( cd "${ROOT}" && W="${W}" bash -c "${SETUP}" >/dev/null 2>&1 ); then
    step_pass "copy ${FIXTURE_REL} -> ${W} (eval setup)"
  else
    step_fail "copy ${FIXTURE_REL} (eval setup)"
  fi
fi
echo "workdir: ${W}"

if [ -n "${SOL_DIR}" ]; then
  sol_rc=0
  # patch/ is applied here, flat and in lexical order. steps/ is applied by the
  # solution's own apply.sh, which needs to interleave commits between them —
  # loop's ideal cycle must land restock in one commit and low_stock in the
  # next. Two names because applying a steps/ patch here too would apply it
  # twice, and the second attempt fails on an already-patched file.
  for p in "${SOL_DIR}"/patch/*.patch; do
    [ -f "${p}" ] || continue
    # --whitespace=nowarn keeps trailing-space noise quiet; never
    # --ignore-whitespace, which would disable the drift detection being bought.
    run_in "${W}" git apply --whitespace=nowarn -p1 "${p}" || { sol_rc=1; break; }
  done
  if [ "${sol_rc}" -eq 0 ] && [ -d "${SOL_DIR}/overlay" ]; then
    cp -R "${SOL_DIR}/overlay/." "${W}/" || sol_rc=1
  fi
  if [ "${sol_rc}" -eq 0 ] && [ -f "${SOL_DIR}/apply.sh" ]; then
    run_in "${SOL_DIR}" bash ./apply.sh "${W}" || sol_rc=1
  fi
  if [ "${sol_rc}" -eq 0 ]; then step_pass "solution ${SOLUTION}"; else step_fail "solution ${SOLUTION}"; fi
fi

if [ "${DO_SUITE}" -eq 1 ]; then
  # Mirrors each grader's own suite_green(), and never run-tests.sh: that script
  # appends to .check-log, the artifact the work grader reads.
  if [ "${SKILL}" = work ]; then suite=(env KATA_HARNESS=1 python3 -m unittest)
  else suite=(python3 -m unittest); fi
  o="$(mktemp)"
  if ( cd "${W}" && "${suite[@]}" ) >"${o}" 2>&1; then suite_rc=0; else suite_rc=$?; fi
  [ -s "${o}" ] && sed 's/^/  /' "${o}"
  # "Ran 0 tests" exits 0, so without this a skill whose fixture carries no
  # unittest suite at all (process, run) reports a green suite having verified
  # nothing. Refusing a vacuous pass is what check-fixture-leaks.sh does for
  # zero scanned files.
  if grep -q '^Ran 0 tests' "${o}"; then
    step_fail "suite (no tests ran — ${SKILL}'s fixture has no unittest suite; drop --suite, or use --check)"
  elif [ "${suite_rc}" -eq 0 ]; then step_pass "suite"
  else step_fail "suite"; fi
  rm -f "${o}"
fi

for p in "${PROBES[@]+"${PROBES[@]}"}"; do
  case "${p}" in *.sh) runner=(bash) ;; *) runner=(python3) ;; esac
  if run_in "${W}" "${runner[@]}" "$(cd "$(dirname "${p}")" && pwd)/$(basename "${p}")"; then
    step_pass "probe $(basename "${p}")"
  else
    step_fail "probe $(basename "${p}")"
  fi
done

if [ "${DO_CHECK}" -eq 1 ]; then
  GRADER="${EVALS_DIR}/check.sh"
  if [ ! -f "${GRADER}" ]; then
    step_fail "check ${ID} (no grader at ${GRADER#"${ROOT}"/})"
  elif run_in "${ROOT}" bash "${GRADER}" "${ID}" "${W}"; then
    step_pass "check ${ID}"
  else
    step_fail "check ${ID}"
  fi
fi

if [ "${DO_PROMPT}" -eq 1 ]; then
  # Not sed: the path is data, and in a replacement `&` means the whole match
  # while `|` closes the s/// expression. Both emitted a wrong prompt, and sed's
  # error status was swallowed by the echo that followed.
  if ! read_eval prompt | python3 -c '
import sys
sys.stdout.write(sys.stdin.read().replace("{{WORKDIR}}", sys.argv[1]) + "\n")
' "${W}"; then
    step_fail "print-prompt"
  fi
fi

exit "${STEP_RC}"
