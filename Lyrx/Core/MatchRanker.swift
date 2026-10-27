import Foundation

/// Predictable relevance ordering, independent of provider completion order.
enum MatchRanker {
    static func ranked(_ matches: [LyricMatch], for request: SearchRequest) -> [LyricMatch] {
        var seen: Set<String> = []
        return matches.filter { request.accepts($0) && seen.insert($0.id).inserted }
            .sorted {
                let lhs = score($0, request: request)
                let rhs = score($1, request: request)
                return lhs == rhs ? $0.id < $1.id : lhs > rhs
            }
    }

    private static func score(_ match: LyricMatch, request: SearchRequest) -> Int {
        let title = SearchRequest.normalized(match.title)
        let artist = SearchRequest.normalized(match.artist)
        let query = SearchRequest.normalized(request.query)
        let combined = "\(artist) \(title)"
        var result = 0
        if !query.isEmpty {
            if query == title { result += 120 }
            if query == artist { result += 100 }
            if query == combined || query == "\(title) \(artist)" { result += 180 }
            let words = Set(combined.split(separator: " "))
            let terms = Set(query.split(separator: " "))
            result += terms.intersection(words).count * 20
            result -= terms.subtracting(words).count * 25
        }
        if !request.title.isEmpty && title == SearchRequest.normalized(request.title) { result += 120 }
        if !request.artist.isEmpty && artist == SearchRequest.normalized(request.artist) { result += 100 }
        if match.hasLyrics { result += 5 }
        if match.instrumental { result -= 10 }
        if match.provider == .lrclib { result += 1 }
        return result
    }
}
