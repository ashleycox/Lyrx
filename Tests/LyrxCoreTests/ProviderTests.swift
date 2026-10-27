import Foundation
import Testing
@testable import LyrxCore

private actor FixtureTransport: HTTPTransport {
    var requests: [URLRequest] = []
    let bodies: [String: String]
    init(_ bodies: [String: String]) { self.bodies = bodies }
    func data(for request: URLRequest) async throws -> Data {
        requests.append(request)
        guard let host = request.url?.host, let body = bodies[host] else { throw URLError(.timedOut) }
        return Data(body.utf8)
    }
}

struct ProviderTests {
    private let record = #"[{"id":42,"trackName":"Harbor","artistName":"Test Artist","albumName":"Dawn","instrumental":false,"plainLyrics":"Original test line","syncedLyrics":null}]"#

    @Test func disabledProviderReceivesNoRequest() async throws {
        let transport = FixtureTransport(["lrclib.net": record])
        let response = try await ProviderClient(transport: transport).search(.init(query: "Harbor"), enabled: [.lrclib])
        #expect(response.matches.count == 1)
        let requests = await transport.requests
        #expect(requests.count == 1)
        #expect(requests[0].url?.host == "lrclib.net")
        #expect(requests[0].value(forHTTPHeaderField: "Accept") == "application/json")
    }
    @Test func providerFailureDoesNotLoseSuccessfulResults() async throws {
        let transport = FixtureTransport(["lrclib.net": record])
        let result = try await ProviderClient(transport: transport).search(.init(query: "Harbor"), enabled: Set(LyricProviderID.allCases))
        #expect(result.matches.count == 1)
        #expect(result.notices.map(\.provider) == [.lyricsOVH])
    }
    @Test func malformedJSONIsReported() async throws {
        let transport = FixtureTransport(["lrclib.net": "<html>unavailable</html>"])
        let result = try await ProviderClient(transport: transport).search(.init(query: "Harbor"), enabled: [.lrclib])
        #expect(result.matches.isEmpty)
        #expect(result.notices.count == 1)
    }
    @Test func lyricsCanComeFromLRCOnly() async throws {
        let transport = FixtureTransport(["lrclib.net": #"[{"id":1,"trackName":"Example","artistName":"Test","syncedLyrics":"[00:01.00]Original words"}]"#])
        let result = try await ProviderClient(transport: transport).search(.init(query: "Example"), enabled: [.lrclib])
        #expect(result.matches.first?.lyrics == "Original words")
    }
    @Test func filtersAreURLQueryEncodedAndAppliedLocally() async throws {
        let transport = FixtureTransport(["lrclib.net": record])
        let result = try await ProviderClient(transport: transport).search(.init(query: "A & B?", artist: "Other"), enabled: [.lrclib])
        #expect(result.matches.isEmpty)
        let request = try #require(await transport.requests.first)
        let url = try #require(request.url)
        #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "A & B?")
    }
    @Test func pathComponentsCannotInjectQueryOrPath() async throws {
        let transport = FixtureTransport(["api.lyrics.ovh": #"{"lyrics":"Original line"}"#])
        let match = LyricMatch(provider: .lyricsOVH, providerID: "1", title: "A?B#C%", artist: "AC/DC")
        #expect(try await ProviderClient(transport: transport).lyrics(for: match) == "Original line")
        let request = try #require(await transport.requests.first)
        let url = try #require(request.url)
        #expect(url.query == nil && url.fragment == nil)
        #expect(url.absoluteString.contains("AC%2FDC"))
        #expect(url.absoluteString.contains("A%3FB%23C%25"))
    }
    @Test func suggestionsDecodeMetadata() async throws {
        let transport = FixtureTransport(["api.lyrics.ovh": #"{"data":[{"id":7,"title":"Harbor","artist":{"name":"Test Artist"},"album":{"title":"Dawn"}}]}"#])
        let result = try await ProviderClient(transport: transport).search(.init(query: "Harbor"), enabled: [.lyricsOVH])
        #expect(result.matches.first?.album == "Dawn")
        #expect(result.matches.first?.provider == .lyricsOVH)
    }
    @Test func exactOVHFiltersSkipSuggestionLookup() async throws {
        let transport = FixtureTransport([:])
        let result = try await ProviderClient(transport: transport).search(.init(artist: "Test", title: "Harbor"), enabled: [.lyricsOVH])
        #expect(result.matches.count == 1)
        #expect(await transport.requests.isEmpty)
    }
    @Test func exactTitleAndArtistWinRegardlessOfArrivalOrder() {
        let exact = LyricMatch(provider: .lyricsOVH, providerID: "2", title: "Harbor", artist: "Test Artist")
        let other = LyricMatch(provider: .lrclib, providerID: "1", title: "Harbor Live", artist: "Other", lyrics: "Example")
        let request = SearchRequest(query: "Test Artist Harbor")
        #expect(MatchRanker.ranked([other, exact, exact], for: request).map(\.id) == [exact.id, other.id])
        #expect(MatchRanker.ranked([exact, other], for: request).first == exact)
    }
    @Test func cancellationIsNotAProviderWarning() async {
        let task = Task {
            try await ProviderClient(transport: FixtureTransport([:])).search(.init(query: "Example"), enabled: [.lrclib])
        }
        task.cancel()
        do { _ = try await task.value; Issue.record("Expected cancellation") }
        catch { #expect(error is CancellationError) }
    }
}
