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
