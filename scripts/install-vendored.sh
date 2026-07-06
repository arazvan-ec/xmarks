#!/usr/bin/env bash
# flywheel — vendor the plugin into a target repo's .claude/ directory.
#
# Why this exists: Claude Code on the web does NOT install marketplace plugins
# declared in .claude/settings.json (extraKnownMarketplaces/enabledPlugins) at
# session start, so /flywheel:* commands never appear in web sessions. What a
# web session DOES always load is the repo's own .claude/skills, .claude/agents
# and .claude/settings.json hooks — they are part of the clone. This script
# copies the plugin's content there, renamed with a `flywheel-` prefix
# (so /flywheel:spec becomes /flywheel-spec) to avoid colliding with built-in
# commands like /loop, /review and /verify.
#
# Usage (from the target repo root, with an xmarks checkout available):
#   bash /path/to/xmarks/scripts/install-vendored.sh [target-repo-dir]
#
# target-repo-dir defaults to the current directory. Re-running is safe: the
# script is idempotent and refreshes previously vendored copies in place.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-$(pwd)}"
TARGET="$(cd "${TARGET}" && pwd)"

if [ ! -f "${SRC}/skills/help/SKILL.md" ]; then
  echo "error: ${SRC} does not look like an xmarks/flywheel checkout" >&2
  exit 1
fi
if [ "${SRC}" = "${TARGET}" ]; then
  echo "error: target is the flywheel repo itself — run this against another repo" >&2
  exit 1
fi
if [ ! -e "${TARGET}/.git" ]; then
  echo "warning: ${TARGET} is not a git repo root — vendoring anyway" >&2
fi

SKILLS_DST="${TARGET}/.claude/skills"
AGENTS_DST="${TARGET}/.claude/agents"
BIN_DST="${TARGET}/.claude/flywheel/bin"
mkdir -p "${SKILLS_DST}" "${AGENTS_DST}" "${BIN_DST}"

# Rewrite plugin-namespaced command references (/flywheel:spec) to the
# vendored flat names (/flywheel-spec).
rewrite() { sed 's|/flywheel:|/flywheel-|g' "$1"; }

count=0
for dir in "${SRC}"/skills/*/; do
  name="$(basename "${dir}")"
  dst="${SKILLS_DST}/flywheel-${name}"
  mkdir -p "${dst}"
  rewrite "${dir}SKILL.md" \
    | sed "0,/^name: ${name}\$/s//name: flywheel-${name}/" \
    > "${dst}/SKILL.md"
  count=$((count + 1))
done
echo "vendored ${count} skills into .claude/skills/flywheel-*"

for f in "${SRC}"/agents/*.md; do
  rewrite "${f}" > "${AGENTS_DST}/$(basename "${f}")"
done
echo "vendored $(ls "${SRC}"/agents/*.md | wc -l | tr -d ' ') agents into .claude/agents/"

for f in "${SRC}"/scripts/session-start.sh "${SRC}"/scripts/gate.sh; do
  rewrite "${f}" > "${BIN_DST}/$(basename "${f}")"
  chmod +x "${BIN_DST}/$(basename "${f}")"
done
echo "vendored hook scripts into .claude/flywheel/bin/"

# Merge the SessionStart/Stop hooks into the target's .claude/settings.json,
# keeping everything already there. Idempotent: entries are matched by their
# command string.
python3 - "${TARGET}/.claude/settings.json" <<'PY'
import json, os, sys

path = sys.argv[1]
settings = {}
if os.path.exists(path):
    with open(path) as f:
        settings = json.load(f)

wanted = {
    "SessionStart": {
        "type": "command",
        "command": '"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/session-start.sh',
        "timeout": 15,
    },
    "Stop": {
        "type": "command",
        "command": '"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/gate.sh',
        "timeout": 300,
    },
}

hooks = settings.setdefault("hooks", {})
for event, hook in wanted.items():
    groups = hooks.setdefault(event, [])
    present = any(
        h.get("command") == hook["command"]
        for g in groups
        for h in g.get("hooks", [])
    )
    if not present:
        groups.append({"hooks": [hook]})

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
print("merged flywheel hooks into .claude/settings.json")
PY

echo ""
echo "done. Next steps:"
echo "  1. Review the changes:  git -C '${TARGET}' status"
echo "  2. Commit and push them so every session (including web) gets them."
echo "  3. Open a NEW session — you should see '🎡 flywheel loaded' and the"
echo "     /flywheel-help, /flywheel-loop, /flywheel-spec ... commands."
