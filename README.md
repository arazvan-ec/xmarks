# xmarks

[![Validate plugins](https://github.com/arazvan-ec/xmarks/actions/workflows/validate-plugins.yml/badge.svg)](https://github.com/arazvan-ec/xmarks/actions/workflows/validate-plugins.yml)

A [Claude Code](https://code.claude.com/docs) **plugin marketplace**. It currently ships one plugin:

## 🎡 flywheel

A nested **spec → plan → work → verify → review → compound** loop that turns "vibe coding"
into disciplined, self-verifying AI-assisted development. It adds an autonomous
metric-driven loop, parallel multi-specialist code review, and spec↔code sync.

See [`plugins/flywheel/README.md`](plugins/flywheel/README.md) for the full command
reference and design notes.

## Install

Add this marketplace and install the plugin from any Claude Code session:

```
/plugin marketplace add arazvan-ec/xmarks
/plugin install flywheel@xmarks
```

Then try it:

```
/flywheel:loop <your feature or task>
```

Run `/plugin` to inspect or manage installed plugins.

## Repository layout

```
xmarks/
├── .claude-plugin/
│   └── marketplace.json      # marketplace catalog (lists the plugins below)
├── plugins/
│   └── flywheel/             # the flywheel plugin
│       ├── .claude-plugin/plugin.json
│       ├── skills/           # /flywheel:* commands
│       ├── agents/           # verifier + specialist reviewers
│       ├── hooks/            # SessionStart + Stop hooks
│       ├── scripts/          # hook implementations
│       └── README.md
├── .claude/settings.json     # enables flywheel when working inside this repo
└── LICENSE
```

## Development

`.claude/settings.json` registers the `xmarks` marketplace and enables `flywheel@xmarks`, so
contributors who clone and trust the folder are prompted to install the plugin. To test local
changes to the plugin before committing, load it directly without an install step:

```
claude --plugin-dir ./plugins/flywheel
```

Validate the marketplace and plugin manifests before publishing:

```
claude plugin validate .
claude plugin validate ./plugins/flywheel
```

## License

[MIT](LICENSE) © arazvan
