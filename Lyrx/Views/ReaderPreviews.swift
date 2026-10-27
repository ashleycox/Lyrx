#if DEBUG
    import SwiftUI

    /// Original fixture text lets previews exercise a loaded reader without network access.
    struct ExampleLyricService: LyricSearching {
        func search(_ request: SearchRequest, access: ProviderAccess) async throws -> SearchResponse {
            let first = LyricMatch(
                provider: .lrclib, providerID: "preview", title: "A Quiet Morning", artist: "Example Artist",
                album: "Reading Preview",
                lyrics:
                    "Morning light across the room\nA page is waiting to be read\n\nEach word has room to find its place\nA quiet line, a little space.",
                metadata: [.init(id: "songwriters", label: "Songwriters", value: "Example Writer")]
            )
            let alternatives = (1...12).map { index in
                LyricMatch(
                    provider: .lrclib, providerID: "example-\(index)", title: "Reading Example \(index)",
                    artist: "Example Artist", album: "Reading Preview",
                    lyrics: "Example \(index) begins on this line\nAnother page is ready to read")
            }
            // Exercise disappearing and recreated lyric readers while table browsing continues.
            let instrumental = LyricMatch(
                provider: .lrclib, providerID: "instrumental", title: "Instrumental Example",
                artist: "Example Artist", instrumental: true)
            let final = LyricMatch(
                provider: .lrclib, providerID: "final", title: "Final Example", artist: "Example Artist",
                lyrics: "A final page is waiting\nAnother line is ready")
            return SearchResponse(matches: ([first] + alternatives + [instrumental, final]).filter(request.accepts))
        }
        func lyrics(for match: LyricMatch, access: ProviderAccess) async throws -> String { match.lyrics ?? "" }
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
