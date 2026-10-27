import Foundation
import Testing

@testable import LyrxCore

struct FormattingTests {
    @Test func spacesAndPunctuationCountTowardHardLimit() throws {
        let result = try LyricFormatter.format("One, two three!", options: .init(lineLimit: 8))
        #expect(result.lines == ["One, two", "three!"])
        #expect(result.lines.allSatisfy { $0.count <= 8 })
    }
    @Test func wordMovesIntactToNextLine() throws {
        #expect(
            try LyricFormatter.format("Blue quiet harbor", options: .init(lineLimit: 10)).lines == [
                "Blue quiet", "harbor",
            ])
    }
    @Test func oversizedWordStopsFormatting() {
        #expect(throws: LyricFormattingError.wordTooLong(required: 9, limit: 4)) {
            try LyricFormatter.format("a wonderful day", options: .init(lineLimit: 4))
        }
    }
    @Test func unlimitedDoesNotWrap() throws {
        #expect(
            try LyricFormatter.format("a wonderful day", options: .init(lineLimit: nil)).lines == ["a wonderful day"])
    }
    @Test func stanzaAndLineEndingsSurvive() throws {
        #expect(
            try LyricFormatter.format(" One\r\n\r\nTwo\rThree\u{2028}Four ", options: .init()).lines == [
                "One", "", "Two", "Three", "Four",
            ])
    }
    @Test func blankLinePreferenceIsIndependentOfWrapping() throws {
        #expect(
            try LyricFormatter.format("One\n\nTwo", options: .init(preserveBlankLines: false)).lines == ["One", "Two"])
    }
    @Test func punctuationAndQuotesStayWithWords() throws {
        let result = try LyricFormatter.format(
            "Hello, friend. “Stay here!” We’re home", options: .init(lineLimit: nil, punctuation: .all))
        #expect(result.lines == ["Hello,", "friend.", "“Stay here!”", "We’re home"])
    }
    @Test func apostrophesHyphensAndUnicodeAreNeverSplit() throws {
        let text = "We’re café 👨‍👩‍👧‍👦 re-entry"
        let result = try LyricFormatter.format(text, options: .init(lineLimit: 8))
        #expect(result.lines == ["We’re", "café 👨‍👩‍👧‍👦", "re-entry"])
        #expect(result.ranges[2].location == "We’re\ncafé 👨‍👩‍👧‍👦\n".utf16.count)
        #expect(result.line(atUTF16Offset: result.ranges[2].location) == 2)
    }
    @Test func lrcRemovesTimingButPreservesHeadings() {
        let source = "[ar:Example]\n[00:01.00][00:12.50]Original line\n[Chorus]\n[00:04.5]<00:04.5>Another line"
        #expect(LyricFormatter.plainText(fromLRC: source) == "Original line\n[Chorus]\nAnother line")
    }
    @Test func lrcWindowsLineEndingsDoNotCreateExtraStanzas() {
        #expect(LyricFormatter.plainText(fromLRC: "[00:01.00]One\r\n[00:02.00]Two") == "One\nTwo")
    }
    @Test func generatedWordSequencesAlwaysRespectLimit() throws {
        for limit in 1...80 {
            let words = (1...40).map { String(repeating: "x", count: ($0 % limit) + 1) }
            let result = try LyricFormatter.format(words.joined(separator: " "), options: .init(lineLimit: limit))
            #expect(result.lines.allSatisfy { $0.count <= limit })
            #expect(result.text.split(whereSeparator: \.isWhitespace).map(String.init) == words)
        }
    }
    @Test func whitespaceOnlyIsEmpty() throws {
        #expect(try LyricFormatter.format(" \n\t ", options: .init()).lines.isEmpty)
    }
}
