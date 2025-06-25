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
    @State private var applyCeiling = false
    @State var lightTemp: Double = 6500
    @State var lightBright: Double = 100
    

    
    var body: some View
    {
        HStack(alignment: .center){
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
            VStack(alignment: .center){
                Button("", systemImage: "arrowshape.left.circle.fill") {
                    LightController().setBrightess(ip: LightController().ip1, brightness: lightBright)
                    LightController().setTemp(ip: LightController().ip1, temp: lightTemp)
                }
                Button("", systemImage: "arrowshape.left.circle.fill") {
                    LightController().setBrightess(ip: LightController().ip2, brightness: lightBright)
                    LightController().setTemp(ip: LightController().ip2, temp: lightTemp)
                }
                .padding(5)
            }
            VStack(alignment: .trailing){
                Slider(value: $lightBright, in: 0...100, step: 10)
                    .frame(width: 200)
                Slider(value: $lightTemp, in: 2200...6500, step: 430)
                    .frame(width: 200)
            }
            VStack(alignment: .center){
                Image(systemName: "light.max")
                    .padding(2)
                Image(systemName: "snowflake")
                    .padding(2)
            }
            
            
        }
            .toggleStyle(SwitchToggleStyle())
            .buttonStyle(BorderlessButtonStyle())
            .bold(true)
            .padding(15)
    }
}


#Preview {
    ContentView()
}
