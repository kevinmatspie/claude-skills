# spie-claude-skills

Personal [Claude Code](https://docs.claude.com/en/docs/claude-code) skills, distributed as a plugin. Includes SPIE-specific tooling alongside more general utilities.

## What's inside

| Skill | Purpose |
|---|---|
| [`spie`](skills/spie/SKILL.md) | Answer natural-language questions about the SPIE CRM by invoking the `spie` CLI (`spie-cli`). Triggers on bare SPIE codes (PW26, EOD26, BO100, 13292-11, …). |
| [`release-notes`](skills/release-notes/SKILL.md) | Generate mobile app release notes from a Jira fix version and update the Confluence draft page. |
| [`copilot-bridge`](skills/copilot-bridge/SKILL.md) | Delegate work to GitHub Copilot via a tmux-driven session — code reviews, second opinions, or anything you want offloaded to a different model/subscription. Explicit invocation only ("ask copilot ...", `/copilot-bridge`). |

## Installation

From any Claude Code session:

```
/plugin marketplace add kevinmatspie/claude-skills
/plugin install spie-claude-skills@spie
/reload-plugins
```

Per-skill prerequisites:

- `spie` — requires the `spie` CLI on PATH.
- `release-notes` — requires access to the SPIE Atlassian Cloud.
- `copilot-bridge` — requires `tmux` and an authenticated GitHub `copilot` CLI on PATH.

## Updates

Bump the `version` in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, tag the commit (`git tag -a v0.2.0 -m "…"`), and push. Users pull updates with:

```
/plugin update spie-claude-skills
```

## Layout

```
.
├── .claude-plugin/
│   ├── plugin.json        # plugin manifest
│   └── marketplace.json   # marketplace entry (required by /plugin install)
└── skills/
    ├── spie/SKILL.md
    ├── release-notes/SKILL.md
    └── copilot-bridge/
        ├── SKILL.md
        ├── README.md       # bridge-specific docs
        └── bin/cop-*       # tmux driver scripts (invoked by SKILL.md, not on PATH)
```
