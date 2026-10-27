import SwiftUI

/// Search stays above the reader; secondary controls never require leaving the lyric view.
struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @State private var model = ReaderModel()
    @State private var showingSettings = false
    @FocusState private var focusedField: SearchField?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    enum SearchField: Hashable { case query, artist, title, album }

    init(model: ReaderModel? = nil) {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                _model = State(initialValue: model ?? ReaderModel(service: ExampleLyricService()))
                return
            }
        #endif
        _model = State(initialValue: model ?? ReaderModel())
    }

    var body: some View {
        NavigationStack {
            adaptiveContent
                .navigationTitle("Lyrx")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem {
                        Button("Reading Help", systemImage: "questionmark.circle") { model.showHelp = true }
                            .help("Reading help (Command–?)")
                    }
                    ToolbarItem {
                        #if os(macOS)
                            SettingsLink { Label("Settings", systemImage: "gearshape") }
                                .help("Settings (Command–Comma)")
                        #else
                            Button("Settings", systemImage: "gearshape") { showingSettings = true }.keyboardShortcut(
                                ",")
                        #endif
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    NavigationStack {
                        SettingsView()
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { showingSettings = false }
                                }
                            }
                    }
                }
                .sheet(isPresented: $model.showHelp) { ReadingHelpView() }
        }
        #if os(macOS)
            .frame(minWidth: 540, minHeight: 480)
        #endif
        .focusedSceneValue(\.lyrxReader, model)
        .onChange(of: model.searchFocusID) { focusedField = .query }
        .onChange(of: model.readerFocusID) { focusedField = nil }
        .onChange(of: model.pendingMatchesFocusID) {
            if model.pendingMatchesFocusID != nil { focusedField = nil }
        }
        .onChange(of: settings.formatting) { model.reformat(settings.formatting) }
        .onChange(of: settings.singleLine) { model.go(to: model.currentLine) }
        .onChange(of: settings.enabledProviders) { model.providersChanged(settings.enabledProviders) }
        .onDisappear { model.cancel() }
    }

    /// At large text sizes or in landscape, the whole page can scroll instead of crushing the reader.
    @ViewBuilder private var adaptiveContent: some View {
        #if os(iOS)
            if dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact {
                ScrollView { mainContent }
            } else {
                mainContent
            }
        #else
            // Keep one hierarchy as filters, notices, and results expand. Switching between
            // duplicate layouts destroys accessibility elements and can dislodge VoiceOver.
            GeometryReader { geometry in
                ScrollView {
                    mainContent.frame(minHeight: geometry.size.height, alignment: .top)
                }
            }
        #endif
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            searchControls.padding()
            Divider()
            readerContent
        }
    }

    private var searchControls: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 12) {
            let searchLayout =
                dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout())
            searchLayout {
                TextField("Song title, artist, or both", text: $model.request.query)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search lyrics")
                    .accessibilityIdentifier("searchField")
                    .focused($focusedField, equals: .query)
                    .onSubmit(search).submitLabel(.search)
                Button("Search", systemImage: "magnifyingglass", action: search)
                    .disabled(!model.canSearch)
                    .accessibilityIdentifier("searchButton")
                    .keyboardShortcut(.return, modifiers: .command)
            }
            HStack {
                Button(model.showFilters ? "Hide Filters" : "Show Filters", systemImage: "line.3.horizontal.decrease") {
                    model.showFilters.toggle()
                }
                .accessibilityValue(model.showFilters ? "Expanded" : "Collapsed")
                .keyboardShortcut("f", modifiers: [.command, .option])
                Spacer()
                if model.isSearching {
                    ProgressView().controlSize(.small).accessibilityLabel("Searching")
                    Button("Cancel", action: model.cancel).keyboardShortcut(".", modifiers: .command)
                }
            }
            if model.showFilters {
                VStack(alignment: .leading, spacing: 8) {
                    filterField("Artist", text: $model.request.artist, field: .artist, key: "1")
                    filterField("Title", text: $model.request.title, field: .title, key: "2")
                    filterField("Album", text: $model.request.album, field: .album, key: "3")
                    Button("Clear Filters") {
                        model.request.artist = ""
                        model.request.title = ""
                        model.request.album = ""
                    }.keyboardShortcut("k", modifiers: [.command, .option])
                }.textFieldStyle(.roundedBorder)
            }
        }
    }

    private func filterField(_ label: String, text: Binding<String>, field: SearchField, key: KeyEquivalent)
        -> some View
    {
        HStack {
            Button(label) { focusedField = field }
                .buttonStyle(.plain)
                .keyboardShortcut(key, modifiers: [.command, .control])
                .accessibilityLabel("Focus \(label) filter")
            TextField(label, text: text)
                .accessibilityLabel("\(label) filter")
                .focused($focusedField, equals: field)
                .onSubmit(search).submitLabel(.search)
        }
    }

    private var readerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let match = model.selected {
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.title).font(.title2).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(
                        .isHeader)
                    Text(match.artist).font(.headline).fixedSize(horizontal: false, vertical: true)
                    if !match.album.isEmpty { Text(match.album).font(.subheadline).foregroundStyle(.secondary) }
                    Text("Lyrics from \(match.provider.name)").font(.caption).foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            if let message = model.formattingError {
                ContentUnavailableView {
                    Label("A word cannot fit", systemImage: "text.badge.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    #if os(macOS)
                        SettingsLink { Text("Change Line Width…") }
                    #else
                        Button("Change Line Width…") { showingSettings = true }
                    #endif
                }.accessibilityIdentifier("formattingError")
            } else if model.hasLyrics {
                NativeLyricReader(model: model, settings: settings)
                    .accessibilityIdentifier("lyricReader")
                    .frame(minHeight: 220)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(.separator) }
                lineControls
            } else {
                ContentUnavailableView {
                    Label(
                        model.selected?.instrumental == true ? "Instrumental recording" : "Lyrics, one line at a time",
                        systemImage: "text.alignleft")
                } description: {
                    Text(
                        model.selected?.instrumental == true
                            ? "This recording has no lyric text."
                            : "Search above. The best available match opens here, ready to read with VoiceOver or your braille display."
                    )
                }.frame(maxHeight: .infinity)
            }
            Text(model.status).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("searchStatus")
            ForEach(model.notices) { notice in
                Label("\(notice.provider.name): \(notice.message)", systemImage: "exclamationmark.circle").font(
                    .callout)
            }
            if !model.matches.isEmpty { MatchesView(model: model, settings: settings) }
        }.padding()
    }

    private var lineControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                navigationButtons
                Spacer()
                Text(model.lineStatus).monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(model.lineStatus).monospacedDigit()
                navigationButtons
            }
        }.font(.callout)
    }
    private var navigationButtons: some View {
        HStack {
            Button("Previous Line", systemImage: "chevron.up") { model.go(to: model.currentLine - 1) }
                .disabled(!model.canGoBack).keyboardShortcut(.upArrow, modifiers: [.command, .option])
            Button("Next Line", systemImage: "chevron.down") { model.go(to: model.currentLine + 1) }
                .disabled(!model.canGoForward).keyboardShortcut(.downArrow, modifiers: [.command, .option])
        }.labelStyle(.iconOnly).buttonStyle(.bordered).controlSize(.large)
    }
    private func search() { model.search(settings: settings) }
}
