import Foundation

/// Nil means unlimited; finite widths count extended grapheme clusters, including punctuation.
struct FormattingOptions: Equatable, Sendable {
    var lineLimit: Int? = 40
    var punctuation: PunctuationBreak = .original
    var preserveBlankLines = true
}

enum PunctuationBreak: String, CaseIterable, Sendable, Identifiable {
    case original, commas, sentences, all
    var id: String { rawValue }
    var name: String {
        switch self {
        case .original: "Original line breaks"
        case .commas: "Commas"
        case .sentences: "Full stops, questions, exclamations"
        case .all: "All punctuation boundaries"
        }
    }

    func shouldBreak(after word: String) -> Bool {
        // Closing quotes/brackets stay with the word; apostrophes and hyphens inside words never split it.
        let closing = CharacterSet(charactersIn: "\"'’”»)]}")
        let end = word.trimmingCharacters(in: closing).last
        guard let end else { return false }
        switch self {
        case .original: return false
        case .commas: return ",，、".contains(end)
        case .sentences: return ".!?。！？…".contains(end)
        case .all: return end.unicodeScalars.allSatisfy { CharacterSet.punctuationCharacters.contains($0) }
        }
    }
}
