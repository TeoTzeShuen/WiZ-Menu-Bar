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
    // Added r,g,b parsing just in case we want to read it later
    let r: Int?
    let g: Int?
    let b: Int?
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
    
    // MARK: - NEW: Color Control
    static func setRGB(ip: String, r: Int, g: Int, b: Int, brightness: Double = 100) {
        // Clamp values to 0-255 to prevent errors
        let red = max(0, min(255, r))
        let green = max(0, min(255, g))
        let blue = max(0, min(255, b))
        let dimming = Int(brightness)
        
        let message = """
        {"id":1,"method":"setPilot","params":{"r":\(red),"g":\(green),"b":\(blue),"dimming":\(dimming)}}
        """
        _ = send(ip: ip, message: message)
    }
    
    // MARK: - Status Check
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
    
    // MARK: - Discovery
    static func discoverBulbs() async -> [String] {
        var foundIPs: Set<String> = []
        
        print("Starting discovery...")
        
        do {
            let socket = try Socket.create(family: .inet, type: .datagram, proto: .udp)
            try socket.udpBroadcast(enable: true) // Essential: Allows sending to 255.255.255.255
            
            // 2 seconds read timeout
            try socket.setReadTimeout(value: 2000)
            
            let message = #"{"method":"getPilot","params":{}}"#
            guard let data = message.data(using: .utf8) else { return [] }
            
            // Broadcast Address
            // Note: On some complex networks this might need to be the specific subnet broadcast (e.g. 192.168.1.255)
            // But 255.255.255.255 works for most simple home setups.
            guard let broadcastAddr = Socket.createAddress(for: "255.255.255.255", on: port) else {
                return []
            }
            
            // Send the "Shout"
            try socket.write(from: data, to: broadcastAddr)
            
            // Listen for replies for roughly 2 seconds
            let startTime = Date()
            while Date().timeIntervalSince(startTime) < 2.0 {
                var readData = Data()
                let (bytesRead, remoteAddr) = try socket.readDatagram(into: &readData)
                
                if bytesRead > 0, let addr = remoteAddr {
                    // Extract IP
                    if let hostname = Socket.hostnameAndPort(from: addr)?.hostname {
                        // Filter out our own device if it somehow echoes back
                        if !hostname.isEmpty {
                            foundIPs.insert(hostname)
                            print("Found bulb at: \(hostname)")
                        }
                    }
                }
            }
            
            socket.close()
            
        } catch let error {
            // specific error code 35 is "Resource temporarily unavailable" which happens on timeout
            // We ignore timeout errors because we expect the read to time out eventually
            if let socketError = error as? Socket.Error, socketError.errorCode == -9982 {
                 print("Discovery permissions issue. Check App Sandbox.")
            }
        }
        
        // Sort them so they populate in a predictable order
        return foundIPs.sorted()
    }
}
