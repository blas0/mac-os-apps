//
//  OnboardingView.swift
//  keyDrop
//

import LocalAuthentication
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.dismissWindow) private var dismissWindow
    @State private var biometryAvailable: Bool = false
    @State private var biometryProbed: Bool = false
    @State private var biometryError: String?
    @State private var showLicenseStep: Bool = false

    var body: some View {
        Group {
            if showLicenseStep {
                LicenseView(onActivated: completeOnboarding)
            } else {
                featureContent
            }
        }
        .onAppear(perform: probeBiometry)
    }

    private var featureContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Divider()
            features
            Divider()
            biometrySection
            Spacer(minLength: 0)
            footer
        }
        .padding(24)
        .frame(width: 460, height: 460)
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
            Button("Get started", action: proceedFromFeatures)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Spacer()
        }
    }

    private func proceedFromFeatures() {
        #if KEYDROP_CHANNEL_DIRECT
        showLicenseStep = true
        #else
        completeOnboarding()
        #endif
    }

    private func completeOnboarding() {
        onFinish()
        dismissWindow(id: "onboarding")
    }

    private func probeBiometry() {
        let ctx = LAContext()
        var error: NSError?
        let canEvaluate = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        biometryAvailable = canEvaluate
        biometryError = error?.localizedDescription
        biometryProbed = true
    }
}

#Preview {
    OnboardingView(onFinish: { })
}
