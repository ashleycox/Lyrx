import Foundation

/// User-facing failures deliberately omit URLs and search text.
enum LyricServiceError: LocalizedError, Sendable, Equatable {
    case invalidResponse, tooLarge
    case unavailable(Int)
    case noLyrics, invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The service returned an unreadable response. Try another provider."
        case .tooLarge: "The service response was too large to read safely."
        case .unavailable(429): "The service is busy. Wait a moment before searching again."
        case .unavailable: "The service is unavailable. Try again later or enable another provider."
        case .noLyrics: "This match has no available lyrics. Choose another match."
        case .invalidURL: "The search could not be sent. Try a different search."
        }
    }
}
