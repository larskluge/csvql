# csvql

A macOS app for viewing CSV and TSV files. Dark theme, type-aware rendering, and a QuickLook extension.

## Features

- **Auto-detected delimiters** — comma, tab, semicolon, pipe
- **Type inference** — numbers, dates, booleans, links, emails, SHAs get distinct formatting
- **Interactive** — sort by column, filter rows, select rows, adjust density (Compact/Regular/Comfortable)
- **QuickLook** — press Space in Finder to preview TSV files (CSV is blocked by Apple's built-in generator)
- **Headerless detection** — files without headers get auto-generated A, B, C labels

## QuickLook: CSV does not work

QuickLook preview works for **TSV files only**. CSV preview is blocked by Apple's built-in `Office.qlgenerator`, which claims the `public.comma-separated-values-text` UTI and always takes priority over third-party extensions. There is no way to override this — SIP protects the system generator from removal or modification.

This is a known, unsolvable Apple limitation that affects all third-party QuickLook extensions for CSV.

## Install

Requires Xcode and xcodegen.

```bash
brew install xcodegen
make generate
make install
```

This builds a release binary, copies it to `/Applications`, and registers the QuickLook extension.

## Build & Test

```bash
make generate    # regenerate .xcodeproj (required before any build)
make test        # build and run all tests
make clean       # clean build artifacts
```

## Architecture

```
File bytes → DelimiterDetector → CSVParser → TypeInferrer → CSVData → CSVRenderer → HTML
```

The host app uses NSDocument + WKWebView. The QuickLook extension shares the same parsing and rendering pipeline from `Shared/`.

## License

MIT
