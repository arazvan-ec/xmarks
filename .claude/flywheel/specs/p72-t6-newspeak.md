# P72 T6 — Newspeak

**Status:** signed 2026-10-04 (autonomous run).

## R — Requirements

CLAUDE.md: "an item written as a bare verb can be done confidently in the wrong
direction; one written with a success criterion cannot. Ask for the criterion
when the item is worth the round trip." Make the gap visible when a list arrives:

- for an idle prompt carrying a list (Memory Hole's trigger: 2+ numbered or 3+
  bullets, fences stripped), each item is checked for a success criterion: a
  marker in English or Spanish (`so that`, `until`, `must`, `should`, `passes`,
  `returns`, `green`, `→`, `=`, a number with a unit, `para que`, `hasta que`,
  `debe`, `que pase`, `en verde`…);
- items with none are named in a context note asking the model to get a
  criterion for them before acting on them; the prompt itself is not changed;
- counts (lists, items, items without criterion) accumulate in `$.store` so the
  share can be measured later; `/newspeak` shows them.

Out: blocking (Memory Hole owns lists; one rule, one enforcer — T5's learning).

## A — gate

T5 says: don't duplicate an enforcer. Memory Hole enforces "list → file";
Newspeak only informs on a different rule, "item → criterion". This step's
question, what share of owner prompts lack a criterion, needs the counter,
which this step builds.

## S — Success metric

`bash scripts/check-mods.sh origin/main newspeak` green: bare items named,
criteria in both languages recognised, fenced lists ignored, no note when every
item has one, counts accumulate.
