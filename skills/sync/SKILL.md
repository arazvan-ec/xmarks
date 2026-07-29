---
name: sync
description: Detect and reconcile spec↔code drift — code the spec doesn't reflect, spec items not implemented — then fix whichever is wrong, with confirmation. Use after code has evolved past its original spec.
argument-hint: "[spec-slug]"
allowed-tools: Read, Grep, Glob, Edit
---

# /flywheel:sync — bidirectional spec↔code reconciliation

Load the spec at `.claude/flywheel/specs/$ARGUMENTS.md` (or the most recent). Then compare it to the current code:

1. **Code → spec drift**: entities, fields, operations, or files that exist in the code but are not reflected in the spec's Entities / Operations / Structure.
2. **Spec → code gaps**: items the spec promises that are not implemented, or that diverge from the described Approach/Structure.
3. **Permission drift** (P21): a signed spec whose Success metric names a command — or a signed process contract whose DATA.md Access names one — with no matching `Bash(…)` rule in the project's `.claude/settings.json` `permissions.allow` (typically pre-P21 sign-offs).

Report both lists. Then reconcile:
- For **code → spec drift** that is intended: update the spec to match reality (the spec is a living contract). Show the diff and get confirmation before writing.
- For **spec → code gaps**: flag them as unfinished work — candidates for a new `/flywheel:plan` → `/flywheel:work` pass. Do not silently delete spec items.
- For **permission drift**: offer to add the missing rule — same consent flow as at sign-off, never written unasked.

Principle (SPDD): when reality and the spec disagree, decide deliberately which one is right and fix *that* one — never let them drift apart silently.
