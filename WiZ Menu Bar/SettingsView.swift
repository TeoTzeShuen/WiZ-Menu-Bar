import SwiftUI

struct SettingsView: View {
    // Bulb 1 Data
    @AppStorage("bulb1_ip") private var bulb1IP: String = ""
    @AppStorage("bulb1_name") private var bulb1Name: String = "Bulb 1"
    
    // Bulb 2 Data
    @AppStorage("bulb2_ip") private var bulb2IP: String = ""
    @AppStorage("bulb2_name") private var bulb2Name: String = "Bulb 2"

    var body: some View {
        Form {
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
        .frame(width: 350, height: 300) // Increased height for new fields
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
