# Applying upgrade strategies

Reference for `/flywheel:update` §2 step 4. Read this before acting on a
version range: the body states the rule, this states the procedure.

   - In the xmarks checkout, list `upgrades/v*.md` and select the notes in the range **(old version, new version]** (compare with `sort -V`; if the old version is unknown, take every note up to the new version).
   - Read each selected note. For notes with `requires-action: true`, execute the steps in its **Strategy** section here in this repo. Strategies are written to be idempotent and verifiable — check each step's "already done" condition before acting, and if a step cannot be automated (e.g. a GitHub UI setting), tell the user exactly what to do instead of skipping it silently.
   - Log what you applied: append a dated entry per executed strategy to `.claude/flywheel/UPGRADES.md` (create it with a `# flywheel upgrades applied` header if missing). Check this log first — a strategy already logged does not need to run again.
   - Clear the pending marker: the installer records unapplied `requires-action` versions in `.claude/flywheel/PENDING-UPGRADES` (one per line — the SessionStart hook nags on it every session). After executing and logging a version's strategy, delete its line; delete the file when no lines remain. Also delete lines whose strategy `UPGRADES.md` shows as already applied.
   - **Fallback when notes are missing** (updating from a pre-0.8.0 vendor): read the old `source-commit` from the pre-refresh VERSION content and analyze `git -C <xmarks> diff <old-commit>..HEAD -- skills agents scripts hooks` yourself; decide whether anything beyond the file refresh is needed and act accordingly.
