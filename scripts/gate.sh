#!/usr/bin/env bash
# flywheel — deterministic completion gate (Stop hook).
#
# OPT-IN: this gate only does anything if the project defines an executable
#   "$CLAUDE_PROJECT_DIR/.claude/flywheel/gate.sh"
# containing the project's own verification command, e.g.:
#   #!/usr/bin/env bash
#   npm test && npm run lint
#
# When that file exists AND you have trusted it (see below), this hook runs it
# whenever Claude tries to finish a turn. If it fails, the turn is blocked
# (exit 2, output fed back to Claude) so work isn't declared "done" with checks
# red. When it doesn't exist, this is a no-op.
#
# TRUST (why a consent step): the gate file lives in the repo, so any PR or
# clone can add or rewrite it — and a Stop hook runs it automatically. To stop a
# malicious gate from running on your machine, an unrecognized gate is NOT
# executed: the hook prints the one command that trusts it (a content hash
# recorded OUTSIDE the repo tree, so a PR can't self-authorize) and lets the
# turn end. Editing the gate revokes trust until you re-consent.
#
# Safety: trust is fail-SAFE (unverified gate never runs); everything else is
# fail-OPEN (any internal error degrades to a no-op and never blocks the turn).
# Bounded to MAX consecutive blocks PER failing tree, and the bypass persists so
# a permanently red gate can't re-trap every turn.
#
# Note: trust defends against a static planted/edited gate file (a PR/clone),
# NOT against a concurrent local attacker racing the hash-then-run window.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
GATE="${PROJECT_DIR}/.claude/flywheel/gate.sh"
STATE="${PROJECT_DIR}/.claude/flywheel/.gate-state"
MAX=3

# Read stdin (hook JSON) so we can inspect stop_hook_active; never fail on it.
INPUT="$(cat 2>/dev/null)"

# Not opted in → allow (no-op), and clear any leftover state.
if [ ! -x "${GATE}" ]; then
  rm -f "${STATE}" 2>/dev/null
  exit 0
fi

# --- Trust check (fail-safe) --------------------------------------------------
# Consent store lives outside the repo tree so a PR that adds the gate cannot
# also authorize it. FLYWHEEL_STATE_DIR overrides the location (used by tests).
STATE_DIR="${FLYWHEEL_STATE_DIR:-${XDG_STATE_HOME:-${HOME}/.local/state}/flywheel}"
TRUSTED="${STATE_DIR}/trusted-gates"

# Refuse a consent store that resolves INSIDE the repo — otherwise a PR could
# point FLYWHEEL_STATE_DIR/XDG_STATE_HOME (via project config) at a repo path
# and commit a matching trusted-gates, self-authorizing the planted gate.
PROJ_ABS="$(cd "${PROJECT_DIR}" 2>/dev/null && pwd -P || printf '%s' "${PROJECT_DIR}")"
case "${STATE_DIR}" in
  /*) SD_ABS="${STATE_DIR}" ;;
  *)  SD_ABS="$(pwd)/${STATE_DIR}" ;;
esac
case "${SD_ABS}/" in
  "${PROJ_ABS}/"*)
    echo "flywheel gate: consent store resolves inside the repo — refusing to run (trust must live outside the project)." >&2
    exit 0 ;;
esac

gate_hash() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" 2>/dev/null | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1
  fi
}
HASH="$(gate_hash "${GATE}")"

# If we can't hash (no sha tool), fail OPEN: behave as a no-op rather than block.
if [ -z "${HASH}" ]; then
  exit 0
fi

if ! { [ -f "${TRUSTED}" ] && grep -qxF "${HASH}" "${TRUSTED}" 2>/dev/null; }; then
  {
    echo "flywheel gate: .claude/flywheel/gate.sh is not trusted yet, so it was NOT run."
    echo "A repo file that runs on every turn is a code-execution risk — review it, then trust it with:"
    echo "  mkdir -p \"${STATE_DIR}\" && echo ${HASH} >> \"${TRUSTED}\""
    echo "(editing the gate changes its hash and revokes trust until you re-run this.)"
  } >&2
  exit 0   # fail-safe: never execute an unverified gate; never block the turn
fi

# --- Cost cache ---------------------------------------------------------------
# Skip the (possibly expensive) suite when the git-tracked working tree is
# byte-for-byte the state that last passed. A cache, never a gate: any git-
# visible change re-runs; no git → always run. (Non-git state — env, external
# files — is not observed; the cache only ever skips a re-run, never turns a
# red gate green for a changed tree.)
gate_stdin_hash() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum 2>/dev/null | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 2>/dev/null | cut -d' ' -f1
  fi
}
tree_signature() {
  command -v git >/dev/null 2>&1 || return 1
  git -C "${PROJECT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  # Exclude .claude/flywheel — the hook writes its own state (.gate-state,
  # reports) there, so including it would make the signature change every run
  # and the cache never hit. The gate verifies project code, not flywheel state.
  local ex=':(exclude).claude/flywheel'
  {
    git -C "${PROJECT_DIR}" rev-parse HEAD 2>/dev/null
    git -C "${PROJECT_DIR}" status --porcelain -- . "${ex}" 2>/dev/null
    git -C "${PROJECT_DIR}" diff HEAD -- . "${ex}" 2>/dev/null     # staged + unstaged tracked content
    # untracked files: names AND content (status --porcelain shows only names)
    git -C "${PROJECT_DIR}" ls-files -o --exclude-standard -z -- . "${ex}" 2>/dev/null \
      | while IFS= read -r -d '' f; do printf '%s\0' "${f}"; cat "${PROJECT_DIR}/${f}" 2>/dev/null; done
  } | gate_stdin_hash
}
SIG="$(tree_signature)"

# State file fields (one per line): count, passed-sig, bypass-sig, counting-sig.
S=""; [ -f "${STATE}" ] && S="$(cat "${STATE}" 2>/dev/null)"
COUNT="$(printf '%s\n' "${S}" | sed -n '1p' | tr -dc '0-9')"; [ -z "${COUNT}" ] && COUNT=0
PASSED_SIG="$(printf '%s\n' "${S}" | sed -n '2p')"
BYPASS_SIG="$(printf '%s\n' "${S}" | sed -n '3p')"
COUNT_SIG="$(printf '%s\n' "${S}" | sed -n '4p')"

# Unchanged since last green → allow without re-running.
if [ -n "${SIG}" ] && [ "${SIG}" = "${PASSED_SIG}" ]; then
  exit 0
fi

# Already bypassed this exact failing tree → don't re-trap (persisted escape).
if [ -n "${SIG}" ] && [ "${SIG}" = "${BYPASS_SIG}" ]; then
  exit 0
fi

# stop_hook_active defense-in-depth: if the runtime says we're already looping
# on the Stop hook, don't re-trap.
STOP_ACTIVE=0
if command -v python3 >/dev/null 2>&1; then
  STOP_ACTIVE="$(FW_IN="${INPUT}" python3 -c 'import json,os
try: print(1 if json.loads(os.environ.get("FW_IN","") or "{}").get("stop_hook_active") else 0)
except Exception: print(0)' 2>/dev/null)"
  [ -z "${STOP_ACTIVE}" ] && STOP_ACTIVE=0
fi

# --- Run the trusted gate -----------------------------------------------------
OUT="$( cd "${PROJECT_DIR}" && bash "${GATE}" 2>&1 )"
CODE=$?

if [ "${CODE}" -eq 0 ]; then
  # Green → record the passing signature; clear counter, bypass and counting.
  printf '0\n%s\n\n\n' "${SIG}" > "${STATE}" 2>/dev/null
  exit 0
fi

# Gate failed. The attempt counter is keyed to the failing tree: a NEW failing
# signature starts its own MAX budget, so one bypass can't disable the gate for
# later, different regressions.
if [ "${SIG}" != "${COUNT_SIG}" ]; then COUNT=0; fi

if [ "${COUNT}" -ge "${MAX}" ] || [ "${STOP_ACTIVE}" = "1" ]; then
  # Persist the bypass against THIS failing tree so we don't re-trap next turn.
  printf '%s\n%s\n%s\n%s\n' "${COUNT}" "${PASSED_SIG}" "${SIG}" "${SIG}" > "${STATE}" 2>/dev/null
  {
    echo "flywheel gate: still failing after ${MAX} attempts — bypassing so you aren't blocked."
    echo "Fix these before shipping:"
    echo "${OUT}" | tail -n 40
  } >&2
  exit 0   # fail-open escape valve
fi

printf '%s\n%s\n%s\n%s\n' "$((COUNT + 1))" "${PASSED_SIG}" "${BYPASS_SIG}" "${SIG}" > "${STATE}" 2>/dev/null

{
  echo "flywheel gate FAILED (.claude/flywheel/gate.sh exited ${CODE}). Do not finish until this is green — fix and re-run:"
  echo "${OUT}" | tail -n 40
} >&2
exit 2   # block the turn from ending; stderr is fed back to Claude
