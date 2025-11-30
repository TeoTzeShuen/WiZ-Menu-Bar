import SwiftUI

struct ContentView: View {
    @ObservedObject var store: BulbStore

    // UUID
    @State private var selectedBulbID: UUID?

    // UI State
    @State private var isLightOn: Bool = false
    @State private var brightness: Double = 100
    @State private var warmth: Double = 4400
    
    // Color State
    @State private var selectedColor: Color = .white
    @State private var colorDebounceTask: Task<Void, Never>? = nil
    @State private var isUpdatingColorProgrammatically: Bool = false
    
    // Connectivity State
    @State private var isSyncing: Bool = false
    @State private var isUnreachable: Bool = false
    
    var body: some View {
        VStack(spacing: 19) {
            
            // Header
            HStack {
                Text("Home Lights")
                    .font(.headline)
                Spacer()
                
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
                    .opacity(isSyncing ? 1 : 0)
                
                // Settings Button
                if #available(macOS 14.0, *) {
                    // pass to settings
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
            
            // DYNAMIC PICKER
            if store.bulbs.isEmpty {
                Text("No bulbs configured.")
                    .font(.caption)
            } else {
                Picker("", selection: $selectedBulbID) {
                    ForEach(store.bulbs) { bulb in
                        Text(bulb.name.isEmpty ? "Unnamed" : bulb.name).tag(bulb.id as UUID?)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedBulbID) { _, _ in
                    syncStateWithBulbs()
                }
            }
            
            // Only show controls if we have a valid IP selected
            if let currentBulb = getSelectedBulb(), !currentBulb.ip.isEmpty {
                Divider()

                // Power Button & Color Picker
                HStack(spacing: 10) {
                    Button(action: toggleBulbLogic) {
                        HStack {
                            Image(systemName: isUnreachable ? "exclamationmark.triangle.fill" : "power")
                            Text(isUnreachable ? "Check Switch" : (isLightOn ? "Turn Off" : "Turn On"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, -2.5) // Some bastardisation to align picker and switch
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isUnreachable ? .red : (isLightOn ? .orange : .gray))
                    .controlSize(.large)
                    
                    // Color Picker
                    ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                        .labelsHidden()
                        .onChange(of: selectedColor) { _, newColor in
                            handleColorChange(newColor)
                        }
                }

                // Brightness
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .font(.caption)
                        Text("Brightness")
                            .font(.caption)
                        Spacer()
                        
                        if brightness == 0 {
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
                    .onChange(of: brightness) { _, newValue in
                        if !isSyncing {
                            updatePickerBrightness(newBrightness: newValue)
                            performAction { ip in
                                LightController.setBrightess(ip: ip, brightness: newValue)
                            }
                        }
                    }
                }

                // Warmth
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "thermometer.sun.fill")
                            .font(.caption)
                        Text(" Warmth") // Added space for alignment with "brightness" text
                            .font(.caption)
                        Spacer()
                        Text("\(Int(warmth))K")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    
                    let kelvinGradient = LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.7, blue: 0.4), // Orange
                            Color.white,                            // Neutral
                            Color(red: 0.8, green: 0.9, blue: 1.0)  // Blue
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    
                    Slider(value: $warmth, in: 2200...6200, step: 400) {
                        EmptyView()
                    }
                    .background(
                        // Create a capsule shape behind the slider with the gradient
                        Capsule()
                            .fill(kelvinGradient)
                            .frame(height: 5) // Match the height of a standard macOS slider track
                            .padding(.top, -1) // Move bar so it completely obscures slider track
                    )
                    .tint(.clear)
                    .onChange(of: warmth) { _, newValue in
                        if !isSyncing {
                            updatePickerToKelvin(kelvin: newValue, bright: brightness)
                            performAction { ip in
                                LightController.setTemp(ip: ip, temp: newValue)
                            }
                        }
                    }
                    
                    
                }
            } else {
                Divider()
                Spacer()
                Text("Please configure IP for this bulb")
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
        .padding()
        .frame(minHeight: 263, alignment: .bottom)
        .frame(width: 260)
        .animation(nil, value: selectedBulbID)
        .onAppear {
            // Select the first bulb by default if none selected
            if selectedBulbID == nil, let first = store.bulbs.first {
                selectedBulbID = first.id
            }
            syncStateWithBulbs()
        }
    }

    // MARK: - Logic Helpers
    
    // Helper to get the full Bulb object from the ID
    func getSelectedBulb() -> Bulb? {
        guard let id = selectedBulbID else { return nil }
        return store.bulbs.first(where: { $0.id == id })
    }
    
    func toggleBulbLogic() {
        guard let ip = getSelectedBulb()?.ip, !ip.isEmpty else { return }
        
        Task {
            if let status = LightController.getStatus(ip: ip) {
                let shouldTurnOn = !status.isOn
                if shouldTurnOn { LightController.turnOn(ip: ip) }
                else { LightController.turnOff(ip: ip) }
                
                await MainActor.run {
                    self.isUnreachable = false
                    self.isLightOn = shouldTurnOn
                }
            } else {
                await MainActor.run { self.isUnreachable = true; self.isLightOn = false }
            }
        }
    }
    
    func performAction(action: @escaping (String) -> Void) {
        guard let ip = getSelectedBulb()?.ip, !ip.isEmpty else { return }
        Task { action(ip) }
    }
    
    func syncStateWithBulbs() {
        guard let ip = getSelectedBulb()?.ip, !ip.isEmpty else { return }
        
        isSyncing = true
        isUnreachable = false
        
        Task.detached {
            if let status = LightController.getStatus(ip: ip) {
                await MainActor.run {
                    self.isUnreachable = false
                    self.isLightOn = status.isOn
                    self.brightness = status.brightness
                    self.warmth = status.temp
                    
                    self.isUpdatingColorProgrammatically = true
                    self.selectedColor = self.kelvinToColor(status.temp, brightness: status.brightness)
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
                await MainActor.run { self.isSyncing = false; self.isUpdatingColorProgrammatically = false }
            } else {
                await MainActor.run { self.isUnreachable = true; self.isSyncing = false }
            }
        }
    }
    
    // For completeness of the file structure
    func updatePickerToKelvin(kelvin: Double, bright: Double) {
        isUpdatingColorProgrammatically = true
        selectedColor = kelvinToColor(kelvin, brightness: bright)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 10_000_000)
            isUpdatingColorProgrammatically = false
        }
    }
    
    func updatePickerBrightness(newBrightness: Double) {
        isUpdatingColorProgrammatically = true
        if let nsColor = NSColor(selectedColor).usingColorSpace(.deviceRGB) {
            let h = nsColor.hueComponent
            let s = nsColor.saturationComponent
            let b = CGFloat(newBrightness / 100.0)
            selectedColor = Color(nsColor: NSColor(hue: h, saturation: s, brightness: b, alpha: 1.0))
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 10_000_000)
            isUpdatingColorProgrammatically = false
        }
    }
    
    func handleColorChange(_ color: Color) {
        if isUpdatingColorProgrammatically { return }
        if isSyncing { return }
        
        colorDebounceTask?.cancel()
        colorDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
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
    
    func kelvinToColor(_ k: Double, brightness: Double) -> Color {
        let temp = k / 100.0
        var r: Double, g: Double, b: Double
        
        if temp <= 66 { r = 255 } else { r = 329.698727446 * pow(temp - 60, -0.1332047592) }
        if temp <= 66 { g = 99.4708025861 * log(temp) - 161.1195681661 } else { g = 288.1221695283 * pow(temp - 60, -0.0755148492) }
        if temp >= 66 { b = 255 } else { if temp <= 19 { b = 0 } else { b = 138.5177312231 * log(temp - 10) - 305.0447927307 } }
        
        let dimFactor = brightness / 100.0
        return Color(red: min(255, max(0, r))/255*dimFactor, green: min(255, max(0, g))/255*dimFactor, blue: min(255, max(0, b))/255*dimFactor)
    }
}

// Preview macro
#Preview {
    let mockStore = BulbStore()
    // Optionally, customize bulbs for preview
    mockStore.bulbs = [
        Bulb(name: "Demo Light", ip: "192.168.1.100"),
        Bulb(name: "Living Room", ip: ""),
    ]
    return ContentView(store: mockStore)
}
