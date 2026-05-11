# csvql Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS QuickLook extension and host app that renders CSV/TSV files as styled, dark-themed data tables with type-inferred cell coloring.

**Architecture:** WKWebView-based rendering (same approach as mdql). Shared Swift parsing/rendering code compiled into both the QuickLook extension and host app targets. HTML/CSS/JS output with embedded data — static for QuickLook, interactive (sort/filter/select) for host app. xcodegen generates the Xcode project from a declarative `project.yml`.

**Tech Stack:** Swift, WKWebView, WebKit, QuickLookUI, AppKit, xcodegen, Make

---

## File Structure

```
csvql/
├── project.yml                          # xcodegen project spec
├── Makefile                             # build/install/test targets
├── scripts/
│   └── install.sh                       # registration + cleanup
├── Shared/                              # compiled into both targets + tests
│   ├── CSVParser.swift                  # state-machine CSV parser
│   ├── DelimiterDetector.swift          # content-based delimiter detection
│   ├── TypeInferrer.swift               # per-column type inference
│   ├── CSVDocument.swift                # parsed CSV data model
│   ├── CSVRenderer.swift                # HTML generation
│   └── Resources/
│       └── preview.css                  # design tokens + table styling
├── csvql/                               # host app target
│   ├── AppDelegate.swift                # @main, NSApplication setup
│   ├── MainMenu.swift                   # app menu (Quit, Copy, Select All)
│   ├── DocumentController.swift         # NSDocument subclass
│   ├── DocumentWindowController.swift   # window hosting WKWebView
│   ├── Info.plist                       # document type registration
│   └── csvql.entitlements               # empty (unsandboxed)
├── csvqlPreview/                        # QuickLook extension target
│   ├── PreviewController.swift          # QLPreviewingController entry point
│   ├── Info.plist                       # extension registration
│   └── csvqlPreview.entitlements        # sandbox + network.client
├── csvqlTests/                          # unit tests
│   ├── CSVParserTests.swift
│   ├── DelimiterDetectorTests.swift
│   ├── TypeInferrerTests.swift
│   ├── CSVRendererTests.swift
│   ├── MainMenuTests.swift
│   └── Fixtures/
│       ├── sales.csv
│       ├── observatory.tsv
│       └── deploys.csv
└── csvql-screenshot/                    # CLI screenshot tool (low priority)
    └── main.swift
```

---

### Task 1: Project Scaffolding

**Files:**
- Create: `project.yml`
- Create: `csvqlPreview/Info.plist`
- Create: `csvqlPreview/csvqlPreview.entitlements`
- Create: `csvql/Info.plist`
- Create: `csvql/csvql.entitlements`
- Create: `Makefile`
- Create: `scripts/install.sh`

- [ ] **Step 1: Create `project.yml`**

```yaml
name: csvql
options:
  bundleIdPrefix: com.csvql
  deploymentTarget:
    macOS: "12.0"
  xcodeVersion: "15.0"
  minimumXcodeGenVersion: "2.38"

targets:
  csvql:
    type: application
    platform: macOS
    sources:
      - path: csvql
      - path: Shared
        excludes:
          - "Resources/**"
    resources:
      - path: Shared/Resources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.csvql.app
        INFOPLIST_FILE: csvql/Info.plist
        CODE_SIGN_ENTITLEMENTS: csvql/csvql.entitlements
        MACOSX_DEPLOYMENT_TARGET: "12.0"
        PRODUCT_NAME: csvql
        GENERATE_INFOPLIST_FILE: false
    dependencies:
      - target: csvqlPreview
        embed: true
        codeSign: true

  csvqlPreview:
    type: app-extension
    platform: macOS
    sources:
      - path: csvqlPreview
      - path: Shared
        excludes:
          - "Resources/**"
    resources:
      - path: Shared/Resources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.csvql.app.preview
        INFOPLIST_FILE: csvqlPreview/Info.plist
        CODE_SIGN_ENTITLEMENTS: csvqlPreview/csvqlPreview.entitlements
        MACOSX_DEPLOYMENT_TARGET: "12.0"
        PRODUCT_NAME: csvqlPreview
        GENERATE_INFOPLIST_FILE: false

  csvqlTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: csvqlTests
      - path: Shared
        excludes:
          - "Resources/**"
    resources:
      - path: Shared/Resources
      - path: csvqlTests/Fixtures
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.csvql.app.tests
        MACOSX_DEPLOYMENT_TARGET: "12.0"
    dependencies:
      - target: csvql
        embed: false

  csvql-screenshot:
    type: tool
    platform: macOS
    sources:
      - path: csvql-screenshot
      - path: Shared
        excludes:
          - "Resources/**"
    resources:
      - path: Shared/Resources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.csvql.app.screenshot
        MACOSX_DEPLOYMENT_TARGET: "12.0"
```

- [ ] **Step 2: Create `csvqlPreview/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>XPC!</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>$(MACOSX_DEPLOYMENT_TARGET)</string>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.quicklook.preview</string>
		<key>NSExtensionPrincipalClass</key>
		<string>$(PRODUCT_MODULE_NAME).PreviewController</string>
		<key>NSExtensionAttributes</key>
		<dict>
			<key>QLIsDataBasedPreview</key>
			<false/>
			<key>QLSupportedContentTypes</key>
			<array>
				<string>public.comma-separated-values-text</string>
				<string>public.tab-separated-values-text</string>
			</array>
		</dict>
	</dict>
</dict>
</plist>
```

- [ ] **Step 3: Create `csvqlPreview/csvqlPreview.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-only</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
</dict>
</plist>
```

- [ ] **Step 4: Create `csvql/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDocumentTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeName</key>
			<string>CSV Document</string>
			<key>CFBundleTypeRole</key>
			<string>Viewer</string>
			<key>LSHandlerRank</key>
			<string>Alternate</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>public.comma-separated-values-text</string>
				<string>public.tab-separated-values-text</string>
			</array>
			<key>NSDocumentClass</key>
			<string>csvql.DocumentController</string>
		</dict>
	</array>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>$(MACOSX_DEPLOYMENT_TARGET)</string>
	<key>NSMainStoryboardFile</key>
	<string></string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
```

- [ ] **Step 5: Create `csvql/csvql.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
```

- [ ] **Step 6: Create `Makefile`**

```makefile
.PHONY: install test clean generate

BUNDLE_ID := com.csvql.app.preview
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister

generate:
	xcodegen generate

install: generate
	@echo "Building csvql (Release)..."
	@xcodebuild -project csvql.xcodeproj -scheme csvql -configuration Release \
		-destination 'platform=macOS' build 2>&1 | tail -3
	@echo ""
	@BUILT="$$(xcodebuild -project csvql.xcodeproj -scheme csvql -configuration Release \
		-showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $$NF}')" && \
		scripts/install.sh "$$BUILT"
	@echo ""
	@# Verify pluginkit registration
	@FINAL="$$(pluginkit -m -v -A -i $(BUNDLE_ID) 2>/dev/null)" && \
		COUNT="$$(echo "$$FINAL" | grep -c '$(BUNDLE_ID)' || true)" && \
		if [ "$$COUNT" -gt 1 ]; then \
			echo "ERROR: $$COUNT pluginkit registrations found (expected 1):"; \
			echo "$$FINAL" | grep '$(BUNDLE_ID)'; \
			exit 1; \
		elif echo "$$FINAL" | grep -Eq '(^|[[:space:]])/Applications/csvql\.app([[:space:]/]|$$)'; then \
			echo "OK: Extension registered from /Applications"; \
		elif echo "$$FINAL" | grep -q '$(BUNDLE_ID)'; then \
			echo "WARN: Registered but not from /Applications:"; \
			echo "$$FINAL" | grep '$(BUNDLE_ID)'; \
		else \
			echo "ERROR: Extension not registered!"; \
			exit 1; \
		fi
	@# Verify no stale lsregister entries
	@STALE="$$($(LSREGISTER) -dump 2>/dev/null | grep 'path:' | grep 'csvql.app' | grep -v '.appex' | grep -Ev 'path:[[:space:]]*/Applications/csvql\.app ' | grep -v 'Application Scripts' | grep -v 'WebKit' || true)" && \
		if [ -n "$$STALE" ]; then \
			echo "WARN: Stale lsregister entries found:"; \
			echo "$$STALE" | sed 's/^/  /'; \
		else \
			echo "OK: No duplicate registrations"; \
		fi
	@echo "Done. Test with: qlmanage -p some-file.csv"

test: generate
	xcodebuild -project csvql.xcodeproj -scheme csvqlTests -destination 'platform=macOS' test

clean:
	xcodebuild -project csvql.xcodeproj -scheme csvql -configuration Release clean
```

- [ ] **Step 7: Create `scripts/install.sh`**

```bash
#!/bin/bash
set -euo pipefail

BUILT_PRODUCTS_DIR="${1:?Usage: $0 <built-products-dir>}"

APP_NAME="csvql.app"
INSTALL_DIR="/Applications"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"

# 1. Copy to /Applications and re-sign (without --deep to preserve extension signature)
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_NAME"
cp -R "$BUILT_PRODUCTS_DIR/$APP_NAME" "$INSTALL_DIR/$APP_NAME"
codesign --force --sign - "$INSTALL_DIR/$APP_NAME" 2>/dev/null || true
echo "Installed $APP_NAME to $INSTALL_DIR"

# 2. Unregister all DerivedData builds
for dir in "$DERIVED_DATA_DIR"/csvql-*/Build/Products/*/; do
    app="$dir$APP_NAME"
    [ -d "$app" ] || continue
    "$LSREGISTER" -u "$app" 2>/dev/null || true
done
"$LSREGISTER" -dump 2>/dev/null | grep 'path:' | grep "DerivedData.*$APP_NAME " | grep -v '.appex' | while read -r line; do
    path="$(echo "$line" | sed 's/.*path: *//' | sed 's/ *(0x.*//')"
    "$LSREGISTER" -u "$path" 2>/dev/null || true
done || true

# 3. Unregister stale sandbox container dirs
"$LSREGISTER" -u "$HOME/Library/Application Scripts/com.csvql.app" 2>/dev/null || true
"$LSREGISTER" -u "$HOME/Library/WebKit/com.csvql.app" 2>/dev/null || true

# 4. Register from /Applications and reset QuickLook
"$LSREGISTER" -f -R "$INSTALL_DIR/$APP_NAME"
qlmanage -r 2>/dev/null || true

# 5. Launch app to finalize pluginkit registration, then quit
if [ "${SKIP_LAUNCH:-}" != "1" ]; then
    open "$INSTALL_DIR/$APP_NAME"
    sleep 2
    osascript -e 'quit app "csvql"' 2>/dev/null || true
fi

echo "Registered $INSTALL_DIR/$APP_NAME"
```

- [ ] **Step 8: Create minimal stub files so the project compiles**

Create empty/minimal stubs for all source files so `xcodegen generate && xcodebuild build` succeeds:

`Shared/CSVParser.swift`:
```swift
import Foundation

struct CSVParser {
}
```

`Shared/DelimiterDetector.swift`:
```swift
import Foundation

struct DelimiterDetector {
}
```

`Shared/TypeInferrer.swift`:
```swift
import Foundation

enum ColumnType {
    case text, number, date, bool, link, email, sha
}

struct TypeInferrer {
}
```

`Shared/CSVDocument.swift`:
```swift
import Foundation

struct CSVData {
    let headers: [String]
    let rows: [[String]]
    let types: [ColumnType]
    let delimiter: Character
    let encoding: String
    let lineEnding: String
}
```

`Shared/CSVRenderer.swift`:
```swift
import Foundation

private class BundleAnchor {}

struct CSVRenderer {
    static let previewSize = NSSize(width: 1180, height: 780)
}
```

`Shared/Resources/preview.css`: (empty file for now)

`csvqlPreview/PreviewController.swift`:
```swift
import Cocoa
import QuickLookUI
import Quartz
import WebKit

class PreviewController: NSViewController, QLPreviewingController {
    override func loadView() {
        self.view = NSView()
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        handler(nil)
    }
}
```

`csvql/AppDelegate.swift`:
```swift
import Cocoa

@main
enum Main {
    private static let appDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.delegate = appDelegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
    }
}
```

`csvql/MainMenu.swift`:
```swift
import Cocoa

enum MainMenu {
    static func make() -> NSMenu {
        let mainMenu = NSMenu()
        mainMenu.addItem(makeAppMenuItem())
        mainMenu.addItem(makeEditMenuItem())
        mainMenu.addItem(makeViewMenuItem())
        return mainMenu
    }

    private static func makeAppMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "csvql", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "csvql")
        submenu.autoenablesItems = false
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        submenu.addItem(quit)
        item.submenu = submenu
        return item
    }

    private static func makeEditMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Edit")
        submenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        submenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        item.submenu = submenu
        return item
    }

    static func makeViewMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "View")
        submenu.addItem(NSMenuItem(title: "Compact", action: #selector(DocumentWindowController.setCompact(_:)), keyEquivalent: "1"))
        submenu.addItem(NSMenuItem(title: "Regular", action: #selector(DocumentWindowController.setRegular(_:)), keyEquivalent: "2"))
        submenu.addItem(NSMenuItem(title: "Comfortable", action: #selector(DocumentWindowController.setComfortable(_:)), keyEquivalent: "3"))
        item.submenu = submenu
        return item
    }
}
```

`csvql/DocumentController.swift`:
```swift
import Cocoa

final class DocumentController: NSDocument {
    override class var autosavesInPlace: Bool { false }
    override var isDocumentEdited: Bool { false }

    override func makeWindowControllers() {
        let wc = DocumentWindowController()
        addWindowController(wc)
    }

    override func read(from url: URL, ofType typeName: String) throws {
    }
}
```

`csvql/DocumentWindowController.swift`:
```swift
import Cocoa
import WebKit

final class DocumentWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 1180, height: 780)),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
    }
}
```

`csvql-screenshot/main.swift`:
```swift
import Foundation
print("csvql-screenshot: not yet implemented")
```

`csvqlTests/CSVParserTests.swift`:
```swift
import XCTest

final class CSVParserTests: XCTestCase {
}
```

`csvqlTests/DelimiterDetectorTests.swift`:
```swift
import XCTest

final class DelimiterDetectorTests: XCTestCase {
}
```

`csvqlTests/TypeInferrerTests.swift`:
```swift
import XCTest

final class TypeInferrerTests: XCTestCase {
}
```

`csvqlTests/CSVRendererTests.swift`:
```swift
import XCTest

final class CSVRendererTests: XCTestCase {
}
```

`csvqlTests/MainMenuTests.swift`:
```swift
import XCTest

final class MainMenuTests: XCTestCase {
}
```

Create empty fixture files:
- `csvqlTests/Fixtures/sales.csv` (empty)
- `csvqlTests/Fixtures/observatory.tsv` (empty)
- `csvqlTests/Fixtures/deploys.csv` (empty)

- [ ] **Step 9: Generate Xcode project and verify it compiles**

```bash
chmod +x scripts/install.sh
xcodegen generate
xcodebuild -project csvql.xcodeproj -scheme csvql -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 10: Verify tests run**

```bash
xcodebuild -project csvql.xcodeproj -scheme csvqlTests -destination 'platform=macOS' test 2>&1 | tail -5
```

Expected: TEST SUCCEEDED (0 tests)

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "feat: project scaffolding with xcodegen, plists, entitlements, Makefile"
```

---

### Task 2: Test Fixtures

**Files:**
- Create: `csvqlTests/Fixtures/sales.csv`
- Create: `csvqlTests/Fixtures/observatory.tsv`
- Create: `csvqlTests/Fixtures/deploys.csv`

- [ ] **Step 1: Create `csvqlTests/Fixtures/sales.csv`**

```csv
order_id,customer,amount,date,shipped,tracking_url
ORD-1001,Acme Corp,2499.99,2025-10-03,true,https://track.example.com/abc123
ORD-1002,Globex Inc,849.50,2025-10-05,false,
ORD-1003,Initech LLC,12750.00,2025-10-07,true,https://track.example.com/def456
ORD-1004,Umbrella Co,399.00,2025-10-12T14:30:00Z,true,https://track.example.com/ghi789
ORD-1005,Stark Industries,5200.00,2025-10-15,false,
ORD-1006,Wayne Enterprises,18900.00,2025-10-18,true,https://track.example.com/jkl012
ORD-1007,Wonka Industries,675.25,2025-10-22,true,https://track.example.com/mno345
ORD-1008,Cyberdyne Systems,3100.00,2025-10-25,false,
```

- [ ] **Step 2: Create `csvqlTests/Fixtures/observatory.tsv`**

```tsv
timestamp	ra	dec	magnitude	exposure_s	filter	note
2025-10-01T02:14:33Z	187.2776	2.0524	14.32	120.0	V	
2025-10-01T02:18:05Z	187.2780	2.0519	14.29	120.0	B	seeing 1.2 arcsec
2025-10-01T02:21:40Z	187.2783	2.0521	14.35	180.0	R	
2025-10-01T02:26:12Z	201.3651	-11.1613	16.01	300.0	V	faint target
2025-10-01T02:32:48Z	201.3648	-11.1610	15.98	300.0	B	
2025-10-01T02:39:15Z	201.3655	-11.1618	16.05	300.0	R	cloud passing
```

- [ ] **Step 3: Create `csvqlTests/Fixtures/deploys.csv`**

```csv
sha,service,environment,status,deployer,deployed_at
a1b2c3d,api-gateway,production,success,deploy-bot@example.com,2025-10-20T09:15:00Z
e4f5g6h,auth-service,staging,success,ops-team@example.com,2025-10-20T09:18:00Z
i7j8k9l,web-frontend,preview,failed,ci-runner@example.com,2025-10-20T09:22:00Z
m0n1o2p,api-gateway,production,success,deploy-bot@example.com,2025-10-20T10:05:00Z
q3r4s5t,data-pipeline,staging,failed,ops-team@example.com,2025-10-20T10:30:00Z
u6v7w8x,auth-service,production,success,deploy-bot@example.com,2025-10-20T11:00:00Z
```

- [ ] **Step 4: Commit**

```bash
git add csvqlTests/Fixtures/
git commit -m "feat: add test fixture CSV/TSV files"
```

---

### Task 3: DelimiterDetector (TDD)

**Files:**
- Modify: `Shared/DelimiterDetector.swift`
- Modify: `csvqlTests/DelimiterDetectorTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest

final class DelimiterDetectorTests: XCTestCase {

    func testDetectsComma() {
        let input = "a,b,c\n1,2,3\n4,5,6\n"
        XCTAssertEqual(DelimiterDetector.detect(in: input), ",")
    }

    func testDetectsTab() {
        let input = "a\tb\tc\n1\t2\t3\n4\t5\t6\n"
        XCTAssertEqual(DelimiterDetector.detect(in: input), "\t")
    }

    func testDetectsSemicolon() {
        let input = "a;b;c\n1;2;3\n4;5;6\n"
        XCTAssertEqual(DelimiterDetector.detect(in: input), ";")
    }

    func testDetectsPipe() {
        let input = "a|b|c\n1|2|3\n4|5|6\n"
        XCTAssertEqual(DelimiterDetector.detect(in: input), "|")
    }

    func testIgnoresDelimitersInsideQuotes() {
        let input = "name,address\n\"Doe, Jane\",\"123 Main St\"\n\"Smith, John\",\"456 Oak Ave\"\n"
        XCTAssertEqual(DelimiterDetector.detect(in: input), ",")
    }

    func testTabWinsOverCommaInContent() {
        let input = "name\tvalue\tdescription\nfoo\t1\t\"has, commas\"\nbar\t2\t\"also, commas\"\n"
        XCTAssertEqual(DelimiterDetector.detect(in: input), "\t")
    }

    func testSingleColumnDefaultsToComma() {
        let input = "hello\nworld\n"
        XCTAssertEqual(DelimiterDetector.detect(in: input), ",")
    }

    func testEmptyInputDefaultsToComma() {
        XCTAssertEqual(DelimiterDetector.detect(in: ""), ",")
    }

    func testConsistencyWins() {
        // 3 commas per line consistently vs 1 tab on some lines
        let input = "a,b,c,d\n1,2,3,4\n5,6,7,8\n"
        XCTAssertEqual(DelimiterDetector.detect(in: input), ",")
    }

    func testUsesFirst10LinesOnly() {
        var lines = (0..<10).map { "a\tb\tc\t\($0)" }
        lines.append(contentsOf: (10..<20).map { "a,b,c,\($0)" })
        let input = lines.joined(separator: "\n") + "\n"
        XCTAssertEqual(DelimiterDetector.detect(in: input), "\t")
    }

    func testDelimiterName() {
        XCTAssertEqual(DelimiterDetector.name(for: ","), "Comma")
        XCTAssertEqual(DelimiterDetector.name(for: "\t"), "Tab")
        XCTAssertEqual(DelimiterDetector.name(for: ";"), "Semicolon")
        XCTAssertEqual(DelimiterDetector.name(for: "|"), "Pipe")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate && xcodebuild -project csvql.xcodeproj -scheme csvqlTests \
  -destination 'platform=macOS' \
  -only-testing:csvqlTests/DelimiterDetectorTests test 2>&1 | tail -10
```

Expected: FAIL — `detect(in:)` and `name(for:)` don't exist yet.

- [ ] **Step 3: Implement DelimiterDetector**

```swift
import Foundation

struct DelimiterDetector {

    private static let candidates: [Character] = ["\t", ",", ";", "|"]

    static func detect(in content: String) -> Character {
        let lines = firstLines(from: content, count: 10)
        guard !lines.isEmpty else { return "," }

        var bestDelimiter: Character = ","
        var bestScore = 0.0

        for delimiter in candidates {
            let counts = lines.map { countUnquoted(delimiter: delimiter, in: $0) }
            let nonZero = counts.filter { $0 > 0 }
            guard nonZero.count == lines.count, let first = nonZero.first, first > 0 else { continue }

            let allSame = nonZero.allSatisfy { $0 == first }
            let consistency = allSame ? 1.0 : Double(nonZero.count) / Double(lines.count)
            let score = Double(first) * consistency

            if score > bestScore {
                bestScore = score
                bestDelimiter = delimiter
            }
        }

        return bestDelimiter
    }

    static func name(for delimiter: Character) -> String {
        switch delimiter {
        case ",": return "Comma"
        case "\t": return "Tab"
        case ";": return "Semicolon"
        case "|": return "Pipe"
        default: return String(delimiter)
        }
    }

    private static func firstLines(from content: String, count: Int) -> [String] {
        var lines: [String] = []
        var start = content.startIndex
        while lines.count < count, start < content.endIndex {
            let end = content[start...].firstIndex(of: "\n") ?? content.endIndex
            let line = String(content[start..<end])
            if !line.isEmpty {
                lines.append(line)
            }
            start = end < content.endIndex ? content.index(after: end) : content.endIndex
        }
        return lines
    }

    private static func countUnquoted(delimiter: Character, in line: String) -> Int {
        var count = 0
        var inQuotes = false
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == delimiter, !inQuotes {
                count += 1
            }
        }
        return count
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate && xcodebuild -project csvql.xcodeproj -scheme csvqlTests \
  -destination 'platform=macOS' \
  -only-testing:csvqlTests/DelimiterDetectorTests test 2>&1 | tail -10
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Shared/DelimiterDetector.swift csvqlTests/DelimiterDetectorTests.swift
git commit -m "feat: content-based delimiter detection with TDD"
```

---

### Task 4: CSVParser (TDD)

**Files:**
- Modify: `Shared/CSVParser.swift`
- Modify: `csvqlTests/CSVParserTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest

final class CSVParserTests: XCTestCase {

    // MARK: - Basic Parsing

    func testSimpleCSV() {
        let input = "a,b,c\n1,2,3\n4,5,6\n"
        let result = CSVParser.parse(input, delimiter: ",")
        XCTAssertEqual(result.headers, ["a", "b", "c"])
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows[0], ["1", "2", "3"])
        XCTAssertEqual(result.rows[1], ["4", "5", "6"])
    }

    func testTabDelimited() {
        let input = "a\tb\tc\n1\t2\t3\n"
        let result = CSVParser.parse(input, delimiter: "\t")
        XCTAssertEqual(result.headers, ["a", "b", "c"])
        XCTAssertEqual(result.rows[0], ["1", "2", "3"])
    }

    func testSemicolonDelimited() {
        let input = "a;b;c\n1;2;3\n"
        let result = CSVParser.parse(input, delimiter: ";")
        XCTAssertEqual(result.headers, ["a", "b", "c"])
        XCTAssertEqual(result.rows[0], ["1", "2", "3"])
    }

    // MARK: - Quoted Fields

    func testQuotedFieldWithComma() {
        let input = "name,address\n\"Doe, Jane\",\"123 Main St\"\n"
        let result = CSVParser.parse(input, delimiter: ",")
        XCTAssertEqual(result.rows[0][0], "Doe, Jane")
        XCTAssertEqual(result.rows[0][1], "123 Main St")
    }

    func testQuotedFieldWithNewline() {
        let input = "name,bio\n\"Jane\",\"Line 1\nLine 2\"\n"
        let result = CSVParser.parse(input, delimiter: ",")
        XCTAssertEqual(result.rows[0][1], "Line 1\nLine 2")
    }

    func testEscapedQuotes() {
        let input = "name,value\n\"has \"\"quotes\"\"\",normal\n"
        let result = CSVParser.parse(input, delimiter: ",")
        XCTAssertEqual(result.rows[0][0], "has \"quotes\"")
    }

    func testQuotedFieldWithTab() {
        let input = "a\tb\n\"has\ttab\"\tplain\n"
        let result = CSVParser.parse(input, delimiter: "\t")
        XCTAssertEqual(result.rows[0][0], "has\ttab")
    }

    // MARK: - Line Endings

    func testCRLF() {
        let input = "a,b\r\n1,2\r\n3,4\r\n"
        let result = CSVParser.parse(input, delimiter: ",")
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows[0], ["1", "2"])
    }

    func testMixedLineEndings() {
        let input = "a,b\n1,2\r\n3,4\n"
        let result = CSVParser.parse(input, delimiter: ",")
        XCTAssertEqual(result.rows.count, 2)
    }

    // MARK: - Edge Cases

    func testEmptyInput() {
        let result = CSVParser.parse("", delimiter: ",")
        XCTAssertEqual(result.headers, [])
        XCTAssertEqual(result.rows.count, 0)
    }

    func testHeaderOnly() {
        let result = CSVParser.parse("a,b,c\n", delimiter: ",")
        XCTAssertEqual(result.headers, ["a", "b", "c"])
        XCTAssertEqual(result.rows.count, 0)
    }

    func testTrailingNewline() {
        let input = "a,b\n1,2\n"
        let result = CSVParser.parse(input, delimiter: ",")
        XCTAssertEqual(result.rows.count, 1)
    }

    func testNoTrailingNewline() {
        let input = "a,b\n1,2"
        let result = CSVParser.parse(input, delimiter: ",")
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows[0], ["1", "2"])
    }

    func testEmptyFields() {
        let input = "a,b,c\n,,\n1,,3\n"
        let result = CSVParser.parse(input, delimiter: ",")
        XCTAssertEqual(result.rows[0], ["", "", ""])
        XCTAssertEqual(result.rows[1], ["1", "", "3"])
    }

    func testUnevenRows() {
        let input = "a,b,c\n1,2\n4,5,6,7\n"
        let result = CSVParser.parse(input, delimiter: ",")
        XCTAssertEqual(result.rows[0], ["1", "2"])
        XCTAssertEqual(result.rows[1], ["4", "5", "6", "7"])
    }

    func testWhitespacePreserved() {
        let input = "a,b\n hello , world \n"
        let result = CSVParser.parse(input, delimiter: ",")
        XCTAssertEqual(result.rows[0][0], " hello ")
        XCTAssertEqual(result.rows[0][1], " world ")
    }

    // MARK: - Line Ending Detection

    func testDetectsLF() {
        XCTAssertEqual(CSVParser.detectLineEnding(in: "a\nb\n"), "LF")
    }

    func testDetectsCRLF() {
        XCTAssertEqual(CSVParser.detectLineEnding(in: "a\r\nb\r\n"), "CRLF")
    }

    func testDetectsCR() {
        XCTAssertEqual(CSVParser.detectLineEnding(in: "a\rb\r"), "CR")
    }

    // MARK: - Fixture Files

    func testParseSalesFixture() {
        let url = Bundle(for: type(of: self)).url(forResource: "sales", withExtension: "csv")!
        let content = try! String(contentsOf: url, encoding: .utf8)
        let result = CSVParser.parse(content, delimiter: ",")
        XCTAssertEqual(result.headers, ["order_id", "customer", "amount", "date", "shipped", "tracking_url"])
        XCTAssertEqual(result.rows.count, 8)
        XCTAssertEqual(result.rows[0][0], "ORD-1001")
        XCTAssertEqual(result.rows[0][2], "2499.99")
    }

    func testParseObservatoryFixture() {
        let url = Bundle(for: type(of: self)).url(forResource: "observatory", withExtension: "tsv")!
        let content = try! String(contentsOf: url, encoding: .utf8)
        let result = CSVParser.parse(content, delimiter: "\t")
        XCTAssertEqual(result.headers.count, 7)
        XCTAssertEqual(result.headers[0], "timestamp")
        XCTAssertEqual(result.rows.count, 6)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate && xcodebuild -project csvql.xcodeproj -scheme csvqlTests \
  -destination 'platform=macOS' \
  -only-testing:csvqlTests/CSVParserTests test 2>&1 | tail -10
```

Expected: FAIL — `CSVParser.parse` and `detectLineEnding` don't exist.

- [ ] **Step 3: Implement CSVParser**

```swift
import Foundation

struct CSVParser {

    struct Result {
        let headers: [String]
        let rows: [[String]]
    }

    static func parse(_ content: String, delimiter: Character) -> Result {
        guard !content.isEmpty else { return Result(headers: [], rows: []) }

        let allRows = parseRows(content, delimiter: delimiter)
        guard let first = allRows.first else { return Result(headers: [], rows: []) }

        return Result(headers: first, rows: Array(allRows.dropFirst()))
    }

    static func detectLineEnding(in content: String) -> String {
        for char in content {
            if char == "\r" {
                let idx = content.firstIndex(of: "\r")!
                let next = content.index(after: idx)
                if next < content.endIndex, content[next] == "\n" {
                    return "CRLF"
                }
                return "CR"
            }
            if char == "\n" {
                return "LF"
            }
        }
        return "LF"
    }

    private static func parseRows(_ content: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var currentField = ""
        var currentRow: [String] = []
        var inQuotes = false
        var i = content.startIndex

        while i < content.endIndex {
            let char = content[i]

            if inQuotes {
                if char == "\"" {
                    let next = content.index(after: i)
                    if next < content.endIndex, content[next] == "\"" {
                        currentField.append("\"")
                        i = content.index(after: next)
                    } else {
                        inQuotes = false
                        i = content.index(after: i)
                    }
                } else {
                    currentField.append(char)
                    i = content.index(after: i)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                    i = content.index(after: i)
                } else if char == delimiter {
                    currentRow.append(currentField)
                    currentField = ""
                    i = content.index(after: i)
                } else if char == "\r" {
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.allSatisfy({ $0.isEmpty }) || currentRow.count > 1 || !rows.isEmpty {
                        rows.append(currentRow)
                    }
                    currentRow = []
                    let next = content.index(after: i)
                    if next < content.endIndex, content[next] == "\n" {
                        i = content.index(after: next)
                    } else {
                        i = next
                    }
                } else if char == "\n" {
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.allSatisfy({ $0.isEmpty }) || currentRow.count > 1 || !rows.isEmpty {
                        rows.append(currentRow)
                    }
                    currentRow = []
                    i = content.index(after: i)
                } else {
                    currentField.append(char)
                    i = content.index(after: i)
                }
            }
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate && xcodebuild -project csvql.xcodeproj -scheme csvqlTests \
  -destination 'platform=macOS' \
  -only-testing:csvqlTests/CSVParserTests test 2>&1 | tail -10
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Shared/CSVParser.swift csvqlTests/CSVParserTests.swift
git commit -m "feat: state-machine CSV parser with TDD"
```

---

### Task 5: TypeInferrer (TDD)

**Files:**
- Modify: `Shared/TypeInferrer.swift`
- Modify: `csvqlTests/TypeInferrerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest

final class TypeInferrerTests: XCTestCase {

    // MARK: - Single Type Detection

    func testInfersNumber() {
        let values = ["100", "200.5", "-3.14", "0", "42"]
        XCTAssertEqual(TypeInferrer.infer(column: values, header: "amount"), .number)
    }

    func testInfersBool() {
        let values = ["true", "false", "True", "FALSE", "true"]
        XCTAssertEqual(TypeInferrer.infer(column: values, header: "active"), .bool)
    }

    func testInfersDate() {
        let values = ["2025-10-01", "2025-10-02", "2025-10-03"]
        XCTAssertEqual(TypeInferrer.infer(column: values, header: "created"), .date)
    }

    func testInfersDateWithTime() {
        let values = ["2025-10-01T02:14:33Z", "2025-10-02T14:30:00Z"]
        XCTAssertEqual(TypeInferrer.infer(column: values, header: "ts"), .date)
    }

    func testInfersLink() {
        let values = ["https://example.com", "http://test.org/path", "https://x.co"]
        XCTAssertEqual(TypeInferrer.infer(column: values, header: "url"), .link)
    }

    func testInfersEmail() {
        let values = ["alice@example.com", "bob@test.org", "carol@x.co"]
        XCTAssertEqual(TypeInferrer.infer(column: values, header: "contact"), .email)
    }

    func testInfersSha() {
        let values = ["a1b2c3d", "e4f5g6h", "i7j8k9l"]
        XCTAssertEqual(TypeInferrer.infer(column: values, header: "sha"), .sha)
    }

    func testShaRequiresColumnName() {
        let values = ["a1b2c3d", "e4f5a6b", "c7d8e9f"]
        XCTAssertEqual(TypeInferrer.infer(column: values, header: "id"), .text)
    }

    func testInfersText() {
        let values = ["hello", "world", "foo bar"]
        XCTAssertEqual(TypeInferrer.infer(column: values, header: "name"), .text)
    }

    // MARK: - Threshold (80%)

    func testNumberWith80PercentMatch() {
        // 4 out of 5 = 80% → number
        let values = ["100", "200", "300", "400", "abc"]
        XCTAssertEqual(TypeInferrer.infer(column: values, header: "val"), .number)
    }

    func testNumberBelow80PercentFallsToText() {
        // 3 out of 5 = 60% → text
        let values = ["100", "200", "300", "abc", "def"]
        XCTAssertEqual(TypeInferrer.infer(column: values, header: "val"), .text)
    }

    // MARK: - Empty Values Ignored

    func testEmptyValuesIgnored() {
        let values = ["100", "", "200", "", "300"]
        XCTAssertEqual(TypeInferrer.infer(column: values, header: "val"), .number)
    }

    func testAllEmpty() {
        let values = ["", "", ""]
        XCTAssertEqual(TypeInferrer.infer(column: values, header: "val"), .text)
    }

    // MARK: - Priority

    func testBoolPriorityOverText() {
        let values = ["true", "false", "true", "true", "false"]
        XCTAssertEqual(TypeInferrer.infer(column: values, header: "flag"), .bool)
    }

    // MARK: - Batch Inference

    func testInferAll() {
        let headers = ["name", "amount", "active"]
        let rows = [
            ["Alice", "100", "true"],
            ["Bob", "200", "false"],
            ["Carol", "300", "true"],
        ]
        let types = TypeInferrer.inferAll(headers: headers, rows: rows)
        XCTAssertEqual(types, [.text, .number, .bool])
    }

    // MARK: - Status Keyword Detection

    func testIsStatusKeyword() {
        XCTAssertTrue(TypeInferrer.isStatusKeyword("success"))
        XCTAssertTrue(TypeInferrer.isStatusKeyword("failed"))
        XCTAssertTrue(TypeInferrer.isStatusKeyword("production"))
        XCTAssertTrue(TypeInferrer.isStatusKeyword("staging"))
        XCTAssertTrue(TypeInferrer.isStatusKeyword("preview"))
        XCTAssertFalse(TypeInferrer.isStatusKeyword("hello"))
        XCTAssertTrue(TypeInferrer.isStatusKeyword("SUCCESS"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate && xcodebuild -project csvql.xcodeproj -scheme csvqlTests \
  -destination 'platform=macOS' \
  -only-testing:csvqlTests/TypeInferrerTests test 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3: Implement TypeInferrer**

```swift
import Foundation

enum ColumnType: Equatable {
    case text, number, date, bool, link, email, sha
}

struct TypeInferrer {

    private static let numberPattern = try! NSRegularExpression(pattern: #"^-?\d+(\.\d+)?$"#)
    private static let datePattern = try! NSRegularExpression(pattern: #"^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}Z?)?$"#)
    private static let emailPattern = try! NSRegularExpression(pattern: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#)
    private static let shaPattern = try! NSRegularExpression(pattern: #"^[0-9a-f]{6,}$"#)

    private static let statusKeywords: Set<String> = [
        "success", "failed", "production", "staging", "preview"
    ]

    static func infer(column values: [String], header: String) -> ColumnType {
        let nonEmpty = values.filter { !$0.isEmpty }
        guard !nonEmpty.isEmpty else { return .text }

        let threshold = 0.8
        let count = Double(nonEmpty.count)

        let checks: [(ColumnType, (String) -> Bool)] = [
            (.bool, { isBool($0) }),
            (.number, { matches(numberPattern, $0) }),
            (.date, { matches(datePattern, $0) }),
            (.link, { $0.lowercased().hasPrefix("http://") || $0.lowercased().hasPrefix("https://") }),
            (.email, { matches(emailPattern, $0) }),
            (.sha, { header.lowercased() == "sha" && matches(shaPattern, $0.lowercased()) }),
        ]

        for (type, test) in checks {
            let matching = Double(nonEmpty.filter(test).count)
            if matching / count >= threshold {
                return type
            }
        }

        return .text
    }

    static func inferAll(headers: [String], rows: [[String]]) -> [ColumnType] {
        return headers.indices.map { colIndex in
            let column = rows.map { row in
                colIndex < row.count ? row[colIndex] : ""
            }
            return infer(column: column, header: headers[colIndex])
        }
    }

    static func isStatusKeyword(_ value: String) -> Bool {
        statusKeywords.contains(value.lowercased())
    }

    private static func isBool(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower == "true" || lower == "false"
    }

    private static func matches(_ regex: NSRegularExpression, _ value: String) -> Bool {
        let range = NSRange(value.startIndex..., in: value)
        return regex.firstMatch(in: value, range: range) != nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate && xcodebuild -project csvql.xcodeproj -scheme csvqlTests \
  -destination 'platform=macOS' \
  -only-testing:csvqlTests/TypeInferrerTests test 2>&1 | tail -10
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Shared/TypeInferrer.swift csvqlTests/TypeInferrerTests.swift
git commit -m "feat: per-column type inference with 80% threshold"
```

---

### Task 6: CSVData Model

**Files:**
- Modify: `Shared/CSVDocument.swift`

- [ ] **Step 1: Update CSVData to include metadata and a convenience initializer**

```swift
import Foundation

struct CSVData {
    let fileName: String
    let filePath: String
    let fileSize: Int
    let modifiedDate: Date?
    let headers: [String]
    let rows: [[String]]
    let types: [ColumnType]
    let delimiter: Character
    let encoding: String
    let lineEnding: String

    static func load(from url: URL) throws -> CSVData {
        let data = try Data(contentsOf: url)
        let content: String
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            content = String(data: data, encoding: .utf16) ?? String(decoding: data, as: UTF8.self)
        } else {
            content = String(decoding: data, as: UTF8.self)
        }

        let delimiter = DelimiterDetector.detect(in: content)
        let parsed = CSVParser.parse(content, delimiter: delimiter)
        let types = TypeInferrer.inferAll(headers: parsed.headers, rows: parsed.rows)
        let lineEnding = CSVParser.detectLineEnding(in: content)

        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modDate = attrs?[.modificationDate] as? Date

        return CSVData(
            fileName: url.lastPathComponent,
            filePath: url.path,
            fileSize: data.count,
            modifiedDate: modDate,
            headers: parsed.headers,
            rows: parsed.rows,
            types: types,
            delimiter: delimiter,
            encoding: data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) ? "UTF-16" : "UTF-8",
            lineEnding: lineEnding
        )
    }

    var formattedSize: String {
        if fileSize < 1024 {
            return "\(fileSize) B"
        } else if fileSize < 1024 * 1024 {
            return String(format: "%.1f KB", Double(fileSize) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(fileSize) / (1024.0 * 1024.0))
        }
    }

    var timeAgo: String {
        guard let date = modifiedDate else { return "unknown" }
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Shared/CSVDocument.swift
git commit -m "feat: CSVData model with file loading and metadata"
```

---

### Task 7: CSS Design Tokens

**Files:**
- Modify: `Shared/Resources/preview.css`

- [ ] **Step 1: Write the complete CSS**

```css
:root {
    --text: #d4d0d2;
    --text-dim: #8a8588;
    --text-faint: #5a5658;
    --bg: #1a1a1a;
    --bg-elev: #202020;
    --bg-soft: #242424;
    --bg-window: #1d1d1d;
    --bg-titlebar: #262626;
    --link: #6cb0e0;
    --link-soft: rgba(108,176,224,0.14);
    --border: #444;
    --border-soft: #2e2e2e;
    --code-bg: rgba(255,255,255,0.08);
    --num: #e0c990;
    --bool-true: #8ec07c;
    --bool-false: #c97a7a;
    --date: #c2a5d6;
    --selection: rgba(108,176,224,0.22);
}

* { margin: 0; padding: 0; box-sizing: border-box; }

body {
    font-family: -apple-system, 'SF Pro', system-ui, sans-serif;
    font-size: 12.5px;
    color: var(--text);
    background: var(--bg-window);
    -webkit-font-smoothing: antialiased;
}

.ql-window {
    display: flex;
    flex-direction: column;
    height: 100vh;
    background: var(--bg-window);
}

/* Titlebar */
.titlebar {
    height: 52px;
    min-height: 52px;
    background: linear-gradient(180deg, #2a2a2a, #232323);
    border-bottom: 1px solid var(--border-soft);
    display: grid;
    grid-template-columns: 1fr auto 1fr;
    align-items: center;
    padding: 0 14px;
}

.titlebar-left {
    display: flex;
    align-items: center;
    gap: 8px;
}

.titlebar-center {
    text-align: center;
}

.titlebar-right {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 8px;
}

.titlebar .filename {
    font-size: 13.5px;
    font-weight: 600;
    color: var(--text);
    line-height: 1.2;
}

.titlebar .meta {
    font-family: 'SF Mono', SFMono-Regular, Menlo, monospace;
    font-size: 10.5px;
    color: var(--text-dim);
    line-height: 1.2;
}

.titlebar .meta .sep {
    color: var(--text-faint);
}

/* Close button (host app only) */
.close-btn {
    width: 22px;
    height: 22px;
    border-radius: 50%;
    background: var(--border-soft);
    border: 1px solid #3a3a3a;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 120ms;
}

.close-btn:hover {
    background: #3a3a3a;
}

.close-btn svg {
    width: 9px;
    height: 9px;
    stroke: var(--text-dim);
    stroke-width: 1.5;
}

.close-btn:hover svg {
    stroke: #fff;
}

.fullscreen-btn {
    width: 26px;
    height: 26px;
    background: transparent;
    border: none;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    opacity: 0.5;
}

.fullscreen-btn:hover {
    opacity: 1;
}

/* Sub-toolbar */
.sub-toolbar {
    height: 42px;
    min-height: 42px;
    background: #1f1f1f;
    border-bottom: 1px solid var(--border-soft);
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 14px;
    gap: 10px;
}

.breadcrumb {
    font-family: 'SF Mono', SFMono-Regular, Menlo, monospace;
    font-size: 11px;
    color: var(--text-faint);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    flex: 1;
    min-width: 0;
}

.breadcrumb .segment-last {
    color: var(--text);
}

.breadcrumb .slash {
    margin: 0 1px;
}

.toolbar-pills {
    display: flex;
    gap: 6px;
    align-items: center;
    flex-shrink: 0;
}

.pill {
    padding: 3px 8px;
    border-radius: 5px;
    background: var(--code-bg);
    font-family: 'SF Mono', SFMono-Regular, Menlo, monospace;
    font-size: 10.5px;
    white-space: nowrap;
}

.pill .label {
    color: var(--text-faint);
}

.pill .value {
    color: var(--text);
}

/* Search box (host app only) */
.search-box {
    height: 26px;
    width: 220px;
    background: #171717;
    border: 1px solid var(--border-soft);
    border-radius: 6px;
    display: flex;
    align-items: center;
    padding: 0 8px;
    gap: 6px;
}

.search-box svg {
    width: 11px;
    height: 11px;
    stroke: var(--text-faint);
    flex-shrink: 0;
}

.search-box input {
    background: transparent;
    border: none;
    outline: none;
    color: var(--text);
    font-family: -apple-system, 'SF Pro', system-ui, sans-serif;
    font-size: 12px;
    flex: 1;
    min-width: 0;
}

.search-box input::placeholder {
    color: var(--text-faint);
}

.search-box .match-count {
    font-family: 'SF Mono', SFMono-Regular, Menlo, monospace;
    font-size: 10.5px;
    color: var(--text-faint);
    flex-shrink: 0;
}

/* Table */
.table-container {
    flex: 1;
    overflow: auto;
    background: var(--bg);
}

table {
    width: 100%;
    border-collapse: collapse;
    table-layout: fixed;
}

/* Header */
thead {
    position: sticky;
    top: 0;
    z-index: 2;
}

thead th {
    height: 38px;
    background: var(--bg-titlebar);
    border-bottom: 1px solid var(--border);
    padding: 0 14px;
    text-align: left;
    font-family: 'SF Mono', SFMono-Regular, Menlo, monospace;
    font-size: 11px;
    font-weight: 600;
    color: var(--text-dim);
    text-transform: lowercase;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    position: relative;
    user-select: none;
}

thead th.sortable {
    cursor: pointer;
}

thead th.sort-active {
    color: var(--text);
}

.sort-indicator {
    display: inline-block;
    width: 8px;
    height: 8px;
    margin-left: 4px;
    vertical-align: middle;
}

.sort-indicator svg {
    fill: var(--link);
}

/* Row number column */
th.row-num, td.row-num {
    width: 54px;
    min-width: 54px;
    max-width: 54px;
    text-align: right;
    font-family: 'SF Mono', SFMono-Regular, Menlo, monospace;
    font-size: 10.5px;
    color: var(--text-faint);
    border-right: 1px solid var(--border-soft);
    position: sticky;
    left: 0;
    z-index: 1;
    background: inherit;
}

thead th.row-num {
    z-index: 3;
}

/* Data rows */
tbody tr {
    height: 34px;
    border-bottom: 1px solid var(--border-soft);
    transition: background 80ms;
}

tbody tr:nth-child(odd) {
    background: #1c1c1c;
}

tbody tr:nth-child(even) {
    background: var(--bg);
}

tbody tr.selected {
    background: var(--selection) !important;
}

/* Density classes */
.density-compact tbody tr { height: 26px; }
.density-comfortable tbody tr { height: 42px; }

td {
    padding: 0 14px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    vertical-align: middle;
}

/* Cell types */
td.type-number {
    text-align: right;
    font-family: 'SF Mono', SFMono-Regular, Menlo, monospace;
    font-size: 12px;
    color: var(--num);
    font-variant-numeric: tabular-nums;
}

td.type-date {
    font-family: 'SF Mono', SFMono-Regular, Menlo, monospace;
    font-size: 11.5px;
    color: var(--date);
}

td.type-date .time-part {
    color: var(--text-faint);
    font-size: 10.5px;
    margin-left: 6px;
}

td.type-link {
    font-family: 'SF Mono', SFMono-Regular, Menlo, monospace;
    font-size: 11.5px;
}

td.type-link a {
    color: var(--link);
    text-decoration: none;
    border-bottom: 1px dotted rgba(108,176,224,0.4);
}

td.type-email {
    font-family: 'SF Mono', SFMono-Regular, Menlo, monospace;
    font-size: 11.5px;
    color: var(--link);
}

td.type-sha .sha-chip {
    font-family: 'SF Mono', SFMono-Regular, Menlo, monospace;
    font-size: 12px;
    background: var(--code-bg);
    padding: 1px 5px;
    border-radius: 3px;
}

td.type-empty {
    font-style: italic;
    font-size: 11px;
    color: var(--text-faint);
}

/* Status pills */
.status-pill {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 2px 7px 2px 6px;
    border-radius: 4px;
    font-family: 'SF Mono', SFMono-Regular, Menlo, monospace;
    font-size: 11px;
    line-height: 1;
}

.status-pill .dot {
    width: 5px;
    height: 5px;
    border-radius: 50%;
    flex-shrink: 0;
}

.pill-success, .pill-true {
    color: #a8d4a0;
    background: rgba(142,192,124,0.13);
}
.pill-success .dot, .pill-true .dot {
    background: #8ec07c;
    box-shadow: 0 0 6px #8ec07c;
}

.pill-failed {
    color: #dfa3a3;
    background: rgba(201,122,122,0.15);
}
.pill-failed .dot {
    background: #c97a7a;
    box-shadow: 0 0 6px #c97a7a;
}

.pill-false {
    color: #9a8a8c;
    background: rgba(255,255,255,0.05);
}
.pill-false .dot {
    background: #6e6466;
    box-shadow: 0 0 6px #6e6466;
}

.pill-production {
    color: #dfa3a3;
    background: rgba(201,122,122,0.12);
}
.pill-production .dot {
    background: #c97a7a;
    box-shadow: 0 0 6px #c97a7a;
}

.pill-staging {
    color: #e0c990;
    background: rgba(224,201,144,0.12);
}
.pill-staging .dot {
    background: #e0c990;
    box-shadow: 0 0 6px #e0c990;
}

.pill-preview {
    color: #c2a5d6;
    background: rgba(194,165,214,0.12);
}
.pill-preview .dot {
    background: #c2a5d6;
    box-shadow: 0 0 6px #c2a5d6;
}

/* Footer */
.footer {
    height: 28px;
    min-height: 28px;
    background: linear-gradient(180deg, #1f1f1f, #1a1a1a);
    border-top: 1px solid var(--border-soft);
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 14px;
    font-family: 'SF Mono', SFMono-Regular, Menlo, monospace;
    font-size: 10.5px;
}

.footer-left, .footer-right {
    display: flex;
    align-items: center;
    gap: 12px;
}

.footer .label {
    color: var(--text-faint);
}

.footer .value {
    color: var(--text-dim);
}

.footer .csvql-badge {
    display: flex;
    align-items: center;
    gap: 5px;
}

.footer .csvql-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: #8ec07c;
    box-shadow: 0 0 6px #8ec07c;
}
```

- [ ] **Step 2: Commit**

```bash
git add Shared/Resources/preview.css
git commit -m "feat: dark theme CSS with all design tokens"
```

---

### Task 8: CSVRenderer (TDD)

**Files:**
- Modify: `Shared/CSVRenderer.swift`
- Modify: `csvqlTests/CSVRendererTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest

final class CSVRendererTests: XCTestCase {

    private func sampleData() -> CSVData {
        return CSVData(
            fileName: "test.csv",
            filePath: "/Users/test/data/test.csv",
            fileSize: 1234,
            modifiedDate: Date(),
            headers: ["name", "amount", "active"],
            rows: [
                ["Alice", "100.50", "true"],
                ["Bob", "200", "false"],
            ],
            types: [.text, .number, .bool],
            delimiter: ",",
            encoding: "UTF-8",
            lineEnding: "LF"
        )
    }

    // MARK: - HTML Structure

    func testRenderContainsDoctype() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.hasPrefix("<!DOCTYPE html>"))
    }

    func testRenderContainsStyleTag() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains("<style>"))
        XCTAssertTrue(html.contains("--text:"))
    }

    func testRenderContainsQLWindow() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains("class=\"ql-window\""))
    }

    // MARK: - Titlebar

    func testTitlebarShowsFilename() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains("test.csv"))
    }

    func testTitlebarShowsRowCount() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains("2 rows"))
    }

    func testTitlebarShowsColCount() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains("3 cols"))
    }

    // MARK: - Sub-toolbar

    func testSubToolbarShowsPath() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains("test.csv"))
    }

    func testSubToolbarShowsDelimiterPill() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains("Comma"))
    }

    func testSubToolbarShowsEncodingPill() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains("UTF-8"))
    }

    // MARK: - Table Headers

    func testTableHeadersLowercased() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains(">name<"))
        XCTAssertTrue(html.contains(">amount<"))
        XCTAssertTrue(html.contains(">active<"))
    }

    func testRowNumberHeader() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains("row-num"))
    }

    // MARK: - Cell Rendering

    func testNumberCellClass() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains("type-number"))
    }

    func testBoolRenderedAsPill() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains("status-pill"))
        XCTAssertTrue(html.contains("pill-true"))
    }

    func testEmptyCellRendersEmDash() {
        let data = CSVData(
            fileName: "test.csv", filePath: "/test.csv", fileSize: 100,
            modifiedDate: nil, headers: ["a", "b"],
            rows: [["hello", ""]], types: [.text, .text],
            delimiter: ",", encoding: "UTF-8", lineEnding: "LF"
        )
        let html = CSVRenderer.render(data: data, interactive: false)
        XCTAssertTrue(html.contains("type-empty"))
        XCTAssertTrue(html.contains("—"))
    }

    // MARK: - Link Rendering

    func testLinkCellStripsScheme() {
        let data = CSVData(
            fileName: "test.csv", filePath: "/test.csv", fileSize: 100,
            modifiedDate: nil, headers: ["url"],
            rows: [["https://example.com/path/"]], types: [.link],
            delimiter: ",", encoding: "UTF-8", lineEnding: "LF"
        )
        let html = CSVRenderer.render(data: data, interactive: false)
        XCTAssertTrue(html.contains("example.com/path"))
        XCTAssertTrue(html.contains("type-link"))
    }

    // MARK: - SHA Rendering

    func testShaCellRendersChip() {
        let data = CSVData(
            fileName: "test.csv", filePath: "/test.csv", fileSize: 100,
            modifiedDate: nil, headers: ["sha"],
            rows: [["a1b2c3d"]], types: [.sha],
            delimiter: ",", encoding: "UTF-8", lineEnding: "LF"
        )
        let html = CSVRenderer.render(data: data, interactive: false)
        XCTAssertTrue(html.contains("sha-chip"))
    }

    // MARK: - Date Rendering

    func testDateWithTimePartSplit() {
        let data = CSVData(
            fileName: "test.csv", filePath: "/test.csv", fileSize: 100,
            modifiedDate: nil, headers: ["ts"],
            rows: [["2025-10-01T14:30:00Z"]], types: [.date],
            delimiter: ",", encoding: "UTF-8", lineEnding: "LF"
        )
        let html = CSVRenderer.render(data: data, interactive: false)
        XCTAssertTrue(html.contains("type-date"))
        XCTAssertTrue(html.contains("time-part"))
    }

    // MARK: - Status Pills in Text Columns

    func testStatusKeywordRenderedAsPill() {
        let data = CSVData(
            fileName: "test.csv", filePath: "/test.csv", fileSize: 100,
            modifiedDate: nil, headers: ["status"],
            rows: [["success"], ["failed"], ["production"], ["staging"], ["preview"]],
            types: [.text],
            delimiter: ",", encoding: "UTF-8", lineEnding: "LF"
        )
        let html = CSVRenderer.render(data: data, interactive: false)
        XCTAssertTrue(html.contains("pill-success"))
        XCTAssertTrue(html.contains("pill-failed"))
        XCTAssertTrue(html.contains("pill-production"))
        XCTAssertTrue(html.contains("pill-staging"))
        XCTAssertTrue(html.contains("pill-preview"))
    }

    // MARK: - Footer

    func testFooterShowsLineEnding() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains(">LF<"))
    }

    func testFooterShowsCsvqlBadge() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains("csvql-badge"))
        XCTAssertTrue(html.contains("csvql-dot"))
    }

    // MARK: - Interactive vs Static

    func testStaticHasNoSearchBox() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertFalse(html.contains("search-box"))
    }

    func testInteractiveHasSearchBox() {
        let html = CSVRenderer.render(data: sampleData(), interactive: true)
        XCTAssertTrue(html.contains("search-box"))
    }

    func testInteractiveHasSortableHeaders() {
        let html = CSVRenderer.render(data: sampleData(), interactive: true)
        XCTAssertTrue(html.contains("sortable"))
    }

    func testStaticHasNoSortableHeaders() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertFalse(html.contains("sortable"))
    }

    func testInteractiveHasCloseButton() {
        let html = CSVRenderer.render(data: sampleData(), interactive: true)
        XCTAssertTrue(html.contains("close-btn"))
    }

    func testStaticHasNoCloseButton() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertFalse(html.contains("close-btn"))
    }

    // MARK: - HTML Escaping

    func testHtmlEscapedInCells() {
        let data = CSVData(
            fileName: "test.csv", filePath: "/test.csv", fileSize: 100,
            modifiedDate: nil, headers: ["name"],
            rows: [["<script>alert('xss')</script>"]], types: [.text],
            delimiter: ",", encoding: "UTF-8", lineEnding: "LF"
        )
        let html = CSVRenderer.render(data: data, interactive: false)
        XCTAssertFalse(html.contains("<script>alert"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
    }

    func testHtmlEscapedInHeaders() {
        let data = CSVData(
            fileName: "test.csv", filePath: "/test.csv", fileSize: 100,
            modifiedDate: nil, headers: ["<b>bold</b>"],
            rows: [["val"]], types: [.text],
            delimiter: ",", encoding: "UTF-8", lineEnding: "LF"
        )
        let html = CSVRenderer.render(data: data, interactive: false)
        XCTAssertFalse(html.contains("<b>bold</b>"))
        XCTAssertTrue(html.contains("&lt;b&gt;"))
    }

    // MARK: - Fixture Integration

    func testRenderSalesFixture() {
        let url = Bundle(for: type(of: self)).url(forResource: "sales", withExtension: "csv")!
        let data = try! CSVData.load(from: url)
        let html = CSVRenderer.render(data: data, interactive: false)
        XCTAssertTrue(html.contains("sales.csv"))
        XCTAssertTrue(html.contains("8 rows"))
        XCTAssertTrue(html.contains("6 cols"))
        XCTAssertTrue(html.contains("type-number"))
        XCTAssertTrue(html.contains("type-date"))
        XCTAssertTrue(html.contains("pill-true"))
        XCTAssertTrue(html.contains("type-link"))
    }

    func testRenderDeploysFixture() {
        let url = Bundle(for: type(of: self)).url(forResource: "deploys", withExtension: "csv")!
        let data = try! CSVData.load(from: url)
        let html = CSVRenderer.render(data: data, interactive: false)
        XCTAssertTrue(html.contains("sha-chip"))
        XCTAssertTrue(html.contains("pill-success"))
        XCTAssertTrue(html.contains("pill-failed"))
        XCTAssertTrue(html.contains("pill-production"))
        XCTAssertTrue(html.contains("pill-staging"))
        XCTAssertTrue(html.contains("pill-preview"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate && xcodebuild -project csvql.xcodeproj -scheme csvqlTests \
  -destination 'platform=macOS' \
  -only-testing:csvqlTests/CSVRendererTests test 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3: Implement CSVRenderer**

```swift
import Foundation

private class BundleAnchor {}

struct CSVRenderer {

    static let previewSize = NSSize(width: 1180, height: 780)

    static func render(data: CSVData, interactive: Bool) -> String {
        let css = loadCSS()
        let js = interactive ? interactiveJS() : ""
        let titlebar = renderTitlebar(data: data, interactive: interactive)
        let subtoolbar = renderSubToolbar(data: data, interactive: interactive)
        let table = renderTable(data: data, interactive: interactive)
        let footer = renderFooter(data: data)

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(css)</style>
        </head>
        <body>
        <div class="ql-window">
        \(titlebar)
        \(subtoolbar)
        <div class="table-container">
        \(table)
        </div>
        \(footer)
        </div>
        \(js)
        </body>
        </html>
        """
    }

    // MARK: - CSS

    private static func loadCSS() -> String {
        let bundle = Bundle(for: BundleAnchor.self)
        guard let url = bundle.url(forResource: "preview", withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return css
    }

    // MARK: - Titlebar

    private static func renderTitlebar(data: CSVData, interactive: Bool) -> String {
        let leftContent: String
        if interactive {
            leftContent = """
            <div class="titlebar-left">
            <div class="close-btn" onclick="window.webkit.messageHandlers.csvql.postMessage({action:'close'})">
            <svg viewBox="0 0 9 9"><line x1="1" y1="1" x2="8" y2="8"/><line x1="8" y1="1" x2="1" y2="8"/></svg>
            </div>
            </div>
            """
        } else {
            leftContent = "<div class=\"titlebar-left\"></div>"
        }

        return """
        <div class="titlebar">
        \(leftContent)
        <div class="titlebar-center">
        <div class="filename">\(escapeHTML(data.fileName))</div>
        <div class="meta">\(data.rows.count) rows<span class="sep"> · </span>\(data.headers.count) cols<span class="sep"> · </span>\(data.formattedSize)</div>
        </div>
        <div class="titlebar-right"></div>
        </div>
        """
    }

    // MARK: - Sub-toolbar

    private static func renderSubToolbar(data: CSVData, interactive: Bool) -> String {
        let pathParts = formatBreadcrumb(data.filePath)
        let delimiterName = DelimiterDetector.name(for: data.delimiter)

        let searchBox: String
        if interactive {
            searchBox = """
            <div class="search-box">
            <svg viewBox="0 0 11 11"><circle cx="4.5" cy="4.5" r="3.5" fill="none" stroke-width="1.2"/><line x1="7" y1="7" x2="10" y2="10" stroke-width="1.2"/></svg>
            <input type="text" placeholder="Filter rows..." oninput="filterRows(this.value)">
            <span class="match-count" id="match-count"></span>
            </div>
            """
        } else {
            searchBox = ""
        }

        return """
        <div class="sub-toolbar">
        <div class="breadcrumb">\(pathParts)</div>
        <div class="toolbar-pills">
        <div class="pill"><span class="label">delimiter </span><span class="value">\(delimiterName)</span></div>
        <div class="pill"><span class="label">encoding </span><span class="value">\(data.encoding)</span></div>
        \(searchBox)
        </div>
        </div>
        """
    }

    private static func formatBreadcrumb(_ path: String) -> String {
        let homePath = NSHomeDirectory()
        var displayPath = path
        if displayPath.hasPrefix(homePath) {
            displayPath = "~" + displayPath.dropFirst(homePath.count)
        }
        let parts = displayPath.split(separator: "/", omittingEmptySubsequences: true)
        guard !parts.isEmpty else { return escapeHTML(displayPath) }

        var result = ""
        for (i, part) in parts.enumerated() {
            if i > 0 {
                result += "<span class=\"slash\">/</span>"
            }
            if i == parts.count - 1 {
                result += "<span class=\"segment-last\">\(escapeHTML(String(part)))</span>"
            } else {
                result += escapeHTML(String(part))
            }
        }
        return result
    }

    // MARK: - Table

    private static func renderTable(data: CSVData, interactive: Bool) -> String {
        var html = "<table><thead><tr>"
        html += "<th class=\"row-num\">#</th>"

        for (i, header) in data.headers.enumerated() {
            let sortClass = interactive ? " sortable" : ""
            let sortAttr = interactive ? " onclick=\"sortColumn(\(i))\"" : ""
            let typeClass = i < data.types.count ? columnWidthClass(data.types[i]) : ""
            html += "<th class=\"\(typeClass)\(sortClass)\"\(sortAttr)>\(escapeHTML(header.lowercased()))</th>"
        }
        html += "</tr></thead><tbody>"

        for (rowIndex, row) in data.rows.enumerated() {
            let rowAttr = interactive ? " onclick=\"selectRow(this)\"" : ""
            html += "<tr\(rowAttr)>"
            html += "<td class=\"row-num\">\(rowIndex + 1)</td>"

            for (colIndex, value) in row.enumerated() {
                let type = colIndex < data.types.count ? data.types[colIndex] : .text
                html += renderCell(value: value, type: type)
            }

            if row.count < data.headers.count {
                for _ in row.count..<data.headers.count {
                    html += renderCell(value: "", type: .text)
                }
            }

            html += "</tr>"
        }

        html += "</tbody></table>"
        return html
    }

    private static func columnWidthClass(_ type: ColumnType) -> String {
        switch type {
        case .number: return "col-number"
        case .link: return "col-link"
        default: return ""
        }
    }

    // MARK: - Cell Rendering

    private static func renderCell(value: String, type: ColumnType) -> String {
        if value.isEmpty {
            return "<td class=\"type-empty\">—</td>"
        }

        switch type {
        case .number:
            return "<td class=\"type-number\">\(formatNumber(value))</td>"

        case .date:
            return renderDateCell(value)

        case .bool:
            let lower = value.lowercased()
            let pillClass = lower == "true" ? "pill-true" : "pill-false"
            return "<td><span class=\"status-pill \(pillClass)\"><span class=\"dot\"></span>\(escapeHTML(value))</span></td>"

        case .link:
            let display = stripScheme(value)
            return "<td class=\"type-link\"><a href=\"\(escapeAttribute(value))\">\(escapeHTML(display))</a></td>"

        case .email:
            return "<td class=\"type-email\">\(escapeHTML(value))</td>"

        case .sha:
            return "<td class=\"type-sha\"><span class=\"sha-chip\">\(escapeHTML(value))</span></td>"

        case .text:
            if TypeInferrer.isStatusKeyword(value) {
                let pillClass = "pill-\(value.lowercased())"
                return "<td><span class=\"status-pill \(pillClass)\"><span class=\"dot\"></span>\(escapeHTML(value))</span></td>"
            }
            return "<td>\(escapeHTML(value))</td>"
        }
    }

    private static func renderDateCell(_ value: String) -> String {
        if let tIndex = value.firstIndex(of: "T") {
            let datePart = String(value[value.startIndex..<tIndex])
            let timePart = String(value[value.index(after: tIndex)...]).replacingOccurrences(of: "Z", with: "")
            return "<td class=\"type-date\">\(escapeHTML(datePart))<span class=\"time-part\">\(escapeHTML(timePart))</span></td>"
        }
        return "<td class=\"type-date\">\(escapeHTML(value))</td>"
    }

    private static func formatNumber(_ value: String) -> String {
        guard let num = Double(value) else { return escapeHTML(value) }
        let hasDecimal = value.contains(".")
        if hasDecimal {
            let decimalPlaces = value.split(separator: ".").last.map { $0.count } ?? 0
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = Locale(identifier: "en_US")
            formatter.minimumFractionDigits = decimalPlaces
            formatter.maximumFractionDigits = decimalPlaces
            return formatter.string(from: NSNumber(value: num)) ?? escapeHTML(value)
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = Locale(identifier: "en_US")
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: num)) ?? escapeHTML(value)
        }
    }

    private static func stripScheme(_ url: String) -> String {
        var result = url
        if result.hasPrefix("https://") { result = String(result.dropFirst(8)) }
        else if result.hasPrefix("http://") { result = String(result.dropFirst(7)) }
        if result.hasSuffix("/") { result = String(result.dropLast()) }
        return result
    }

    // MARK: - Footer

    private static func renderFooter(data: CSVData) -> String {
        return """
        <div class="footer">
        <div class="footer-left">
        <span><span class="label">rows </span><span class="value" id="row-count">\(data.rows.count)</span></span>
        <span><span class="label">cols </span><span class="value">\(data.headers.count)</span></span>
        <span><span class="label">size </span><span class="value">\(data.formattedSize)</span></span>
        <span><span class="label">modified </span><span class="value">\(data.timeAgo)</span></span>
        </div>
        <div class="footer-right">
        <span class="value">\(data.lineEnding)</span>
        <span class="value">\(data.encoding)</span>
        <span class="csvql-badge"><span class="csvql-dot"></span><span class="value">csvql</span></span>
        </div>
        </div>
        """
    }

    // MARK: - Interactive JS

    private static func interactiveJS() -> String {
        return """
        <script>
        let sortCol = null;
        let sortDir = null;
        const tbody = document.querySelector('tbody');
        const rows = Array.from(tbody.querySelectorAll('tr'));
        const originalRows = rows.slice();

        function sortColumn(colIndex) {
            const headers = document.querySelectorAll('thead th');
            if (sortCol === colIndex) {
                if (sortDir === 'asc') { sortDir = 'desc'; }
                else if (sortDir === 'desc') { sortCol = null; sortDir = null; }
            } else {
                sortCol = colIndex;
                sortDir = 'asc';
            }

            headers.forEach(h => { h.classList.remove('sort-active'); h.querySelector('.sort-indicator')?.remove(); });

            if (sortCol !== null) {
                const th = headers[colIndex + 1];
                th.classList.add('sort-active');
                const indicator = document.createElement('span');
                indicator.className = 'sort-indicator';
                indicator.innerHTML = sortDir === 'asc'
                    ? '<svg viewBox="0 0 8 8"><polygon points="4,1 7,6 1,6"/></svg>'
                    : '<svg viewBox="0 0 8 8"><polygon points="4,7 1,2 7,2"/></svg>';
                th.appendChild(indicator);
            }

            const sorted = sortCol !== null ? rows.slice().sort((a, b) => {
                const cellA = a.children[colIndex + 1]?.textContent?.trim() || '';
                const cellB = b.children[colIndex + 1]?.textContent?.trim() || '';
                const numA = parseFloat(cellA.replace(/,/g, ''));
                const numB = parseFloat(cellB.replace(/,/g, ''));
                let cmp;
                if (!isNaN(numA) && !isNaN(numB)) { cmp = numA - numB; }
                else { cmp = cellA.localeCompare(cellB); }
                return sortDir === 'desc' ? -cmp : cmp;
            }) : originalRows;

            sorted.forEach(r => tbody.appendChild(r));
            renumberRows();
        }

        function filterRows(query) {
            const q = query.toLowerCase();
            let visible = 0;
            rows.forEach(row => {
                const cells = Array.from(row.children).slice(1);
                const match = !q || cells.some(c => c.textContent.toLowerCase().includes(q));
                row.style.display = match ? '' : 'none';
                if (match) visible++;
            });
            const countEl = document.getElementById('match-count');
            if (countEl) countEl.textContent = q ? visible + '/' + rows.length : '';
            const rowCountEl = document.getElementById('row-count');
            if (rowCountEl) rowCountEl.textContent = q ? visible + '/' + rows.length : String(rows.length);
        }

        function selectRow(tr) {
            document.querySelectorAll('tbody tr.selected').forEach(r => r.classList.remove('selected'));
            tr.classList.add('selected');
        }

        function renumberRows() {
            const visible = rows.filter(r => r.style.display !== 'none');
            visible.forEach((r, i) => { r.children[0].textContent = i + 1; });
        }

        function setDensity(density) {
            const win = document.querySelector('.ql-window');
            win.classList.remove('density-compact', 'density-comfortable');
            if (density === 'compact') win.classList.add('density-compact');
            else if (density === 'comfortable') win.classList.add('density-comfortable');
        }
        </script>
        """
    }

    // MARK: - HTML Escaping

    static func escapeHTML(_ string: String) -> String {
        string.replacingOccurrences(of: "&", with: "&amp;")
              .replacingOccurrences(of: "<", with: "&lt;")
              .replacingOccurrences(of: ">", with: "&gt;")
              .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func escapeAttribute(_ string: String) -> String {
        escapeHTML(string)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate && xcodebuild -project csvql.xcodeproj -scheme csvqlTests \
  -destination 'platform=macOS' \
  -only-testing:csvqlTests/CSVRendererTests test 2>&1 | tail -10
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Shared/CSVRenderer.swift csvqlTests/CSVRendererTests.swift
git commit -m "feat: HTML renderer with type-aware cell rendering and interactive JS"
```

---

### Task 9: QuickLook PreviewController

**Files:**
- Modify: `csvqlPreview/PreviewController.swift`

- [ ] **Step 1: Implement PreviewController**

```swift
import Cocoa
import QuickLookUI
import Quartz
import WebKit

class PreviewController: NSViewController, QLPreviewingController {

    private let webView: WKWebView

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        let config = WKWebViewConfiguration()
        self.webView = WKWebView(frame: NSRect(origin: .zero, size: CSVRenderer.previewSize), configuration: config)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override func loadView() {
        webView.autoresizingMask = [.width, .height]
        self.view = webView
        preferredContentSize = CSVRenderer.previewSize
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let data = try CSVData.load(from: url)
            let html = CSVRenderer.render(data: data, interactive: false)
            webView.loadHTMLString(html, baseURL: nil)
            handler(nil)
        } catch {
            handler(error)
        }
    }
}
```

- [ ] **Step 2: Verify project compiles**

```bash
xcodegen generate && xcodebuild -project csvql.xcodeproj -scheme csvql \
  -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add csvqlPreview/PreviewController.swift
git commit -m "feat: QuickLook extension with WKWebView preview"
```

---

### Task 10: Host App — Document & Window

**Files:**
- Modify: `csvql/DocumentController.swift`
- Modify: `csvql/DocumentWindowController.swift`
- Modify: `csvql/AppDelegate.swift`

- [ ] **Step 1: Implement DocumentController**

```swift
import Cocoa

final class DocumentController: NSDocument {

    override class var autosavesInPlace: Bool { false }
    override var isDocumentEdited: Bool { false }

    override func makeWindowControllers() {
        let wc = DocumentWindowController()
        addWindowController(wc)
        if let url = fileURL {
            wc.loadCSV(at: url)
        }
    }

    override func read(from url: URL, ofType typeName: String) throws {
    }
}
```

- [ ] **Step 2: Implement DocumentWindowController**

```swift
import Cocoa
import WebKit

final class DocumentWindowController: NSWindowController, WKScriptMessageHandler {

    private let webView: WKWebView
    private var loadedURL: URL?

    convenience init() {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(
            frame: NSRect(origin: .zero, size: CSVRenderer.previewSize),
            configuration: config
        )

        let window = CSVWindow(
            contentRect: NSRect(origin: .zero, size: CSVRenderer.previewSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1.0)

        self.init(window: window)
        self.webView = webView

        config.userContentController.add(self, name: "csvql")

        webView.autoresizingMask = [.width, .height]
        window.contentView = webView

        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let width = min(max(visibleFrame.width * 0.74, 860), 1280)
            let height = min(max(visibleFrame.height * 0.86, 700), 900)
            let size = NSSize(width: width, height: height)
            let origin = NSPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.midY - size.height / 2
            )
            window.setFrame(NSRect(origin: origin, size: size), display: false)
        }
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "csvql")
    }

    func loadCSV(at url: URL) {
        do {
            let data = try CSVData.load(from: url)
            let html = CSVRenderer.render(data: data, interactive: true)
            webView.loadHTMLString(html, baseURL: nil)
            loadedURL = url
            window?.title = url.lastPathComponent
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        if action == "close" {
            window?.performClose(nil)
        }
    }

    // MARK: - Density

    private func setDensity(_ density: String) {
        webView.evaluateJavaScript("setDensity('\(density)')", completionHandler: nil)
    }

    @objc func setCompact(_ sender: Any?) { setDensity("compact") }
    @objc func setRegular(_ sender: Any?) { setDensity("regular") }
    @objc func setComfortable(_ sender: Any?) { setDensity("comfortable") }
}

private final class CSVWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch key {
        case "w":
            performClose(nil)
            return true
        case "q":
            NSApp.terminate(nil)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}
```

- [ ] **Step 3: Update AppDelegate**

```swift
import Cocoa

@main
enum Main {
    private static let appDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.delegate = appDelegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        NSDocumentController.shared.openDocument(nil)
        return true
    }
}
```

- [ ] **Step 4: Verify project compiles**

```bash
xcodegen generate && xcodebuild -project csvql.xcodeproj -scheme csvql \
  -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add csvql/DocumentController.swift csvql/DocumentWindowController.swift csvql/AppDelegate.swift
git commit -m "feat: host app with document-based window and interactive WKWebView"
```

---

### Task 11: MainMenu Tests (TDD)

**Files:**
- Modify: `csvqlTests/MainMenuTests.swift`

- [ ] **Step 1: Write tests**

```swift
import XCTest

final class MainMenuTests: XCTestCase {

    func testMenuHasAppEditAndViewItems() {
        let menu = MainMenu.make()
        XCTAssertEqual(menu.items.count, 3)
        XCTAssertEqual(menu.items[0].title, "csvql")
        XCTAssertEqual(menu.items[1].title, "Edit")
        XCTAssertEqual(menu.items[2].title, "View")
    }

    func testAppMenuHasQuit() {
        let menu = MainMenu.make()
        let appSubmenu = menu.items[0].submenu!
        let quit = appSubmenu.items.first { $0.title == "Quit" }
        XCTAssertNotNil(quit)
        XCTAssertEqual(quit?.keyEquivalent, "q")
        XCTAssertEqual(quit?.action, #selector(NSApplication.terminate(_:)))
    }

    func testEditMenuHasCopyAndSelectAll() {
        let menu = MainMenu.make()
        let editSubmenu = menu.items[1].submenu!

        let copy = editSubmenu.items.first { $0.title == "Copy" }
        XCTAssertNotNil(copy)
        XCTAssertEqual(copy?.keyEquivalent, "c")

        let selectAll = editSubmenu.items.first { $0.title == "Select All" }
        XCTAssertNotNil(selectAll)
        XCTAssertEqual(selectAll?.keyEquivalent, "a")
    }

    func testViewMenuHasDensityOptions() {
        let menu = MainMenu.make()
        let viewSubmenu = menu.items[2].submenu!
        XCTAssertEqual(viewSubmenu.items.count, 3)

        let compact = viewSubmenu.items.first { $0.title == "Compact" }
        XCTAssertNotNil(compact)
        XCTAssertEqual(compact?.keyEquivalent, "1")

        let regular = viewSubmenu.items.first { $0.title == "Regular" }
        XCTAssertNotNil(regular)
        XCTAssertEqual(regular?.keyEquivalent, "2")

        let comfortable = viewSubmenu.items.first { $0.title == "Comfortable" }
        XCTAssertNotNil(comfortable)
        XCTAssertEqual(comfortable?.keyEquivalent, "3")
    }
}
```

- [ ] **Step 2: Run tests**

```bash
xcodegen generate && xcodebuild -project csvql.xcodeproj -scheme csvqlTests \
  -destination 'platform=macOS' \
  -only-testing:csvqlTests/MainMenuTests test 2>&1 | tail -10
```

Expected: All tests PASS (MainMenu already implemented in Task 1 stubs).

- [ ] **Step 3: Commit**

```bash
git add csvqlTests/MainMenuTests.swift
git commit -m "test: MainMenu unit tests"
```

---

### Task 12: Run All Tests & Build Verification

**Files:** None (verification only)

- [ ] **Step 1: Run full test suite**

```bash
xcodegen generate && xcodebuild -project csvql.xcodeproj -scheme csvqlTests \
  -destination 'platform=macOS' test 2>&1 | grep -E '(Test Suite|Test Case|Executed|FAIL|PASS)' | tail -30
```

Expected: All tests pass.

- [ ] **Step 2: Build Release**

```bash
xcodebuild -project csvql.xcodeproj -scheme csvql -configuration Release \
  -destination 'platform=macOS' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Verify extension is embedded in app**

```bash
BUILT="$(xcodebuild -project csvql.xcodeproj -scheme csvql -configuration Release \
  -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $NF}')" && \
  ls "$BUILT/csvql.app/Contents/PlugIns/"
```

Expected: `csvqlPreview.appex`

- [ ] **Step 4: Commit any fixes needed**

Only if Steps 1-3 revealed issues.

---

### Task 13: Install & Manual Test

**Files:** None

- [ ] **Step 1: Run `make install`**

```bash
make install
```

Expected: Installs to /Applications, registers extension, outputs "OK: Extension registered from /Applications".

- [ ] **Step 2: Test QuickLook with fixture files**

```bash
qlmanage -p csvqlTests/Fixtures/sales.csv
```

Expected: QuickLook window shows styled dark-themed table with typed cells.

```bash
qlmanage -p csvqlTests/Fixtures/observatory.tsv
```

Expected: Tab-delimited data rendered correctly.

```bash
qlmanage -p csvqlTests/Fixtures/deploys.csv
```

Expected: SHA chips, status pills, email coloring visible.

- [ ] **Step 3: Test host app**

```bash
open -a csvql csvqlTests/Fixtures/sales.csv
```

Expected: Host app opens with interactive table — search box visible, click headers to sort, click rows to select.

- [ ] **Step 4: Create CLAUDE.md**

Write a CLAUDE.md with build/test commands, architecture overview, and any learnings discovered during implementation.

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: csvql v1.0 — QuickLook + host app for CSV/TSV files"
```
