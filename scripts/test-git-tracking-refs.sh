#!/usr/bin/env bash
# flywheel — test for the tracking-ref SessionStart hook.
# Reproduces the real defect first: in a shallow single-branch clone, `git push
# -u` of a new branch leaves `@{u}` unresolvable, so pushed work reads as
# unpushed. Then asserts the hook fixes it prospectively, is idempotent, and
# leaves alone every repo it has no business touching (non-shallow, already
# general, multi-refspec, no origin, not a repo) — printing nothing and
# exiting 0 in each of those.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${SRC}/scripts/git-tracking-refs.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

git config --global --get user.email >/dev/null 2>&1 || export GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_EMAIL=t@t
export GIT_AUTHOR_NAME=t GIT_COMMITTER_NAME=t

# A bare origin with three commits on main, so --depth 1 really truncates.
# Seeded by `clone --bare` rather than by pushing into an empty bare: a local
# push here trips git's push negotiation ("expected 'acknowledgments'") and can
# leave the bare empty, which would silently make every later assertion vacuous.
BARE="${WORK}/origin.git"
SEED="${WORK}/seed"
git init -q -b main "${SEED}"
for m in one two three; do
  git -C "${SEED}" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "${m}"
done
git clone -q --bare "${SEED}" "${BARE}"

# NOTE: `file://` is required, not cosmetic. Git ignores --depth for a local
# clone given as a plain path (it hardlinks instead), so the clone would come
# out single-branch but NOT shallow — and the hook deliberately requires both.
# Without file:// this test would silently exercise the wrong shape.
fresh_clone() {  # $1 = destination, $2... = extra clone flags
  local dst="$1"; shift
  git clone -q "$@" "file://${BARE}" "${dst}" 2>/dev/null
  git -C "${dst}" config user.email t@t
  git -C "${dst}" config user.name t
}

run_hook() { CLAUDE_PROJECT_DIR="$1" bash "${SCRIPT}"; }

# The fixture must really be shallow+single-branch, or every assertion below
# would pass vacuously against the wrong shape of repo.
GUARD="${WORK}/guard"
fresh_clone "${GUARD}" --depth 1
[ "$(git -C "${GUARD}" rev-parse --is-shallow-repository)" = "true" ] \
  || fail "fixture is not shallow — --depth was ignored (local path instead of file://?)"
[ "$(git -C "${GUARD}" config --get remote.origin.fetch)" = "+refs/heads/main:refs/remotes/origin/main" ] \
  || fail "fixture does not have the single-branch refspec"
pass "fixture is a genuine shallow single-branch clone"

# --- the defect, reproduced --------------------------------------------------
BROKEN="${WORK}/broken"
fresh_clone "${BROKEN}" --depth 1
git -C "${BROKEN}" checkout -q -b feature-x
git -C "${BROKEN}" commit -q --allow-empty -m work
git -C "${BROKEN}" -c push.negotiate=false push -q -u origin feature-x 2>/dev/null
git -C "${BROKEN}" rev-parse --verify -q '@{u}' >/dev/null 2>&1 \
  && fail "the defect did not reproduce: @{u} resolved in a shallow single-branch clone"
pass "defect reproduced: after push -u, @{u} is unresolvable (work reads as unpushed)"

# --- the hook fixes it prospectively ----------------------------------------
FIXED="${WORK}/fixed"
fresh_clone "${FIXED}" --depth 1
out="$(run_hook "${FIXED}")"
[ -n "${out}" ] || fail "the hook said nothing on a clone it should have fixed"
case "${out}" in *'refs/heads/*'*) pass "the hook reports the widened refspec" ;;
  *) fail "the report does not name the new refspec: ${out}" ;; esac
[ "$(git -C "${FIXED}" config --get remote.origin.fetch)" = '+refs/heads/*:refs/remotes/origin/*' ] \
  || fail "refspec not widened"
pass "refspec widened to the wildcard form"

git -C "${FIXED}" checkout -q -b feature-y
git -C "${FIXED}" commit -q --allow-empty -m work
git -C "${FIXED}" -c push.negotiate=false push -q -u origin feature-y 2>/dev/null
git -C "${FIXED}" rev-parse --verify -q '@{u}' >/dev/null 2>&1 \
  || fail "@{u} still unresolvable after the fix — the hook does not solve the real problem"
[ "$(git -C "${FIXED}" rev-parse HEAD)" = "$(git -C "${FIXED}" rev-parse '@{u}')" ] \
  || fail "@{u} resolves but does not match HEAD"
[ "$(git -C "${FIXED}" log --oneline '@{u}..HEAD' | wc -l)" -eq 0 ] \
  || fail "pushed work still counts as unpushed"
pass "after the fix, push -u creates the tracking ref and @{u} == HEAD (0 unpushed)"

# --- idempotent --------------------------------------------------------------
out="$(run_hook "${FIXED}")"
[ -z "${out}" ] || fail "second run should be silent, got: ${out}"
[ "$(git -C "${FIXED}" config --get-all remote.origin.fetch | wc -l)" -eq 1 ] \
  || fail "a second run duplicated the refspec"
pass "a second run is silent and does not duplicate the refspec"

# --- repos it must not touch -------------------------------------------------
FULL="${WORK}/full"
fresh_clone "${FULL}" --single-branch      # single-branch but NOT shallow: a choice
before="$(git -C "${FULL}" config --get remote.origin.fetch)"
out="$(run_hook "${FULL}")"
[ -z "${out}" ] || fail "a non-shallow single-branch clone must be left alone"
[ "$(git -C "${FULL}" config --get remote.origin.fetch)" = "${before}" ] \
  || fail "a deliberate --single-branch clone had its refspec rewritten"
pass "a non-shallow single-branch clone is left untouched"

MULTI="${WORK}/multi"
fresh_clone "${MULTI}" --depth 1
git -C "${MULTI}" config --add remote.origin.fetch '+refs/pull/*/head:refs/remotes/origin/pr/*'
out="$(run_hook "${MULTI}")"
[ -z "${out}" ] || fail "a customized multi-refspec remote must be left alone"
[ "$(git -C "${MULTI}" config --get-all remote.origin.fetch | wc -l)" -eq 2 ] \
  || fail "a customized multi-refspec remote was rewritten"
pass "a customized multi-refspec remote is left untouched"

NOORIGIN="${WORK}/noorigin"
git init -q -b main "${NOORIGIN}"
out="$(run_hook "${NOORIGIN}")"
[ -z "${out}" ] || fail "a repo without origin must be left alone"
pass "a repo with no origin produces no output"

NOREPO="${WORK}/norepo"; mkdir -p "${NOREPO}"
out="$(run_hook "${NOREPO}")"
[ -z "${out}" ] || fail "a non-repo must be left alone"
pass "a directory that is not a repo produces no output"

# --- opt-out -----------------------------------------------------------------
OPTOUT="${WORK}/optout"
fresh_clone "${OPTOUT}" --depth 1
before="$(git -C "${OPTOUT}" config --get remote.origin.fetch)"
out="$(FLYWHEEL_NO_REFSPEC_FIX=1 CLAUDE_PROJECT_DIR="${OPTOUT}" bash "${SCRIPT}")"
[ -z "${out}" ] || fail "FLYWHEEL_NO_REFSPEC_FIX=1 must silence the hook"
[ "$(git -C "${OPTOUT}" config --get remote.origin.fetch)" = "${before}" ] \
  || fail "the opt-out did not prevent the mutation"
pass "FLYWHEEL_NO_REFSPEC_FIX=1 opts out entirely"

# --- it never fails a session start ------------------------------------------
run_hook "${NOREPO}" || fail "must exit 0 on a non-repo"
run_hook "${FIXED}" >/dev/null || fail "must exit 0 when there is nothing to do"
pass "always exits 0"

echo "git-tracking-refs: all assertions passed"
