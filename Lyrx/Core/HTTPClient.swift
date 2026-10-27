import Foundation

/// Injection point for fixture-based tests; production never persists requests or lyrics.
protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> Data
}

struct HTTPClient: HTTPTransport {
    private let session: URLSession
    static let maximumBytes = 4 * 1_024 * 1_024

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 18
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        session = URLSession(configuration: configuration)
    }

    func data(for request: URLRequest) async throws -> Data {
        let redirectPolicy: (any URLSessionTaskDelegate)? =
            request.url?.host == "lrc.red" ? ContactRedirectPolicy() : nil
        let (bytes, response) = try await session.bytes(for: request, delegate: redirectPolicy)
        guard let response = response as? HTTPURLResponse else { throw LyricServiceError.invalidResponse }
        guard response.url?.scheme == "https" else { throw LyricServiceError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            throw response.statusCode == 404
                ? LyricServiceError.noLyrics
                : .unavailable(
                    response.statusCode,
                    retryAfterSeconds: Self.retryAfterSeconds(response.value(forHTTPHeaderField: "Retry-After")))
        }
        guard response.expectedContentLength <= Self.maximumBytes else { throw LyricServiceError.tooLarge }
        var data = Data()
        // A streaming limit also bounds responses without Content-Length and decompressed bodies.
        for try await byte in bytes {
            if data.count.isMultiple(of: 4096) { try Task.checkCancellation() }
            guard data.count < Self.maximumBytes else { throw LyricServiceError.tooLarge }
            data.append(byte)
        }
        try Task.checkCancellation()
        return data
    }

    /// Accept delta-seconds only. Unsupported dates or malformed values never trigger an early retry.
    static func retryAfterSeconds(_ header: String?) -> Int? {
        guard let value = header?.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) })
        else { return nil }
        return Int(value)
    }
}
