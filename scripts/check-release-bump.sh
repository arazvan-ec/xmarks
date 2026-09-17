#!/usr/bin/env bash
# flywheel — CI gate (P47): the release convention, read in the direction it is
# written. CLAUDE.md says every change to skills/, agents/, hooks/ or scripts/
# is a release; test-docs-consistency.sh only ever checked the converse — that a
# version already declared has a note. Nothing asked where the bump was.
#
# Usage: check-release-bump.sh [base-ref]   (default: BASE_REF env, then
# origin/main, then main) — base resolution identical to check-test-pairing.sh,
# so the two gates cannot disagree about what "the base" is.
#
# Two escape hatches, both carrying a REASON rather than a 1, because an
# exception is a debt and the reason is what makes it payable:
#   Release-Exception: <reason>   a trailer on a commit in the diff. The one a
#                                 pull request can use — it reaches CI, travels
#                                 with the commits under review, and expires
#                                 with them.
#   SKIP_RELEASE_BUMP=<reason>    the operator's lever, for a local run. It
#                                 reaches no CI runner.
# A bare truthy value is refused in both.
#
# Exit: 0 ok · 1 a release-bearing change with no release · 2 unusable input

set -uo pipefail

SKIP="${SKIP_RELEASE_BUMP:-}"
if [ -n "${SKIP}" ]; then
  case "$(printf '%s' "${SKIP}" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|on|y|t)
      echo "release-bump: SKIP_RELEASE_BUMP must carry a reason, not '${SKIP}'." >&2
      echo "              e.g. SKIP_RELEASE_BUMP='orchestrator renumbers at integration'" >&2
      exit 2 ;;
  esac
  echo "release-bump: SKIPPED — ${SKIP}"
  exit 0
fi

BASE="${1:-${BASE_REF:-}}"
if [ -z "${BASE}" ]; then
  if git rev-parse -q --verify origin/main >/dev/null; then BASE=origin/main; else BASE=main; fi
fi

# An empty diff and a diff that could not be taken look identical in a variable,
# and treating the second as the first is exactly the fail-open this gate exists
# to close: a typo'd or unfetched base would wave every release-bearing change
# through. A shallow checkout is the realistic way to get here.
if ! changed="$(git diff --name-only "${BASE}...HEAD" -- skills agents hooks scripts 2>/dev/null)"; then
  echo "release-bump: cannot diff ${BASE}...HEAD — is '${BASE}' a ref this checkout has?" >&2
  echo "              (a shallow clone does not; CI checks out with fetch-depth: 0)" >&2
  exit 2
fi
[ -n "${changed}" ] || { echo "release-bump: no release-bearing changes vs ${BASE}"; exit 0; }

# The exception a pull request can actually carry. SKIP_RELEASE_BUMP is the
# operator's lever and reaches nothing in CI: the workflow step passes no
# environment, and a PR cannot add one without editing the workflow for every
# later PR — which would leave the gate disabled rather than excepted once. A
# trailer travels with the commits under review, expires with them, and is read
# in the same place the reason has to be argued.
# Matched as whole LINES, not as captured reasons: a trailer whose reason is
# empty captures to "" and would otherwise be indistinguishable from no trailer
# at all — which is the one case that must refuse rather than fall through.
exc_raw="$(git log --format=%B "${BASE}..HEAD" 2>/dev/null \
  | grep -E '^[[:space:]]*Release-Exception:' || true)"
if [ -n "${exc_raw}" ]; then
  reason="$(printf '%s\n' "${exc_raw}" \
    | sed -E 's/^[[:space:]]*Release-Exception:[[:space:]]*//; s/[[:space:]]+$//' \
    | grep -v '^$' | head -n1)"
  if [ -z "${reason}" ]; then
    echo "release-bump: a Release-Exception: trailer carries the reason, and this one is empty." >&2
    echo "              e.g. Release-Exception: orchestrator renumbers at integration" >&2
    exit 2
  fi
  echo "release-bump: EXCEPTED by a commit trailer — ${reason}"
  exit 0
fi

command -v python3 >/dev/null 2>&1 || { echo "release-bump: no python3" >&2; exit 2; }

MANIFEST=".claude-plugin/plugin.json"
READ_V='import json,sys; print(json.load(sys.stdin)["version"])'
BASE_V="$(git show "${BASE}:${MANIFEST}" 2>/dev/null | python3 -c "${READ_V}" 2>/dev/null)"
HEAD_V="$(python3 -c "${READ_V}" < "${MANIFEST}" 2>/dev/null)"
[ -n "${BASE_V}" ] || { echo "release-bump: cannot read a version from ${BASE}:${MANIFEST}" >&2; exit 2; }
[ -n "${HEAD_V}" ] || { echo "release-bump: cannot read a version from ${MANIFEST}" >&2; exit 2; }

# GREATER, not merely different. A branch cut before the base moved carries an
# OLDER version, which differs from the base's and would sail through — and that
# is the shape of PR #85 itself (head 0.58.0, base 0.61.0, scripts/ changed).
python3 -c 'import re,sys
def p(v):
    m = re.match(r"^(\d+)\.(\d+)\.(\d+)$", v.strip())
    if not m: sys.exit(2)
    return tuple(map(int, m.groups()))
sys.exit(0 if p(sys.argv[2]) > p(sys.argv[1]) else 1)' "${BASE_V}" "${HEAD_V}"
ahead=$?
[ "${ahead}" -le 1 ] || { echo "release-bump: '${BASE_V}' or '${HEAD_V}' is not an x.y.z version" >&2; exit 2; }

rc=0
if [ "${ahead}" -ne 0 ]; then
  echo "release-bump: this diff touches a release-bearing path, but ${MANIFEST} says ${HEAD_V}, which is not ahead of ${BASE}'s ${BASE_V}:" >&2
  printf '%s\n' "${changed}" | sed 's/^/              /' >&2
  echo "              Bump the version and write upgrades/v<new>.md (CLAUDE.md, 'Repo conventions')." >&2
  echo "              A branch cut before ${BASE} moved needs ${BASE} merged in first." >&2
  rc=1
fi

NOTE="upgrades/v${HEAD_V}.md"
if [ "${rc}" -eq 0 ] && [ ! -f "${NOTE}" ]; then
  echo "release-bump: version ${HEAD_V} has no ${NOTE} — every release ships its upgrade analysis" >&2
  rc=1
fi

[ "${rc}" -eq 0 ] && echo "release-bump: OK (${BASE_V} → ${HEAD_V}, ${NOTE})"
exit "${rc}"
