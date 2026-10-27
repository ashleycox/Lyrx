# Lyrx contributor guidance

## Purpose

Lyrx is a native macOS, iPhone, and iPad lyric finder designed first for people reading with VoiceOver and single-line braille displays. The main path is search, automatic best-match selection, and focus in a selectable plain-text lyric reader. Preserve this path in every change.

## Implementation

- Use Swift 6 language mode with complete strict concurrency checking. Keep UI state on the main actor, use Sendable values at concurrency boundaries, and prefer structured child tasks. Cancel superseded searches and reject stale responses.
- Follow current Apple API and Human Interface Guidelines. Prefer SwiftUI and system components; use AppKit or UIKit text views where native selection, accessibility, and braille navigation need them.
- Keep domain logic, provider networking, formatting, and platform UI separate. Document public types, non-obvious behavior, concurrency boundaries, and accessibility decisions without narrating obvious statements.
- Use HTTPS, bounded requests, typed decoding, actionable errors, and cancellation. Do not scrape websites, embed secrets, silently contact disabled providers, or log search terms or lyric text.
- Search only enabled providers. Persist provider preferences and enforce at least one enabled provider in the model as well as the interface. Preserve source attribution and describe API limitations honestly.
- Do not commit copyrighted lyric fixtures. Tests and previews use original example text. Lyrics remain in memory unless a later feature explicitly changes the privacy policy.

## Accessibility and formatting

- Use actual newline characters and native selectable text. Preserve stanza breaks. Never split a word or Unicode grapheme. A finite line width is a hard limit including spaces and punctuation: move a whole word to the next line if it will not fit. If a word alone exceeds the limit, pause formatting and ask the user to increase the width or choose Unlimited.
- Default to a hard 40-character limit and whole-word wrapping. Provide Unlimited for display panning. Formatting choices must never silently remove lyric words or punctuation. Braille translation and its relationship to text characters belong to the operating system.
- On successful search, focus the lyric reader at the first line. Provide next, previous, first, and last line actions and accessible current-line status. Do not steal focus on ordinary redraws.
- Every action must be keyboard reachable on macOS. Add discoverable menu commands and shortcuts for primary actions, filters, match selection, and settings. Use native keyboard interaction inside controls.
- Support VoiceOver, Full Keyboard Access, Dynamic Type, Zoom, light and dark appearance, increased contrast, and Reduce Motion. Do not use color alone or clip large text.
- Verify text selection and focus with platform accessibility tools. Record real-device braille checks as manual unless actually performed; simulator results cannot prove hardware compatibility.

## Project and signing

- Maintain a shared Xcode scheme for macOS and iOS and deterministic tests. Keep deployment targets and toolchain requirements documented.
- Commit no development team, personal bundle identifier, provisioning profile, certificate, signing key, device identifier, or user-specific Xcode state. Use ignored local configuration for personal signing; check the staged diff before committing.
- Keep sandbox permissions minimal: outgoing network access on macOS, no unrelated file, microphone, location, or cloud capabilities. Do not weaken App Transport Security.
- Keep dependencies to Apple frameworks unless a justified addition is agreed. Include required privacy declarations and maintain build instructions and contribution guidance.

## Verification and Git

- Before changes, inspect the working tree and fetch the authorized remote. This is the owner's project: continue on the default branch unless a task branch is requested or already active. Preserve unrelated work.
- Make coherent commits with descriptive titles and no tool branding or attribution. Verify the actual remote destination before pushing completed work. Do not open pull requests unless explicitly requested.
- Test formatting, ranking, provider invariants, decoding, failure isolation, and cancellation with deterministic fixtures. Build both macOS and iOS. Run accessibility and keyboard checks appropriate to the change and report limitations.
- Maintain README.md, CONTRIBUTING.md, provider research, and manual accessibility checks as behavior changes. The project uses GPL v3; preserve its license and notices.
