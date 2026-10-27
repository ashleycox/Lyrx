import Foundation

/// Stable identifiers are stored locally; display names may change independently.
enum LyricProviderID: String, CaseIterable, Codable, Sendable, Identifiable {
    case lrclib
    case lyricsOVH
    case lrcRed

    var id: String { rawValue }
    var name: String {
        switch self {
        case .lrclib: "LRCLIB"
        case .lyricsOVH: "lyrics.ovh"
        case .lrcRed: "lrc.red"
        }
    }
    var shortcut: Character {
        switch self {
        case .lrclib: "1"
        case .lyricsOVH: "2"
        case .lrcRed: "3"
        }
    }
    var website: URL {
        // These compile-time constants are controlled by the app, never by API responses.
        switch self {
        case .lrclib: URL(string: "https://lrclib.net")!
        case .lyricsOVH: URL(string: "https://lyrics.ovh")!
        case .lrcRed: URL(string: "https://lrc.red")!
        }
    }
    var summary: String {
        switch self {
        case .lrclib: "Community lyric database. Search by title, artist, or album."
        case .lyricsOVH: "Song suggestions from Deezer; lyrics from several sources. May contact LRCLIB itself."
        case .lrcRed: "Lyrics and recording credits. Requires a contact email sent with requests."
        }
    }
}
