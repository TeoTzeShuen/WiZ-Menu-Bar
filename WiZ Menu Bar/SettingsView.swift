import SwiftUI

struct SettingsView: View {
    // Bulb 1 Data
    @AppStorage("bulb1_ip") private var bulb1IP: String = ""
    @AppStorage("bulb1_name") private var bulb1Name: String = "Bulb 1"
    
    // Bulb 2 Data
    @AppStorage("bulb2_ip") private var bulb2IP: String = ""
    @AppStorage("bulb2_name") private var bulb2Name: String = "Bulb 2"
    
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
            
            Section(header: Text("Bulb 1 Settings")) {
                TextField("Name", text: $bulb1Name)
                TextField("IP Address", text: $bulb1IP)
            }
            
            Section(header: Text("Bulb 2 Settings")) {
                TextField("Name", text: $bulb2Name)
                TextField("IP Address", text: $bulb2IP)
            }

            Section {
                Button("Quit Application") {
                    NSApplication.shared.terminate(nil)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .frame(width: 350, height: 350) // Increased height for new button
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    // MARK: - Logic
    func runDiscovery() {
        isScanning = true
        scanStatus = ""
        
        Task {
            let foundIPs = await LightController.discoverBulbs()
            
            await MainActor.run {
                isScanning = false
                
                if foundIPs.isEmpty {
                    scanStatus = "No bulbs found."
                    return
                }
                
                // Auto-fill logic:
                // Fill Bulb 1 if empty
                // Fill Bulb 2 if empty and we found more than 1 bulb
                
                var usedIndex = 0
                
                if bulb1IP.isEmpty && foundIPs.indices.contains(usedIndex) {
                    bulb1IP = foundIPs[usedIndex]
                    usedIndex += 1
                }
                
                if bulb2IP.isEmpty && foundIPs.indices.contains(usedIndex) {
                    bulb2IP = foundIPs[usedIndex]
                    usedIndex += 1
                }
                
                scanStatus = "Found \(foundIPs.count) bulb(s)."
            }
        }
    }
}
