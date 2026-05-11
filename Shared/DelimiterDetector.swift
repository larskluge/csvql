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
