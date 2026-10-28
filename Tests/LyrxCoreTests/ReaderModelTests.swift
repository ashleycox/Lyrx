import Foundation
import Testing

@testable import LyrxCore

private struct ImmediateService: LyricSearching {
    let matches: [LyricMatch]
    func search(_ request: SearchRequest, access: ProviderAccess) async throws -> SearchResponse {
        .init(matches: matches)
    }
    func lyrics(for match: LyricMatch, access: ProviderAccess) async throws -> String {
        if match.instrumental { return "" }
        guard let lyrics = match.lyrics else { throw LyricServiceError.noLyrics }
        return lyrics
    }
}

/// Deliberately ignores cancellation so the tests exercise the generation guard, not URLSession.
private actor SuspendedService: LyricSearching {
    private let delaysLyrics: Bool
    private var pending: [String: CheckedContinuation<SearchResponse, any Error>] = [:]
    private var arrivals: [String: CheckedContinuation<Void, Never>] = [:]
    private var pendingLyrics: CheckedContinuation<String, Never>?
    private var lyricsArrival: CheckedContinuation<Void, Never>?
    init(delaysLyrics: Bool = false) { self.delaysLyrics = delaysLyrics }
    func search(_ request: SearchRequest, access: ProviderAccess) async throws -> SearchResponse {
        try await withCheckedThrowingContinuation { continuation in
            pending[request.query] = continuation
            arrivals.removeValue(forKey: request.query)?.resume()
        }
    }
    func waitForRequest(_ name: String) async {
        if pending[name] != nil { return }
        await withCheckedContinuation { arrivals[name] = $0 }
    }
    func complete(_ name: String) {
        pending.removeValue(forKey: name)?.resume(
            returning: .init(matches: [
                LyricMatch(
                    provider: .lrclib, providerID: name, title: name, artist: "Test", lyrics: "First line\nSecond line")
            ]))
    }
    func fail(_ name: String) {
        pending.removeValue(forKey: name)?.resume(throwing: LyricServiceError.unavailable(503))
    }
    func lyrics(for match: LyricMatch, access: ProviderAccess) async throws -> String {
        guard delaysLyrics else { return match.lyrics ?? "" }
        return await withCheckedContinuation { continuation in
            pendingLyrics = continuation
            lyricsArrival?.resume()
            lyricsArrival = nil
        }
    }
    func waitForLyrics() async {
        if pendingLyrics != nil { return }
        await withCheckedContinuation { lyricsArrival = $0 }
    }
    func completeLyrics() {
        pendingLyrics?.resume(returning: "First line\nSecond line")
        pendingLyrics = nil
    }
}

@MainActor struct ReaderModelTests {
    private func preferences() -> (AppSettings, UserDefaults, String) {
        let name = "LyrxTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        return (AppSettings(defaults: defaults), defaults, name)
    }
    @Test func automaticSelectionSkipsInstrumentalsAndMissingLyrics() async {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        let matches = [
            LyricMatch(provider: .lrclib, providerID: "1", title: "Instrumental", artist: "Test", instrumental: true),
            LyricMatch(provider: .lrclib, providerID: "2", title: "Missing", artist: "Test"),
            LyricMatch(
                provider: .lrclib, providerID: "3", title: "Vocal", artist: "Test", lyrics: "First line\n\nLast line"),
        ]
        let model = ReaderModel(service: ImmediateService(matches: matches))
        let oldFocus = model.readerFocusID
        model.request.query = "Test"
        await model.search(settings: settings)?.value
        #expect(model.selected?.title == "Vocal")
        #expect(model.document.lines == ["First line", "", "Last line"])
        #expect(model.readerFocusID != oldFocus)
        model.go(to: 200)
        #expect(model.currentLine == 2)
        model.go(to: -5)
        #expect(model.currentLine == 0)
        model.caretMoved(toUTF16Offset: 12)
        #expect(model.currentLine == 2)
    }
    @Test func oversizedWordCanRecoverWithoutNetwork() async {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        settings.lineWidth = 4
        let model = ReaderModel(
            service: ImmediateService(matches: [
                .init(provider: .lrclib, providerID: "1", title: "Example", artist: "Test", lyrics: "Wonderful day")
            ]))
        model.request.query = "Example"
        await model.search(settings: settings)?.value
        #expect(model.formattingError != nil)
        #expect(!model.hasLyrics)
        model.reformat(.init(lineLimit: nil))
        #expect(model.document.lines == ["Wonderful day"])
        #expect(model.formattingError == nil)
    }
    @Test func browsingMatchesDoesNotRequestReaderFocus() async throws {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        let matches = [
            LyricMatch(provider: .lrclib, providerID: "1", title: "First", artist: "Test", lyrics: "First line"),
            LyricMatch(provider: .lrclib, providerID: "2", title: "Second", artist: "Test", lyrics: "Second line"),
        ]
        let model = ReaderModel(service: ImmediateService(matches: matches))
        model.request.query = "Test"
        await model.search(settings: settings)?.value
        let searchFocus = try #require(model.pendingReaderFocusID)
        #expect(model.consumeReaderFocus(searchFocus))
        // A remounted reader must not be able to repeat the old accessibility focus notification.
        #expect(!model.consumeReaderFocus(searchFocus))

        await model.select(matches[1], settings: settings, focusOnLoad: false)?.value
        #expect(model.document.text == "Second line")
        #expect(model.readerFocusID == searchFocus)
        #expect(model.pendingReaderFocusID == nil)

        model.focusMatches()
        let tableFocus = try #require(model.pendingMatchesFocusID)
        #expect(!model.showMatches)  // The iOS disclosure state is independent of Mac focus.
        #expect(model.consumeMatchesFocus(tableFocus))
        #expect(!model.consumeMatchesFocus(tableFocus))
        model.focusReader()
        let explicitFocus = try #require(model.pendingReaderFocusID)
        #expect(explicitFocus != searchFocus)
        let selection = model.select(matches[0], settings: settings, focusOnLoad: false)
        #expect(!model.consumeReaderFocus(explicitFocus))
        await selection?.value
        #expect(model.pendingReaderFocusID == nil)
        model.focusMatches()
        #expect(!model.showMatches)
        #expect(model.pendingReaderFocusID == nil)
        #expect(model.pendingMatchesFocusID != nil)
        #expect(model.pendingMatchesFocusID != tableFocus)
        model.toggleMatches()
        #expect(model.showMatches)
        model.toggleMatches()
        #expect(!model.showMatches)
    }
    @Test(arguments: [false, true])
    func lateSearchCannotOverwriteNewerSearch(oldRequestFails: Bool) async {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = SuspendedService()
        let model = ReaderModel(service: service)
        model.request.query = "Old"
        let oldSearch = model.search(settings: settings)
        await service.waitForRequest("Old")
        model.request.query = "New"
        let newSearch = model.search(settings: settings)
        await service.waitForRequest("New")
        await service.complete("New")
        await newSearch?.value
        #expect(model.selected?.title == "New")
        if oldRequestFails { await service.fail("Old") } else { await service.complete("Old") }
        // Await the replaced operation itself, including its stale-response guard.
        await oldSearch?.value
        #expect(model.selected?.title == "New")
        #expect(!model.isSearching)
        #expect(model.status == "Loaded New by Test.")
    }
    @Test(arguments: [true, false]) func enteringMatchesDuringLoadingPreservesFocus(usingShortcut: Bool) async throws {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = SuspendedService(delaysLyrics: true)
        let model = ReaderModel(service: service)
        let oldFocus = model.readerFocusID
        model.request.query = "Example"
        let search = model.search(settings: settings)
        await service.waitForRequest("Example")
        await service.complete("Example")
        await service.waitForLyrics()
        if usingShortcut {
            model.focusMatches()
            let tableFocus = try #require(model.pendingMatchesFocusID)
            #expect(model.consumeMatchesFocus(tableFocus))
        } else {
            model.beginBrowsingMatches()
        }
        await service.completeLyrics()
        await search?.value
        #expect(model.hasLyrics)
        #expect(model.readerFocusID == oldFocus)
        #expect(model.pendingReaderFocusID == nil)
    }
    @Test func providerChangeCancelsPendingSearch() async {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = SuspendedService()
        let model = ReaderModel(service: service)
        model.request.query = "Old"
        let oldSearch = model.search(settings: settings)
        await service.waitForRequest("Old")
        model.providersChanged([.lyricsOVH])
        await service.complete("Old")
        await oldSearch?.value
        #expect(model.selected == nil)
        #expect(model.matches.isEmpty)
        #expect(!model.isSearching)
    }
    @Test func closingReaderDuringAutomaticLoadingReleasesItsState() async {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = SuspendedService(delaysLyrics: true)
        var model: ReaderModel? = ReaderModel(service: service)
        weak var released = model
        model?.request.query = "Closing"
        let operation = model?.search(settings: settings)
        await service.waitForRequest("Closing")
        await service.complete("Closing")
        await service.waitForLyrics()
        model = nil
        #expect(released == nil)
        #expect(operation?.isCancelled == true)
        await service.completeLyrics()
        await operation?.value
    }

}
