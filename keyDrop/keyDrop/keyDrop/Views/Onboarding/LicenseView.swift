//
//  LicenseView.swift
//  keyDrop
//
//  License key entry view for Direct (Gumroad) distribution.
//

import SwiftUI

#if KEYDROP_CHANNEL_DIRECT

struct LicenseView: View {
    let onActivated: () -> Void

    @Environment(LicenseService.self) private var licenseService
    @State private var licenseKey: String = ""
    @State private var showError: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            Divider()
            instructions
            licenseInput
            if showError, let error = licenseService.lastError {
                errorBanner(error)
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(24)
        .frame(width: 460, height: 380)
        .onAppear {
            isTextFieldFocused = true
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 28))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Activate keyDrop")
                    .font(AppFont.rounded(18, weight: .semibold))
                Text("Enter your license key to continue")
                    .font(AppFont.small)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Instructions

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            instructionRow(
                number: "1",
                text: "Find your license key in the purchase confirmation email from Gumroad"
            )
            instructionRow(
                number: "2",
                text: "Paste the key below (format: XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX)"
            )
            instructionRow(
                number: "3",
                text: "Click Activate to unlock the app"
            )
        }
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(AppFont.small.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.accentColor)
                .clipShape(Circle())
            Text(text)
                .font(AppFont.small)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - License Input

    private var licenseInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("License Key")
                .font(AppFont.small.weight(.medium))
            TextField("XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX", text: $licenseKey)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .focused($isTextFieldFocused)
                .disabled(licenseService.isValidating)
                .onSubmit(activate)
                .onChange(of: licenseKey) { _, _ in
                    showError = false
                }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: LicenseError) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(error.localizedDescription)
                .font(AppFont.small)
                .foregroundStyle(.red)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Link("Need a license?", destination: URL(string: "https://156859252656.gumroad.com/l/dlvjgm")!)
                .font(AppFont.small)

            Spacer()

            Button(action: activate) {
                if licenseService.isValidating {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 8)
                } else {
                    Text("Activate")
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(licenseKey.trimmingCharacters(in: .whitespaces).isEmpty || licenseService.isValidating)
        }
    }

    // MARK: - Actions

    private func activate() {
        let trimmed = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            let success = await licenseService.validateLicense(key: trimmed)
            if success {
                onActivated()
            } else {
                showError = true
            }
        }
    }
}

#Preview {
    LicenseView(onActivated: {})
        .environment(LicenseService())
}

#else

// MAS builds don't show license view
struct LicenseView: View {
    let onActivated: () -> Void

    var body: some View {
        EmptyView()
            .onAppear { onActivated() }
    }
}

#endif
