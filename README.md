# Lyrx

A native lyric finder for macOS, iPhone, and iPad, designed for reading with VoiceOver and single-line braille displays.

Search by song title, artist, or both. Lyrx searches your enabled services, ranks the matches, loads the best available lyric, and moves focus into a native, selectable text control. The reader uses real line breaks, without webpage navigation or advertising.

## Reading

On Mac, press **Command–F**, enter your search, and press **Return**. **Command–L** (**Lyrics → Focus Lyrics**) returns to the loaded lyric text from Search or Other Matches without resetting the text caret. The command is available once lyric text has loaded and can be formatted. On iPhone and iPad, enter your query and use Search. Read within the native text control using your normal VoiceOver text navigation and braille panning.

**Show line controls and highlighting** in Settings is an optional visual reading aid, off by default. It adds Previous Line and Next Line buttons, a position count, and a background highlight on the current line's text. It tracks the text caret, not VoiceOver's cursor or braille position. On Mac, **Command–Shift–N** toggles it; the Lyrics menu and **Command–Option–Up/Down Arrow** also move between formatted lines. On iOS, line navigation is available through the reader's VoiceOver actions. Enable the controls to navigate one-line mode by touch.

- The default **40-character hard limit** counts letters, spaces, and punctuation. A word that does not fit moves intact to the next line.
- A word longer than the entire limit pauses formatting with an explanation. Increase the limit or choose **Unlimited**; words are never truncated or split.
- Unlimited preserves longer lines for horizontal and braille panning. Original line breaks remain; optional splitting after commas, sentence punctuation, or other punctuation happens at whitespace-separated word boundaries. Apostrophes and hyphens inside words remain intact.
- Blank lines between stanzas are preserved by default. One-line mode exposes just the current line in the text control.
- Font and text-size settings apply to the reader. iPhone and iPad also support Dynamic Type. The interface uses semantic colors and standard platform controls.

Text width counts Unicode extended grapheme clusters, not translated braille cells. Contractions, capital indicators, and other translation choices can change the cell count. Set the width to suit your display and translation table. This app does not implement a braille driver or change system braille settings.

Show Filters to narrow results by artist, title, or album. Selecting another match replaces the current lyric. Songwriter filtering is not offered because these APIs do not reliably supply songwriter metadata. Automatic loading tries at most five vocal candidates; all returned matches remain available for manual selection. Instrumentals can be selected explicitly.

On Mac, Other Matches is a native table with title, artist, album, and provider columns, always visible when results are available. Command–Option–M focuses the table. Arrow keys browse rows and update the lyrics without moving focus out of the table. Press Return, double-click a row, or choose Read Lyrics from its context menu to enter the reader. Command–L also returns to the loaded lyric. On iPhone and iPad, Other Matches remains collapsible, with individually accessible result buttons.

**Additional Info** shows credits and other metadata returned by the source, such as duration, release date, language, identifiers, and source links. Open it with **Command–I** on Mac, the reader's info button, or a result's Additional Info action. lrc.red's full record loads when this view opens; other services show their search metadata. Missing information is left absent, and no artwork or audio is downloaded automatically. Synchronization status is omitted because Lyrx reads plain text and does not support following playback or highlighting timed words.

Artist and album names open another search on that match's provider. The artist/album filters are shown, Mac results retain table focus, and iOS expands Other Matches. These links do not change your saved service switches. **Command–Shift–A/B** searches the loaded match's artist/album on Mac. **All Enabled Services** (**Command–Shift–S**) repeats the filtered search across your configured providers. Provider result limits apply; these searches are not complete discographies or album track lists.

## Services and privacy

[LRCLIB](https://lrclib.net/docs) is enabled by default. [lyrics.ovh](https://github.com/NTag/lyrics.ovh) and [lrc.red](https://lrc.red/api) are optional. None requires an API key. Settings always keeps at least one service enabled. Service errors are shown separately, so a failed provider does not discard successful results from another.

Enable **lrc.red** in Settings to reveal its **Contact email** field. A valid contact address is required by that service and sent in its identifying User-Agent with each request. A blank or invalid address excludes lrc.red from searches, lyric downloads, and metadata requests even while its switch is on. Clearing the address does not enable another provider automatically. The last usable alternative cannot be disabled in favor of an unconfigured lrc.red; if you later clear the email with only lrc.red enabled, configure it or enable another service before searching. On Mac, **Search Results → Lyric Services** exposes the provider commands: **Command–Shift–1/2** toggles LRCLIB/lyrics.ovh and **Command–Shift–R** toggles lrc.red. In Settings, **Command–Shift–E** focuses its email field.

The address stays in local preferences and is sent only to lrc.red. Requests carrying it cannot redirect to another origin. It is never placed in a URL, displayed as attribution, or sent to the other providers. Linked credits identify the provider beside its results, lyrics, and additional information.

LRCLIB can return HTTP 503 when overloaded. Lyrx retries a read once when a 429 or 503 response asks for a wait of at most two seconds. Longer waits and persistent failures are reported without repeated requests. Keeping lyrics.ovh enabled provides another lookup option; a retry cannot resolve a sustained service outage.

Requests happen on search submission, result selection, artist/album navigation, or opening Additional Info. Configured, enabled providers receive search terms or recording identifiers and the network IP address; lrc.red also receives the configured email. lyrics.ovh obtains suggestions from Deezer and may query other lyric services, including LRCLIB, internally; its switch controls Lyrx's direct use of that service. The app uses ephemeral networking, stores only preferences, and includes no analytics, local search history, on-disk lyric cache, account, or cloud sync. Provider-side retention is governed by each service. See [provider research](Documentation/Providers.md).

Lyrics remain the property of their rights holders. The app's GPL license applies to its code, not lyric content. Public API access does not grant redistribution rights to lyrics. Provider availability, accuracy, licensing, and service terms can change.

## Build and run

Use **Xcode 26.6 or later**, with the macOS/iOS SDKs installed. CI explicitly selects Xcode 26.6; development with newer Xcode versions is supported. Keep the project in its existing compatible file format (object version 77), even when saving it with newer Xcode. Swift 6 language mode and complete concurrency checking remain enabled. Deployment targets are **macOS 26** and **iOS/iPadOS 26**. The app is SwiftUI with AppKit and UIKit text controls, and has no third-party runtime dependencies.

1. Open `Lyrx.xcodeproj`.
2. Select the shared **Lyrx** scheme.
3. Choose **My Mac** or an iPhone/iPad simulator and Run.

Personal signing details are deliberately absent. For physical devices or distribution, copy `Configuration/Local.xcconfig.example` to `Configuration/Local.xcconfig`, then enter your team ID and your own unique bundle identifier there. This local file is ignored by Git. Avoid saving your team directly in the project editor; Xcode can otherwise write it into the shared project.

The public bundle identifier is `org.lyrx.app`. The Mac target uses App Sandbox with outgoing network access; Xcode generates the corresponding entitlements from build settings. No push notifications, iCloud, file access, or unrelated capabilities are required. The privacy manifest declares local preference use of UserDefaults and the contact email and searches sent for app functionality. It declares no tracking.

For an unsigned build without an account:

```sh
xcodebuild -project Lyrx.xcodeproj -scheme Lyrx \
  -destination 'platform=macOS' -derivedDataPath /tmp/lyrx-mac \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Lyrx.xcodeproj -scheme Lyrx \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/lyrx-ios \
  CODE_SIGNING_ALLOWED=NO build
```

For local Mac runtime testing with the sandbox, use `CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=` instead of `CODE_SIGNING_ALLOWED=NO`. Distribution requires your own signing and notarization or provisioning workflow. No App Store submission or release automation is configured.

## Verification

```sh
Scripts/verify.sh
```

This runs repository privacy checks, deterministic Swift Testing tests, and both platform builds. Set `LYRX_BUILD_ROOT` to override its temporary output directory. Core tests are also runnable independently:

```sh
swift test --scratch-path /tmp/lyrx-tests
```

The standalone `Package.swift` builds the same core files used by the application. Tests cover hard limits, word preservation, Unicode ranges, LRC parsing, ranking, enabled providers, decoding, failures, cancellation, stale responses, settings recovery, metadata-cache lifetime, and deferred focus requests. Cancellation tests await replaced operations, including late failures. Fixtures contain original example text, not song lyrics. Routine CI runs these checks and builds without starting UI automation; a newer push cancels an obsolete Verify run.

For UI changes, run the smallest relevant check. The default is a single Mac search-and-reading smoke test:

```sh
Scripts/test-ui.sh
Scripts/test-ui.sh macOS focus
Scripts/test-ui.sh iOS large-text
```

Available scopes are `smoke` (either platform), `focus` (Mac table navigation), `reader-focus` (Mac search and Command–L), `details` (Additional Info and album navigation on either platform), `settings` and `large-text` (iOS), and `all` (the selected platform). Use `Scripts/test-ui.sh iOS all` for the full iPhone suite. Broader coverage belongs before releases or when a shared interface change warrants it, rather than after every edit.

The runner reuses `Scripts/verify.sh` build directories, prefers an already booted compatible iPhone simulator, and disables parallel simulator clones. `LYRX_BUILD_ROOT` changes the shared build root; `LYRX_UI_BUILD_ROOT` overrides just the UI output directory. `LYRX_UI_DESTINATION` selects a specific destination on the requested platform, including an iPad simulator. Tests have a 60-second timeout because [XCTest rounds allowances up to whole minutes](https://developer.apple.com/documentation/xctest/xctestcase/executiontimeallowance); build and boot time are separate. The warm smoke-test target is under 15 seconds of test execution, with other focused tests under 30 seconds.

The **UI checks** GitHub Actions workflow is manual: choose a platform and scope. It has a five-minute job limit for focused checks and eight minutes for a full platform suite. The shared Xcode scheme also supports selecting individual tests in the Test navigator. UI tests use a Debug-only fixture service and isolated preferences; Release builds do not contain that test mode. Successful runs do not add custom screenshot attachments; failures retain XCTest diagnostics.

See [accessibility verification](Documentation/Accessibility.md) for the hardware and manual checklist. Automated tests and accessibility-tree inspection do not establish compatibility with a particular braille display or translation table. Physical braille validation remains necessary before a public release.

## Contributing and license

Read [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md). Lyrx is licensed under [GNU GPL version 3](LICENSE), SPDX identifier `GPL-3.0-only`.
