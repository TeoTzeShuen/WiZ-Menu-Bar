import SwiftUI

struct ContentView: View {
    @AppStorage("bulb1_ip") private var bulb1IP: String = ""
    @AppStorage("bulb2_ip") private var bulb2IP: String = ""

    // Selection State
    enum BulbSelection: String, CaseIterable {
        case all = "All"
        case bulb1 = "Bulb 1"
        case bulb2 = "Bulb 2"
    }
    @State private var selection: BulbSelection = .all

    // UI State
    @State private var isLightOn: Bool = false
    @State private var brightness: Double = 100
    @State private var warmth: Double = 4400
    @State private var isSyncing: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            
            // Header & Settings Button
            HStack {
                Text("Home Lights")
                    .font(.headline)
                Spacer()
                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.5)
                }
                
                // Settings Button Logic
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Image(systemName: "gearshape.fill")
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        NSApp.activate(ignoringOtherApps: true)
                    }) {
                        Image(systemName: "gearshape.fill")
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Bulb Selector
            Picker("", selection: $selection) {
                ForEach(BulbSelection.allCases, id: \.self) { option in
                    Text(option.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selection) { _ in
                // When switching bulbs, refresh the UI with that bulb's current state
                syncStateWithBulbs()
            }
            
            Divider()

            // 1. Master Switch
            Toggle(isOn: $isLightOn) {
                Text(isLightOn ? "Lights On" : "Lights Off")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.switch)
            .onChange(of: isLightOn) { newValue in
                performAction { ip in
                    if newValue { LightController.turnOn(ip: ip) }
                    else { LightController.turnOff(ip: ip) }
                }
            }

            // 2. Brightness
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "sun.max.fill")
                        .font(.caption)
                    Text("Brightness")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(brightness))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $brightness, in: 10...100, step: 5) {
                    EmptyView() // Redundant label removed
                }
                .onChange(of: brightness) { newValue in
                    performAction { ip in
                        LightController.setBrightess(ip: ip, brightness: newValue)
                    }
                }
            }

            // 3. Warmth
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "thermometer.sun.fill")
                        .font(.caption)
                    Text("Warmth")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(warmth))K")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                
                // Slider from Warm (2200) to Cold (6200)
                // Range = 4000. Step = 400 to provide exactly 10 steps.
                Slider(value: $warmth, in: 2200...6200, step: 400) {
                    EmptyView() // Redundant label removed
                }
                .tint(.orange)
                .onChange(of: warmth) { newValue in
                    performAction { ip in
                        LightController.setTemp(ip: ip, temp: newValue)
                    }
                }
            }
            
            // Quit button removed from here
        }
        .padding()
        .frame(width: 260)
        .onAppear {
            syncStateWithBulbs()
        }
    }

    // MARK: - Logic
    
    // Determines which IP(s) to send the command to based on selection
    func performAction(action: @escaping (String) -> Void) {
        var targetIPs: [String] = []
        
        switch selection {
        case .all:
            targetIPs = [bulb1IP, bulb2IP]
        case .bulb1:
            targetIPs = [bulb1IP]
        case .bulb2:
            targetIPs = [bulb2IP]
        }
        
        // Filter out empty strings just in case settings are blank
        let validIPs = targetIPs.filter { !$0.isEmpty }
        
        Task {
            for ip in validIPs {
                action(ip)
            }
        }
    }
    
    // Syncs the UI sliders with the selected bulb
    func syncStateWithBulbs() {
        // If "All" is selected, we default to syncing with Bulb 1 for the UI display
        let syncIP: String
        switch selection {
        case .all, .bulb1:
            syncIP = bulb1IP
        case .bulb2:
            syncIP = bulb2IP
        }
        
        guard !syncIP.isEmpty else { return }
        
        isSyncing = true
        Task.detached {
            if let status = LightController.getStatus(ip: syncIP) {
                await MainActor.run {
                    self.isLightOn = status.isOn
                    self.brightness = status.brightness
                    self.warmth = status.temp
                    self.isSyncing = false
                }
            } else {
                await MainActor.run { self.isSyncing = false }
            }
        }
    }
}
