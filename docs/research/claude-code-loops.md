# Claude Code loop primitives — reference

Summarized from the official Claude Code docs (2026-07-08). A "loop" is an agent
repeating cycles of work until a stop condition is met; the primitives differ by
**what starts the next turn** and **what stops it**. Recommended progression:
turn-based (manual) → `/goal` (clear success criteria) → `/loop` (local interval)
/ `/schedule` (cloud) → proactive streams (routines + workflows + auto mode).
Start simple; compose only as needed.

The three "keep this session going" approaches at a glance:

| Approach | Next turn starts when | Stops when |
| --- | --- | --- |
| `/goal` | Previous turn finishes | A model confirms the condition is met |
| `/loop` | A time interval elapses | You stop it, or Claude decides work is done |
| Stop hook | Previous turn finishes | Your own script/prompt decides |

Sources: <https://claude.com/blog/getting-started-with-loops>, <https://code.claude.com/docs/en/goal>

---

## 1. `/goal` — iterate until a condition holds

- **What / why:** set a completion condition; Claude keeps starting new turns
  toward it with no re-prompting. For substantial work with a verifiable end
  state (migrate until all call sites compile + tests pass; drain a backlog).
  Requires Claude Code **v2.1.139+**. One goal active per session.
- **Syntax:** `/goal <condition>` sets/replaces it **and immediately starts a
  turn**; `/goal` (no args) shows status (condition, elapsed, turns evaluated,
  token spend, evaluator's last reason); `/goal clear` (aliases `stop`/`off`/
  `reset`/`cancel`) removes it. Example: `/goal all tests in test/auth pass and
  the lint step is clean`.
- **Evaluator mechanism (the key detail):** `/goal` is a wrapper around a
  **session-scoped, prompt-based Stop hook**. After *every* turn, the condition +
  the conversation so far are sent to a **small fast model (Haiku by default)**,
  which returns yes/no + a short reason. "No" sends Claude back to work with the
  reason as guidance. The evaluator **does not call tools or read files** — it
  judges only what Claude surfaced in the transcript, so conditions must be
  provable from Claude's own output (e.g. "`npm test` exits 0").
- **Bounding runtime:** put the cap in the condition, e.g. `… or stop after 20
  turns`.
- **Limits:** condition up to **4,000 chars**; evaluator tokens billed on the
  cheap model (negligible). Local/in-session; restored on `--resume` (condition
  carries; counters reset). Needs a trusted workspace; unavailable if hooks are
  disabled.

Sources: <https://code.claude.com/docs/en/goal>

---

## 2. `/loop` — run a prompt on an interval (local, in-session)

> **URL correction:** the canonical page is
> <https://code.claude.com/docs/en/scheduled-tasks> ("Run prompts on a
> schedule"). `https://code.claude.com/docs/en/loop` is a **404** — the article's
> "loop" link mis-points.

- **What / why:** a bundled skill that re-runs a prompt on an interval while the
  session stays open — poll a deploy, babysit a PR, check a build. Requires
  **v2.1.72+**. Tasks are **session-scoped** (die on a new conversation; restored
  on `--resume`).
- **Syntax by argument:**
  - `/loop 5m check the deploy` → fixed cron interval.
  - `/loop check the deploy` → **self-paced**: Claude picks a delay between **1
    min and 1 hour** each iteration based on activity (may use the **Monitor**
    tool, often more token-efficient than re-prompting).
  - `/loop` (bare) → runs the built-in maintenance prompt (or your `loop.md`):
    continue unfinished work → tend the branch's PR → cleanup passes; never
    starts new initiatives; irreversible actions only if already authorized.
  - Intervals lead or trail (`30m`, `every 2 hours`); units `s/m/h/d`; seconds
    round up (cron is 1-min granular). Can pass a skill: `/loop 20m /review-pr 1234`.
- **`loop.md`** (project `.claude/loop.md` > user `~/.claude/loop.md`) replaces
  the default prompt; truncated beyond **25,000 bytes**.
- **Limits:** min interval **1 min**; up to **50 scheduled tasks** per session;
  8-char task IDs; recurring tasks **expire after 7 days**; jitter up to 30 min
  (or half the interval if sub-hourly). Press **Esc** to stop. Manage via natural
  language or `CronCreate`/`CronList`/`CronDelete`. Disable with
  `CLAUDE_CODE_DISABLE_CRON=1`.
- **Local only** — fires while Claude Code runs and is idle; closing the terminal
  stops it.

Sources: <https://code.claude.com/docs/en/scheduled-tasks>

---

## 3. `/schedule` + Routines — cloud automation

- **What / why:** a **routine** is a saved config (prompt + repos + connectors)
  that runs **autonomously on Anthropic's cloud** — laptop closed. **Research
  preview.** Manage at claude.ai/code/routines, desktop, or CLI `/schedule`.
- **Triggers (combinable):** **Scheduled** (recurring or one-off), **API** (a
  per-routine HTTP `/fire` endpoint with a bearer token; optional freeform `text`
  passed alongside the saved prompt), and **GitHub** (reacts to pull_request /
  release events with filters).
- **CLI:** `/schedule daily PR review at 9am`, `/schedule clean up flag in one
  week` (one-off), `/schedule list|update|run`. CLI creates scheduled routines
  only; add API/GitHub triggers on the web.
- **Limits:** **minimum interval 1 hour** (sub-hourly cron rejected); a **daily
  per-account run cap** (one-offs don't count); GitHub webhook caps during
  preview.
- **Execution:** full cloud sessions, **no permission prompts** (autonomous);
  each repo cloned fresh from the default branch; pushes to `claude/`-prefixed
  branches by default; default **Trusted** network access. **Per-routine model
  selector** on the creation form — route routine work to a cheaper model.
- **Caveat:** a green run status means the session started/exited cleanly, **not**
  that the task succeeded — open the run to confirm.

Sources: <https://code.claude.com/docs/en/routines>, <https://code.claude.com/docs/en/scheduled-tasks>

---

## 4. Subagents / parallel agents

- **What / why:** specialized workers that run a side task in **their own
  isolated context** and return only a summary — keeping logs/file contents out
  of the main conversation, enforcing tool constraints, and **controlling cost by
  routing to cheaper models**.
- **Definition:** Markdown + YAML frontmatter in `.claude/agents/` (project) or
  `~/.claude/agents/` (user). Only `name` + `description` required. Key fields:
  - **`model`** — `sonnet`/`opus`/`haiku`/`fable`, a full ID, or `inherit`
    (**default is `inherit`**).
  - **`maxTurns`** — max agentic turns before the subagent stops (the per-subagent
    turn cap).
  - `tools`/`disallowedTools`, `permissionMode`, `skills`, `mcpServers`, `hooks`,
    `isolation: worktree`, `effort`, etc.
- **Model resolution order:** `CLAUDE_CODE_SUBAGENT_MODEL` env → per-invocation
  `model` → frontmatter `model` → main conversation model. Values checked against
  the org `availableModels` allowlist. Set `model: haiku` for cheap routine work.
- **Parallelism:** just ask ("research X, Y, Z in parallel using separate
  subagents"). As of **v2.1.198** subagents run in the **background by default**.
  **Nesting depth is fixed at 5** (a depth-5 subagent can't spawn more). Related:
  **`/batch`** splits one change into **5–30** worktree-isolated subagents that
  each open a PR.
- **Forks:** a fork inherits the full conversation (cheaper — reuses the parent's
  prompt cache) instead of starting fresh. `/fork <directive>`.

Sources: <https://code.claude.com/docs/en/agents>, <https://code.claude.com/docs/en/sub-agents>

---

## 5. Dynamic workflows — orchestrate subagents at scale from a script

- **What / why:** a **JavaScript script that orchestrates subagents**. Claude
  writes it for the task you describe; a runtime runs it **in the background**.
  Intermediate results live in **script variables, not Claude's context** — only
  the final answer returns. For work needing more agents than one conversation
  can coordinate: codebase-wide sweeps, large migrations, cross-checked research.
  Requires **v2.1.154+**.
- **Who holds the plan:** the **script** holds the loop/branching/intermediate
  results (vs subagents where Claude decides turn-by-turn). Enables repeatable
  quality patterns — **adversarial cross-review**, multi-angle plan drafting.
- **Script model:** top-level `await`; a `meta` block then a body. Core
  primitives: `agent(prompt, options)` (one subagent; supports `schema` for
  structured output) and `pipeline(list, fn)` (one agent per item — fan-out).
- **Triggering:** bundled `/deep-research <question>`; ad hoc via the **`ultracode`**
  keyword or "use a workflow"; session-wide via `/effort ultracode` (xhigh
  reasoning + auto orchestration).
- **Hard limits:** **up to 16 concurrent** agents; **1,000 agents total per run**;
  an advisory **large-workflow warning** when a run schedules **>25 agents** or
  its projected tokens pass **1.5M**. Manage with `/workflows` (per-agent token
  usage live; pause/stop/restart). Disable via `/config`,
  `CLAUDE_CODE_DISABLE_WORKFLOWS=1`, or managed settings.

Sources: <https://code.claude.com/docs/en/workflows>, <https://code.claude.com/docs/en/agents>

---

## Cross-cutting: model routing & token management

- **Route by role:** cheap/fast models (Haiku) for routine work and
  completion-judging (the `/goal` evaluator defaults to Haiku); capable models for
  the judgment/main work. Subagents via `model:` or `CLAUDE_CODE_SUBAGENT_MODEL`;
  routines via the per-routine selector; workflows via per-stage routing in the
  script.
- **Visibility:** `/usage` (breakdown by skills/subagents/MCPs), `/goal` with no
  args (turns + tokens), `/workflows` (per-agent/per-phase totals, live).
- **Guardrails:** workflow caps (16 concurrent / 1,000 total), the >25-agent or
  >1.5M-token warning, `/config` size guidelines, `/loop`'s 7-day expiry / 50-task
  cap, routines' 1-hour minimum.
- **Pilot before scaling:** run workflows on a small slice first; match `/loop`
  intervals to real change frequency; prefer deterministic scripts / the Monitor
  tool over re-prompting.

Sources: <https://claude.com/blog/getting-started-with-loops> and the per-primitive pages above.

---

## Numeric caps cheat-sheet

| Primitive | Caps / key numbers |
| --- | --- |
| `/goal` | condition ≤ 4,000 chars; evaluator on Haiku; v2.1.139+ |
| `/loop` | 1-min min interval; 50 tasks/session; 7-day expiry; self-paced 1min–1h; v2.1.72+ |
| Routines (`/schedule`) | 1-hour min interval; daily per-account run cap; research preview |
| Subagents | nesting depth fixed at 5; `/batch` = 5–30 |
| Dynamic workflows | 16 concurrent; 1,000 total/run; >25-agent or >1.5M-token warning; v2.1.154+ |
