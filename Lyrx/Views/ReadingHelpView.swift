import SwiftUI

struct ReadingHelpView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Find lyrics") {
                    #if os(macOS)
                        Text(
                            "Press Command–F, type a song title, artist, or both, then Return. The best available match opens in the lyric text control. Show Filters for artist, title, or album. Other Matches lets you choose another recording or source."
                        )
                        Text(
                            "The Other Matches table stays visible after a search. Command–Option–M focuses it. Selecting a row updates the lyrics while keeping focus in the table. Press Return, double-click, or choose Read Lyrics to move into the reader."
                        )
                    #else
                        Text(
                            "Enter a song title, artist, or both in Search Lyrics, then tap Search. The best available match opens in the lyric text control. Show Filters for artist, title, or album. Other Matches lets you choose another recording or source."
                        )
                    #endif
                }
                Section("Read with braille") {
                    #if os(macOS)
                        Text(
                            "Lyrics use real line breaks in a native, read-only text control. Use your normal VoiceOver text-navigation and braille panning commands. Command–L returns focus to the lyrics."
                        )
                        Text(
                            "Show One Line at a Time exposes only the current line. Blank lines mark stanza breaks. Configure your display and braille translation in VoiceOver Utility."
                        )
                    #else
                        Text(
                            "Lyrics use real line breaks in a native, read-only text control. Use VoiceOver’s text rotor and your braille display’s panning controls. Next Line and Previous Line are also available as VoiceOver actions on the lyrics."
                        )
                        Text(
                            "Show One Line at a Time exposes only the current line. Blank lines mark stanza breaks. Configure your braille display in Settings, Accessibility, VoiceOver, Braille."
                        )
                    #endif
                }
                Section("Optional visual line guide") {
                    Text(
                        "Show line controls and highlighting in Settings adds Previous Line and Next Line buttons, a position count, and a highlight on the current line. It is off by default. The position follows Lyrx's text caret, not the VoiceOver cursor or braille display."
                    )
                    #if os(macOS)
                        Text(
                            "Command–Shift–N toggles the visual guide. The Lyrics menu also provides line navigation commands."
                        )
                    #else
                        Text("If you use one-line mode, enable the controls to move between lines by touch.")
                    #endif
                }
                Section("Fit your display") {
                    Text(
                        "Settings starts at 40 characters, counting spaces and punctuation. Words stay intact. A word longer than the limit pauses formatting until you increase the width or choose Unlimited. Unlimited keeps longer lines for panning. You can also split at punctuation boundaries, change font and text size, and preserve or remove blank lines."
                    )
                }
                #if os(macOS)
                    Section("Keyboard access") {
                        Text(
                            "Command–Comma: Settings. Command–Option–F: filters. Command–Option–M: other matches. Command–Option–[ or ]: previous or next match. Command–Option–Home or End: first or last line. Command–Period: cancel. Standard Tab, Shift–Tab, arrows, Space, and Return operate native controls. Enable Keyboard Navigation in macOS Settings for all controls."
                        )
                    }
                #else
                    Section("External keyboard") {
                        Text(
                            "With a keyboard connected, Command–F focuses search. Command–Option–Up or Down Arrow moves between lyric lines. Hold Command to discover available shortcuts. Full Keyboard Access is available in Accessibility settings."
                        )
                    }
                #endif
            }
            .formStyle(.grouped).navigationTitle("Reading with Lyrx")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
                }
            }
        }
        #if os(macOS)
            .frame(minWidth: 500, idealWidth: 560, minHeight: 500, idealHeight: 640)
        #endif
    }
}
