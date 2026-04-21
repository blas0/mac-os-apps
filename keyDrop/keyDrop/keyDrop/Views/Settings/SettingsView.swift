//
//  SettingsView.swift
//  keyDrop
//

import SwiftUI

enum SettingsTab: Hashable {
    case general
    case keys
}

struct SettingsView: View {
    @State private var selection: SettingsTab = .general

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selection) {
                GeneralTab()
                    .tabItem { Label("General", systemImage: "gearshape") }
                    .tag(SettingsTab.general)

                KeysTab()
                    .tabItem { Label("Keys", systemImage: "key") }
                    .tag(SettingsTab.keys)
            }
            .frame(maxHeight: .infinity)

            aboutFooter
        }
        .frame(width: AppMetrics.settingsWidth, height: AppMetrics.settingsHeight)
    }

    private var aboutFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ABOUT")
                .font(AppFont.monoLabel)
                .foregroundStyle(.secondary)
            HStack(spacing: 24) {
                aboutItem(title: "Version", value: appVersion)
                aboutItem(title: "Identifier", value: "com.neurix.keydrop")
                aboutItem(title: "Storage", value: "Keychain + Secure Enclave")
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Divider() }
    }

    private func aboutItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(AppFont.monoLabel)
                .foregroundStyle(.secondary)
            Text(value)
                .font(AppFont.monoSmall)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    SettingsView()
        .environment(KeyStore())
}
