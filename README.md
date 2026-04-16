# spie-claude-skills

SPIE-internal [Claude Code](https://docs.claude.com/en/docs/claude-code) skills, distributed as a plugin.

## What's inside

| Skill | Purpose |
|---|---|
| [`spie`](skills/spie/SKILL.md) | Answer natural-language questions about the SPIE CRM by invoking the `spie` CLI (`spie-cli`). Triggers on bare SPIE codes (PW26, EOD26, BO100, 13292-11, …). |
| [`release-notes`](skills/release-notes/SKILL.md) | Generate mobile app release notes from a Jira fix version and update the Confluence draft page. |

## Installation

From any Claude Code session:

```
/plugin marketplace add kevinmatspie/claude-skills
/plugin install spie-claude-skills@spie
/reload-plugins
```

The `spie` skill requires the `spie` CLI on PATH. The `release-notes` skill requires access to the SPIE Atlassian Cloud.

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
    └── release-notes/SKILL.md
```
