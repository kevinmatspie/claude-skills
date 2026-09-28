---
name: copilot-herdr
description: Use ONLY when the user explicitly asks for GitHub Copilot's input AND this session runs inside Herdr (HERDR_ENV=1) — phrases like "ask copilot", "have copilot review X", "get copilot's eyes on this", "second opinion from copilot", "is copilot done?", "stop copilot", or /copilot-herdr. Starts GitHub Copilot CLI as a read-only reviewer in a sibling Herdr pane, briefs it, and brings its answer back. Inside Herdr this takes precedence over copilot-bridge. Never use proactively.
---

# Copilot via Herdr

## Overview

Runs GitHub Copilot CLI in a pane next to this one, through the `herdr` CLI, so a model from a different vendor can review work or critique a design. The user can watch the pane and step in. Herdr handles the terminal mechanics: readiness, prompt delivery, and the `idle`/`working`/`blocked` lifecycle.

**Explicit invocation only.** Do not start Copilot, or suggest starting it, unless the user asks.

## Preconditions

```sh
test "${HERDR_ENV:-}" = 1 && command -v copilot
```

If either fails, say which and stop. If `copilot --version` hangs after a Homebrew upgrade, point the user at `brew-copilot-upgrade` (the quarantined first-launch hang).

## Model

The value of a second reviewer is a different vendor's blind spots, so never pick a Claude model.

| Use | Model | Slug |
|--|--|--|
| Reviews, design critique (default) | GPT-6 Astra | `gpt-6-astra` |
| Quick back-and-forth | GPT-6 Sol | `gpt-6-sol` |
| Tiebreaker when Claude and GPT disagree | Grok or Gemini | probe the slug first (below) |

For scale: a two-round review with GPT-6 Astra used 2 premium requests and about 241 AI credits (the status bar shows the running "AIC used").

Honor a model the user names. The `/model` picker shows display names and premium-request multipliers, not slugs. Probe a guessed slug from a scratch directory, which costs one request:

```sh
cd "$TMPDIR" && copilot -p "Reply with only the word ok." --model <slug> --available-tools= --allow-all-tools -s
```

An unknown slug fails with `Model "<slug>" from --model flag is not available.` (`--available-tools=` leaves the probe with no tools, so `--allow-all-tools` grants nothing.)

## Session

- **Only drive panes you started in this conversation.** Record the pane ID and agent name when you start one. `herdr agent list` can show Copilot sessions the user started themselves; never rename, prompt or close those.
- **Reuse or restart.** Copilot keeps context within a session, so reuse yours for follow-ups on the same task. For an unrelated task, ask whether to close it and start fresh.
- **Names can vanish.** Before reusing, run `herdr agent get <name>`. If it returns `agent_not_found`, the user closed or moved the pane; start a new one rather than searching for it.

## Start

Pick the split direction from `herdr pane layout --pane "$HERDR_PANE_ID"`: split `right` when the pane is wide, `down` when it is narrow. Keep focus here.

```sh
PANE=$(herdr pane split --current --direction right --cwd "$PWD" --no-focus | jq -r .result.pane.pane_id)

# Hide tokens from Copilot's shell and MCP servers (Copilot's own sign-in is unaffected).
SECRET_VARS=$(env | cut -d= -f1 | grep -E 'TOKEN|SECRET|PASSW|API_?KEY|ACCESS_KEY|CREDENTIAL|^KSM_' | paste -sd, -)

herdr agent start cop-review --kind copilot --pane "$PANE" -- \
  --model gpt-6-astra \
  --mode interactive \
  --disable-builtin-mcps \
  --secret-env-vars="$SECRET_VARS" \
  --deny-tool write \
  --deny-tool 'shell(git push)' --deny-tool 'shell(git commit)' --deny-tool 'shell(git reset)' \
  --deny-tool 'shell(git checkout)' --deny-tool 'shell(git restore)' --deny-tool 'shell(git clean)' \
  --deny-tool 'shell(git rebase)' --deny-tool 'shell(git merge)' \
  --deny-tool 'shell(gh:*)' --deny-tool 'shell(rm:*)' --deny-tool 'shell(sudo:*)' \
  --deny-tool 'shell(ssh:*)' --deny-tool 'shell(curl:*)' --deny-tool 'shell(ksm:*)' \
  --deny-tool 'shell(spie-sql:*)' --deny-tool 'shell(spie-graylog:*)' \
  --allow-tool 'shell(git diff)' --allow-tool 'shell(git log)' --allow-tool 'shell(git show)' \
  --allow-tool 'shell(nl)'
```

Why these flags:
- Copilot runs commands it judges read-only (`printenv`, `ls`) without asking, so the allow-list is not the only gate. The deny rules block risky commands outright, even ones Copilot rates as safe.
- `--deny-tool write` blocks file edits. Shell redirection still needs approval, which surfaces as `blocked`.
- `--disable-builtin-mcps` turns off the GitHub MCP server. Its tools aren't `shell(...)`, so the `gh` deny doesn't cover them, and they include writes such as comments and issues. A review of local code needs no GitHub access. Drop the flag only when the user asks Copilot to look at a PR or issue.
- `--mode interactive` sets the starting mode, so every approval is asked rather than auto-denied. It doesn't stop the mode being switched later (the mode-cycle key or `/autopilot`), so "Prompt and wait" handles the autopilot dialog.
- `sed` stays off the allow-list because allowing it also allows `sed -i`, which gets around `--deny-tool write`. The brief asks Copilot to read files with its viewer, which avoids most `sed` prompts. `nl` is allowed because it can't write.
- A "don't ask again" answer to an approval dialog is saved per repo in `~/.copilot/permissions-config.json` and applies to later sessions there. That explains a command running without a prompt.
- Never add `--allow-all`, `--allow-all-tools` or `--yolo`.

Use a unique name per session (`cop-review`, `cop-design`, …). `agent start` returns once Herdr detects Copilot. Right after start, don't trust a `blocked` status: the first run in a repo shows Copilot's folder-trust dialog, and Herdr can also report `blocked` while Copilot sits idle at its prompt. Read the pane (`herdr agent read cop-review --source visible --lines 30`) before telling the user about a dialog. An idle-but-`blocked` session takes a prompt normally.

## Brief

Copilot does not see this conversation. It loads `AGENTS.md` itself, but not `.claude/rules/*.md`, so name the rule files that apply. Write the brief to a scratchpad file and pass it with `"$(cat "$BRIEF")"`.

For a **review**:

```
You are reviewing, not editing: do not modify anything.
Read files with your file viewer, not shell commands.

Task: review <what> for correctness bugs and risky behaviour.
Scope: `git diff main...HEAD` (or: these files: …)
Context: <2-4 sentences on why the change exists and what it must preserve>
Rules that apply: AGENTS.md, plus <.claude/rules/x.md, …>. Read them first.

Output: findings ranked by severity, each as
[Critical|Important|Minor] path:line: the problem, why it matters, the fix.
If nothing significant, say so. No praise and no summary of the diff.
```

For **design critique**, give Copilot the problem and constraints *before* your plan and ask for its approach. Then send your plan as a follow-up and ask where it disagrees. A reviewer who sees your plan first tends to follow its framing.

Never put secrets, Keeper notation, CRM or person data, or `spie-sql`/`spie-graylog` output in a brief.

## Prompt and wait

```sh
herdr agent prompt cop-review "$(cat "$BRIEF")" --wait --timeout 540000
```

Keep each Herdr timeout under 9 minutes and give the Bash call its 10-minute maximum (`timeout: 600000`). Otherwise the tool kills the wait and it looks like a Herdr failure. For a longer review, repeat `herdr agent wait cop-review --timeout 540000` until the status changes. Copilot keeps working in between.

Check `.result.agent.agent_status`:
- `idle` or `done`: read the answer.
- `blocked`: Copilot is at an approval dialog. Read it with `herdr agent read cop-review --source visible --lines 30` and show the user the exact command. **Never approve it yourself.** If the user declines, read the pane again first: they may already have answered in the pane, and an Esc sent then lands on a working Copilot. If the dialog is still there, send `herdr agent send-keys cop-review esc`. Herdr can keep reporting `blocked` briefly after that, so confirm with a read.
  - **"Enable autopilot mode"** means the session was switched to autopilot, and this dialog appears when a prompt is sent. Its default option, "Enable all permissions", lifts every approval gate except the deny rules. Never choose it or press Enter here. Show the user the dialog and let them answer it. In autopilot, commands off the allow-list are refused without asking, so expect Copilot to report tools it couldn't run.
- `agent_prompt_stalled`: common with long briefs, because Copilot can take more than Herdr's 5 s window to start. **Don't resend.** Read the pane. If the brief is in the conversation, Copilot has it, so wait for it to start and then to finish:
  ```sh
  herdr agent wait cop-review --until working --until blocked --timeout 120000
  herdr agent wait cop-review --timeout 540000
  ```
  A plain `agent wait` before Copilot starts working returns `idle` straight away.
- Timeout or other error: run `herdr agent get` and `herdr agent read`, and don't resend the prompt blindly.

## Read the answer

```sh
herdr agent read cop-review --source recent-unwrapped --lines 400
```

The read covers the whole session, and Copilot does not use the alternate screen. The answer follows the end of the echoed brief. Replies start with `●`, tool calls show as `$ Shell …` or `✗ Shell …`, and the status bar follows. Strip the `┃` border characters that pad the right edge of each line. Don't wait on a pattern from the brief with `pane wait-output`: the echoed brief matches it immediately. If the answer starts mid-way, raise `--lines`. If it's still cut off, ask Copilot to repeat the rest starting from a given heading. File output is not available because writes are denied.

## Report

- Start with one line such as "From Copilot (GPT-6 Astra):", then pass its answer through with formatting fixes only. Don't paraphrase it.
- Then add your take on each finding: **confirmed** (you checked the code), **rejected** (why), or **unsure**. Copilot's findings are claims to verify before anyone acts on them.
- Don't fix anything based on its findings without the user's go-ahead, unless the user already asked for fixes.

## Cleanup

Ask before closing. Then close with `herdr pane close <pane>`, and only for panes you started. Closing the pane is a clean shutdown: Copilot records `session.shutdown` and keeps the whole conversation, the same as `/exit`. `/exit` also misfires when Copilot is mid-answer or at an approval prompt, so don't send it first. To come back to a closed review, get the session ID (the newest directory in `~/.copilot/session-state/`) and start Copilot in a new pane with the same flags plus `--resume=<id>`. If the user has clearly moved on, mention the running session once.

## Code-writing work

This skill is for read-only review. If the user wants Copilot to write code, don't loosen these flags in the shared checkout. Two agents editing one working tree collide. Propose a separate worktree (`herdr worktree create --branch … --no-focus`) and ask the user which permissions to grant there.
