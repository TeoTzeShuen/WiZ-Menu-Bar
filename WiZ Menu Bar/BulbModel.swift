//
//  BulbModel.swift
//  WiZ Menu Bar
//
//  Created by Tze Shuen Teo on 22/11/25.
//

import Foundation
import SwiftUI

// Define Bulb
struct Bulb: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var ip: String
}

// Data Manager
class BulbStore: ObservableObject {
    @Published var bulbs: [Bulb] = [] {
        didSet {
            save()
        }
    }
    
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
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(bulbs) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Bulb].self, from: data) {
            self.bulbs = decoded
        }
    }
}
