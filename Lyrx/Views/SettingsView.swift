import SwiftUI

/// Shared by the macOS Settings window and the iOS settings sheet.
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @FocusState private var widthFocused: Bool
    @FocusState private var emailFocused: Bool
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
                    .disabled(settings.enabledProviders.contains(provider) && !settings.canDisable(provider))
                    .accessibilityLabel(provider.name)
                    .keyboardShortcut(
                        provider == .lrcRed ? "r" : KeyEquivalent(provider.shortcut), modifiers: [.command, .shift]
                    )
                    .accessibilityHint(
                        provider.summary
                            + (settings.enabledProviders.contains(provider) && !settings.canDisable(provider)
                                ? " Configure and enable another service before turning this one off."
                                : " Changes which service receives future searches."))
                    if provider == .lrcRed, settings.enabledProviders.contains(.lrcRed) {
                        HStack {
                            Button("Contact email") { emailFocused = true }
                                .buttonStyle(.plain).keyboardShortcut("e", modifiers: [.command, .shift])
                            TextField("Contact email for lrc.red", text: $settings.lrcRedEmail)
                                .focused($emailFocused).autocorrectionDisabled()
                                .accessibilityIdentifier("lrcRedEmail")
                                #if os(iOS)
                                    .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                                #endif
                        }
                        Text(
                            "Stored on this device and sent to lrc.red with each request to identify this app's use. It is not sent to the other providers."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                        if settings.providerAccess.contactEmail == nil {
                            Text("lrc.red is skipped until you enter a valid contact email.")
                                .font(.caption).accessibilityIdentifier("lrcRedUnavailable")
                        }
                    }
                }
            } header: {
                Text("Lyric Services")
            } footer: {
                Text(
                    "At least one service must stay enabled. Lyric searches and metadata requests contact only configured services you have enabled. lyrics.ovh may use other services internally."
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
                Toggle("Show line controls and highlighting", isOn: $settings.showLineControls)
                    .accessibilityHint(
                        "Shows line navigation buttons, a position count, and a highlight for the current line."
                    )
                    #if os(macOS)
                        .help("Show line controls and highlighting (Command–Shift–N)")
                    #endif
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
                        "Line controls and highlighting are optional visual reading aids. Use VoiceOver's text navigation and braille panning to read normally. One-line mode keeps only the current line; the Lyrics menu also provides line commands."
                    )
                #else
                    Text(
                        "Text follows your preferred text size in Accessibility settings. Line controls and highlighting are optional visual reading aids. In one-line mode, enable the controls to move by touch, or use the reader's VoiceOver actions."
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
                Link("lrc.red API documentation", destination: URL(string: "https://lrc.red/api")!)
                    .keyboardShortcut("3", modifiers: [.command, .control])
            }
        }.formStyle(.grouped).navigationTitle("Settings")
    }
}
