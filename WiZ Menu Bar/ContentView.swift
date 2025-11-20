import SwiftUI

struct ContentView: View {
    // IPs
    @AppStorage("bulb1_ip") private var bulb1IP: String = ""
    @AppStorage("bulb2_ip") private var bulb2IP: String = ""
    
    // Names
    @AppStorage("bulb1_name") private var bulb1Name: String = "Bulb 1"
    @AppStorage("bulb2_name") private var bulb2Name: String = "Bulb 2"

    enum BulbSelection: String, CaseIterable {
        case bulb1
        case bulb2
    }
    @State private var selection: BulbSelection = .bulb1

    // UI State
    @State private var isLightOn: Bool = false
    @State private var brightness: Double = 100
    @State private var warmth: Double = 4400
    
    // Flag to prevent feedback loops
    @State private var isSyncing: Bool = false
    
    var isConfigurationValid: Bool {
        switch selection {
        case .bulb1: return !bulb1IP.isEmpty
        case .bulb2: return !bulb2IP.isEmpty
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            
            // Header
            HStack {
                Text("Home Lights")
                    .font(.headline)
                Spacer()
                
                // FIXED: Use opacity + fixed frame to prevent window jitter
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16) // Force small size to match text height
                    .opacity(isSyncing ? 1 : 0)   // Hide instead of remove to reserve space
                
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
            
            // Picker
            Picker("", selection: $selection) {
                ForEach(BulbSelection.allCases, id: \.self) { option in
                    Text(displayName(for: option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selection) { _ in
                syncStateWithBulbs()
            }
            
            if isConfigurationValid {
                Divider()

                // 1. Power Button
                Button(action: toggleBulbLogic) {
                    HStack {
                        Image(systemName: "power")
                        Text(isLightOn ? "Turn Off" : "Turn On")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(isLightOn ? .orange : .gray)
                .controlSize(.large)

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
                    
                    Slider(value: $brightness, in: 10...100, step: 10) {
                        EmptyView()
                    }
                    .onChange(of: brightness) { newValue in
                        if !isSyncing {
                            performAction { ip in
                                LightController.setBrightess(ip: ip, brightness: newValue)
                            }
                        }
                    }
                }

                // 3. Warmth
                
                let kelvinGradient = LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 1.0, green: 0.7, blue: 0.4),
                        Color.white,
                        Color(red: 0.8, green: 0.9, blue: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                    
                
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
                    
                    Slider(value: $warmth, in: 2200...6200, step: 400) {
                        EmptyView()
                    }
                    .background(
                        Capsule()
                            .fill(kelvinGradient)
                            .frame(height: 4)
                            .padding(.horizontal, 2)
                    )
                    .tint(.clear)
                    .onChange(of: warmth) { newValue in
                        if !isSyncing {
                            performAction { ip in
                                LightController.setTemp(ip: ip, temp: newValue)
                            }
                        }
                    }
                }
            } else {
                Divider()
                Text("Please configure IP Address in Settings")
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
        .padding()
        .frame(width: 260)
        .onAppear {
            syncStateWithBulbs()
        }
    }

    // MARK: - Logic
    
    func displayName(for selection: BulbSelection) -> String {
        switch selection {
        case .bulb1:
            return bulb1Name.isEmpty ? "Bulb 1" : bulb1Name
        case .bulb2:
            return bulb2Name.isEmpty ? "Bulb 2" : bulb2Name
        }
    }
    
    // Toggle logic
    func toggleBulbLogic() {
        let ip: String
        switch selection {
        case .bulb1: ip = bulb1IP
        case .bulb2: ip = bulb2IP
        }
        
        guard !ip.isEmpty else { return }
        
        Task {
            if let status = LightController.getStatus(ip: ip) {
                let shouldTurnOn = !status.isOn
                
                if shouldTurnOn {
                    LightController.turnOn(ip: ip)
                } else {
                    LightController.turnOff(ip: ip)
                }
                
                await MainActor.run {
                    self.isLightOn = shouldTurnOn
                }
            }
        }
    }
    
    // Slider Logic (Write-only)
    func performAction(action: @escaping (String) -> Void) {
        let ip: String
        switch selection {
        case .bulb1: ip = bulb1IP
        case .bulb2: ip = bulb2IP
        }
        
        guard !ip.isEmpty else { return }
        
        Task {
            action(ip)
        }
    }
    
    // Initial Sync Logic
    func syncStateWithBulbs() {
        let ip: String
        switch selection {
        case .bulb1: ip = bulb1IP
        case .bulb2: ip = bulb2IP
        }
        
        guard !ip.isEmpty else { return }
        
        isSyncing = true
        
        Task.detached {
            if let status = LightController.getStatus(ip: ip) {
                await MainActor.run {
                    self.isLightOn = status.isOn
                    self.brightness = status.brightness
                    self.warmth = status.temp
                }
                
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                
                await MainActor.run {
                    self.isSyncing = false
                }
            } else {
                await MainActor.run { self.isSyncing = false }
            }
        }
    }
}
