#!/usr/bin/env bash
# flywheel — test for the delegated-work PreToolUse hook.
# Asserts the ask-only contract across its three families: TIER (no `model`,
# no effort named), CONTEXT (no anchor, contract pasted) and FANOUT (an anchor
# already delegated by this session, and width past the threshold). A fully
# decided call, any other tool, malformed input and a missing state file must
# produce no output and exit 0. The hook must never deny and never block.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${SRC}/scripts/delegation-guard.sh"
RECORDER="${SRC}/scripts/delegation-record.sh"
WORK="$(mktemp -d)"
export TMPDIR="${WORK}"          # keep the fanout ledger inside the sandbox
trap 'rm -rf "${WORK}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "  ok: $*"; }

# Build a PreToolUse payload. $1 session id, $2 tool, $3 json object of extras.
payload() {
  FW_SID="$1" FW_TOOL="$2" FW_EXTRA="$3" python3 -c '
import json, os
extra = json.loads(os.environ["FW_EXTRA"])
print(json.dumps({"session_id": os.environ["FW_SID"],
                  "tool_name": os.environ["FW_TOOL"],
                  "tool_input": extra}))'
}

run_hook() { bash "${SCRIPT}"; }
run_recorder() { bash "${RECORDER}"; }

# Asserts the envelope is a well-formed `ask` naming every expected family.
assert_ask() {
  FW_OUT="$1" FW_WANT="$2" python3 - <<'PY'
import json, os, sys
out = os.environ["FW_OUT"].strip()
if not out:
    print("expected an ask envelope, got nothing", file=sys.stderr); sys.exit(1)
d = json.loads(out)["hookSpecificOutput"]
if d.get("hookEventName") != "PreToolUse":
    print("wrong hookEventName: %r" % d.get("hookEventName"), file=sys.stderr); sys.exit(1)
if d.get("permissionDecision") != "ask":
    print("expected ask, got %r" % d.get("permissionDecision"), file=sys.stderr); sys.exit(1)
reason = d.get("permissionDecisionReason") or ""
for family in os.environ["FW_WANT"].split(","):
    if family and ("%s —" % family) not in reason:
        print("reason is missing the %s family: %r" % (family, reason[:200]), file=sys.stderr)
        sys.exit(1)
PY
}

assert_silent() {
  [ -z "$(printf '%s' "$1" | tr -d '[:space:]')" ] || fail "$2 (got: ${1:0:120})"
}

DECIDED='{"model":"sonnet","prompt":"Job 2, issue #29. Route sonnet/medium: run at that effort."}'

# --- the contract's happy path -------------------------------------------
out="$(payload s-happy mcp__Claude_Code_Remote__create_session "${DECIDED}" | run_hook)"
assert_silent "${out}" "a fully decided call must pass in silence"
pass "decided call (model + effort + anchor) produces no output"

# --- TIER -----------------------------------------------------------------
out="$(payload s-tier mcp__Claude_Code_Remote__create_session \
  '{"prompt":"Job 2, issue #29"}' | run_hook)"
assert_ask "${out}" "TIER" || fail "missing model must raise TIER"
pass "no model raises TIER"

out="$(payload s-effort mcp__Claude_Code_Remote__create_session \
  '{"model":"sonnet","prompt":"Do the recorder machine, issue #29"}' | run_hook)"
assert_ask "${out}" "TIER" || fail "unnamed effort must raise TIER"
pass "model without effort raises TIER"

# The ladder is named from route-tiers.txt, not from a copy in the script.
case "${out}" in *"sonnet/medium"*) pass "the ask names tiers read from route-tiers.txt" ;;
  *) fail "the ask does not name the ladder's tiers" ;; esac

# --- CONTEXT ---------------------------------------------------------------
out="$(payload s-anchor mcp__Claude_Code_Remote__create_session \
  '{"model":"sonnet","prompt":"Build the thing. Route sonnet/medium, that effort."}' | run_hook)"
assert_ask "${out}" "CONTEXT" || fail "a prompt with no anchor must raise CONTEXT"
pass "no anchor raises CONTEXT"

big="$(FW_N=9000 python3 -c 'import os;print("x"*int(os.environ["FW_N"]))')"
out="$(FW_BIG="${big}" python3 -c '
import json, os
print(json.dumps({"model":"sonnet",
                  "prompt":"issue #29 Route sonnet/medium effort. " + os.environ["FW_BIG"]}))' \
  | { read -r extra; payload s-copy mcp__Claude_Code_Remote__create_session "${extra}"; } | run_hook)"
assert_ask "${out}" "CONTEXT" || fail "a pasted contract must raise CONTEXT"
pass "an oversized prompt raises CONTEXT (pasted contract)"

# --- FANOUT ----------------------------------------------------------------
# Three recorded children keep quiet; the fourth trips the width threshold.
for n in 28 29 30; do
  payload s-fan mcp__Claude_Code_Remote__create_session \
    "$(FW_N="$n" python3 -c '
import json, os
n = os.environ["FW_N"]
print(json.dumps({"model":"sonnet","prompt":"Job, issue #%s. Route sonnet/medium effort." % n}))')" \
    | run_recorder
done

out="$(payload s-fan mcp__Claude_Code_Remote__create_session \
  '{"model":"sonnet","prompt":"Job, issue #31. Route sonnet/medium effort."}' | run_hook)"
assert_ask "${out}" "FANOUT" || fail "the fourth child must raise FANOUT (width)"
pass "the fourth child raises FANOUT (width)"

out="$(payload s-fan mcp__Claude_Code_Remote__create_session \
  '{"model":"sonnet","prompt":"Relaunch, issue #29. Route sonnet/medium effort."}' | run_hook)"
assert_ask "${out}" "FANOUT" || fail "a re-delegated anchor must raise FANOUT (duplicate)"
case "${out}" in *"#29"*) pass "a re-delegated anchor raises FANOUT and names the issue" ;;
  *) fail "the duplicate warning does not name the repeated anchor" ;; esac

# A different parent session shares no ledger.
out="$(payload s-other mcp__Claude_Code_Remote__create_session \
  '{"model":"sonnet","prompt":"Job, issue #29. Route sonnet/medium effort."}' | run_hook)"
assert_silent "${out}" "the ledger must be per parent session"
pass "another parent session does not inherit the ledger"

# --- subagents share the contract -----------------------------------------
out="$(payload s-agent Agent '{"description":"find it","prompt":"look for X"}' | run_hook)"
assert_ask "${out}" "TIER" || fail "a subagent without model must raise TIER"
case "${out}" in *subagent*) pass "the subagent wording says subagent" ;;
  *) fail "the subagent ask calls it a session" ;; esac

# --- fail-open -------------------------------------------------------------
out="$(payload s-x Bash '{"command":"ls"}' | run_hook)"
assert_silent "${out}" "an unrelated tool must pass through untouched"
pass "an unrelated tool produces no output"

out="$(printf 'create_session {not json' | run_hook)"
assert_silent "${out}" "malformed input must fail open"
pass "malformed input fails open"

out="$(printf '' | run_hook)"
assert_silent "${out}" "empty input must fail open"
pass "empty input fails open"

echo "delegation-guard: all assertions passed"
