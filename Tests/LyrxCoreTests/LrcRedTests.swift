import Foundation
import Testing

@testable import LyrxCore

private actor RoutedTransport: HTTPTransport {
    let responses: [String: String]
    let failure: LyricServiceError?
    private(set) var requests: [URLRequest] = []
    init(_ responses: [String: String] = [:], failure: LyricServiceError? = nil) {
        self.responses = responses
        self.failure = failure
    }
    func data(for request: URLRequest) async throws -> Data {
        requests.append(request)
        if let failure { throw failure }
        let key = (request.url?.host ?? "") + (request.url?.path ?? "")
        guard let response = responses[key] else { throw LyricServiceError.noLyrics }
        return Data(response.utf8)
    }
}

struct LrcRedTests {
    private let access = ProviderAccess(enabled: [.lrcRed], lrcRedEmail: "reader@example.invalid")
    private let match = LyricMatch(
        provider: .lrcRed, providerID: "USAAA2600001", title: "Harbor", artist: "Test Artist", album: "Dawn",
        detailsComplete: false)

    @Test(arguments: [
        "", "  ", "not an address", "user@example.invalid\r\nX-Header: injected", "user@example.invalid)",
    ])
    func missingOrInvalidEmailNeverContactsTheProvider(email: String) async throws {
        let transport = RoutedTransport()
        let client = ProviderClient(transport: transport)
        let access = ProviderAccess(enabled: [.lrcRed], lrcRedEmail: email)
        let response = try await client.search(.init(query: "Harbor"), access: access)
        #expect(response.matches.isEmpty)
        await #expect(throws: LyricServiceError.providerNotConfigured) {
            try await client.lyrics(for: match, access: access)
        }
        await #expect(throws: LyricServiceError.providerNotConfigured) {
            try await client.details(for: match, access: access)
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test func aSavedEmailDoesNotEnableTheProviderOrLeakToOthers() async throws {
        let transport = RoutedTransport([
            "lrclib.net/api/search": "[]", "api.lyrics.ovh/suggest/Harbor": #"{"data":[]}"#,
            "lrc.red/search.json": #"{"hits":[]}"#,
        ])
        let client = ProviderClient(transport: transport)
        var access = self.access
        access.enabled = [.lrclib, .lyricsOVH]
        _ = try await client.search(.init(query: "Harbor"), access: access)
        #expect(await transport.requests.allSatisfy { $0.url?.host != "lrc.red" })
        access.enabled.insert(.lrcRed)
        _ = try await client.search(.init(query: "Harbor"), access: access)
        for request in await transport.requests {
            let hasEmail = request.value(forHTTPHeaderField: "User-Agent")?.contains("reader@example.invalid") == true
            #expect(hasEmail == (request.url?.host == "lrc.red"))
            #expect(request.url?.absoluteString.contains("example.invalid") == false)
        }
    }

    @Test func searchLoadsTTMLAndFetchesCreditsOnlyOnRequest() async throws {
        let transport = RoutedTransport([
            "lrc.red/search.json":
                #"{"hits":[{"isrc":"USAAA2600001","title":"Harbor","artist":"Test Artist","album":"Dawn","duration":123.5,"year":2026,"sync":"word"}]}"#,
            "lrc.red/s/USAAA2600001.ttml":
                #"<tt xmlns="http://www.w3.org/ns/ttml"><body><div><p>Original fixture line</p><p>Another fixture line</p></div></body></tt>"#,
            "lrc.red/s/USAAA2600001.json":
                #"{"isrc":"USAAA2600001","title":"Harbor","artist":"Test Artist","album":"Dawn","songwriters":["Example Writer","Second Writer"],"released":"2026-01-01","language":"en","genres":["Folk"],"featured":["Guest Singer"],"sync":"word","custom_credit":{"producer":"Example Producer"}}"#,
        ])
        let client = ProviderClient(transport: transport)
        let response = try await client.search(.init(query: "Harbor", album: "Dawn"), access: access)
        let found = try #require(response.matches.first)
        #expect(found.provider == .lrcRed)
        #expect(!found.detailsComplete)
        #expect(!found.metadata.contains { $0.id == "sync" })
        #expect(try await client.lyrics(for: found, access: access) == "Original fixture line\nAnother fixture line")
        #expect(await transport.requests.count == 2)
        let detailed = try await client.details(for: found, access: access)
        #expect(detailed.detailsComplete)
        #expect(!detailed.metadata.contains { $0.id == "sync" })
        #expect(detailed.metadata.contains { $0.label == "Songwriters" && $0.value.contains("Example Writer") })
        #expect(detailed.metadata.contains { $0.value == "Example Producer" })
        #expect(detailed.sourceURL.absoluteString == "https://lrc.red/s/USAAA2600001")
        _ = try await client.details(for: detailed, access: access)
        #expect(await transport.requests.count == 3)
    }

    @Test func unavailableTTMLFallsBackToLRC() async throws {
        let transport = RoutedTransport([
            "lrc.red/s/USAAA2600001.lrc": "[00:01.00]Original fixture line\n[00:02.00]Another line"
        ])
        let lyrics = try await ProviderClient(transport: transport).lyrics(for: match, access: access)
        #expect(lyrics == "Original fixture line\nAnother line")
        #expect(await transport.requests.count == 2)
    }

    @Test(arguments: [LyricServiceError.unavailable(503), .invalidResponse])
    func serviceFailuresDoNotTriggerAnotherFormatRequest(error: LyricServiceError) async {
        let transport = RoutedTransport(failure: error)
        await #expect(throws: error) {
            try await ProviderClient(transport: transport).lyrics(for: match, access: access)
        }
        #expect(await transport.requests.count == 1)
    }

    @Test func contactRedirectsStayOnTheHTTPSOrigin() {
        let original = URL(string: "https://lrc.red/search.json")!
        #expect(ContactRedirectPolicy.permits(from: original, to: URL(string: "https://lrc.red/s/example.json")))
        for target in [
            "https://other.example/search", "http://lrc.red/search", "https://lrc.red:8443/search",
            "https://user@lrc.red/search",
        ] {
            #expect(!ContactRedirectPolicy.permits(from: original, to: URL(string: target)))
        }
    }
}
