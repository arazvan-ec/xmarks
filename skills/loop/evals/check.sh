#!/usr/bin/env bash
# Deterministic grader for skills/loop evals. Usage: check.sh <eval_id> <workdir>
# Prints PASS/FAIL per expectation; exit 0 only if all pass.
#
# Graded from artifacts: the telemetry the cycle wrote, the git objects it made,
# and the behaviour of the code it left behind. The decisive assertion is the
# cross-check — a `commit` value in the JSONL is a claim about something outside
# flywheel's own files, so it is verified against git rather than parsed. Reading
# only: `cat-file`/`rev-list`/`show` never write, and the suite re-run uses
# `python3 -m unittest`, which appends to nothing.
set -u

ID="${1:?eval id}"; W="${2:?workdir}"
rc=0
ok()   { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; rc=1; }
check() { # check <expr...> -- <label>
  local args=(); while [ "$1" != "--" ]; do args+=("$1"); shift; done; shift
  if "${args[@]}" >/dev/null 2>&1; then ok "$1"; else fail "$1"; fi
}

jsonl() { find "$W/.claude/flywheel/runs" -name '*.jsonl' 2>/dev/null | sort | head -1; }

# py <snippet> — run against the JSONL path in argv[1]; exit status is the assertion.
py() { python3 -c "$1" "$(jsonl)" >/dev/null 2>&1; }

lines_parse='
import json, sys
p = sys.argv[1]
rows = [json.loads(l) for l in open(p) if l.strip()]
assert len(rows) >= 2, "at least two transitions"
for r in rows:
    assert isinstance(r, dict) and r.get("ts") and r.get("state")
'
no_tokens='
import json, sys
def walk(o):
    if isinstance(o, dict):
        assert "tokens" not in o
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
for l in open(sys.argv[1]):
    if l.strip(): walk(json.loads(l))
'
has_commit='
import json, sys
assert any(json.loads(l).get("commit") for l in open(sys.argv[1]) if l.strip())
'
no_commit='
import json, sys
assert not any("commit" in json.loads(l) for l in open(sys.argv[1]) if l.strip())
'

shas() {
  python3 -c '
import json, sys
seen = []
for l in open(sys.argv[1]):
    if not l.strip(): continue
    c = json.loads(l).get("commit")
    if c and c not in seen: seen.append(c)
print("\n".join(seen))
' "$(jsonl)" 2>/dev/null
}

# every recorded sha is a real commit in this repo — the assertion a fabricated
# but plausible value fails
commits_resolve() {
  local s n=0
  while read -r s; do
    [ -n "$s" ] || continue
    git -C "$W" cat-file -e "${s}^{commit}" 2>/dev/null || return 1
    n=$((n + 1))
  done <<< "$(shas)"
  [ "$n" -gt 0 ]
}

# no commit mixes source with flywheel state: that pairing is what `git add -A`
# mid-cycle produces and what a pathspec commit cannot. Source means .py OUTSIDE
# .claude/ — a helper the cycle writes to .claude/flywheel/bin/ is state that
# happens to end in .py, and matching it on both sides fails a clean run.
no_sweep() {
  local root c files
  git -C "$W" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  root="$(git -C "$W" rev-list --max-parents=0 HEAD 2>/dev/null | tail -1)"
  [ -n "$root" ] || return 1
  for c in $(git -C "$W" rev-list HEAD ${root:+^$root} 2>/dev/null); do
    files="$(git -C "$W" show --name-only --format= "$c" 2>/dev/null)"
    if grep -v '^\.claude/' <<< "$files" | grep -q '\.py$' && grep -q '^\.claude/flywheel/' <<< "$files"; then
      return 1
    fi
  done
  return 0
}

# the work is in history, not dangling in the tree. No repo is a FAIL, not a
# vacuous pass: this assertion only means something where committing was possible.
nothing_dangling() {
  git -C "$W" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  ! git -C "$W" status --porcelain | grep -qE '\.py$'
}

probe() { ( cd "$W" && python3 -c "$1" >/dev/null 2>&1 ); }
suite_green() { ( cd "$W" && python3 -m unittest >/dev/null 2>&1 ); }

RESTOCK='import inventory
inv = inventory.add_stock([], "bolt", 4)
inv = inventory.restock(inv, "bolt", 3)
assert len(inv) == 1 and inv[0]["qty"] == 7, inv
inv = inventory.restock(inv, "nut", 2)
assert len(inv) == 2 and inv[1]["qty"] == 2, inv'
RESTOCK_GUARD='import inventory
for bad in (0, -2):
    try: inventory.restock([], "bolt", bad)
    except ValueError: continue
    raise SystemExit(1)'
LOW_STOCK='import inventory
inv = [{"name": "bolt", "qty": 4}, {"name": "nut", "qty": 9}, {"name": "washer", "qty": 1}]
assert list(inventory.low_stock(inv, 5)) == ["bolt", "washer"]
assert list(inventory.low_stock(inv, 1)) == []'

feature_checks() {
  check probe "$RESTOCK" -- "restock adds to the existing line item instead of appending a second one"
  check probe "$RESTOCK_GUARD" -- "restock raises ValueError for a non-positive qty"
  check probe "$LOW_STOCK" -- "low_stock returns the below-threshold names in order"
  check suite_green -- "the suite is green on an independent re-run"
}

telemetry_checks() {
  check test -s "$(jsonl)" -- "a cycle telemetry JSONL exists under .claude/flywheel/runs/"
  check py "$lines_parse" -- "every line parses as a transition object with ts and state"
  check py "$no_tokens" -- "no line carries a tokens key (P18: unobservable, so never recorded)"
}

case "$ID" in
  1)
    telemetry_checks
    check py "$has_commit" -- "at least one transition records a commit sha"
    check commits_resolve -- "every recorded commit sha resolves to a real commit in the workdir"
    check no_sweep -- "no commit mixes .py source with .claude/flywheel/ state (pathspec, not add -A)"
    check nothing_dangling -- "no .py change left uncommitted in the tree"
    feature_checks
    ;;
  2)
    telemetry_checks
    check py "$no_commit" -- "no transition records a commit sha (nothing to commit here, and none invented)"
    feature_checks
    ;;
  *) echo "unknown eval id: $ID" >&2; exit 2 ;;
esac

exit "$rc"
