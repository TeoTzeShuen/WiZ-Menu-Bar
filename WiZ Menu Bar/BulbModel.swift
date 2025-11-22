//
//  BulbModel.swift
//  WiZ Menu Bar
//
//  Created by Tze Shuen Teo on 22/11/25.
//

import Foundation
import SwiftUI

// 1. The Definition of a Bulb
struct Bulb: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var ip: String
}

// 2. The Data Manager (Handles saving/loading the list)
class BulbStore: ObservableObject {
    @Published var bulbs: [Bulb] = [] {
        didSet {
            save()
        }
    }
    
    private let key = "saved_bulbs_json"
    
    init() {
        load()
        // Fallback: If empty (first run), add a placeholder so the UI isn't broken
        if bulbs.isEmpty {
            bulbs.append(Bulb(name: "Living Room", ip: ""))
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
