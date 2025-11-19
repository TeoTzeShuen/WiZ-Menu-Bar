import SwiftUI

struct SettingsView: View {
    @AppStorage("bulb1_ip") private var bulb1IP: String = "192.168.1.10"
    @AppStorage("bulb2_ip") private var bulb2IP: String = "192.168.1.11"

    var body: some View {
        Form {
            Section(header: Text("Bulb Configuration")) {
                TextField("Bulb 1 IP Address", text: $bulb1IP)
                TextField("Bulb 2 IP Address", text: $bulb2IP)
            }
            
            Section {
                Button("Quit Application") {
                    NSApplication.shared.terminate(nil)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .frame(width: 350, height: 220) // Height accommodates the new button
    }
}
