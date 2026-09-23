# Spec: P59 — a renumber is performed, not remembered

**Slug:** `p59-a-renumber-is-performed` · **Created:** 2026-09-23 · **Backlog:** P59
**Status:** spec + plan committed, not built. It builds after P60, and its release check uses `sweep.sh`.

**Prime:** `docs/research/template-opportunities-2026-09.md` § P59, and the owner's
decision (2026-09-23): the script does the mechanics, the AI classifies what needs
judgment through a short template, and the script checks that nothing was left
unclassified.

## R — Requirements

About 11 version collisions have been renumbered by hand, across up to 7 sites each
(journal.md:178, :213; aebafb4, 3d1dd19, dcb77f8). The renumber in #81 shipped three
stale `0.59.0` pointers, one of them inside an `::error::` remedy. P-numbers collide
too: the backlog table carries two P55 rows and two P56 rows. `check-release-bump.sh`
detects a collision, but nothing performs the renumber. A bare mention of a version is
free by design (P47), so whether a leftover `<old>` token is a pointer or history is a
judgment call.

1. **`scripts/renumber.sh <old> <new>` does the mechanics.** It `git mv`s
   `upgrades/v<old>.md` and every `*-v<old>` dir, then rewrites the note's frontmatter
   `version:` and the `version` in `plugin.json`. It refuses when `<new>` is not ahead
   of the base, and when `upgrades/v<new>.md` already exists.
2. **The same script lists what is left, with `--check`.** It lists every `<old>` token
   in files this branch touches against the base, as `file:line`. It exempts
   `.claude/flywheel/runs/**` (immutable) and lines carrying `Renumbered from`. It exits
   1 while any token is not classified.
3. **Classification is a marker that the check can read.** Two forms count:
   - a pointer is fixed, so the token is gone;
   - history is kept by adding `<!-- renumber: keep -->` on the line, or a
     `Renumbered from v<old>` line in the note.

   Nothing else counts, so the AI cannot skip a site.
4. **`skills/ship/references/renumber.md`** is the template for the judgment part. It
   says how to tell a pointer (a link, `see`/`read`, a workflow message, a Status line,
   a backlog cell) from history (journal prose, a decision log). It covers the
   P-number variant (pick the next free P, then move its heading, row, spec slug and
   citations), and says to finish when `--check` exits 0. `/flywheel:ship` cites it
   at the step where `main` is merged and the release gate reddens.

## Success metric

`bash scripts/test-renumber.sh` passes on a fixture repo with these arms:
- the mechanics move the note, its frontmatter, `plugin.json` and a `*-v<old>` dir;
- `--check` exits 1 listing an unfixed pointer in a touched file;
- `--check` exits 0 after a fix, and exits 0 on a `keep` marker;
- a token in `runs/` or on a `Renumbered from` line is never listed;
- a `<new>` that is not ahead of the base is refused.

A replay of the #81 case, the fixture tree with `flywheel-update.yml` pointers, has
`--check` naming all three stale pointers. The invocation budget stays green with the
citation from `ship`.

## Safeguards

- It is not a process contract: there is too little judgment for one (owner decision).
- What it cannot see: files the branch did not touch. A stale pointer in an untouched
  file is still `check-version-citations.sh`'s job.
