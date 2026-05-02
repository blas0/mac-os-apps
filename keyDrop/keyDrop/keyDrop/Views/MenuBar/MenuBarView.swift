//
//  MenuBarView.swift
//  keyDrop
//

import AppKit
import SwiftUI

struct MenuBarView: View {
    private static let feedbackURL = URL(string: "applefeedback://")!
    private static let feedbackAssistantBundleID = "com.apple.appleseed.FeedbackAssistant"

    @Environment(\.openSettings) private var openSettings
    @Environment(KeyStore.self) private var store

    @AppStorage("showRecentList") private var showRecentList: Bool = true

    private static let maxVisibleRecents = 5
    private static let recentRowHeight: CGFloat = 44
    private static let recentRowSpacing: CGFloat = 4
    private static let toastLifetime: TimeInterval = 1.5

    @State private var label: String = ""
    @State private var key: String = ""
    @State private var statusMessage: StatusMessage?
    @State private var statusDismissTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case label, key }

    private struct StatusMessage: Equatable, Identifiable {
        let id = UUID()
        let text: String
        let kind: Kind
        enum Kind { case success, error }
    }

    private var canSubmit: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Entries are pre-sorted by createdAt descending in KeyStore.
    private var sortedRecents: [KeyEntry] { store.entries }

    private var recentScrollHeight: CGFloat {
        let rows = CGFloat(Self.maxVisibleRecents)
        return rows * Self.recentRowHeight + (rows - 1) * Self.recentRowSpacing
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                header
                form
                VStack(alignment: .center, spacing: 4) {
                    submitButton
                    shortcutHint
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if showRecentList && !sortedRecents.isEmpty {
                recentList
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            footer
        }
        .frame(width: AppMetrics.popoverWidth)
        .background(PopoverWindowStyler(cornerRadius: AppMetrics.popoverCornerRadius))
        .overlay(alignment: .bottom) { toastView }
        .onAppear { focusedField = .label }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            guard !store.auth.shouldPinMenu else { return }
            Self.dismissPopover()
        }
    }

    private static func dismissPopover() {
        let tolerance: CGFloat = 4
        for window in NSApp.windows where window.isVisible {
            let width = window.frame.width
            guard abs(width - AppMetrics.popoverWidth) <= tolerance else { continue }
            window.orderOut(nil)
        }
    }

    private var toastView: some View {
        Group {
            if let status = statusMessage {
                HStack(spacing: 8) {
                    Image(systemName: status.kind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(status.kind == .success ? Color.green : Color.red)
                    Text(status.text)
                        .font(AppFont.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                .padding(.bottom, 56)
                .id(status.id)
                .transition(.menuBarToastBlurFade)
                .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: statusMessage)
    }

    private var header: some View {
        Text("keyDrop")
            .font(AppFont.title)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldBlock(title: "LABEL *") {
                TextField("e.g. OPENAI_API_KEY", text: $label)
                    .textFieldStyle(.plain)
                    .font(AppFont.body)
                    .focused($focusedField, equals: .label)
                    .focusEffectDisabled()
                    .onSubmit { focusedField = .key }
                    .onKeyPress(.tab) { focusedField = .key; return .handled }
                    .modifier(IBeamCursor())
                    .modifier(RoundedFieldBackground(
                        cornerRadius: AppMetrics.popoverCornerRadius,
                        isFocused: focusedField == .label
                    ))
            }

            fieldBlock(title: "KEY *") {
                SecureField("e.g. sk123-...", text: $key)
                    .textFieldStyle(.plain)
                    .font(AppFont.body)
                    .focused($focusedField, equals: .key)
                    .focusEffectDisabled()
                    .onSubmit(submit)
                    .onKeyPress(.tab) { focusedField = .label; return .handled }
                    .modifier(IBeamCursor())
                    .modifier(RoundedFieldBackground(
                        cornerRadius: AppMetrics.popoverCornerRadius,
                        isFocused: focusedField == .key
                    ))
            }
        }
    }

    private func fieldBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppFont.label)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            Text("Drop Key")
                .font(AppFont.body)
        }
        .keyboardShortcut(.return, modifiers: .command)
        .buttonStyle(RoundedPrimaryButtonStyle(cornerRadius: AppMetrics.popoverCornerRadius))
        .disabled(!canSubmit)
    }

    private var shortcutHint: some View {
        HStack(spacing: 3) {
            Image(systemName: "command").font(.system(size: 10))
            Image(systemName: "return").font(.system(size: 10))
            Text("to drop").font(AppFont.small)
        }
        .foregroundStyle(.secondary)
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECENT")
                .font(AppFont.label)
                .foregroundStyle(.secondary)
            if sortedRecents.count <= Self.maxVisibleRecents {
                VStack(spacing: Self.recentRowSpacing) {
                    ForEach(sortedRecents) { entry in
                        recentRow(entry)
                    }
                }
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: Self.recentRowSpacing) {
                        ForEach(sortedRecents) { entry in
                            recentRow(entry)
                        }
                    }
                }
                .frame(height: recentScrollHeight)
            }
        }
    }

    private func recentRow(_ entry: KeyEntry) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.label)
                    .font(AppFont.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(entry.keyPreview)
                    .font(AppFont.monoSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            Button {
                let needsAuth = !store.auth.isWithinGrace
                if needsAuth {
                    flash(StatusMessage(text: "Please authenticate.", kind: .error), persistent: true)
                }
                store.copyKey(entry) { success in
                    if success {
                        flash(StatusMessage(text: "Copied!", kind: .success))
                    } else if let err = store.lastError {
                        flash(StatusMessage(text: err, kind: .error))
                    } else {
                        statusMessage = nil
                    }
                }
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("Copy key")
            .accessibilityLabel("Copy \(entry.label)")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .frame(height: Self.recentRowHeight)
        .background(
            RoundedRectangle(cornerRadius: AppMetrics.popoverCornerRadius)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button(action: openFeedback) {
                Label("Feedback", systemImage: "exclamationmark.bubble")
                    .font(AppFont.small)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.borderless)
            .help("Open Feedback Assistant")
            .accessibilityLabel("Open Feedback Assistant")

            Spacer(minLength: 8)

            Button(action: openSettingsWindow) {
                Image(systemName: "app.background.dotted")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.borderless)
            .help("Settings")
            .accessibilityLabel("Open settings")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.borderless)
            .help("Quit keyDrop")
            .accessibilityLabel("Quit keyDrop")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Divider() }
    }

    private func openSettingsWindow() {
        Self.dismissPopover()
        NSApp.setActivationPolicy(.regular)
        openSettings()
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let win = NSApp.windows.first(where: { $0.canBecomeKey && $0.contentViewController != nil && $0.frame.width >= AppMetrics.settingsMinWidth - 1 }) else { return }
            win.makeKeyAndOrderFront(nil)
            win.orderFrontRegardless()
        }
    }

    private func openFeedback() {
        let workspace = NSWorkspace.shared
        if workspace.open(Self.feedbackURL) { return }
        if let appURL = workspace.urlForApplication(withBundleIdentifier: Self.feedbackAssistantBundleID) {
            workspace.open(appURL)
            return
        }
        flash(StatusMessage(text: "Feedback Assistant unavailable.", kind: .error))
    }

    private func submit() {
        guard canSubmit else { return }
        store.add(label: label, key: key)
        if let err = store.lastError {
            flash(StatusMessage(text: err, kind: .error))
        } else {
            flash(StatusMessage(text: "Dropped \(label.trimmingCharacters(in: .whitespacesAndNewlines))", kind: .success))
            label = ""
            key = ""
            focusedField = .label
        }
    }

    private func flash(_ message: StatusMessage, persistent: Bool = false) {
        statusDismissTask?.cancel()
        statusDismissTask = nil

        if statusMessage != nil {
            statusMessage = nil
            statusDismissTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 240_000_000)
                guard !Task.isCancelled else { return }
                presentToast(message, persistent: persistent)
            }
        } else {
            presentToast(message, persistent: persistent)
        }
    }

    private func presentToast(_ message: StatusMessage, persistent: Bool) {
        statusMessage = message
        guard !persistent else { return }
        statusDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Self.toastLifetime * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if statusMessage == message { statusMessage = nil }
        }
    }

}

private extension AnyTransition {
    static var menuBarToastBlurFade: AnyTransition {
        .modifier(
            active: MenuBarToastBlurFadeModifier(opacity: 0, blur: 10),
            identity: MenuBarToastBlurFadeModifier(opacity: 1, blur: 0)
        )
    }
}

private struct MenuBarToastBlurFadeModifier: ViewModifier {
    let opacity: Double
    let blur: CGFloat
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .blur(radius: blur)
    }
}

private struct IBeamCursor: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { hovering in
            if hovering {
                NSCursor.iBeam.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

private struct RoundedFieldBackground: ViewModifier {
    let cornerRadius: CGFloat
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        isFocused ? Color.accentColor : Color.secondary.opacity(0.25),
                        lineWidth: 1
                    )
            )
    }
}

private struct RoundedPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillColor(pressed: configuration.isPressed))
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private func fillColor(pressed: Bool) -> Color {
        guard isEnabled else { return Color.accentColor.opacity(0.35) }
        return pressed ? Color.accentColor.opacity(0.75) : Color.accentColor
    }
}

private struct PopoverWindowStyler: NSViewRepresentable {
    let cornerRadius: CGFloat

    final class Coordinator {
        var applied = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { [cornerRadius] in
            apply(to: view, coordinator: context.coordinator, cornerRadius: cornerRadius)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard !context.coordinator.applied else { return }
        DispatchQueue.main.async { [cornerRadius] in
            apply(to: nsView, coordinator: context.coordinator, cornerRadius: cornerRadius)
        }
    }

    private func apply(to view: NSView, coordinator: Coordinator, cornerRadius: CGFloat) {
        guard let window = view.window else { return }
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true

        guard let content = window.contentView else { return }
        content.wantsLayer = true
        content.layer?.cornerRadius = cornerRadius
        content.layer?.masksToBounds = true
        if #available(macOS 10.15, *) {
            content.layer?.cornerCurve = .continuous
        }
        coordinator.applied = true
    }
}

#Preview {
    MenuBarView()
        .environment(KeyStore())
}
