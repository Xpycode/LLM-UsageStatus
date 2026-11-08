import AppKit
import SwiftUI

@main
struct LLMUsageStatusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        // Settings is the app's own AppKit window (SettingsWindowController); dropping the
        // automatic Settings… item keeps SwiftUI from claiming Command-Comma.
        Settings { EmptyView() }
            .commands { CommandGroup(replacing: .appSettings) {} }
    }
}
