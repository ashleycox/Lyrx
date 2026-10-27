import SwiftUI

/// Shared by the macOS Settings window and the iOS settings sheet.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @FocusState private var widthFocused: Bool
    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                ForEach(LyricProviderID.allCases) { provider in
                    Toggle(
                        isOn: Binding(
                            get: { settings.enabledProviders.contains(provider) },
                            set: { settings.setEnabled($0, provider: provider) })
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(provider.name)
                            Text(provider.summary).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(settings.enabledProviders == [provider])
                    .accessibilityLabel(provider.name)
                    .keyboardShortcut(provider == .lrclib ? "1" : "2", modifiers: [.command, .shift])
                    .accessibilityHint(
                        provider.summary
                            + (settings.enabledProviders == [provider]
                                ? " Enable another service before turning this one off."
                                : " Changes which service receives future searches."))
                }
            } header: {
                Text("Lyric Services")
            } footer: {
                Text(
                    "At least one service must stay enabled. Searches are sent only when you press Search. lyrics.ovh may use other services internally."
                )
            }
            Section {
                Toggle(
                    "Unlimited line length",
                    isOn: Binding(get: { settings.lineWidth == 0 }, set: { settings.lineWidth = $0 ? 0 : 40 })
                )
                .keyboardShortcut("u", modifiers: [.command, .shift])
                if settings.lineWidth != 0 {
                    HStack {
                        Button("Characters per line") { widthFocused = true }
                            .buttonStyle(.plain).keyboardShortcut("l", modifiers: [.command, .shift])
                        TextField(
                            "Characters per line",
                            value: Binding(
                                get: { settings.lineWidth }, set: { settings.lineWidth = min(max($0, 1), 500) }),
                            format: .number.grouping(.never)
                        )
                        .focused($widthFocused).multilineTextAlignment(.trailing).accessibilityLabel(
                            "Characters per line"
                        )
                        #if os(iOS)
                            .keyboardType(.numberPad)
                        #endif
                    }
                }
                Picker("Split after", selection: $settings.punctuation) {
                    ForEach(PunctuationBreak.allCases) { Text($0.name).tag($0) }
                }.pickerStyle(.menu)
                Toggle("Preserve blank lines between stanzas", isOn: $settings.preserveBlankLines)
                    .keyboardShortcut("b", modifiers: [.command, .shift])
            } header: {
                Text("Line Formatting")
            } footer: {
                Text(
                    "The hard limit includes spaces and punctuation. Whole words move to the next line. If one word cannot fit, increase the limit or choose Unlimited. Punctuation splits occur at word boundaries. Braille translation may use a different number of cells."
                )
            }
            Section {
                Toggle("Show one line at a time", isOn: $settings.singleLine).keyboardShortcut(
                    "1", modifiers: [.command, .option])
                Toggle("Use a monospaced lyric font", isOn: $settings.monospaced).keyboardShortcut(
                    "m", modifiers: [.command, .shift])
                Picker("Lyric text size", selection: $settings.textScale) {
                    Text("100% — System size").tag(1.0)
                    Text("125%").tag(1.25)
                    Text("150%").tag(1.5)
                    Text("200%").tag(2.0)
                    Text("300%").tag(3.0)
                }
            } header: {
                Text("Reading")
            } footer: {
                #if os(macOS)
                    Text(
                        "Use the Lyrics menu to adjust text size and move between lines. One-line mode keeps only the current line in the text control. System Zoom is available in Accessibility settings."
                    )
                #else
                    Text(
                        "Text follows your preferred text size in Accessibility settings. One-line mode keeps only the current line in the text control; use the Previous Line and Next Line buttons or VoiceOver actions to move."
                    )
                #endif
            }
            Section("Privacy & Sources") {
                Text(
                    "Lyrx stores preferences on this device. It does not save search history or lyrics, and includes no analytics. Enabled services receive your search terms and IP address. Lyrics belong to their respective rights holders."
                )
                Link("LRCLIB API documentation", destination: URL(string: "https://lrclib.net/docs")!).keyboardShortcut(
                    "1", modifiers: [.command, .control])
                Link("lyrics.ovh API documentation", destination: URL(string: "https://github.com/NTag/lyrics.ovh")!)
                    .keyboardShortcut("2", modifiers: [.command, .control])
            }
        }.formStyle(.grouped).navigationTitle("Settings")
    }
}
