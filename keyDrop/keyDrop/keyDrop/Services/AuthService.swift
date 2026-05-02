//
//  AuthService.swift
//  keyDrop
//

import Foundation
import LocalAuthentication
import Observation

@Observable
final class AuthService {
    private static let graceKey = "authGraceSeconds"

    var graceDuration: TimeInterval {
        get {
            let raw = UserDefaults.standard.integer(forKey: Self.graceKey)
            return raw > 0 ? TimeInterval(raw) : 5 * 60
        }
        set {
            UserDefaults.standard.set(Int(newValue), forKey: Self.graceKey)
        }
    }

    private(set) var graceExpiresAt: Date?
    private(set) var isAuthenticating: Bool = false
    private(set) var authHoldUntil: Date?

    var onInvalidate: (() -> Void)?

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

    func didAuthenticate(with context: LAContext) {
        let expires = Date().addingTimeInterval(graceDuration)
        graceExpiresAt = expires
        scheduleExpiration(at: expires)
    }

    func invalidate() {
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
