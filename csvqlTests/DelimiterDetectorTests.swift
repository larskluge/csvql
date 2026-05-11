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
