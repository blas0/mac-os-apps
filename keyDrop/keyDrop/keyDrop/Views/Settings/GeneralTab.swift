//
//  GeneralTab.swift
//  keyDrop
//

import SwiftUI

struct GeneralTab: View {
    @Environment(KeyStore.self) private var store

    @AppStorage("themeOverride") private var themeOverrideRaw: String = ThemeOverride.system.rawValue
    @AppStorage("showRecentList") private var showRecentList: Bool = true
    @AppStorage("recentListCount") private var recentListCount: Int = 3
    @AppStorage("clipboardClearSeconds") private var clipboardClearSeconds: Int = 30

    @State private var graceHours: Int = 0
    @State private var graceMinutes: Int = 5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section("APPEARANCE", rows: [
                    AnyView(row("Theme") {
                        Picker("", selection: $themeOverrideRaw) {
                            ForEach(ThemeOverride.allCases) { override in
                                Text(override.label).tag(override.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 240)
                    })
                ])

                section("MENU BAR", rows: [
                    AnyView(row("Show recent keys") {
                        Toggle("", isOn: $showRecentList).labelsHidden()
                    }),
                    AnyView(row("Recent count") {
                        Picker("", selection: $recentListCount) {
                            ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 200)
                        .disabled(!showRecentList)
                    })
                ])

                section("SECURITY", rows: [
                    AnyView(row("Auth grace period") {
                        HStack(spacing: 14) {
                            stepperPair(value: "\(graceHours)h", binding: $graceHours, range: 0...24, disabled: false)
                            stepperPair(value: "\(graceMinutes)m", binding: $graceMinutes, range: 0...59, disabled: graceHours == 24)
                        }
                    }),
                    AnyView(caption("Resets on app quit. Touch ID will not be required again until the timer expires."))
                ])

                section("CLIPBOARD", rows: [
                    AnyView(row("Auto-clear after") {
                        Picker("", selection: $clipboardClearSeconds) {
                            Text("30 seconds").tag(30)
                            Text("1 minute").tag(60)
                            Text("2 minutes").tag(120)
                            Text("5 minutes").tag(300)
                            Text("10 minutes").tag(600)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 160)
                    }),
                    AnyView(caption("Always on. Minimum 30 seconds. Skips clear if you copied something else in the meantime."))
                ])
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            let total = Int(store.auth.graceDuration)
            graceHours = total / 3600
            graceMinutes = (total % 3600) / 60
            if clipboardClearSeconds < 30 { clipboardClearSeconds = 30 }
            store.clipboard.clearAfter = TimeInterval(clipboardClearSeconds)
        }
        .onChange(of: graceHours) { _, _ in pushGrace() }
        .onChange(of: graceMinutes) { _, _ in pushGrace() }
        .onChange(of: clipboardClearSeconds) { _, new in
            store.clipboard.clearAfter = TimeInterval(max(30, new))
        }
    }

    private func section(_ title: String, rows: [AnyView]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppFont.label)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows.indices, id: \.self) { idx in
                    rows[idx]
                        .padding(.vertical, 8)
                    if idx < rows.count - 1 {
                        Divider().opacity(0.4)
                    }
                }
            }
        }
    }

    private func row<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(title).font(AppFont.body)
            Spacer(minLength: 16)
            trailing()
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(AppFont.small)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepperPair(value: String, binding: Binding<Int>, range: ClosedRange<Int>, disabled: Bool) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(AppFont.body)
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)
                .foregroundStyle(disabled ? .secondary : .primary)
            Stepper("", value: binding, in: range)
                .labelsHidden()
                .disabled(disabled)
        }
    }

    private func pushGrace() {
        if graceHours == 24 && graceMinutes != 0 {
            graceMinutes = 0
            return
        }
        let total = TimeInterval(graceHours * 3600 + graceMinutes * 60)
        store.auth.graceDuration = total
    }
}

#Preview {
    GeneralTab()
        .environment(KeyStore())
        .frame(width: AppMetrics.settingsWidth, height: AppMetrics.settingsHeight)
}
