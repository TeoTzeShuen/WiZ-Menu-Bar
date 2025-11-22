import SwiftUI

@main
struct WiZMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Create a SINGLE shared source of truth for the data
    @StateObject var store = BulbStore()

    var body: some Scene {
        MenuBarExtra("WiZ Control", systemImage: "lightbulb.fill") {
            // FIXED: Pass the shared 'store' here so ContentView sees updates immediately
            ContentView(store: store)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView(store: store)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
