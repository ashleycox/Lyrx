import Foundation

protocol LyricSearching: Sendable {
    func search(_ request: SearchRequest, access: ProviderAccess) async throws -> SearchResponse
    func lyrics(for match: LyricMatch, access: ProviderAccess) async throws -> String
    func details(for match: LyricMatch, access: ProviderAccess) async throws -> LyricMatch
}

extension LyricSearching {
    func details(for match: LyricMatch, access: ProviderAccess) async throws -> LyricMatch { match }
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
    var transport: any HTTPTransport = RetryingHTTPTransport()

    // Keep response decoding and lyric parsing off the caller's UI actor with approachable concurrency.
    @concurrent
    func search(_ request: SearchRequest, access: ProviderAccess) async throws -> SearchResponse {
        let cleaned = request.cleaned
        guard !cleaned.isEmpty else { return SearchResponse(matches: []) }
        let batches = await withTaskGroup(of: SearchResponse.self) { group in
            for provider in LyricProviderID.allCases where access.searchable.contains(provider) {
                group.addTask {
                    do {
                        let matches = try await search(cleaned, provider: provider, access: access)
                        return SearchResponse(matches: matches)
                    } catch {
                        if Task.isCancelled { return SearchResponse(matches: []) }
                        return SearchResponse(
                            matches: [],
                            notices: [ProviderNotice(provider: provider, message: Self.message(for: error))])
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
        return SearchResponse(
            matches: MatchRanker.ranked(batches.matches, for: cleaned),
            notices: batches.notices.sorted { $0.provider.rawValue < $1.provider.rawValue })
    }

    @concurrent
    func lyrics(for match: LyricMatch, access: ProviderAccess) async throws -> String {
        try Task.checkCancellation()
        guard access.searchable.contains(match.provider) else { throw LyricServiceError.providerNotConfigured }
        if match.instrumental { return "" }
        if let lyrics = match.lyrics, !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return lyrics }
        if match.provider == .lrcRed {
            do {
                let data = try await get(
                    host: "lrc.red", path: ["s", match.providerID + ".ttml"], access: access,
                    accept: "application/ttml+xml, application/xml")
                return try TTMLReader.plainText(data)
            } catch LyricServiceError.noLyrics {
                let data = try await get(
                    host: "lrc.red", path: ["s", match.providerID + ".lrc"], access: access, accept: "text/plain")
                guard let text = String(data: data, encoding: .utf8) else { throw LyricServiceError.invalidResponse }
                let lyrics = LyricFormatter.plainText(fromLRC: text)
                guard !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw LyricServiceError.noLyrics
                }
                return lyrics
            }
        }
        guard match.provider == .lyricsOVH else { throw LyricServiceError.noLyrics }
        let data = try await get(host: "api.lyrics.ovh", path: ["v1", match.artist, match.title])
        let response: OVHLyrics = try decode(data)
        guard !response.lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LyricServiceError.noLyrics
        }
        return response.lyrics
    }

    @concurrent
    func details(for match: LyricMatch, access: ProviderAccess) async throws -> LyricMatch {
        guard access.searchable.contains(match.provider) else { throw LyricServiceError.providerNotConfigured }
        try Task.checkCancellation()
        guard match.provider == .lrcRed, !match.detailsComplete else { return match }
        let data = try await get(host: "lrc.red", path: ["s", match.providerID + ".json"], access: access)
        let record: LrcRedRecord = try decode(data)
        guard record.isrc == match.providerID else { throw LyricServiceError.invalidResponse }
        var result = record.match
        result.lyrics = match.lyrics
        result.detailsComplete = true
        return result
    }

    private func search(_ request: SearchRequest, provider: LyricProviderID, access: ProviderAccess) async throws
        -> [LyricMatch]
    {
        switch provider {
        case .lrclib:
            let queryText =
                request.query.isEmpty && request.artist.isEmpty && request.title.isEmpty ? request.album : request.query
            let fields = [
                ("q", queryText), ("artist_name", request.artist),
                ("track_name", request.title), ("album_name", request.album),
            ]
            let query = fields.filter { !$0.1.isEmpty }.map { URLQueryItem(name: $0.0, value: $0.1) }
            let data = try await get(host: "lrclib.net", path: ["api", "search"], query: query)
            let records: [LRCLIBRecord] = try decode(data)
            let metadata: [MetadataValue] = try decode(data)
            return zip(records, metadata).prefix(200).map { record, values in
                var match = record.match
                match.metadata = values.fields(excluding: [
                    "plainLyrics", "syncedLyrics", "lyricsfile", "trackName", "artistName", "albumName",
                ])
                return match
            }
        case .lyricsOVH:
            // Exact artist/title searches do not require the suggestions service to be available.
            if !request.artist.isEmpty, !request.title.isEmpty, request.album.isEmpty, request.query.isEmpty {
                return [
                    LyricMatch(
                        provider: .lyricsOVH, providerID: request.artist + "/" + request.title,
                        title: request.title, artist: request.artist)
                ]
            }
            let data = try await get(host: "api.lyrics.ovh", path: ["suggest", request.suggestionQuery])
            let response: OVHSuggestions = try decode(data)
            let metadata: OVHMetadata = try decode(data)
            return zip(response.data, metadata.data).prefix(50).map { track, values in
                LyricMatch(
                    provider: .lyricsOVH, providerID: String(track.id), title: track.title,
                    artist: track.artist.name, album: track.album?.title ?? "",
                    metadata: values.fields(excluding: ["title"]))
            }
        case .lrcRed:
            // The API searches titles/artists; album filtering is applied locally to those candidates.
            let query =
                request.query.isEmpty
                ? [request.artist, request.title].filter { !$0.isEmpty }.joined(separator: " ") : request.query
            let text = query.isEmpty ? request.album : query
            let data = try await get(
                host: "lrc.red", path: ["search.json"], query: [.init(name: "q", value: text)], access: access)
            let response: LrcRedSearch = try decode(data)
            return response.hits.prefix(200).map(\.match)
        }
    }

    private func get(
        host: String, path: [String], query: [URLQueryItem] = [], access: ProviderAccess? = nil,
        accept: String = "application/json"
    ) async throws -> Data {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        // Encode each segment separately: artist names may contain slash, %, ?, or #.
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/%?#"))
        components.percentEncodedPath =
            "/" + path.map { $0.addingPercentEncoding(withAllowedCharacters: allowed) ?? "" }.joined(separator: "/")
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw LyricServiceError.invalidURL }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.setValue(accept, forHTTPHeaderField: "Accept")
        if host == "lrc.red" {
            guard let access, access.searchable.contains(.lrcRed), let email = access.contactEmail else {
                throw LyricServiceError.providerNotConfigured
            }
            request.setValue(
                "Lyrx/1.0 (https://github.com/ashleycox/Lyrx; contact: \(email))", forHTTPHeaderField: "User-Agent")
        } else {
            request.setValue("Lyrx/1.0 (https://github.com/ashleycox/Lyrx)", forHTTPHeaderField: "User-Agent")
        }
        try Task.checkCancellation()
        return try await transport.data(for: request)
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) } catch { throw LyricServiceError.invalidResponse }
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
        return LyricMatch(
            provider: .lrclib, providerID: String(id), title: trackName,
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
private struct OVHMetadata: Decodable { let data: [MetadataValue] }

private struct LrcRedSearch: Decodable { let hits: [LrcRedRecord] }

private struct LrcRedRecord: Decodable {
    let isrc: String
    let title: String
    let artist: String
    let album: String
    let metadata: [MetadataField]

    private enum CodingKeys: String, CodingKey { case isrc, title, artist, album }
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isrc = try values.decode(String.self, forKey: .isrc)
        title = try values.decode(String.self, forKey: .title)
        artist = try values.decode(String.self, forKey: .artist)
        album = try values.decodeIfPresent(String.self, forKey: .album) ?? ""
        // Timing availability is irrelevant to the plain-text reader, which never follows playback.
        metadata = try MetadataValue(from: decoder).fields(excluding: [
            "title", "artist", "album", "lyrics", "plainLyrics", "syncedLyrics", "sync",
        ])
    }

    var match: LyricMatch {
        LyricMatch(
            provider: .lrcRed, providerID: isrc, title: title, artist: artist, album: album, metadata: metadata,
            detailsComplete: false)
    }
}
