#if os(macOS)
    import AppKit
    import SwiftUI

    /// NSTableView preserves its rows and first responder while the selected lyric changes.
    struct MacMatchesTable: NSViewRepresentable {
        let model: ReaderModel
        let settings: AppSettings

        func makeCoordinator() -> Coordinator { Coordinator(model: model, settings: settings) }

        func makeNSView(context: Context) -> NSScrollView {
            let scroll = NSScrollView()
            scroll.hasVerticalScroller = true
            scroll.hasHorizontalScroller = true
            scroll.autohidesScrollers = true
            scroll.borderType = .bezelBorder
            let table = ResultsTableView()
            table.style = .inset
            table.usesAlternatingRowBackgroundColors = true
            table.allowsMultipleSelection = false
            table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
            table.rowHeight = 24
            for title in ["Title", "Artist", "Album", "Provider"] {
                let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(title))
                column.title = title
                column.minWidth = 80
                column.width = title == "Provider" ? 96 : 160
                table.addTableColumn(column)
            }
            table.setAccessibilityLabel("Other matches")
            table.setAccessibilityIdentifier("matchesTable")
            table.setAccessibilityHelp(
                "Select a row to update the lyrics. Press Return to read the selected match.")
            table.dataSource = context.coordinator
            table.delegate = context.coordinator
            table.target = context.coordinator
            table.doubleAction = #selector(Coordinator.readSelected)
            table.readSelection = { [weak coordinator = context.coordinator] in coordinator?.readSelected() }
            let menu = NSMenu()
            menu.autoenablesItems = false
            let item = NSMenuItem(title: "Read Lyrics", action: #selector(Coordinator.readFromMenu), keyEquivalent: "")
            item.target = context.coordinator
            menu.addItem(item)
            menu.delegate = context.coordinator
            table.menu = menu
            context.coordinator.table = table
            scroll.documentView = table
            return scroll
        }

        func updateNSView(_ scroll: NSScrollView, context: Context) {
            guard let table = scroll.documentView as? ResultsTableView else { return }
            let coordinator = context.coordinator
            coordinator.model = model
            coordinator.settings = settings
            coordinator.updating = true
            defer { coordinator.updating = false }
            let changed = coordinator.matches != model.matches
            if changed {
                coordinator.matches = model.matches
                table.reloadData()
            }
            // Updating the reader must not reload rows or undo a newer, still-loading selection.
            if changed || coordinator.lastLoadedID != model.selected?.id {
                coordinator.lastLoadedID = model.selected?.id
                if let index = coordinator.matches.firstIndex(where: { $0.id == model.selected?.id }) {
                    table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                } else {
                    table.deselectAll(nil)
                }
            }
            if let requestID = model.pendingMatchesFocusID, coordinator.lastFocusID != requestID {
                coordinator.lastFocusID = requestID
                coordinator.focusTask?.cancel()
                coordinator.focusTask = Task { @MainActor [weak table] in
                    await Task.yield()
                    guard !Task.isCancelled, let table, let window = table.window,
                        model.consumeMatchesFocus(requestID)
                    else { return }
                    window.makeFirstResponder(table)
                    if table.selectedRow >= 0 { table.scrollRowToVisible(table.selectedRow) }
                    NSAccessibility.post(element: table, notification: .focusedUIElementChanged)
                }
            }
        }

        static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
            coordinator.focusTask?.cancel()
            guard let table = scroll.documentView as? ResultsTableView else { return }
            table.delegate = nil
            table.dataSource = nil
            table.menu?.delegate = nil
            table.readSelection = nil
        }

        @MainActor final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
            var model: ReaderModel
            var settings: AppSettings
            var matches: [LyricMatch] = []
            var lastLoadedID: LyricMatch.ID?
            var updating = false
            var lastFocusID: UUID?
            var focusTask: Task<Void, Never>?
            weak var table: ResultsTableView?

            init(model: ReaderModel, settings: AppSettings) {
                self.model = model
                self.settings = settings
            }

            func numberOfRows(in tableView: NSTableView) -> Int { matches.count }

            func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
                guard matches.indices.contains(row), let column = tableColumn else { return nil }
                let match = matches[row]
                let value: String
                switch column.identifier.rawValue {
                case "Title": value = match.title
                case "Artist": value = match.artist
                case "Album": value = match.album
                default: value = match.provider.name
                }
                let cell: NSTableCellView
                if let reused = tableView.makeView(withIdentifier: column.identifier, owner: self) as? NSTableCellView {
                    cell = reused
                } else {
                    cell = NSTableCellView()
                    cell.identifier = column.identifier
                    let label = NSTextField(labelWithString: "")
                    label.font = .preferredFont(forTextStyle: .body)
                    label.lineBreakMode = .byTruncatingTail
                    label.translatesAutoresizingMaskIntoConstraints = false
                    cell.addSubview(label)
                    cell.textField = label
                    NSLayoutConstraint.activate([
                        label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                        label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                        label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    ])
                }
                cell.textField?.stringValue = value
                cell.textField?.setAccessibilityIdentifier("match-\(match.id)-\(column.identifier.rawValue)")
                cell.toolTip = value
                return cell
            }

            func tableViewSelectionDidChange(_ notification: Notification) {
                guard !updating, let table, matches.indices.contains(table.selectedRow) else { return }
                let match = matches[table.selectedRow]
                if match.id != model.selected?.id || model.isSearching {
                    model.select(match, settings: settings, focusOnLoad: false)
                }
            }

            @objc func readSelected() {
                guard let table else { return }
                read(row: table.selectedRow)
            }

            @objc func readFromMenu() {
                readSelected()
            }

            func menuNeedsUpdate(_ menu: NSMenu) {
                guard let table else { return }
                menu.items.first?.isEnabled = matches.indices.contains(table.selectedRow)
            }

            private func read(row: Int) {
                guard matches.indices.contains(row) else { return }
                let match = matches[row]
                if model.selected?.id == match.id, model.hasLyrics, !model.isSearching {
                    model.focusReader()
                } else {
                    model.select(match, settings: settings)
                }
            }
        }
    }

    /// All navigation remains AppKit's; only Return and keypad Enter open the selected lyric.
    final class ResultsTableView: NSTableView {
        var readSelection: (() -> Void)?

        override func menu(for event: NSEvent) -> NSMenu? {
            let clicked = row(at: convert(event.locationInWindow, from: nil))
            if clicked >= 0 { selectRowIndexes(IndexSet(integer: clicked), byExtendingSelection: false) }
            return super.menu(for: event)
        }

        override func keyDown(with event: NSEvent) {
            if event.charactersIgnoringModifiers == "\r" || event.charactersIgnoringModifiers == "\u{3}" {
                readSelection?()
            } else {
                super.keyDown(with: event)
            }
        }
    }
#endif
