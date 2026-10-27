# Contributing to Lyrx

Lyrx's priority is reliable lyric reading with VoiceOver and a single-line braille display. Changes should preserve the direct search-to-reader workflow and the native behavior of each platform.

## Development

Use Xcode 26.6 or later and Swift 6 strict concurrency. Keep the project file at object version 77 so the CI toolchain can open it; newer Xcode versions must not automatically upgrade that format. Open `Lyrx.xcodeproj`, select the shared Lyrx scheme, and choose a Mac or iOS simulator. See the README for command-line builds and local signing. Use descriptive topic branches for contributions and keep changes focused.

- Put provider adapters, formatting, ranking, and state logic in `Lyrx/Core`; native text bridges belong in `Lyrx/Reader`, and interface components in `Lyrx/Views`.
- Keep UI state on the main actor. Pass Sendable values between tasks. Cancel superseded work and check request identity after suspension. Do not silence isolation errors with unchecked conformances.
- Comment the reason behind accessibility behavior, API boundaries, unusual formatting, and concurrency decisions. Prefer small types with clear responsibilities.
- Preserve native text selection and accessibility APIs. A multiline label or HTML view is not a substitute for the reader.
- Keep hard line limits, including spaces and punctuation. Never split a word or grapheme. An oversized word must produce an actionable formatting error; Unlimited is an explicit choice.
- Keep help and settings specific to the platform being used. Mac users must not see touch-platform instructions.
- Use semantic colors, Dynamic Type where supported, native controls, and keyboard access. Test large text and small windows. Avoid animation that interferes with reading focus.
- Do not add a dependency, service, data collection, persistent lyric storage, or permission without discussing its purpose and implications first.

## Providers

Use documented public HTTPS APIs, not webpage scraping. Record endpoint contracts and limitations in `Documentation/Providers.md`. Every provider must be selectable, and at least one must stay enabled. Check cancellation, timeouts, response bounds, empty results, invalid JSON, and partial failures. Never embed API credentials. Keep attribution visible and do not represent API availability as permission to redistribute lyric content.

## Tests and review

Run `Scripts/verify.sh`. Add meaningful tests for behavioral changes using Swift Testing and original fixture text. Do not make routine tests depend on public service availability. Build both macOS and iOS after changes to shared code. Use `Documentation/Accessibility.md` for manual checks; state the actual platform, assistive technology, and display tested.

Pull requests should explain the problem, the resulting behavior, why the approach was chosen, verification commands and results, and any untested behavior. Include screenshots for visual changes where useful, without copyrighted lyrics or personal information. Keep commits short and descriptive. Preserve any required human sign-offs; do not add tool attribution.

## Signing and repository privacy

Copy `Configuration/Local.xcconfig.example` to ignored `Configuration/Local.xcconfig` for your own team and bundle identifier. Do not commit certificates, provisioning profiles, device identifiers, private keys, personal team IDs, Xcode user data, or absolute paths to your home directory. Do not change the shared bundle-identifier expression to your personal identifier.

Run `python3 Scripts/check-repository.py --staged` after staging changes and inspect `git diff --cached`. The check supplements review; it is not a general secret scanner. The initial project history may contain earlier signing metadata; do not rewrite shared history as part of an ordinary contribution.

## License

Contributions are made under GPL-3.0-only, the project's existing license. Keep copyright and license notices intact. Lyrics supplied by services are not part of the software license and must not be added as fixtures or bundled content.
