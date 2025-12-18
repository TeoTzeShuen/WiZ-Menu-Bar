//
//  BulbModel.swift
//  WiZ Menu Bar
//
//  Created by Tze Shuen Teo on 22/11/25.
//

import Foundation
import SwiftUI
import WidgetKit
internal import Combine

// Define Bulb
struct Bulb: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var ip: String
    
    var showInWidget: Bool = false
        
    // Last Known State (Cached for Widget)
    var isVerifiedOn: Bool = false
    // Store color as simple RGB components for Codable support
    var cachedR: Double = 1.0
    var cachedG: Double = 1.0
    var cachedB: Double = 1.0
    
    var displayColor: Color {
        Color(red: cachedR, green: cachedG, blue: cachedB)
    }
}

// Data Manager
class BulbStore: ObservableObject {
    @Published var bulbs: [Bulb] = [] {
        didSet {
            save()
        }
    }
    
    // private let key = "saved_bulbs_json"
    
    private let suiteName = "group.com.tzeshuen.wizcontrol"
    private let key = "saved_bulbs_json"
    
    init() {
        load()
        // Placeholder Bulb for first run
        if bulbs.isEmpty {
            bulbs.append(Bulb(name: "Example Name", ip: ""))
        }
    }
    
    func addBulb(name: String = "New Bulb", ip: String = "") {
        bulbs.append(Bulb(name: name, ip: ip))
    }
    
    func deleteBulb(at offsets: IndexSet) {
        bulbs.remove(atOffsets: offsets)
    }
    
    func updateState(for id: UUID, isOn: Bool, color: Color) {
        if let index = bulbs.firstIndex(where: { $0.id == id }) {
            bulbs[index].isVerifiedOn = isOn
            
            if let components = NSColor(color).usingColorSpace(.deviceRGB) {
                bulbs[index].cachedR = Double(components.redComponent)
                bulbs[index].cachedG = Double(components.greenComponent)
                bulbs[index].cachedB = Double(components.blueComponent)
            }
            // Saving happens automatically via didSet
            // We also tell the widget to refresh
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private func save() {
        // --- CHANGED SAVE LOGIC ---
        // Encode to the Shared App Group Container
        if let encoded = try? JSONEncoder().encode(bulbs),
           let userDefaults = UserDefaults(suiteName: suiteName) { // Use suiteName
            userDefaults.set(encoded, forKey: key)
        }
    }
    
    private func load() {
        // --- CHANGED LOAD LOGIC ---
        // Decode from the Shared App Group Container
        if let userDefaults = UserDefaults(suiteName: suiteName), // Use suiteName
           let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Bulb].self, from: data) {
            self.bulbs = decoded
        }
    }
}
