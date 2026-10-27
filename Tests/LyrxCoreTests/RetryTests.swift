import Foundation
import Testing

@testable import LyrxCore

/// No network or elapsed-time waits: fixtures record attempts and the requested backoff.
private actor OverloadedTransport: HTTPTransport {
    let failure: LyricServiceError
    let recovers: Bool
    private(set) var requests: [URLRequest] = []
    private(set) var pauses: [Duration] = []

    init(_ failure: LyricServiceError, recovers: Bool = true) {
        self.failure = failure
        self.recovers = recovers
    }

    func data(for request: URLRequest) async throws -> Data {
        requests.append(request)
        if requests.count == 1 || !recovers { throw failure }
        return Data("Original fixture response".utf8)
    }

    func recordPause(_ duration: Duration) { pauses.append(duration) }
}

struct RetryTests {
    private var request: URLRequest { URLRequest(url: URL(string: "https://example.invalid/lyrics")!) }

    @Test(arguments: [429, 503]) func shortBackoffRetriesTheSameRequestOnce(status: Int) async throws {
        let transport = OverloadedTransport(.unavailable(status, retryAfterSeconds: 1))
        let client = RetryingHTTPTransport(transport: transport, pause: { await transport.recordPause($0) })
        #expect(try await client.data(for: request) == Data("Original fixture response".utf8))
        #expect(await transport.requests == [request, request])
        #expect(await transport.pauses == [.seconds(1)])
    }

    @Test func persistentOverloadStopsAfterSecondAttempt() async {
        let error = LyricServiceError.unavailable(503, retryAfterSeconds: 1)
        let transport = OverloadedTransport(error, recovers: false)
        let client = RetryingHTTPTransport(transport: transport, pause: { await transport.recordPause($0) })
        await #expect(throws: error) { try await client.data(for: request) }
        #expect(await transport.requests.count == 2)
        #expect(await transport.pauses == [.seconds(1)])
    }

    @Test(arguments: [
        LyricServiceError.unavailable(503), .unavailable(503, retryAfterSeconds: 60),
        .unavailable(503, retryAfterSeconds: -1), .unavailable(403, retryAfterSeconds: 1), .noLyrics,
    ]) func otherFailuresAndLongBackoffsAreNotRetried(error: LyricServiceError) async {
        let transport = OverloadedTransport(error)
        let client = RetryingHTTPTransport(transport: transport, pause: { await transport.recordPause($0) })
        await #expect(throws: error) { try await client.data(for: request) }
        #expect(await transport.requests.count == 1)
        #expect(await transport.pauses.isEmpty)
    }

    @Test func cancellationDuringBackoffSendsNoSecondRequest() async {
        let transport = OverloadedTransport(.unavailable(503, retryAfterSeconds: 1))
        let client = RetryingHTTPTransport(transport: transport, pause: { _ in throw CancellationError() })
        await #expect(throws: CancellationError.self) { try await client.data(for: request) }
        #expect(await transport.requests.count == 1)
    }

    @Test func writesAreNeverRetried() async {
        let error = LyricServiceError.unavailable(503, retryAfterSeconds: 1)
        let transport = OverloadedTransport(error)
        let client = RetryingHTTPTransport(transport: transport, pause: { await transport.recordPause($0) })
        var request = request
        request.httpMethod = "POST"
        await #expect(throws: error) { try await client.data(for: request) }
        #expect(await transport.requests.count == 1)
        #expect(await transport.pauses.isEmpty)
    }

    @Test func retryHeaderDoesNotMistakeAnInvalidValueForZero() {
        #expect(HTTPClient.retryAfterSeconds(" 1 ") == 1)
        #expect(HTTPClient.retryAfterSeconds("0") == 0)
        #expect(HTTPClient.retryAfterSeconds("60") == 60)
        for header in ["", "-1", "+1", "1.5", "nan", "999999999999999999999999", "Wed, 28 Oct 2026 00:00:00 GMT"] {
            #expect(HTTPClient.retryAfterSeconds(header) == nil)
        }
        #expect(HTTPClient.retryAfterSeconds(nil) == nil)
    }
}
