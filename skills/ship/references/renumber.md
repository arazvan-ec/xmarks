# Renumber: the base took your version or your P-number

Reached when merging the base into the branch reddens the release gate
(`check-release-bump.sh`: version not ahead of the base), or when the base
added a backlog row with your P-number. The script does the mechanics; you
classify what it cannot. The script is `bash scripts/renumber.sh` inside
flywheel, `bash "${CLAUDE_PLUGIN_ROOT}/scripts/renumber.sh"` on a marketplace install.

## A version

1. Pick `<new>`: the base's version plus one minor, unless the owner pre-assigned one.
2. `bash scripts/renumber.sh <old> <new>` — moves `upgrades/v<old>.md` and every
   `*-v<old>` dir, rewrites the note's frontmatter and `plugin.json`. It refuses a
   `<new>` not ahead of the base or already taken; pick again, never force it.
3. Add a `Renumbered from v<old>: the base took it with <what>.` line to the note.
4. `bash scripts/renumber.sh --check <old>` lists every leftover `<old>` in files
   the branch touches as `file:line`. Classify **each** one:

   | It is a **pointer** — fix it to `<new>` | It is **history** — keep it |
   |---|---|
   | a link or path to `upgrades/v<old>.md` | journal prose narrating what happened |
   | `see` / `read` / `follow` before a version | a decision-log entry dated before the renumber |
   | a workflow message, `::error::` remedy, or comment saying what this release does | a LEARNINGS evidence field |
   | a spec **Status** line, a plan title, a backlog cell | a quoted command output |
   | a `*-v<old>` path the mechanics did not own | |

   Keep history by appending `<!-- renumber: keep -->` to the line. In doubt, it
   is a pointer: a stale pointer ships a lie (#81 shipped three, one inside the
   refusal message a third-party repo reads); a fixed history line costs nothing.
5. Re-run `--check` until it exits 0, then the release gate.

## A P-number

1. Pick the next free P: one above the highest `P<n>` heading or row in
   `docs/research/improvement-proposals.md` on the merged tree.
2. Move, by hand, its heading, its backlog row, its spec slug (`git mv` the spec,
   plan and runs dir — the runs *lines* stay as written), and every citation.
3. `bash scripts/renumber.sh --check P<old>` and classify as above. A row that
   belongs to the base's own `P<old>` is not yours: keep-mark it.

## Done when

`--check` exits 0, and so does `check-release-bump.sh` against the base. The
script cannot see files the branch did not touch: a stale pointer there is
`check-version-citations.sh`'s job.
