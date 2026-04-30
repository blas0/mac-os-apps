//
//  keyDropApp.swift
//  keyDrop
//

import AppKit
import SwiftUI

@main
struct KeyDropApp: App {
    @AppStorage("themeOverride") private var themeOverrideRaw: String = ThemeOverride.system.rawValue
    @AppStorage("hasOnboarded") private var legacyHasOnboarded: Bool = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var keyStore = KeyStore()
    @State private var updateService = UpdateService()
    @State private var licenseService = LicenseService()

    private var shouldInsertMenuBar: Bool {
        #if KEYDROP_CHANNEL_DIRECT
        hasCompletedOnboarding && licenseService.isLicensed
        #else
        hasCompletedOnboarding
        #endif
    }

    var body: some Scene {
        Window("Welcome to keyDrop", id: "onboarding") {
            OnboardingView {
                hasCompletedOnboarding = true
            }
            .environment(licenseService)
            .onAppear(perform: migrateLegacyOnboardingState)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(shouldInsertMenuBar ? .suppressed : .presented)

        MenuBarExtra("keyDrop", systemImage: "key.fill", isInserted: .constant(shouldInsertMenuBar)) {
            MenuBarView()
                .environment(keyStore)
                .environment(updateService)
                .onAppear(perform: applyTheme)
                .onChange(of: themeOverrideRaw) { _, _ in applyTheme() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(keyStore)
                .environment(updateService)
                .environment(licenseService)
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
        applyAppIcon(for: override)
    }

    private func migrateLegacyOnboardingState() {
        guard !hasCompletedOnboarding, legacyHasOnboarded else { return }
        hasCompletedOnboarding = true
        legacyHasOnboarded = false
    }

    /// Override the dock tile icon to track the user's theme choice.
    /// Per `NSApplication.applicationIconImage` docs: assigning an `NSImage`
    /// temporarily replaces the dock icon; assigning `nil` restores the
    /// original `.icon` bundle (which then follows system appearance).
    private func applyAppIcon(for override: ThemeOverride) {
        let imageName: String?
        switch override {
        case .system: imageName = nil
        case .light:  imageName = "AppIconLight"
        case .dark:   imageName = "AppIconDark"
        }
        NSApp.applicationIconImage = imageName.flatMap { NSImage(named: $0) }
    }
}
