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
        let lineEnding = CSVParser.detectLineEnding(in: content)

        let maxCols = ([parsed.headers] + parsed.rows).map(\.count).max() ?? 0

        let typesFromData = TypeInferrer.inferAll(headers: parsed.headers, rows: parsed.rows)
        let hasHeaders = isHeaderRow(parsed.headers, dataTypes: typesFromData)

        let headers: [String]
        let rows: [[String]]
        let types: [ColumnType]

        if hasHeaders {
            var h = parsed.headers
            while h.count < maxCols { h.append(columnLabel(h.count)) }
            headers = h
            rows = parsed.rows
            types = TypeInferrer.inferAll(headers: headers, rows: rows)
        } else {
            headers = (0..<maxCols).map { columnLabel($0) }
            rows = [parsed.headers] + parsed.rows
            types = TypeInferrer.inferAll(headers: headers, rows: rows)
        }

        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modDate = attrs?[.modificationDate] as? Date

        return CSVData(
            fileName: url.lastPathComponent,
            filePath: url.path,
            fileSize: data.count,
            modifiedDate: modDate,
            headers: headers,
            rows: rows,
            types: types,
            delimiter: delimiter,
            encoding: data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) ? "UTF-16" : "UTF-8",
            lineEnding: lineEnding
        )
    }

    private static func isHeaderRow(_ row: [String], dataTypes: [ColumnType]) -> Bool {
        guard !row.isEmpty else { return true }
        var nonTextCols = 0
        var headerMatchesType = 0
        for (i, value) in row.enumerated() {
            guard i < dataTypes.count, !value.isEmpty else { continue }
            let type = dataTypes[i]
            if type == .text { continue }
            nonTextCols += 1
            if TypeInferrer.valueMatchesType(value, type: type) {
                headerMatchesType += 1
            }
        }
        if nonTextCols > 0 && headerMatchesType == nonTextCols {
            return false
        }
        return true
    }

    static func columnLabel(_ index: Int) -> String {
        var label = ""
        var n = index
        repeat {
            label = String(Character(UnicodeScalar(65 + (n % 26))!)) + label
            n = n / 26 - 1
        } while n >= 0
        return label
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
