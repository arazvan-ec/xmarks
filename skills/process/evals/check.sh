#!/usr/bin/env bash
# Deterministic grader for skills/process evals. Usage: check.sh <eval_id> <workdir>
# Prints PASS/FAIL per expectation; exit 0 only if all pass.
set -u

ID="${1:?eval id}"; W="${2:?workdir}"
PROC="$W/.claude/flywheel/processes"
rc=0
ok()   { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; rc=1; }
check() { # check <expr...> -- <label>
  local args=(); while [ "$1" != "--" ]; do args+=("$1"); shift; done; shift
  if "${args[@]}" >/dev/null 2>&1; then ok "$1"; else fail "$1"; fi
}

new_contract() { ls "$PROC"/*.md 2>/dev/null | grep -v '/plate-audit\.md$' | head -1; }

contract_shape() { # contract_shape <file>
  local f="$1"
  check grep -Eq '^name: ' "$f" -- "frontmatter: name"
  check grep -Eq '^kind: process' "$f" -- "frontmatter: kind: process"
  check grep -Eq '^version: 1' "$f" -- "frontmatter: version: 1"
  check grep -Eq '^## Rules' "$f" -- "Rules (fixed contract) section"
  n="$(grep -Ec '^[0-9]+\. ' "$f")"
  if [ "${n:-0}" -ge 3 ]; then ok "fixed Rules: >= 3 numbered steps ($n)"; else fail "fixed Rules: >= 3 numbered steps (found ${n:-0})"; fi
  check grep -Eq '^## Output schema' "$f" -- "Output schema section"
  check grep -Eq '^## Persistence' "$f" -- "Persistence section"
  check grep -Eiq 'idempoten' "$f" -- "Persistence names an idempotency key"
  check grep -Eq '^## Judgment latitude' "$f" -- "Judgment latitude section"
  check grep -Eq '^## Guardrails' "$f" -- "Guardrails section"
  check grep -Eq '^## Progress reporting' "$f" -- "Progress reporting section"
  check grep -q '\.claude/flywheel/runs/' "$f" -- "Progress reporting names .claude/flywheel/runs/"
  check grep -Eq '^## Improvement log' "$f" -- "Improvement log (maturation) section"
  if awk '/^## Improvement log/{f=1;next} f&&/^### /{bad=1} END{exit bad}' "$f"; then
    ok "Improvement log empty at creation"
  else
    fail "Improvement log empty at creation"
  fi
}

case "$ID" in
  1)
    f="$(new_contract)"
    if [ -n "$f" ]; then ok "new contract file created under .claude/flywheel/processes/"; contract_shape "$f"; else fail "new contract file created under .claude/flywheel/processes/"; fi
    ;;
  2)
    D="$W/.claude/flywheel/DATA.md"
    check test -f "$D" -- "DATA.md recreated"
    for s in Store Access Schema Conventions; do
      check grep -Eq "^## $s" "$D" -- "DATA.md: ## $s"
    done
    f="$(new_contract)"
    if [ -n "$f" ]; then ok "new contract file created under .claude/flywheel/processes/"; contract_shape "$f"; else fail "new contract file created under .claude/flywheel/processes/"; fi
    ;;
  3)
    f="$PROC/plate-audit.md"
    check grep -Eq '^version: 2' "$f" -- "version bumped to 2"
    # date may arrive as a '### <date> — …' heading (run's template) or a dated
    # bullet — process SKILL.md fixes no format, so accept any dated entry
    check awk '/^## Improvement log/{f=1;next} f&&/20[0-9][0-9]-[0-1][0-9]-[0-3][0-9]/&&!/^<!--/&&!/-->/{found=1} END{exit !found}' "$f" -- "Improvement log gained a dated entry"
    check grep -q '\*\*Normalize\*\*' "$f" -- "original Rule 1 (Normalize) preserved"
    check awk '/^## Output schema/{f=1;next} /^## /{f=0} f&&/round_number/{found=1} END{exit !found}' "$f" -- "round_number added to Output schema"
    ;;
  *) echo "unknown eval id: $ID" >&2; exit 2 ;;
esac

exit "$rc"
