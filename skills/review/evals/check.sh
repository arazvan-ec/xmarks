#!/usr/bin/env bash
# Deterministic grader for skills/review evals. Usage: check.sh <eval_id> <workdir>
# Prints PASS/FAIL per expectation; exit 0 only if all pass.
#
# SCOPE, and it is narrower than the skill: `Task` does not exist inside a
# subagent, so no executor this repo runs ever dispatches `reviewer-*`. What is
# graded here is (a) which reviewers the run DREW — read from .dispatch-log, the
# artifact the fixture's shim writes, never from the report's prose about its own
# routing — and (b) whether the report SAYS the specialists did not actually run.
# Dispatch itself has one arm and it is manual: evals/README.md, "The top-level
# arm (Option A)".
#
# Reading only: grep and python3 over two files the executor left behind.
set -u

ID="${1:?eval id}"; W="${2:?workdir}"
R="${FW_EVAL_REPORT:-$W/review.md}"
D="${FW_EVAL_DISPATCH:-$W/.dispatch-log}"
rc=0
ok()   { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; rc=1; }
check() { # check <expr...> -- <label>
  local args=(); while [ "$1" != "--" ]; do args+=("$1"); shift; done; shift
  if "${args[@]}" >/dev/null 2>&1; then ok "$1"; else fail "$1"; fi
}

# An absent artifact must fail by name: a grader that passes on absence reads as
# evidence while proving nothing.
have() { # have <path> <label>
  [ -s "$1" ] && return 0
  fail "$2 exists and is non-empty ($1 missing or empty)"
  return 1
}

# --- routing: the artifact, not the prose --------------------------------------
# A lens counts as drawn when its name appears in .dispatch-log, however the run
# spelled the call: `reviewer-security`, `security`, `Task(reviewer-security)`.
# The name is the whole assertion — nothing here reads what the reviewer said,
# because nothing ran.
drew() { grep -qiE "$1" "$D"; }
drew_correctness() { drew 'correct'; }
drew_security()    { drew 'security|sec\b'; }
drew_performance() { drew 'perf'; }
skipped_security()    { ! drew_security; }
skipped_performance() { ! drew_performance; }

# --- Option B: the honesty of the fallback -------------------------------------
# The defect is SILENCE — a report that reads as if three specialists reviewed in
# parallel when one context reviewed everything inline. The wording is the run's
# choice, so this is an alternation over two groups matched within one window:
# something naming the dispatch machinery, near something saying it did not
# happen. v0.40.1 and v0.41.0 both mechanized a property as ONE surface form and
# reddened correct runs; scripts/test-eval-graders.sh carries a spelling battery
# against this pattern for exactly that reason.
#
# Deliberately NOT in group B, each for a measured reason:
#   "fallback"/"stub"  — ops-console-repo's diff adds a hardcoded *fallback*
#                        token, so every report on evals 2-3 would match it.
#   "one reviewer"     — it contains group A ("reviewer") itself, so it matches
#                        its own window; and SKILL.md's small-diff rule says
#                        "one reviewer with a combined lens", which a routing
#                        paragraph may quote while claiming a fan-out elsewhere.
#   "no <role>"        — "no performance reviewer was drawn" is a ROUTING
#                        sentence, and a report may say it while still implying
#                        the two it did draw ran in parallel.
# Each would have made the assertion vacuously green — the hollow-grader failure
# P26 exists to catch.
DISCLOSED='
import re, sys
A = r"dispatch\w*|specialist\w*|sub-?agent\w*|\bagents?\b|task tool|\bTask\b|fan-?out|in parallel|reviewer-\w+|\breviewers?\b"
B = (r"unavailab\w*|not available|isn.t available|in-?line|in this context|in one context|"
     r"same context|single context|one context|did not (actually )?(run|execute|happen)|"
     r"were not (actually )?(run|dispatched|spawned|launched)|was not (actually )?(run|dispatched|spawned|launched)|"
     r"not (actually )?(run|dispatched|spawned|launched)|never (ran|run|dispatched)|no findings|"
     r"returned nothing|could not|couldn.t|cannot|can.t|simulat\w*|sequential\w*|"
     r"only recorded|recorded only|records the request|no separate|no real|no actual|"
     r"\bmyself\b|\bby me\b|on my own|no sub-?agent|no specialist|"
     r"without (a |any )?(sub-?agent|specialist|fan-?out|dispatch)|"
     r"never (ran|run|dispatched|launched|spawned)")
text = re.sub(r"\s+", " ", open(sys.argv[1], encoding="utf-8", errors="replace").read())
pat = re.compile(r"(?:%s).{0,160}?(?:%s)|(?:%s).{0,160}?(?:%s)" % (A, B, B, A), re.I)
sys.exit(0 if pat.search(text) else 1)
'
disclosed() { python3 -c "$DISCLOSED" "$R" >/dev/null 2>&1; }

# --- eval 1: the skips are stated ---------------------------------------------
# "always state which reviewers you skipped and the rule that skipped them (a
# silent cap reads as full coverage)" — SKILL.md. The names are read, not the
# sentence around them.
names_skipped_lenses() { grep -qi 'security' "$R" && grep -qi 'perf' "$R"; }

# --- eval 2: the review found the planted defect ------------------------------
# A suite that grades routing and never asks whether the review saw anything is
# hollow. Both halves are broad on purpose: the file is named by path, the defect
# by class rather than by wording.
cites_changed_file() { grep -qE 'app\.py|store\.py' "$R"; }
names_the_class() {
  grep -qiE 'inject|sqli|interpolat|concaten|unparameter|parameteri[sz]|sanitis|sanitiz|escap|f-string|hard-?cod|credential|secret' "$R"
}

case "$ID" in
  1)
    if have "$R" "review.md"; then
      check names_skipped_lenses -- "the report names both lenses it skipped (a silent cap reads as full coverage)"
    fi
    if have "$D" ".dispatch-log"; then
      check drew_correctness -- "a correctness reviewer was drawn"
      check skipped_security -- "no security reviewer was drawn — the diff touches no input handling, auth, secrets or dependencies"
      check skipped_performance -- "no performance reviewer was drawn — the diff touches no loops, queries, I/O or data volume"
    fi
    ;;
  2)
    if have "$R" "review.md"; then
      check cites_changed_file -- "the report cites the changed file (app.py or store.py)"
      check names_the_class -- "the report names the class of defect (injection / interpolation / unparameterized SQL / hardcoded credential)"
      check disclosed -- "the report says the specialists did not actually run (Option B)"
    fi
    if have "$D" ".dispatch-log"; then
      check drew_security -- "a security reviewer was drawn — the diff touches input handling, secrets and auth"
      check drew_correctness -- "a correctness reviewer was drawn"
    fi
    ;;
  3)
    if have "$R" "review.md"; then
      check disclosed -- "the report says the specialists did not actually run (Option B)"
    fi
    if have "$D" ".dispatch-log"; then
      check drew_correctness -- "a correctness reviewer was drawn"
      check drew_security -- "a security reviewer was drawn — input handling and a new dependency"
      check drew_performance -- "a performance reviewer was drawn — a query and an HTTP POST per row inside a loop"
    fi
    ;;
  *) echo "unknown eval id: $ID" >&2; exit 2 ;;
esac

exit "$rc"
