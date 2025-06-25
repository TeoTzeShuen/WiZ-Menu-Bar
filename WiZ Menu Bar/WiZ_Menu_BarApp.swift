//
//  WiZ_Menu_BarApp.swift
//  WiZ Menu Bar
//
//  Created by Tze Shuen Teo on 24/6/25.
//

import SwiftUI

@main
struct WiZ_Menu_BarApp: App {
    var body: some Scene {
        MenuBarExtra(
            "Lights",
            systemImage: "bolt.house"
        ){
            ContentView()
                .overlay(alignment: .topTrailing) {
                    Button(
                        "Quit",
                        systemImage: "x.circle"
                    ){
                        NSApp.terminate(nil)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                }}
        .menuBarExtraStyle(.window)
    }
}
