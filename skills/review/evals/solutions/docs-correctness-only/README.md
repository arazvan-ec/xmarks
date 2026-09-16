# docs-correctness-only

The ideal outcome for eval 1: a docs-only diff draws the correctness lens alone,
and the report names both lenses it skipped together with the rule that skipped
them. Overlay only — the run leaves `review.md` and `.dispatch-log` behind and
changes nothing in the tree it is reviewing.
