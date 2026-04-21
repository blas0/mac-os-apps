//
//  keyDropApp.swift
//  keyDrop
//

import AppKit
import SwiftUI

@main
struct KeyDropApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("themeOverride") private var themeOverrideRaw: String = ThemeOverride.system.rawValue
    @State private var keyStore = KeyStore()

    var body: some Scene {
        MenuBarExtra("keyDrop", image: "MenuBarIcon") {
            MenuBarView()
                .environment(keyStore)
                .onAppear(perform: applyTheme)
                .onChange(of: themeOverrideRaw) { _, _ in applyTheme() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(keyStore)
                .onAppear(perform: applyTheme)
                .onChange(of: themeOverrideRaw) { _, _ in applyTheme() }
        }
        .windowResizability(.contentSize)
    }

    private func applyTheme() {
        let override = ThemeOverride(rawValue: themeOverrideRaw) ?? .system
        switch override {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
