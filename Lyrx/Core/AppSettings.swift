import Foundation
import Observation

/// Local preferences only. All provider mutations enforce the last-provider invariant.
@MainActor @Observable
final class AppSettings {
    private let defaults: UserDefaults
    private(set) var enabledProviders: Set<LyricProviderID>
    var lineWidth: Int { didSet { defaults.set(lineWidth, forKey: "lineWidth") } }
    var punctuation: PunctuationBreak { didSet { defaults.set(punctuation.rawValue, forKey: "punctuation") } }
    var preserveBlankLines: Bool { didSet { defaults.set(preserveBlankLines, forKey: "preserveBlankLines") } }
    var monospaced: Bool { didSet { defaults.set(monospaced, forKey: "monospaced") } }
    var textScale: Double { didSet { defaults.set(textScale, forKey: "textScale") } }
    var singleLine: Bool { didSet { defaults.set(singleLine, forKey: "singleLine") } }
    /// Optional visual reading aids; VoiceOver and braille use the native text independently.
    var showLineControls: Bool { didSet { defaults.set(showLineControls, forKey: "showLineControls") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.stringArray(forKey: "providers")?.compactMap(LyricProviderID.init(rawValue:)) ?? [.lrclib]
        enabledProviders = saved.isEmpty ? [.lrclib] : Set(saved)
        let width = defaults.object(forKey: "lineWidth") as? Int ?? 40
        lineWidth = (0...500).contains(width) ? width : 40
        punctuation = PunctuationBreak(rawValue: defaults.string(forKey: "punctuation") ?? "") ?? .original
        preserveBlankLines = defaults.object(forKey: "preserveBlankLines") as? Bool ?? true
        monospaced = defaults.object(forKey: "monospaced") as? Bool ?? false
        let scale = defaults.object(forKey: "textScale") as? Double ?? 1
        textScale = scale.isFinite ? min(max(scale, 1), 3) : 1
        singleLine = defaults.bool(forKey: "singleLine")
        showLineControls = defaults.bool(forKey: "showLineControls")
    }

    var formatting: FormattingOptions {
        FormattingOptions(
            lineLimit: lineWidth == 0 ? nil : max(1, lineWidth),
            punctuation: punctuation, preserveBlankLines: preserveBlankLines)
    }

    @discardableResult
    func setEnabled(_ enabled: Bool, provider: LyricProviderID) -> Bool {
        if enabled {
            enabledProviders.insert(provider)
        } else {
            guard enabledProviders.count > 1 || !enabledProviders.contains(provider) else { return false }
            enabledProviders.remove(provider)
        }
        defaults.set(enabledProviders.map(\.rawValue).sorted(), forKey: "providers")
        return true
    }
}
