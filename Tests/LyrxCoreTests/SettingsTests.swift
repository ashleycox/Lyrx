import Foundation
import Testing
@testable import LyrxCore

@MainActor struct SettingsTests {
    @Test func lastProviderCannotBeDisabledAndPreferencesPersist() throws {
        let name = "LyrxTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
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
}
