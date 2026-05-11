# csvql Implementation Progress

Plan: `docs/superpowers/plans/2026-05-11-csvql-implementation.md`
Spec: `docs/superpowers/specs/2026-05-11-csvql-design.md`

## Completed

- [x] Task 1: Project Scaffolding (xcodegen, Makefile, entitlements, Info.plists, stubs)
- [x] Task 2: Test Fixtures (sales.csv, observatory.tsv, deploys.csv)
- [x] Task 3: DelimiterDetector TDD (11 tests passing)
- [x] Task 4: CSVParser TDD (21 tests passing, unicode scalar iteration for CRLF)
- [x] Task 5: TypeInferrer TDD (16 tests passing — bool/number/date/link/email/sha/text, 80% threshold)
- [x] Task 6: CSVData Model (file loading, metadata, delimiter/encoding detection)
- [x] Task 7: CSS Design Tokens (dark theme, type coloring, status pills, density classes)
- [x] Task 8: CSVRenderer TDD (30 tests passing — HTML generation, cell rendering, interactive JS)
- [x] Task 9: QuickLook PreviewController (WKWebView + static HTML)
- [x] Task 10: Host App Document & Window (NSDocument + WKWebView + JS bridge for density/sort/filter)
- [x] Task 11: MainMenu Tests TDD (4 tests passing)
- [x] Task 12: Full Test Suite & Build Verification (82 tests passing, Release build + extension embed verified)
- [x] Task 13: Install & Manual Test (make install, extension registered, QuickLook working)

## Notes

- Fixed deploys.csv fixture: SHA values must be valid hex (0-9, a-f) for TypeInferrer detection
- Fixed project.yml: `Shared/Resources` must use `buildPhase: resources` under `sources` (not separate `resources` key) for xcodegen to include CSS
- SourceKit shows "No such module XCTest" — IDE noise, xcodebuild passes fine
- CSVParser uses Unicode.Scalar iteration (not Character) because Swift merges \r\n into a single grapheme cluster
