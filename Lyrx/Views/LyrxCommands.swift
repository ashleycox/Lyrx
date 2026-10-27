import SwiftUI

private struct ReaderFocusKey: FocusedValueKey { typealias Value = ReaderModel }
extension FocusedValues {
    var lyrxReader: ReaderModel? {
        get { self[ReaderFocusKey.self] }
        set { self[ReaderFocusKey.self] = newValue }
    }
}

/// Commands follow the focused window, including when several lyric windows are open.
struct LyrxCommands: Commands {
    @FocusedValue(\.lyrxReader) private var reader
    let settings: AppSettings
    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Divider()
            Button("Find Lyrics…") { reader?.searchFocusID = UUID() }.keyboardShortcut("f").disabled(reader == nil)
            Button("Search") { reader?.search(settings: settings) }.keyboardShortcut(.return, modifiers: .command)
                .disabled(reader?.canSearch != true)
            Button("Cancel Search") { reader?.cancel() }.keyboardShortcut(".").disabled(reader?.isSearching != true)
        }
        CommandMenu("Lyrics") {
            Button("Focus Lyrics") { reader?.focusReader() }.keyboardShortcut("l").disabled(reader?.hasLyrics != true)
            Button("Previous Line") { if let reader { reader.go(to: reader.currentLine - 1) } }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option]).disabled(reader?.canGoBack != true)
            Button("Next Line") { if let reader { reader.go(to: reader.currentLine + 1) } }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option]).disabled(reader?.canGoForward != true)
            Button("First Line") { reader?.go(to: 0) }
                .keyboardShortcut(.home, modifiers: [.command, .option]).disabled(reader?.hasLyrics != true)
            Button("Last Line") { if let reader { reader.go(to: reader.document.lines.count - 1) } }
                .keyboardShortcut(.end, modifiers: [.command, .option]).disabled(reader?.hasLyrics != true)
            Divider()
            Toggle(
                "Show Line Controls and Highlighting",
                isOn: Binding(get: { settings.showLineControls }, set: { settings.showLineControls = $0 })
            ).keyboardShortcut("n", modifiers: [.command, .shift])
            Toggle(
                "Show One Line at a Time",
                isOn: Binding(get: { settings.singleLine }, set: { settings.singleLine = $0 })
            ).keyboardShortcut("1", modifiers: [.command, .option])
            Toggle(
                "Unlimited Line Length",
                isOn: Binding(get: { settings.lineWidth == 0 }, set: { settings.lineWidth = $0 ? 0 : 40 })
            ).keyboardShortcut("u", modifiers: [.command, .shift])
            Menu("Split After") {
                ForEach(Array(PunctuationBreak.allCases.enumerated()), id: \.element.id) { index, mode in
                    Button(mode.name) { settings.punctuation = mode }
                        .keyboardShortcut(
                            KeyEquivalent(Character(String(index + 1))), modifiers: [.command, .control, .shift])
                }
            }
            Menu("Lyric Text Size") {
                Button("Increase") { settings.textScale = min(3, settings.textScale + 0.25) }.keyboardShortcut("+")
                Button("Decrease") { settings.textScale = max(1, settings.textScale - 0.25) }.keyboardShortcut("-")
                Button("System Size") { settings.textScale = 1 }.keyboardShortcut("0")
            }
        }
        CommandMenu("Search Results") {
            Button("Show or Hide Filters") { reader?.showFilters.toggle() }.keyboardShortcut(
                "f", modifiers: [.command, .option])
            #if os(macOS)
                Button("Focus Other Matches") { reader?.focusMatches() }
                    .keyboardShortcut("m", modifiers: [.command, .option])
                    .disabled(reader?.matches.isEmpty != false)
            #else
                Button("Show or Hide Other Matches") { reader?.toggleMatches() }
                    .keyboardShortcut("m", modifiers: [.command, .option])
                    .disabled(reader?.matches.isEmpty != false)
            #endif
            Button("Previous Match") { selectRelative(-1) }.keyboardShortcut("[", modifiers: [.command, .option])
                .disabled(reader?.matches.isEmpty != false)
            Button("Next Match") { selectRelative(1) }.keyboardShortcut("]", modifiers: [.command, .option]).disabled(
                reader?.matches.isEmpty != false)
        }
        CommandGroup(replacing: .help) {
            Button("Lyrx Reading Help") { reader?.showHelp = true }.keyboardShortcut("?")
        }
    }
    private func selectRelative(_ offset: Int) {
        guard let reader, !reader.matches.isEmpty else { return }
        let current = reader.matches.firstIndex { $0.id == reader.selected?.id } ?? (offset > 0 ? -1 : 1)
        let next = min(max(0, current + offset), reader.matches.count - 1)
        reader.select(reader.matches[next], settings: settings)
    }
}
