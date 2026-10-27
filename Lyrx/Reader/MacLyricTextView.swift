#if os(macOS)
    import AppKit

    /// A focus request may arrive before SwiftUI attaches the reader to a window.
    final class MacLyricTextView: NSTextView {
        var didAttachToWindow: (() -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil { didAttachToWindow?() }
        }
    }
#endif
