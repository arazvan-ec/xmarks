---
name: verify
description: Objective PASS/FAIL gate — run the app and the test suite against the spec's success metric, with evidence. Use before review/ship, or to confirm a change really works rather than assuming it does.
context: fork
agent: verifier
argument-hint: "[what to verify / spec-slug]"
allowed-tools: Bash, Read, Grep, Glob
---

# /flywheel:verify — objective gate

You are the verification gate for: **$ARGUMENTS**

Load the spec's **Success metric** from `.claude/flywheel/specs/` if available. Then gather objective evidence:

1. Run the full test suite. Capture pass/fail counts and any failures. If the project defines an executable `.claude/flywheel/gate.sh` (the opt-in Stop-hook gate), run **that** as the suite command — it is the project's own definition of green, and running it here lets step 5 make the Stop hook's re-run free.
2. Run the linter / type-checker / formatter check (skip what the project gate already ran).
3. Build the project if it has a build.
4. If the change is user-visible, **run the real thing** and observe actual behavior against the metric (start the server and hit it, run the CLI, execute the import and count rows, etc.).
5. **Seal on PASS** — only if the verdict is PASS *and* you ran the project's own `.claude/flywheel/gate.sh` green in step 1: run `gate.sh seal` from flywheel's scripts (`"${CLAUDE_PLUGIN_ROOT}/scripts/gate.sh" seal` on a marketplace install, `.claude/flywheel/bin/gate.sh seal` on a vendored one). It records the current tree as passed so the Stop hook doesn't re-run the same suite minutes later. Fail-open: if the script isn't found or seal refuses (untrusted gate), skip silently — the hook will just re-run.

Then emit a verdict:
- **PASS** — only if the success metric is objectively met. Include the evidence (commands run, exit codes, key output).
- **FAIL** — otherwise. State exactly what failed and the smallest signal that would flip it to PASS.

Do not rationalize a FAIL into a PASS. A phase does not advance on a FAIL. Make the verdict the last line: `VERDICT: PASS` or `VERDICT: FAIL — <reason>`.
