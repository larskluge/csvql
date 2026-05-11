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
