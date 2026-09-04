# release-notes skill — Atlassian config (example)

Copy this file to `~/.claude/spie/release-notes.config.local.md` and fill in your
values. That location is outside the versioned plugin cache, so it survives
plugin updates. Do **not** put real values in this example file — it is committed.

| Key | Value | Notes |
|-----|-------|-------|
| ATLASSIAN_SITE | your-site.atlassian.net | Site hostname; pass as `cloudId` to the Atlassian MCP tools. |
| ATLASSIAN_CLOUD_UUID | 00000000-0000-0000-0000-000000000000 | Numeric cloud id for the Jira `blockCard` datasource. Also appears in `context.cloudId` of any Jira MCP response. |
| JIRA_PROJECT | MOB | Jira project key for the mobile app. |
| JIRA_BASE_URL | https://your-site.atlassian.net | Base URL for the Jira widget `url` field. |

If this file is absent, the skill falls back to values in `~/.claude/CLAUDE.md`
and to `context.cloudId` returned by any live Jira MCP call, so a missing config
never blocks a run.
