import SwiftUI

/// Mac results stay visible; iPhone and iPad retain a compact disclosure.
struct MatchesView: View {
    @Bindable var model: ReaderModel
    let settings: AppSettings
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            #if os(macOS)
                Text("Other Matches (\(model.matches.count))")
                    .font(.headline).accessibilityAddTraits(.isHeader)
                MacMatchesTable(model: model, settings: settings)
                    .frame(height: 192)
            #else
                Button {
                    model.toggleMatches()
                } label: {
                    Label(
                        "Other Matches (\(model.matches.count))",
                        systemImage: model.showMatches ? "chevron.down" : "chevron.right"
                    )
                    .fixedSize(horizontal: false, vertical: true)
                }
                .keyboardShortcut("m", modifiers: [.command, .option])
                .accessibilityValue(model.showMatches ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("matchesDisclosure")
                if model.showMatches {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(model.matches) { match in
                                VStack(alignment: .leading, spacing: 8) {
                                    Button {
                                        model.select(match, settings: settings)
                                    } label: {
                                        Text(match.title).font(.headline).frame(
                                            maxWidth: .infinity, alignment: .leading)
                                    }.buttonStyle(.plain)
                                        .accessibilityValue(model.selected?.id == match.id ? "Selected" : "")
                                    RelatedSearchButton(field: .artist, match: match, model: model, settings: settings)
                                    if !match.album.isEmpty {
                                        RelatedSearchButton(
                                            field: .album, match: match, model: model, settings: settings)
                                    }
                                    Text(match.provider.name).font(.caption).foregroundStyle(.secondary)
                                    Button("Additional Info") { model.openInfo(for: match, settings: settings) }
                                        .font(.caption)
                                }.padding(.vertical, 8).accessibilityElement(children: .contain)
                                Divider()
                            }
                        }
                    }.frame(maxHeight: 180).accessibilityLabel("Other matches")
                }
            #endif
            // Linked credits remain alongside the table/list, including lrc.red search data.
            if showsCredits {
                ForEach(
                    LyricProviderID.allCases.filter { provider in model.matches.contains { $0.provider == provider } }
                ) { provider in
                    Link("Results from \(provider.name)", destination: provider.website)
                        .font(.caption)
                        .keyboardShortcut(KeyEquivalent(provider.shortcut), modifiers: [.command, .control, .option])
                }
            }
        }
    }

    private var showsCredits: Bool {
        #if os(macOS)
            true
        #else
            model.showMatches
        #endif
    }
}
