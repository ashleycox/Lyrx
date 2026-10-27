import Foundation

protocol LyricSearching: Sendable {
    func search(_ request: SearchRequest, enabled: Set<LyricProviderID>) async throws -> SearchResponse
    func lyrics(for match: LyricMatch) async throws -> String
}

struct ProviderNotice: Identifiable, Equatable, Sendable {
    let provider: LyricProviderID
    let message: String
    var id: LyricProviderID { provider }
}

struct SearchResponse: Sendable {
    var matches: [LyricMatch]
    var notices: [ProviderNotice] = []
}

/// Runs independent services concurrently; one failing service does not discard another's results.
struct ProviderClient: LyricSearching {
    var transport: any HTTPTransport = HTTPClient()

    func search(_ request: SearchRequest, enabled: Set<LyricProviderID>) async throws -> SearchResponse {
        let cleaned = request.cleaned
        guard !cleaned.isEmpty else { return SearchResponse(matches: []) }
        let batches = await withTaskGroup(of: SearchResponse.self) { group in
            for provider in LyricProviderID.allCases where enabled.contains(provider) {
                group.addTask {
                    do {
                        let matches = try await search(cleaned, provider: provider)
                        return SearchResponse(matches: matches)
                    } catch {
                        if Task.isCancelled { return SearchResponse(matches: []) }
                        return SearchResponse(matches: [], notices: [ProviderNotice(provider: provider, message: Self.message(for: error))])
                    }
                }
            }
            var response = SearchResponse(matches: [])
            for await batch in group {
                response.matches += batch.matches
                response.notices += batch.notices
            }
            return response
        }
        try Task.checkCancellation()
        return SearchResponse(matches: MatchRanker.ranked(batches.matches, for: cleaned),
                              notices: batches.notices.sorted { $0.provider.rawValue < $1.provider.rawValue })
    }

    func lyrics(for match: LyricMatch) async throws -> String {
        try Task.checkCancellation()
        if match.instrumental { return "" }
        if let lyrics = match.lyrics, !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return lyrics }
        guard match.provider == .lyricsOVH else { throw LyricServiceError.noLyrics }
        let data = try await get(host: "api.lyrics.ovh", path: ["v1", match.artist, match.title])
        let response: OVHLyrics = try decode(data)
        guard !response.lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LyricServiceError.noLyrics }
        return response.lyrics
    }

    private func search(_ request: SearchRequest, provider: LyricProviderID) async throws -> [LyricMatch] {
        switch provider {
        case .lrclib:
            let fields = [("q", request.query), ("artist_name", request.artist),
                          ("track_name", request.title), ("album_name", request.album)]
            let query = fields.filter { !$0.1.isEmpty }.map { URLQueryItem(name: $0.0, value: $0.1) }
            let data = try await get(host: "lrclib.net", path: ["api", "search"], query: query)
            let records: [LRCLIBRecord] = try decode(data)
            return records.prefix(200).map(\.match)
        case .lyricsOVH:
            // Exact artist/title searches do not require the suggestions service to be available.
            if !request.artist.isEmpty, !request.title.isEmpty, request.album.isEmpty, request.query.isEmpty {
                return [LyricMatch(provider: .lyricsOVH, providerID: request.artist + "/" + request.title,
                                   title: request.title, artist: request.artist)]
            }
            let data = try await get(host: "api.lyrics.ovh", path: ["suggest", request.suggestionQuery])
            let response: OVHSuggestions = try decode(data)
            return response.data.prefix(50).map {
                LyricMatch(provider: .lyricsOVH, providerID: String($0.id), title: $0.title,
                           artist: $0.artist.name, album: $0.album?.title ?? "")
            }
        }
    }

    private func get(host: String, path: [String], query: [URLQueryItem] = []) async throws -> Data {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        // Encode each segment separately: artist names may contain slash, %, ?, or #.
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/%?#"))
        components.percentEncodedPath = "/" + path.map { $0.addingPercentEncoding(withAllowedCharacters: allowed) ?? "" }.joined(separator: "/")
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw LyricServiceError.invalidURL }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Lyrx/1.0 (https://github.com/ashleycox/Lyrx)", forHTTPHeaderField: "User-Agent")
        return try await transport.data(for: request)
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw LyricServiceError.invalidResponse }
    }

    static func message(for error: any Error) -> String {
        if let error = error as? LyricServiceError { return error.localizedDescription }
        if let error = error as? URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost: return "Check your internet connection and try again."
            case .timedOut: return "The service took too long to respond. Try again or enable another provider."
            default: return "Could not connect to the service. Try again later."
            }
        }
        return "The service could not complete this request. Try again."
    }
}

// Wire formats are confined to the adapter; no view depends on provider-specific JSON.
private struct LRCLIBRecord: Decodable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String?
    let instrumental: Bool?
    let plainLyrics: String?
    let syncedLyrics: String?

    var match: LyricMatch {
        let plain = plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines)
        let lyrics = plain?.isEmpty == false ? plain : syncedLyrics.map(LyricFormatter.plainText)
        return LyricMatch(provider: .lrclib, providerID: String(id), title: trackName,
                          artist: artistName, album: albumName ?? "", lyrics: lyrics,
                          instrumental: instrumental ?? false)
    }
}

private struct OVHSuggestions: Decodable {
    let data: [Track]
    struct Track: Decodable {
        let id: Int
        let title: String
        let artist: Artist
        let album: Album?
    }
    struct Artist: Decodable { let name: String }
    struct Album: Decodable { let title: String }
}

private struct OVHLyrics: Decodable { let lyrics: String }
