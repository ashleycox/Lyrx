import Foundation
import Testing

@testable import LyrxCore

@MainActor struct SettingsTests {
    @Test func lastProviderCannotBeDisabledAndPreferencesPersist() throws {
        let name = "LyrxTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        #expect(!settings.showLineControls)
        settings.showLineControls = true
        #expect(AppSettings(defaults: defaults).showLineControls)
        settings.showLineControls = false
        #expect(!AppSettings(defaults: defaults).showLineControls)
        #expect(settings.enabledProviders == [.lrclib])
        #expect(!settings.setEnabled(false, provider: .lrclib))
        #expect(settings.setEnabled(true, provider: .lyricsOVH))
        #expect(settings.setEnabled(false, provider: .lrclib))
        #expect(!settings.setEnabled(false, provider: .lyricsOVH))
        #expect(AppSettings(defaults: defaults).enabledProviders == [.lyricsOVH])
        settings.lineWidth = 0
        #expect(AppSettings(defaults: defaults).formatting.lineLimit == nil)
    }
    @Test func corruptedPreferencesRecoverSafeDefaults() throws {
        let name = "LyrxTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(["unknown"], forKey: "providers")
        defaults.set(-500, forKey: "lineWidth")
        defaults.set(1000, forKey: "textScale")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.enabledProviders == [.lrclib])
        #expect(settings.lineWidth == 40)
        #expect(settings.textScale == 3)
    }

    @Test func unconfiguredLrcRedCannotReplaceTheLastUsableProvider() throws {
        let name = "LyrxTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        settings.setEnabled(true, provider: .lrcRed)
        #expect(settings.enabledProviders.contains(.lrcRed))
        #expect(settings.providerAccess.searchable == [.lrclib])
        #expect(!settings.setEnabled(false, provider: .lrclib))
        settings.lrcRedEmail = "reader@example.invalid"
        #expect(settings.setEnabled(false, provider: .lrclib))
        #expect(AppSettings(defaults: defaults).providerAccess.contactEmail == "reader@example.invalid")
        settings.lrcRedEmail = ""
        #expect(settings.enabledProviders == [.lrcRed])
        #expect(settings.providerAccess.searchable.isEmpty)
        #expect(!settings.setEnabled(false, provider: .lrcRed))
    }
}
