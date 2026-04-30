//
//  SettingsView.swift
//  keyDrop
//

import SwiftUI

struct SettingsView: View {
    @Environment(KeyStore.self) private var store
    @Environment(UpdateService.self) private var updateService

    @AppStorage("themeOverride") private var themeOverrideRaw: String = ThemeOverride.system.rawValue
    @AppStorage("showRecentList") private var showRecentList: Bool = true
    @AppStorage("clipboardClearSeconds") private var clipboardClearSeconds: Int = 30

    @State private var graceSeconds: Int = Self.graceOptions[0].seconds
    @State private var launchAtLogin: Bool = LaunchAtLoginService.isEnabled
    @State private var pane: SettingsPane = .preferences

    enum SettingsPane: Hashable { case preferences, keys }

    private static let graceOptions: [(label: String, seconds: Int)] = [
        ("5m", 5 * 60),
        ("15m", 15 * 60),
        ("30m", 30 * 60),
        ("1hr", 60 * 60),
        ("4hr", 4 * 60 * 60)
    ]

    private static let appVersion: String = {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                paneContent
            }

            aboutFooter
        }
        .frame(minWidth: AppMetrics.settingsMinWidth)
        .background(SettingsWindowStyler())
        .onAppear {
            let snapped = Self.nearestGraceOption(for: Int(store.auth.graceDuration))
            if graceSeconds != snapped { graceSeconds = snapped }
            let clamped = max(30, clipboardClearSeconds)
            if clipboardClearSeconds != clamped { clipboardClearSeconds = clamped }
            let target = TimeInterval(clamped)
            if store.clipboard.clearAfter != target { store.clipboard.clearAfter = target }
            let actualLogin = LaunchAtLoginService.isEnabled
            if launchAtLogin != actualLogin { launchAtLogin = actualLogin }
        }
        .onChange(of: graceSeconds) { old, new in
            guard old != new else { return }
            store.auth.graceDuration = TimeInterval(new)
        }
        .onChange(of: clipboardClearSeconds) { old, new in
            guard old != new else { return }
            store.clipboard.clearAfter = TimeInterval(max(30, new))
        }
        .onChange(of: launchAtLogin) { old, new in
            guard old != new else { return }
            let ok = LaunchAtLoginService.setEnabled(new)
            if !ok {
                launchAtLogin = LaunchAtLoginService.isEnabled
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 6) {
            sidebarIcon(inactive: "gearshape", active: "gearshape.fill", pane: .preferences, label: "Preferences")
            sidebarIcon(inactive: "key", active: "key.fill", pane: .keys, label: "Keys")
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .frame(width: AppMetrics.settingsSidebarWidth)
        .frame(maxHeight: .infinity)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.secondary.opacity(0.28))
                .frame(width: 1)
        }
        .focusEffectDisabled()
    }

    private func sidebarIcon(inactive: String, active: String, pane target: SettingsPane, label: String) -> some View {
        let isActive = pane == target
        return Button {
            guard pane != target else { return }
            pane = target
        } label: {
            Image(systemName: isActive ? active : inactive)
                .font(.system(size: 16))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .frame(width: 44, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(label)
        .accessibilityLabel(label)
    }

    // MARK: - Pane switcher

    private var paneContent: some View {
        Group {
            switch pane {
            case .preferences:
                settingsToolbar
                    .fixedSize(horizontal: false, vertical: true)
            case .keys:
                keysPane
                    .frame(minHeight: 420)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - settingsToolbar (Preferences pane)

    private var settingsToolbar: some View {
        VStack(alignment: .leading, spacing: 0) {
            formRow("Theme") {
                themeIconPicker
            }
            formDivider
            formRow("Recent keys") {
                Toggle("", isOn: $showRecentList)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            formDivider
            formRow("Launch at login") {
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            formDivider
            formRow("Auth grace") {
                Picker("", selection: $graceSeconds) {
                    ForEach(Self.graceOptions, id: \.seconds) { opt in
                        Text(opt.label).tag(opt.seconds)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 90)
            }
            formDivider
            formRow("Clipboard clear") {
                Picker("", selection: $clipboardClearSeconds) {
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("2 minutes").tag(120)
                    Text("5 minutes").tag(300)
                    Text("10 minutes").tag(600)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 140)
            }
            formDivider
            formRow("Auto-update") {
                @Bindable var updates = updateService
                Toggle("", isOn: $updates.automaticallyChecksForUpdates)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            formDivider
            formRow("Updates") {
                HStack(spacing: 12) {
                    Button {
                        updateService.checkForUpdates()
                    } label: {
                        if updateService.isCheckingForUpdates {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 14, height: 14)
                        } else {
                            Text("Check for Updates")
                        }
                    }
                    .disabled(!updateService.canCheckForUpdates || updateService.isCheckingForUpdates)

                    if let lastCheck = updateService.lastUpdateCheckDate {
                        Text("Last: \(lastCheck, format: .relative(presentation: .named))")
                            .font(AppFont.small)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
    }

    private var formDivider: some View {
        Divider().opacity(0.35)
    }

    private func formRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text("\(title):")
                .font(AppFont.body)
                .foregroundStyle(.primary)
                .frame(width: AppMetrics.settingsFormLabelWidth, alignment: .trailing)
            content()
        }
        .padding(.vertical, 10)
    }

    private var themeIconPicker: some View {
        HStack(spacing: 8) {
            ForEach(ThemeOverride.allCases) { opt in
                let active = themeOverrideRaw == opt.rawValue
                Button {
                    themeOverrideRaw = opt.rawValue
                } label: {
                    Image(systemName: opt.symbolName(active: active))
                        .font(.system(size: 13))
                        .foregroundStyle(active ? Color.accentColor : Color.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(active ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10))
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    active ? Color.accentColor.opacity(0.55) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(opt.label)
                .accessibilityLabel(opt.label)
            }
        }
    }

    // MARK: - Keys pane

    private var keysPane: some View {
        KeysTab()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private static func nearestGraceOption(for seconds: Int) -> Int {
        let values = graceOptions.map { $0.seconds }
        return values.min(by: { abs($0 - seconds) < abs($1 - seconds) }) ?? values[0]
    }

    // MARK: - Footer

    private var aboutFooter: some View {
        HStack(spacing: 24) {
            aboutItem(title: "Version", value: Self.appVersion)
            aboutItem(title: "Identifier", value: "com.neurix.keydrop")
            aboutItem(title: "Storage", value: "Keychain + Secure Enclave")
            aboutLinkItem(title: "Website", url: Self.websiteURL)
            Spacer(minLength: 0)
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

    private func aboutLinkItem(title: String, url: URL) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(AppFont.monoLabel)
                .foregroundStyle(.secondary)
            Link(url.absoluteString, destination: url)
                .font(AppFont.monoSmall)
        }
    }

    private static let websiteURL = URL(string: "https://neurix.co/keydrop")!
}

// MARK: - Window styler (hide title, remove focus ring)

private struct SettingsWindowStyler: NSViewRepresentable {
    final class Coordinator {
        var applied = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        DispatchQueue.main.async { apply(to: v, coordinator: context.coordinator) }
        return v
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard !context.coordinator.applied else { return }
        DispatchQueue.main.async { apply(to: view, coordinator: context.coordinator) }
    }

    private func apply(to view: NSView, coordinator: Coordinator) {
        guard let window = view.window else { return }
        window.identifier = KeyDropWindowIdentifier.settings
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        coordinator.applied = true
    }
}

#Preview {
    SettingsView()
        .environment(KeyStore())
}
