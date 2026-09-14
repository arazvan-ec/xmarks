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
    # The maturation must survive the session that made it. Read the contract AS
    # GIT HAS IT: "the file changed" passes on the staged-and-lost behaviour this
    # asserts against. Reachable only here, because step 4 matures after a
    # SUCCESSFUL run — a blocked one never opens this path.
    CONTRACT=".claude/flywheel/processes/plate-audit.md"
    if git -C "$W" show "HEAD:$CONTRACT" 2>/dev/null | grep -qE '^### [0-9]{4}-[0-9]{2}-[0-9]{2} — '; then
      ok "the maturation reached git (HEAD's contract carries the dated Improvement log entry)"
    else
      fail "the maturation reached git — HEAD's contract has no dated entry (staged is lost when the session ends)"
    fi
    if [ -z "$(git -C "$W" diff HEAD -- "$CONTRACT")" ] && [ -z "$(git -C "$W" diff --cached -- "$CONTRACT")" ]; then
      ok "nothing about the contract left uncommitted or staged"
    else
      fail "nothing about the contract left uncommitted or staged"
    fi
    LAST="$(git -C "$W" log --format=%H -- "$CONTRACT" 2>/dev/null | head -1)"
    TOUCHED="$(git -C "$W" show --name-only --format= "${LAST}" 2>/dev/null | grep -c . || true)"
    if [ "${TOUCHED}" = "1" ]; then ok "the maturation commit touches the contract and nothing else"; else fail "the maturation commit touches the contract alone (carries ${TOUCHED} file(s))"; fi
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
  4)
    # Every assertion is a NEGATIVE: the correct outcome of this eval is that
    # nothing happened. A run that "completed" with an empty result is the exact
    # failure this eval exists to catch, so absence of work is what passes.
    if ! grep -q "9876 KZX" "$AUD" 2>/dev/null; then
      ok "nothing persisted for 9876 KZX (the run never reached a write)"
    else
      fail "nothing persisted for 9876 KZX (a row was written despite an unreachable store)"
    fi
    check seed_intact -- "seeded 1234 BCD row byte-intact"
    check not_unstaged -- "datastore not modified"
    if ! staged; then ok "datastore not staged (no partial write committed)"; else fail "datastore not staged"; fi
    # A run that stopped at step 1 may have opened its ledger; it must not have
    # worked through the contract. Any Rule marked done means it executed first
    # and discovered the broken store afterwards — the defect, not the fix.
    if ! grep -hoE '"state"[[:space:]]*:[[:space:]]*"[a-z_]+"' "$W"/.claude/flywheel/runs/*/*.jsonl 2>/dev/null \
         | grep -qE '"(done|complete|completed|green|passed)"'; then
      ok "no Rule recorded as completed (stopped before executing the contract)"
    else
      fail "a Rule was recorded as completed — the run executed before probing its write path"
    fi
    # WITHOUT this, every assertion above is satisfied by a workdir nobody ever
    # ran — a hollow grader, which is what P26's red-on-untouched invariant
    # exists to catch. A deliberate stop must leave a trace, so the run records
    # the blocker in its ledger BEFORE stopping. That is the one positive
    # assertion here, and it is what separates "refused correctly" from "never
    # started".
    if grep -hoE '"(state|status)"[[:space:]]*:[[:space:]]*"[a-z_]+"' "$W"/.claude/flywheel/runs/*/*.jsonl 2>/dev/null \
         | grep -qE '"(blocked|blocker|stopped|refused)"'; then
      ok "the run recorded a blocker before stopping (it refused; it did not simply never start)"
    else
      fail "no blocker recorded in the run ledger — an untouched workdir is indistinguishable from a correct refusal"
    fi
    # The store is unreachable, so a result appearing anywhere else means the run
    # silently fell back to a second store — banned: it scatters a process's
    # records with nobody told.
    if ! grep -rl "9876" "$W/data" 2>/dev/null | grep -qv "plate-audits.md"; then
      ok "no fallback artifact outside the declared store"
    else
      fail "a result appeared outside the declared store (silent fallback)"
    fi
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
