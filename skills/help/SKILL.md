---
name: help
description: Onboarding and command reference — the nested loop, every /flywheel command, and where to start. Use when someone is new to flywheel or asks how it works.
argument-hint: "[optional: a topic, or a task you want to start]"
---

# /flywheel:help — onboarding & command map

Onboard the user to flywheel. Be friendly, concrete, and skimmable — not a wall of text. If `$ARGUMENTS` names a topic or a task, tailor the answer to it; otherwise give the full orientation below, in order.

## 1. What flywheel is — say it in 2–3 lines
A disciplined, self-verifying development loop. One unit of work flows through six gated phases — **spec → plan → work → verify → review → compound** — and inside `work` runs a tight *write-failing-test → implement → run → observe → fix* inner loop. Nothing advances on "seems right": `verify` runs the real app/tests, and each finished cycle deposits reusable lessons into a ledger that primes the next one.

It has a **second pillar** too: where the loop *builds* software, `/flywheel:process` + `/flywheel:run` let flywheel *operate* it — Claude runs recurring domain operations ("analyze a car") as the backend, following a fixed contract, persisting to the repo's own datastore, and maturing the contract each run. This is the [agent-native](https://every.to/go-agent-native) side.

## 2. The command map — show as a table
| Command | When to use it |
| --- | --- |
| `/flywheel:loop <task>` | **Start here.** Runs the whole cycle end to end, gating between phases; routes small, clear tasks through a collapsed micro-cycle. |
| `/flywheel:brainstorm <idea>` | The idea is fuzzy — sharpen it into agreed requirements first. |
| `/flywheel:spec <feature>` | Write the contract + one machine-checkable success metric. |
| `/flywheel:plan <spec>` | Turn a signed spec into ordered tasks, each with its own check. |
| `/flywheel:work <task>` | Implement with the iterate-until-green inner loop. |
| `/flywheel:debug <symptom>` | Something's broken — reproduce → isolate → fix → add a regression test. |
| `/flywheel:verify` | Objective PASS/FAIL gate; runs the real app/tests. |
| `/flywheel:review <ref>` | Multi-specialist review, routed by diff type (docs diff ≠ full fan-out). |
| `/flywheel:compound` | Capture this cycle's decisions and gotchas into the ledger. |
| `/flywheel:recall <query>` | Look up a past decision/gotcha/pattern the ledger has, on demand. |
| `/flywheel:route <task>` | About to delegate work outside a plan — pick tool, fresh session or subagent, and its model and effort. |
| `/flywheel:ship <title>` | Clean commit + push + PR. |
| `/flywheel:process <desc>` | Define an **agent-native process** — a reusable contract (fixed rules + output schema + persistence) for a recurring domain operation Claude runs as the backend. |
| `/flywheel:run <slug> [input]` | Run a defined process as the runtime — follow its rules, persist to the repo's datastore, mature the contract. |
| `/flywheel:autoloop <goal>` | Hands-off: iterate autonomously until a metric is met or a budget runs out. |
| `/flywheel:sync <spec>` | Reconcile drift between a spec and the code. |
| `/flywheel:update [vendored\|marketplace]` | Update flywheel itself in this repo (mode autodetected). |

## 3. How to pick a starting point
- Clear feature/task in mind → `/flywheel:loop <task>` (it pauses at each gate for your sign-off).
- Idea still fuzzy → `/flywheel:brainstorm <idea>`, then `/flywheel:spec`.
- Just fixing a bug → `/flywheel:debug <symptom>`.
- Want it fully autonomous → `/flywheel:autoloop <goal>` (define a measurable goal first).
- Want Claude to *operate* the repo (run a recurring domain operation, not build code) → `/flywheel:process <desc>` to define it, then `/flywheel:run <slug> <input>` to execute + persist.

## 4. Good to know
Read `skills/help/references/good-to-know.md` and surface only the three or four
items that answer what the user actually asked — reciting all fourteen is the
wall of text this skill opens by forbidding. Commands are namespaced
`/flywheel:…` and also show up in `/help`.

## 5. Offer to start
Finish by asking one question: **"What do you want to build, fix, or explore right now?"** Based on the answer, recommend the exact command. If the user says go, invoke it for them (for example, run `/flywheel:loop <task>`). Never launch a `loop`, `autoloop`, or `ship` command without explicit confirmation.
