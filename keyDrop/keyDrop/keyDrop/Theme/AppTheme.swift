//
//  AppTheme.swift
//  keyDrop
//

import SwiftUI

enum AppFont {
    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("SF Mono", size: size).weight(weight)
    }

    static let title = rounded(14, weight: .bold)
    static let body = rounded(14)
    static let label = rounded(10)
    static let small = rounded(10)

    static let monoBody = mono(10)
    static let monoSmall = mono(10)
    static let monoLabel = mono(10)
}

enum AppMetrics {
    static let popoverWidth: CGFloat = 300
    static let popoverCornerRadius: CGFloat = 18
    static let settingsMinWidth: CGFloat = 580
    static let settingsSidebarWidth: CGFloat = 64
    static let settingsFormLabelWidth: CGFloat = 160
}

enum ThemeOverride: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    func symbolName(active: Bool) -> String {
        switch self {
        case .system: active ? "apple.terminal.fill" : "apple.terminal"
        case .light: active ? "sun.max.fill" : "sun.max"
        case .dark: active ? "moon.fill" : "moon"
        }
    }
}
