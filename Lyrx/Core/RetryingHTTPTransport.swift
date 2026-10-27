import Foundation

/// A short, server-requested backoff can recover overload without looping or changing providers.
struct RetryingHTTPTransport: HTTPTransport {
    private let transport: any HTTPTransport
    private let pause: @Sendable (Duration) async throws -> Void

    init(
        transport: any HTTPTransport = HTTPClient(),
        pause: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.transport = transport
        self.pause = pause
    }

    func data(for request: URLRequest) async throws -> Data {
        try Task.checkCancellation()
        do {
            return try await transport.data(for: request)
        } catch let error as LyricServiceError {
            // Only idempotent reads qualify, and only when the server explicitly asks for a short wait.
            // A longer/unknown delay is surfaced to the user instead of clamped or ignored.
            guard request.httpMethod == "GET",
                case .unavailable(let status, let seconds?) = error,
                status == 429 || status == 503, (0...2).contains(seconds)
            else { throw error }
            try Task.checkCancellation()
            try await pause(.seconds(max(1, seconds)))
            try Task.checkCancellation()
            // Outside the first attempt's catch: a second failure is returned, never retried again.
            return try await transport.data(for: request)
        }
    }
}
