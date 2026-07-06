# Add flywheel to a repo

flywheel (from the `xmarks` marketplace) auto-activates in any **Claude Code** session —
local, IDE, or web — that opens a repo containing the config below. This is the reliable way
to have it everywhere, because plugins installed by hand may not persist across ephemeral web
sessions.

> **Claude Code only.** The claude.ai chat app uses a different "Skills" system and does not run
> Claude Code plugins.

## 1. Add `.claude/settings.json`

Create (or **merge into**) `.claude/settings.json` at the repo root, then commit and push:

```json
{
  "extraKnownMarketplaces": {
    "xmarks": { "source": { "source": "github", "repo": "arazvan-ec/xmarks" } }
  },
  "enabledPlugins": { "flywheel@xmarks": true }
}
```

If the file already exists, merge just these two keys (`extraKnownMarketplaces`,
`enabledPlugins`) — keep any existing settings.

Next time you open the repo in Claude Code and **trust the folder**, flywheel registers and
activates automatically: you'll see `🎡 flywheel loaded` at session start and the `/flywheel:*`
commands become available.

## 2. Copy-paste prompt (let Claude Code set it up)

Paste this into a Claude Code session opened on the target repo:

```
Set up the flywheel plugin in this repo so it auto-activates in Claude Code.
Create or merge `.claude/settings.json` at the repo root with these keys, keeping any
existing settings intact:

{
  "extraKnownMarketplaces": { "xmarks": { "source": { "source": "github", "repo": "arazvan-ec/xmarks" } } },
  "enabledPlugins": { "flywheel@xmarks": true }
}

Then validate the JSON, commit, and push. Remind me to trust the folder so it loads.
```

## Manual alternative (per session, no repo change)

```
/plugin marketplace add arazvan-ec/xmarks
/plugin install flywheel@xmarks
```

Note: in ephemeral web sessions this may not survive a new container — prefer the
`.claude/settings.json` method above for anything you want to persist.

## Using it

- `/flywheel:help` — onboarding + command map
- `/flywheel:loop <task>` — the full spec → plan → work → verify → review → compound cycle
- `/flywheel:spec`, `/flywheel:plan`, `/flywheel:work`, `/flywheel:debug`, `/flywheel:review`,
  `/flywheel:ship`, `/flywheel:autoloop`, `/flywheel:sync`

## Requirements

- **Claude Code** (CLI, IDE, or web) — not the claude.ai chat app.
- The `arazvan-ec/xmarks` marketplace repo must be reachable (it's public).
- To pick up a newer plugin version later: `/plugin update flywheel@xmarks`.
