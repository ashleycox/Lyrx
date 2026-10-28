import Foundation
import Observation

/// Per-window state. Request generations prevent late responses from replacing a newer selection.
@MainActor @Observable
final class ReaderModel {
    var request = SearchRequest()
    private(set) var matches: [LyricMatch] = []
    private var loadedMatch: LyricMatch?
    private var rawLyrics = ""
    private(set) var document = FormattedLyrics(lines: [])
    private(set) var currentLine = 0
    private(set) var isSearching = false
    private(set) var status = "Search by song title, artist, or both."
    private(set) var notices: [ProviderNotice] = []
    private(set) var formattingError: String?
    private(set) var readerFocusID = UUID()
    private(set) var pendingReaderFocusID: UUID?
    private(set) var pendingMatchesFocusID: UUID?
    private(set) var selectionID = UUID()
    var searchFocusID = UUID()
    var showFilters = false
    var showMatches = false
    var showHelp = false
    var searchScope: LyricProviderID?
    let info: RecordingInfoModel
    @ObservationIgnored private let service: any LyricSearching
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var shouldFocusSearchResult = true

    init(service: any LyricSearching = ProviderClient()) {
        self.service = service
        info = RecordingInfoModel(service: service)
    }

    isolated deinit { operation?.cancel() }

    var selected: LyricMatch? { loadedMatch.map(info.enriched) }
    var canSearch: Bool { !request.cleaned.isEmpty }
    var hasLyrics: Bool { !document.lines.isEmpty }
    var lineStatus: String { hasLyrics ? "Line \(currentLine + 1) of \(document.lines.count)" : "No lyric lines" }
    var canGoBack: Bool { hasLyrics && currentLine > 0 }
    var canGoForward: Bool { hasLyrics && currentLine + 1 < document.lines.count }

    /// The model owns cancellation; callers may await the returned task across replacement.
    @discardableResult
    func search(settings: AppSettings, focusResults: Bool = false) -> Task<Void, Never>? {
        guard canSearch else { return nil }
        cancel()
        info.reset()
        shouldFocusSearchResult = !focusResults
        let token = generation
        let snapshot = request.cleaned
        let access = settings.providerAccess.restricted(to: searchScope)
        isSearching = true
        status = "Searching enabled providers…"
        matches = []
        notices = []
        loadedMatch = nil
        rawLyrics = ""
        document = FormattedLyrics(lines: [])
        currentLine = 0
        formattingError = nil
        guard !access.searchable.isEmpty else {
            isSearching = false
            status =
                "No configured service is available for this search. Enable a service or enter a valid contact email for lrc.red in Settings."
            return nil
        }
        // A user action owns this task. It is cancelled on replacement, window closure, and deinit.
        let task = Task { [weak self, service] in
            do {
                let response = try await service.search(snapshot, access: access)
                guard self?.isCurrent(token) == true else { return }
                self?.matches = response.matches
                self?.notices = response.notices
                guard !response.matches.isEmpty else {
                    self?.status =
                        response.notices.isEmpty
                        ? "No matches. Try a shorter search or change the filters."
                        : "No matches were returned. Check the service messages below."
                    self?.isSearching = false
                    return
                }
                if focusResults {
                    self?.showMatches = true
                    self?.focusMatches()
                }
                // Bound automatic lookups; remaining candidates are available in Other Matches.
                var lastError: (any Error)?
                let vocalMatches = response.matches.filter { !$0.instrumental }
                let candidates = vocalMatches.isEmpty ? response.matches : vocalMatches
                for match in candidates.prefix(5) {
                    guard self?.isCurrent(token) == true else { return }
                    self?.status = "Loading the best available match…"
                    do {
                        let lyrics = try await service.lyrics(for: match, access: access)
                        guard let self, self.isCurrent(token) else { return }
                        self.install(
                            match, lyrics: lyrics, options: settings.formatting,
                            focusOnLoad: self.shouldFocusSearchResult)
                        self.isSearching = false
                        return
                    } catch {
                        guard self?.isCurrent(token) == true else { return }
                        lastError = error
                    }
                }
                guard let self, self.isCurrent(token) else { return }
                self.status = lastError.map(ProviderClient.message) ?? "No lyrics are available for these matches."
                self.showMatches = true
                self.isSearching = false
            } catch {
                guard let self, self.isCurrent(token) else { return }
                self.status = ProviderClient.message(for: error)
                self.isSearching = false
            }
        }
        operation = task
        return task
    }

    /// Table selection can update the lyric without interrupting keyboard or VoiceOver browsing.
    @discardableResult
    func select(_ match: LyricMatch, settings: AppSettings, focusOnLoad: Bool = true) -> Task<Void, Never>? {
        let access = settings.providerAccess
        guard access.searchable.contains(match.provider) else { return nil }
        cancel()
        let token = generation
        isSearching = true
        status = "Loading \(match.title)…"
        let task = Task { [weak self, service] in
            do {
                let lyrics = try await service.lyrics(for: match, access: access)
                guard let self, self.isCurrent(token) else { return }
                self.install(match, lyrics: lyrics, options: settings.formatting, focusOnLoad: focusOnLoad)
                self.isSearching = false
            } catch {
                guard let self, self.isCurrent(token) else { return }
                self.status = ProviderClient.message(for: error)
                self.isSearching = false
            }
        }
        operation = task
        return task
    }

    func cancel() {
        operation?.cancel()
        operation = nil
        generation = UUID()
        pendingReaderFocusID = nil
        pendingMatchesFocusID = nil
        if isSearching { status = "Search cancelled." }
        isSearching = false
    }

    func providersChanged(_ enabled: Set<LyricProviderID>) {
        cancel()
        info.providersChanged(enabled)
        matches.removeAll { !enabled.contains($0.provider) }
    }

    /// Related links scope this search only; they never change saved provider preferences.
    @discardableResult
    func searchRelated(_ field: RelatedSearch, match: LyricMatch, settings: AppSettings) -> Task<Void, Never>? {
        guard settings.providerAccess.searchable.contains(match.provider),
            !match.artist.isEmpty, field != .album || !match.album.isEmpty
        else { return nil }
        searchScope = match.provider
        request = SearchRequest(artist: match.artist, album: field == .album ? match.album : "")
        showFilters = true
        return search(settings: settings, focusResults: true)
    }

    func reformat(_ options: FormattingOptions) {
        guard !rawLyrics.isEmpty else { return }
        do {
            document = try LyricFormatter.format(rawLyrics, options: options)
            currentLine = min(currentLine, max(0, document.lines.count - 1))
            formattingError = nil
            selectionID = UUID()
        } catch {
            document = FormattedLyrics(lines: [])
            currentLine = 0
            formattingError = error.localizedDescription
        }
    }

    func go(to line: Int) {
        guard hasLyrics else { return }
        currentLine = min(max(line, 0), document.lines.count - 1)
        selectionID = UUID()
        focusReader()
    }

    /// Native caret movement updates status without issuing another selection request.
    func caretMoved(toUTF16Offset offset: Int) {
        currentLine = document.line(atUTF16Offset: offset)
    }

    func focusReader() {
        guard hasLyrics else { return }
        pendingMatchesFocusID = nil
        readerFocusID = UUID()
        pendingReaderFocusID = readerFocusID
    }

    /// A request is consumed once, so recreating a native text view cannot replay old focus changes.
    func consumeReaderFocus(_ requestID: UUID) -> Bool {
        guard pendingReaderFocusID == requestID else { return false }
        pendingReaderFocusID = nil
        return true
    }

    /// iOS keeps its disclosure; Mac results are always visible when matches are available.
    func toggleMatches() {
        guard !matches.isEmpty else { return }
        showMatches.toggle()
        if showMatches { beginBrowsingMatches() }
    }

    /// Entering the persistent Mac table never hides it or toggles focus back into the reader.
    func focusMatches() {
        guard !matches.isEmpty else { return }
        beginBrowsingMatches()
        pendingMatchesFocusID = UUID()
    }

    /// Mouse, keyboard, and accessibility entry all take priority over a slow automatic lyric load.
    func beginBrowsingMatches() {
        shouldFocusSearchResult = false
        pendingReaderFocusID = nil
    }

    func consumeMatchesFocus(_ requestID: UUID) -> Bool {
        guard pendingMatchesFocusID == requestID else { return false }
        pendingMatchesFocusID = nil
        return true
    }

    private func isCurrent(_ token: UUID) -> Bool { generation == token && !Task.isCancelled }

    private func install(
        _ match: LyricMatch, lyrics: String, options: FormattingOptions, focusOnLoad: Bool = true
    ) {
        loadedMatch = match
        rawLyrics = lyrics
        currentLine = 0
        formattingError = nil
        document = FormattedLyrics(lines: [])
        reformat(options)
        status =
            match.instrumental
            ? "This recording is marked instrumental; there are no lyric lines."
            : "Loaded \(match.title) by \(match.artist)."
        selectionID = UUID()
        if focusOnLoad { focusReader() }
    }
}
