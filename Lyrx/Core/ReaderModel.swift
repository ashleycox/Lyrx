import Foundation
import Observation

/// Per-window state. Request generations prevent late responses from replacing a newer selection.
@MainActor @Observable
final class ReaderModel {
    var request = SearchRequest()
    private(set) var matches: [LyricMatch] = []
    private(set) var selected: LyricMatch?
    private(set) var rawLyrics = ""
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
    var showAdditionalInfo = false
    private(set) var infoMatch: LyricMatch?
    private(set) var isLoadingInfo = false
    private(set) var infoError: String?
    private var infoOperation: Task<Void, Never>?
    private var infoGeneration = UUID()
    private var infoCache: [LyricMatch.ID: LyricMatch] = [:]
    private let service: any LyricSearching
    private var operation: Task<Void, Never>?
    private var generation = UUID()
    private var shouldFocusSearchResult = true

    init(service: any LyricSearching = ProviderClient()) { self.service = service }

    isolated deinit {
        operation?.cancel()
        infoOperation?.cancel()
    }

    var canSearch: Bool { !request.cleaned.isEmpty }
    var hasLyrics: Bool { !document.lines.isEmpty }
    var lineStatus: String { hasLyrics ? "Line \(currentLine + 1) of \(document.lines.count)" : "No lyric lines" }
    var canGoBack: Bool { hasLyrics && currentLine > 0 }
    var canGoForward: Bool { hasLyrics && currentLine + 1 < document.lines.count }

    func search(settings: AppSettings, focusResults: Bool = false) {
        guard canSearch else { return }
        cancel()
        closeInfo()
        infoCache.removeAll()
        shouldFocusSearchResult = !focusResults
        let token = generation
        let snapshot = request.cleaned
        let access = settings.providerAccess.restricted(to: searchScope)
        isSearching = true
        status = "Searching enabled providers…"
        matches = []
        notices = []
        selected = nil
        rawLyrics = ""
        document = FormattedLyrics(lines: [])
        formattingError = nil
        guard !access.searchable.isEmpty else {
            isSearching = false
            status =
                "No configured service is available for this search. Enable a service or enter a valid contact email for lrc.red in Settings."
            return
        }
        // A user action owns this task. It is cancelled on replacement, window closure, and deinit.
        operation = Task { [weak self, service] in
            do {
                let response = try await service.search(snapshot, access: access)
                guard let self, self.isCurrent(token) else { return }
                self.matches = response.matches
                self.notices = response.notices
                guard !response.matches.isEmpty else {
                    self.status =
                        response.notices.isEmpty
                        ? "No matches. Try a shorter search or change the filters."
                        : "No matches were returned. Check the service messages below."
                    self.isSearching = false
                    return
                }
                if focusResults {
                    self.showMatches = true
                    self.focusMatches()
                }
                // Bound automatic lookups; remaining candidates are available in Other Matches.
                var lastError: (any Error)?
                let vocalMatches = response.matches.filter { !$0.instrumental }
                let candidates = vocalMatches.isEmpty ? response.matches : vocalMatches
                for match in candidates.prefix(5) {
                    guard self.isCurrent(token) else { return }
                    self.status = "Loading the best available match…"
                    do {
                        let lyrics = try await service.lyrics(for: match, access: access)
                        guard self.isCurrent(token) else { return }
                        self.install(
                            match, lyrics: lyrics, options: settings.formatting,
                            focusOnLoad: self.shouldFocusSearchResult)
                        self.isSearching = false
                        return
                    } catch {
                        guard self.isCurrent(token) else { return }
                        lastError = error
                    }
                }
                self.status = lastError.map(ProviderClient.message) ?? "No lyrics are available for these matches."
                self.showMatches = true
                self.isSearching = false
            } catch {
                guard let self, self.isCurrent(token) else { return }
                self.status = ProviderClient.message(for: error)
                self.isSearching = false
            }
        }
    }

    /// Table selection can update the lyric without interrupting keyboard or VoiceOver browsing.
    func select(_ match: LyricMatch, settings: AppSettings, focusOnLoad: Bool = true) {
        let access = settings.providerAccess
        guard access.searchable.contains(match.provider) else { return }
        cancel()
        let token = generation
        isSearching = true
        status = "Loading \(match.title)…"
        operation = Task { [weak self, service] in
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

    /// Allows deterministic callers (including tests) to await the operation they just started.
    func waitForCurrentOperation() async { await operation?.value }

    func providersChanged(_ enabled: Set<LyricProviderID>) {
        cancel()
        cancelInfo()
        matches.removeAll { !enabled.contains($0.provider) }
        if let match = infoMatch, !match.detailsComplete, !enabled.contains(match.provider) {
            infoError = LyricServiceError.providerNotConfigured.localizedDescription
        }
    }

    /// Related links scope this search only; they never change saved provider preferences.
    func searchRelated(_ field: RelatedSearch, match: LyricMatch, settings: AppSettings) {
        guard settings.providerAccess.searchable.contains(match.provider),
            !match.artist.isEmpty, field != .album || !match.album.isEmpty
        else { return }
        closeInfo()
        searchScope = match.provider
        request = SearchRequest(artist: match.artist, album: field == .album ? match.album : "")
        showFilters = true
        search(settings: settings, focusResults: true)
    }

    func openInfo(for match: LyricMatch, settings: AppSettings) {
        cancelInfo()
        let match = infoCache[match.id] ?? match
        infoMatch = match
        showAdditionalInfo = true
        infoError = nil
        guard !match.detailsComplete else { return }
        let access = settings.providerAccess
        guard access.searchable.contains(match.provider) else {
            infoError = LyricServiceError.providerNotConfigured.localizedDescription
            return
        }
        isLoadingInfo = true
        let token = infoGeneration
        infoOperation = Task { [weak self, service] in
            do {
                let enriched = try await service.details(for: match, access: access)
                guard let self, self.infoGeneration == token, !Task.isCancelled else { return }
                self.infoMatch = enriched
                // Reuse fetched metadata in this window without retaining it on disk.
                if self.selected?.id == enriched.id {
                    self.selected?.metadata = enriched.metadata
                    self.selected?.detailsComplete = true
                }
                var cached = enriched
                cached.lyrics = nil
                self.infoCache[enriched.id] = cached
                self.isLoadingInfo = false
            } catch {
                guard let self, self.infoGeneration == token, !Task.isCancelled else { return }
                self.infoError = ProviderClient.message(for: error)
                self.isLoadingInfo = false
            }
        }
    }

    func cancelInfo() {
        infoOperation?.cancel()
        infoOperation = nil
        infoGeneration = UUID()
        isLoadingInfo = false
    }

    func closeInfo() {
        cancelInfo()
        showAdditionalInfo = false
    }
    func waitForInfoOperation() async { await infoOperation?.value }

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
        selected = match
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
