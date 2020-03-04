import Foundation

struct BuildErrorParser {
    struct BuildError {
        let filePath: String
        let lineNumber: Int?
        let columnNumber: Int?
        let errorMessage: String
    }

    static func parseBuildErrors(fromString string: String) -> [BuildError] {
        let lines = string.split { $0.isNewline }
        let errors: [BuildError] = lines.compactMap {
            if $0.hasPrefix("e: ") {
                return parseCompilationError(fromLine: $0)
            } else if $0.contains(" AAPT: ") {
                return parseXmlError(fromLine: $0)
            } else {
                return nil
            }
        }
        return errors
    }

    private static func parseCompilationError(fromLine substring: Substring) -> BuildError? {
        let contents = substring.dropPrefix(prefix: "e: ")
        guard let beforeLineColumn = contents.range(of: ": (") else { return nil }
        guard let afterLineColumn = contents.range(of: "): ") else { return nil }
        guard beforeLineColumn.upperBound < afterLineColumn.lowerBound else { return nil }
        let filePath = contents.prefix(upTo: beforeLineColumn.lowerBound)
        let errorMessage = contents.suffix(from: afterLineColumn.upperBound)
        let lineColumn = contents[beforeLineColumn.upperBound..<afterLineColumn.lowerBound].components(separatedBy: ", ")
        guard lineColumn.count == 2 else { return nil }
        guard let line = Int(lineColumn[0]) else { return nil }
        guard let column = Int(lineColumn[1]) else { return nil }
        return BuildError(
            filePath: String(filePath),
            lineNumber: line,
            columnNumber: column,
            errorMessage: String(errorMessage)
        )
    }

    private static func parseXmlError(fromLine substring: Substring) -> BuildError? {
        guard let beforeLineNumber = substring.range(of: ":") else { return nil }
        guard let afterLineNumber = substring.range(of: ": AAPT: error: ") else { return nil }
        let filePath = substring.prefix(upTo: beforeLineNumber.lowerBound)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let errorMessage = substring.suffix(from: afterLineNumber.upperBound)
        return BuildError(
            filePath: String(filePath),
            lineNumber: parseXmlLineNumber(fromLine: substring),
            columnNumber: nil,
            errorMessage: String(errorMessage)
        )
    }

    private static func parseXmlLineNumber(fromLine substring: Substring) -> Int? {
        guard let beforeLineNumber = substring.range(of: ":") else { return nil }
        guard let afterLineNumber = substring.range(of: ": AAPT: error: ") else { return nil }
        guard beforeLineNumber.upperBound < afterLineNumber.lowerBound else { return nil }
        return Int(substring[beforeLineNumber.upperBound..<afterLineNumber.lowerBound])
    }
}
