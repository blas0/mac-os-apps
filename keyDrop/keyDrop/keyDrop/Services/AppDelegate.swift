//
//  AppDelegate.swift
//  keyDrop
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static let onboardedKey = "hasOnboarded"

    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !UserDefaults.standard.bool(forKey: Self.onboardedKey) {
            DispatchQueue.main.async { [weak self] in
                self?.presentOnboarding()
            }
        }
    }

    private func presentOnboarding() {
        guard onboardingWindow == nil else {
            onboardingWindow?.makeKeyAndOrderFront(nil)
            return
        }

        let view = OnboardingView { [weak self] in
            UserDefaults.standard.set(true, forKey: Self.onboardedKey)
            self?.dismissOnboarding()
        }

        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self

        onboardingWindow = window
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func dismissOnboarding() {
        onboardingWindow?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow,
              closing == onboardingWindow else { return }
        onboardingWindow = nil
        NSApp.setActivationPolicy(.accessory)
    }
}
