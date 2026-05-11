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
        let values = ["a1b2c3d", "e4f5a6b", "c7d8e9f"]
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
        let values = ["100", "200", "300", "400", "abc"]
        XCTAssertEqual(TypeInferrer.infer(column: values, header: "val"), .number)
    }

    func testNumberBelow80PercentFallsToText() {
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
