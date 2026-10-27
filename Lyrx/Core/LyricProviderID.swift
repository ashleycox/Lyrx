import Foundation

/// Stable identifiers are stored locally; display names may change independently.
enum LyricProviderID: String, CaseIterable, Codable, Sendable, Identifiable {
    case lrclib
    case lyricsOVH

    var id: String { rawValue }
    var name: String { self == .lrclib ? "LRCLIB" : "lyrics.ovh" }
    var website: URL {
        // These compile-time constants are controlled by the app, never by API responses.
        URL(string: self == .lrclib ? "https://lrclib.net" : "https://lyrics.ovh")!
    }
    var summary: String {
        switch self {
        case .lrclib: "Community lyric database. Search by title, artist, or album."
        case .lyricsOVH: "Song suggestions from Deezer; lyrics from several sources. May contact LRCLIB itself."
        }
    }
}
