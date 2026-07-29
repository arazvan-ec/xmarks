---
name: brainstorm
description: Sharpen a vague or fuzzy idea into agreed requirements — key questions, 2–3 approaches with trade-offs, converge on scope. Use before /flywheel:spec when the idea isn't clear yet.
argument-hint: "[rough idea]"
allowed-tools: Read, Grep, Glob
---

# /flywheel:brainstorm — sharpen a fuzzy idea before spec

Rough idea: **$ARGUMENTS**

The goal is clarity, fast — not a document. Do this conversationally:

1. **Restate** the goal in one sentence and confirm it is what the user means.
2. **Ask the few questions that matter most** (3–5): who it is for, the must-haves vs. nice-to-haves, hard constraints, and what "done / good" looks like. Skip questions whose answers you can reasonably assume — state the assumption instead.
3. **Sketch 2–3 approaches**, each with its main trade-off, and recommend one.
4. **Converge:** agree explicitly on what is in scope and what is out for the first cut.
5. **Hand off:** when the shape is clear, move to `/flywheel:spec` to turn it into a REASONS contract with a success metric.

Keep it tight. If the idea is already clear, say so and go straight to `/flywheel:spec`.
