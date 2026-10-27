# Accessibility verification

Lyrx uses a read-only, selectable NSTextView on macOS and UITextView on iOS. The text contains actual newline characters. Soft visual wrapping is disabled; longer lines can be panned horizontally. No custom braille translation or hardware transport is implemented.

## Automated coverage

Core tests verify hard widths (including spaces and punctuation), intact words and Unicode graphemes, UTF-16 selection offsets, stanza preservation, punctuation boundaries, unlimited lines, oversized-word recovery, ranking, provider isolation, cancellation, and stale-response protection.

Focus requests are consumed once. Core tests verify that browsing a match can update the lyric without requesting reader focus, and that an old focus request cannot be replayed after a text view is recreated. The focused Mac interface test checks an adjacent row, crosses the scroll boundary in one keyboard-input batch, and visits an instrumental result that temporarily removes the text view. Application-level key events detect focus escaping into the reader without a separate wait for every equivalent row.

After Return, Up must no longer select the preceding instrumental row. This guards against leaving keyboard focus in the table without assuming that bare arrow keys move a read-only text caret on every system. The smoke test separately checks the Next Line action; exact VoiceOver focus and braille routing still require the manual checks below.

Use `Scripts/test-ui.sh macOS focus` for this regression, `Scripts/test-ui.sh iOS large-text` for Dynamic Type layout, and `Scripts/test-ui.sh iOS settings` for provider controls. The default runner selects one Mac smoke test. Broader suites are explicit and are not run on every push; see the verification policy in `AGENTS.md`.

## Runtime checks performed

During development on 27 October 2026:

- macOS and iOS Simulator builds passed in Swift 6 mode with complete concurrency checking.
- The Mac app was built with ad-hoc signing. Its resulting entitlements contained App Sandbox and outgoing network access, without cloud or push capabilities.
- A live Mac search returned provider results and moved keyboard focus to the native lyric text control, confirmed through the accessibility tree. Mac table browsing now preserves results focus; explicitly reading a match moves focus into its lyrics.
- Next Line advanced the current position. One-line mode exposed only the selected line, with an accessible line-number label. Returning to full text kept the position.
- The Mac Settings accessibility tree exposed the last enabled provider as disabled, with an explanation. Provider labels were made explicit after inspection.
- iPhone and iPad Simulator UI tests passed for search-to-reader behavior, line navigation, provider-toggle protection, and the largest Dynamic Type setting. Visual inspection caught a compressed reader at large text sizes; the layout now scrolls and tests assert a usable reader height.

These checks do not substitute for VoiceOver and physical braille-display testing. No physical display, braille translation table, iPhone, or iPad has been validated yet.

## Before a public release

Record OS versions, display model and firmware, connection type, braille table, and contracted/uncontracted mode for each hardware run.

1. Start with only a keyboard or braille input. On Mac, Command–F must focus search, Return must submit, and successful loading must focus the first lyric line without selecting the entire song. Confirm focus does not jump on redraws or ordinary caret movement.
2. Confirm standard text navigation, selection, copy, braille routing keys, and panning on both platforms. Validate Next/Previous/First/Last Line commands, end boundaries, blank stanzas, and supplementary Unicode characters.
3. Test 20, 40, and 80 characters plus Unlimited. Count spaces and punctuation. A word that crosses the remaining width must move to the next line; a word longer than an empty line must show a formatting error. Recover by increasing the width or choosing Unlimited without another search.
4. Test one-line and full-text modes with VoiceOver. Ensure the current line is available through braille after a line action, including an empty stanza line. Check rotor access and custom actions on iOS. Watch for duplicate announcements.
5. Exercise Mac menus, shortcuts, Tab/Shift–Tab, native picker keyboard behavior, and settings controls with Keyboard Navigation enabled. Verify every action is reachable and there are no focus traps. Test multiple windows and confirm commands target the focused one.
6. Test iPhone portrait and landscape, small screens, iPad split view, all Dynamic Type sizes, 300% lyric text, Zoom, dark mode, Increase Contrast, Bold Text, and Reduce Motion. Controls and error messages must remain reachable without clipping.
7. Disable each provider in turn; the final enabled service must stay on. Search offline, cancel, repeat rapidly, switch matches mid-load, and change providers mid-search. Confirm errors are available to VoiceOver and that stale responses never replace newer content.
8. Confirm platform-specific help: Mac screens describe menus and VoiceOver Utility; iOS screens describe touch and system Settings. Do not show instructions for another platform.
9. On Mac, expand Other Matches and interact with the table using VoiceOver. Browse every row, scroll, resize the window, and expand filters. Focus must stay in the table while lyrics update. Return or Read Lyrics must focus the reader once. Test selections with missing lyrics, instrumentals, delayed responses, and formatting errors as well as successful results.

## References

- [Apple accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [NSTextView](https://developer.apple.com/documentation/appkit/nstextview)
- [UITextView](https://developer.apple.com/documentation/uikit/uitextview)
- [Required-reason API declarations](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)
