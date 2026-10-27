#if DEBUG
    import SwiftUI

    /// Original fixture text lets previews exercise a loaded reader without network access.
    struct ExampleLyricService: LyricSearching {
        func search(_ request: SearchRequest, enabled: Set<LyricProviderID>) async throws -> SearchResponse {
            SearchResponse(matches: [
                .init(
                    provider: .lrclib, providerID: "preview", title: "A Quiet Morning", artist: "Example Artist",
                    album: "Reading Preview",
                    lyrics:
                        "Morning light across the room\nA page is waiting to be read\n\nEach word has room to find its place\nA quiet line, a little space."
                )
            ])
        }
        func lyrics(for match: LyricMatch) async throws -> String { match.lyrics ?? "" }
    }

    private struct ReaderPreview: View {
        @State private var model = ReaderModel(service: ExampleLyricService())
        @State private var settings = AppSettings(defaults: UserDefaults(suiteName: "Lyrx.Preview")!)
        var body: some View {
            ContentView(model: model).environment(settings)
                .task {
                    model.request.query = "A Quiet Morning"
                    model.search(settings: settings)
                    await model.waitForCurrentOperation()
                }
        }
    }

    #Preview("Reader") { ReaderPreview() }
    #Preview("Large Text") { ReaderPreview().dynamicTypeSize(.accessibility5) }
    #Preview("Dark Reader") { ReaderPreview().preferredColorScheme(.dark) }
#endif
