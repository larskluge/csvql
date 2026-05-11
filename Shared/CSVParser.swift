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
        let scalars = Array(content.unicodeScalars)
        for i in 0..<scalars.count {
            let scalar = scalars[i]
            if scalar == "\r" {
                if i + 1 < scalars.count, scalars[i + 1] == "\n" {
                    return "CRLF"
                }
                return "CR"
            }
            if scalar == "\n" {
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

        // Work at the Unicode scalar level to avoid \r\n being merged into a single grapheme
        let scalars = Array(content.unicodeScalars)
        var i = 0
        let delimScalar = delimiter.unicodeScalars.first!

        while i < scalars.count {
            let scalar = scalars[i]

            if inQuotes {
                if scalar == "\"" {
                    if i + 1 < scalars.count, scalars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                    } else {
                        inQuotes = false
                        i += 1
                    }
                } else {
                    currentField.unicodeScalars.append(scalar)
                    i += 1
                }
            } else {
                if scalar == "\"" {
                    inQuotes = true
                    i += 1
                } else if scalar == delimScalar {
                    currentRow.append(currentField)
                    currentField = ""
                    i += 1
                } else if scalar == "\r" {
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.allSatisfy({ $0.isEmpty }) || currentRow.count > 1 || !rows.isEmpty {
                        rows.append(currentRow)
                    }
                    currentRow = []
                    if i + 1 < scalars.count, scalars[i + 1] == "\n" {
                        i += 2
                    } else {
                        i += 1
                    }
                } else if scalar == "\n" {
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.allSatisfy({ $0.isEmpty }) || currentRow.count > 1 || !rows.isEmpty {
                        rows.append(currentRow)
                    }
                    currentRow = []
                    i += 1
                } else {
                    currentField.unicodeScalars.append(scalar)
                    i += 1
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
