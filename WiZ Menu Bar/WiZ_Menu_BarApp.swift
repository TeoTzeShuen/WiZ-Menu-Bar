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
            systemImage: "lamp.floor.fill"
        ){
            ContentView()
                .overlay(alignment: .topTrailing) {
                    Button(
                        "Quit",
                        systemImage: "xmark.circle.fill"
                    ){
                        NSApp.terminate(nil)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                }}
        .menuBarExtraStyle(.window)
    }
}
