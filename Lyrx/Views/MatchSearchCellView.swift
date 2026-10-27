#if os(macOS)
    import AppKit

    /// A real button keeps linked table cells usable with keyboard navigation and VoiceOver.
    final class MatchSearchCellView: NSTableCellView {
        let button = NSButton(title: "", target: nil, action: nil)

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            button.isBordered = false
            button.alignment = .left
            button.font = .preferredFont(forTextStyle: .body)
            button.contentTintColor = .linkColor
            button.lineBreakMode = .byTruncatingTail
            button.translatesAutoresizingMaskIntoConstraints = false
            addSubview(button)
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
                button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
                button.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
        }

        required init?(coder: NSCoder) { nil }
    }
#endif
