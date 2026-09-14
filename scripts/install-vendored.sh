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
#   bash /path/to/xmarks/scripts/install-vendored.sh --agents-only [target-repo-dir]
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
AGENTS_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) MODE=uninstall; shift ;;
    --auto-update) AUTO_UPDATE=1; shift ;;
    --agents-only) AGENTS_ONLY=1; shift ;;
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
# Self-targeting the full install would duplicate every skill body into
# .claude/skills/flywheel-*, to drift on the next edit. --agents-only is the one
# exception (P41): agent discovery is session-start scoped and web sessions never
# install marketplace plugins, so without registered copies flywheel's own dev
# loop cannot honor the `+delegate` routes it prescribes to every other repo.
# The exception is INSTALL-only: --uninstall --agents-only here would delete the
# repo's own committed .claude/agents/ and run the hook-uninstall besides.
if [ "${SRC}" = "${TARGET}" ] && ! { [ "${AGENTS_ONLY}" = 1 ] && [ "${MODE}" = install ]; }; then
  echo "error: target is the flywheel repo itself — run this against another repo" >&2
  echo "       (only --agents-only, installing, is allowed here: it registers" >&2
  echo "        agents/ and nothing else — never uninstalls)" >&2
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
WRITE_ALLOW_CMD='"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/write-allow.sh'
BASH_ALLOW_CMD='"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/bash-allow.sh'
GATE_CMD='"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/gate.sh'
DELEGATION_GUARD_CMD='"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/delegation-guard.sh'
DELEGATION_RECORD_CMD='"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/delegation-record.sh'
GIT_TRACKING_REFS_CMD='"$CLAUDE_PROJECT_DIR"/.claude/flywheel/bin/git-tracking-refs.sh'

# True if a previous install wrote this repo-relative path (so it is ours to
# overwrite/remove without a backup).
in_manifest() { [ -f "${MANIFEST}" ] && grep -qxF "$1" "${MANIFEST}"; }

if [ "${MODE}" = "uninstall" ]; then
  remove_or_restore() {
    local path="${TARGET}/$1"
    if [ -f "${path}.pre-flywheel" ]; then
      mv "${path}.pre-flywheel" "${path}"
      echo "restored pre-flywheel backup of $1"
    else
      rm -f "${path}"
    fi
  }
  # Remove vendored skill dirs — manifest-driven, never glob-driven: a dir is
  # only ours to delete if the manifest says we wrote its SKILL.md. A dir whose
  # SKILL.md we backed up at install time belonged to the user first: restore
  # the backup and keep it. (Pre-manifest installs keep the old wholesale
  # behavior — there is no record to consult.)
  for d in "${SKILLS_DST}"/flywheel-*/; do
    [ -d "${d}" ] || continue
    base="$(basename "${d%/}")"
    if [ -f "${d}SKILL.md.pre-flywheel" ]; then
      mv "${d}SKILL.md.pre-flywheel" "${d}SKILL.md"
      echo "restored pre-flywheel backup of ${d#"${TARGET}"/}SKILL.md"
      # The dir is the user's again, but the references/ files we vendored into
      # it are ours (P35). Remove them the way every other vendored file is
      # removed — one at a time, manifest-driven, restoring any backup — and
      # never the directory wholesale: it may hold the user's own files, and
      # their .pre-flywheel backups, which an rm -rf would destroy.
      if [ -f "${MANIFEST}" ]; then
        while IFS= read -r rel; do
          case "${rel}" in
            ".claude/skills/${base}/references/"*) remove_or_restore "${rel}" ;;
          esac
        done < "${MANIFEST}"
        rmdir "${d}references" 2>/dev/null || true
      fi
    elif in_manifest ".claude/skills/${base}/SKILL.md" || [ ! -f "${MANIFEST}" ]; then
      rm -rf "${d}"
    else
      echo "kept ${d#"${TARGET}"/} (not vendored by flywheel)"
    fi
  done

  # Remove files we vendored (manifest when present, else the source listing
  # for pre-manifest installs), restoring any .pre-flywheel backups.
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
  rm -rf "${BIN_DST}" "${FLYWHEEL_DST}/VERSION" "${FLYWHEEL_DST}/PENDING-UPGRADES" "${MANIFEST}"

  if [ -f "${SETTINGS}" ]; then
    FW_SESSION_START="${SESSION_START_CMD}" FW_READ_PRIME="${READ_PRIME_CMD}" \
    FW_WRITE_ALLOW="${WRITE_ALLOW_CMD}" FW_BASH_ALLOW="${BASH_ALLOW_CMD}" FW_GATE="${GATE_CMD}" \
    FW_DELEGATION_GUARD="${DELEGATION_GUARD_CMD}" FW_DELEGATION_RECORD="${DELEGATION_RECORD_CMD}" \
    FW_GIT_TRACKING_REFS="${GIT_TRACKING_REFS_CMD}" \
    python3 - "${SETTINGS}" <<'PY'
import json, os, sys

path = sys.argv[1]
with open(path) as f:
    settings = json.load(f)

ours = {os.environ["FW_SESSION_START"], os.environ["FW_READ_PRIME"],
        os.environ["FW_WRITE_ALLOW"], os.environ["FW_BASH_ALLOW"],
        os.environ["FW_GATE"], os.environ["FW_DELEGATION_GUARD"],
        os.environ["FW_DELEGATION_RECORD"], os.environ["FW_GIT_TRACKING_REFS"]}
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

if [ "${AGENTS_ONLY}" = 1 ]; then
  mkdir -p "${AGENTS_DST}"
else
  mkdir -p "${SKILLS_DST}" "${AGENTS_DST}" "${BIN_DST}"
fi
NEW_MANIFEST="$(mktemp)"

# The version this repo carried BEFORE this refresh — read now, before anything
# overwrites VERSION. Drives the pending-strategy computation below. (Guarded:
# under pipefail a sed on a missing file would abort fresh installs.)
OLD_VERSION=""
if [ -f "${FLYWHEEL_DST}/VERSION" ]; then
  OLD_VERSION="$(sed -n 's/^flywheel //p' "${FLYWHEEL_DST}/VERSION" | head -1)"
fi

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
if [ "${AGENTS_ONLY}" = 0 ]; then
for dir in "${SRC}"/skills/*/; do
  name="$(basename "${dir}")"
  mkdir -p "${SKILLS_DST}/flywheel-${name}"
  # `1,/re/` (portable; the GNU-only zero-start address dies on BSD/macOS
  # sed): safe because line 1 is always the frontmatter `---`, never `name:`.
  rewrite "${dir}SKILL.md" \
    | sed "1,/^name: ${name}\$/s/^name: ${name}\$/name: flywheel-${name}/" \
    | vendor_file ".claude/skills/flywheel-${name}/SKILL.md"
  # Progressive-disclosure references (P35) travel with the body that cites
  # them: a vendored SKILL.md pointing at a references/ file nobody copied
  # loses the rule silently, in someone else's repo. Manifest-recorded like
  # every other vendored file, so pruning and uninstall already know them.
  if [ -d "${dir}references" ]; then
    mkdir -p "${SKILLS_DST}/flywheel-${name}/references"
    for ref in "${dir}references"/*.md; do
      [ -f "${ref}" ] || continue
      rewrite "${ref}" \
        | vendor_file ".claude/skills/flywheel-${name}/references/$(basename "${ref}")"
    done
  fi
  count=$((count + 1))
done
echo "vendored ${count} skills into .claude/skills/flywheel-*"
fi

for f in "${SRC}"/agents/*.md; do
  rewrite "${f}" | vendor_file ".claude/agents/$(basename "${f}")"
done
echo "vendored $(ls "${SRC}"/agents/*.md | wc -l | tr -d ' ') agents into .claude/agents/"

if [ "${AGENTS_ONLY}" = 1 ]; then
  # Merge into the manifest, never replace it: the prune at the end of a full
  # install is manifest-driven, and a narrowed run's manifest would read as
  # "this version dropped every skill". No manifest at all means nothing was
  # ever vendored here, so none is written — the copies are then part of the
  # repo's own tree, which is exactly the flywheel-on-flywheel case.
  # Non-agent entries are KEPT untouched (this run vendored none of them, so
  # dropping them would read as "this version deleted every skill"), but an
  # agent entry the plugin no longer ships is pruned like the full install
  # prunes: the file would otherwise stay discoverable and be delegated to.
  if [ -f "${MANIFEST}" ]; then
    sort -u "${NEW_MANIFEST}" > "${NEW_MANIFEST}.sorted"
    : > "${NEW_MANIFEST}.kept"
    while IFS= read -r rel; do
      case "${rel}" in
        .claude/agents/*) ;;
        *) printf '%s\n' "${rel}" >> "${NEW_MANIFEST}.kept"; continue ;;
      esac
      if grep -qxF "${rel}" "${NEW_MANIFEST}.sorted"; then
        printf '%s\n' "${rel}" >> "${NEW_MANIFEST}.kept"
        continue
      fi
      stale="${TARGET}/${rel}"
      if [ -f "${stale}.pre-flywheel" ]; then
        mv "${stale}.pre-flywheel" "${stale}"
        echo "pruned ${rel} (no longer shipped; pre-flywheel backup restored)"
      elif [ -e "${stale}" ]; then
        rm -f "${stale}"
        echo "pruned ${rel} (no longer shipped)"
      fi
    done < "${MANIFEST}"
    sort -u "${NEW_MANIFEST}" "${NEW_MANIFEST}.kept" > "${MANIFEST}"
    rm -f "${NEW_MANIFEST}.sorted" "${NEW_MANIFEST}.kept"
  fi
  rm -f "${NEW_MANIFEST}"
  exit 0
fi

# Hooks, plus the analysis scripts the skills invoke (plan-route, run-cost):
# without those a vendored repo cannot lint its plan's routes or read its own
# run cost, and the skills' fail-open makes that absence silent.
for f in "${SRC}"/scripts/session-start.sh "${SRC}"/scripts/read-prime.sh "${SRC}"/scripts/write-allow.sh "${SRC}"/scripts/bash-allow.sh "${SRC}"/scripts/gate.sh "${SRC}"/scripts/delegation-guard.sh "${SRC}"/scripts/delegation-record.sh "${SRC}"/scripts/git-tracking-refs.sh "${SRC}"/scripts/plan-route.sh "${SRC}"/scripts/run-cost.sh; do
  rewrite "${f}" | vendor_file ".claude/flywheel/bin/$(basename "${f}")"
  chmod +x "${BIN_DST}/$(basename "${f}")"
done
# plan-route.sh and delegation-guard.sh both resolve the tier table beside
# themselves, so the data file has to travel with them. Not executable: it is
# data, not a script.
rewrite "${SRC}/scripts/route-tiers.txt" | vendor_file ".claude/flywheel/bin/route-tiers.txt"
# Smoke check: a vendored hook that doesn't parse breaks every future session
# start. Abort before the manifest/VERSION swap so a broken refresh is never
# recorded as installed (the rewrite sed above could itself introduce this).
for f in "${BIN_DST}"/*.sh; do
  bash -n "${f}" || { echo "error: vendored ${f#"${TARGET}"/} fails bash -n — aborting install" >&2; exit 1; }
done
echo "vendored hook + analysis scripts into .claude/flywheel/bin/ (bash -n clean)"

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

# Record upgrade strategies this refresh does NOT apply: notes in the range
# (old, new] with requires-action: true. The file is repo STATE (like
# LEARNINGS.md) — deliberately kept out of the manifest so pruning can never
# erase the debt. SessionStart nags on it every session; /flywheel:update
# clears each version after executing its strategy; --uninstall removes it.
PENDING="${FLYWHEEL_DST}/PENDING-UPGRADES"
if [ -n "${OLD_VERSION}" ] && [ "${OLD_VERSION}" != "${PLUGIN_VERSION}" ]; then
  for f in "${SRC}"/upgrades/v*.md; do
    [ -f "${f}" ] || continue
    v="$(basename "${f}" .md)"; v="${v#v}"
    # keep OLD_VERSION < v <= PLUGIN_VERSION
    [ "${v}" = "${OLD_VERSION}" ] && continue
    [ "$(printf '%s\n%s\n' "${OLD_VERSION}" "${v}" | sort -V | head -1)" = "${OLD_VERSION}" ] || continue
    [ "$(printf '%s\n%s\n' "${v}" "${PLUGIN_VERSION}" | sort -V | head -1)" = "${v}" ] || continue
    grep -q '^requires-action: true$' "${f}" || continue
    echo "${v}" >> "${PENDING}"
  done
  if [ -f "${PENDING}" ]; then
    sort -uV -o "${PENDING}" "${PENDING}"
    echo "⚠️  pending upgrade strategies recorded in .claude/flywheel/PENDING-UPGRADES:"
    sed 's/^/     v/' "${PENDING}"
    echo "   run /flywheel:update to execute and clear them."
  fi
fi

# Preserve a previously vendored auto-update workflow across plain re-installs
# (the --auto-update choice is sticky; --uninstall still removes it).
if [ "${AUTO_UPDATE}" = 0 ] && in_manifest "${UPDATE_WORKFLOW_REL}" && [ -f "${TARGET}/${UPDATE_WORKFLOW_REL}" ]; then
  echo "${UPDATE_WORKFLOW_REL}" >> "${NEW_MANIFEST}"
fi

# Prune files a previous version vendored but this version no longer ships:
# anything listed in the OLD manifest and absent from the NEW one (and only
# that — never user files). Restore a .pre-flywheel backup when one exists.
if [ -f "${MANIFEST}" ]; then
  sort -u "${NEW_MANIFEST}" > "${NEW_MANIFEST}.sorted"
  while IFS= read -r rel; do
    if ! grep -qxF "${rel}" "${NEW_MANIFEST}.sorted"; then
      stale="${TARGET}/${rel}"
      if [ -f "${stale}.pre-flywheel" ]; then
        mv "${stale}.pre-flywheel" "${stale}"
        echo "pruned ${rel} (dropped by this version; pre-flywheel backup restored)"
      elif [ -e "${stale}" ]; then
        rm -f "${stale}"
        echo "pruned ${rel} (dropped by this version)"
      fi
      rmdir "$(dirname "${stale}")" 2>/dev/null || true
    fi
  done < "${MANIFEST}"
  rm -f "${NEW_MANIFEST}.sorted"
fi

sort -u "${NEW_MANIFEST}" > "${MANIFEST}"
rm -f "${NEW_MANIFEST}"

# Merge the SessionStart/PreToolUse/Stop hooks into the target's
# .claude/settings.json, keeping everything already there. Idempotent: entries
# are matched by their command string.
FW_SESSION_START="${SESSION_START_CMD}" FW_READ_PRIME="${READ_PRIME_CMD}" \
FW_WRITE_ALLOW="${WRITE_ALLOW_CMD}" FW_BASH_ALLOW="${BASH_ALLOW_CMD}" FW_GATE="${GATE_CMD}" \
FW_DELEGATION_GUARD="${DELEGATION_GUARD_CMD}" FW_DELEGATION_RECORD="${DELEGATION_RECORD_CMD}" \
FW_GIT_TRACKING_REFS="${GIT_TRACKING_REFS_CMD}" \
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
    ("PreToolUse", "Write|Edit|MultiEdit|NotebookEdit", {
        "type": "command",
        "command": os.environ["FW_WRITE_ALLOW"],
        "timeout": 5,
    }),
    ("PreToolUse", "Bash", {
        "type": "command",
        "command": os.environ["FW_BASH_ALLOW"],
        "timeout": 10,
    }),
    ("Stop", None, {
        "type": "command",
        "command": os.environ["FW_GATE"],
        "timeout": 300,
    }),
    ("PreToolUse", "mcp__.*__create_session|Agent|Task", {
        "type": "command",
        "command": os.environ["FW_DELEGATION_GUARD"],
        "timeout": 5,
    }),
    ("PostToolUse", "mcp__.*__create_session|Agent|Task", {
        "type": "command",
        "command": os.environ["FW_DELEGATION_RECORD"],
        "timeout": 5,
    }),
    ("SessionStart", None, {
        "type": "command",
        "command": os.environ["FW_GIT_TRACKING_REFS"],
        "timeout": 5,
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
