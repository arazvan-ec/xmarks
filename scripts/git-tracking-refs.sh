#!/usr/bin/env bash
# flywheel — SessionStart hook: make `git push -u` produce a tracking ref.
#
# An agent session's repo arrives as `git clone --depth 1`, which implies
# --single-branch and leaves a narrow fetch refspec:
#
#     +refs/heads/main:refs/remotes/origin/main
#
# Push a NEW branch from such a clone and git stores branch.<n>.remote and
# branch.<n>.merge, but creates no `refs/remotes/origin/<n>` — the refspec maps
# nothing to it. `@{u}` then fails to resolve, and every tool that reads it
# concludes the branch was never pushed. It is a lie with a convincing shape:
# the commits ARE on the remote. Seen three times on 2026-09-13, once in a
# session that diagnosed it independently, each costing minutes and a false
# "N unpushed commits" warning that invites a pointless re-push.
#
# Contract: this hook MUTATES ONE LINE of the repo's LOCAL git config
# (`remote.origin.fetch`) and nothing else — never the working tree, never
# history, never a ref's content, never the remote. The value it writes is the
# one a plain `git clone` would have given. Reversible with one command:
#
#     git config --replace-all remote.origin.fetch '+refs/heads/<branch>:refs/remotes/origin/<branch>'
#
# It acts ONLY on a clone that is BOTH shallow and single-branch — the agent
# clone's signature. A deliberate `--single-branch` full clone is left alone:
# there the narrow refspec is a choice about fetch cost, not an accident.
# `FLYWHEEL_NO_REFSPEC_FIX=1` opts out entirely.
#
# Fail-open: no git, no repo, no `origin`, a customized multi-refspec remote or
# any error at all and it prints nothing and exits 0. A session must never fail
# to start because of this.

[ "${FLYWHEEL_NO_REFSPEC_FIX:-0}" = "1" ] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
command -v git >/dev/null 2>&1 || exit 0
cd "${PROJECT_DIR}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Only the agent-clone signature: shallow AND single-branch.
[ -f "$(git rev-parse --git-dir 2>/dev/null)/shallow" ] || exit 0

# Exactly one fetch refspec. More than one means someone configured this remote
# on purpose, and a hook has no business rewriting that.
COUNT="$(git config --get-all remote.origin.fetch 2>/dev/null | grep -c . || true)"
[ "${COUNT}" = "1" ] || exit 0

CURRENT="$(git config --get remote.origin.fetch 2>/dev/null || true)"
case "${CURRENT}" in
  # Already general — nothing to do. This is what makes the hook idempotent.
  *'refs/heads/*'*) exit 0 ;;
  # The single-branch form written by --depth/--single-branch.
  +refs/heads/*:refs/remotes/origin/*) : ;;
  *) exit 0 ;;
esac

WIDE='+refs/heads/*:refs/remotes/origin/*'
git config --replace-all remote.origin.fetch "${WIDE}" 2>/dev/null || exit 0

echo "🔗 flywheel: widened this shallow clone's fetch refspec to ${WIDE}"
echo "   (was ${CURRENT} — a single-branch clone never creates refs/remotes/origin/<new-branch>,"
echo "    so \`git push -u\` left \`@{u}\` unresolvable and tools reported pushed work as unpushed)."
exit 0
