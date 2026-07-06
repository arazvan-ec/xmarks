# Upgrade notes — AI-authored migration strategies

Refreshing vendored files is not always enough: a new flywheel version can require
**action in the target repo** beyond copying files (enable a GitHub setting, adopt a new
config key, migrate ledger state). This directory closes that gap.

## The process

1. **At release time (in this repo):** the AI preparing a version bump analyzes the diff
   since the previous version (`git diff v<prev>..HEAD -- skills agents scripts hooks
   .claude-plugin`) and writes `upgrades/v<version>.md` answering one question: *does an
   installed repo need to do anything beyond re-vendoring — and if so, exactly what?*
   CI **fails** if `plugin.json`'s version has no matching note, so no release ships
   without this analysis. A "nothing to do" note is a valid (and common) outcome.

2. **At update time (in the target repo):** `/flywheel:update` reads every note in the
   range `(installed version, new version]` and **executes** the strategies whose
   `requires-action` is true, then logs what it applied to
   `.claude/flywheel/UPGRADES.md` in the target repo. The auto-update workflow includes
   the same notes in its PR body so humans see them too.

## Note format

One file per released version, named `v<version>.md`:

```markdown
---
version: 0.8.0
requires-action: true | false
summary: One line a human can read in a PR body.
---

## What changed
Short, factual list of the changes that matter to installed repos.

## Strategy
Only when requires-action is true. Ordered steps written FOR THE UPDATING AI to
execute in the target repo. Each step must be:
- **idempotent** — safe to run when already applied;
- **verifiable** — state the check that tells whether it is already done;
- **scoped** — touch only the target repo (never this one), and ask the user
  before anything destructive or outward-facing.
```

Keep strategies honest: if a step can't be automated (e.g. flipping a GitHub repo
setting needs admin UI), say so explicitly and instruct the AI to tell the user instead
of silently skipping.
