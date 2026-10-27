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
        case .unavailable(let status) where status == 400 || status == 422:
            "The service could not accept this search (HTTP \(status)). Try a shorter search or clear the filters."
        case .unavailable(401):
            "The service requires authorization (HTTP 401). Enable another provider while access is unavailable."
        case .unavailable(403):
            "The service denied this request (HTTP 403). Try again later or enable another provider."
        case .unavailable(429):
            "The service's request limit has been reached (HTTP 429). Wait before searching again."
        case .unavailable(let status):
            "The service returned an error (HTTP \(status)). Try again later or enable another provider."
        case .noLyrics: "This match has no available lyrics. Choose another match."
        case .invalidURL: "The search could not be sent. Try a different search."
        }
    }
}
