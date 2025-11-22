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
    
    // Color State
    @State private var selectedColor: Color = .white
    @State private var colorDebounceTask: Task<Void, Never>? = nil
    @State private var isUpdatingColorProgrammatically: Bool = false // Prevents feedback loops
    
    // Flag to prevent feedback loops from Bulb -> UI
    @State private var isSyncing: Bool = false
    
    // State for checking if light is Unreachable
    @State private var isUnreachable: Bool = false
    
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
                
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
                    .opacity(isSyncing ? 1 : 0)
                
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
            .onChange(of: selection) { _,_ in
                syncStateWithBulbs()
            }
            
            if isConfigurationValid {
                Divider()

                // 1. Power Button & Color Picker
                HStack(spacing: 10) {
                    // Power Button
                    Button(action: toggleBulbLogic) {
                        HStack {
                        // Change icon if unreachable
                            Image(systemName: isUnreachable ? "exclamationmark.triangle.fill" : "power")
                            
                            // Change text if unreachable
                            Text(isUnreachable ? "Check Switch/IP" : (isLightOn ? "Turn Off" : "Turn On"))
                                .fontWeight(.semibold)
                            
                            // Old Logic
                            // Image(systemName: "power")
                            // Text(isLightOn ? "Turn Off" : "Turn On")
                            //    .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    // Change color to Red if unreachable, otherwise keep existing logic
                    .tint(isUnreachable ? .red : (isLightOn ? .orange : .gray))
                    .controlSize(.large)
                    
                    // Color Picker - Standard Native Size
                    ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                        .labelsHidden()
                        .onChange(of: selectedColor) { _, newColor in
                            handleColorChange(newColor)
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
                        if Int(brightness) == 0 {
                            Text("Min")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                        else{
                            Text("\(Int(brightness))%")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                        
                    }
                    
                    Slider(value: $brightness, in: 0...100, step: 10) {
                        EmptyView()
                    }
                    .onChange(of: brightness) { _,newValue in
                        if !isSyncing {
                            // Update picker visually (brightness only)
                            updatePickerBrightness(newBrightness: newValue)
                            
                            performAction { ip in
                                LightController.setBrightess(ip: ip, brightness: newValue)
                            }
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
                    
                    // Warmth gradient on temp slider
                    let kelvinGradient = LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.7, blue: 0.4),
                            Color.white,
                            Color(red: 0.8, green: 0.9, blue: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    
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
                    .onChange(of: warmth) { _,newValue in
                        if !isSyncing {
                            // Update picker visually (Kelvin color)
                            updatePickerToKelvin(kelvin: newValue, bright: brightness)
                            
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
    
    // MARK: - Color Sync Logic
    
    // Update the picker to match Kelvin slider
    func updatePickerToKelvin(kelvin: Double, bright: Double) {
        isUpdatingColorProgrammatically = true
        selectedColor = kelvinToColor(kelvin, brightness: bright)
        
        // Reset flag after a micro-delay to ensure the onChange doesn't fire
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 10_000_000)
            isUpdatingColorProgrammatically = false
        }
    }
    
    // Update picker brightness only (preserving Hue)
    func updatePickerBrightness(newBrightness: Double) {
        isUpdatingColorProgrammatically = true
        
        // Get current HSBA
        if let nsColor = NSColor(selectedColor).usingColorSpace(.deviceRGB) {
            let h = nsColor.hueComponent
            let s = nsColor.saturationComponent
            // Map 10-100 slider to 0.1-1.0 brightness
            let b = CGFloat(newBrightness / 100.0)
            
            selectedColor = Color(nsColor: NSColor(hue: h, saturation: s, brightness: b, alpha: 1.0))
        }
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 10_000_000)
            isUpdatingColorProgrammatically = false
        }
    }
    
    // Handles Color Picker Logic with Debounce
    func handleColorChange(_ color: Color) {
        // If we changed this programmatically (via sliders), do NOT send command
        if isUpdatingColorProgrammatically { return }
        if isSyncing { return }
        
        // 1. Cancel any pending request
        colorDebounceTask?.cancel()
        
        // 2. Start a new task
        colorDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s wait
            
            if !Task.isCancelled {
                if let nsColor = NSColor(color).usingColorSpace(.deviceRGB) {
                    let r = Int(nsColor.redComponent * 255)
                    let g = Int(nsColor.greenComponent * 255)
                    let b = Int(nsColor.blueComponent * 255)
                    
                    performAction { ip in
                        LightController.setRGB(ip: ip, r: r, g: g, b: b, brightness: self.brightness)
                    }
                }
            }
        }
    }
    
    // Helper: Convert Kelvin to Color
    func kelvinToColor(_ k: Double, brightness: Double) -> Color {
        let temp = k / 100.0
        var r: Double
        var g: Double
        var b: Double
        
        // Red
        if temp <= 66 {
            r = 255
        } else {
            r = temp - 60
            r = 329.698727446 * pow(r, -0.1332047592)
        }
        
        // Green
        if temp <= 66 {
            g = temp
            g = 99.4708025861 * log(g) - 161.1195681661
        } else {
            g = temp - 60
            g = 288.1221695283 * pow(g, -0.0755148492)
        }
        
        // Blue
        if temp >= 66 {
            b = 255
        } else {
            if temp <= 19 {
                b = 0
            } else {
                b = temp - 10
                b = 138.5177312231 * log(b) - 305.0447927307
            }
        }
        
        // Clamp and apply brightness
        let dimFactor = brightness / 100.0
        let red = min(255, max(0, r)) / 255.0 * dimFactor
        let green = min(255, max(0, g)) / 255.0 * dimFactor
        let blue = min(255, max(0, b)) / 255.0 * dimFactor
        
        return Color(red: red, green: green, blue: blue)
    }
    
    // MARK: - Existing Logic
    
    func toggleBulbLogic() {
        let ip: String
        switch selection {
        case .bulb1: ip = bulb1IP
        case .bulb2: ip = bulb2IP
        }
        
        guard !ip.isEmpty else { return }
        
        Task {
            if let status = LightController.getStatus(ip: ip) {
                // SUCCESS: Calculate toggle
                let shouldTurnOn = !status.isOn
                    
                if shouldTurnOn {
                    LightController.turnOn(ip: ip)
                } else {
                    LightController.turnOff(ip: ip)
                }
                
                await MainActor.run {
                    self.isUnreachable = false // Connection successful
                    self.isLightOn = shouldTurnOn
                }
            } else {
                // FAILURE: Bulb timed out
                await MainActor.run {
                    self.isUnreachable = true // Show "Check Switch"
                    // Optional: Turn off "On" state visually so it doesn't look stuck on
                    self.isLightOn = false
                }
            }
        }
    }
    
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
                    self.isUnreachable = false // Connection OK
                    self.isLightOn = status.isOn
                    self.brightness = status.brightness
                    self.warmth = status.temp
                    
                    // Set initial color based on retrieved warmth
                    // We set flag to true so this doesn't trigger a "Send RGB" command
                    self.isUpdatingColorProgrammatically = true
                    self.selectedColor = self.kelvinToColor(status.temp, brightness: status.brightness)
                }
                
                try? await Task.sleep(nanoseconds: 200_000_000)
                
                await MainActor.run {
                    self.isSyncing = false
                    self.isUpdatingColorProgrammatically = false
                }
            } else {
                await MainActor.run {
                    self.isUnreachable = true // Show Error
                    self.isSyncing = false }
            }
        }
    }
}
