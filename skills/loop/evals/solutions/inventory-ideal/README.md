# Ideal outcome — loop eval 1 (`inventory-repo`)

A completed cycle: both functions implemented, one pathspec commit per task,
and a transition JSONL whose `commit` shas are the real git objects those
commits produced.

```bash
bash scripts/fixture-scratch.sh loop 1 --solution inventory-ideal --check
```

**Why `steps/` and not `patch/`.** `fixture-scratch.sh` applies `patch/` itself,
flat and in lexical order. These two must land in *separate commits* — restock
in one, low_stock in the next — so `apply.sh` applies them, and a second name
keeps the script's flat pass from applying each of them twice.

**Why any of it is a script.** The grader's decisive assertion is that every
recorded sha resolves via `git cat-file -e <sha>^{commit}`. A sha written into a
committed asset is by definition a sha nobody made in that workdir — the exact
`fabricated-sha` cheat this grader is tested against — so the commits have to be
made at apply time. The *content* of each step is still a reviewable patch;
only the git ceremony is code.

`apply.sh` checks each git command's status explicitly rather than trusting
`set -e`, which does not abort a failure inside the command substitution that
captures each sha. The first draft did trust it, and produced a `commit` field
containing git's "nothing to commit" chatter while still exiting 0.
