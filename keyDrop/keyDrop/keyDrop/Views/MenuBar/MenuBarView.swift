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
    @AppStorage("recentListCount") private var recentListCount: Int = 3

    @State private var label: String = ""
    @State private var key: String = ""
    @State private var statusMessage: StatusMessage?
    @State private var statusDismissTask: Task<Void, Never>?
    @State private var quitCountdown: Int?
    @State private var quitTask: Task<Void, Never>?
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

    private var visibleRecents: [KeyEntry] {
        let count = max(1, min(5, recentListCount))
        return Array(store.entries.prefix(count))
    }

    private var isQuitting: Bool { quitCountdown != nil }
    private var showsFooterCenter: Bool { isQuitting || statusMessage != nil }

    private let mutedRed = Color(red: 0.74, green: 0.36, blue: 0.36)

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                header
                form
                submitButton
                if showRecentList && !visibleRecents.isEmpty {
                    recentList
                }
            }
            .padding(16)

            footer
        }
        .frame(width: AppMetrics.popoverWidth)
        .onAppear { focusedField = .label }
    }

    private var header: some View {
        Text("keyDrop")
            .font(AppFont.title)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldBlock(title: "LABEL *") {
                TextField("e.g. OPENAI_API_KEY", text: $label)
                    .textFieldStyle(.roundedBorder)
                    .font(AppFont.body)
                    .focused($focusedField, equals: .label)
                    .onSubmit { focusedField = .key }
                    .modifier(IBeamCursor())
            }

            fieldBlock(title: "KEY *") {
                SecureField("Paste your key", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .font(AppFont.body)
                    .focused($focusedField, equals: .key)
                    .onSubmit(submit)
                    .modifier(IBeamCursor())
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
            VStack(spacing: 2) {
                Text("Drop Key")
                    .font(AppFont.body)

                HStack(spacing: 3) {
                    Image(systemName: "command").font(.system(size: 10))
                    Image(systemName: "return").font(.system(size: 10))
                    Text("to drop")
                        .font(AppFont.small)
                }
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .keyboardShortcut(.return, modifiers: .command)
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
        .environment(\.controlActiveState, .key)
        .disabled(!canSubmit)
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECENT")
                .font(AppFont.label)
                .foregroundStyle(.secondary)
            VStack(spacing: 4) {
                ForEach(visibleRecents) { entry in
                    recentRow(entry)
                }
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
                    .font(AppFont.small)
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
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if showsFooterCenter {
                HStack(spacing: 8) {
                    Spacer(minLength: 8)
                    footerCenter
                }
            }

            HStack(spacing: 10) {
                Button(action: openFeedback) {
                    Label("Feedback", systemImage: "exclamation.bubble")
                        .font(AppFont.small)
                }
                .buttonStyle(.borderless)
                .help("Open Feedback Assistant")
                .accessibilityLabel("Open Feedback Assistant")

                Spacer(minLength: 0)

                Button(action: openSettingsWindow) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                }
                .buttonStyle(.borderless)
                .help("Settings")
                .accessibilityLabel("Open settings")

                Button(action: toggleQuit) {
                    Image(systemName: isQuitting ? "stop.fill" : "power")
                        .font(.system(size: 13))
                        .foregroundStyle(isQuitting ? mutedRed : Color.primary)
                }
                .buttonStyle(.borderless)
                .help(isQuitting ? "Cancel quit" : "Quit keyDrop")
                .accessibilityLabel(isQuitting ? "Cancel quit" : "Quit keyDrop")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private var footerCenter: some View {
        if isQuitting {
            Text("\(quitCountdown ?? 0)s till quit")
                .font(AppFont.small)
                .foregroundStyle(mutedRed)
                .monospacedDigit()
        } else if let status = statusMessage {
            Text(status.text)
                .font(AppFont.small)
                .foregroundStyle(status.kind == .success ? Color.green : Color.red)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func openSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        openSettings()
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let win = NSApp.windows.first(where: { $0.canBecomeKey && $0.contentViewController != nil && $0.frame.width >= AppMetrics.settingsWidth - 1 }) else { return }
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
        statusMessage = message
        statusDismissTask?.cancel()
        statusDismissTask = nil
        guard !persistent else { return }
        let lifetime: TimeInterval = message.kind == .error ? 5 : 2.5
        statusDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(lifetime * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if statusMessage == message { statusMessage = nil }
        }
    }

    private func toggleQuit() {
        if isQuitting {
            cancelQuit()
        } else {
            startQuit()
        }
    }

    private func startQuit() {
        quitCountdown = 5
        quitTask?.cancel()
        quitTask = Task { @MainActor in
            for next in stride(from: 4, through: 0, by: -1) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                if next == 0 {
                    NSApp.terminate(nil)
                    return
                }
                quitCountdown = next
            }
        }
    }

    private func cancelQuit() {
        quitTask?.cancel()
        quitTask = nil
        quitCountdown = nil
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

#Preview {
    MenuBarView()
        .environment(KeyStore())
}
