import Foundation

enum LyricFormattingError: LocalizedError, Equatable {
    case wordTooLong(required: Int, limit: Int)

    var errorDescription: String? {
        switch self {
        case let .wordTooLong(required, limit):
            "A word needs \(required) characters, but the line limit is \(limit). Increase the limit to at least \(required), or choose Unlimited in Settings. No words have been split or removed."
        }
    }
}

/// Pure formatting: original line and stanza boundaries survive reflow; words remain intact.
enum LyricFormatter {
    static func format(_ source: String, options: FormattingOptions) throws -> FormattedLyrics {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return FormattedLyrics(lines: []) }
        let limit = options.lineLimit.map { max(1, $0) }
        var result: [String] = []
        for original in normalized.components(separatedBy: "\n") {
            let words = original.split(whereSeparator: \.isWhitespace).map(String.init)
            if words.isEmpty {
                if options.preserveBlankLines { result.append("") }
                continue
            }
            var line = ""
            for word in words {
                if let limit, word.count > limit {
                    throw LyricFormattingError.wordTooLong(required: word.count, limit: limit)
                }
                if let limit, !line.isEmpty, line.count + 1 + word.count > limit {
                    result.append(line)
                    line = ""
                }
                line += (line.isEmpty ? "" : " ") + word
                if options.punctuation.shouldBreak(after: word) {
                    result.append(line)
                    line = ""
                }
            }
            if !line.isEmpty { result.append(line) }
        }
        return FormattedLyrics(lines: result)
    }

    /// LRCLIB may supply only LRC. Remove timing and known metadata, never bracketed lyric headings.
    static func plainText(fromLRC source: String) -> String {
        source.components(separatedBy: .newlines).compactMap { line -> String? in
            if line.range(of: #"^\[(ar|ti|al|by|offset|re|ve|length):.*\]$"#, options: .regularExpression) != nil {
                return nil
            }
            return line.replacingOccurrences(of: #"^(\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\])+\s*"#,
                                            with: "", options: .regularExpression)
                .replacingOccurrences(of: #"<\d{1,3}:\d{2}(?:[.:]\d{1,3})?>"#, with: "", options: .regularExpression)
        }.joined(separator: "\n")
    }
}
