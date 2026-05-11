import Foundation

struct CSVData {
    var headers: [String]
    var rows: [[String]]
    var types: [ColumnType]
    var delimiter: Character
    var encoding: String.Encoding
    var lineEnding: String
}
