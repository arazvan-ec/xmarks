#!/usr/bin/env bash
# Irreducibly imperative, and for a load-bearing reason. This grader's decisive
# assertion is that every `commit` in the telemetry resolves via
# `git cat-file -e <sha>^{commit}` — so a sha committed to an asset would be, by
# definition, a sha nobody made in this workdir: byte-indistinguishable from the
# `fabricated-sha` cheat the same grader is tested against. The shas have to be
# made here.
#
# The sequence is equally irreducible: commit 1 must hold only the restock
# append and commit 2 only low_stock, which an overlay can never express — it
# can only state an end result. So the *content* of each step is a reviewable
# patch under steps/ and only the git ceremony is script. steps/ rather than
# patch/ because fixture-scratch.sh applies patch/ itself, which would apply
# each of these twice.
#
# No `git init`: eval 1's own `setup` in evals.json does that, and eval 2
# deliberately does not. Instantiation belongs to the eval, not to the solution.
#
# Statuses are checked explicitly. `set -e` does not abort a failure inside the
# command substitution this function is called from — a first draft relied on it
# and produced a `commit` field containing git's "nothing to commit" chatter,
# and still exited 0.
set -u
W="${1:?workdir}"
HERE="$(cd "$(dirname "$0")" && pwd)"
g=(git -C "${W}" -c user.email=e@e -c user.name=e)

die() { echo "inventory-ideal: $*" >&2; exit 1; }

commit_step() { # commit_step <patch> <message> -> prints the new sha
  "${g[@]}" apply --whitespace=nowarn -p1 "${HERE}/$1" || die "$1 does not apply"
  # A pathspec commit, never `add -A`: the grader rejects a commit mixing .py
  # source with .claude/flywheel/ state, which is what a sweep produces.
  "${g[@]}" commit -q -m "$2" -- inventory.py || die "$1: nothing was committed"
  "${g[@]}" rev-parse HEAD || die "$1: no HEAD to record"
}

c1="$(commit_step steps/01-restock.patch 'Add restock')" || exit 1
c2="$(commit_step steps/02-low-stock.patch 'Add low_stock')" || exit 1
case "${c1}${c2}" in *[!0-9a-f]*) die "captured a non-sha: c1=${c1} c2=${c2}" ;; esac
[ "${c1}" != "${c2}" ] || die "both tasks recorded the same commit"

mkdir -p "${W}/.claude/flywheel/runs/stock-levels"
{ printf '{"ts":"2026-09-09T10:00:00Z","phase":"spec","state":"done"}\n'
  printf '{"ts":"2026-09-09T10:05:00Z","task":"T1","state":"green","commit":"%s"}\n' "${c1}"
  printf '{"ts":"2026-09-09T10:09:00Z","task":"T2","state":"green","commit":"%s"}\n' "${c2}"
} > "${W}/.claude/flywheel/runs/stock-levels/2026-09-09.jsonl"
