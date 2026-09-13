# Entry types — what a `fixture` entry must contain

Reference for `/flywheel:compound`'s entry format. Read before writing a
`fixture` entry; the other four types need no more than their one-line title.

- `type` is one of `decision`, `gotcha`, `pattern`, `bugfix`, `fixture`.
  A **`fixture`** entry captures *how to set up the world* — the recipe to build
  a valid stub/fixture for a domain entity, seed the datastore, or stand up a
  test harness, with the fields/relationships easy to get wrong (title names the
  entity, e.g. `fixture: editorial stub for homeTag`). This is the costliest
  thing a future cycle re-derives, so capture it whenever this cycle discovered
  one — but **only a recipe you observed work** (it built a valid instance and
  the check using it went green), never a plausible-but-unrun one. Record *how
  to build* test data, **never** real credentials or PII. Keep the recipe body
  prose + inline code — no lines starting with `## ` (the ledger parsers read
  those as a new entry boundary and would split the recipe).
