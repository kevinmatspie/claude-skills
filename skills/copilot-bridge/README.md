# copilot-bridge

Shell scripts that drive a long-lived GitHub Copilot CLI session via tmux.
Used by the `copilot-bridge` skill — Claude invokes these scripts by path
rather than relying on PATH.

Purpose: offload work from Claude to Copilot without leaving the Claude
session or manually copy-pasting between terminals. Uses a separate billing
bucket (GitHub Copilot subscription), supports model choice
(`gpt-5.3-codex` by default), and preserves Copilot's conversation context
across multiple prompts.

## Install

These scripts ship as part of the `spie-claude-skills` plugin — no separate
install required. Requirements:

- `tmux` on PATH
- GitHub `copilot` CLI on PATH and authenticated

If you want to run the scripts by hand from a shell (not via the skill), invoke
them by full path or `cd` into this directory first:

```sh
cd path/to/skills/copilot-bridge
bin/cop-start
bin/cop-nudge --wait "your prompt"
bin/cop-stop
```

## Scripts

| Script | Purpose |
|--|--|
| `bin/cop-start` | Idempotently start tmux session running Copilot |
| `bin/cop-nudge "prompt"` | Send a prompt; prints a request ID |
| `bin/cop-nudge --wait "prompt"` | Send a prompt and block until result is ready |
| `bin/cop-watch <id>` | Block until the request completes; print the result |
| `bin/cop-send-keys <key>...` | Escape hatch for raw tmux keys (Enter, C-c, etc.) |
| `bin/cop-status` | Is the session running? Show last pane lines |
| `bin/cop-stop` | Kill the session and clean up stale output files |

Attach to the live Copilot session interactively: `tmux attach -t cop`
(detach with `C-b d`).

## Environment

| Var | Default | Purpose |
|--|--|--|
| `COP_SESSION` | `cop` | tmux session name |
| `COP_MODEL` | `gpt-5.3-codex` | Copilot model |
| `COP_DIR` | `$PWD` | Dir granted to Copilot at start |
| `COP_READY_TIMEOUT` | `30` | Seconds to wait for TUI to stabilize before nudge |

## How it works

- **`cop-nudge`** uses `tmux set-buffer` + `paste-buffer` instead of
  `send-keys "text"` to avoid a race with Copilot's bubbletea TUI, which drops
  typed input while rendering its input box.
- Each nudge augments the prompt with instructions to write the final answer
  to `/tmp/cop-out-<id>.md` and print a sentinel `COP_DONE_<id>`. This avoids
  scraping ANSI-laden TUI output.
- **`cop-watch`** completes when either the sentinel appears in the pane, or
  the output file has been idle for 15 seconds (fallback for models that
  forget the sentinel). On timeout, dumps the last 30 pane lines to stderr.
- Copilot is started with `--allow-all-tools --allow-all-paths` so it can
  write to `/tmp` without prompting — acceptable because it's running in an
  isolated tmux session you chose to spawn.
- **`cop-send-keys`** is a thin escape hatch for the rare case Copilot's TUI
  shows an unexpected confirmation prompt the bridge doesn't handle.

## Known limits

- One session at a time by default (override with `COP_SESSION` for parallel
  sessions).
- If Copilot's TUI layout changes significantly in a future release, the
  ready-check or sentinel detection may need adjustment.
