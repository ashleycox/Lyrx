import Foundation

/// Extracts paragraph text and stanza boundaries; timings and presentation markup never reach braille.
enum TTMLReader {
    static func plainText(_ data: Data) throws -> String {
        guard data.count <= HTTPClient.maximumBytes else { throw LyricServiceError.tooLarge }
        // Accept UTF-8 lyric documents without a DTD. Foundation can silently skip an external
        // entity without notifying its delegate, so reject declarations before parsing too.
        guard let source = String(data: data, encoding: .utf8), !source.contains("\0"),
            !source.contains("<!DOCTYPE")
        else { throw LyricServiceError.invalidResponse }
        let delegate = Paragraphs()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        parser.delegate = delegate
        guard parser.parse(), !delegate.rejected, delegate.sawBody else { throw LyricServiceError.invalidResponse }
        var lines = delegate.lines
        while lines.last == "" { lines.removeLast() }
        let text = lines.joined(separator: "\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LyricServiceError.noLyrics }
        return text
    }

    /// Used synchronously by one XMLParser; no parser state crosses a concurrency boundary.
    private final class Paragraphs: NSObject, XMLParserDelegate {
        var lines: [String] = []
        var rejected = false
        var sawBody = false
        private var bodyDepth: Int?
        private var ignoredDepth: Int?
        private var paragraph: String?
        private var preserveSpace: [Bool] = []
        private var pendingSpace = false
        private var textBytes = 0

        private func reject(_ parser: XMLParser) {
            rejected = true
            parser.abortParsing()
        }

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
            attributes: [String: String]
        ) {
            guard preserveSpace.count < 128 else {
                reject(parser)
                return
            }
            preserveSpace.append(attributes["xml:space"].map { $0 == "preserve" } ?? preserveSpace.last ?? false)
            guard ignoredDepth == nil else { return }
            guard name != "metadata",
                namespaceURI == "http://www.w3.org/ns/ttml" || namespaceURI == nil || namespaceURI == ""
            else {
                ignoredDepth = preserveSpace.count
                return
            }
            if name == "body" {
                bodyDepth = preserveSpace.count
                sawBody = true
            }
            guard bodyDepth != nil else { return }
            if name == "p" {
                guard paragraph == nil else {
                    reject(parser)
                    return
                }
                paragraph = ""
                pendingSpace = false
            } else if name == "br", paragraph != nil {
                paragraph?.append("\n")
                pendingSpace = false
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard paragraph != nil, ignoredDepth == nil else { return }
            textBytes += string.utf8.count
            guard textBytes <= HTTPClient.maximumBytes else {
                reject(parser)
                return
            }
            for character in string {
                if preserveSpace.last != true && character.isWhitespace {
                    pendingSpace = true
                } else {
                    if pendingSpace, let paragraph, !paragraph.isEmpty, paragraph.last != "\n" {
                        self.paragraph?.append(" ")
                    }
                    paragraph?.append(character)
                    pendingSpace = false
                }
            }
        }

        func parser(_ parser: XMLParser, foundCDATA block: Data) {
            guard let text = String(data: block, encoding: .utf8) else {
                reject(parser)
                return
            }
            self.parser(parser, foundCharacters: text)
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            defer { if !preserveSpace.isEmpty { preserveSpace.removeLast() } }
            if let ignoredDepth {
                if ignoredDepth == preserveSpace.count { self.ignoredDepth = nil }
                return
            }
            guard bodyDepth != nil,
                namespaceURI == "http://www.w3.org/ns/ttml" || namespaceURI == nil || namespaceURI == ""
            else { return }
            if name == "p", let paragraph {
                lines += paragraph.components(separatedBy: "\n")
                self.paragraph = nil
            } else if name == "div", paragraph == nil, !lines.isEmpty, lines.last != "" {
                lines.append("")
            } else if name == "body", bodyDepth == preserveSpace.count {
                bodyDepth = nil
            }
        }

        // No DTD entity expansion, external files, or secondary network access is allowed.
        func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
            reject(parser)
        }
        func parser(
            _ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?,
            systemID: String?
        ) { reject(parser) }
        func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? {
            reject(parser)
            return nil
        }
    }
}
