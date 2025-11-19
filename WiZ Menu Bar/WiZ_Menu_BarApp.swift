import SwiftUI

@main
struct WiZMenuApp: App {
    // This adaptor helps hide the app from the dock
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("WiZ Control", systemImage: "lightbulb.fill") {
            ContentView()
        }
        .menuBarExtraStyle(.window) // Allows interactive sliders
        
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keeps the app as a menu bar accessory (no dock icon)
        NSApp.setActivationPolicy(.accessory)
    }
}
