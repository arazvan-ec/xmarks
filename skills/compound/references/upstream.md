# Sending a lesson about flywheel upstream (P70)

An entry is **about flywheel** when it names a part of the plugin (a skill, a
hook, a script, a gate, the installer, the plan or run format, the `DATA.md`
template) or the loop's own behaviour, rather than the repo's domain. Those
lessons strand in the repo that learned them unless they are sent on.

In flywheel's own repo, skip this: the ledger is already upstream (the script
exits 3).

1. Render the entry as a prefilled issue:
   `bash .claude/flywheel/bin/upstream-issue.sh "<title words>"` on a vendored
   install, `bash "${CLAUDE_PLUGIN_ROOT}/scripts/upstream-issue.sh" "<title words>"`
   on a marketplace one. It keeps only flywheel paths in `files`, marks a
   missing `evidence=` as `unverified`, and truncates long prose.
2. Before showing it, reread the prose for anything private to this repo:
   customer names, internal hosts, credentials, business detail. If there is
   any, rewrite the entry in general terms first. The upstream repo is public.
3. Give the owner the URL. Opening it shows the filled form, and nothing is
   sent until they submit it.
4. If this session has GitHub write access to the upstream repo, you may offer
   to open the issue yourself. Show the exact title and body, and create it only
   after an explicit yes. Never create it unasked.
5. Add `"upstream": <N offered>` to the `phase: compound` line.
