import XCTest

final class CSVDocumentTests: XCTestCase {

    // MARK: - Column Labels

    func testColumnLabelSingleLetters() {
        XCTAssertEqual(CSVData.columnLabel(0), "A")
        XCTAssertEqual(CSVData.columnLabel(1), "B")
        XCTAssertEqual(CSVData.columnLabel(25), "Z")
    }

    func testColumnLabelDoubleLetters() {
        XCTAssertEqual(CSVData.columnLabel(26), "AA")
        XCTAssertEqual(CSVData.columnLabel(27), "AB")
        XCTAssertEqual(CSVData.columnLabel(51), "AZ")
        XCTAssertEqual(CSVData.columnLabel(52), "BA")
    }

    // MARK: - Header Detection

    func testHeaderlessFileUsesGeneratedLabels() {
        let url = Bundle(for: type(of: self)).url(forResource: "headerless", withExtension: "tsv")!
        let data = try! CSVData.load(from: url)
        XCTAssertEqual(data.headers, ["A", "B", "C", "D"])
        XCTAssertEqual(data.rows.count, 3)
        XCTAssertEqual(data.rows[0][0], "wa")
    }

    func testFileWithHeadersKeepsThem() {
        let url = Bundle(for: type(of: self)).url(forResource: "sales", withExtension: "csv")!
        let data = try! CSVData.load(from: url)
        XCTAssertEqual(data.headers.first, "order_id")
        XCTAssertEqual(data.rows.count, 8)
    }

    // MARK: - Column Count Consistency

    func testRowsPaddedToMaxColumnCount() {
        let url = Bundle(for: type(of: self)).url(forResource: "sales", withExtension: "csv")!
        let data = try! CSVData.load(from: url)
        XCTAssertEqual(data.headers.count, data.types.count)
    }
}
