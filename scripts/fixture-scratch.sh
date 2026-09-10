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
step_pass() { echo "PASS: $*"; }
step_fail() { echo "FAIL: $*"; STEP_RC=1; }
# Indented, so the helper's own result lines stay the only ones at column 0 and
# `grep -cE '^(PASS|FAIL): '` counts steps rather than a grader's expectations.
indent() { sed 's/^/  /'; }

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
fixture_digest() {
  ( cd "${FIXTURE}" && find . -type f -print0 | LC_ALL=C sort -z \
      | xargs -0r sha256sum | sha256sum | cut -c1-64 )
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
  if [ -d "${SOL_DIR}/overlay" ]; then
    while IFS= read -r rel; do
      [ -n "${rel}" ] || continue
      [ ! -e "${FIXTURE}/${rel}" ] \
        || die "solution '${SOLUTION}': overlay/${rel} shadows a fixture file — express an edit to an existing file as a patch/ entry instead"
    done < <(cd "${SOL_DIR}/overlay" && find . -type f -printf '%P\n')
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
  for p in "${SOL_DIR}"/patch/*.patch; do
    [ -f "${p}" ] || continue
    # --whitespace=nowarn keeps trailing-space noise quiet; never
    # --ignore-whitespace, which would disable the drift detection being bought.
    ( cd "${W}" && git apply --whitespace=nowarn -p1 "${p}" ) 2>&1 | indent \
      || { sol_rc=1; break; }
    [ "${PIPESTATUS[0]}" -eq 0 ] || { sol_rc=1; break; }
  done
  [ "${sol_rc}" -ne 0 ] || { [ ! -d "${SOL_DIR}/overlay" ] || cp -R "${SOL_DIR}/overlay/." "${W}/" || sol_rc=1; }
  [ "${sol_rc}" -ne 0 ] || { [ ! -f "${SOL_DIR}/apply.sh" ] || bash "${SOL_DIR}/apply.sh" "${W}" 2>&1 | indent || sol_rc=1; }
  if [ "${sol_rc}" -eq 0 ]; then step_pass "solution ${SOLUTION}"; else step_fail "solution ${SOLUTION}"; fi
fi

if [ "${DO_SUITE}" -eq 1 ]; then
  # Mirrors each grader's own suite_green(), and never run-tests.sh: that script
  # appends to .check-log, the artifact the work grader reads.
  if [ "${SKILL}" = work ]; then suite=(env KATA_HARNESS=1 python3 -m unittest)
  else suite=(python3 -m unittest); fi
  if ( cd "${W}" && "${suite[@]}" ) 2>&1 | indent && [ "${PIPESTATUS[0]}" -eq 0 ]; then
    step_pass "suite"
  else
    step_fail "suite"
  fi
fi

for p in "${PROBES[@]+"${PROBES[@]}"}"; do
  case "${p}" in *.sh) runner=(bash) ;; *) runner=(python3) ;; esac
  if ( cd "${W}" && "${runner[@]}" "${p}" ) 2>&1 | indent && [ "${PIPESTATUS[0]}" -eq 0 ]; then
    step_pass "probe $(basename "${p}")"
  else
    step_fail "probe $(basename "${p}")"
  fi
done

if [ "${DO_CHECK}" -eq 1 ]; then
  GRADER="${EVALS_DIR}/check.sh"
  if [ ! -f "${GRADER}" ]; then
    step_fail "check ${ID} (no grader at ${GRADER#"${ROOT}"/})"
  elif bash "${GRADER}" "${ID}" "${W}" 2>&1 | indent && [ "${PIPESTATUS[0]}" -eq 0 ]; then
    step_pass "check ${ID}"
  else
    step_fail "check ${ID}"
  fi
fi

if [ "${DO_PROMPT}" -eq 1 ]; then
  read_eval prompt | sed "s|{{WORKDIR}}|${W}|g"
  echo
fi

exit "${STEP_RC}"
