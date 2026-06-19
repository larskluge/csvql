# csvql — macOS QuickLook & Viewer for CSV/TSV Files

## Overview

csvql is a macOS app that provides a rich, dark-themed preview of CSV and TSV files. It consists of a QuickLook extension (static scrollable table) and a host app (with search, sort, filter, row selection, density controls). Content-based delimiter detection supports tabs, commas, semicolons, and pipes. Per-column type inference colors numbers, dates, booleans, links, emails, and SHA hashes distinctively.

## Architecture

### Targets

Four targets in one Xcode project:

1. **csvql** — Host app (document-based, opens CSV/TSV with full interactivity)
2. **csvqlPreview** — QuickLook extension (.appex, static scrollable table)
3. **csvqlTests** — Unit tests
4. **csvql-screenshot** — CLI for generating screenshots (low priority)

No XPC service. No external dependencies — macOS built-in frameworks only (WebKit, QuickLookUI, Cocoa).

### Deployment

- **macOS 12.0+**
- **Xcode 15.0+**
- Dark theme only (no light mode)

### UTIs

- `public.comma-separated-values-text` (.csv)
- `public.tab-separated-values-text` (.tsv, .tab)

### Shared Code

Shared between host app and QuickLook extension:

- **CSVParser** — state-machine parser handling quoted fields, `""` escapes, embedded delimiters, `\r\n` and `\n` line endings
- **DelimiterDetector** — content-based detection by counting candidate delimiters (tab, comma, semicolon, pipe) outside quoted fields in first 10 lines; picks the most consistent non-zero count
- **TypeInferrer** — per-column scan; if >80% of non-empty values match a type, column gets that type. Priority: bool → number → date → link → email → sha → text
- **CSVRenderer** — generates complete self-contained HTML document with embedded CSS and data
- **preview.css** — all design tokens and styling

### Rendering Approach

WKWebView + HTML/CSS (same approach as mdql). Single self-contained HTML string — no external resources. CSS embedded in `<style>`, data injected as JSON in `<script>`, table built via JS from that data.

QuickLook extension calls `CSVRenderer.render()` for a static table. Host app calls `CSVRenderer.render(interactive: true)` which adds JS for sort, filter, search, and row selection.

### No File Watching

Neither the QuickLook extension nor the host app watches for file changes. The file is read once on load.

## Rendering Pipeline

### CSV Processing (Swift)

1. **Read file** — read bytes, detect encoding (UTF-8 default, BOM-aware for UTF-16)
2. **Detect delimiter** — scan first 10 lines, count occurrences of each candidate (tab, comma, semicolon, pipe) outside quoted fields, pick the most consistent non-zero count
3. **Parse** — state machine: quoted fields with `""` escapes, embedded delimiters inside quotes, `\r\n` and `\n` line endings. Returns `(headers: [String], rows: [[String]])`
4. **Infer types** — scan each column, >80% match threshold. Priority: bool → number → date → link → email → sha → text
5. **Render HTML** — complete HTML document with metadata (filename, file size, delimiter name, encoding, line ending style, modified date)

### HTML Structure

```
DOCTYPE → html → head (meta, style) → body
  → .ql-window
    → .titlebar (filename, row/col/size meta)
    → .sub-toolbar (path breadcrumb, delimiter pill, encoding pill, [search if interactive])
    → .table-container (scrollable)
      → table with sticky header + sticky row-number column
    → .footer (row count, col count, size, modified, LF/CRLF, encoding, csvql badge)
```

## QuickLook vs Host App

| Feature | QuickLook | Host App |
|---------|-----------|----------|
| Search/filter | No | Yes |
| Column sort | No | Yes |
| Row selection | No | Yes |
| Titlebar close/fullscreen buttons | No (OS provides) | Yes |
| Density toggle | No (regular) | Yes (compact/regular/comfortable) |
| Row numbers | Yes (always) | Yes (always) |
| Zebra striping | Yes (always) | Yes (always) |

## Cell Rendering Rules

Each column gets a type from inference. Cells render based on their column type:

| Type | Font | Color | Alignment | Special behavior |
|------|------|-------|-----------|-----------------|
| text | SF Pro 12.5px | `#d4d0d2` | left | Status keywords render as pills |
| number | SF Mono 12 | `#e0c990` | right | `tabular-nums`, en-US locale formatting, preserves original decimal places |
| date | SF Mono 11.5 | `#c2a5d6` | left | Time portion in `#5a5658` 10.5px with 6px gap |
| bool | SF Mono 11 | — | left | Rendered as pill |
| link | SF Mono 11.5 | `#6cb0e0` | left | Strips scheme + trailing slash, 1px dotted bottom border |
| email | SF Mono 11.5 | `#6cb0e0` | left | No underline |
| sha | SF Mono 12 | `#d4d0d2` | left | Code chip bg `rgba(255,255,255,0.08)`, 3px radius |
| empty | SF Pro 11 italic | `#5a5658` | — | Em-dash `—` |

### Type Inference Patterns

- **bool**: case-insensitive `true` or `false`
- **number**: matches `^-?\d+(\.\d+)?$`
- **date**: `YYYY-MM-DD` or `YYYY-MM-DDTHH:MM:SS[Z]`
- **link**: starts with `http://` or `https://`
- **email**: matches standard email pattern
- **sha**: column name is `sha` and value matches `^[0-9a-f]{6,}$`

### Pill Variants

| Keyword | Text color | Background | Dot color |
|---------|-----------|------------|-----------|
| success / true | `#a8d4a0` | `rgba(142,192,124,0.13)` | `#8ec07c` |
| failed | `#dfa3a3` | `rgba(201,122,122,0.15)` | `#c97a7a` |
| false | `#9a8a8c` | `rgba(255,255,255,0.05)` | `#6e6466` |
| production | `#dfa3a3` | `rgba(201,122,122,0.12)` | `#c97a7a` |
| staging | `#e0c990` | `rgba(224,201,144,0.12)` | `#e0c990` |
| preview | `#c2a5d6` | `rgba(194,165,214,0.12)` | `#c2a5d6` |

Pill structure: 5px circular dot with `box-shadow: 0 0 6px` glow, then label text. Padding `2px 7px 2px 6px`, 4px radius, SF Mono 11.

## Layout & Chrome

### Titlebar (52px)

- Background: `linear-gradient(180deg, #2a2a2a, #232323)`, bottom border 1px `#2e2e2e`

**QuickLook version:**
- No close/fullscreen buttons (OS provides)
- Center: filename in SF Pro 13.5px/600 `#d4d0d2`, meta line below in SF Mono 10.5px `#8a8588` showing `{rows} rows · {cols} cols · {size}` with `·` in `#5a5658`

**Host app version:**
- Left side: close button (22x22 circle, `#2e2e2e` bg, `×` stroke, hover `#3a3a3a`) + fullscreen button (26x26, corner brackets icon)
- Center: same as QuickLook version
- No right-side buttons

### Sub-toolbar (42px)

- Background `#1f1f1f`, bottom border 1px `#2e2e2e`
- Left: file path breadcrumb in SF Mono 11px, progressively brighter segments, final segment full `#d4d0d2`
- Right: delimiter pill + encoding pill
  - Pills: `rgba(255,255,255,0.08)` bg, 5px radius, SF Mono 10.5px, label in `#5a5658`, value in `#d4d0d2`
- Host app adds: search box (26px tall, 220px wide, `#171717` bg, 1px `#2e2e2e` border, 6px radius, magnifier icon `#5a5658`, SF Pro 12px input, match count right-aligned in `#5a5658`)

### Table

- Background `#1a1a1a`
- Sticky header row: 38px, `#262626` bg, bottom border 1px `#444`, SF Mono 11/600 lowercase, `#8a8588` color
- Sticky row-number column: 54px wide, right-aligned, SF Mono 10.5px, `#5a5658`, 1px right border `#2e2e2e`
- Row heights: 34px default. Host app toggles: compact (26px), regular (34px), comfortable (42px)
- Zebra: odd rows `#1c1c1c`, even rows transparent. Always on.
- Cell padding: 14px horizontal
- Column widths:
  - Numeric: `minmax(90px, 130px)`
  - Link: `minmax(180px, 1fr)`
  - Other: `minmax(120px, 1fr)`

**Host app only:**
- Sort: click header → asc, click again → desc, third click → unsorted. Active sort shows 8x8 filled triangle in `#6cb0e0`. Numeric sort uses `parseFloat`, everything else uses `localeCompare`.
- Filter: search box live-filters rows where any cell (case-insensitive) contains query. Filtered count in search box and footer.
- Row selection: click any cell selects entire row, background `rgba(108,176,224,0.22)`

### Footer (28px)

- Background: `linear-gradient(180deg, #1f1f1f, #1a1a1a)`, top border 1px `#2e2e2e`
- SF Mono 10.5px, labels `#5a5658`, values `#8a8588`
- Left: `rows {n}` (host app: `rows {filtered}/{total}` when filtering), `cols {n}`, `size {kb}`, `modified {ago}`
- Right: line ending type (LF/CRLF), encoding (UTF-8), green dot (`#8ec07c` with `box-shadow: 0 0 6px`) + `csvql` label

## Design Tokens

```css
--text:         #d4d0d2
--text-dim:     #8a8588
--text-faint:   #5a5658
--bg:           #1a1a1a
--bg-elev:      #202020
--bg-soft:      #242424
--bg-window:    #1d1d1d
--bg-titlebar:  #262626
--link:         #6cb0e0
--link-soft:    rgba(108,176,224,0.14)
--border:       #444
--border-soft:  #2e2e2e
--code-bg:      rgba(255,255,255,0.08)
--blockquote:   #666
--num:          #e0c990
--bool-true:    #8ec07c
--bool-false:   #c97a7a
--date:         #c2a5d6
--selection:    rgba(108,176,224,0.22)
```

### Typography

- UI text: **SF Pro** (system font) 400/500/600/700
- Mono / data: **SF Mono** 400/500/600

### Spacing

- Cells: 14px horizontal padding throughout
- Titlebar/sub-toolbar/footer: 14px gutters
- Border radii: 4px (pills), 5px (small pills), 6px (buttons, search)

### Transitions

- `transition: background 80ms` on cells
- `transition: all 120ms` on close button

## Interactions Summary

- **Open file**: read bytes, detect encoding, detect delimiter (content-based), parse, infer types, render
- **Sort** (host app): click header cycles asc → desc → unsorted
- **Filter** (host app): live case-insensitive substring match across all cells
- **Row select** (host app): click selects entire row
- **Density** (host app): compact (26px) / regular (34px) / comfortable (42px)
- **No hover state** on rows — keep cells calm
- **No file watching** — file read once on load

## Build & Install

Makefile with targets mirroring mdql:

- `make install` — build Release, copy to /Applications, register with lsregister + pluginkit
- `make test` — run unit tests
- `make clean` — clean build artifacts

Install script handles registration cleanup (stale lsregister/pluginkit entries) and app launch for pluginkit finalization.

## Test Fixtures

Three sample datasets (from design spec) for testing:

- `sales_q4_2025.csv` — orders with mixed text, currency, dates, booleans, URLs
- `observatory_log.tsv` — tab-delimited timestamps + floats + sparse note column
- `deploys.csv` — git SHAs, emails, environment values, status pills

All test data must be fully anonymized — no real names, phone numbers, or PII.
