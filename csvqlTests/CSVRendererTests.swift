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

    func testNoHtmlTitlebar() {
        let staticHtml = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertFalse(staticHtml.contains("class=\"titlebar\""))
        let interactiveHtml = CSVRenderer.render(data: sampleData(), interactive: true)
        XCTAssertFalse(interactiveHtml.contains("class=\"titlebar\""))
    }

    func testStaticHasNoSubToolbar() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertFalse(html.contains("<div class=\"sub-toolbar\">"))
    }

    // MARK: - Footer Pills

    func testFooterShowsDelimiterPill() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains("delimiter"))
        XCTAssertTrue(html.contains("Comma"))
    }

    func testFooterShowsEncodingPill() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains("encoding"))
        XCTAssertTrue(html.contains("UTF-8"))
    }

    // MARK: - Table Headers

    func testTableHeadersPreserveCase() {
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
        XCTAssertTrue(html.contains("\u{2014}"))
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
        XCTAssertTrue(html.contains("LF"))
    }

    func testFooterShowsCsvqlBadge() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertTrue(html.contains("csvql-badge"))
        XCTAssertTrue(html.contains("csvql-dot"))
    }

    // MARK: - Interactive vs Static

    func testStaticHasNoSearchBox() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertFalse(html.contains("class=\"search-box\""))
    }

    func testInteractiveHasSearchBox() {
        let html = CSVRenderer.render(data: sampleData(), interactive: true)
        XCTAssertTrue(html.contains("class=\"search-box\""))
    }

    func testInteractiveHasSortableHeaders() {
        let html = CSVRenderer.render(data: sampleData(), interactive: true)
        XCTAssertTrue(html.contains("sortable\""))
    }

    func testStaticHasNoSortableHeaders() {
        let html = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertFalse(html.contains("sortable\""))
    }

    func testNoCloseButton() {
        let staticHtml = CSVRenderer.render(data: sampleData(), interactive: false)
        XCTAssertFalse(staticHtml.contains("close-btn"))
        let interactiveHtml = CSVRenderer.render(data: sampleData(), interactive: true)
        XCTAssertFalse(interactiveHtml.contains("close-btn"))
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
