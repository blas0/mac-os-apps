//
//  AuthService.swift
//  keyDrop
//

import Foundation
import LocalAuthentication
import Observation

@Observable
final class AuthService {
    var graceDuration: TimeInterval = 5 * 60
    private(set) var graceExpiresAt: Date?
    private(set) var isAuthenticating: Bool = false
    private(set) var authHoldUntil: Date?

    var onInvalidate: (() -> Void)?

    private var cachedContext: LAContext?
    private var graceTimer: Timer?

    var isWithinGrace: Bool {
        guard let expires = graceExpiresAt else { return false }
        return expires > Date()
    }

    var isWithinHold: Bool {
        guard let until = authHoldUntil else { return false }
        return until > Date()
    }

    var shouldPinMenu: Bool { isAuthenticating || isWithinHold }

    func beginAuth() {
        isAuthenticating = true
        authHoldUntil = nil
    }

    func endAuth() {
        isAuthenticating = false
        authHoldUntil = Date().addingTimeInterval(3.0)
    }

    func contextForRead() -> LAContext {
        if let ctx = cachedContext, isWithinGrace {
            return ctx
        }
        let ctx = LAContext()
        ctx.localizedReason = "Unlock your stored key"
        let cap = min(graceDuration, LATouchIDAuthenticationMaximumAllowableReuseDuration)
        ctx.touchIDAuthenticationAllowableReuseDuration = cap
        return ctx
    }

    func didAuthenticate(with context: LAContext) {
        cachedContext = context
        let expires = Date().addingTimeInterval(graceDuration)
        graceExpiresAt = expires
        scheduleExpiration(at: expires)
    }

    func invalidate() {
        cachedContext?.invalidate()
        cachedContext = nil
        graceExpiresAt = nil
        graceTimer?.invalidate()
        graceTimer = nil
        onInvalidate?()
    }

    static func biometryAvailable() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    private func scheduleExpiration(at date: Date) {
        graceTimer?.invalidate()
        let interval = max(0.1, date.timeIntervalSinceNow)
        graceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.invalidate()
        }
    }
}
