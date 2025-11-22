import SwiftUI

struct SettingsView: View {
    // Access bulb data store
    @ObservedObject var store: BulbStore
    
    @State private var isScanning: Bool = false
    @State private var scanStatus: String = ""

    var body: some View {
           
        Form {
            // NEW: Auto-Discovery Section
            Section {
                HStack {
                    Button(action: runDiscovery) {
                        HStack {
                            Image(systemName: "network")
                            Text(isScanning ? "Scanning..." : "Auto-Detect Bulbs")
                        }
                    }
                    .disabled(isScanning)
                    
                    if !scanStatus.isEmpty {
                        Spacer()
                        Text(scanStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // MARK: - Dynamic Bulb List
            Section(header: Text("My Bulbs")) {
                List {
                    ForEach($store.bulbs) { $bulb in
                        HStack {
                            TextField("Name", text: $bulb.name)
                                .frame(width: 100)
                            
                            Divider()
                            
                            TextField("IP Address (e.g. 192.168.1.50)", text: $bulb.ip)
                            
                            Divider()
                            
                            // NEW: Visual Delete Button
                            Button(action: {
                                if let index = store.bulbs.firstIndex(where: { $0.id == bulb.id }) {
                                    store.deleteBulb(at: IndexSet(integer: index))
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain) // Prevents the whole row from flashing
                        }
                    }
                    // Keep onDelete for swipe capability too
                    .onDelete(perform: store.deleteBulb)
                }
                .frame(minHeight: 150) // Give the list some space
                
                Button("Add Manually") {
                    store.addBulb()
                }
            }

            Section {
                HStack{
                    Button("Quit Application") {
                        NSApplication.shared.terminate(nil)
                    }
                    Section() {
                        Text(getAppVersionAndBuild())
                            .overlay(alignment: .bottomTrailing){}
                    }
                    .frame(maxWidth: .infinity)
                }
                
            }
        }
        .padding()
        .frame(width: 400, height: 400) // Increased height for new button
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    // MARK: - Logic
    
    func getAppVersionAndBuild() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

        if let version = version, let build = build {
            return "Version: \(version) (\(build))"
        } else {
            return "Version information not available"
        }
    }
    func runDiscovery() {
        isScanning = true
        scanStatus = "Searching..."
        
        Task {
            let foundIPs = await LightController.discoverBulbs()
            
            await MainActor.run {
                isScanning = false
                
                if foundIPs.isEmpty {
                    scanStatus = "No bulbs found."
                    return
                }
                
                var addedCount = 0
                
                // Check every IP found
                for ip in foundIPs {
                    // If we don't already have this IP in our list, add it
                    if !store.bulbs.contains(where: { $0.ip == ip }) {
                        store.addBulb(name: "WiZ \(ip.split(separator: ".").last ?? "?")", ip: ip)
                        addedCount += 1
                    }
                }
                
                if addedCount > 0 {
                    scanStatus = "Added \(addedCount) new bulb(s)!"
                } else {
                    scanStatus = "Bulbs found, but already in list."
                }
            }
        }
    }
}
