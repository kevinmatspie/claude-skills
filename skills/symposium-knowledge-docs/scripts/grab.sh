#!/usr/bin/env bash
# grab.sh — Fetch one SPIE page, clean it, and save it by title for a chatbot KB.
#
# Two-fetch design, and the reason for it:
#   • ?tfrm=5 (raw Ingeniux XML) is the reliable source of METADATA — the page ID (used
#     to dedupe across sections) and the signals that mark a dynamic search widget
#     (exhibitor roster / program search). But its body is NOT safe to publish: it dumps
#     every CMS field, including non-rendered authoring-helper copy that can contain stale
#     example text from a previous event. (We found Tokyo/Yokohama airport info buried in
#     a Copenhagen page this way.)
#   • ?tfrm=1 (the published render) is the source of CONTENT — exactly what the public
#     sees, with the stale hidden fields gone. We strip its site chrome via extract.mjs.
#
# So: fetch tfrm=5 to decide (dedupe? widget? title), then fetch tfrm=1 to capture clean
# content. Two small GETs per page is negligible for these ~dozens-of-pages runs and keeps
# both the robust dedupe/widget logic AND correct, publish-accurate output.
#
# Usage:
#   grab.sh <url-without-tfrm> <output-dir> <manifest-file> [--keep-widget]
#
# Exit codes:
#   0  saved a new file
#   3  skipped — duplicate page ID (already saved this run)
#   4  skipped — not a CMS page / no title (likely external or redirect)
#   5  fetch failed (curl error or empty body)
#   6  skipped — dynamic list widget (exhibitor roster / program search)
#   7  extraction failed (tfrm=1 fetch or extract.mjs error)
#
# Pass --keep-widget to override exit 6 and capture a widget page anyway (rarely wanted).
#
# Prints one TSV status line to stdout: <status>\t<page_id>\t<filename-or-url>
# where status is one of: SAVED, DUP, SKIP, WIDGET, ERROR

set -uo pipefail

url="${1:?usage: grab.sh <url> <output-dir> <manifest-file> [--keep-widget]}"
outdir="${2:?missing output dir}"
manifest="${3:?missing manifest file}"
keep_widget=0
[[ "${4:-}" == "--keep-widget" ]] && keep_widget=1

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
extractor="${here}/extract.mjs"

# Build tfrm URLs, preserving any existing query string.
sep='?'; [[ "$url" == *\?* ]] && sep='&'
meta_url="${url}${sep}tfrm=5"
page_url="${url}${sep}tfrm=1"

mkdir -p "$outdir"
touch "$manifest"

# ---- Pass 1: metadata from the raw XML view ----
meta="$(curl -fsSL --max-time 60 "$meta_url" 2>/dev/null)"
if [[ -z "$meta" ]]; then
  printf 'ERROR\t-\t%s\n' "$url"
  exit 5
fi

# Page ID lives in the root element: <PageBuilderTemplate ID="x138816" ...> etc.
page_id="$(printf '%s' "$meta" | perl -0777 -ne 'print "$1" if /\bID="(x\d+)"/')"

# Widget guard: a known search root element, or a <SearchType> field (present only on the
# program/session search page, never on normal content). Skip by default.
if [[ "$keep_widget" -eq 0 ]] && \
   printf '%s' "$meta" | grep -qE '<(ExhibitorListSearch|ProgramSearch|SessionSearch|PaperSearch)\b|<SearchType\b'; then
  printf 'WIDGET\t%s\t%s\n' "${page_id:--}" "$url"
  exit 6
fi

# Dedupe by page ID across the run.
if [[ -n "$page_id" ]] && grep -q "^${page_id}	" "$manifest" 2>/dev/null; then
  printf 'DUP\t%s\t%s\n' "$page_id" "$url"
  exit 3
fi

# Title for the filename — from the raw <Title>, with <Header> fallback for widget-style
# templates. (We name from tfrm=5's title rather than tfrm=1's <title> tag because the raw
# title is the clean CMS page name without the " | SPIE ..." suffix the rendered tag adds.)
title="$(printf '%s' "$meta" | perl -0777 -ne '
  my $t;
  if (/<Title\b[^>]*>(.*?)<\/Title>/s)      { $t = $1; }
  elsif (/<Header\b[^>]*>(.*?)<\/Header>/s)  { $t = $1; }
  if (defined $t) {
    $t =~ s/<!\[CDATA\[(.*?)\]\]>/$1/gs;
    $t =~ s/<[^>]+>//g;
    $t =~ s/&amp;/and/g; $t =~ s/&lt;/</g; $t =~ s/&gt;/>/g;
    $t =~ s/&quot;/"/g; $t =~ s/&#39;/'"'"'/g;
    $t =~ s/\s+/ /g; $t =~ s/^\s+//; $t =~ s/\s+$//;
    print $t;
  }
')"

if [[ -z "$title" ]]; then
  printf 'SKIP\t%s\t%s\n' "${page_id:--}" "$url"
  exit 4
fi

# Filesystem-safe filename; keep it readable (titles include "+", commas, parens).
safe="$(printf '%s' "$title" | sed 's#[/:]#-#g; s#[\\*?"<>|]##g; s#  *# #g; s#^ *##; s# *$##')"

# ---- Pass 2: published content, cleaned ----
tmp_in="$(mktemp)"; trap 'rm -f "$tmp_in"' EXIT
if ! curl -fsSL --max-time 60 "$page_url" -o "$tmp_in" || [[ ! -s "$tmp_in" ]]; then
  printf 'ERROR\t%s\t%s (tfrm=1 fetch failed)\n' "${page_id:--}" "$url"
  exit 7
fi

if ! node "$extractor" "$tmp_in" "${outdir}/${safe}.html" >/dev/null 2>&1; then
  printf 'ERROR\t%s\t%s (extract.mjs failed)\n' "${page_id:--}" "$url"
  exit 7
fi

printf '%s\t%s\t%s\n' "${page_id:--}" "${safe}.html" "$url" >> "$manifest"
printf 'SAVED\t%s\t%s\n' "${page_id:--}" "${safe}.html"
exit 0
