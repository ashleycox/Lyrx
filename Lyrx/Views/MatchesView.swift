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
                                Button {
                                    model.select(match, settings: settings)
                                } label: {
                                    HStack(alignment: .top, spacing: 8) {
                                        if model.selected?.id == match.id {
                                            Image(systemName: "checkmark").accessibilityLabel("Selected")
                                        }
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(match.title).font(.headline)
                                            Text(
                                                [match.artist, match.album, match.provider.name].filter { !$0.isEmpty }
                                                    .joined(separator: " · ")
                                            )
                                            .font(.subheadline).foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 0)
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                                        .contentShape(
                                            .rect)
                                }.buttonStyle(.plain)
                                Divider()
                            }
                        }
                    }.frame(maxHeight: 180).accessibilityLabel("Other matches")
                }
            #endif
        }
    }
}
