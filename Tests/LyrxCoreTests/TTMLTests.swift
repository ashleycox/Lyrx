import Foundation
import Testing

@testable import LyrxCore

struct TTMLTests {
    @Test func annotationsNeverBecomeLyricText() throws {
        let xml =
            #"<tt xmlns="http://www.w3.org/ns/ttml" xmlns:m="urn:example:metadata"><body><p>Read <m:note>an annotation</m:note><metadata>hidden credits</metadata>these words</p></body></tt>"#
        #expect(try TTMLReader.plainText(Data(xml.utf8)) == "Read these words")
    }
    @Test func paragraphsSpansBreaksAndStanzasPreserveWords() throws {
        let xml = #"""
            <tt xmlns="http://www.w3.org/ns/ttml"><head><metadata>Not lyric text</metadata></head><body>
              <div><p><span begin="1s">Morning</span> <span>light &amp; sky</span><br/>Another line</p>
              <p><span>sun</span><span>shine</span> returns</p></div>
              <div><p>New stanza 👩🏽‍🚀</p></div>
            </body></tt>
            """#
        #expect(
            try TTMLReader.plainText(Data(xml.utf8))
                == "Morning light & sky\nAnother line\nsunshine returns\n\nNew stanza 👩🏽‍🚀")
    }

    @Test func explicitSpaceAndCDATAAreReadWithoutMarkup() throws {
        let xml =
            #"<tt xmlns="http://www.w3.org/ns/ttml" xml:space="preserve"><body><div><p> Two  spaces </p><p><![CDATA[Original <words>]]></p></div></body></tt>"#
        #expect(try TTMLReader.plainText(Data(xml.utf8)) == " Two  spaces \nOriginal <words>")
    }

    @Test(arguments: [
        "<html><p>Not TTML</p></html>", "<tt><body><p>Unclosed",
        #"<!DOCTYPE tt [<!ENTITY words "expanded">]><tt><body><p>&words;</p></body></tt>"#,
        #"<!DOCTYPE tt [<!ENTITY words SYSTEM "file:///etc/hosts">]><tt><body><p>&words;</p></body></tt>"#,
    ]) func malformedDocumentsAndEntitiesAreRejected(xml: String) {
        #expect(throws: LyricServiceError.invalidResponse) { try TTMLReader.plainText(Data(xml.utf8)) }
    }
}
