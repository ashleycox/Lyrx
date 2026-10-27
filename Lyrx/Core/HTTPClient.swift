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
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw LyricServiceError.invalidResponse }
        guard response.url?.scheme == "https" else { throw LyricServiceError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            throw response.statusCode == 404 ? LyricServiceError.noLyrics : .unavailable(response.statusCode)
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
}
