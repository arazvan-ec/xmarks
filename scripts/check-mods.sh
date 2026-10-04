#!/usr/bin/env bash
# flywheel — CI gate (P72): every mod under mods/<name>/ is a plugin of its own,
# listed in the marketplace, test-first, validated and tested by the engine, and
# a change to it moves its own version ahead of the base's.
#
# Mods are separate plugins, not modules in flywheel's hooks.json, because some
# deny tools: each must be opt-in and versioned on its own (P72 T0 gate).
#
# Usage: check-mods.sh [base-ref] [mod ...]   (base default origin/main)
#   CLAUDE         the CLI to run (default: claude); absent → engine steps SKIPPED
#   SKIP_MOD_BUMP  <reason> waives the version rule, logged; a bare 1 is refused
#
# Exit: 0 ok · 1 a mod fails · 2 unusable input

set -uo pipefail

BASE="${1:-origin/main}"; shift || true
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "check-mods: not a git repo" >&2; exit 2; }
cd "${ROOT}" || exit 2
command -v python3 >/dev/null || { echo "check-mods: python3 required" >&2; exit 2; }

python3 - "${BASE}" "$@" <<'EOF' || exit $?
import json, os, subprocess, sys

base, named = sys.argv[1], sys.argv[2:]
cli = os.environ.get("CLAUDE", "claude")
skip = os.environ.get("SKIP_MOD_BUMP")
errors = []

def git(*a):
    r = subprocess.run(["git", *a], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None

listed = set()
try:
    for p in json.load(open(".claude-plugin/marketplace.json")).get("plugins", []):
        src = p.get("source", "")
        if isinstance(src, str) and src.startswith("./mods/"):
            listed.add(src[len("./mods/"):].rstrip("/"))
except FileNotFoundError:
    pass

present = {d for d in (os.listdir("mods") if os.path.isdir("mods") else [])
           if os.path.isdir(os.path.join("mods", d))}
for n in named:
    if n not in present:
        errors.append(f"{n}: no mods/{n}/")
scope = set(named) & present if named else present | listed
if not scope and not errors:
    print("check-mods: no mods")
    sys.exit(0)

def version(text):
    try:
        return tuple(int(x) for x in json.loads(text)["version"].split("."))
    except Exception:
        return None

base_ok = git("rev-parse", "--verify", "-q", base) is not None
mb = (git("merge-base", base, "HEAD") or "").strip() if base_ok else ""
if skip == "1" or skip == "":
    print("check-mods: SKIP_MOD_BUMP needs a reason, not '1'", file=sys.stderr)
    sys.exit(2)

for n in sorted(scope):
    d = f"mods/{n}"
    if n not in present:
        errors.append(f"{n}: listed in marketplace.json but {d}/ does not exist")
        continue
    if n not in listed:
        errors.append(f"{n}: {d}/ is not listed in .claude-plugin/marketplace.json (source ./{d})")
    for f in (".claude-plugin/plugin.json", "hooks/hooks.json"):
        if not os.path.isfile(f"{d}/{f}"):
            errors.append(f"{n}: missing {d}/{f}")
    tests = [f for _, _, fs in os.walk(d) for f in fs if f.endswith(".test.ts")]
    if not tests:
        errors.append(f"{n}: no *.test.ts — a mod is test-first")
    if not base_ok or not mb:
        print(f"check-mods: {n}: base {base} not found, version rule not checked")
        continue
    changed = (git("diff", "--name-only", mb, "--", d) or "") + (git("ls-files", "--others", "--exclude-standard", d) or "")
    old = git("show", f"{base}:{d}/.claude-plugin/plugin.json")
    if not changed.strip() or old is None:
        continue
    ov = version(old)
    try:
        nv = version(open(f"{d}/.claude-plugin/plugin.json").read())
    except FileNotFoundError:
        nv = None
    if ov and nv and nv > ov:
        continue
    if skip:
        print(f"check-mods: {n}: version rule waived — SKIP_MOD_BUMP: {skip}")
        continue
    shown = ".".join(map(str, nv)) if nv else "?"
    errors.append(f"{n}: changed since {base} but its version {shown} is not ahead of {'.'.join(map(str, ov or ()))}")

have_cli = subprocess.run(["sh", "-c", f'command -v "{cli}"'], capture_output=True).returncode == 0
for n in sorted(scope & present):
    d = f"mods/{n}"
    if not have_cli:
        print(f"SKIPPED {n}: plugin validate / plugin test (no {cli} CLI)")
        continue
    for step, argv in (("validate", [cli, "plugin", "validate", d, "--strict"]), ("test", [cli, "plugin", "test", d])):
        r = subprocess.run(argv, capture_output=True, text=True)
        sys.stdout.write(r.stdout)
        if r.returncode != 0:
            sys.stdout.write(r.stderr)
            errors.append(f"{n}: plugin {step} failed (exit {r.returncode})")

if errors:
    print("check-mods: FAIL", file=sys.stderr)
    for e in errors:
        print(f"  {e}", file=sys.stderr)
    sys.exit(1)
print(f"check-mods: {len(scope)} mod(s) OK")
EOF
