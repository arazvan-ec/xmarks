#!/usr/bin/env bash
# Deterministic grader for skills/run evals. Usage: check.sh <eval_id> <workdir>
# Prints PASS/FAIL per expectation; exit 0 only if all pass.
set -u

ID="${1:?eval id}"; W="${2:?workdir}"
AUD="$W/data/plate-audits.md"
rc=0
ok()   { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; rc=1; }
check() { # check <expr...> -- <label>
  local args=(); while [ "$1" != "--" ]; do args+=("$1"); shift; done; shift
  if "${args[@]}" >/dev/null 2>&1; then ok "$1"; else fail "$1"; fi
}

row() { grep -Ec "\|[ ]*$1[ ]*\|" "$AUD" 2>/dev/null; }
not_unstaged() { ! git -C "$W" diff --name-only | grep -qx data/plate-audits.md; }
# Positive proof the run wrote: DATA.md requires the datastore to end up STAGED.
# not_unstaged() alone is satisfied by an untouched file, so an in-place update
# (eval 2) needs this instead — otherwise a run that did nothing scores full marks.
staged() { git -C "$W" diff --cached --name-only | grep -qx data/plate-audits.md; }
seed_intact() { grep -E "\|[ ]*1234 BCD[ ]*\|[ ]*1234[ ]*\|[ ]*BCD[ ]*\|[ ]*10[ ]*\|" "$AUD"; }

case "$ID" in
  1)
    # the run's own date, not the grading date — a workdir graded the next day
    # must still grade the same. Export FW_EVAL_DATE when regrading old runs.
    TODAY="${FW_EVAL_DATE:-$(date +%F)}"
    check grep -E "\|[ ]*9876 KZX[ ]*\|[ ]*9876[ ]*\|[ ]*KZX[ ]*\|[ ]*30[ ]*\|[ ]*${TODAY}[ ]*\|" "$AUD" -- "row for 9876 KZX with digits/letters/digit_sum=30/audited=today"
    check not_unstaged -- "write landed (no unstaged modification of the datastore)"
    # two-tier since v0.30.0: JSONL per transition, HTML rendered at close —
    # the final report always renders, so require the HTML and accept the JSONL beside it
    check ls "$W"/.claude/flywheel/runs/plate-audit/*.html -- "telemetry report rendered in .claude/flywheel/runs/plate-audit/"
    check seed_intact -- "seeded 1234 BCD row untouched"
    ;;
  2)
    # The seed already satisfies "one row, digit_sum=10", so those alone cannot
    # tell a correct upsert from a run that did nothing. The run date and the
    # staged write are what prove the re-audit actually happened.
    TODAY="${FW_EVAL_DATE:-$(date +%F)}"
    n="$(row '1234 BCD')"
    if [ "$n" = "1" ]; then ok "exactly one row for 1234 BCD (idempotent upsert)"; else fail "exactly one row for 1234 BCD (found $n)"; fi
    check grep -E "\|[ ]*1234 BCD[ ]*\|[ ]*1234[ ]*\|[ ]*BCD[ ]*\|[ ]*10[ ]*\|[ ]*${TODAY}[ ]*\|" "$AUD" -- "deterministic fields preserved, audited refreshed to the run date (digit_sum=10)"
    check staged -- "write landed (datastore staged as modified)"
    ;;
  3)
    if [ -f "$AUD" ] && ! awk '/^## Rejections/{exit} /\|/ && /AEI/' "$AUD" | grep -q .; then
      ok "no fabricated audit row for AEI"
    else
      fail "no fabricated audit row for AEI"
    fi
    check awk '/^## Rejections/{f=1;next} f&&/[Aa][Ee][Ii]/{found=1} END{exit !found}' "$AUD" -- "rejection recorded under ## Rejections"
    check seed_intact -- "seeded 1234 BCD row untouched"
    ;;
  *) echo "unknown eval id: $ID" >&2; exit 2 ;;
esac

exit "$rc"
