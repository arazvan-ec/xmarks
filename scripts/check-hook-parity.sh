#!/usr/bin/env bash
# flywheel — CI gate (P38): flywheel has two independently-wired hook delivery
# paths. An INSTALLED plugin gets its hooks from hooks/hooks.json; a VENDORED
# repo (the documented path for Claude Code on the web, which never installs
# marketplace plugins) is wired by scripts/install-vendored.sh, whose hook list
# is hand-maintained. v0.44.0 (2026-09) added delegation-guard.sh and
# delegation-record.sh to hooks.json and stopped there: a vendored repo would
# have refreshed to 0.44.0 with the guard neither copied nor registered —
# silently, because a hook that never fires is indistinguishable from one with
# nothing to warn about. Hotfixed by hand in v0.44.1. This gate is the fix for
# the root cause: nothing asserted the two wirings agree, so the next hook can
# hit the same trap.
#
# BEHAVIORAL, not textual: install-vendored.sh's bash variables and python
# heredoc are not statically parsed — that parser would be as fragile as the
# thing it guards. Instead the installer is actually run against a throwaway
# target repo, and what it registers there is compared against hooks/hooks.json
# as normalized (event, matcher, script-basename) triples, in both directions.
# Every script hooks.json names is also checked for actually landing in the
# target's .claude/flywheel/bin/, executable — a registration with no copied
# script is a distinct failure mode from a missing registration, and 0.44.0 had
# both.
#
# This proves the two wirings AGREE, not that either is correct.
#
# Usage: check-hook-parity.sh   (run from the repo root)
#   SKIP_HOOK_PARITY=1   skip with a logged notice, never silently
#
# Exit: 0 parity · 1 the wirings disagree, or a registered script did not land
#         in .claude/flywheel/bin/ · 2 unusable input (missing hooks.json or
#         installer, no python3, or the installer itself failed)

set -uo pipefail

if [ "${SKIP_HOOK_PARITY:-0}" = "1" ]; then
  echo "hook-parity: SKIPPED via SKIP_HOOK_PARITY=1"
  exit 0
fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_JSON="${SRC}/hooks/hooks.json"
INSTALLER="${SRC}/scripts/install-vendored.sh"

[ -f "${HOOKS_JSON}" ] || { echo "hook-parity: no ${HOOKS_JSON}" >&2; exit 2; }
[ -f "${INSTALLER}" ] || { echo "hook-parity: no ${INSTALLER}" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "hook-parity: python3 not found" >&2; exit 2; }

TARGET="$(mktemp -d)"
trap 'rm -rf "${TARGET}"' EXIT

if ! bash "${INSTALLER}" "${TARGET}" >"${TARGET}/.install.log" 2>&1; then
  echo "hook-parity: install-vendored.sh failed against a throwaway target — refusing to judge parity on a broken install" >&2
  cat "${TARGET}/.install.log" >&2
  exit 2
fi

SETTINGS="${TARGET}/.claude/settings.json"
[ -f "${SETTINGS}" ] || { echo "hook-parity: installer produced no ${SETTINGS}" >&2; exit 2; }

python3 - "${HOOKS_JSON}" "${SETTINGS}" "${TARGET}/.claude/flywheel/bin" <<'PY'
import json, os, sys

hooks_json_path, settings_path, bin_dir = sys.argv[1:4]

def die(msg, code=2):
    print(f"hook-parity: {msg}", file=sys.stderr)
    sys.exit(code)

def load_hooks(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        die(f"{path} is not readable JSON: {e}")
    return data.get("hooks", {})

# (event, matcher-or-"", basename-of-the-.sh-command) — the unit both wirings
# must agree on. Basename, not full path: the two paths are legitimately
# different (${CLAUDE_PLUGIN_ROOT}/scripts/ vs .claude/flywheel/bin/).
def triples(hooks_by_event):
    out = set()
    for event, groups in hooks_by_event.items():
        for g in groups:
            matcher = g.get("matcher") or ""
            for h in g.get("hooks", []):
                cmd = h.get("command", "")
                if cmd.endswith(".sh"):
                    out.add((event, matcher, os.path.basename(cmd)))
    return out

hooks_json = triples(load_hooks(hooks_json_path))
installed = triples(load_hooks(settings_path))

if not hooks_json:
    die(f"no .sh hook commands found in {hooks_json_path} — refusing a vacuous pass")

def fmt(t):
    event, matcher, name = t
    return f"{event}/{matcher or '(no matcher)'} -> {name}"

missing_in_installer = sorted(hooks_json - installed)
extra_in_installer = sorted(installed - hooks_json)

rc = 0
for t in missing_in_installer:
    print(f"hook-parity: hooks.json registers {fmt(t)}, but install-vendored.sh does not register it", file=sys.stderr)
    rc = 1
for t in extra_in_installer:
    print(f"hook-parity: install-vendored.sh registers {fmt(t)}, but hooks.json does not register it", file=sys.stderr)
    rc = 1

# Registration and landing are checked separately: a script hooks.json names
# can be registered by the installer while never having been copied into bin/.
not_landed = []
for _, _, name in sorted({(e, m, n) for e, m, n in hooks_json}):
    path = os.path.join(bin_dir, name)
    if not (os.path.isfile(path) and os.access(path, os.X_OK)):
        not_landed.append(name)
for name in not_landed:
    print(f"hook-parity: hooks.json names {name}, but it is not an executable file in {bin_dir}", file=sys.stderr)
    rc = 1

if rc == 0:
    print(f"hook-parity: OK — {len(hooks_json)} hook registration(s) agree, all landed in {bin_dir}")
sys.exit(rc)
PY
