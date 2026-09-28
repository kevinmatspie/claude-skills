# spie-claude-skills

Personal [Claude Code](https://docs.claude.com/en/docs/claude-code) skills, distributed as a plugin. Includes SPIE-specific tooling alongside more general utilities.

## What's inside

| Skill | Purpose |
|---|---|
| [`spie`](skills/spie/SKILL.md) | Answer natural-language questions about the SPIE CRM by invoking the `spie` CLI (`spie-cli`). Triggers on bare SPIE codes (PW26, EOD26, BO100, 13292-11, …). |
| [`release-notes`](skills/release-notes/SKILL.md) | Generate mobile app release notes from a Jira fix version and update the Confluence draft page. |
| [`copilot-bridge`](skills/copilot-bridge/SKILL.md) | Delegate work to GitHub Copilot via a tmux-driven session — code reviews, second opinions, or anything you want offloaded to a different model/subscription. Explicit invocation only ("ask copilot ...", `/copilot-bridge`). |
| [`copilot-herdr`](skills/copilot-herdr/SKILL.md) | Run GitHub Copilot CLI as a read-only second reviewer in a sibling Herdr pane: code reviews, design critique, second opinions from a non-Claude model. Explicit invocation only; takes precedence over `copilot-bridge` inside Herdr. |
| [`symposium-knowledge-docs`](skills/symposium-knowledge-docs/SKILL.md) | Capture a SPIE symposium site's content pages as raw Ingeniux CMS HTML (via `?tfrm=5`), named by page title, into a per-event folder for a chatbot/Copilot knowledge base. Skips dynamic rosters/search widgets and external apps. |

## Installation

From any Claude Code session:

```
/plugin marketplace add kevinmatspie/claude-skills
/plugin install spie-claude-skills@spie
/reload-plugins
```

Then **turn on auto-update**: run `/plugin`, open the **Marketplaces** tab, select `spie`, and choose **Enable auto-update**. Marketplaces added from a GitHub repo have auto-update **off by default**, so without this step you stay on whatever version you first installed (one machine was still running 0.1.0 over a month after 0.4 shipped). With it on, Claude Code checks for updates at the start of each session; a session that's already running keeps its current version until `/reload-plugins`.

Per-skill prerequisites:

- `spie` — requires the `spie` CLI (0.5.1 or newer) on PATH. The CLI is installed separately from this plugin, and updating the plugin does not update it; see the [spie-cli releases](https://github.com/spie-dev/spie-cli/releases) for binaries.
- `release-notes` — requires access to the SPIE Atlassian Cloud.
- `copilot-bridge` — requires `tmux` and an authenticated GitHub `copilot` CLI on PATH.
- `copilot-herdr` — requires running inside Herdr (`HERDR_ENV=1`), plus `jq` and an authenticated GitHub `copilot` CLI on PATH.

## Updates

### Getting updates

With auto-update on (see Installation), updates arrive on their own at session start. To update by hand:

```
/plugin marketplace update spie
/plugin update spie-claude-skills
/reload-plugins
```

### Releasing

Bump the `version` in **both** `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, tag the commit (`git tag -a v0.2.0 -m "…"`), and push `main` and the tag. The update check compares against `marketplace.json`, so bumping only `plugin.json` ships the content without anyone being notified (this happened with 0.5.0). Check that the two versions match before tagging.

## Layout

```
.
├── .claude-plugin/
│   ├── plugin.json        # plugin manifest
│   └── marketplace.json   # marketplace entry (required by /plugin install)
└── skills/
    ├── spie/SKILL.md
    ├── release-notes/SKILL.md
    ├── copilot-herdr/SKILL.md
    └── copilot-bridge/
        ├── SKILL.md
        ├── README.md       # bridge-specific docs
        └── bin/cop-*       # tmux driver scripts (invoked by SKILL.md, not on PATH)
```
