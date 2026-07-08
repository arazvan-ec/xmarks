#!/usr/bin/env bash
# flywheel — SessionStart hook.
# Contract: READ-ONLY and idempotent. It never mutates the working tree.
# Everything printed to stdout is injected into Claude's session context.
# It always exits 0 so a missing/malformed ledger can never block a session.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LEDGER="${PROJECT_DIR}/.claude/flywheel/LEARNINGS.md"
N_INJECT="${FLYWHEEL_LEARNINGS_INJECT:-12}"

echo "🎡 flywheel loaded — a nested loop for disciplined AI development."
echo "   Full cycle:  /flywheel:loop <feature>"
echo "   Phases:      brainstorm → spec → plan → work → verify → review → compound → ship"
echo "   Anytime:     /flywheel:debug (systematic) · /flywheel:autoloop (autonomous) · /flywheel:sync (spec↔code)"
echo ""

# Soft new-version notice for VENDORED installs only (the VERSION file exists
# only in repos vendored by install-vendored.sh; marketplace installs update
# via /plugin update). Fail-silent and bounded to 2s so it can never slow down
# or break session start. Opt out with FLYWHEEL_NO_UPDATE_CHECK=1.
VERSION_FILE="${PROJECT_DIR}/.claude/flywheel/VERSION"
if [ -f "${VERSION_FILE}" ] && [ -z "${FLYWHEEL_NO_UPDATE_CHECK:-}" ] && command -v curl >/dev/null 2>&1; then
  LOCAL_V="$(sed -n 's/^flywheel //p' "${VERSION_FILE}" 2>/dev/null | head -1)"
  REMOTE_V="$(curl -m 2 -fsSL https://raw.githubusercontent.com/arazvan-ec/xmarks/main/.claude-plugin/plugin.json 2>/dev/null \
    | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  if [ -n "${LOCAL_V}" ] && [ -n "${REMOTE_V}" ] && [ "${LOCAL_V}" != "${REMOTE_V}" ]; then
    echo "⬆️  flywheel ${REMOTE_V} is available (this repo carries ${LOCAL_V}) — run /flywheel:update to refresh."
    echo ""
  fi
fi

# --- Relevance-scored, budgeted ledger injection (git-native memory, P2) ---
#
# Instead of dumping the first N lines of the ledger, score each entry by how
# relevant it is to the current context (branch / changed files / active spec
# / recency) and inject only the top N=$FLYWHEEL_LEARNINGS_INJECT full entries,
# plus a one-line pointer to the rest (recoverable via /flywheel:recall).
# Everything below is best-effort and wrapped so a parsing hiccup degrades to
# silence, never a non-zero exit.

show_ledger() {
  [ -f "${LEDGER}" ] || return 1

  BRANCH="$(git -C "${PROJECT_DIR}" branch --show-current 2>/dev/null)"
  MERGE_BASE="$(git -C "${PROJECT_DIR}" merge-base HEAD origin/main 2>/dev/null \
    || git -C "${PROJECT_DIR}" merge-base HEAD main 2>/dev/null)"
  CHANGED="$(
    {
      git -C "${PROJECT_DIR}" diff --name-only 2>/dev/null
      git -C "${PROJECT_DIR}" diff --name-only --cached 2>/dev/null
      [ -n "${MERGE_BASE}" ] && git -C "${PROJECT_DIR}" diff --name-only "${MERGE_BASE}"...HEAD 2>/dev/null
    } | sort -u
  )"
  SPEC="$(printf '%s\n' "${CHANGED}" | grep -m1 '^\.claude/flywheel/specs/.*\.md$' \
    | sed -E 's#^\.claude/flywheel/specs/##; s#\.plan\.md$##; s#\.md$##')"
  if [ -z "${SPEC}" ] && [ -d "${PROJECT_DIR}/.claude/flywheel/specs" ]; then
    SPEC="$(ls -t "${PROJECT_DIR}/.claude/flywheel/specs"/*.md 2>/dev/null | head -1 \
      | xargs -n1 basename 2>/dev/null | sed -E 's#\.plan\.md$##; s#\.md$##')"
  fi
  CUTOFF="$(date -d '-30 days' +%F 2>/dev/null || date -v-30d +%F 2>/dev/null || echo 0000-00-00)"

  TMPDIR="$(mktemp -d 2>/dev/null)" || return 1
  trap 'rm -rf "${TMPDIR}"' RETURN

  awk -v dir="${TMPDIR}" 'BEGIN {n = 0} /^## / {n++} {print > (dir "/e" n)}' "${LEDGER}" 2>/dev/null
  ENTRY_COUNT=0
  for f in "${TMPDIR}"/e*; do
    [ -f "${f}" ] || continue
    [ "$(basename "${f}")" = "e0" ] && continue
    ENTRY_COUNT=$((ENTRY_COUNT + 1))
  done
  [ "${ENTRY_COUNT}" -gt 0 ] || return 1

  SCORED="${TMPDIR}/.scored"
  : > "${SCORED}"
  for f in "${TMPDIR}"/e*; do
    [ -f "${f}" ] || continue
    n="$(basename "${f}" | sed 's/^e//')"
    [ "${n}" = "0" ] && continue

    title_line="$(head -n1 "${f}")"
    meta_line="$(sed -n '2p' "${f}")"
    score=0
    entry_date=""

    case "${meta_line}" in
      '<!-- fw: '*)
        meta="${meta_line#<!-- fw: }"
        meta="${meta% -->}"
        files_val=""; spec_val=""; branch_val=""
        IFS=';' read -ra kvs <<< "${meta}"
        for kv in "${kvs[@]}"; do
          kv="$(printf '%s' "${kv}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
          key="${kv%%=*}"
          val="${kv#*=}"
          case "${key}" in
            date) entry_date="${val}" ;;
            files) files_val="${val}" ;;
            spec) spec_val="${val}" ;;
            branch) branch_val="${val}" ;;
          esac
        done
        if [ -n "${files_val}" ] && [ -n "${CHANGED}" ]; then
          IFS=',' read -ra flist <<< "${files_val}"
          for ff in "${flist[@]}"; do
            ff="$(printf '%s' "${ff}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            if [ -n "${ff}" ] && printf '%s\n' "${CHANGED}" | grep -qxF "${ff}"; then
              score=$((score + 3))
              break
            fi
          done
        fi
        if { [ -n "${branch_val}" ] && [ "${branch_val}" = "${BRANCH}" ]; } \
          || { [ -n "${spec_val}" ] && [ "${spec_val}" = "${SPEC}" ]; }; then
          score=$((score + 2))
        fi
        ;;
      *)
        # Old free-prose entries: no metadata, so files/branch/spec bonuses
        # don't apply — always-eligible, low-priority. Still try to recover a
        # date from the old "## YYYY-MM-DD — title" title line for recency.
        entry_date="$(printf '%s' "${title_line}" | sed -n 's/^## \([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\).*/\1/p')"
        ;;
    esac

    if [ -n "${entry_date}" ] && [[ ! "${entry_date}" < "${CUTOFF}" ]]; then
      score=$((score + 1))
    fi

    printf '%s\t%s\t%s\n' "${score}" "${entry_date:-0000-00-00}" "${n}" >> "${SCORED}"
  done

  TOP="$(sort -t "$(printf '\t')" -k1,1nr -k2,2r -k3,3n "${SCORED}" | head -n "${N_INJECT}" | cut -f3)"
  INJECTED="$(printf '%s\n' "${TOP}" | grep -c .)"
  REMAINING=$((ENTRY_COUNT - INJECTED))

  echo "📓 Relevant flywheel learnings (top ${INJECTED} of ${ENTRY_COUNT}, from .claude/flywheel/LEARNINGS.md${BRANCH:+, branch=${BRANCH}}${SPEC:+, spec=${SPEC}}):"
  echo "------------------------------------------------------------------------------"
  first=1
  while IFS= read -r n; do
    [ -z "${n}" ] && continue
    [ "${first}" -eq 1 ] || echo ""
    first=0
    cat "${TMPDIR}/e${n}"
  done <<< "${TOP}"
  echo "------------------------------------------------------------------------------"
  if [ "${REMAINING}" -gt 0 ]; then
    echo "… ${REMAINING} more learnings — run /flywheel:recall <query> to pull specifics."
  fi
  echo "(Use these to avoid repeating past gotchas. /flywheel:compound appends new ones.)"
  return 0
}

show_ledger 2>/dev/null || {
  echo "📓 No flywheel learnings yet. /flywheel:compound will create"
  echo "   .claude/flywheel/LEARNINGS.md at the end of your first cycle."
}

exit 0
