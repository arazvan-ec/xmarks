# Spec: P58 — templates for two steps that went wrong by hand

**Slug:** `p58-templates-for-repeated-steps` · **Created:** 2026-09-23 · **Backlog:** P58
**Status:** in progress

**Prime:** P57 (the delegated-review template) and the owner's ask to record the
practice and apply it to the two candidates the same session surfaced.

## R — Requirements

The practice, as agreed with the owner: a template for a repeated step is worth
having when (1) it comes from a real failure, (2) something checks it was used,
and (3) it is pointed to, never pasted. Two steps in this session failed by hand:

- **Eval executor prompt.** `fixture-scratch.sh work 1 --keep` and then
  `--print-prompt` as a second call created two scratch dirs. The printed
  prompt named a workdir that was torn down on exit, and two executors
  reported "no such directory" before doing anything.
- **Answering review findings on a PR.** Reproduce red, fix, reply on each
  thread naming the commit before pushing, push, resolve, skip echoes: done by
  hand from memory on PR #95.

1. **`--print-prompt` refuses a workdir it is about to delete**: without
   `--keep` or `--into`, it exits 2 and says why. A prompt naming a dir that
   will not exist is never printed.
2. **`--executor-prompt`** prints the eval prompt wrapped in the executor
   preamble (read `skills/<skill>/SKILL.md`, touch only the workdir, report
   briefly). It implies `--keep`, so the dir it names exists. The template is
   in the tool, so there is no second copy to drift.
3. **`skills/review/references/answering-review.md`**, cited from
   `/flywheel:review`'s gate step: the per-thread procedure for review
   findings on a PR.
4. **A ledger entry** recording the practice and its three conditions.

## Success metric

`bash scripts/test-fixture-scratch.sh` green with new arms: `--print-prompt`
without `--keep`/`--into` exits 2; `--executor-prompt` names an existing dir,
includes the SKILL.md path and the eval prompt. Invocation budget,
docs-consistency and the full sweep green.
