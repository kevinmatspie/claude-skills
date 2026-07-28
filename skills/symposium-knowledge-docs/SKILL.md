---
name: symposium-knowledge-docs
description: Use when capturing SPIE symposium website content as clean HTML files to feed a chatbot/Copilot knowledge source — e.g. "grab the presenter pages for AS26 into knowledge docs", "pull the exhibition section for the chatbot", "scrape the symposium site for the bot", or when the user points you at a spie.org symposium/section URL and wants the supporting pages saved. Builds a per-symposium folder of cleaned, published-content HTML pages named by page title. Skips dynamic rosters and external apps (floor plans, exhibitor lists).
---

# Symposium Knowledge Docs

## Overview

Capture the content-rich pages of a SPIE symposium website as clean, minimal HTML files,
one per page, named by page title — ready to drop into a chatbot/Copilot knowledge source.

SPIE runs on the Ingeniux CMS, whose pages can be fetched in two views via a `?tfrm=` query
param. The skill uses **both, deliberately**:

- **`?tfrm=1`** is the *published render* — exactly what the public sees. This is the source
  of truth for CONTENT.
- **`?tfrm=5`** is the *raw XML* of every CMS field. It's the source of METADATA (the page
  ID, the title, and the signals that flag a dynamic search widget).

Why not just use the raw view for content? Because `?tfrm=5` dumps **non-rendered** fields
too — including authoring-helper copy the public never sees. On at least one real page that
held stale example text from a *previous* event (Tokyo/Yokohama airport info sitting in a
Copenhagen travel page). Feeding that to a bot would make it confidently wrong. So content
must come from the published `?tfrm=1` render, with the surrounding site chrome stripped.

**Audience:** SPIE engineers prepping per-event chatbot knowledge bases. You'll run this
once per symposium as new events come online. Be terse; they know the event vocabulary.

## What this does and doesn't grab

- **Grabs:** real content pages — presenter instructions, exhibition info, sponsor info,
  attendee/general info, manuscript and policy pages. These are the "supporting documents"
  a chatbot answers from.
- **Skips:** external apps (ExpoCAD floor plans on `*.expocad.com`), transactional funnels
  (registration, e-commerce), and dynamic list widgets whose real data loads client-side
  (the live exhibitor roster on `/exhibition/exhibitors`, the program search on
  `/program/browse-program`). These widget pages render from a `?tfrm=5` template like
  `ExhibitorListSearch` and carry only a header + intro blurb — the actual roster/program is
  NOT in the raw content. **Always skip them, regardless of how the request is phrased.** Their
  thin CMS shell adds nothing a chatbot can answer from, so saving it just dilutes the knowledge
  base with a near-empty file. (If the user ever explicitly says they want that shell, you can
  grab it, but never do so by default — and never chase the live roster itself.)

Always report what you skipped so the user can override case-by-case.

## The core tools: scripts/grab.sh + scripts/extract.mjs

`scripts/grab.sh` does the deterministic per-page work. For each page it fetches `?tfrm=5`
for metadata (page ID, title, widget detection), and if the page is a keeper, fetches
`?tfrm=1` and pipes it through `scripts/extract.mjs` to produce clean published HTML. It
dedupes by Ingeniux page ID and names the file by title. Use it for every page; don't
re-implement its logic inline.

`scripts/extract.mjs` (Node, no dependencies) takes the `?tfrm=1` render and emits a small
valid HTML document: it slices the content out from between the `#header` and `#footer`
regions (SPIE pages have no `<main>`, but those IDs reliably bracket the body), keeps only
`h1-4`/`p`/`ul`/`li`/`a`, resolves links to absolute `https://spie.org` URLs, and drops
empty headings. grab.sh calls it for you — you won't invoke it directly.

```
grab.sh <page-url-without-tfrm> <output-dir> <manifest-file> [--keep-widget]
```

It prints one TSV status line and sets an exit code:

| Status | Exit | Meaning |
|--------|------|---------|
| `SAVED`  | 0 | New file written |
| `DUP`    | 3 | Page ID already saved this run — skipped |
| `SKIP`   | 4 | No title/header — not a content page (external/dynamic) |
| `ERROR`  | 5 | Metadata fetch (`?tfrm=5`) failed |
| `WIDGET` | 6 | Dynamic search page (exhibitor roster / program search) — skipped by default |
| `ERROR`  | 7 | Content fetch (`?tfrm=1`) or extraction failed |

`WIDGET` is the script enforcing the always-skip rule for search-driven pages, so you get the
same result whether or not you remembered to filter them in step 3. If a user explicitly wants
a widget's shell, pass `--keep-widget` as a 4th arg to grab.sh.

The manifest file (TSV: `page_id  filename  url`) is how it dedupes across sections, so pass
the **same manifest path** for every page in a run. A page linked from two sections is
grabbed once.

## Workflow

### 1. Resolve scope and output folder

The user points you at either a **symposium root** (e.g.
`.../astronomical-telescopes-and-instrumentation`) or a **single section**
(e.g. `.../exhibition`). Derive the event code from context (the user usually says "AS26")
or ask if it's not obvious, and create a per-symposium output folder, e.g. `./<CODE>/`
(default to the current directory's convention if the user already has one, like `AS26/`).
Put the run manifest at `<output>/.manifest.tsv`.

### 2. Discover the pages to grab

This is the judgment step — do it yourself, don't script it. Fetch the **rendered** landing
page(s) with WebFetch (not `?tfrm=5`) and ask it to list every nav/sidebar/in-content link
with its resolved `/conferences-and-exhibitions/...` URL. WebFetch is right here because you
want it to *resolve* internal Ingeniux page IDs (the `x###` references) into real URLs — the
raw `?tfrm=5` view leaves them unresolved.

- **Section URL:** fetch that one page, collect its sub-page links.
- **Symposium root:** fetch the root, identify the top-level sections, then fetch each
  content-rich section landing page to collect its sub-pages. Default to the content
  sections (Presenters, Exhibition, Attendees / general info, Program info, About).

Build a flat, de-duplicated list of candidate content URLs. Drop only the things that are
never CMS content — anchors to `*.expocad.com`, `mailto:`, social media, and offsite
domains — plus the always-skip page types in the default-exclude list below.

### 3. Confirm the page list before fetching

Not every content page belongs in a chatbot knowledge base. The useful/not-useful split
is the user's call, and — importantly — it tends to be the same *types* of page across every
symposium (the city changes, the page type doesn't). So this is a confirm step, not a guess.

**Apply the default-exclude list** (page types that are reliably low-value for an event
chatbot — logistics and transactional pages whose content is just dates, prices, and
addresses):

```
# Default excludes — match on URL slug or CMS title, case-insensitive.
# These recur on every symposium site; drop them unless the user asks to keep them.
attend/registration            # registration info (logistical; the bot rarely answers from it)
attend/hotel-and-travel        # hotel/travel logistics (city-specific addresses)
hotel-and-travel/visa-information
attend/highlights              # marketing/promo highlights
```

This list is intentionally short and conservative right now. As more symposia get processed,
watch for page types that are consistently noise and add them here — that's how this list
earns its keep. When you exclude something, prefer matching the *slug* (stable across events)
over the title (varies by city/year).

**Then show the user the candidate list** grouped by section, marking which pages the
default-exclude list dropped, e.g.:

```
Presenters (7):  Information for Authors and Presenters, Abstract Submission Guidelines, ...
Exhibition (6):  SPIE ... Exhibition, Sponsors of ..., For Exhibitors, ...
Attend (4):      Attending ..., Onsite Services, Event Policies   [excluded: Registration, Hotel/Travel, Visa, Highlights]
```

Ask the user to confirm or adjust before fetching — drop more, or rescue an excluded page.
Skip this confirmation only if the user explicitly said "just grab everything" or the run is
a single small section. The point is to never waste a fetch on a page the user doesn't want,
and to surface recurring excludes worth promoting to the default list.

### 4. Grab the confirmed candidates

Loop the confirmed URLs through `grab.sh`, passing the shared manifest. Collect the status
lines. Running them sequentially is fine (it's polite to the server and these runs are small);
the script is safe to call repeatedly.

### 5. Verify and report

Don't trust exit codes alone — SPIE returns HTTP 200 even for some empty/placeholder pages.
After the run:

- Confirm each saved file is real content: it's a small valid HTML doc starting with
  `<!DOCTYPE html>`, with an `<h1>` title and real body text (not an empty shell). The
  manifest's page-ID column makes duplicates and collisions easy to spot.
- Spot-check for contamination: the whole reason for the `?tfrm=1` approach is that the old
  raw view leaked stale cross-event text. After a run, it's worth grepping the output for the
  *previous* event's city/venue (e.g. if this is Copenhagen, search for "Yokohama"/"Tokyo"/
  "San Diego"). Clean output should have none. If you find some, the extraction boundary may
  have missed a block — investigate before handing files to the user.
- Summarize for the user as a table: **filename → page ID → source URL**, plus a separate list
  of everything **SKIPPED** (with why) so they can tell you if a skipped page actually matters.
- Flag filename surprises. The filename follows the CMS `<Title>`, which sometimes differs from
  the nav label (e.g. a nav item "Prepare to Present" whose page is titled "Presentation
  Guidelines", or "Become a Sponsor" titled "Information for Sponsors"). Call these out so the
  user isn't surprised when wiring up the knowledge source — offer to rename to the nav label
  if they'd prefer that for the bot.

## Notes

- **Why curl, not WebFetch, for the grab:** WebFetch runs pages through a summarizing model and
  returns a paraphrase, not the actual page. We need the real published content (and the raw
  metadata view), so `grab.sh` uses curl. WebFetch is still the right tool for *link discovery*
  in step 2, where you specifically want it to resolve Ingeniux `x###` IDs into real URLs.
- **Output format is clean minimal HTML** — `<h1-4>`, `<p>`, `<ul>/<li>`, and `<a href>` only,
  links resolved absolute. Small (a few KB/page), valid, and friendly to KB ingesters like
  Copilot Studio. If an ingester wants plain text or markdown instead, `extract.mjs` is easy to
  extend with another output mode — ask before changing the default.
- **The two-fetch cost is intentional.** Each kept page is two small GETs (`?tfrm=5` for
  metadata, `?tfrm=1` for content). For dozens-of-pages runs that's negligible, and it's what
  lets us keep reliable ID-based dedupe + widget detection while capturing only published
  content. Don't "optimize" it to one fetch — the metadata isn't reliably present in `?tfrm=1`.
- **Re-runs:** to refresh an event, just run again into the same folder. Delete the old
  `.manifest.tsv` first if you want a clean dedupe pass, or keep it to skip unchanged pages.
