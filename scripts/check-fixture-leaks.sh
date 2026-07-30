#!/usr/bin/env bash
# flywheel — CI gate (P26): every file in an eval fixture is copied into the
# executor's workdir, so every file in it is part of the prompt. Three leaks were
# found by accident in one week — the `work` fixture README stating the grading
# rule, the `verify` fixture READMEs carrying the answer key, and a comment in
# `run-tests.sh` explaining that red-before-green is what gets measured. Both
# eval READMEs already carried this grep as a manual "before any iteration" step;
# a manual step is not a gate.
#
# Fails when a fixture file contains the assertion vocabulary, unless the exact
# path+pattern pair is allowlisted with a reason in scripts/fixture-leak-allow.txt.
#
# Usage: check-fixture-leaks.sh   (run from the repo root)
#   FW_FIXTURE_ROOT=<dir>    scan under this root instead of the repo (tests)
#   FW_LEAK_ALLOW=<file>     use this allowlist instead of the committed one
#   SKIP_FIXTURE_LEAKS=1     skip with a logged notice, never silently
#
# Scope: file CONTENTS. Filenames are not scanned — the standing exception is
# `baseline-sha`, whose name sits in the workdir and is noted in the allowlist.

set -uo pipefail

if [ "${SKIP_FIXTURE_LEAKS:-0}" = "1" ]; then
  echo "fixture-leaks: SKIPPED via SKIP_FIXTURE_LEAKS=1"
  exit 0
fi

ROOT="${FW_FIXTURE_ROOT:-.}"
ALLOW="${FW_LEAK_ALLOW:-scripts/fixture-leak-allow.txt}"

# id|regex — the vocabulary that describes how a run is graded. An id is what an
# allowlist entry names, so an exemption says which hint it is accepting.
PATTERNS=(
  "verdict|VERDICT:"
  "baseline|baseline-sha"
  "checklog|\.check-log"
  "implsha|IMPL_SHA"
  "result|RESULT="
  "asserts|the eval asserts"
  "pristine|pristine"
  "redgreen|red.?(→|->|then )green"
  "mechanical|mechanically checkable"
  "isfixture|eval fixture"
  "isgraded|is graded"
  "answerkey|answer key"
  "expverdict|expected verdict"
  "onlycorrect|only correct verdict"
)

pattern_ids() { printf '%s\n' "${PATTERNS[@]}" | cut -d'|' -f1; }

mapfile -t FILES < <(find "${ROOT}" -type d -name fixtures -path '*/evals/fixtures' \
  -exec find {} -type f -print \; 2>/dev/null | sort)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "fixture-leaks: no files under */evals/fixtures/ in ${ROOT} — refusing a vacuous pass" >&2
  exit 2
fi

# Allowlist: "<path> <pattern-id> <reason...>", # comments and blanks ignored.
declare -A ALLOWED=() USED=()
allow_rc=0
if [ -f "${ALLOW}" ]; then
  lineno=0
  while IFS= read -r line || [ -n "${line}" ]; do
    lineno=$((lineno + 1))
    case "${line}" in ''|'#'*) continue ;; esac
    read -r apath aid areason <<< "${line}"
    if [ -z "${aid:-}" ]; then
      echo "fixture-leaks: ${ALLOW}:${lineno}: entry needs '<path> <pattern-id> <reason>'" >&2
      allow_rc=2; continue
    fi
    if [ -z "${areason:-}" ]; then
      echo "fixture-leaks: ${ALLOW}:${lineno}: '${apath} ${aid}' has no reason — an exemption without one is indistinguishable from a leak" >&2
      allow_rc=2; continue
    fi
    if ! pattern_ids | grep -qx "${aid}"; then
      echo "fixture-leaks: ${ALLOW}:${lineno}: unknown pattern id '${aid}' (known: $(pattern_ids | tr '\n' ' '))" >&2
      allow_rc=2; continue
    fi
    ALLOWED["${apath} ${aid}"]=1
  done < "${ALLOW}"
fi
[ "${allow_rc}" -eq 0 ] || exit "${allow_rc}"

rc=0
hits=0
for f in "${FILES[@]}"; do
  rel="${f#"${ROOT}"/}"
  for p in "${PATTERNS[@]}"; do
    pid="${p%%|*}"; re="${p#*|}"
    matches="$(grep -inE -- "${re}" "${f}" 2>/dev/null)" || continue
    hits=$((hits + 1))
    if [ -n "${ALLOWED["${rel} ${pid}"]:-}" ]; then
      USED["${rel} ${pid}"]=1
      continue
    fi
    while IFS= read -r m; do
      echo "fixture-leaks: ${rel}:${m%%:*}: [${pid}] ${m#*:*:}" >&2
    done <<< "${matches}"
    rc=1
  done
done

if [ "${rc}" -ne 0 ]; then
  echo "fixture-leaks: FAIL — the lines above are copied into the executor's workdir, so they are part of the prompt." >&2
  echo "  Move grading rules to skills/<name>/evals/README.md, or allowlist the exact" >&2
  echo "  '<path> <pattern-id> <reason>' in ${ALLOW} with a reason that is not \"it explains what we measure\"." >&2
  exit 1
fi

# A stale exemption silently widens the gate: it stops describing a real hit and
# starts standing ready to absorb the next one.
stale=0
for k in "${!ALLOWED[@]}"; do
  [ -n "${USED[$k]:-}" ] && continue
  echo "fixture-leaks: ${ALLOW}: stale entry '${k}' matches nothing — remove it" >&2
  stale=1
done
[ "${stale}" -eq 0 ] || exit 1

echo "fixture-leaks: OK — ${#FILES[@]} fixture files scanned, ${hits} allowlisted hit(s), no leaks"
