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
            // --- CHANGED "My Bulbs" SECTION START ---
            Section(header: Text("My Bulbs")) {
                List {
                    // CHANGED LOOP: Using indices to get a Binding to the mutable structure
                    ForEach($store.bulbs.indices, id: \.self) { index in
                        let binding = $store.bulbs[index]
                        
                        VStack(alignment: .leading) {
                            HStack {
                                TextField("Name", text: binding.name)
                                    .frame(width: 100)
                                Divider()
                                TextField("IP", text: binding.ip)
                                Divider()
                                Button(action: {
                                    store.deleteBulb(at: IndexSet(integer: index))
                                }) {
                                    Image(systemName: "trash").foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // NEW: Widget Toggle
                            Toggle("Show in Widget", isOn: binding.showInWidget)
                                .font(.caption)
                                .padding(.leading, 4)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(minHeight: 150)
                
                Button("Add Manually") {
                    store.addBulb()
                }
            }
            // --- CHANGED "My Bulbs" SECTION END ---

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
