---
name: spie
description: Use when the user asks about SPIE (the International Society for Optics and Photonics) meetings, conferences, papers, sessions, badges, registrations, exhibitors, or people — including questions referencing SPIE event codes (e.g. PW26, EOD26, AS26, BO100, OSD06, AL101), paper numbers (e.g. 13292-11, PC13823-1), composed session IDs (e.g. 13823-1), SPIE badge numbers, SPIE IDs, or @spie.org-associated contacts. Also when the user invokes /spie.
---

# SPIE CRM Lookup

## Overview

Answer natural-language questions about the SPIE CRM by invoking the `spie` CLI with `--json` and parsing structured output. Audience is SPIE engineers who already know SPIE's event/symposium/conference/session vocabulary — don't over-explain.

## Prerequisite

The `spie` binary must be on PATH. Verify once per session with `which spie`. If missing, tell the user the skill requires `spie-cli` to be installed and stop.

## Core rules

- **Always pass `--json`.** Never parse the formatted/colored table output.
  The one exception is `--qr` (see below): the scannable code only exists in the
  terminal rendering, so that flag is run *without* `--json` when the user wants
  to scan it.
- **Pass `--verbose` when the user needs detail** that isn't in the default output: chairs for a conference, presentations/roles for a session, authors for a paper, exhibit list for a symposium, contact email for a badge, etc. Default output stays lean.
- **Don't ask for clarification before trying.** Make the best guess at which command + identifier applies and run it; if the CLI returns an error, iterate. Faster than a clarifying round-trip.
- **Don't invent flags.** The commands below are the full set. If unsure, run `spie <cmd> --help`.
- **Default environment is `dev`**, but a user-configured default may override that (check `spie config` if it matters). Honor explicit cues: "in test", "on prod" → pass `--env test` or `--env prod`.
- **Error shape is `{"error": "..."}`.** If you see this, surface the message to the user and try a different identifier shape before giving up.
- **SPIE codes trigger this skill.** Bare codes like `PW26`, `EOD26`, `BO100`, `13292-11` are SPIE identifiers even without "SPIE" in the question.

## Efficient querying

The point of this skill is to beat a CRM Advanced Find or a hand-written SQL query on speed. Stay lean:

- **One CLI call per question** when possible. Don't pre-flight with `head -c`, `--help`, or schema checks — just run the real query.
- **Don't re-pipe the same JSON through multiple `jq` passes.** Pick one filter and run it once. If you need several fields, compute them in a single `jq` expression or (better) just read the raw JSON.
- **For counts, pipe to `jq length`.** `spie exhibitor PW26 --json | jq length` — no object wrapping, no extra aggregation.
- **For lists (any length), format in the response, not via shell.** Once the JSON is back from the CLI, Claude already has the data in context — write the markdown list directly in the answer. Do **not** `jq -r` a formatted string and expect the user to see it; Claude Code truncates long `Bash` stdout in the UI (user has to hit ctrl-o), so the list often appears delivered but is invisible. Never write to `/tmp` and Read it back as a workaround.
- **Skip `jq` entirely** when the raw JSON already answers the question (single-record lookups, or lists short enough to just read).

## Workflow

```dot
digraph spie_lookup {
    "User question" [shape=box];
    "Identify entity + identifier" [shape=diamond];
    "Pick command" [shape=box];
    "Run with --json (+ --verbose if detail needed)" [shape=box];
    "Error?" [shape=diamond];
    "Try different identifier / command" [shape=box];
    "Summarize JSON for user" [shape=box];

    "User question" -> "Identify entity + identifier";
    "Identify entity + identifier" -> "Pick command";
    "Pick command" -> "Run with --json (+ --verbose if detail needed)";
    "Run with --json (+ --verbose if detail needed)" -> "Error?";
    "Error?" -> "Try different identifier / command" [label="yes"];
    "Try different identifier / command" -> "Run with --json (+ --verbose if detail needed)";
    "Error?" -> "Summarize JSON for user" [label="no"];
}
```

## Command reference

All commands support these global flags: `--json`, `--verbose` (`-v`), `--env <dev|test|prod>` (`-e`). Arguments accept GUID, event ID, or a smart-resolved domain identifier (SPIE code, email, paper number, etc.).

### Entity map

| User mentions… | Command | Minimal args |
|---|---|---|
| A symposium (PW26, EOD26, AS26, …) or sub-symposium (PW26B, AVR26, …) | `spie symposium <query>` | 1 |
| A person (email, web username, SPIE ID, GUID) | `spie person <query>` | 1 |
| A registration ("is X registered for Y") | `spie registration <symposium> <person>` | 2 |
| Registrations at a show (count, list, filter, fuzzy person search) | `spie registration <symposium> [<partial>] [flags]` | 1 |
| A badge number at a symposium | `spie badge <symposium> <badge>` | 2 |
| A badge QR code (lead retrieval) | `spie badge <symposium> <badge> --qr` | 2 |
| CRM personas for a person at a symposium | `spie persona <symposium> <person>` | 2 |
| Exhibitors at a show (list or one company) | `spie exhibitor <symposium> [<query>]` | 1–2 |
| A paper/presentation (13292-11, PC13823-1, title) | `spie paper <query>` | 1 |
| A conference (list all at symposium, or one by code) | `spie conference <symposium> [<conference>]` | 1–2 |
| A session (by symposium+conference+number, or event ID) | `spie session <symposium> <conference> <query>` | 3 |

Aliases: `sym`/`symposium`, `contact`/`person`, `reg`/`registration`, `ex`/`exhibitor`, `pres`/`presentation`/`paper`, `conf`/`conference`, `sess`/`session`. `persona` has no alias.

### Registration list mode (v0.3.0+)

The person argument on `spie registration` is optional. Three modes, decided by what you pass:

- **Exact person** (email, SPIE ID, GUID, or a string that matches a web username) → single-person registrations, the classic shape.
- **Partial string** (no web-username match) → fuzzy search across web username, badge name, and badge company within that symposium: `spie reg PW26 millisch --json`.
- **No person** → count breakdown by category abbreviation and status, plus the 15 most recent registrations.

List flags (combine freely with each other and with a partial string):

- `--type XR,AU` — registration category abbreviations, comma-separated. Vocabulary: `XR` exhibitor, `XO` exhibit visitor only, `AU` author, `AT` attendee, `ST` student, `EO` education only, `PCT` program committee, `CH` chair, `NCH` session chair, `IN` instructor, `PS` press.
- `--status Registered,Cancelled` — friendly names: Registered, Attended, Cancelled, No Show (or `noshow`), Duplicate, Quote.
- `--limit N` — rows returned, default 15, newest first. `total` in the JSON still reflects ALL matches.
- `--count` — breakdown only, no rows. Best answer for "how many registered".

Gotchas:
- Duplicate and Quote registrations are excluded from everything unless explicitly named in `--status`.
- List flags are **rejected** when the person resolves to an exact contact — don't combine `--type` etc. with an email/SPIE ID.
- A partial string that happens to be a real web username takes the exact path. If the user clearly wanted a fuzzy search, retry with a longer/shorter fragment that isn't a username.

### Badge QR codes (v0.4.0+)

`--qr` on `badge` or `registration` shows the lead-retrieval QR code that
exhibitors and staff scan off an attendee's badge. It prints the normal
registration table first, then the code.

**This is the one place the always-`--json` rule is wrong.** The scannable
artifact only exists in the terminal rendering:

- **User wants to scan it** (testing lead retrieval, checking a badge at a
  show) → run **without** `--json` so the code renders. Then tell them it's
  displayed above your response; don't try to reproduce the code yourself.
- **User wants the encoded data** ("what does it scan as?", "which SPIE ID is
  on that badge?") → run with `--json` and read `qr.payload`.

Both commands take it, whichever identifier is handier:

```
spie badge PW26 388526 --qr            # by badge number
spie reg PW26 kevinm@spie.org --qr     # by person
spie badge PW26 388526 --qr --json     # payload only, no art
spie badge PW26 388526 --qr --qr-invert  # if a scanner rejects the default
```

JSON shape — the `qr` key is added alongside `registrations`:

```
qr: { payload, badgeNumber, firstName, lastName, spieId, symposiumCode,
      generatedOn, annotationId }
```

`payload` is the raw scanned string, format
`badgeNumber;firstName;lastName;spieId;symposiumCode`. The PNG bytes are
deliberately not in the JSON — there's nothing useful to do with a base64 blob.

Gotchas:

- **`--qr` needs a specific person.** It's rejected in `reg` list mode and
  alongside `--type`/`--status`/`--limit`/`--count`, since there's no single
  registration to take a code from.
- **The payload's symposium code is the parent show.** A registration held
  against a sub-symposium (`PW26B`) still scans as `PW26`. When they disagree,
  the payload wins — that's what a scanner reads.
- **Multiple registrations → the newest one's code is shown**, with a note
  saying which. CRM regenerates the code on every badge reprint, and for a
  transferable exhibitor badge the *name* can change between reprints, so the
  newest is the current holder rather than just a duplicate.
- **Absent QR is normal on older records.** If the CLI reports no QR attached,
  say so plainly rather than retrying.
- `badge.pdf` notes also exist in CRM but are **not** exposed by the CLI: dev
  and test only ever received a one-off bulk run in Jan 2025, so they're
  missing for essentially every recent show. Don't offer badge PDFs.

### Smart-resolution rules

- **Symposium code** — 2-4 letters + 2 digits (+ optional 1-letter suffix): `PW26`, `EOD26`, `AS26`, `PW26B`, `AVR26`.
- **Conference code** — letters + digits, usually 5 chars: `BO100`, `OSD06`, `AL101`. Always scoped under a symposium.
- **Paper number** — `<conf#>-<seq>`, e.g. `13292-11`; may have `PC` prefix for late/prerecorded: `PC13823-1`.
- **Session** — composed as `<conf#>-<seq>`, e.g. `13823-1`. Not directly resolvable by that string; look up via `spie session <symposium> <conference> <sessionNumber>` (the symposium may be the parent, e.g. `PW26`, or a sub-symposium like `PW26B` — the CLI resolves either) or by event ID.
- **Event ID** — integer (typically 7 digits, e.g. `8100174`). Works as a direct identifier on most commands.
- **SPIE ID** — integer person identifier (e.g. `4284005`).
- **Badge number** — integer, 6 digits (e.g. `388526`). Always paired with a symposium.
- **Email / web username** — natural form; `kevinm@spie.org` or `kevinmatspie`.
- **GUID** — full 36-char UUID; works anywhere an entity accepts one.

### Choosing default vs. verbose

Default output is enough for:
- "Where is PW26?" → `spie symposium PW26 --json`
- "Who is badge 388526 at PW26?" → `spie badge PW26 388526 --json`
- "What conferences are at EOD26?" → `spie conference EOD26 --json`

Use `--verbose` when the user's question requires nested data:
- **symposium** verbose → sub-symposiums + exhibitions list
- **person** verbose → extra contact detail (same schema, richer fields)
- **conference** verbose → `sessions[]` + `chairs[]`
- **session** verbose → `roles[]` (chairs/organizers) + `presentations[]`
- **paper** verbose → authors with emails/SPIE IDs
- **exhibitor** verbose → booths already included, but verbose adds booth-staff detail where present
- **registration**/**badge** verbose → expanded contact fields (e.g. email)
- **registration**/**badge** `--qr` → badge QR code; orthogonal to `--verbose`

Only climb to verbose when you actually need those fields; it's significantly more data.

## JSON shape cheat sheet

Non-exhaustive — just enough to know what to extract without a second round trip.

**`spie symposium PW26 --json`** → object: `{uniqueIdentifier, eventId, code, name, city, state, country, venue, startDate, endDate, webStatus, timezone, location, subSymposiums[], exhibitions[]}`. `subSymposiums[]` is populated only in `--verbose`.

**`spie person kevinm@spie.org --json`** → object: `{uniqueIdentifier, spieId, email, webUsername, firstName, lastName, company, jobTitle, phone, gender, profile}`.

**`spie registration PW26 <person> --json`** and **`spie badge PW26 388526 --json`** → same shape:
```
{
  symposium: { code, name, eventId },
  contact:   { firstName, lastName, spieId },
  registrations: [ { uniqueIdentifier, symposiumCode, badgeFirstName, badgeLastName, badgeCompany, badgeNumber, category, technicalPass, registrationType, registeredOn, badgeName, status, confirmationLevel } ]
}
```

**`spie registration PW26 --json`** (list mode, no person) → `{symposium: {code, name, eventId}, total, byType: [{abbreviation, typeName, count}], byStatus: [{status, count}], recent: []}`. With `--count`, same minus `recent`.

**`spie registration PW26 <partial-or-filters> --json`** (fuzzy/filtered) → `{total, matches: []}` where `matches[]` rows are registration objects plus `webUsername` and `spieId`; `total` counts all matches, `matches` is capped by `--limit`. Zero matches → `{error}`.

**`spie conference PW26 [code] --json`** → array of conferences: `{uniqueIdentifier, eventId, conferenceCode, programDisplayNumber, conferenceNumber, title, symposiumCode, room, startDateTime, endDateTime, callForPapersUrl, sessions[], chairs[]}`. `sessions[]` and `chairs[]` populate under `--verbose`.

**`spie session <sym> <conf> <num> --json`** → array of sessions: `{uniqueIdentifier, eventId, sessionNumber, title, room, startDateTime, endDateTime, duration, conferenceCode, conferenceTitle, conferenceNumber, symposiumCode, sessionId, sessionType, roles[], presentations[], presentationCount}`. `roles[]` and `presentations[]` populate under `--verbose`.

**`spie paper <query> --json`** → array of papers: `{uniqueIdentifier, paperNumber, trackingNumber, eventId, title, conferenceCode, conferenceTitle, symposiumCode, startDateTime, duration, primaryAuthor, contactAuthor, abstractSubmissionDate, publicationDate, status, presentationType}`. Title searches return many rows; narrow by conference or symposium when possible.

**`spie exhibitor <sym> [<query>] --json`** → array of exhibitors: `{uniqueIdentifier, spieExhibitorId, companyName, accountName, exhibitionName, symposiumCode, cancelled, confirmed, primaryContact*, website, city, country, phone, technicalPasses, displayName, location, exhibitType, confirmationLevel, booths[]}`. Omit the query to list every exhibitor at the show (large).

Field notes for exhibitors:
- `cancelled: true` means the booking was pulled — exclude from "active exhibitors" counts.
- Don't volunteer `confirmed` in summaries unless the user specifically asks about it.
- `confirmationLevel` (string) is the human-readable status; `"Confirmed"` is typical.
- `booths[]` is present for assigned exhibitors; empty for pending.

## Common question patterns

| Question | Command |
|---|---|
| "What's PW26?" / "When is PW26?" | `spie symposium PW26 --json` |
| "What sub-events are part of PW26?" | `spie symposium PW26 --verbose --json` |
| "Who is kevinm@spie.org?" | `spie person kevinm@spie.org --json` |
| "Is Kevin registered for PW26?" | `spie registration PW26 kevinm@spie.org --json` |
| "How many people are registered for PW26?" | `spie reg PW26 --count --json` → read `total`, `byType` |
| "List exhibitor registrations at PW26" | `spie reg PW26 --type XR --json` (raise `--limit` for more rows) |
| "Who cancelled their PW26 registration?" | `spie reg PW26 --status Cancelled --json` |
| "Find a PW26 registration for someone named Millischer" | `spie reg PW26 millisch --json` (fuzzy) |
| "What personas does Kevin have at PW26?" | `spie persona PW26 kevinm@spie.org --json` |
| "Who has badge 388526 at PW26?" | `spie badge PW26 388526 --json` |
| "Email for badge 388526 at PW26?" | `spie badge PW26 388526 --verbose --json` |
| "Show me the QR code for badge 388526" | `spie badge PW26 388526 --qr` (no `--json` — see QR section) |
| "What does Kevin's PW26 badge scan as?" | `spie reg PW26 kevinm@spie.org --qr --json` → read `qr.payload` |
| "What conferences are happening at EOD26?" | `spie conference EOD26 --json` |
| "Who chairs BO100 at PW26?" | `spie conference PW26 BO100 --verbose --json` → read `chairs[]` |
| "What sessions are in BO100?" | `spie conference PW26 BO100 --verbose --json` → read `sessions[]` |
| "Who chairs session 1 of BO100?" | `spie session PW26 BO100 1 --verbose --json` → read `roles[]` |
| "Papers in session 13823-1" | `spie session PW26 BO100 1 --verbose --json` → read `presentations[]` |
| "Show me paper 13292-11" | `spie paper 13292-11 --json` |
| "Find papers about quantum dots" | `spie paper --title "quantum dots" --json` |
| "Is 2b-special exhibiting at PW26?" | `spie exhibitor PW26 "2b-special" --json` |
| "List all exhibitors at PW26" | `spie exhibitor PW26 --json` → render list in response |
| "How many exhibitors at PW26?" | `spie exhibitor PW26 --json \| jq length` |
| "How many active exhibitors at PW26?" | `spie exhibitor PW26 --json \| jq '[.[] \| select(.cancelled \| not)] \| length'` |

## Responding to the user

- Summarize the JSON; don't dump it. Users want "Kevin Mills, badge 388526, Exhibitor category, registered 2025-12-24", not the raw object.
- Include the key identifiers (SPIE ID, badge #, event ID, paper #) when relevant so the user can pivot to another lookup.
- **When the user asks for a list, render it in your response as a markdown list** built from the JSON you already have. Do not rely on shell-formatted output reaching the user — Claude Code truncates long `Bash` stdout (the user has to hit ctrl-o to expand), so a `jq -r` pretty-print often looks delivered but isn't visible.
- For long lists, render everything (or the top N with a total count) in the response text; offer to narrow with a follow-up filter.
- Quote the command you ran so the user can repeat or adjust it.
- **After rendering a QR (`--qr` without `--json`), just say it's displayed
  above and give the decoded payload as text.** Never try to redraw the code in
  your reply — block characters retyped by hand won't scan. If the terminal
  output was truncated, tell the user to hit ctrl-o rather than re-running.
- For cross-environment answers, state which environment you queried.
