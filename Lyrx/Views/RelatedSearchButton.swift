import SwiftUI

/// Artist and album navigation stays inside Lyrx and uses only the match's source.
struct RelatedSearchButton: View {
    let field: RelatedSearch
    let match: LyricMatch
    let model: ReaderModel
    let settings: AppSettings

    private var value: String { field == .artist ? match.artist : match.album }
    var body: some View {
        Button {
            model.searchRelated(field, match: match, settings: settings)
        } label: {
            Text(value).underline().fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain).foregroundStyle(.tint)
        .disabled(value.isEmpty || match.artist.isEmpty || !settings.providerAccess.searchable.contains(match.provider))
        .accessibilityLabel(
            field == .artist
                ? "Find songs by \(value) on \(match.provider.name)"
                : "Find songs from \(value) on \(match.provider.name)"
        )
        .accessibilityIdentifier(field == .artist ? "artistSearch" : "albumSearch")
    }
}
