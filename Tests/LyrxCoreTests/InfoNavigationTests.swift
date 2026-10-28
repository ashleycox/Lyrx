import Foundation
import Testing

@testable import LyrxCore

/// Captures scoped requests and controls detail completion without timers or network access.
private actor InfoService: LyricSearching {
    var searches: [(SearchRequest, ProviderAccess)] = []
    var detailRequests: [String] = []
    private var pending: [String: CheckedContinuation<LyricMatch, any Error>] = [:]
    private var arrivals: [String: CheckedContinuation<Void, Never>] = [:]

    func search(_ request: SearchRequest, access: ProviderAccess) async throws -> SearchResponse {
        searches.append((request, access))
        return .init(matches: [Self.match("result")])
    }
    func lyrics(for match: LyricMatch, access: ProviderAccess) async throws -> String { "Original example line" }
    func details(for match: LyricMatch, access: ProviderAccess) async throws -> LyricMatch {
        detailRequests.append(match.providerID)
        return try await withCheckedThrowingContinuation { continuation in
            pending[match.providerID] = continuation
            arrivals.removeValue(forKey: match.providerID)?.resume()
        }
    }
    func waitForDetails(_ id: String) async {
        if pending[id] != nil { return }
        await withCheckedContinuation { arrivals[id] = $0 }
    }
    func complete(_ id: String) {
        var match = Self.match(id)
        match.metadata = [.init(id: "writer", label: "Songwriters", value: "Writer \(id)")]
        match.detailsComplete = true
        pending.removeValue(forKey: id)?.resume(returning: match)
    }
    func fail(_ id: String) {
        pending.removeValue(forKey: id)?.resume(throwing: LyricServiceError.unavailable(503))
    }
    static func match(_ id: String) -> LyricMatch {
        .init(
            provider: .lrcRed, providerID: id, title: "Example", artist: "An Artist", album: "An Album",
            detailsComplete: false)
    }
}

@MainActor struct InfoNavigationTests {
    private func preferences() -> (AppSettings, UserDefaults, String) {
        let name = "LyrxTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        let settings = AppSettings(defaults: defaults)
        settings.setEnabled(true, provider: .lrcRed)
        settings.lrcRedEmail = "reader@example.invalid"
        return (settings, defaults, name)
    }

    @Test(arguments: [RelatedSearch.artist, .album])
    func relatedLinksScopeRequestsAndKeepPreferences(field: RelatedSearch) async throws {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        let saved = settings.providerAccess
        let service = InfoService()
        let model = ReaderModel(service: service)
        await model.searchRelated(field, match: InfoService.match("link"), settings: settings)?.value
        let searches = await service.searches
        #expect(searches.count == 1)
        let (request, access) = try #require(searches.first)
        #expect(request.artist == "An Artist")
        #expect(request.album == (field == .album ? "An Album" : ""))
        #expect(request.query.isEmpty && request.title.isEmpty)
        #expect(access.searchable == [.lrcRed])
        #expect(settings.providerAccess == saved)
        #expect(model.searchScope == .lrcRed)
        #expect(model.showMatches)
        #expect(model.pendingMatchesFocusID != nil)
        #expect(model.pendingReaderFocusID == nil)
    }

    @Test func noConfiguredProviderSendsNoRequest() async {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        settings.setEnabled(false, provider: .lrclib)
        settings.lrcRedEmail = ""
        let service = InfoService()
        let model = ReaderModel(service: service)
        model.request.query = "example"
        await model.search(settings: settings)?.value
        #expect(await service.searches.isEmpty)
        #expect(!model.isSearching)
        #expect(model.status.contains("No configured service"))
        model.searchRelated(.artist, match: InfoService.match("link"), settings: settings)
        #expect(await service.searches.isEmpty)
    }

    @Test(arguments: [false, true])
    func staleInfoCannotReplaceNewerInfoAndReopeningUsesCache(oldRequestFails: Bool) async {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = InfoService()
        let model = ReaderModel(service: service)
        let oldInfo = model.info.open(InfoService.match("old"), access: settings.providerAccess)
        await service.waitForDetails("old")
        let newInfo = model.info.open(InfoService.match("new"), access: settings.providerAccess)
        await service.waitForDetails("new")
        await service.complete("new")
        await newInfo?.value
        if oldRequestFails { await service.fail("old") } else { await service.complete("old") }
        await oldInfo?.value
        #expect(model.info.match?.providerID == "new")
        #expect(model.info.match?.metadata.first?.value == "Writer new")
        #expect(!model.info.isLoading)
        #expect(model.info.error == nil)
        model.info.close()
        model.info.open(InfoService.match("new"), access: settings.providerAccess)
        #expect(!model.info.isLoading)
        #expect(model.info.match?.detailsComplete == true)
        #expect(await service.detailRequests == ["old", "new"])
    }

    @Test func detailsEnrichTheReaderWithoutCachingLyricText() async {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = InfoService()
        let model = ReaderModel(service: service)
        var original = InfoService.match("selected")
        original.lyrics = "Original private fixture text"
        await model.select(original, settings: settings)?.value
        let details = model.info.open(original, access: settings.providerAccess)
        #expect(model.info.match?.lyrics == nil)
        await service.waitForDetails("selected")
        await service.complete("selected")
        await details?.value
        #expect(model.selected?.metadata.first?.value == "Writer selected")
        #expect(model.selected?.lyrics == original.lyrics)
        #expect(model.info.match?.lyrics == nil)
        model.info.close()
        #expect(model.info.open(original, access: settings.providerAccess) == nil)
        #expect(model.info.match?.detailsComplete == true)
        #expect(model.info.match?.lyrics == nil)
    }

    @Test func newSearchClearsDetailsAndRejectsAnOutstandingResponse() async {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = InfoService()
        let model = ReaderModel(service: service)
        let cached = model.info.open(InfoService.match("cached"), access: settings.providerAccess)
        await service.waitForDetails("cached")
        await service.complete("cached")
        await cached?.value
        let old = model.info.open(InfoService.match("old"), access: settings.providerAccess)
        await service.waitForDetails("old")
        model.request.query = "Example"
        await model.search(settings: settings)?.value
        await service.complete("old")
        await old?.value
        #expect(!model.info.isPresented)
        #expect(model.info.match == nil)
        let reopened = model.info.open(InfoService.match("cached"), access: settings.providerAccess)
        await service.waitForDetails("cached")
        #expect(model.info.isLoading)
        #expect(await service.detailRequests == ["cached", "old", "cached"])
        await service.complete("cached")
        await reopened?.value
    }

    @Test func closingDetailsRejectsLateFailures() async {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = InfoService()
        let model = ReaderModel(service: service)
        let details = model.info.open(InfoService.match("closed"), access: settings.providerAccess)
        await service.waitForDetails("closed")
        model.info.close()
        await service.fail("closed")
        await details?.value
        #expect(!model.info.isPresented)
        #expect(!model.info.isLoading)
        #expect(model.info.error == nil)
    }

    @Test func removingEmailCancelsPendingInfo() async {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = InfoService()
        let model = ReaderModel(service: service)
        let oldInfo = model.info.open(InfoService.match("old"), access: settings.providerAccess)
        await service.waitForDetails("old")
        settings.lrcRedEmail = ""
        model.providersChanged(settings.providerAccess.searchable)
        await service.complete("old")
        await oldInfo?.value
        #expect(!model.info.isLoading)
        #expect(model.info.match?.metadata.isEmpty == true)
        model.info.open(InfoService.match("new"), access: settings.providerAccess)
        #expect(model.info.error != nil)
        #expect(await service.detailRequests == ["old"])
    }
}
