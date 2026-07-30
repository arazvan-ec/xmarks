#!/usr/bin/env bash
# flywheel — CI gate (P24): the frontmatter `description` of every skill loads
# into context in every session, so the sum of those values is a fixed cost paid
# forever. v0.30.0 cut it 22%; this keeps it cut. Fails when the total exceeds
# scripts/description-budget.txt, printing the per-skill breakdown so the diff
# says which skill grew.
# Usage: check-description-budget.sh   (run from the repo root)
#   FW_DESC_BUDGET=<n>          override the committed budget (tests, probes)
#   SKIP_DESCRIPTION_BUDGET=1   skip with a logged notice, never silently

set -euo pipefail

if [ "${SKIP_DESCRIPTION_BUDGET:-0}" = "1" ]; then
  echo "description-budget: SKIPPED via SKIP_DESCRIPTION_BUDGET=1"
  exit 0
fi

BUDGET_FILE="scripts/description-budget.txt"
if [ -n "${FW_DESC_BUDGET:-}" ]; then
  BUDGET="${FW_DESC_BUDGET}"
elif [ -f "${BUDGET_FILE}" ]; then
  BUDGET="$(tr -dc '0-9' < "${BUDGET_FILE}")"
else
  echo "description-budget: no ${BUDGET_FILE} and no FW_DESC_BUDGET — cannot judge" >&2
  exit 2
fi
[ -n "${BUDGET}" ] || { echo "description-budget: budget is not a number" >&2; exit 2; }

shopt -s nullglob
files=(skills/*/SKILL.md)
[ "${#files[@]}" -gt 0 ] || { echo "description-budget: no skills/*/SKILL.md found" >&2; exit 2; }

total=0
rows=""
rc=0
for f in "${files[@]}"; do
  name="$(basename "$(dirname "${f}")")"
  # Scoped to the leading YAML frontmatter only: a `description:` line in the
  # skill body is prose and must never count toward the budget.
  raw="$(awk 'NR==1 && /^---$/ {fm=1; next}
              fm && /^---$/ {exit}
              fm && /^description:/ {sub(/^description:[[:space:]]*/, ""); print "V" $0; exit}' "${f}")"
  if [ -z "${raw}" ]; then
    echo "description-budget: ${name} has no frontmatter description — refusing to count it as 0" >&2
    rc=2; continue
  fi
  val="${raw#V}"
  if [ -z "${val}" ]; then
    echo "description-budget: ${name} has an empty description — refusing to count it as 0" >&2
    rc=2; continue
  fi
  case "${val}" in
    [\>\|]*)
      echo "description-budget: ${name} uses a YAML folded/block description (${val}) — keep it one line so the budget is measurable" >&2
      rc=2; continue ;;
  esac
  n="${#val}"
  total=$((total + n))
  rows="${rows}${n} ${name}"$'\n'
done

[ "${rc}" -eq 0 ] || exit "${rc}"

if [ "${total}" -gt "${BUDGET}" ]; then
  echo "description-budget: FAIL — ${total} chars across ${#files[@]} skills exceeds budget ${BUDGET} (over by $((total - BUDGET)))" >&2
  echo "  largest first:" >&2
  printf '%s' "${rows}" | sort -rn | awk '{printf "  %5d  %s\n", $1, $2}' >&2
  echo "  Trim a description, or raise ${BUDGET_FILE} in a deliberate commit." >&2
  exit 1
fi

echo "description-budget: OK — ${total}/${BUDGET} chars across ${#files[@]} skills"
