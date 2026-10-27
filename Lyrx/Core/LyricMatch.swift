import Foundation

/// Metadata and optional inline lyrics. Provider identity is retained for attribution.
struct LyricMatch: Identifiable, Equatable, Sendable {
    let provider: LyricProviderID
    let providerID: String
    let title: String
    let artist: String
    var album = ""
    var lyrics: String?
    var instrumental = false
    var metadata: [MetadataField] = []
    var detailsComplete = true

    var sourceURL: URL {
        provider == .lrcRed ? provider.website.appending(path: "s").appending(component: providerID) : provider.website
    }

    var id: String { "\(provider.rawValue):\(providerID)" }
    var hasLyrics: Bool { !(lyrics?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
}
