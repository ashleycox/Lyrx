import SwiftUI

/// Preferences are shared; each window owns its search and reading position.
@main
struct LyrxApp: App {
    @State private var settings = AppSettings()

    init() {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
                let defaults = UserDefaults(suiteName: "Lyrx.UITests")
            {
                // UI tests never modify the user's actual preferences or contact a lyric service.
                defaults.removePersistentDomain(forName: "Lyrx.UITests")
                _settings = State(initialValue: AppSettings(defaults: defaults))
            }
        #endif
    }
    var body: some Scene {
        WindowGroup { ContentView().environment(settings) }
            .defaultSize(width: 820, height: 720)
            .commands { LyrxCommands(settings: settings) }
        #if os(macOS)
            Settings {
                SettingsView().environment(settings)
                    .frame(minWidth: 520, minHeight: 620)
            }
        #endif
    }
}
