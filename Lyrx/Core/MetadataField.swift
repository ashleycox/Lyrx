import Foundation

struct MetadataField: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let value: String

    /// Links are opt-in user actions, never automatically fetched or rendered as remote content.
    var link: URL? {
        guard let url = URL(string: value), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
}

/// Retains additional public provider metadata while excluding full lyrics from the info sheet.
indirect enum MetadataValue: Decodable, Sendable {
    case object([String: MetadataValue])
    case array([MetadataValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: Self].self) {
            self = .object(value)
        } else {
            self = .array(try container.decode([Self].self))
        }
    }

    func fields(excluding excluded: Set<String> = []) -> [MetadataField] {
        var result: [MetadataField] = []
        func append(_ value: Self, path: [String]) {
            switch value {
            case .null: break
            case .object(let values):
                for key in values.keys.sorted() where !excluded.contains(key) {
                    if let child = values[key] { append(child, path: path + [key]) }
                }
            case .array(let values):
                if values.allSatisfy({
                    if case .string = $0 { return true }
                    return false
                }) {
                    let strings = values.compactMap {
                        if case .string(let text) = $0 { return text }
                        return nil
                    }
                    if !strings.isEmpty { append(.string(strings.formatted(.list(type: .and))), path: path) }
                } else {
                    for (index, child) in values.enumerated() { append(child, path: path + [String(index + 1)]) }
                }
            default:
                let text: String
                switch value {
                case .string(let string): text = string
                case .bool(let bool): text = bool ? "Yes" : "No"
                case .number(let number):
                    text =
                        path.last == "duration" && number >= 0 && number < 604_800
                        ? Duration.seconds(number).formatted(.time(pattern: .minuteSecond))
                        : number.formatted(.number.grouping(.never))
                default: return
                }
                guard !text.isEmpty else { return }
                let id = path.map {
                    $0.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")
                }.joined(separator: "/")
                result.append(MetadataField(id: id, label: path.map(Self.label).joined(separator: " › "), value: text))
            }
        }
        append(self, path: [])
        return result
    }

    private static func label(_ key: String) -> String {
        let labels = [
            "id": "Provider ID", "isrc": "ISRC", "released": "Release date", "lines": "Lyric lines",
            "featured": "Featured artists", "songwriters": "Songwriters", "bpm": "BPM",
            "explicit_lyrics": "Explicit lyrics", "trackName": "Title", "artistName": "Artist", "albumName": "Album",
        ]
        return labels[key]
            ?? key.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
    }
}
