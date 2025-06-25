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
            Toggle("", systemImage: "lamp.ceiling",isOn: $ceilingOn)
                .onChange(of: ceilingOn, initial: false){
                    if ceilingOn{
                        LightController().turnOn(ip: LightController().ip1)
                    }
                    else{
                        LightController().turnOff(ip: LightController().ip1)
                    }
                }
            Toggle("", systemImage: "lamp.floor" ,isOn: $uplighterOn)
                .onChange(of: uplighterOn, initial: false){
                    if uplighterOn{
                        LightController().turnOn(ip: LightController().ip2)
                    }
                    else{
                        LightController().turnOff(ip: LightController().ip2)
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
