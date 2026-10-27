import Foundation
import Testing

@testable import LyrxCore

/// Captures scoped requests and controls detail completion without timers or network access.
private actor InfoService: LyricSearching {
    var searches: [(SearchRequest, ProviderAccess)] = []
    var detailRequests: [String] = []
    private var pending: [String: CheckedContinuation<LyricMatch, Never>] = [:]
    private var arrivals: [String: CheckedContinuation<Void, Never>] = [:]

    func search(_ request: SearchRequest, access: ProviderAccess) async throws -> SearchResponse {
        searches.append((request, access))
        return .init(matches: [Self.match("result")])
    }
    func lyrics(for match: LyricMatch, access: ProviderAccess) async throws -> String { "Original example line" }
    func details(for match: LyricMatch, access: ProviderAccess) async throws -> LyricMatch {
        detailRequests.append(match.providerID)
        return await withCheckedContinuation { continuation in
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
        model.searchRelated(field, match: InfoService.match("link"), settings: settings)
        await model.waitForCurrentOperation()
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
        model.search(settings: settings)
        await model.waitForCurrentOperation()
        #expect(await service.searches.isEmpty)
        #expect(!model.isSearching)
        #expect(model.status.contains("No configured service"))
        model.searchRelated(.artist, match: InfoService.match("link"), settings: settings)
        #expect(await service.searches.isEmpty)
    }

    @Test func staleInfoCannotReplaceNewerInfoAndReopeningUsesCache() async {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = InfoService()
        let model = ReaderModel(service: service)
        model.openInfo(for: InfoService.match("old"), settings: settings)
        await service.waitForDetails("old")
        model.openInfo(for: InfoService.match("new"), settings: settings)
        await service.waitForDetails("new")
        await service.complete("old")
        await service.complete("new")
        await model.waitForInfoOperation()
        #expect(model.infoMatch?.providerID == "new")
        #expect(model.infoMatch?.metadata.first?.value == "Writer new")
        #expect(!model.isLoadingInfo)
        model.closeInfo()
        model.openInfo(for: InfoService.match("new"), settings: settings)
        #expect(!model.isLoadingInfo)
        #expect(model.infoMatch?.detailsComplete == true)
        #expect(await service.detailRequests == ["old", "new"])
    }

    @Test func removingEmailCancelsPendingInfo() async {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = InfoService()
        let model = ReaderModel(service: service)
        model.openInfo(for: InfoService.match("old"), settings: settings)
        await service.waitForDetails("old")
        settings.lrcRedEmail = ""
        model.providersChanged(settings.providerAccess.searchable)
        await service.complete("old")
        await Task.yield()
        #expect(!model.isLoadingInfo)
        #expect(model.infoMatch?.metadata.isEmpty == true)
        model.openInfo(for: InfoService.match("new"), settings: settings)
        #expect(model.infoError != nil)
        #expect(await service.detailRequests == ["old"])
    }
}
