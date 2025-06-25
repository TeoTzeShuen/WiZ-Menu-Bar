//
//  LightController.swift
//  WiZ Menu Bar
//
//  Created by Tze Shuen Teo on 24/6/25.
//

import Foundation
import Socket
import Dispatch

class LightController {
    var s: Socket!
    var ip1: String = "192.168.1.14" //ceiling
    var ip2: String = "192.168.1.10" //uplighter
    
    func messageSend(ip:String, sendMessage: String){
        let message = sendMessage
        var readData:Data = message.data(using: .utf8)!
        do {
            s = try Socket.create(family: .inet, type: .datagram, proto: .udp)
            let addr = Socket.createAddress(for: ip, on: 38899)!
            try s.write(from: message, to: addr)
            _ = try s.readDatagram(into: &readData)
            let resp = String(data: readData, encoding: .utf8)!
            print (resp)
        } catch let error {
            print(error)
        }
    }
    
    func checkLightState(ip: String) -> Bool {
        let message = """
                {"method":"getPilot","params":{}}
            """
        var readData:Data = message.data(using: .utf8)!
        let lightState:Bool = false
        
        do {
            s = try Socket.create(family: .inet, type: .datagram, proto: .udp)
            let addr = Socket.createAddress(for: ip, on: 38899)!
            try s.write(from: message, to: addr)
            _ = try s.readDatagram(into: &readData)
            let resp = String(data: readData, encoding: .utf8)!
            print(resp)
        } catch let error {
            print(error)
        }
        return lightState
    }
    
    
    // 开灯
    func turnOn(ip: String) {
        let message = """
            {
                "method":"setPilot",
                "params":{
                    "state":true
                }
            }
        """
        do {
            s = try Socket.create(family: .inet, type: .datagram, proto: .udp)
            let addr = Socket.createAddress(for: ip, on: 38899)!
            try s.write(from: message, to: addr)
        } catch let error {
            print(error)
        }
        
    }
    
    // 关灯
    func turnOff(ip: String) {
        let message = """
            {
                "method":"setPilot",
                "params":{
                    "state":false
                }
            }
        """
        do {
            s = try Socket.create(family: .inet, type: .datagram, proto: .udp)
            let addr = Socket.createAddress(for: ip, on: 38899)!
            try s.write(from: message, to: addr)
        } catch let error {
            print(error)
        }
    }
}

