# Lyrx

A native lyric finder for macOS, iPhone, and iPad, designed for reading with VoiceOver and single-line braille displays.

Search by song title, artist, or both. Lyrx searches your enabled services, ranks the matches, loads the best available lyric, and moves focus into a native, selectable text control. The reader uses real line breaks, without webpage navigation or advertising.

## Reading

On Mac, press **Command–F**, enter your search, and press **Return**. Use the Lyrics menu or **Command–Option–Up/Down Arrow** to move between formatted lines. **Command–L** focuses the lyrics again. On iPhone and iPad, use Search, the Previous Line and Next Line buttons, or the reader's VoiceOver actions. Standard VoiceOver text navigation and braille panning remain available.

- The default **40-character hard limit** counts letters, spaces, and punctuation. A word that does not fit moves intact to the next line.
- A word longer than the entire limit pauses formatting with an explanation. Increase the limit or choose **Unlimited**; words are never truncated or split.
- Unlimited preserves longer lines for horizontal and braille panning. Original line breaks remain; optional splitting after commas, sentence punctuation, or other punctuation happens at whitespace-separated word boundaries. Apostrophes and hyphens inside words remain intact.
- Blank lines between stanzas are preserved by default. One-line mode exposes just the current line in the text control.
- Font and text-size settings apply to the reader. iPhone and iPad also support Dynamic Type. The interface uses semantic colors and standard platform controls.

Text width counts Unicode extended grapheme clusters, not translated braille cells. Contractions, capital indicators, and other translation choices can change the cell count. Set the width to suit your display and translation table. This app does not implement a braille driver or change system braille settings.

Show Filters to narrow results by artist, title, or album. Other Matches is collapsible; selecting a result replaces the current lyric. Songwriter filtering is not offered because these APIs do not reliably supply songwriter metadata. Automatic loading tries at most five vocal candidates; all returned matches remain available for manual selection. Instrumentals can be selected explicitly.

## Services and privacy

[LRCLIB](https://lrclib.net/docs) is enabled by default. [lyrics.ovh](https://github.com/NTag/lyrics.ovh) is optional. Both public APIs work without an embedded API key. Settings always keeps at least one service enabled. Service errors are shown separately, so a failed provider does not discard successful results from another.

Searches happen only on submission. Enabled providers receive search terms and the network IP address. lyrics.ovh obtains suggestions from Deezer and may query other lyric services, including LRCLIB, internally; its switch controls Lyrx's direct use of that service. The app uses ephemeral networking, stores only preferences, and includes no analytics, search history, on-disk lyric cache, account, or cloud sync. See [provider research](Documentation/Providers.md).

Lyrics remain the property of their rights holders. The app's GPL license applies to its code, not lyric content. Public API access does not grant redistribution rights to lyrics. Provider availability, accuracy, licensing, and service terms can change.

## Build and run

Use **Xcode 26.6 or later**, with the macOS/iOS SDKs installed. CI explicitly selects Xcode 26.6; development with newer Xcode versions is supported. Keep the project in its existing compatible file format (object version 77), even when saving it with newer Xcode. Swift 6 language mode and complete concurrency checking remain enabled. Deployment targets are **macOS 26** and **iOS/iPadOS 26**. The app is SwiftUI with AppKit and UIKit text controls, and has no third-party runtime dependencies.

1. Open `Lyrx.xcodeproj`.
2. Select the shared **Lyrx** scheme.
3. Choose **My Mac** or an iPhone/iPad simulator and Run.

Personal signing details are deliberately absent. For physical devices or distribution, copy `Configuration/Local.xcconfig.example` to `Configuration/Local.xcconfig`, then enter your team ID and your own unique bundle identifier there. This local file is ignored by Git. Avoid saving your team directly in the project editor; Xcode can otherwise write it into the shared project.

The public bundle identifier is `org.lyrx.app`. The Mac target uses App Sandbox with outgoing network access; Xcode generates the corresponding entitlements from build settings. No push notifications, iCloud, file access, or unrelated capabilities are required. The privacy manifest declares local preference use of UserDefaults.

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

The standalone `Package.swift` builds the same core files used by the application. Tests cover hard limits, word preservation, Unicode ranges, LRC parsing, ranking, enabled providers, decoding, failures, cancellation, stale responses, and settings recovery. Fixtures contain original example text, not song lyrics. The shared app scheme also contains UI tests. Select an iPhone or iPad simulator and choose Product → Test, or run:

```sh
xcodebuild -project Lyrx.xcodeproj -scheme Lyrx \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath /tmp/lyrx-ui-tests CODE_SIGNING_ALLOWED=NO test
```

Replace the simulator name with one installed on your Mac, or run `Scripts/test-ui.sh` to select an available iPhone automatically. Set `LYRX_UI_DESTINATION` to test another simulator. The CI workflow runs this interface suite after core checks and platform builds. UI tests use a Debug-only fixture service and an isolated preference suite; Release builds do not contain that test mode. Core tests are available through the Swift package.

See [accessibility verification](Documentation/Accessibility.md) for the hardware and manual checklist. Automated tests and accessibility-tree inspection do not establish compatibility with a particular braille display or translation table. Physical braille validation remains necessary before a public release.

## Contributing and license

Read [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md). Lyrx is licensed under [GNU GPL version 3](LICENSE), SPDX identifier `GPL-3.0-only`.
