//
//  LicenseService.swift
//  keyDrop
//
//  License validation for Direct (Gumroad) distribution.
//  Medium enforcement: validate on first launch, cache forever in Keychain.
//

import Foundation

#if KEYDROP_CHANNEL_DIRECT

enum LicenseError: Error, LocalizedError {
    case invalidKey
    case networkError(String)
    case serverError(String)
    case productMismatch
    case refunded
    case chargebacked
    case expired

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Invalid license key. Please check and try again."
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .productMismatch:
            return "This license key is for a different product."
        case .refunded:
            return "This license has been refunded."
        case .chargebacked:
            return "This license has been disputed."
        case .expired:
            return "This license has expired."
        }
    }
}

struct LicenseInfo: Codable {
    let licenseKey: String
    let email: String
    let purchaseDate: Date
    let validatedAt: Date
}

@Observable
final class LicenseService {
    // MARK: - Configuration

    /// Gumroad product ID (from product settings, not the URL slug)
    private static let productId = "Jy8k3C3ozWUG2ezk5CFJ8Q=="
    private static let keychainAccount = "license_info"

    // MARK: - State

    private(set) var isValidating: Bool = false
    private(set) var licenseInfo: LicenseInfo?
    private(set) var lastError: LicenseError?

    var isLicensed: Bool {
        licenseInfo != nil
    }

    // MARK: - Initialization

    init() {
        loadCachedLicense()
    }

    // MARK: - Public API

    /// Validate a license key against Gumroad API
    @MainActor
    func validateLicense(key: String) async -> Bool {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            lastError = .invalidKey
            return false
        }

        isValidating = true
        lastError = nil

        defer { isValidating = false }

        do {
            let info = try await verifyWithGumroad(licenseKey: trimmedKey)
            try saveLicenseToKeychain(info)
            licenseInfo = info
            return true
        } catch let error as LicenseError {
            licenseInfo = nil
            lastError = error
            return false
        } catch {
            licenseInfo = nil
            lastError = .networkError(error.localizedDescription)
            return false
        }
    }

    /// Remove stored license (for debugging/support purposes)
    func clearLicense() {
        try? KeychainService.delete(account: Self.keychainAccount)
        licenseInfo = nil
    }

    // MARK: - Private: Gumroad API

    private func verifyWithGumroad(licenseKey: String) async throws -> LicenseInfo {
        let url = URL(string: "https://api.gumroad.com/v2/licenses/verify")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "product_id=\(Self.productId)&license_key=\(licenseKey)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LicenseError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            throw LicenseError.serverError("HTTP \(httpResponse.statusCode)")
        }

        return try parseGumroadResponse(data: data, licenseKey: licenseKey)
    }

    private func parseGumroadResponse(data: Data, licenseKey: String) throws -> LicenseInfo {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LicenseError.serverError("Invalid JSON response")
        }

        // Check success field
        guard let success = json["success"] as? Bool, success else {
            let message = json["message"] as? String ?? "Unknown error"
            if message.lowercased().contains("not exist") ||
               message.lowercased().contains("invalid") {
                throw LicenseError.invalidKey
            }
            throw LicenseError.serverError(message)
        }

        // Parse purchase info
        guard let purchase = json["purchase"] as? [String: Any] else {
            throw LicenseError.serverError("Missing purchase data")
        }

        // Verify product matches
        if let productId = purchase["product_id"] as? String,
           productId != Self.productId {
            throw LicenseError.productMismatch
        }

        // Check for refund/chargeback
        if let refunded = purchase["refunded"] as? Bool, refunded {
            throw LicenseError.refunded
        }

        if let chargebacked = purchase["chargebacked"] as? Bool, chargebacked {
            throw LicenseError.chargebacked
        }

        // Check subscription status if applicable
        if let subscriptionEnded = purchase["subscription_ended_at"] as? String,
           !subscriptionEnded.isEmpty {
            throw LicenseError.expired
        }

        // Extract email
        let email = purchase["email"] as? String ?? "unknown"

        // Parse purchase date
        var purchaseDate = Date()
        if let dateString = purchase["created_at"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            purchaseDate = formatter.date(from: dateString) ?? Date()
        }

        return LicenseInfo(
            licenseKey: licenseKey,
            email: email,
            purchaseDate: purchaseDate,
            validatedAt: Date()
        )
    }

    // MARK: - Private: Keychain Storage

    private func loadCachedLicense() {
        guard let jsonString = try? KeychainService.load(account: Self.keychainAccount),
              let data = jsonString.data(using: .utf8),
              let info = decodeLicenseInfo(from: data) else {
            return
        }
        licenseInfo = info
    }

    private func decodeLicenseInfo(from data: Data) -> LicenseInfo? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(LicenseInfo.self, from: data)
    }

    private func saveLicenseToKeychain(_ info: LicenseInfo) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(info)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw LicenseError.serverError("Failed to encode license")
        }
        try KeychainService.save(account: Self.keychainAccount, value: jsonString)
    }
}

#else

// MARK: - MAS Stub (App Store handles licensing)

@Observable
final class LicenseService {
    var isLicensed: Bool { true }
    var isValidating: Bool { false }
    var licenseInfo: LicenseInfo? { nil }
    var lastError: LicenseError? { nil }

    struct LicenseInfo: Codable {
        let licenseKey: String
        let email: String
        let purchaseDate: Date
        let validatedAt: Date
    }

    enum LicenseError: Error {
        case invalidKey
    }

    func validateLicense(key: String) async -> Bool { true }
    func clearLicense() {}
}

#endif
