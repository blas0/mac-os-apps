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

    static let title = rounded(13, weight: .semibold)
    static let body = rounded(12)
    static let label = rounded(10, weight: .medium)
    static let small = rounded(10)

    static let monoBody = mono(12)
    static let monoSmall = mono(10)
    static let monoLabel = mono(10, weight: .medium)
}

enum AppMetrics {
    static let popoverWidth: CGFloat = 360
    static let settingsWidth: CGFloat = 720
    static let settingsHeight: CGFloat = 720
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
}
