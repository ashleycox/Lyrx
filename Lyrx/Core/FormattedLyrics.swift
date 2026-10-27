import Foundation

/// Text-system ranges use UTF-16 while wrapping uses Swift Characters; never mix these units.
struct FormattedLyrics: Equatable, Sendable {
    let lines: [String]
    let text: String
    let ranges: [NSRange]

    init(lines: [String]) {
        self.lines = lines
        text = lines.joined(separator: "\n")
        var offset = 0
        ranges = lines.map { line in
            let length = line.utf16.count
            defer { offset += length + 1 }
            return NSRange(location: offset, length: length)
        }
    }

    func line(atUTF16Offset offset: Int) -> Int {
        ranges.lastIndex { $0.location <= offset } ?? 0
    }
}
