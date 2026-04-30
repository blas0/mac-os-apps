//
//  OnboardingView.swift
//  keyDrop
//

import LocalAuthentication
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(LicenseService.self) private var licenseService
    @State private var biometryAvailable: Bool = false
    @State private var biometryProbed: Bool = false
    @State private var biometryError: String?
    @State private var licenseKey: String = ""
    @State private var showLicenseError: Bool = false
    @FocusState private var isLicenseFieldFocused: Bool

    var body: some View {
        featureContent
        .onAppear(perform: probeBiometry)
    }

    private var featureContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Divider()
            features
            Divider()
            biometrySection
            #if KEYDROP_CHANNEL_DIRECT
            Divider()
            licenseSection
            #endif
            Spacer(minLength: 0)
            footer
        }
        .padding(24)
        .frame(width: 460, height: 620)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("OnboardingIcon")
                .resizable()
                .frame(width: 32, height: 32)
            Text("keyDrop")
                .font(AppFont.rounded(22, weight: .bold))
            Text("where you dump and pickup your keys.")
                .font(AppFont.rounded(14, weight: .semibold))
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 10) {
            featureRow(symbol: "menubar.rectangle", title: "Lives in your menu bar",
                       detail: "No Dock icon, no clutter. Click the key to drop a secret.")
            featureRow(symbol: "lock.shield", title: "Stored in the Keychain",
                       detail: "Encrypted at rest, bound to this Mac, gated by Touch ID.")
            featureRow(symbol: "doc.on.clipboard", title: "Auto-clears your clipboard",
                       detail: "Copies disappear after the configured timeout.")
        }
    }

    private func featureRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(.tint)
                .frame(width: 22, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFont.body)
                Text(detail)
                    .font(AppFont.small)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var biometrySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: biometryStatusSymbol)
                    .font(.system(size: 14))
                    .foregroundStyle(biometryStatusColor)
                Text(biometryStatusTitle)
                    .font(AppFont.body)
            }
            Text(biometryStatusDetail)
                .font(AppFont.small)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    #if KEYDROP_CHANNEL_DIRECT
    private var licenseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Activate your Gumroad purchase")
                .font(AppFont.rounded(16, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                instructionRow(
                    number: "1",
                    text: "Find your license key in the Gumroad purchase confirmation email."
                )
                instructionRow(
                    number: "2",
                    text: "Paste it below to unlock keyDrop on this Mac."
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("License Key")
                    .font(AppFont.small.weight(.medium))
                TextField("XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX", text: $licenseKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .focused($isLicenseFieldFocused)
                    .disabled(licenseService.isValidating)
                    .onSubmit(activateLicenseAndCompleteOnboarding)
                    .onChange(of: licenseKey) { _, _ in
                        showLicenseError = false
                    }
            }

            if showLicenseError, let error = licenseService.lastError {
                errorBanner(error)
            }

            Link("Need a license?", destination: URL(string: "https://156859252656.gumroad.com/l/dlvjgm")!)
                .font(AppFont.small)
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
    #endif

    private var biometryStatusSymbol: String {
        if !biometryProbed { return "hourglass" }
        return biometryAvailable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
    }

    private var biometryStatusColor: Color {
        if !biometryProbed { return .secondary }
        return biometryAvailable ? .green : .orange
    }

    private var biometryStatusTitle: String {
        if !biometryProbed { return "Checking Touch ID..." }
        return biometryAvailable ? "Touch ID is ready" : "Touch ID is unavailable"
    }

    private var biometryStatusDetail: String {
        if let err = biometryError { return err }
        if !biometryProbed { return "Confirming this Mac supports biometric authentication." }
        return biometryAvailable
            ? "You'll be asked to authenticate before any stored key can be revealed or copied."
            : "Stored keys will fall back to your Mac password whenever biometric auth is unavailable."
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(action: proceedFromOnboarding) {
                if licenseService.isValidating {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 8)
                } else {
                    Text(primaryActionTitle)
                }
            }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(primaryActionDisabled)
            Spacer()
        }
    }

    private var primaryActionTitle: String {
        #if KEYDROP_CHANNEL_DIRECT
        "Activate & continue"
        #else
        "Get started"
        #endif
    }

    private var primaryActionDisabled: Bool {
        #if KEYDROP_CHANNEL_DIRECT
        licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || licenseService.isValidating
        #else
        false
        #endif
    }

    private func proceedFromOnboarding() {
        #if KEYDROP_CHANNEL_DIRECT
        activateLicenseAndCompleteOnboarding()
        #else
        completeOnboarding()
        #endif
    }

    private func activateLicenseAndCompleteOnboarding() {
        let trimmed = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            let success = await licenseService.validateLicense(key: trimmed)
            if success {
                await MainActor.run {
                    completeOnboarding()
                }
            } else {
                await MainActor.run {
                    showLicenseError = true
                }
            }
        }
    }

    @MainActor
    private func completeOnboarding() {
        onFinish()
        dismissWindow(id: "onboarding")
        NSApp.setActivationPolicy(.accessory)
    }

    private func probeBiometry() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let ctx = LAContext()
        var error: NSError?
        let canEvaluate = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        biometryAvailable = canEvaluate
        biometryError = error?.localizedDescription
        biometryProbed = true
        #if KEYDROP_CHANNEL_DIRECT
        if !licenseService.isLicensed {
            isLicenseFieldFocused = true
        }
        #endif
    }
}

#Preview {
    OnboardingView(onFinish: { })
        .environment(LicenseService())
}
