import Foundation
import Socket // Requires "BlueSocket" package via Swift Package Manager
import Dispatch

// 1. Helper structs to parse the JSON response from WiZ bulbs
struct WizResponse: Codable {
    let method: String
    let result: WizResult?
}

struct WizResult: Codable {
    let state: Bool?
    let dimming: Int?
    let temp: Int?
}

// 2. The Controller
struct LightController {
    
    // Standard UDP Port for WiZ
    static let port: Int32 = 38899
    
    // A generic helper to send a message and optionally return the response string
    private static func send(ip: String, message: String, expectResponse: Bool = false) -> String? {
        guard !ip.isEmpty else { return nil }
        
        do {
            // Create a new UDP socket
            let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
            
            // Set a timeout so the app doesn't freeze if bulb is offline
            try socket.setReadTimeout(value: 500) // 500ms timeout
            
            guard let addr = Socket.createAddress(for: ip, on: port) else { return nil }
            
            // Write data
            try socket.write(from: message, to: addr)
            
            var response: String? = nil
            
            if expectResponse {
                var readData = Data()
                // Read response
                let _ = try socket.readDatagram(into: &readData)
                response = String(data: readData, encoding: .utf8)
            }
            
            socket.close()
            return response
            
        } catch {
            print("Connection error for \(ip): \(error)")
            return nil
        }
    }
    
    // MARK: - Control Functions
    
    static func turnOn(ip: String) {
        let message = #"{"method":"setPilot","params":{"state":true}}"#
        _ = send(ip: ip, message: message)
    }
    
    static func turnOff(ip: String) {
        let message = #"{"method":"setPilot","params":{"state":false}}"#
        _ = send(ip: ip, message: message)
    }
    
    static func setTemp(ip: String, temp: Double = 4400) {
        // WiZ expects integers for these values
        let val = Int(temp)
        let message = #"{"method":"setPilot","params":{"temp":\#(val)}}"#
        _ = send(ip: ip, message: message)
    }
    
    static func setBrightess(ip: String, brightness: Double = 100) {
        // WiZ expects dimming 10-100
        let val = Int(brightness)
        // We also send "state": true to ensure it turns on if we slide the slider
        let message = #"{"method":"setPilot","params":{"dimming":\#(val), "state":true}}"#
        _ = send(ip: ip, message: message)
    }
    
    // MARK: - Status Check
    // This replaces your original checkLightState.
    // It returns a tuple of (isOn, Brightness, Temp) so the UI can update.
    static func getStatus(ip: String) -> (isOn: Bool, brightness: Double, temp: Double)? {
        let message = #"{"method":"getPilot","params":{}}"#
        
        guard let jsonString = send(ip: ip, message: message, expectResponse: true),
              let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        // Decode the JSON
        let decoder = JSONDecoder()
        do {
            let response = try decoder.decode(WizResponse.self, from: data)
            if let res = response.result {
                // Return the values found, or defaults if missing
                return (
                    isOn: res.state ?? false,
                    brightness: Double(res.dimming ?? 100),
                    temp: Double(res.temp ?? 4400)
                )
            }
        } catch {
            print("JSON Parse Error: \(error)")
        }
        return nil
    }
}
