import Foundation
import Testing

@testable import LyrxCore

private struct ImmediateService: LyricSearching {
    let matches: [LyricMatch]
    func search(_ request: SearchRequest, enabled: Set<LyricProviderID>) async throws -> SearchResponse {
        .init(matches: matches)
    }
    func lyrics(for match: LyricMatch) async throws -> String {
        if match.instrumental { return "" }
        guard let lyrics = match.lyrics else { throw LyricServiceError.noLyrics }
        return lyrics
    }
}

/// Deliberately ignores cancellation so the tests exercise the generation guard, not URLSession.
private actor SuspendedService: LyricSearching {
    private var pending: [String: CheckedContinuation<SearchResponse, Never>] = [:]
    private var arrivals: [String: CheckedContinuation<Void, Never>] = [:]
    func search(_ request: SearchRequest, enabled: Set<LyricProviderID>) async throws -> SearchResponse {
        await withCheckedContinuation { continuation in
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
    func lyrics(for match: LyricMatch) async throws -> String { match.lyrics ?? "" }
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
        model.search(settings: settings)
        await model.waitForCurrentOperation()
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
        model.search(settings: settings)
        await model.waitForCurrentOperation()
        #expect(model.formattingError != nil)
        #expect(!model.hasLyrics)
        model.reformat(.init(lineLimit: nil))
        #expect(model.document.lines == ["Wonderful day"])
        #expect(model.formattingError == nil)
    }
    @Test func lateSearchCannotOverwriteNewerSearch() async {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = SuspendedService()
        let model = ReaderModel(service: service)
        model.request.query = "Old"
        model.search(settings: settings)
        await service.waitForRequest("Old")
        model.request.query = "New"
        model.search(settings: settings)
        await service.waitForRequest("New")
        await service.complete("New")
        await model.waitForCurrentOperation()
        #expect(model.selected?.title == "New")
        await service.complete("Old")
        // Actor queue hop allows the stale response to return before the assertion.
        await Task.yield()
        #expect(model.selected?.title == "New")
        #expect(!model.isSearching)
    }
    @Test func providerChangeCancelsPendingSearch() async {
        let (settings, defaults, name) = preferences()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = SuspendedService()
        let model = ReaderModel(service: service)
        model.request.query = "Old"
        model.search(settings: settings)
        await service.waitForRequest("Old")
        model.providersChanged([.lyricsOVH])
        await service.complete("Old")
        await Task.yield()
        #expect(model.selected == nil)
        #expect(model.matches.isEmpty)
        #expect(!model.isSearching)
    }
}
