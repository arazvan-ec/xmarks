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
# Usage (with an xmarks checkout available):
#   bash /path/to/xmarks/scripts/install-vendored.sh [--auto-update] [target-repo-dir]
#   bash /path/to/xmarks/scripts/install-vendored.sh --uninstall [target-repo-dir]
#
# target-repo-dir defaults to the current directory. Re-running is safe: the
# script is idempotent and refreshes previously vendored copies in place.
# The vendored version is recorded in .claude/flywheel/VERSION, and every file
# the install writes is listed in .claude/flywheel/.manifest. Files that
# existed before flywheel (e.g. your own .claude/agents/verifier.md) are backed
# up next to the original as <file>.pre-flywheel before being overwritten.
#
# --auto-update additionally writes .github/workflows/flywheel-update.yml, a
# thin caller of the reusable workflow in this repo that refreshes the vendored
# copy weekly and opens a PR when a new flywheel version is out. The caller
# repo must allow GitHub Actions to create pull requests
# (Settings → Actions → General).
#
# --uninstall removes everything the install put there (vendored skills,
# agents, hook scripts, hook entries in settings.json, VERSION, manifest, the
# auto-update workflow) restoring any .pre-flywheel backups, but preserves
# flywheel's project state: .claude/flywheel/LEARNINGS.md, specs/ and gate.sh.

set -euo pipefail

MODE=install
AUTO_UPDATE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) MODE=uninstall; shift ;;
    --auto-update) AUTO_UPDATE=1; shift ;;
    --*) echo "error: unknown flag $1" >&2; exit 1 ;;
    *) break ;;
  esac
done

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

SKILLS_DST="${TARGET}/.claude/skills"
AGENTS_DST="${TARGET}/.claude/agents"
FLYWHEEL_DST="${TARGET}/.claude/flywheel"
BIN_DST="${FLYWHEEL_DST}/bin"
SETTINGS="${TARGET}/.claude/settings.json"
MANIFEST="${FLYWHEEL_DST}/.manifest"
UPDATE_WORKFLOW_REL=".github/workflows/flywheel-update.yml"

SESSION_START_CMD='"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/session-start.sh'
READ_PRIME_CMD='"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/read-prime.sh'
GATE_CMD='"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/gate.sh'

# True if a previous install wrote this repo-relative path (so it is ours to
# overwrite/remove without a backup).
in_manifest() { [ -f "${MANIFEST}" ] && grep -qxF "$1" "${MANIFEST}"; }

if [ "${MODE}" = "uninstall" ]; then
  rm -rf "${SKILLS_DST}"/flywheel-*

  # Remove files we vendored (manifest when present, else the source listing
  # for pre-manifest installs), restoring any .pre-flywheel backups.
  remove_or_restore() {
    local path="${TARGET}/$1"
    if [ -f "${path}.pre-flywheel" ]; then
      mv "${path}.pre-flywheel" "${path}"
      echo "restored pre-flywheel backup of $1"
    else
      rm -f "${path}"
    fi
  }
  if [ -f "${MANIFEST}" ]; then
    while IFS= read -r rel; do
      case "${rel}" in
        .claude/skills/*|.claude/flywheel/bin/*|.claude/flywheel/VERSION) ;; # handled wholesale below
        *) remove_or_restore "${rel}" ;;
      esac
    done < "${MANIFEST}"
  else
    for f in "${SRC}"/agents/*.md; do
      remove_or_restore ".claude/agents/$(basename "${f}")"
    done
  fi
  rm -rf "${BIN_DST}" "${FLYWHEEL_DST}/VERSION" "${MANIFEST}"

  if [ -f "${SETTINGS}" ]; then
    FW_SESSION_START="${SESSION_START_CMD}" FW_READ_PRIME="${READ_PRIME_CMD}" FW_GATE="${GATE_CMD}" \
    python3 - "${SETTINGS}" <<'PY'
import json, os, sys

path = sys.argv[1]
with open(path) as f:
    settings = json.load(f)

ours = {os.environ["FW_SESSION_START"], os.environ["FW_READ_PRIME"], os.environ["FW_GATE"]}
hooks = settings.get("hooks", {})
for event in list(hooks):
    groups = []
    for g in hooks[event]:
        g["hooks"] = [h for h in g.get("hooks", []) if h.get("command") not in ours]
        if g["hooks"]:
            groups.append(g)
    if groups:
        hooks[event] = groups
    else:
        del hooks[event]
if not hooks:
    settings.pop("hooks", None)

if settings:
    with open(path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
else:
    os.remove(path)
print("removed flywheel hooks from .claude/settings.json")
PY
  fi

  # Clean up directories we may have created, if now empty. Project state
  # (.claude/flywheel/LEARNINGS.md, specs/, gate.sh) is deliberately kept.
  rmdir "${SKILLS_DST}" "${AGENTS_DST}" "${FLYWHEEL_DST}" "${TARGET}/.claude" \
        "${TARGET}/.github/workflows" "${TARGET}/.github" 2>/dev/null || true

  echo "flywheel uninstalled from ${TARGET}"
  [ -d "${FLYWHEEL_DST}" ] && echo "(kept project state under .claude/flywheel/ — delete it manually if unwanted)"
  exit 0
fi

if [ ! -e "${TARGET}/.git" ]; then
  echo "warning: ${TARGET} is not a git repo root — vendoring anyway" >&2
fi

mkdir -p "${SKILLS_DST}" "${AGENTS_DST}" "${BIN_DST}"
NEW_MANIFEST="$(mktemp)"

# Rewrite plugin-namespaced command references (/flywheel:spec) to the
# vendored flat names (/flywheel-spec).
rewrite() { sed 's|/flywheel:|/flywheel-|g' "$1"; }

# Write a vendored file at repo-relative $1 from stdin, backing up any
# pre-flywheel original the first time we touch it.
vendor_file() {
  local rel="$1" dst tmp
  dst="${TARGET}/${rel}"
  tmp="$(mktemp)"
  cat > "${tmp}"
  if [ -f "${dst}" ] && ! in_manifest "${rel}" && ! cmp -s "${tmp}" "${dst}"; then
    cp "${dst}" "${dst}.pre-flywheel"
    echo "warning: ${rel} existed before flywheel — original saved as ${rel}.pre-flywheel" >&2
  fi
  mv "${tmp}" "${dst}"
  echo "${rel}" >> "${NEW_MANIFEST}"
}

count=0
for dir in "${SRC}"/skills/*/; do
  name="$(basename "${dir}")"
  mkdir -p "${SKILLS_DST}/flywheel-${name}"
  rewrite "${dir}SKILL.md" \
    | sed "0,/^name: ${name}\$/s//name: flywheel-${name}/" \
    | vendor_file ".claude/skills/flywheel-${name}/SKILL.md"
  count=$((count + 1))
done
echo "vendored ${count} skills into .claude/skills/flywheel-*"

for f in "${SRC}"/agents/*.md; do
  rewrite "${f}" | vendor_file ".claude/agents/$(basename "${f}")"
done
echo "vendored $(ls "${SRC}"/agents/*.md | wc -l | tr -d ' ') agents into .claude/agents/"

for f in "${SRC}"/scripts/session-start.sh "${SRC}"/scripts/read-prime.sh "${SRC}"/scripts/gate.sh; do
  rewrite "${f}" | vendor_file ".claude/flywheel/bin/$(basename "${f}")"
  chmod +x "${BIN_DST}/$(basename "${f}")"
done
echo "vendored hook scripts into .claude/flywheel/bin/"

if [ "${AUTO_UPDATE}" = 1 ]; then
  if [ -f "${TARGET}/${UPDATE_WORKFLOW_REL}" ] && ! in_manifest "${UPDATE_WORKFLOW_REL}"; then
    echo "warning: ${UPDATE_WORKFLOW_REL} already exists and is not flywheel's — leaving it untouched" >&2
  else
    mkdir -p "${TARGET}/.github/workflows"
    vendor_file "${UPDATE_WORKFLOW_REL}" <<'YAML'
name: flywheel update

# Written by flywheel's install-vendored.sh --auto-update. Refreshes the
# vendored flywheel copy weekly and opens a PR when a new version is out.
# Requires: Settings → Actions → General → "Allow GitHub Actions to create
# and approve pull requests".

on:
  schedule:
    - cron: "0 6 * * 1"
  workflow_dispatch: {}

jobs:
  update:
    uses: arazvan-ec/xmarks/.github/workflows/flywheel-update.yml@main
    permissions:
      contents: write
      pull-requests: write
YAML
    echo "wrote ${UPDATE_WORKFLOW_REL} (weekly auto-update PRs)"
  fi
  # Point the user at the exact toggle the workflow needs, deriving the
  # settings URL from the repo's origin (handles git@, https:// and proxied
  # remotes by taking the last two path segments).
  ORIGIN="$(git -C "${TARGET}" remote get-url origin 2>/dev/null || true)"
  REPO_PATH="$(printf '%s\n' "${ORIGIN}" | sed -E 's#\.git$##; s#.*[:/]([^/]+/[^/]+)$#\1#')"
  echo ""
  echo "⚠️  auto-update PRs need a one-time repo setting (admin, GitHub UI only):"
  if [ -n "${REPO_PATH}" ] && [ "${REPO_PATH}" != "${ORIGIN}" ]; then
    echo "   https://github.com/${REPO_PATH}/settings/actions"
  else
    echo "   your repo's Settings → Actions → General"
  fi
  echo "   → Workflow permissions → check 'Allow GitHub Actions to create and approve pull requests' → Save"
fi

# Record what was vendored, so repos know which version they carry.
PLUGIN_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "${SRC}/.claude-plugin/plugin.json")"
SRC_COMMIT="$(git -C "${SRC}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
{
  echo "flywheel ${PLUGIN_VERSION}"
  echo "source-commit: ${SRC_COMMIT}"
  echo "installed: $(date +%F)"
} > "${FLYWHEEL_DST}/VERSION"
echo ".claude/flywheel/VERSION" >> "${NEW_MANIFEST}"
echo "recorded flywheel ${PLUGIN_VERSION} (${SRC_COMMIT}) in .claude/flywheel/VERSION"

sort -u "${NEW_MANIFEST}" > "${MANIFEST}"
rm -f "${NEW_MANIFEST}"

# Merge the SessionStart/PreToolUse/Stop hooks into the target's
# .claude/settings.json, keeping everything already there. Idempotent: entries
# are matched by their command string.
FW_SESSION_START="${SESSION_START_CMD}" FW_READ_PRIME="${READ_PRIME_CMD}" FW_GATE="${GATE_CMD}" \
python3 - "${SETTINGS}" <<'PY'
import json, os, sys

path = sys.argv[1]
settings = {}
if os.path.exists(path):
    with open(path) as f:
        settings = json.load(f)

wanted = [
    ("SessionStart", None, {
        "type": "command",
        "command": os.environ["FW_SESSION_START"],
        "timeout": 15,
    }),
    ("PreToolUse", "Read", {
        "type": "command",
        "command": os.environ["FW_READ_PRIME"],
        "timeout": 5,
    }),
    ("Stop", None, {
        "type": "command",
        "command": os.environ["FW_GATE"],
        "timeout": 300,
    }),
]

hooks = settings.setdefault("hooks", {})
for event, matcher, hook in wanted:
    groups = hooks.setdefault(event, [])
    present = any(
        h.get("command") == hook["command"]
        for g in groups
        for h in g.get("hooks", [])
    )
    if not present:
        group = {"hooks": [hook]}
        if matcher is not None:
            group["matcher"] = matcher
        groups.append(group)

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
