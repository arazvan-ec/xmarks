#!/usr/bin/env bash
# flywheel — the local sweep is the CI sweep (P60).
#
# Runs what .github/workflows/validate-plugins.yml runs: `claude plugin validate
# . --strict`, every `run: bash scripts/check-*.sh` step with its arguments (read
# from the workflow, so the two cannot drift), then every scripts/test-*.sh.
# `${{ github.base_ref }}` resolves to <base-ref>, so the base-ref gates compare
# against something instead of passing having compared nothing.
#
# The verdict is each script's exit code, never its output: a red hidden behind
# `| tail`, or a suite that prints "all passed" and exits 1, still reads FAIL.
# Runs are sequential, each with its own TMPDIR. Not a CI replacement: runner
# differences (mawk vs gawk) stay invisible here.
#
# Usage: sweep.sh [--list] [<base-ref>]   (default origin/main)
#   --list          print the commands, run nothing
#   SWEEP_ROOT      repo to sweep (default: this script's repo)
#   SWEEP_CLAUDE    claude CLI to use (default: claude); absent -> SKIPPED
#
# Exit: 0 all passed · 1 any failed · 2 unusable input

set -uo pipefail

LIST=0
[ "${1:-}" = "--list" ] && { LIST=1; shift; }
BASE="${1:-origin/main}"
ROOT="${SWEEP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
FLOW="${ROOT}/.github/workflows/validate-plugins.yml"
CLAUDE="${SWEEP_CLAUDE:-claude}"

[ -f "${FLOW}" ] || { echo "sweep: no ${FLOW}" >&2; exit 2; }
cd "${ROOT}" || exit 2

cmds=()
while IFS= read -r line; do
  line="${line//origin\/\$\{\{ github.base_ref \}\}/${BASE}}"
  line="${line//\$\{\{ github.base_ref \}\}/${BASE}}"
  cmds+=("${line//\"/}")
done < <(sed -nE 's/^[[:space:]]*(- )?run:[[:space:]]*(bash scripts\/check-[A-Za-z0-9_-]+\.sh.*)$/\2/p' "${FLOW}")
shopt -s nullglob
for t in scripts/test-*.sh; do cmds+=("bash ${t}"); done

if [ "${LIST}" -eq 1 ]; then
  echo "${CLAUDE} plugin validate . --strict"
  printf '%s\n' "${cmds[@]}"
  exit 0
fi

SCRATCH="$(mktemp -d)"
trap 'rm -rf "${SCRATCH}"' EXIT

total=0 passed=0 failed=()
step() {
  local name="$1"; shift
  local dir="${SCRATCH}/${total}"
  mkdir -p "${dir}/tmp"
  total=$((total + 1))
  if TMPDIR="${dir}/tmp" "$@" >"${dir}/log" 2>&1; then
    passed=$((passed + 1)); echo "PASS ${name}"
  else
    failed+=("${name}"); echo "FAIL ${name}"; tail -n 20 "${dir}/log" | sed 's/^/    /'
  fi
}

if command -v "${CLAUDE}" >/dev/null 2>&1; then
  step "claude plugin validate . --strict" "${CLAUDE}" plugin validate . --strict
else
  echo "SKIPPED claude plugin validate . --strict (no ${CLAUDE} CLI)"
fi
for c in "${cmds[@]}"; do
  read -ra argv <<<"${c}"
  step "${argv[1]}" "${argv[@]}"
done

echo "${passed}/${total} passed"
[ "${#failed[@]}" -eq 0 ] || { echo "failed: ${failed[*]}"; exit 1; }
