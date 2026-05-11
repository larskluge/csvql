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

    static func valueMatchesType(_ value: String, type: ColumnType) -> Bool {
        guard !value.isEmpty else { return false }
        switch type {
        case .bool: return isBool(value)
        case .number: return matches(numberPattern, value)
        case .date: return matches(datePattern, value)
        case .link: return value.lowercased().hasPrefix("http://") || value.lowercased().hasPrefix("https://")
        case .email: return matches(emailPattern, value)
        case .sha: return matches(shaPattern, value.lowercased())
        case .text: return true
        }
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
