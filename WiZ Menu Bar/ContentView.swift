//
//  ContentView.swift
//  WiZ Menu Bar
//
//  Created by Tze Shuen Teo on 24/6/25.
//

import SwiftUI


struct ContentView: View {
    @State private var ceilingOn = false
    @State private var uplighterOn = false
    
    var body: some View
    {
        VStack(alignment: .trailing){
            Toggle("Celiing", isOn: $ceilingOn)
                .onChange(of: ceilingOn, initial: false){
                    if ceilingOn{
                        LightController().turnOn(ip: "192.168.1.14")
                    }
                    else{
                        LightController().turnOff(ip: "192.168.1.14")
                    }
                }
            Toggle("Uplighter", isOn: $uplighterOn)
                .onChange(of: uplighterOn, initial: false){
                    if uplighterOn{
                        LightController().turnOn(ip: "192.168.1.10")
                    }
                    else{
                        LightController().turnOff(ip: "192.168.1.10")
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle())
            .buttonStyle(PlainButtonStyle())
            .bold(true)
            .padding(15)
    }
}


#Preview {
    ContentView()
}
