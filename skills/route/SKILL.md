---
name: route
description: Recommend how to run a piece of work you are about to delegate — tool, fresh session, subagent or here — and at which model and effort. Use before create_session, an Agent call or a /flywheel:run execution, whenever the work is outside a plan's routed tasks.
argument-hint: "<the task you are about to delegate>"
allowed-tools: Read, Grep, Glob
---

# /flywheel:route — pick the mechanism, model and effort before delegating

Recommend how to run: **$ARGUMENTS**

A plan task already carries its route (`/flywheel:plan`). This is for everything
else: a child session, a loose subagent, a process run. Without a decision, each
of those inherits the caller's model, and the caller's context along with it.

## 1. Read the tiers

Read the tier table: `.claude/flywheel/bin/route-tiers.txt` on a vendored
install, `${CLAUDE_PLUGIN_ROOT}/scripts/route-tiers.txt` on a marketplace one,
`scripts/route-tiers.txt` inside flywheel itself. It is the only authority on
what tier 1, 2 and 3 mean. Never restate a tier from memory.

## 2. Decide the mechanism — first yes wins

1. **A deterministic tool or script already does it** → `tool`. It costs no
   model, it gives the same answer every time, and it does not tire by the
   hundredth item. Name the command.
2. **The work carries a point of view** (research, grading evidence, adversarial
   review, synthesis, judging someone else's diff) → `fresh-session`. A subagent
   inherits the caller's framing, which is exactly what this work must not start
   from. **Never a `fork`**: it inherits the whole context and ignores `model`.
3. **Reads or edits with no judgment**, many identical ones or one that would
   flood this context (is this figure on this page, summarise this log, apply
   this recorded recipe to each file). A rename that `sed` or an LSP can do is
   step 1, not this one → `subagent` at tier 1,
   in parallel. Being expensive does not make a model better at reading.
4. **Anything else** → `here`, or `subagent` if it would flood this context with
   reading. Then pick the tier in step 3.

## 3. Pick the tier, then the effort

Check tier 3 first, so risk inside an existing module is never tier 2.

- **Tier 1**: fully specified, no design choice left.
- **Tier 2**: ordinary work inside structure that already exists. Most work.
- **Tier 3**: design, ambiguous requirements, security, secrets or data risk,
  a change that needs design across 3+ modules, or the riskiest step. A
  `fresh-session` from step 2 is tier 3 unless the work is plainly mechanical.
- **A step-2.3 subagent stays tier 1 however wide it fans out.** Breadth is not
  difficulty: a recorded recipe applied to 12 files is still fully specified. The
  one exception is size: an item that does not fit tier 1's context, with room
  left for the brief and the answer, goes to tier 2. Context sizes are in
  `skills/route/references/models.md`.

**Effort before model.** A tier's effort in the table is its default, not a
floor. Recommend the lowest effort that holds within the tier
(a tier whose model takes no effort, per `skills/route/references/models.md`,
has only the model as a lever).
Raise it when the *check* is subtle, not when the work is large. Offer a cheaper
model only when the next tier down at the same effort would do the job, and
judge cost per **completed** task, not per call: a cheap model that needs a retry
is not cheap. Compare prices only when two routes are close, with
`skills/route/references/models.md`.

## 4. Answer in this shape

```
mechanism: tool | fresh-session | subagent | here
route:     <model>/<effort>[+delegate]    (none for a tool; +delegate only for a tier-1
           `subagent`: the `executor` agent where registered, else a
           subagent with `model`; drop it for any other mechanism)
why:       one line per decision above
escalate-if: <what you would see if this was too cheap>
```

Then say how to launch it: the tool command; `create_session` with `model` set
explicitly (never inherited); `Agent` with `model` and an effort-pinned
`subagent_type` where one exists; or keep it here, switching this session to
the route's model and effort first if it runs on others. The caller decides. This is a
recommendation, not a gate.

**Escalate on evidence, not on worry.** A second red on the same check, or an
answer that ignores part of the brief, moves the work one tier up. A route that
merely feels risky does not.
