import SwiftUI

#if os(macOS)
    import AppKit

    /// NSTextView exposes real text ranges and standard VoiceOver/braille text navigation.
    struct NativeLyricReader: NSViewRepresentable {
        let model: ReaderModel
        let settings: AppSettings

        func makeCoordinator() -> Coordinator { Coordinator(model: model) }
        func makeNSView(context: Context) -> NSScrollView {
            let scroll = NSScrollView()
            scroll.hasVerticalScroller = true
            scroll.hasHorizontalScroller = true
            scroll.autohidesScrollers = true
            scroll.borderType = .noBorder
            let text = MacLyricTextView()
            text.isEditable = false
            text.isSelectable = true
            text.isRichText = false
            text.isAutomaticLinkDetectionEnabled = false
            text.isHorizontallyResizable = true
            text.isVerticallyResizable = true
            text.autoresizingMask = [.width]
            text.minSize = .zero
            text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            text.textContainer?.widthTracksTextView = false
            text.textContainer?.containerSize = text.maxSize
            text.textContainerInset = NSSize(width: 12, height: 12)
            text.delegate = context.coordinator
            text.didAttachToWindow = { [weak text, weak coordinator = context.coordinator] in
                guard let text else { return }
                coordinator?.scheduleFocus(in: text)
            }
            text.setAccessibilityLabel("Lyrics")
            text.setAccessibilityIdentifier("lyricReader")
            text.setAccessibilityHelp(
                "Read-only lyrics. Command–L returns focus here. Use standard text navigation, or Command–Option–Up and Down Arrow to move between formatted lines."
            )
            scroll.documentView = text
            return scroll
        }

        func updateNSView(_ scroll: NSScrollView, context: Context) {
            guard let text = scroll.documentView as? NSTextView else { return }
            let coordinator = context.coordinator
            // SwiftUI may update a representable once more before removing an empty reader.
            guard model.hasLyrics else {
                coordinator.focus.cancel()
                return
            }
            coordinator.model = model
            coordinator.singleLine = settings.singleLine
            coordinator.updating = true
            defer { coordinator.updating = false }
            let content = settings.singleLine ? model.document.lines[model.currentLine] : model.document.text
            let changed = text.string != content
            if changed { text.string = content }
            let size = NSFont.preferredFont(forTextStyle: .body).pointSize * settings.textScale
            text.font =
                settings.monospaced ? .monospacedSystemFont(ofSize: size, weight: .regular) : .systemFont(ofSize: size)
            text.textColor = .textColor
            text.backgroundColor = .textBackgroundColor
            text.setAccessibilityLabel(settings.singleLine ? "Lyrics, \(model.lineStatus)" : "Lyrics")
            let highlight =
                settings.showLineControls
                ? (settings.singleLine
                    ? NSRange(location: 0, length: content.utf16.count)
                    : model.document.ranges[model.currentLine]) : nil
            if changed || coordinator.lastHighlight != highlight {
                coordinator.lastHighlight = highlight
                if let storage = text.textStorage {
                    // Background attributes provide a visual marker without selecting words,
                    // changing plain text, or moving the VoiceOver cursor.
                    storage.beginEditing()
                    storage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: storage.length))
                    if let highlight {
                        storage.addAttribute(
                            .backgroundColor, value: NSColor.selectedTextBackgroundColor.withAlphaComponent(0.25),
                            range: highlight)
                    }
                    storage.endEditing()
                }
            }
            if changed || coordinator.lastSelection != model.selectionID {
                coordinator.lastSelection = model.selectionID
                let offset = settings.singleLine ? 0 : model.document.ranges[model.currentLine].location
                text.setSelectedRange(NSRange(location: offset, length: 0))
                text.scrollRangeToVisible(text.selectedRange())
            }
            coordinator.scheduleFocus(in: text)
        }

        static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
            coordinator.focus.cancel()
            let text = nsView.documentView as? MacLyricTextView
            text?.didAttachToWindow = nil
            text?.delegate = nil
        }

        @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
            var model: ReaderModel
            var lastSelection: UUID?
            var lastHighlight: NSRange?
            var updating = false
            var singleLine = false
            let focus = FocusRequestScheduler()
            init(model: ReaderModel) { self.model = model }

            func scheduleFocus(in text: NSTextView) {
                let requestID = model.pendingReaderFocusID
                focus.schedule(requestID, isAttached: text.window != nil) { [weak self, weak text] in
                    guard let self, let text, let window = text.window, let requestID,
                        self.model.hasLyrics, self.model.pendingReaderFocusID == requestID
                    else { return false }
                    return window.makeFirstResponder(text) && window.firstResponder === text
                } accepted: { [weak self, weak text] in
                    guard let self, let text, let requestID, self.model.consumeReaderFocus(requestID) else { return }
                    text.scrollRangeToVisible(text.selectedRange())
                    NSAccessibility.post(element: text, notification: .focusedUIElementChanged)
                }
            }

            func textViewDidChangeSelection(_ notification: Notification) {
                guard !updating, !singleLine, let text = notification.object as? NSTextView else { return }
                model.caretMoved(toUTF16Offset: text.selectedRange().location)
            }
        }
    }
#else
    import UIKit

    /// A noneditable UITextView keeps the platform's text rotor, selection, and braille routing.
    struct NativeLyricReader: UIViewRepresentable {
        let model: ReaderModel
        let settings: AppSettings
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        func makeCoordinator() -> Coordinator { Coordinator(model: model) }
        func makeUIView(context: Context) -> PanningTextView {
            let text = PanningTextView(usingTextLayoutManager: false)
            text.isEditable = false
            text.isSelectable = true
            text.isScrollEnabled = true
            text.alwaysBounceVertical = true
            text.adjustsFontForContentSizeCategory = true
            text.textContainer.widthTracksTextView = false
            text.textContainer.size = CGSize(width: 100_000, height: CGFloat.greatestFiniteMagnitude)
            text.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            text.delegate = context.coordinator
            text.didAttachToWindow = { [weak text, weak coordinator = context.coordinator] in
                guard let text else { return }
                coordinator?.scheduleFocus(in: text)
            }
            text.accessibilityIdentifier = "lyricReader"
            text.accessibilityHint = "Read-only lyrics. Use text navigation or the Next Line and Previous Line actions."
            text.accessibilityCustomActions = [
                UIAccessibilityCustomAction(
                    name: "Next line", target: context.coordinator, selector: #selector(Coordinator.nextLine)),
                UIAccessibilityCustomAction(
                    name: "Previous line", target: context.coordinator, selector: #selector(Coordinator.previousLine)),
            ]
            return text
        }

        func updateUIView(_ text: PanningTextView, context: Context) {
            let coordinator = context.coordinator
            guard model.hasLyrics else {
                coordinator.focus.cancel()
                return
            }
            coordinator.model = model
            coordinator.singleLine = settings.singleLine
            coordinator.updating = true
            defer { coordinator.updating = false }
            // Observe Dynamic Type so the font is recalculated even when the lyric text has not changed.
            _ = dynamicTypeSize
            let base =
                settings.monospaced
                ? UIFont.monospacedSystemFont(ofSize: 17 * settings.textScale, weight: .regular)
                : UIFont.systemFont(ofSize: 17 * settings.textScale)
            text.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
            text.textColor = .label
            text.backgroundColor = .systemBackground
            let content = settings.singleLine ? model.document.lines[model.currentLine] : model.document.text
            let changed = text.text != content
            if changed { text.text = content }
            text.accessibilityLabel = settings.singleLine ? "Lyrics, \(model.lineStatus)" : "Lyrics"
            let highlight =
                settings.showLineControls
                ? (settings.singleLine
                    ? NSRange(location: 0, length: content.utf16.count)
                    : model.document.ranges[model.currentLine]) : nil
            if changed || coordinator.lastHighlight != highlight {
                coordinator.lastHighlight = highlight
                let storage = text.textStorage
                storage.beginEditing()
                storage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: storage.length))
                if let highlight {
                    storage.addAttribute(.backgroundColor, value: UIColor.tertiarySystemFill, range: highlight)
                }
                storage.endEditing()
            }
            if changed || coordinator.lastSelection != model.selectionID {
                coordinator.lastSelection = model.selectionID
                let offset = settings.singleLine ? 0 : model.document.ranges[model.currentLine].location
                text.selectedRange = NSRange(location: offset, length: 0)
                text.scrollRangeToVisible(text.selectedRange)
            }
            coordinator.scheduleFocus(in: text)
        }

        static func dismantleUIView(_ uiView: PanningTextView, coordinator: Coordinator) {
            coordinator.focus.cancel()
            uiView.didAttachToWindow = nil
            uiView.delegate = nil
        }

        @MainActor final class Coordinator: NSObject, UITextViewDelegate {
            var model: ReaderModel
            var lastSelection: UUID?
            var lastHighlight: NSRange?
            var singleLine = false
            var updating = false
            let focus = FocusRequestScheduler()
            init(model: ReaderModel) { self.model = model }
            func scheduleFocus(in text: UITextView) {
                let requestID = model.pendingReaderFocusID
                focus.schedule(requestID, isAttached: text.window != nil) { [weak self, weak text] in
                    guard let self, let text, text.window != nil, let requestID,
                        self.model.hasLyrics, self.model.pendingReaderFocusID == requestID
                    else { return false }
                    return text.becomeFirstResponder() && text.isFirstResponder
                } accepted: { [weak self, weak text] in
                    guard let self, let text, let requestID, self.model.consumeReaderFocus(requestID) else { return }
                    text.scrollRangeToVisible(text.selectedRange)
                    UIAccessibility.post(notification: .layoutChanged, argument: text)
                }
            }

            func textViewDidChangeSelection(_ textView: UITextView) {
                guard !updating, !singleLine else { return }
                model.caretMoved(toUTF16Offset: textView.selectedRange.location)
            }
            @objc func nextLine() -> Bool {
                guard model.canGoForward else { return false }
                model.go(to: model.currentLine + 1)
                return true
            }
            @objc func previousLine() -> Bool {
                guard model.canGoBack else { return false }
                model.go(to: model.currentLine - 1)
                return true
            }
        }
    }

    /// No visual soft wrapping: a formatted line remains one line, with horizontal touch panning.
    final class PanningTextView: UITextView {
        var didAttachToWindow: (() -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { didAttachToWindow?() }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            // UITextView can reset its container during layout and Dynamic Type changes.
            // Reapply an unbounded width before measuring, so visual lines match literal newlines.
            textContainer.widthTracksTextView = false
            if textContainer.size.width != 100_000 {
                textContainer.size = CGSize(width: 100_000, height: CGFloat.greatestFiniteMagnitude)
            }
            layoutManager.ensureLayout(for: textContainer)
            let used = layoutManager.usedRect(for: textContainer)
            let required = CGSize(
                width: max(bounds.width, used.maxX + textContainerInset.left + textContainerInset.right),
                height: max(bounds.height, used.maxY + textContainerInset.top + textContainerInset.bottom))
            if contentSize != required { contentSize = required }
        }
    }
#endif
