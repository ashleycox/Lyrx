import Foundation

/// A snapshot of the search controls, immutable for the lifetime of a request.
struct SearchRequest: Equatable, Sendable {
    var query = ""
    var artist = ""
    var title = ""
    var album = ""

    var cleaned: Self {
        Self(
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            artist: artist.trimmingCharacters(in: .whitespacesAndNewlines),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            album: album.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    var isEmpty: Bool { [query, artist, title, album].allSatisfy { $0.isEmpty } }
    var suggestionQuery: String { [query, artist, title, album].filter { !$0.isEmpty }.joined(separator: " ") }

    /// Explicit filters are applied locally too, because provider matching differs.
    func accepts(_ match: LyricMatch) -> Bool {
        [(artist, match.artist), (title, match.title), (album, match.album)].allSatisfy { filter, value in
            filter.isEmpty || Self.normalized(value).contains(Self.normalized(filter))
        }
    }

    static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }
}
