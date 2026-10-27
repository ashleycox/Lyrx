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
    private let service: any LyricSearching
    private var operation: Task<Void, Never>?
    private var generation = UUID()
    private var shouldFocusSearchResult = true

    init(service: any LyricSearching = ProviderClient()) { self.service = service }

    isolated deinit { operation?.cancel() }

    var canSearch: Bool { !request.cleaned.isEmpty }
    var hasLyrics: Bool { !document.lines.isEmpty }
    var lineStatus: String { hasLyrics ? "Line \(currentLine + 1) of \(document.lines.count)" : "No lyric lines" }
    var canGoBack: Bool { hasLyrics && currentLine > 0 }
    var canGoForward: Bool { hasLyrics && currentLine + 1 < document.lines.count }

    func search(settings: AppSettings) {
        guard canSearch else { return }
        cancel()
        shouldFocusSearchResult = true
        let token = generation
        let snapshot = request.cleaned
        let providers = settings.enabledProviders
        isSearching = true
        status = "Searching enabled providers…"
        matches = []
        notices = []
        selected = nil
        rawLyrics = ""
        document = FormattedLyrics(lines: [])
        formattingError = nil
        // A user action owns this task. It is cancelled on replacement, window closure, and deinit.
        operation = Task { [weak self, service] in
            do {
                let response = try await service.search(snapshot, enabled: providers)
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
                // Bound automatic lookups; remaining candidates are available in Other Matches.
                var lastError: (any Error)?
                let vocalMatches = response.matches.filter { !$0.instrumental }
                let candidates = vocalMatches.isEmpty ? response.matches : vocalMatches
                for match in candidates.prefix(5) {
                    guard self.isCurrent(token) else { return }
                    self.status = "Loading the best available match…"
                    do {
                        let lyrics = try await service.lyrics(for: match)
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
        guard settings.enabledProviders.contains(match.provider) else { return }
        cancel()
        let token = generation
        isSearching = true
        status = "Loading \(match.title)…"
        operation = Task { [weak self, service] in
            do {
                let lyrics = try await service.lyrics(for: match)
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
        matches.removeAll { !enabled.contains($0.provider) }
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

    /// The menu shortcut enters results directly; clicking the disclosure keeps focus on its button.
    func toggleMatches(focusResults: Bool = false) {
        guard !matches.isEmpty else { return }
        showMatches.toggle()
        // A slow lyric request must not interrupt someone who has started exploring results.
        if showMatches { shouldFocusSearchResult = false }
        pendingMatchesFocusID = nil
        if focusResults {
            if showMatches {
                pendingReaderFocusID = nil
                pendingMatchesFocusID = UUID()
            } else {
                focusReader()
            }
        }
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
